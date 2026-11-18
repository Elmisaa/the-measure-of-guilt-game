class_name WalkPlayer
extends Node2D
## Alexei walking left/right in a side-view room. Sheet: 10 frames in a row
## (0–1 idle, 2–9 walk), facing right; flipped for walking left. The origin is at
## his feet. Drawn on the 4px grid of the room art.

signal moved(x: float)

@export var sheet: Texture2D
@export var frames: int = 10
@export var speed: float = 90.0
@export var grid: float = 4.0

var min_x: float = 0.0
var max_x: float = 2000.0
var frozen: bool = false

var _sprite: Sprite2D
var _t: float = 0.0
var _walking: bool = false


func _ready() -> void:
	_ensure_actions()
	_sprite = Sprite2D.new()
	_sprite.texture = sheet
	_sprite.hframes = frames
	_sprite.centered = true
	_sprite.offset = Vector2(0, -sheet.get_height() / 2.0)
	add_child(_sprite)


func _ensure_actions() -> void:
	for pair: Array in [["move_left", [KEY_A, KEY_LEFT]], ["move_right", [KEY_D, KEY_RIGHT]], ["interact", [KEY_E]]]:
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
	_walking = absf(dir) > 0.1
	if _walking:
		position.x = clampf(position.x + dir * speed * delta, min_x, max_x)
		_sprite.flip_h = dir < 0.0
		moved.emit(position.x)
	_t += delta
	if _walking:
		_sprite.frame = 2 + int(_t * 10.0) % (frames - 2)
	else:
		_sprite.frame = int(_t * 1.5) % 2
	# keep the art on the room's pixel grid
	_sprite.position.x = roundf(position.x / grid) * grid - position.x


func face_right(v: bool) -> void:
	_sprite.flip_h = not v


func is_walking() -> bool:
	return _walking
