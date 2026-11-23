class_name Jitter
extends Node

@export var amplitude: int = 1
@export var step_time: float = 0.05
@export var burst_time: float = 0.6
@export var calm_time: float = 0.5

var _target: CanvasItem
var _base: Vector2
var _t: float = 0.0
var _step: float = 0.0


func _ready() -> void:
	_target = get_parent() as CanvasItem
	_base = _get_pos()


func _process(delta: float) -> void:
	if not _target.is_visible_in_tree():
		return
	_t = fmod(_t + delta, burst_time + calm_time)
	_step -= delta
	if _step > 0.0:
		return
	_step = step_time
	var off: Vector2 = Vector2.ZERO
	if _t < burst_time:
		off = Vector2(randi_range(-amplitude, amplitude), randi_range(-amplitude, amplitude))
	_set_pos(_base + off)


func _get_pos() -> Vector2:
	if _target is Control:
		return (_target as Control).position
	return (_target as Node2D).position


func _set_pos(p: Vector2) -> void:
	if _target is Control:
		(_target as Control).position = p
	else:
		(_target as Node2D).position = p
