class_name LightFlicker
extends PointLight2D
## Living light: slow "breathing" + optional rare stutter (fluorescent tube).

@export var base_energy: float = 0.3
@export var breath_amount: float = 0.05
@export var breath_speed: float = 0.5
## Average stutters per minute (0 = never).
@export var stutters_per_minute: float = 0.0
@export var stutter_energy: float = 0.0

var _noise: FastNoiseLite = FastNoiseLite.new()
var _t: float = 0.0
var _stutter_left: float = 0.0
var _flip: float = 0.0
var _on: bool = true


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_t = randf() * 100.0


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
	elif stutters_per_minute > 0.0 and randf() < stutters_per_minute / 60.0 * delta:
		_stutter_left = randf_range(0.2, 0.7)
		_on = false
	energy = maxf(0.0, e)
