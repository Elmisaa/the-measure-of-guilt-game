class_name LightFlicker
extends PointLight2D

@export var base_energy: float = 0.3
@export var breath_amount: float = 0.05
@export var breath_speed: float = 0.5
@export var stutters_per_minute: float = 0.0
@export var stutter_energy: float = 0.0
@export var flicker_every_min: float = 0.0
@export var flicker_every_max: float = 0.0
@export var flicker_length_min: float = 0.4
@export var flicker_length_max: float = 1.2
@export var dim_node: CanvasItem

var _noise: FastNoiseLite = FastNoiseLite.new()
var _t: float = 0.0
var _stutter_left: float = 0.0
var _flip: float = 0.0
var _on: bool = true
var _next_flicker: float = 0.0


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_t = randf() * 100.0
	_next_flicker = _pick_next()
	if dim_node:
		dim_node.visible = false


func _pick_next() -> float:
	if flicker_every_max <= 0.0:
		return INF
	return randf_range(flicker_every_min, flicker_every_max)


func _start_stutter(length: float) -> void:
	_stutter_left = length
	_on = false
	_flip = randf_range(0.03, 0.12)


func _process(delta: float) -> void:
	_t += delta * breath_speed
	var e: float = base_energy + _noise.get_noise_1d(_t) * breath_amount
	if _stutter_left > 0.0:
		_stutter_left -= delta
		_flip -= delta
		if _flip <= 0.0:
			_on = not _on
			_flip = randf_range(0.03, 0.12)
		if not _on:
			e = stutter_energy
	else:
		_on = true
		_next_flicker -= delta
		if _next_flicker <= 0.0:
			_next_flicker = _pick_next()
			_start_stutter(randf_range(flicker_length_min, flicker_length_max))
		elif stutters_per_minute > 0.0 and randf() < stutters_per_minute / 60.0 * delta:
			_start_stutter(randf_range(0.2, 0.7))
	energy = maxf(0.0, e)
	if dim_node:
		dim_node.visible = not _on
