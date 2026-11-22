class_name StreetRain
extends Node2D
## Falling rain over an outdoor shot, drawn on the art's pixel grid (cell px) so it matches pixel art.
## Streaks slant a little and fall fast; area = screen rect it covers (local coords).

@export var area: Rect2 = Rect2(0, 0, 640, 360)
@export var drops: int = 90
@export var cell: int = 4
@export var speed_min: float = 520.0
@export var speed_max: float = 760.0
@export var slant: float = 0.18  ## x per y
@export var color: Color = Color(0.72, 0.8, 0.95, 0.22)

var _pos: PackedVector2Array = PackedVector2Array()
var _spd: PackedFloat32Array = PackedFloat32Array()
var _len: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_pos.resize(drops)
	_spd.resize(drops)
	_len.resize(drops)
	for i: int in drops:
		_respawn(i, true)


func _respawn(i: int, anywhere: bool) -> void:
	_pos[i] = Vector2(randf_range(area.position.x - 40.0, area.end.x), area.position.y + (randf() * area.size.y if anywhere else -randf() * 40.0))
	_spd[i] = randf_range(speed_min, speed_max)
	_len[i] = randi_range(2, 4)


func _process(delta: float) -> void:
	for i: int in drops:
		var p: Vector2 = _pos[i]
		p.y += _spd[i] * delta
		p.x += _spd[i] * delta * slant
		_pos[i] = p
		if p.y > area.end.y:
			_respawn(i, false)
	queue_redraw()


func _draw() -> void:
	var c: float = float(cell)
	for i: int in drops:
		var p: Vector2 = _pos[i]
		var gx: float = floorf(p.x / c) * c
		var gy: float = floorf(p.y / c) * c
		for k: int in _len[i]:  # a short diagonal streak, one cell per step
			draw_rect(Rect2(gx - roundf(k * slant) * c, gy - k * c, c / 2.0, c), color)
