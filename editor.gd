extends Node3D


const EXTRA_DATA_FILE_EXTENSION = ".extradata"
const ADD_POPUP_ICON_RESOLUTION = Vector2i(64, 64)
const ADD_POPUP_ICON_CAMERA_OFFSET = 4


# "DS" is short for "Data Structure"
class DS_MapObjectRegistration:
	var path: String
	var object: Node3D
	var default_extra_data: String

var registered_map_objects: Array[DS_MapObjectRegistration] = []

var selected_map_object: Node3D


func LoadSceneFromPath(path: String) -> Node3D:
	var gltf_document_load = GLTFDocument.new()
	var gltf_state_load = GLTFState.new()
	var error = gltf_document_load.append_from_file(path, gltf_state_load)
	if error != OK:
		printerr("ERROR: Failed to load scene at path: \"" + path + "\"")
		return Node3D.new()
	return gltf_document_load.generate_scene(gltf_state_load)

func LoadDefaultExtraData(path: String) -> String:
	var file := FileAccess.open(
		path.get_basename() + EXTRA_DATA_FILE_EXTENSION,
		FileAccess.READ
	)
	if file == null:
		return ""
	return file.get_as_text()

func GetColliderForMeshes(target: Node3D) -> CollisionShape3D:
	var aabb: AABB
	for child in target.find_children("", "MeshInstance3D", true, false):
		if not aabb:
			aabb = child.mesh.get_aabb()
			continue
		aabb = aabb.merge(child.mesh.get_aabb())
	
	var collider := CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	collider.shape.size = aabb.size
	
	return collider

func RegisterMapObject(
	path: String,
	default_extra_data: String = ""
) -> void:
	for existing in registered_map_objects:
		if existing.path == path:
			printerr("ERROR: MapObject \"" + path + "\" already registered!")
			return
	
	var registration := DS_MapObjectRegistration.new()
	registration.path = path
	registration.object = Area3D.new()
	registration.object.add_child(LoadSceneFromPath(path))
	registration.object.add_child(GetColliderForMeshes(registration.object))
	if default_extra_data != "":
		registration.default_extra_data = default_extra_data
	else:
		registration.default_extra_data = LoadDefaultExtraData(path)
	registered_map_objects.append(registration)
	
	var sub_viewport := SubViewport.new()
	sub_viewport.size = ADD_POPUP_ICON_RESOLUTION
	sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.world_3d = World3D.new()
	var sub_viewport_camera := Camera3D.new()
	sub_viewport_camera.position.z = ADD_POPUP_ICON_CAMERA_OFFSET
	sub_viewport.add_child(sub_viewport_camera)
	sub_viewport.add_child(registration.object.duplicate())
	get_child(0).add_child(sub_viewport)
	await RenderingServer.frame_post_draw
	var MapObject_button := Button.new()
	MapObject_button.icon = ImageTexture.create_from_image(
		sub_viewport.get_texture().get_image()
	)
	sub_viewport.queue_free()
	MapObject_button.tooltip_text = registration.path
	MapObject_button.pressed.connect(
		func():
			InstantiateMapObject(
				registration.path,
				%EditorCamera.position
			)
			%AddMapObjectPopup.hide()
			get_viewport().gui_release_focus()
	)
	%AddMapObjectButtonsGrid.add_child(MapObject_button)

func InstantiateMapObject(
	path: String,
	pos: Vector3 = Vector3.ZERO,
	rot: Vector3 = Vector3.ZERO,
	scale: Vector3 = Vector3.ONE,
	extra_data: String = "",
	name: String = ""
) -> void:
	for registration in registered_map_objects:
		if registration.path == path:
			var instance = registration.object.duplicate()
			instance.set_meta("path", path)
			if extra_data == "":
				instance.set_meta("extra_data", registration.default_extra_data)
			else:
				instance.set_meta("extra_data", extra_data)
			instance.position = pos
			instance.rotation = rot
			instance.scale = scale
			if name != "":
				instance.name = name
			add_child(instance)
			break

func SelectMapObject(target: Node3D) -> void:
	selected_map_object = target
	
	var target_collider := selected_map_object.get_child(-1)
	%SelectBoxOutline.mesh.size = target_collider.shape.size
	%SelectBoxOutline.global_transform = target_collider.global_transform
	%SelectBoxOutline.show()
	
	if not %Gizmo3D.is_selected(selected_map_object):
		%Gizmo3D.clear_selection()
		%Gizmo3D.select(selected_map_object)
	%Gizmo3D.show()
	
	%LineEdit_name.text = selected_map_object.name
	%LineEdit_position_x.text = str(selected_map_object.position.x)
	%LineEdit_position_y.text = str(selected_map_object.position.y)
	%LineEdit_position_z.text = str(selected_map_object.position.z)
	%LineEdit_rotation_x.text = str(rad_to_deg(selected_map_object.rotation.x))
	%LineEdit_rotation_y.text = str(rad_to_deg(selected_map_object.rotation.y))
	%LineEdit_rotation_z.text = str(rad_to_deg(selected_map_object.rotation.z))
	%LineEdit_scale_x.text = str(selected_map_object.scale.x)
	%LineEdit_scale_y.text = str(selected_map_object.scale.y)
	%LineEdit_scale_z.text = str(selected_map_object.scale.z)
	%CodeEdit_extra_data.text = selected_map_object.get_meta("extra_data")

func DeselectMapObject() -> void:
	selected_map_object = null
	
	%SelectBoxOutline.hide()
	
	%Gizmo3D.clear_selection()
	%Gizmo3D.hide()
	
	%LineEdit_name.text = ""
	%LineEdit_position_x.text = ""
	%LineEdit_position_y.text = ""
	%LineEdit_position_z.text = ""
	%LineEdit_rotation_x.text = ""
	%LineEdit_rotation_y.text = ""
	%LineEdit_rotation_z.text = ""
	%LineEdit_scale_x.text = ""
	%LineEdit_scale_y.text = ""
	%LineEdit_scale_z.text = ""
	%CodeEdit_extra_data.text = ""

func DeleteSelectedMapObject() -> void:
	if selected_map_object:
		var target := selected_map_object
		DeselectMapObject()
		target.queue_free()

func Save(path: String) -> void:
	var map_object_instances_data: Array[Dictionary]
	var children := get_children()
	children.pop_front() # Exclude internal nodes
	for child in children:
		map_object_instances_data.append({
			"name": child.name,
			"path": child.get_meta("path"),
			"position_x": child.global_position.x,
			"position_y": child.global_position.y,
			"position_z": child.global_position.z,
			"rotation_x": child.global_rotation.x,
			"rotation_y": child.global_rotation.y,
			"rotation_z": child.global_rotation.z,
			"scale_x": child.scale.x,
			"scale_y": child.scale.y,
			"scale_z": child.scale.z,
			"extra_data": child.get_meta("extra_data")
		})
	
	FileAccess.open(path, FileAccess.WRITE).store_string(
		JSON.stringify(map_object_instances_data, "\t")
	)

func Load(path: String) -> void:
	DeselectMapObject()
	
	var children := get_children()
	children.pop_front() # Exclude internal nodes
	for child in children:
		child.queue_free()
	
	var loaded_data = JSON.parse_string(
		FileAccess.open(path, FileAccess.READ).get_as_text()
	)
	for instance in loaded_data:
		InstantiateMapObject(
			instance["path"],
			Vector3(instance["position_x"], instance["position_y"], instance["position_z"]),
			Vector3(instance["rotation_x"], instance["rotation_y"], instance["rotation_z"]),
			Vector3(instance["scale_x"], instance["scale_y"], instance["scale_z"]),
			instance["extra_data"],
			instance["name"]
		)

# https://gist.github.com/hiulit/772b8784436898fd7f942750ad99e33e?permalink_comment_id=5034395#gistcomment-5034395
func get_all_files(path: String, file_ext := "", files := []):
	var dir = DirAccess.open(path)
	
	if DirAccess.get_open_error() == OK:
		dir.list_dir_begin()
		
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir():
				files = get_all_files(dir.get_current_dir() +"/"+ file_name, file_ext, files)
			else:
				if file_ext and file_name.get_extension() != file_ext:
					file_name = dir.get_next()
					continue
				
				files.append(dir.get_current_dir() +"/"+ file_name)
	
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access %s." % path)
	
	return files

func RegisterMapObjectsFromDir(path: String) -> void:
	var files: Array = get_all_files(path, "glb")
	for file in files:
		for i in range(len(file)): # Convert absolute path to relative path (imperfect)
			if file.substr(i, len(path)) == path:
				RegisterMapObject(file.substr(i))

func _ready() -> void:
	if (OS.get_cmdline_args().is_empty()):
		print("\n\tUSAGE: OpenMap <RELATIVE_PATH_TO_MODELS_DIR>\n")
		get_tree().quit()
		return
	
	RegisterMapObjectsFromDir(OS.get_cmdline_args()[0])

func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed):
		match event.keycode:
			KEY_ESCAPE: get_viewport().gui_release_focus()
			KEY_DELETE: DeleteSelectedMapObject()

func _physics_process(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() != null: return
	if %Gizmo3D.hovering or %Gizmo3D.editing: return
	
	if Input.is_action_just_pressed("Click"):
		var mouse_position := get_viewport().get_mouse_position()
		var from: Vector3 = %EditorCamera.project_ray_origin(mouse_position)
		var to: Vector3 = from + %EditorCamera.project_ray_normal(mouse_position) * %EditorCamera.far
		var ray_query_params := PhysicsRayQueryParameters3D.create(from, to)
		ray_query_params.collide_with_areas = true
		var raycast_result := get_world_3d().direct_space_state.intersect_ray(ray_query_params)
		if raycast_result:
			SelectMapObject(raycast_result["collider"])
		else:
			DeselectMapObject()


func _on_button_add_pressed() -> void:
	%AddMapObjectPopup.popup_centered()


func _on_button_save_pressed() -> void:
	%SaveFileDialog.popup_centered()

func _on_save_file_dialog_file_selected(path: String) -> void:
	Save(path)
	get_viewport().gui_release_focus()


func _on_button_load_pressed() -> void:
	%LoadFileDialog.popup_centered()

func _on_load_file_dialog_file_selected(path: String) -> void:
	Load(path)
	get_viewport().gui_release_focus()


func _on_line_edit_name_text_submitted(new_text: String) -> void:
	get_viewport().gui_release_focus()
	if selected_map_object:
		selected_map_object.name = new_text
	else:
		%LineEdit_name.text = ""

func _on_line_edit_position_x_text_submitted(new_text: String) -> void:
	get_viewport().gui_release_focus()
	if selected_map_object:
		selected_map_object.position.x = float(new_text)
		SelectMapObject(selected_map_object) # Refresh
	else:
		%LineEdit_position_x.text = ""

func _on_line_edit_position_y_text_submitted(new_text: String) -> void:
	get_viewport().gui_release_focus()
	if selected_map_object:
		selected_map_object.position.y = float(new_text)
		SelectMapObject(selected_map_object) # Refresh
	else:
		%LineEdit_position_y.text = ""

func _on_line_edit_position_z_text_submitted(new_text: String) -> void:
	get_viewport().gui_release_focus()
	if selected_map_object:
		selected_map_object.position.z = float(new_text)
		SelectMapObject(selected_map_object) # Refresh
	else:
		%LineEdit_position_z.text = ""

func _on_line_edit_rotation_x_text_submitted(new_text: String) -> void:
	get_viewport().gui_release_focus()
	if selected_map_object:
		selected_map_object.rotation.x = deg_to_rad(float(new_text))
		SelectMapObject(selected_map_object) # Refresh
	else:
		%LineEdit_rotation_x.text = ""

func _on_line_edit_rotation_y_text_submitted(new_text: String) -> void:
	get_viewport().gui_release_focus()
	if selected_map_object:
		selected_map_object.rotation.y = deg_to_rad(float(new_text))
		SelectMapObject(selected_map_object) # Refresh
	else:
		%LineEdit_rotation_y.text = ""

func _on_line_edit_rotation_z_text_submitted(new_text: String) -> void:
	get_viewport().gui_release_focus()
	if selected_map_object:
		selected_map_object.rotation.z = deg_to_rad(float(new_text))
		SelectMapObject(selected_map_object) # Refresh
	else:
		%LineEdit_rotation_z.text = ""

func _on_line_edit_scale_x_text_submitted(new_text: String) -> void:
	get_viewport().gui_release_focus()
	if selected_map_object:
		selected_map_object.scale.x = float(new_text)
		SelectMapObject(selected_map_object) # Refresh
	else:
		%LineEdit_scale_x.text = ""

func _on_line_edit_scale_y_text_submitted(new_text: String) -> void:
	get_viewport().gui_release_focus()
	if selected_map_object:
		selected_map_object.scale.y = float(new_text)
		SelectMapObject(selected_map_object) # Refresh
	else:
		%LineEdit_scale_y.text = ""

func _on_line_edit_scale_z_text_submitted(new_text: String) -> void:
	get_viewport().gui_release_focus()
	if selected_map_object:
		selected_map_object.scale.z = float(new_text)
		SelectMapObject(selected_map_object) # Refresh
	else:
		%LineEdit_scale_z.text = ""

func _on_code_edit_extra_data_text_changed() -> void:
	if selected_map_object:
		selected_map_object.set_meta("extra_data", %CodeEdit_extra_data.text)
	else:
		%CodeEdit_extra_data.text = ""


func _on_gizmo_3d_transform_changed(mode: Gizmo3D.TransformMode, value: Vector3) -> void:
	get_viewport().gui_release_focus()
	match mode:
		Gizmo3D.TransformMode.TRANSLATE:
			selected_map_object.global_position += value
		Gizmo3D.TransformMode.ROTATE:
			selected_map_object.global_rotation += value
		Gizmo3D.TransformMode.SCALE:
			selected_map_object.scale += value
	SelectMapObject(selected_map_object) # Refresh


func _on_line_edit_add_search_text_changed(new_text: String) -> void:
	var buttons_sorted := %AddMapObjectButtonsGrid.get_children()
	buttons_sorted.sort_custom(
		func(a, b):
			if (
				a.tooltip_text.similarity(new_text) >
				b.tooltip_text.similarity(new_text)
			):
				return true
			else:
				return false
	)
	for button in buttons_sorted:
		%AddMapObjectButtonsGrid.remove_child(button)
		%AddMapObjectButtonsGrid.add_child(button)
