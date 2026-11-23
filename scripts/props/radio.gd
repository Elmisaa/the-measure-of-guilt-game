class_name Radio
extends Node2D

signal station_changed(index: int, name: String)

const OFF_TEX: String = "res://assets/props/s01/radio_off.png"
const ON_TEX: String = "res://assets/props/s01/radio_on.png"
const CLICK: String = "res://assets/audio/sfx/radio_click.wav"
const STATIC: String = "res://assets/audio/sfx/tune_static.ogg"
const LED_POS: Vector2 = Vector2(-20, -24)
const LED_SIZE: Vector2 = Vector2(4, 4)
const BLINK_PERIOD: float = 1.6
const BLINK_ON: float = 0.25
const VOLUME_DB: float = -6.0
const CODE: String = "4719"
const DIGIT_TIME: float = 1.3
const CODE_HOLD: float = 2.6
const CODE_GAP: float = 1.2
const CAPTION_COLOR: Color = Color(0.62, 0.86, 0.72)
const CAPTION_Y: float = -164.0

var stations: Array[Dictionary] = [
	{"name": "88.3 — Ночной джаз", "tracks": ["res://assets/audio/music/radio/ruskerdax_moil.mp3"], "db": 0.0},
	{"name": "101.9 — Саксофон до утра", "tracks": ["res://assets/audio/music/radio/prosensory_jazz_sax.mp3", "res://assets/audio/music/radio/prosensory_public_domain_jazz.mp3"], "db": 0.0},
	{"name": "Странная станция", "tracks": ["res://assets/audio/music/radio/strange_station.ogg"], "db": -2.0, "code": true},
]

var _station: int = -1
var _track: int = 0
var _sprite: Sprite2D
var _led: ColorRect
var _glow: PointLight2D
var _player: AudioStreamPlayer2D
var _static: AudioStreamPlayer2D
var _t: float = 0.0
var _caption: VBoxContainer
var _digits: Label
var _code_t: float = 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load(OFF_TEX)
	_sprite.centered = false
	_sprite.position = Vector2(-24, -48)
	add_child(_sprite)
	_led = ColorRect.new()
	_led.position = LED_POS
	_led.size = LED_SIZE
	_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_led)
	_glow = PointLight2D.new()
	_glow.texture = _glow_texture()
	_glow.position = LED_POS + LED_SIZE / 2.0
	_glow.texture_scale = 0.6
	_glow.energy = 0.0
	add_child(_glow)
	_build_caption()
	_player = _make_player()
	_player.finished.connect(_next_track)
	_static = _make_player()
	_static.stream = load(STATIC)
	_set_lamp()


func _make_player() -> AudioStreamPlayer2D:
	var p: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	p.max_distance = 1100.0
	p.attenuation = 1.6
	p.panning_strength = 0.6
	p.bus = "Music"
	p.position = Vector2(0, -24)
	add_child(p)
	return p


func _glow_texture() -> Texture2D:
	var g: GradientTexture2D = GradientTexture2D.new()
	g.width = 64
	g.height = 64
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	var gr: Gradient = Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	g.gradient = gr
	return g


func _build_caption() -> void:
	_caption = VBoxContainer.new()
	_caption.add_theme_constant_override("separation", 1)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.z_index = 1000
	var title: Label = Label.new()
	title.text = "Странная станция"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", CAPTION_COLOR)
	_caption.add_child(title)
	_digits = Label.new()
	_digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_digits.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	_caption.add_child(_digits)
	_caption.size = Vector2(160, 32)
	_caption.position = Vector2(-80, CAPTION_Y)
	_caption.visible = false
	add_child(_caption)


func _update_code(delta: float) -> void:
	_code_t += delta
	var n: int = CODE.length()
	var cycle_len: float = DIGIT_TIME * n + CODE_HOLD + CODE_GAP
	var t: float = fmod(_code_t, cycle_len)
	var shown: int = mini(n, int(t / DIGIT_TIME) + 1)
	if t > DIGIT_TIME * n + CODE_HOLD:
		_digits.text = ""
		return
	var parts: PackedStringArray = PackedStringArray()
	for i: int in n:
		parts.append(CODE[i] if i < shown else "_")
	_digits.text = "  ".join(parts)


func _process(delta: float) -> void:
	_t += delta
	if _caption.visible:
		_update_code(delta)
	if _station < 0:
		var lit: bool = fmod(_t, BLINK_PERIOD) < BLINK_ON
		_led.color = Color(0.95, 0.22, 0.18) if lit else Color(0.25, 0.07, 0.06)
		_glow.energy = 0.7 if lit else 0.0


func cycle() -> int:
	_station += 1
	if _station >= stations.size():
		_station = -1
	_apply()
	return _station


func set_station(i: int) -> void:
	if i == _station or i >= stations.size():
		return
	_station = i
	_apply()


func turn_off() -> void:
	if _station < 0:
		return
	_station = -1
	_apply()


func is_on() -> bool:
	return _station >= 0


func station() -> int:
	return _station


func station_name() -> String:
	return str(stations[_station]["name"]) if _station >= 0 else ""


func _apply() -> void:
	var coded: bool = _station >= 0 and bool(stations[_station].get("code", false))
	_caption.visible = coded
	_code_t = 0.0
	_digits.text = ""
	if coded:
		var gs: Node = get_node_or_null("/root/GameState")
		if gs:
			gs.set_flag("radio_code", CODE)
	var audio: Node = get_node_or_null("/root/Audio")
	if audio:
		audio.sfx(CLICK, -8.0, randf_range(0.95, 1.05))
		audio.duck_music(_station >= 0)
	_player.stop()
	_sprite.texture = load(ON_TEX if _station >= 0 else OFF_TEX)
	_set_lamp()
	if _station >= 0:
		_static.volume_db = VOLUME_DB - 4.0
		_static.play()
		_track = 0
		await get_tree().create_timer(0.45).timeout
		if _station >= 0:
			_play_track()
	else:
		_static.stop()
	station_changed.emit(_station, station_name())


func _play_track() -> void:
	var st: Dictionary = stations[_station]
	var tracks: Array = st["tracks"]
	var s: AudioStream = load(str(tracks[_track % tracks.size()]))
	if "loop" in s:
		s.set("loop", tracks.size() == 1)
	_player.stream = s
	_player.volume_db = VOLUME_DB + float(st.get("db", 0.0))
	_player.play()


func _next_track() -> void:
	if _station < 0:
		return
	_track += 1
	_play_track()


func _set_lamp() -> void:
	if _station >= 0:
		_led.color = Color(0.45, 0.95, 0.5)
		_glow.color = Color(1.0, 0.75, 0.4)
		_glow.energy = 0.9
		_glow.texture_scale = 1.4
	else:
		_glow.color = Color(1.0, 0.25, 0.2)
		_glow.texture_scale = 0.6
