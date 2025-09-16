General-purpose cross-platform 3D map editor

Import GLTF/GLB 3D models, optionally with default extra data via ".extradata" file
with same base name and base directory, transform them in 3D space, save as JSON.

Intended to be used either directly for new games by reading from output JSON,
or by feeding JSON into custom converter program which would convert
it to an already existing map file format for an existing game/engine.

## Usage:
`OpenMap <RELATIVE_PATH_TO_MODELS_DIRECTORY>` (only supports GLTF/GLB)

## Controls:
While holding down Right Mouse Button:
- W = Forward
- S = Back
- A = Left
- D = Right
- Space = Up
- CTRL = Down

Esc = unfocus GUI

Scroll = change camera move speed

Click = select/deselect map object

Del = delete selected map object