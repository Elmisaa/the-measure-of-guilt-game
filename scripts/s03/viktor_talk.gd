extends Node2D

@export var data_name: String = "s03_viktor"
@export var phone: bool = false

const BACK_SCENE: String = "res://scenes/s03/penthouse.tscn"
const TITLE_SCENE: String = "res://scenes/menu/title.tscn"
const BG_NORMAL: String = "res://assets/backgrounds/s03/talk_normal.png"
const BG_MOON: String = "res://assets/backgrounds/s03/talk_moon.png"
const ALEXEI_SHEET: String = "res://assets/characters/alexei/alexei_talk.png"
const ALEXEI_WALK: String = "res://assets/characters/alexei/walk_side_depth_coat.png"
const WALK_SPEED: float = 70.0
const HOLE_POS: Vector2 = Vector2(458, 162)
const HOLE_SCALE: float = 0.75
const VIKTOR_SHEET: String = "res://assets/characters/viktor/viktor_poses.png"
const ENTITY_TEX: String = "res://assets/characters/entity/entity.png"
const BULLET_TEX: String = "res://assets/props/s03/bullet.png"
const GLASS_HOLE: String = "res://assets/props/s03/glass_hole.png"
const SFX: String = "res://assets/audio/sfx/"
const AMBIENCE: String = "res://assets/audio/music/877124__adamdavidsmith__ambience_rain_thunder-2.ogg"
const HEARTBEAT: String = "res://assets/audio/sfx/879917__woodbetweenstudio__heartbeat-tense.wav"
const GLITCH_SHADER: String = "res://scripts/fx/screen_glitch.gdshader"
const WOBBLE_SHADER: String = "res://scripts/fx/entity_wobble.gdshader"
const CHARS_PER_SEC: float = 34.0
const ALEXEI_POS: Vector2 = Vector2(164, 342)
const VIKTOR_POS: Vector2 = Vector2(458, 322)
const ENTITY_POS: Vector2 = Vector2(588, 326)
const LAMP_POS: Vector2 = Vector2(296, 185)
const WINDOW_X: float = 458.0
const CHAR_SCALE: float = 1.0
const PAGE_CHARS: int = 110
const GLASS_RAIN: String = "res://scripts/fx/glass_rain.gdshader"
const LAMP_UV: Dictionary = {
	"res://assets/backgrounds/s03/talk_normal.png": Vector2(0.462, 0.514),
	"res://assets/props/s03/shot_viktor.png": Vector2(0.22, 0.28),
	"res://assets/props/s03/shot_alexei.png": Vector2(0.77, 0.27),
}
const MUSIC: String = "res://assets/audio/music/penthouse_theme.wav"
const ENTITY_DRONE: String = "res://assets/audio/sfx/entity_drone.wav"
const VOICE: Dictionary = {"viktor": ["res://assets/audio/sfx/key_viktor_1.wav", "res://assets/audio/sfx/key_viktor_2.wav", "res://assets/audio/sfx/key_viktor_3.wav"], "ivan": ["res://assets/audio/sfx/key_ivan_1.wav", "res://assets/audio/sfx/key_ivan_2.wav", "res://assets/audio/sfx/key_ivan_3.wav"], "dmitry": ["res://assets/audio/sfx/key_viktor_1.wav", "res://assets/audio/sfx/key_viktor_3.wav"]}
const PITCH: Dictionary = {"alexei": 1.0, "viktor": 0.78, "ivan": 1.0, "dmitry": 1.15}

var _d: Dictionary = {}
var _steps: Array = []
var _i: int = 0
var _frame: Node2D
var _bg: Sprite2D
var _alexei: Sprite2D
var _viktor: Sprite2D
var _entity: Sprite2D
var _smoke: CPUParticles2D
var _lamp: Sprite2D
var _hole: Sprite2D
var _glow_tex: GradientTexture2D
var _glitch: ShaderMaterial
var _black: ColorRect
var _flash: ColorRect
var _dim: ColorRect
var _ui: Control
var _box: VBoxContainer
var _name: Label
var _text: RichTextLabel
var _thought: ThoughtBox
var _insert: TextureRect
var _notice: PanelContainer
var _notice_label: Label
var _clock: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _typing: Tween
var _wait_click: bool = false
var _shake: float = 0.0
var _shake_amp: float = 2.0
var _zoom_to: String = "wide"
var _frozen: bool = false
var _choice_box: Control
var _choice_made: String = ""
var _speaker: String = ""
var _shown: int = 0
var step_name: String = ""
var _shot: TextureRect
var _drone: AudioStreamPlayer
var _music: AudioStreamPlayer
var _last_space: int = -1
var _tension: float = 0.0
var _glitch_spike: float = 0.0
var _rain_mats: Array[ShaderMaterial] = []
var _lamp_uv: Dictionary = LAMP_UV.duplicate()
var _rain_on: float = 1.0
var _lamp_t: float = 0.0


func _ready() -> void:
	_d = DialogueData.load_file(data_name)
	_steps = _d.get("steps", [])
	_rain_on = float(_d.get("rain", 1.0))
	var extra: Dictionary = _d.get("lamp_uv", {})
	for k: String in extra:
		_lamp_uv[k] = Vector2(float(extra[k][0]), float(extra[k][1]))
	Hud.set_hud_visible(false)
	Letterbox.hide_bars()
	_glow_tex = _make_glow()
	_build_frame()
	_build_fx()
	_build_ui()
	_clock = _player(SFX + "clock_tick.wav", -16.0, true)
	_drone = _player(ENTITY_DRONE, -6.0, true)
	_music = _player(str(_d.get("music", MUSIC)), -14.0, true)
	_music.bus = "Music"
	_heart = _player(HEARTBEAT, -8.0, true)
	_wind = _player(SFX + "wind_loop.wav", -10.0, true)
	if phone:
		var backdrop: ColorRect = ColorRect.new()
		backdrop.size = Vector2(640, 360)
		backdrop.color = Color(0, 0, 0, 1)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(backdrop)
		_frame.move_child(backdrop, 0)
		_bg.visible = false
		_alexei.visible = false
		_viktor.visible = false
		_lamp.visible = false
	else:
		if bool(_d.get("clock", true)):
			_clock.play()
		Audio.stop_music(0.5)
		_music.play()
	_run()


func _player(path: String, db: float, loop: bool) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	var s: AudioStream = load(path)
	if loop and "loop" in s:
		s.set("loop", true)
	if loop and s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)
	p.stream = s
	p.volume_db = db
	p.bus = "SFX"
	add_child(p)
	return p


func _make_glow() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _tex_or_box(path: String, size: Vector2i, c: Color) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


func _build_frame() -> void:
	_frame = Node2D.new()
	add_child(_frame)
	_bg = Sprite2D.new()
	var bg_path: String = str(_d.get("bg", BG_NORMAL))
	_bg.texture = load(bg_path)
	_bg.centered = false
	_bg.material = _rain_mat(bg_path)
	_frame.add_child(_bg)
	_lamp = Sprite2D.new()
	_lamp.texture = _glow_tex
	_lamp.position = LAMP_POS
	_lamp.scale = Vector2(3.2, 3.2)
	_lamp.self_modulate = Color(1.0, 0.7, 0.35)
	_lamp.modulate.a = 0.35
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lamp.material = add
	_frame.add_child(_lamp)
	_hole = Sprite2D.new()
	_hole.texture = _tex_or_box(GLASS_HOLE, Vector2i(4, 4), Color(0, 0, 0, 0))
	_hole.position = HOLE_POS
	_hole.visible = false
	_frame.add_child(_hole)
	var op: Array = _d.get("other_pos", [VIKTOR_POS.x, VIKTOR_POS.y])
	_viktor = _char(str(_d.get("other_sheet", VIKTOR_SHEET)), int(_d.get("other_frames", 7)), Vector2(float(op[0]), float(op[1])), Color(0.55, 0.55, 0.6))
	_viktor.scale *= float(_d.get("other_scale", 1.0))
	_viktor.flip_h = bool(_d.get("other_flip", true))
	_entity = Sprite2D.new()
	_entity.texture = _tex_or_box(ENTITY_TEX, Vector2i(160, 320), Color(0.02, 0.02, 0.03, 0.95))
	_entity.offset = Vector2(0, -_entity.texture.get_height() / 2.0)
	_entity.position = ENTITY_POS
	_entity.visible = false
	var wob: ShaderMaterial = ShaderMaterial.new()
	wob.shader = load(WOBBLE_SHADER)
	_entity.material = wob
	_frame.add_child(_entity)
	_smoke = CPUParticles2D.new()
	_smoke.position = ENTITY_POS + Vector2(0, -110)
	_smoke.emitting = false
	_smoke.amount = 40
	_smoke.lifetime = 2.4
	_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_smoke.emission_rect_extents = Vector2(50, 100)
	_smoke.direction = Vector2(-0.3, -1)
	_smoke.initial_velocity_min = 6.0
	_smoke.initial_velocity_max = 18.0
	_smoke.gravity = Vector2.ZERO
	_smoke.scale_amount_min = 4.0
	_smoke.scale_amount_max = 10.0
	_smoke.color = Color(0.02, 0.02, 0.04, 0.55)
	_frame.add_child(_smoke)
	var ap: Array = _d.get("alexei_pos", [ALEXEI_POS.x, ALEXEI_POS.y])
	_alexei = _char(ALEXEI_SHEET, 4, Vector2(float(ap[0]), float(ap[1])), Color(0.3, 0.32, 0.4))
	if _d.has("lamp_pos"):
		_lamp.position = Vector2(float(_d["lamp_pos"][0]), float(_d["lamp_pos"][1]))


func _char(path: String, frames: int, pos: Vector2, placeholder: Color) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = _tex_or_box(path, Vector2i(100 * frames, 200), placeholder)
	s.hframes = frames
	s.offset = Vector2(0, -100)
	s.scale = Vector2(CHAR_SCALE, CHAR_SCALE)
	s.position = pos
	_frame.add_child(s)
	return s


func _build_fx() -> void:
	var gl: CanvasLayer = CanvasLayer.new()
	gl.layer = 1
	add_child(gl)
	var r: ColorRect = ColorRect.new()
	r.size = Vector2(640, 360)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch = ShaderMaterial.new()
	_glitch.shader = load(GLITCH_SHADER)
	_glitch.set_shader_parameter("intensity", 0.0)
	_glitch.set_shader_parameter("saturation", 1.0)
	r.material = _glitch
	gl.add_child(r)
	var top: CanvasLayer = CanvasLayer.new()
	top.layer = 3
	add_child(top)
	_dim = _rect(top, Color(0, 0, 0, 0))
	_flash = _rect(top, Color(1, 1, 1, 0))
	_black = _rect(top, Color(0, 0, 0, 1))
	_shot = TextureRect.new()
	_shot.visible = false
	_shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shot.size = Vector2(640, 360)
	_shot.material = _rain_mat("")
	top.add_child(_shot)
	top.move_child(_shot, 0)
	_insert = TextureRect.new()
	_insert.visible = false
	_insert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insert.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(_insert)


func _rain_mat(tex_path: String) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(GLASS_RAIN)
	m.set_shader_parameter("lamp_uv", _lamp_uv.get(tex_path, Vector2(-1, -1)))
	_vary_rain(m, tex_path)
	_rain_mats.append(m)
	return m


func _vary_rain(m: ShaderMaterial, key: String) -> void:
	var h: int = absi(key.hash())
	m.set_shader_parameter("seed", float(h % 97) * 1.37)
	m.set_shader_parameter("slant", 0.04 + float(h % 7) * 0.025 * (1.0 if h % 2 == 0 else -0.6))
	m.set_shader_parameter("density", 0.8 + float((h / 7) % 5) * 0.12)


func _update_light(delta: float) -> void:
	_lamp_t += delta
	var e: float = 0.75 + 0.12 * sin(_lamp_t * 1.7) + 0.06 * sin(_lamp_t * 5.3)
	if _lamp.visible and _lamp.modulate.a < 0.2:
		e *= 0.2
	if not _lamp.visible:
		e = 0.0
	for m: ShaderMaterial in _rain_mats:
		m.set_shader_parameter("rain", _rain_on)
		m.set_shader_parameter("lamp_energy", e)


func _rect(parent: Node, c: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.size = Vector2(640, 360)
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	_ui.add_child(_box)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 8)
	_box.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(250, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	_box.add_child(_text)
	_thought = ThoughtBox.new()
	_ui.add_child(_thought)
	_notice = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.92)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.5, 0.45, 0.3)
	sb.set_content_margin_all(6)
	_notice.add_theme_stylebox_override("panel", sb)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	_notice_label = Label.new()
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.custom_minimum_size = Vector2(380, 0)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_child(_notice_label)
	_ui.add_child(_notice)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		var a: float = _shake * _shake_amp * 4.0
		_frame.position = _zoom_base() + Vector2(roundf(randf_range(-a, a) / 4.0) * 4.0, roundf(randf_range(-a, a) / 4.0) * 4.0)
	_update_blips()
	_update_tension(delta)
	_update_light(delta)


func _update_tension(delta: float) -> void:
	if _glitch_spike > 0.0:
		_glitch_spike = maxf(0.0, _glitch_spike - delta * 1.5)
	_glitch.set_shader_parameter("intensity", _tension * 0.3 + _glitch_spike)
	if _lamp.visible and _tension > 0.0 and randf() < _tension * delta * 3.0:
		_lamp_dip()


func _lamp_dip() -> void:
	var t: Tween = create_tween()
	t.tween_property(_lamp, "modulate:a", 0.04, 0.04)
	t.parallel().tween_property(_dim, "color:a", 0.22, 0.04)
	t.tween_interval(randf_range(0.05, 0.2))
	t.tween_property(_lamp, "modulate:a", 0.35, 0.06)
	t.parallel().tween_property(_dim, "color:a", 0.0, 0.06)


func _zoom_base() -> Vector2:
	if _zoom_to == "wide":
		return Vector2.ZERO
	var focus: Vector2 = (_viktor.position if _zoom_to == "viktor" else _alexei.position) + Vector2(0, -110 * CHAR_SCALE)
	var p: Vector2 = Vector2(320, 180) - focus * 2.0
	p.x = clampf(p.x, -640.0, 0.0)
	p.y = clampf(p.y, -360.0, 0.0)
	return (p / 8.0).round() * 8.0


func _run() -> void:
	var t: Tween = create_tween()
	t.tween_property(_black, "color:a", 0.0, 0.6)
	await t.finished
	while _i < _steps.size():
		var s: Dictionary = _steps[_i]
		_i += 1
		if s.has("if") and not bool(GameState.get_flag(str(s["if"]), false)):
			continue
		if not is_inside_tree():
			return
		await _step(s)


func _step(s: Dictionary) -> void:
	if s.has("say"):
		step_name = "say:" + str(s["say"])
		await _say(str(s["say"]), str(s["text"]))
	elif s.has("think"):
		step_name = "think"
		_box.visible = false
		var tp: PackedStringArray = TextPager.pages(str(s["think"]), PAGE_CHARS)
		for pi: int in tp.size():
			_thought.show_text(tp[pi], 0.0, pi < tp.size() - 1)
			await _advance()
		_thought.hide_box()
	elif s.has("choice"):
		step_name = "choice"
		await _choice(s["choice"])
	else:
		step_name = str(s.get("do", ""))
		await _do(s)


func _say(who: String, text: String) -> void:
	_thought.hide_box()
	if who == "entity":
		await _entity_voice(text)
		return
	_speaker = who
	var names: Dictionary = _d.get("names", {})
	_name.text = str(names.get(who, who))
	_name.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66) if who == "alexei" else Color(0.72, 0.8, 0.86))
	var pages: PackedStringArray = TextPager.pages(text, PAGE_CHARS)
	for pi: int in pages.size():
		var loud: bool = "!" in pages[pi]
		_text.text = pages[pi]
		if loud:
			_shake = 0.6
			_shake_amp = 1.0 + _tension
		_text.visible_ratio = 0.0
		_box.visible = true
		await get_tree().process_frame
		_box.reset_size()
		var screen_x: float = (_alexei.position if who == "alexei" else _viktor.position).x
		_box.position = Vector2(16, 18) if screen_x < 320.0 or (_shot.visible and who == "alexei") else Vector2(374, 18)
		if phone:
			_box.position = Vector2(16, 18) if who == "alexei" else Vector2(374, 18)
		_shown = 0
		_last_space = -1
		_typing = create_tween()
		_typing.tween_property(_text, "visible_ratio", 1.0, maxf(0.15, pages[pi].length() / CHARS_PER_SEC))
		await _advance()
	_box.visible = false


func _update_blips() -> void:
	if not (_typing and _typing.is_running()) or not _box.visible:
		return
	var n: int = int(_text.visible_ratio * _text.get_total_character_count())
	var txt: String = _text.get_parsed_text()
	while _shown < n and _shown < txt.length():
		var c: String = txt[_shown]
		_shown += 1
		if VOICE.has(_speaker):
			if (_shown == 1 or c == " ") and _shown - _last_space > 1:
				_last_space = _shown
				var list: Array = VOICE[_speaker]
				Audio.sfx(str(list[randi() % list.size()]), -14.0, float(PITCH.get(_speaker, 1.0)) * randf_range(0.96, 1.04))
		elif _shown % 2 == 0:
			Audio.sfx(SFX + "voice_blip.wav", -16.0, randf_range(0.92, 1.1))


func _advance() -> void:
	_wait_click = true
	while _wait_click:
		if not is_inside_tree():
			return
		await get_tree().process_frame


func _unhandled_input(event: InputEvent) -> void:
	if not _wait_click:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var go: bool = event.is_action_pressed("ui_accept") or (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT)
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode == KEY_SPACE:
		go = true
	if not go:
		return
	get_viewport().set_input_as_handled()
	if _typing and _typing.is_running():
		_typing.kill()
		_text.visible_ratio = 1.0
		return
	_wait_click = false


func _do(s: Dictionary) -> void:
	match str(s.get("do", "")):
		"wait":
			await get_tree().create_timer(float(s.get("t", 0.5))).timeout
		"pose":
			var spr: Sprite2D = _who(str(s["who"]))
			spr.frame = int(s["pose"])
		"move":
			if str(s["who"]) == "alexei" and bool(s.get("walk", false)):
				await _walk_alexei(float(s["x"]), str(s.get("face", "")))
			else:
				var spr2: Sprite2D = _who(str(s["who"]))
				var t: Tween = create_tween()
				t.tween_method(func(x: float) -> void: spr2.position.x = roundf(x / 4.0) * 4.0, spr2.position.x, float(s["x"]), 0.6)
				await t.finished
		"shot":
			await _show_shot(str(s.get("img", "")))
		"shake":
			_shake = 1.0
			_shake_amp = float(s.get("amp", 1))
		"lamp_flicker":
			var t2: Tween = create_tween()
			for i: int in 3:
				t2.tween_property(_lamp, "modulate:a", 0.05, 0.05)
				t2.tween_property(_dim, "color:a", 0.25, 0.05)
				t2.tween_property(_lamp, "modulate:a", 0.35, 0.08)
				t2.tween_property(_dim, "color:a", 0.0, 0.05)
		"clock":
			_clock.volume_db = float(s.get("db", -16.0))
		"hum":
			if bool(s.get("on", true)):
				Audio.play_track(AMBIENCE, 0.6, -22.0)
			else:
				Audio.stop_music(0.3)
		"saturation":
			var t3: Tween = create_tween()
			t3.tween_method(func(v: float) -> void: _glitch.set_shader_parameter("saturation", v), float(_glitch.get_shader_parameter("saturation")), float(s["v"]), float(s.get("time", 1.0)))
		"tension":
			_tension = float(s["v"])
		"glitch":
			_glitch_spike = float(s.get("v", 0.6))
		"heartbeat_once":
			Audio.sfx(HEARTBEAT, -6.0)
		"insert":
			await _show_insert(str(s["img"]), float(s.get("scale", 1.5)), bool(s.get("fill", false)))
			if s.has("label"):
				_insert_label(str(s["label"]), s.get("label_rect", [0, 0, 100, 20]))
		"insert_off":
			_insert.visible = false
			_clear_insert_labels()
			_dim.color.a = 0.0
		"portrait_off":
			await _show_shot("")
		"portrait":
			await _show_shot(str(s["img"]))
		"entity_arrives":
			await _entity_arrives()
		"gunshot":
			await _gunshot()
		"psych_attack":
			await _psych(s.get("lines", []))
		"viktor_falls":
			await _viktor_falls()
		"end":
			await _end()
		"notice":
			await _show_notice(str(s.get("text", "")), bool(s.get("good", true)))
		"item":
			GameState.add_item(str(s["id"]))
		"flag":
			GameState.set_flag(str(s["key"]), s.get("value", true))
		"notebook":
			await _notebook(s)
		"punch":
			await _punch()
		"sfx":
			Audio.sfx(str(s["path"]), float(s.get("db", -6.0)))
		"end_scene":
			await _end_scene(s)
		"ring":
			for k: int in int(s.get("times", 2)):
				Audio.sfx(SFX + "mobile_ring.wav", -6.0)
				await get_tree().create_timer(2.2).timeout
		"end_call":
			await _end_call(s)


func _mask_hole() -> void:
	if not ResourceLoader.exists(GLASS_HOLE) or _bg.texture == null:
		return
	var h: Image = (load(GLASS_HOLE) as Texture2D).get_image()
	if h.is_compressed():
		h.decompress()
	h.convert(Image.FORMAT_RGBA8)
	var w: int = int(h.get_width() * HOLE_SCALE)
	var hh: int = int(h.get_height() * HOLE_SCALE)
	h.resize(w, hh, Image.INTERPOLATE_NEAREST)
	var bg: Image = _bg.texture.get_image()
	if bg.is_compressed():
		bg.decompress()
	var k: Vector2 = Vector2(bg.get_width(), bg.get_height()) / Vector2(640, 360)
	var o: Vector2 = HOLE_POS - Vector2(w, hh) * 0.5
	for y: int in hh:
		for x: int in w:
			var c: Color = h.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var bx: int = int((o.x + x) * k.x)
			var by: int = int((o.y + y) * k.y)
			if bx < 0 or by < 0 or bx >= bg.get_width() or by >= bg.get_height():
				continue
			var b: Color = bg.get_pixel(bx, by)
			if b.b - b.r < 0.045:
				c.a = 0.0
				h.set_pixel(x, y, c)
	_hole.texture = ImageTexture.create_from_image(h)
	_hole.scale = Vector2.ONE


func _clear_insert_labels() -> void:
	for n: Node in _insert.get_parent().get_children():
		if n.name.begins_with("InsertLabel"):
			n.queue_free()


func _walk_alexei(to_x: float, face: String) -> void:
	var tex: Texture2D = _alexei.texture
	var frames: int = _alexei.hframes
	var pose: int = _alexei.frame
	var from_x: float = _alexei.position.x
	if ResourceLoader.exists(ALEXEI_WALK):
		_alexei.texture = load(ALEXEI_WALK)
		_alexei.hframes = 10
		_alexei.vframes = 3
	_alexei.flip_h = to_x < from_x
	var dur: float = maxf(absf(to_x - from_x) / WALK_SPEED, 0.3)
	var t: float = 0.0
	while t < dur:
		t += get_process_delta_time()
		var k: float = clampf(t / dur, 0.0, 1.0)
		_alexei.position.x = roundf(lerpf(from_x, to_x, k))
		if _alexei.texture != tex:
			_alexei.frame = 2 + int(t * 11.0) % 8
		await get_tree().process_frame
	_alexei.texture = tex
	_alexei.vframes = 1
	_alexei.hframes = frames
	_alexei.frame = pose
	_alexei.flip_h = face == "left"


func _insert_label(text: String, r: Array) -> void:
	if _insert.texture == null or not _insert.visible:
		return
	var l: Label = Label.new()
	l.text = text
	l.position = _insert.position + Vector2(float(r[0]), float(r[1])) * (_insert.size / _insert.texture.get_size())
	l.size = Vector2(float(r[2]), float(r[3])) * (_insert.size / _insert.texture.get_size())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.08, 0.14, 0.06))
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.name = "InsertLabel"
	_insert.get_parent().add_child(l)


func _end_call(s: Dictionary) -> void:
	GameState.set_flag("ivan_called", true)
	Hud.set_objective(str(s.get("objective", "")))
	_box.visible = false
	var btn: Button = Button.new()
	btn.text = str(s.get("button", "Дальше"))
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.modulate.a = 0.0
	_ui.add_child(btn)
	await get_tree().process_frame
	btn.reset_size()
	btn.position = Vector2(roundf((640.0 - btn.size.x) / 2.0), 300)
	Audio.bind_button(btn)
	create_tween().tween_property(btn, "modulate:a", 1.0, 0.4)
	btn.grab_focus()
	await btn.pressed
	btn.disabled = true
	var bt: Tween = create_tween()
	bt.tween_property(btn, "modulate:a", 0.0, 0.25)
	await get_tree().create_timer(0.8).timeout
	btn.queue_free()
	var lab: Node = _insert.get_parent().get_node_or_null("InsertLabel")
	var t: Tween = create_tween()
	t.tween_property(_insert, "modulate:a", 0.0, 1.5)
	if lab:
		t.parallel().tween_property(lab, "modulate:a", 0.0, 1.5)
	t.parallel().tween_property(_black, "color:a", 1.0, 1.5)
	await t.finished
	_insert.visible = false
	if lab:
		lab.queue_free()
	_dim.color.a = 0.0
	await get_tree().create_timer(0.6).timeout
	for th: Variant in s.get("thoughts", []):
		_thought.show_text(str(th), 0.0)
		await _advance()
	_thought.hide_box()
	await get_tree().create_timer(0.8).timeout
	GameState.set_flag("ivan_flat_slow_reveal", true)
	if is_inside_tree():
		SceneRouter.go_to(str(s.get("next", TITLE_SCENE)), 0.5)


func _show_shot(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		if _shot.visible:
			_black.color.a = 1.0
			_shot.visible = false
			await get_tree().create_timer(0.08).timeout
			_black.color.a = 0.0
		return
	_black.color.a = 1.0
	_shot.texture = load(path)
	(_shot.material as ShaderMaterial).set_shader_parameter("lamp_uv", _lamp_uv.get(path, Vector2(-1, -1)))
	_vary_rain(_shot.material as ShaderMaterial, path)
	_shot.visible = true
	await get_tree().create_timer(0.08).timeout
	_black.color.a = 0.0


func _who(id: String) -> Sprite2D:
	return _alexei if id == "alexei" else (_entity if id == "entity" else _viktor)


func _show_insert(path: String, scale: float, fill: bool = false) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	_insert.texture = tex
	if fill:
		scale = maxf(640.0 / tex.get_width(), 360.0 / tex.get_height())
	_insert.size = tex.get_size() * scale
	_insert.scale = Vector2.ONE
	_insert.stretch_mode = TextureRect.STRETCH_SCALE
	_insert.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_insert.position = ((Vector2(640, 360 if fill else 330) - _insert.size) / 2.0).floor()
	_dim.color.a = 1.0 if fill else 0.6
	_insert.modulate.a = 0.0
	_insert.visible = true
	var t: Tween = create_tween()
	t.tween_property(_insert, "modulate:a", 1.0, 0.25)
	await t.finished


func _choice(c: Dictionary) -> void:
	if c.has("options"):
		await _choice_n(c)
		return
	_choice_box = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.94)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.32, 0.36)
	sb.set_content_margin_all(8)
	_choice_box.add_theme_stylebox_override("panel", sb)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_choice_box.add_child(col)
	var title: Label = Label.new()
	title.text = str(c.get("title", ""))
	title.add_theme_color_override("font_color", Color(0.62, 0.86, 0.72))
	col.add_child(title)
	var buttons: Array[Button] = []
	for key: String in ["a", "b"]:
		var opt: Dictionary = c[key]
		var b: Button = MenuUI.button(("А. " if key == "a" else "Б. ") + str(opt["label"]))
		b.custom_minimum_size = Vector2(300, 0)
		b.pressed.connect(func() -> void: _choice_made = key)
		col.add_child(b)
		buttons.append(b)
		var hint: Label = Label.new()
		hint.text = "    " + str(opt["text"]).substr(0, 70) + "…"
		hint.add_theme_font_size_override("font_size", 8)
		hint.add_theme_color_override("font_color", Color(0.5, 0.54, 0.58))
		col.add_child(hint)
	buttons[0].focus_neighbor_bottom = buttons[0].get_path_to(buttons[1])
	buttons[1].focus_neighbor_top = buttons[1].get_path_to(buttons[0])
	_ui.add_child(_choice_box)
	await get_tree().process_frame
	_choice_box.reset_size()
	_choice_box.position = ((Vector2(640, 300) - _choice_box.size) / 2.0).floor()
	buttons[0].grab_focus()
	_choice_made = ""
	while _choice_made == "":
		if not is_inside_tree():
			return
		await get_tree().process_frame
	_choice_box.queue_free()
	var opt2: Dictionary = c[_choice_made]
	var good: bool = bool(opt2.get("good", false))
	GameState.set_flag("argument_1", good)
	GameState.set_flag("viktor_choice", _choice_made)
	await _say("alexei", str(opt2["text"]))
	if opt2.has("reply_1"):
		await _say("viktor", str(opt2["reply_1"]))
	_viktor.frame = int(opt2.get("pose", 1))
	await _say("viktor", str(opt2["reply"]))
	if good:
		GameState.add_item("confession")
	await _show_notice(str(opt2.get("notice", "")), good)


func _choice_n(c: Dictionary) -> void:
	_choice_box = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.94)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.32, 0.36)
	sb.set_content_margin_all(8)
	_choice_box.add_theme_stylebox_override("panel", sb)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_choice_box.add_child(col)
	var title: Label = Label.new()
	title.text = str(c.get("title", ""))
	title.add_theme_color_override("font_color", Color(0.62, 0.86, 0.72))
	col.add_child(title)
	var opts: Array = c["options"]
	var buttons: Array[Button] = []
	for i: int in opts.size():
		var opt: Dictionary = opts[i]
		var b: Button = MenuUI.button("%d. %s" % [i + 1, str(opt["label"])])
		b.custom_minimum_size = Vector2(420, 0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var key: String = str(i)
		b.pressed.connect(func() -> void: _choice_made = key)
		col.add_child(b)
		buttons.append(b)
	for i: int in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
	_ui.add_child(_choice_box)
	await get_tree().process_frame
	_choice_box.reset_size()
	_choice_box.position = ((Vector2(640, 300) - _choice_box.size) / 2.0).floor()
	buttons[0].grab_focus()
	_choice_made = ""
	while _choice_made == "":
		if not is_inside_tree():
			return
		await get_tree().process_frame
	_choice_box.queue_free()
	var opt2: Dictionary = opts[int(_choice_made)]
	if c.has("flag"):
		GameState.set_flag(str(c["flag"]), bool(opt2.get("good", false)))
	for st: Variant in opt2.get("steps", []):
		var sd: Dictionary = st
		if sd.has("if") and not bool(GameState.get_flag(str(sd["if"]), false)):
			continue
		await _step(sd)


func _show_notice(text: String, good: bool) -> void:
	_notice_label.text = text
	_notice_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55) if good else Color(0.85, 0.45, 0.42))
	_notice.visible = true
	_notice.reset_size()
	_notice.position = Vector2(roundf((640 - _notice.size.x) / 2.0), 120)
	_notice.modulate.a = 0.0
	Audio.sfx(SFX + "ui_click.wav", -10.0, 0.7 if good else 0.5)
	var t: Tween = create_tween()
	t.tween_property(_notice, "modulate:a", 1.0, 0.3)
	await _advance()
	var t2: Tween = create_tween()
	t2.tween_property(_notice, "modulate:a", 0.0, 0.3)
	await t2.finished
	_notice.visible = false


func _entity_arrives() -> void:
	for i: int in 4:
		_lamp_dip()
		await get_tree().create_timer(randf_range(0.18, 0.4)).timeout
	_glitch_spike = 0.8
	_black.color.a = 1.0
	_shot.visible = false
	Audio.stop_music(0.05)
	_music.stop()
	_clock.stop()
	_bg.texture = load(BG_MOON)
	(_bg.material as ShaderMaterial).set_shader_parameter("lamp_uv", Vector2(-1, -1))
	_lamp.visible = false
	_zoom_to = "wide"
	_frame.scale = Vector2.ONE
	_frame.position = Vector2.ZERO
	_viktor.flip_h = false
	await get_tree().create_timer(0.5).timeout
	_heart.play()
	_drone.play()
	_glitch.set_shader_parameter("saturation", 0.0)
	_tension = 0.3
	var t: Tween = create_tween()
	t.tween_property(_black, "color:a", 0.0, 1.2)
	await t.finished
	_entity.visible = true
	_entity.modulate.a = 0.0
	_smoke.emitting = true
	Audio.sfx(SFX + "entity_voice.wav", -4.0, 0.9)
	var t2: Tween = create_tween()
	t2.tween_property(_entity, "modulate:a", 1.0, 1.4)
	await t2.finished


func _entity_voice(text: String) -> void:
	_box.visible = false
	var layer: Control = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(layer)
	var offs: Array[Vector2] = [Vector2(-3, -1), Vector2(3, 1), Vector2(0, 0)]
	var alphas: Array[float] = [0.35, 0.35, 0.95]
	for i: int in 3:
		var l: RichTextLabel = RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size = Vector2(640, 60)
		l.position = Vector2(0, 140) + offs[i]
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.text = "[center][font_size=36][shake rate=14.0 level=%d connected=0][color=#e8e8ee]%s[/color][/shake][/font_size][/center]" % [4 + i * 3, text]
		l.modulate.a = 0.0
		layer.add_child(l)
		create_tween().tween_property(l, "modulate:a", alphas[i], 0.5)
	Audio.sfx(SFX + "entity_voice.wav", -3.0, randf_range(0.9, 1.0))
	_glitch_spike = 0.7
	_shake = 0.8
	_shake_amp = 1.0
	await get_tree().create_timer(0.6).timeout
	await _advance()
	var t: Tween = create_tween()
	t.tween_property(layer, "modulate:a", 0.0, 0.3)
	await t.finished
	layer.queue_free()


func _gunshot() -> void:
	_alexei.frame = 1
	_flash.color.a = 0.8
	Audio.sfx(SFX + "gunshot.wav", -2.0)
	var muzzle: Sprite2D = Sprite2D.new()
	muzzle.texture = _glow_tex
	muzzle.position = _alexei.position + Vector2(52, -128) * CHAR_SCALE
	muzzle.scale = Vector2(1.4, 1.0)
	muzzle.self_modulate = Color(1.0, 0.85, 0.5)
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	muzzle.material = add
	_frame.add_child(muzzle)
	_shake = 1.0
	_shake_amp = 2.0
	await get_tree().create_timer(0.05).timeout
	_flash.color.a = 0.0
	await get_tree().create_timer(0.08).timeout
	muzzle.queue_free()
	_alexei.frame = 0
	var bullet: Sprite2D = Sprite2D.new()
	bullet.texture = _tex_or_box(BULLET_TEX, Vector2i(8, 4), Color(0.8, 0.75, 0.6))
	bullet.position = Vector2(_entity.position.x - 56, _alexei.position.y - 128 * CHAR_SCALE)
	_frame.add_child(bullet)
	_set_frozen(true)
	await get_tree().create_timer(1.6).timeout
	var t: Tween = create_tween()
	t.tween_property(bullet, "position:y", _alexei.position.y - 4, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	Audio.sfx(SFX + "bullet_clink.wav", -6.0)
	_set_frozen(false)
	await get_tree().create_timer(0.6).timeout


func _set_frozen(on: bool) -> void:
	_frozen = on
	var rain: Node = _frame.get_node_or_null("Rain")
	if rain:
		rain.set_process(not on)
	_smoke.speed_scale = 0.0 if on else 1.0
	(_entity.material as ShaderMaterial).set_shader_parameter("speed", 0.0 if on else 1.0)
	_heart.volume_db = -22.0 if on else -8.0


func _psych(lines: Array) -> void:
	var sounds: Array[String] = [SFX + "glass_shatter.wav", SFX + "metal_clang.wav", SFX + "breath.wav", SFX + "bars_clang.wav"]
	var l: Label = Label.new()
	l.size = Vector2(640, 30)
	l.position = Vector2(0, 165)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(l)
	for i: int in lines.size():
		_black.color.a = 1.0
		await get_tree().create_timer(0.07).timeout
		_black.color.a = 0.0
		await get_tree().create_timer(0.07).timeout
		_black.color.a = 1.0
		l.text = "«%s»" % str(lines[i])
		Audio.sfx(sounds[i % sounds.size()], -6.0)
		_glitch_spike = 0.9
		await get_tree().create_timer(1.3).timeout
		l.text = ""
	_black.color.a = 0.0
	l.queue_free()


func _viktor_falls() -> void:
	_glitch_spike = 1.0
	_shake = 0.8
	_shake_amp = 1.5
	await get_tree().create_timer(0.7).timeout
	_black.color.a = 1.0
	_heart.stop()
	_drone.stop()
	Audio.sfx(SFX + "glass_shatter.wav", -2.0)
	await get_tree().create_timer(1.0).timeout
	_viktor.visible = false
	_entity.visible = false
	_smoke.emitting = false
	_mask_hole()
	_hole.visible = true
	_tension = 0.0
	_glitch_spike = 0.0
	_rain_on = 0.0
	_music.volume_db = -20.0
	_music.play()
	var t2: Tween = create_tween()
	t2.tween_property(_black, "color:a", 0.0, 1.2)
	t2.parallel().tween_method(func(v: float) -> void: _glitch.set_shader_parameter("saturation", v), 0.0, 0.45, 5.0)
	await t2.finished


func _notebook(s: Dictionary) -> void:
	await _show_insert(str(s["img"]), 1.0, true)
	var labels: Array[RichTextLabel] = []
	for side: String in ["left", "right"]:
		if not s.has(side):
			continue
		var l: RichTextLabel = RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var r: Array = s.get("rect_" + side, [100, 120, 200, 200])
		l.position = Vector2(float(r[0]), float(r[1]))
		l.size = Vector2(float(r[2]), float(r[3]))
		l.custom_minimum_size = Vector2(float(r[2]), 0)
		l.add_theme_color_override("default_color", Color(0.14, 0.13, 0.16))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		l.add_theme_font_size_override("normal_font_size", 8)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.text = str(s[side])
		_insert.get_parent().add_child(l)
		labels.append(l)
	await _advance()
	for l: RichTextLabel in labels:
		l.queue_free()
	_insert.visible = false
	_dim.color.a = 0.0


func _punch() -> void:
	_flash.color.a = 0.7
	_shake = 1.0
	_shake_amp = 2.5
	_glitch_spike = 0.5
	Audio.sfx(SFX + "punch.wav", -2.0)
	await get_tree().create_timer(0.06).timeout
	_flash.color.a = 0.0
	await get_tree().create_timer(0.4).timeout


func _end_scene(s: Dictionary) -> void:
	for k: Variant in (s.get("flags", {}) as Dictionary).keys():
		GameState.set_flag(str(k), s["flags"][k])
	var t: Tween = create_tween()
	t.tween_property(_black, "color:a", 1.0, float(s.get("fade", 1.2)))
	t.parallel().tween_property(_music, "volume_db", -40.0, float(s.get("fade", 1.2)))
	await t.finished
	SceneRouter.go_to(str(s.get("next", TITLE_SCENE)), 0.3)


func _end() -> void:
	GameState.set_flag("viktor_dead", true)
	GameState.set_flag("penthouse_state", "after")
	GameState.set_flag("penthouse_x", WINDOW_X / 640.0 * 7.0 - 3.5)
	var t: Tween = create_tween()
	t.tween_property(_black, "color:a", 1.0, 1.0)
	t.parallel().tween_property(_wind, "volume_db", -40.0, 1.0)
	await t.finished
	SceneRouter.go_to(BACK_SCENE, 0.3)
