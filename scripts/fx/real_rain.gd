class_name RealRain
extends Node2D
## Screen-space rain for cutscenes: two depths of thin streaks (far — short, faint, slower; near — long,
## brighter, fast), wind gusts that change the slant, and splashes where drops hit the ground band.
## Not snapped to the pixel grid on purpose: thin fast lines read as real rain over the pixel art.

@export var area: Rect2 = Rect2(0, 44, 640, 272)
@export var intensity: float = 1.0:  ## 0 = off, 1 = heavy
	set(v):
		intensity = clampf(v, 0.0, 1.5)
@export var ground: Vector2 = Vector2(250, 316)  ## screen y band where splashes appear (x = top, y = bottom); 0,0 = none
@export var tint: Color = Color(0.72, 0.8, 0.95)

const FAR: int = 220
const NEAR: int = 90

var _p: PackedVector2Array = PackedVector2Array()
var _v: PackedFloat32Array = PackedFloat32Array()  # speed
var _l: PackedFloat32Array = PackedFloat32Array()  # length
var _near: PackedByteArray = PackedByteArray()
var _splash: Array[Vector3] = []  # x, y, age
var _t: float = 0.0
var _wind: float = 0.16


func _ready() -> void:
	for i: int in FAR + NEAR:
		_p.append(Vector2.ZERO)
		_v.append(0.0)
		_l.append(0.0)
		_near.append(1 if i >= FAR else 0)
		_spawn(i, true)


func _spawn(i: int, anywhere: bool) -> void:
	var near: bool = _near[i] == 1
	var y: float = randf_range(area.position.y - 40.0, area.end.y) if anywhere else area.position.y - randf_range(10.0, 80.0)
	_p[i] = Vector2(randf_range(area.position.x - 80.0, area.end.x + 20.0), y)
	_v[i] = randf_range(1050.0, 1350.0) if near else randf_range(620.0, 820.0)
	_l[i] = randf_range(16.0, 28.0) if near else randf_range(6.0, 11.0)


func _process(delta: float) -> void:
	_t += delta
	_wind = 0.14 + 0.08 * sin(_t * 0.7) + 0.05 * sin(_t * 2.3)  # gusts
	var active_far: int = int(FAR * minf(intensity, 1.0))
	var active_near: int = int(NEAR * intensity)
	for i: int in _p.size():
		var p: Vector2 = _p[i]
		p.y += _v[i] * delta
		p.x += _v[i] * delta * _wind
		_p[i] = p
		if p.y > area.end.y:
			var on: bool = (i < active_far) if _near[i] == 0 else (i - FAR < active_near)
			if on and ground != Vector2.ZERO and randf() < (0.5 if _near[i] == 1 else 0.12):
				_splash.append(Vector3(p.x, randf_range(ground.x, ground.y), 0.0))
			_spawn(i, false)
	for j: int in range(_splash.size() - 1, -1, -1):
		var s: Vector3 = _splash[j]
		s.z += delta
		_splash[j] = s
		if s.z > 0.22:
			_splash.remove_at(j)
	queue_redraw()


func _draw() -> void:
	if intensity <= 0.0:
		return
	var active_far: int = int(FAR * minf(intensity, 1.0))
	var active_near: int = int(NEAR * intensity)
	for i: int in _p.size():
		var near: bool = _near[i] == 1
		if (not near and i >= active_far) or (near and i - FAR >= active_near):
			continue
		var p: Vector2 = _p[i]
		if p.y < area.position.y - 30.0:
			continue
		var dir: Vector2 = Vector2(_wind, 1.0).normalized()
		var a: float = 0.26 if near else 0.13
		draw_line(p - dir * _l[i], p, Color(tint, a), 1.0 if not near else 1.5)
	for s: Vector3 in _splash:  # a little crown that opens and fades
		var k: float = s.z / 0.22
		var r: float = 1.0 + k * 4.0
		var c: Color = Color(tint, 0.35 * (1.0 - k))
		draw_line(Vector2(s.x - r, s.y - k * 3.0), Vector2(s.x - r * 0.4, s.y), c, 1.0)
		draw_line(Vector2(s.x + r, s.y - k * 3.0), Vector2(s.x + r * 0.4, s.y), c, 1.0)
