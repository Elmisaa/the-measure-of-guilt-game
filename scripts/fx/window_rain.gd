class_name WindowRain
extends Node2D
## Rain streaks visible only through the windows of a painted background.
## The window mask is computed at runtime from the background: pixels inside
## `areas` that are bluish and bright enough. Drawn on the 2x pixel grid.

@export var background: Sprite2D
@export var areas: Array[Rect2] = []
@export var drops: int = 45
@export var speed_min: float = 140.0
@export var speed_max: float = 200.0
@export var slant: float = -0.12  ## x per y
@export var color: Color = Color(0.8, 0.9, 1.0, 0.45)
@export var min_blue: int = 20  ## b - r
@export var min_luma: float = 0.1
@export var max_luma: float = 0.45  ## brighter = blinds/highlights, not outside

@export var cell: int = 2  ## art pixel size on screen

var _mask: PackedByteArray = PackedByteArray()
var _gw: int = 0
var _gh: int = 0
var _pos: PackedVector2Array = PackedVector2Array()
var _spd: PackedFloat32Array = PackedFloat32Array()
var _len: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_build_mask()
	for i in drops:
		_pos.append(Vector2.ZERO)
		_spd.append(0.0)
		_len.append(0)
		_respawn(i, true)


func _build_mask() -> void:
	var img: Image = background.texture.get_image()
	if img.is_compressed():
		img.decompress()
	_gw = img.get_width() / cell
	_gh = img.get_height() / cell
	_mask.resize(_gw * _gh)
	_mask.fill(0)
	for r: Rect2 in areas:
		for gy in range(int(r.position.y) / cell, int(r.end.y) / cell):
			for gx in range(int(r.position.x) / cell, int(r.end.x) / cell):
				if gx < 0 or gy < 0 or gx >= _gw or gy >= _gh:
					continue
				var c: Color = img.get_pixel(gx * cell, gy * cell)
				var l: float = c.get_luminance()
				if c.b8 - c.r8 >= min_blue and l >= min_luma and l <= max_luma:
					_mask[gy * _gw + gx] = 1


func _respawn(i: int, anywhere: bool) -> void:
	var r: Rect2 = areas[randi() % areas.size()]
	var y: float = randf_range(r.position.y, r.end.y) if anywhere else r.position.y - randf_range(0.0, 30.0)
	_pos[i] = Vector2(randf_range(r.position.x, r.end.x + 20.0), y)
	_spd[i] = randf_range(speed_min, speed_max)
	_len[i] = randi_range(3, 5)


func _process(delta: float) -> void:
	var bottom: float = 0.0
	for r: Rect2 in areas:
		bottom = maxf(bottom, r.end.y)
	for i in drops:
		var dy: float = _spd[i] * delta
		_pos[i] += Vector2(dy * slant, dy)
		if _pos[i].y > bottom + 8.0:
			_respawn(i, false)
	queue_redraw()


func _draw() -> void:
	for i in drops:
		var gx: int = int(_pos[i].x) / cell
		var gy: int = int(_pos[i].y) / cell
		for k in _len[i]:
			var y: int = gy - k
			if gx < 0 or y < 0 or gx >= _gw or y >= _gh or _mask[y * _gw + gx] == 0:
				continue
			var a: float = color.a * (1.0 - float(k) / float(_len[i]))
			draw_rect(Rect2(gx * cell, y * cell, cell, cell), Color(color, a))
