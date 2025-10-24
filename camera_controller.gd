extends Camera3D


const SENSITIVITY = 0.01
const MOVE_SPEED_SCROLL_MULTIPLIER = 2


var move_speed := 10.0
var rot_x := 0.0
var rot_y := 0.0

func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null: return
	
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_RIGHT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		rot_x += event.relative.x * SENSITIVITY
		rot_x = fmod(rot_x, PI*2)
		rot_y += event.relative.y * SENSITIVITY
		rot_y = clampf(rot_y, -PI/2, PI/2)
		transform.basis = Basis()
		rotate_object_local(Vector3.UP, -rot_x)
		rotate_object_local(Vector3.RIGHT, -rot_y)
	elif event is InputEventMouseMotion and not event.button_mask & MOUSE_BUTTON_RIGHT:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: move_speed *= MOVE_SPEED_SCROLL_MULTIPLIER
			MOUSE_BUTTON_WHEEL_DOWN: move_speed /= MOVE_SPEED_SCROLL_MULTIPLIER

func _physics_process(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() != null: return
	if %Gizmo3D.editing: return
	if (
		%SaveFileDialog.visible == true or
		%LoadFileDialog.visible == true or
		%AddMapObjectPopup.visible == true
	): return
	
	if Input.is_key_pressed(KEY_W): translate_object_local(Vector3.FORWARD * move_speed * delta)
	if Input.is_key_pressed(KEY_S): translate_object_local(Vector3.BACK * move_speed * delta)
	if Input.is_key_pressed(KEY_A): translate_object_local(Vector3.LEFT * move_speed * delta)
	if Input.is_key_pressed(KEY_D): translate_object_local(Vector3.RIGHT * move_speed * delta)
	if Input.is_key_pressed(KEY_SPACE): translate_object_local(Vector3.UP * move_speed * delta)
	if Input.is_key_pressed(KEY_CTRL): translate_object_local(Vector3.DOWN * move_speed * delta)
	if Input.is_key_pressed(KEY_0): global_position = Vector3.ZERO
