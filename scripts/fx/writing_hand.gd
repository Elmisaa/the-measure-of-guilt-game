class_name WritingHand
extends Sprite2D
## Drives write_wobble.gdshader: short pen strokes moving right, then a hop back
## (next word), with small pauses. Offsets are in texture pixels.

@export var stroke_step: float = 2.0
@export var strokes_per_word: int = 3
@export var stroke_time: float = 0.18
@export var pause_min: float = 0.3
@export var pause_max: float = 0.9
@export var jitter_px: float = 2.0

var _mat: ShaderMaterial
var _x: float = 0.0
var _stroke: int = 0
var _timer: float = 0.0
var _jitter: bool = false


func _ready() -> void:
	_mat = material as ShaderMaterial


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if _stroke < strokes_per_word:
		_stroke += 1
		_x += stroke_step
		_jitter = not _jitter
		_timer = stroke_time
	else:
		_stroke = 0
		_x = 0.0
		_jitter = false
		_timer = randf_range(pause_min, pause_max)
	var y: float = -jitter_px if _jitter else 0.0
	_mat.set_shader_parameter("offset_px", Vector2(_x, y))
