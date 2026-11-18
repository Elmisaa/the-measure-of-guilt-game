class_name WalkPlayer
extends Node2D
## Alexei walking left/right in a side-view room. Sheet: 10 frames in a row
## (0–1 idle, 2–9 walk), facing right; flipped for walking left. The origin is at
## his feet. Drawn on the 4px grid of the room art.

signal moved(x: float)

@export var sheet: Texture2D
@export var frames: int = 10
## Rows in the sheet = the same animation pre-rendered at smaller sizes (depth).
@export var depth_rows: int = 1
@export var speed: float = 90.0
@export var grid: float = 4.0

## Depth: W/S step toward the wall (y_far) or back (y_near); smaller when farther.
var y_far: float = 346.0
var y_near: float = 346.0
var scale_far: float = 1.0
@export var depth_speed: float = 40.0
var min_x: float = 0.0
var max_x: float = 2000.0
var frozen: bool = false

var _sprite: Sprite2D
var _t: float = 0.0
var _walking: bool = false
var _row: int = 0


func _ready() -> void:
	_ensure_actions()
	_sprite = Sprite2D.new()
	_sprite.texture = sheet
	_sprite.hframes = frames
	_sprite.vframes = depth_rows
	_sprite.centered = true
	_sprite.offset = Vector2(0, -sheet.get_height() / float(depth_rows) / 2.0)
	add_child(_sprite)


func _ensure_actions() -> void:
	for pair: Array in [["move_left", [KEY_A, KEY_LEFT]], ["move_right", [KEY_D, KEY_RIGHT]], ["move_up", [KEY_W, KEY_UP]], ["move_down", [KEY_S, KEY_DOWN]], ["interact", [KEY_E]]]:
		var action: String = pair[0]
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in pair[1]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	var dir: float = 0.0 if frozen else Input.get_axis("move_left", "move_right")
	var vdir: float = 0.0 if frozen or y_far == y_near else Input.get_axis("move_up", "move_down")
	_walking = absf(dir) > 0.1 or absf(vdir) > 0.1
	if absf(dir) > 0.1:
		position.x = clampf(position.x + dir * speed * delta, min_x, max_x)
		_sprite.flip_h = dir < 0.0
		moved.emit(position.x)
	if absf(vdir) > 0.1:
		position.y = clampf(position.y + vdir * depth_speed * delta, y_far, y_near)
	_apply_depth()
	_t += delta
	var col: int = 2 + int(_t * 9.0) % (frames - 2) if _walking else int(_t * 1.5) % 2
	_sprite.frame = _row * frames + col
	# keep the art on the room's pixel grid
	_sprite.position.x = roundf(position.x / grid) * grid - position.x


## Farther from the camera = smaller: pick a pre-rendered row (clean pixels, no scaling).
func _apply_depth() -> void:
	if y_far == y_near or depth_rows <= 1:
		return
	var k: float = clampf((position.y - y_far) / (y_near - y_far), 0.0, 1.0)  # 0 far .. 1 near
	_row = clampi(int(roundf((1.0 - k) * float(depth_rows - 1))), 0, depth_rows - 1)
	z_index = int(position.y)


func depth_row() -> int:
	return _row


func face_right(v: bool) -> void:
	_sprite.flip_h = not v


func is_walking() -> bool:
	return _walking
