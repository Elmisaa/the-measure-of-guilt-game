extends Node2D

const NEXT_SCENE: String = "res://scenes/s03/penthouse.tscn"
const BG: String = "res://assets/backgrounds/s02/"
const SFX: String = "res://assets/audio/sfx/"
const TRACK: String = "res://assets/audio/music/drive_theme.wav"
const RAIN: String = "res://assets/audio/music/877124__adamdavidsmith__ambience_rain_thunder-2.ogg"
const TRACK_DB: float = -4.0
const TRACK_END: float = 18.0
const GRID: float = 4.0
const TOP: float = 35.0
const BEAT0: float = 1.71
const BEAT: float = 0.5875
const BAR: float = 2.35
const SHOT_EVENTS: Array = [
	[0.0, "_shot_precinct"],
	[1.71, "_shot_key"],
	[2.88, "_shot_leave"],
	[4.06, "_shot_skyline"],
	[5.24, "_shot_nightlife"],
	[6.41, "_shot_windshield"],
	[7.59, "_shot_tunnel"],
	[8.76, "_shot_neon"],
	[9.35, "_shot_gauges"],
	[9.94, "_shot_city"],
	[10.52, "_shot_echo"],
	[11.11, "_shot_face"],
	[13.46, "_shot_ues"],
	[18.0, "_engine_off"],
	[20.4, "_finish"],
]
const DOWNBEATS: Array[float] = [1.71, 4.06, 6.41, 8.76, 11.11, 13.46, 15.81]

var _d: Dictionary = {}
var _t: float = 0.0
var _next_event: int = 0
var _next_down: int = 0
var _shots: Node2D
var _rain_layer: CanvasLayer
var _rain: RealRain
var _fog: Array[Sprite2D] = []
var _over: CanvasLayer
var _tint: ColorRect
var _flash: ColorRect
var _black: ColorRect
var _text_layer: CanvasLayer
var _music: AudioStreamPlayer
var _rain_snd: AudioStreamPlayer
var _tex: Dictionary = {}
var _current: Node2D
var _pan: Tween
var _fx_tweens: Array[Tween] = []
var _lights: Array[Dictionary] = []
var _shake: float = 0.0
var _glow_tex: GradientTexture2D
var _done: bool = false
var shot_name: String = ""


func _ready() -> void:
	_d = DialogueData.load_file("s02_drive")
	Letterbox.show_bars()
	Hud.set_hud_visible(false)
	Audio.stop_music(0.5)
	for n: String in ["a_precinct", "b_interior", "c_leave", "d_skyline", "f_nightlife", "h_face", "i_ues", "j_tunnel"]:
		_tex[n] = load(BG + "drive_" + n + ".png")
	_glow_tex = _make_glow_tex()
	_shots = Node2D.new()
	add_child(_shots)
	_rain_layer = CanvasLayer.new()
	_rain_layer.layer = 2
	add_child(_rain_layer)
	_build_fog()
	_rain = RealRain.new()
	_rain_layer.add_child(_rain)
	_over = CanvasLayer.new()
	_over.layer = 5
	add_child(_over)
	_tint = _screen_rect(Color(0, 0, 0, 0), true)
	_flash = _screen_rect(Color(1, 1, 1, 0), false)
	_black = _screen_rect(Color(0, 0, 0, 1), false)
	_text_layer = CanvasLayer.new()
	_text_layer.layer = 95
	add_child(_text_layer)
	_music = _player(TRACK, TRACK_DB, "Music", false)
	_rain_snd = _player(RAIN, -60.0, "SFX", true)
	_rain_snd.play()
	_fade_db(_rain_snd, -18.0, 1.0)
	_music.play()


func _screen_rect(c: Color, additive: bool) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.size = Vector2(640, 360)
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if additive:
		var m: CanvasItemMaterial = CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		r.material = m
	_over.add_child(r)
	return r


func _player(path: String, db: float, bus: String, loop: bool) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	var s: AudioStream = load(path)
	if loop and "loop" in s:
		s.set("loop", true)
	p.stream = s
	p.volume_db = db
	p.bus = bus
	add_child(p)
	return p


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	while _next_event < SHOT_EVENTS.size() and _t >= float(SHOT_EVENTS[_next_event][0]):
		var ev: Array = SHOT_EVENTS[_next_event]
		_next_event += 1
		call(str(ev[1]))
	while _next_down < DOWNBEATS.size() and _t >= DOWNBEATS[_next_down]:
		_next_down += 1
		_shake = 1.0
	_update_shake(delta)
	_update_lights()
	_update_fog(delta)


func _beat_k() -> float:
	if _t < BEAT0 or _t > TRACK_END:
		return 0.0
	var ph: float = fmod(_t - BEAT0, BEAT) / BEAT
	return pow(1.0 - ph, 3.0)


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		_shots.position = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - delta * 4.0)
	var a: float = _shake * 6.0
	_shots.position = Vector2(roundf(randf_range(-a, a) / GRID) * GRID, roundf(randf_range(-a, a) * 0.5 / GRID) * GRID)


func _update_lights() -> void:
	var bk: float = _beat_k()
	for L: Dictionary in _lights:
		var n: CanvasItem = L["node"]
		if not is_instance_valid(n):
			continue
		var e: float = float(L["base"]) * (1.0 + float(L["beat"]) * bk)
		var fl: float = float(L["flicker"])
		if fl > 0.0 and randf() < fl * 0.08:
			e *= randf_range(0.2, 0.6)
		e *= 1.0 + 0.08 * sin(_t * 3.0 + float(L["phase"]))
		n.modulate.a = clampf(e, 0.0, 1.0)



func _shot_precinct() -> void:
	_show("a_precinct", "precinct", 1.0, Vector2(285, 316))
	_pan_x(0.0, -220.0, 1.71, Tween.EASE_IN)
	_fade_black(0.0, 0.9)
	_light(Vector2(352, 107), Color(1.0, 0.7, 0.35), 3.0, 0.55, 0.0, 1.0)
	_light(Vector2(672, 43), Color(1.0, 0.75, 0.4), 2.6, 0.6, 0.0, 0.3)
	_light(Vector2(92, 120), Color(1.0, 0.7, 0.35), 1.6, 0.35, 0.0, 0.0)
	_sweep(Color(0.9, 0.85, 0.7), Vector2(980, 230), Vector2(-120, 250), 1.5, Vector2(7, 2.2), 0.35)


func _shot_key() -> void:
	_show("b_interior", "key", 0.0, Vector2.ZERO)
	_current.position.x = -160.0
	_fade_db(_rain_snd, -24.0, 0.2)
	var dash: Sprite2D = _light(Vector2(483, 147), Color(0.3, 1.0, 0.7), 2.6, 0.0, 0.6, 0.0)
	var radio: Sprite2D = _light(Vector2(603, 181), Color(1.0, 0.7, 0.3), 1.8, 0.0, 0.6, 0.0)
	_after(0.58, func() -> void:
		_set_base(dash, 0.7)
		_set_base(radio, 0.6))
	_pan_x(-160.0, -120.0, 1.17, Tween.EASE_OUT)


func _shot_leave() -> void:
	_show("c_leave", "leave", 1.0, Vector2(265, 316))
	_pan_x(0.0, -40.0, 1.18, Tween.EASE_OUT)
	_fade_db(_rain_snd, -18.0, 0.2)
	for p: Vector2 in [Vector2(339, 244), Vector2(399, 229)]:
		_light(p, Color(1.0, 0.15, 0.1), 1.4, 0.9, 0.3, 0.0)
	_light(Vector2(370, 278), Color(1.0, 0.2, 0.15), 1.0, 0.4, 0.3, 0.0, Vector2(1.2, 4.0))
	_light(Vector2(171, 59), Color(1.0, 0.75, 0.4), 2.4, 0.5, 0.0, 0.2)


func _shot_skyline() -> void:
	_show("d_skyline", "skyline", 1.0, Vector2(290, 316))
	_pan_x(-120.0, -360.0, 1.18, Tween.EASE_OUT)
	for p: Vector2 in [Vector2(158, 32), Vector2(796, 175), Vector2(953, 271)]:
		_light(p, Color(1.0, 0.78, 0.45), 2.2, 0.5, 0.4, 0.15)
	_light(Vector2(877, 176), Color(0.3, 0.8, 1.0), 2.0, 0.35, 0.6, 0.0)
	_light(Vector2(368, 180), Color(0.3, 0.8, 1.0), 1.6, 0.3, 0.6, 0.0)


func _shot_nightlife() -> void:
	_show("f_nightlife", "nightlife", 1.0, Vector2(275, 316))
	_pan_x(0.0, -228.0, 1.17, Tween.EASE_IN_OUT)
	_light(Vector2(542, 87), Color(1.0, 0.8, 0.45), 4.0, 0.45, 0.8, 0.25)
	_light(Vector2(737, 107), Color(0.25, 0.9, 1.0), 3.0, 0.5, 1.0, 0.6)
	_light(Vector2(398, 122), Color(1.0, 0.15, 0.35), 2.4, 0.5, 1.0, 0.5)
	_sweep(Color(1.0, 0.9, 0.7), Vector2(-60, 250), Vector2(900, 250), 1.1, Vector2(6, 1.6), 0.3)


func _shot_windshield() -> void:
	_show("b_interior", "windshield", 0.0, Vector2.ZERO)
	_pan_x(-160.0, -40.0, 1.18, Tween.EASE_OUT)
	_fade_db(_rain_snd, -24.0, 0.2)
	_light(Vector2(483, 147), Color(0.3, 1.0, 0.7), 2.6, 0.7, 0.3, 0.0)
	for i: int in 2:
		_after(i * BEAT, func() -> void:
			_sweep(Color(1.0, 0.75, 0.4), Vector2(820, 60), Vector2(120, 120), 0.7, Vector2(5, 3), 0.4))


func _shot_tunnel() -> void:
	_show("j_tunnel", "tunnel", 0.0, Vector2.ZERO)
	_pan_x(0.0, -40.0, 1.17, Tween.EASE_IN)
	_police_lights(1.2)
	for i: int in 4:
		_after(i * 0.29, func() -> void:
			_sweep(Color(1.0, 0.8, 0.5), Vector2(330, 100), Vector2(-40, -20), 0.45, Vector2(3, 1.5), 0.45)
			_sweep(Color(1.0, 0.8, 0.5), Vector2(350, 100), Vector2(720, -20), 0.45, Vector2(3, 1.5), 0.45))


func _shot_neon() -> void:
	_cut_zoom("f_nightlife", Vector2(-860, -70), Vector2(-920, -70), "montage_neon", BEAT)
	_light(Vector2(737, 107), Color(0.25, 0.9, 1.0), 3.0, 0.6, 1.0, 0.7)
	_light(Vector2(542, 87), Color(1.0, 0.8, 0.45), 4.0, 0.5, 0.8, 0.3)


func _shot_gauges() -> void:
	_cut_zoom("b_interior", Vector2(-420, -180), Vector2(-460, -180), "montage_gauges", BEAT)
	_light(Vector2(483, 147), Color(0.3, 1.0, 0.7), 2.0, 0.8, 0.5, 0.0)


func _shot_city() -> void:
	_cut_zoom("d_skyline", Vector2(-1100, -60), Vector2(-1180, -60), "montage_city", BEAT)
	_rain.intensity = 0.0
	_light(Vector2(796, 175), Color(1.0, 0.78, 0.45), 2.0, 0.5, 0.6, 0.2)


func _shot_echo() -> void:
	_show("b_interior", "echo", 0.0, Vector2.ZERO)
	_current.position.x = -60.0
	_tint.color = Color(0.4, 0.02, 0.02)
	_fx().tween_property(_tint, "color", Color(0.18, 0.0, 0.0), 0.55)
	var lines: Array = _d.get("echoes", [])
	if not lines.is_empty():
		_echo(str(lines[0]))


func _shot_face() -> void:
	_kill_fx()
	_tint.color = Color(0, 0, 0, 0)
	_show("h_face", "face", 0.0, Vector2.ZERO)
	_pan_x(0.0, -40.0, BAR, Tween.EASE_OUT)
	var colors: Array[Color] = [Color(1.0, 0.3, 0.7), Color(0.3, 0.9, 1.0), Color(1.0, 0.75, 0.35), Color(1.0, 0.3, 0.7)]
	for i: int in colors.size():
		var c: Color = colors[i]
		_after(i * BEAT, func() -> void:
			_sweep(c, Vector2(-80, 90), Vector2(720, 150), 0.7, Vector2(4, 6), 0.32))
	_after(0.35, func() -> void: _thought(str(_d.get("thought", "")), 1.9))


func _shot_ues() -> void:
	_kill_fx()
	_show("i_ues", "ues", 1.0, Vector2(268, 316))
	_current.position.y = TOP - (1020.0 - 290.0)
	_fade_db(_rain_snd, -14.0, 1.0)
	_light(Vector2(344, 97), Color(1.0, 0.8, 0.5), 2.6, 0.7, 0.3, 0.0)
	_light(Vector2(207, 794), Color(1.0, 0.75, 0.4), 2.2, 0.6, 0.2, 0.2)
	_light(Vector2(483, 795), Color(1.0, 0.75, 0.4), 2.2, 0.6, 0.2, 0.0)
	_light(Vector2(335, 840), Color(1.0, 0.7, 0.35), 3.4, 0.45, 0.1, 0.0)
	_sweep(Color(0.95, 0.9, 0.75), Vector2(-120, 940), Vector2(260, 960), 0.9, Vector2(6, 2.2), 0.35)
	var t: Tween = create_tween()
	t.tween_interval(0.7)
	t.tween_callback(func() -> void: _rain.ground = Vector2.ZERO)
	t.tween_method(func(y: float) -> void: _current.position.y = roundf(y / GRID) * GRID, TOP - 730.0, TOP, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_after(1.6, _type_place)
	_after(15.81 - 13.46, _lightning)


func _engine_off() -> void:
	_music.stop()
	Audio.sfx(SFX + "engine_off.wav", -12.0)
	_after(0.9, func() -> void: Audio.sfx(SFX + "car_door.wav", -10.0))
	_fade_db(_rain_snd, -10.0, 1.0)


func _finish() -> void:
	_done = true
	var t: Tween = create_tween()
	t.tween_property(_black, "color:a", 1.0, 1.3)
	for c: Node in _text_layer.get_children():
		t.parallel().tween_property(c, "modulate:a", 0.0, 1.0)
	await t.finished
	_rain.intensity = 0.0
	_fade_db(_rain_snd, -40.0, 1.0)
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree():
		SceneRouter.go_to(NEXT_SCENE, 0.4)



func _show(tex: String, name: String, rain: float, ground: Vector2) -> void:
	if _pan:
		_pan.kill()
	_lights.clear()
	for c: Node in _shots.get_children():
		c.queue_free()
	_current = Node2D.new()
	_current.position = Vector2(0, TOP)
	var s: Sprite2D = Sprite2D.new()
	s.texture = _tex[tex]
	s.centered = false
	_current.add_child(s)
	_shots.add_child(_current)
	shot_name = name
	_rain.intensity = 0.0
	_rain.ground = ground
	for f: Sprite2D in _fog:
		f.visible = rain > 0.0


func _pan_x(from_x: float, to_x: float, time: float, ease: Tween.EaseType) -> void:
	var node: Node2D = _current
	_pan = create_tween()
	_pan.tween_method(func(x: float) -> void:
		if is_instance_valid(node):
			node.position.x = roundf(x / GRID) * GRID, from_x, to_x, time).set_trans(Tween.TRANS_SINE).set_ease(ease)


func _cut_zoom(tex: String, from: Vector2, to: Vector2, name: String, time: float) -> void:
	_kill_fx()
	_tint.color = Color(0, 0, 0)
	_show(tex, name, 0.0, Vector2.ZERO)
	_current.scale = Vector2(2, 2)
	_current.position = Vector2(from.x, TOP + from.y)
	var node: Node2D = _current
	_pan = create_tween()
	_pan.tween_method(func(x: float) -> void:
		if is_instance_valid(node):
			node.position.x = roundf(x / 8.0) * 8.0, from.x, to.x, time)


func _make_glow_tex() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _light(pos: Vector2, c: Color, size: float, base: float, beat: float, flicker: float, stretch: Vector2 = Vector2.ONE) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = _glow_tex
	s.position = pos
	s.scale = Vector2(size, size) * stretch
	s.self_modulate = c
	s.modulate.a = base
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	_current.add_child(s)
	_lights.append({"node": s, "base": base, "beat": beat, "flicker": flicker, "phase": randf() * TAU})
	return s


func _set_base(s: Sprite2D, base: float) -> void:
	for L: Dictionary in _lights:
		if L["node"] == s:
			L["base"] = base


func _sweep(c: Color, from: Vector2, to: Vector2, time: float, scl: Vector2, alpha: float) -> void:
	if not is_instance_valid(_current):
		return
	var s: Sprite2D = Sprite2D.new()
	s.texture = _glow_tex
	s.position = from
	s.scale = scl
	s.self_modulate = c
	s.modulate.a = 0.0
	var m: CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	_current.add_child(s)
	var t: Tween = s.create_tween()
	t.tween_property(s, "position", to, time)
	t.parallel().tween_property(s, "modulate:a", alpha, time * 0.3)
	t.parallel().tween_property(s, "modulate:a", 0.0, time * 0.4).set_delay(time * 0.6)
	t.tween_callback(s.queue_free)


func _police_lights(time: float) -> void:
	_kill_fx()
	var red: Sprite2D = _light(Vector2(315, 145), Color(1.0, 0.1, 0.1), 1.6, 0.0, 0.0, 0.0)
	var blue: Sprite2D = _light(Vector2(373, 149), Color(0.15, 0.35, 1.0), 1.6, 0.0, 0.0, 0.0)
	var wall_r: Sprite2D = _light(Vector2(90, 150), Color(1.0, 0.1, 0.1), 6.0, 0.0, 0.0, 0.0)
	var wall_b: Sprite2D = _light(Vector2(590, 150), Color(0.15, 0.35, 1.0), 6.0, 0.0, 0.0, 0.0)
	var t: Tween = _fx()
	t.set_loops(int(time / 0.3) + 1)
	t.tween_callback(func() -> void:
		_set_base(red, 0.95)
		_set_base(wall_r, 0.3)
		_set_base(blue, 0.0)
		_set_base(wall_b, 0.0)
		_tint.color = Color(0.08, 0.0, 0.0))
	t.tween_interval(0.15)
	t.tween_callback(func() -> void:
		_set_base(red, 0.0)
		_set_base(wall_r, 0.0)
		_set_base(blue, 0.95)
		_set_base(wall_b, 0.3)
		_tint.color = Color(0.0, 0.02, 0.1))
	t.tween_interval(0.15)


func _lightning() -> void:
	var t: Tween = create_tween()
	t.tween_property(_flash, "color:a", 0.45, 0.04)
	t.tween_property(_flash, "color:a", 0.05, 0.1)
	t.tween_property(_flash, "color:a", 0.3, 0.04)
	t.tween_property(_flash, "color:a", 0.0, 0.5)


func _build_fog() -> void:
	for i: int in 2:
		var n: FastNoiseLite = FastNoiseLite.new()
		n.seed = 7 + i
		n.frequency = 0.012 if i == 0 else 0.02
		n.fractal_octaves = 3
		var tex: NoiseTexture2D = NoiseTexture2D.new()
		tex.width = 640
		tex.height = 272
		tex.seamless = true
		tex.noise = n
		var s: Sprite2D = Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = Vector2(0, 44)
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, 640, 272)
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.modulate = Color(0.55, 0.65, 0.8, 0.09 if i == 0 else 0.06)
		var m: CanvasItemMaterial = CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
		_rain_layer.add_child(s)
		_fog.append(s)


func _update_fog(delta: float) -> void:
	for i: int in _fog.size():
		var r: Rect2 = _fog[i].region_rect
		r.position.x += delta * (14.0 if i == 0 else 26.0)
		_fog[i].region_rect = r


func _echo(text: String) -> void:
	var l: RichTextLabel = RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size = Vector2(640, 40)
	l.position = Vector2(0, 150)
	l.text = "[center][font_size=24][shake rate=24.0 level=8 connected=1][color=#f0dccc]%s[/color][/shake][/font_size][/center]" % text
	_text_layer.add_child(l)
	var t: Tween = create_tween()
	t.tween_interval(0.45)
	t.tween_property(l, "modulate:a", 0.0, 0.15)
	t.tween_callback(l.queue_free)


func _thought(text: String, time: float) -> void:
	var l: Label = Label.new()
	l.text = text
	l.size = Vector2(600, 20)
	l.position = Vector2(20, 290)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.modulate.a = 0.0
	_text_layer.add_child(l)
	var t: Tween = create_tween()
	t.tween_property(l, "modulate:a", 1.0, 0.3)
	t.tween_interval(maxf(0.1, time - 0.6))
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


func _type_place() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(28, 262)
	box.add_theme_constant_override("separation", 2)
	_text_layer.add_child(box)
	var lines: Array = _d.get("place", [])
	var labels: Array[Label] = []
	for i: int in lines.size():
		var l: Label = Label.new()
		l.text = str(lines[i])
		l.visible_characters = 0
		l.add_theme_color_override("font_color", Color(0.93, 0.9, 0.82) if i == 0 else Color(0.62, 0.86, 0.72))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		if i == 0:
			l.add_theme_font_size_override("font_size", 16)
		box.add_child(l)
		labels.append(l)
	for l: Label in labels:
		for c: int in l.text.length():
			if not is_inside_tree() or _done:
				return
			l.visible_characters = c + 1
			if l.text[c] != " ":
				Audio.sfx(SFX + "key_tick.wav", -22.0, randf_range(0.9, 1.1))
			await get_tree().create_timer(0.04).timeout
		await get_tree().create_timer(0.2).timeout


func _fade_black(alpha: float, time: float) -> void:
	create_tween().tween_property(_black, "color:a", alpha, time)


func _fade_db(p: AudioStreamPlayer, db: float, time: float) -> void:
	create_tween().tween_property(p, "volume_db", db, time)


func _after(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec, false).timeout.connect(func() -> void:
		if is_inside_tree() and not _done:
			f.call())


func _fx() -> Tween:
	var t: Tween = create_tween()
	_fx_tweens.append(t)
	return t


func _kill_fx() -> void:
	for t: Tween in _fx_tweens:
		if t and t.is_valid():
			t.kill()
	_fx_tweens.clear()
