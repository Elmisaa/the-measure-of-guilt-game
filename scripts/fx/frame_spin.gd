class_name FrameSpin
extends Sprite2D
## Loops through hframes at a fixed speed (ceiling fans).

@export var fps: float = 12.0

var _t: float = 0.0


func _ready() -> void:
	_t = randf() * hframes


func _process(delta: float) -> void:
	_t = fmod(_t + delta * fps, float(hframes))
	frame = int(_t)
