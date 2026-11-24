extends Node3D

const NEAR_MARGIN: float = 0.35
const BARS_HOLD: float = 1.6
const BARS_TIME: float = 1.0
const THOUGHT_TIME: float = 4.5
const CAM_SIZE: float = 4.35
const CAM_DROP: float = 0.05
const CAM_OFFSET_X: float = -1.0
const CAM_MIN_X: float = -17.3
const CAM_MAX_X: float = 1.2
const PX: float = CAM_SIZE / 360.0
const VIKTOR_SHEET: String = "res://assets/characters/viktor/viktor_poses.png"
const TALK_SCENE: String = "res://scenes/s03/viktor_talk.tscn"
const CALL_SCENE: String = "res://scenes/s03/ivan_call.tscn"
const GLASS_HOLE: String = "res://assets/props/s03/glass_hole.png"
const WIND: String = "res://assets/audio/sfx/wind_loop.wav"
const RING: String = "res://assets/audio/sfx/mobile_ring.wav"
const MUSIC: String = "res://assets/audio/music/penthouse_theme.wav"
const AMBIENCE: String = "res://assets/audio/music/877124__adamdavidsmith__ambience_rain_thunder-2.ogg"

var _d: Dictionary = {}
var _player: ExplorePlayer3D
var _cam: Camera3D
var _thought: ThoughtBox
var _prompt: Button
var _spots: Array = []
var _near: String = ""
var _seen: Dictionary = {}
var _busy: bool = false
var _cam_y: float = 4.5
var _cam_z: float = 28.86
var _after: bool = false
var _ringing: bool = false
var _viktor: Sprite3D
var _wind: AudioStreamPlayer


func _ready() -> void:
	_d = DialogueData.load_file("s03_penthouse")
	var set_scene: Node3D = (load("res://scenes/s03/penthouse_set.tscn") as PackedScene).instantiate()
	set_scene.name = "Set"
	add_child(set_scene)
	for c: Node in set_scene.find_children("*", "Camera3D", true, false):
		(c as Camera3D).current = false
	_player = ExplorePlayer3D.new()
	_player.name = "Player"
	var b: Array = _d.get("bounds", [-19.6, 5.5])
	_player.min_x = float(b[0])
	_player.max_x = float(b[1])
	var lane: Array = _d.get("lane", [0.0, 1.0])
	_player.z_far = float(lane[0])
	_player.z_near = float(lane[1])
	add_child(_player)
	_player.position = Vector3(float(_d.get("spawn_x", -19.0)), 0.0, float(_d.get("spawn_z", 0.6)))
	var back_x: Variant = GameState.get_flag("penthouse_x")
	if back_x != null:
		_player.position.x = float(back_x)
		_player.position.z = float(GameState.get_flag("penthouse_z", _player.position.z))
	for id: Variant in GameState.get_flag("penthouse_seen", []):
		_seen[str(id)] = true
	_after = str(GameState.get_flag("penthouse_state", "")) == "after"
	_spots = _d.get("spots_after" if _after else "spots", [])
	if not _after:
		_place_viktor()
		_place_props()
	else:
		_go_dark(set_scene)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = CAM_SIZE
	_cam.near = 0.05
	_cam.far = 80.0
	var set_cam: Camera3D = set_scene.get_node_or_null("Camera3D")
	if set_cam:
		_cam.basis = set_cam.basis
		_cam_y = set_cam.position.y - CAM_DROP
		_cam_z = set_cam.position.z
	add_child(_cam)
	_cam.make_current()
	_build_ui()
	_update_camera()
	if _after:
		Audio.play_track(MUSIC, 2.0, -20.0)
		_after_intro()
	else:
		Audio.play_track(MUSIC, 2.0, -12.0)
		_intro()


func _intro() -> void:
	_busy = true
	_player.frozen = true
	Hud.set_hud_visible(false)
	Letterbox.show_bars()
	await get_tree().create_timer(BARS_HOLD).timeout
	if not is_inside_tree():
		return
	await Letterbox.retract(BARS_TIME)
	if not is_inside_tree():
		return
	_busy = false
	_player.frozen = false
	Hud.set_hud_visible(true)
	Hud.show_stamina(true)
	Hud.set_walk_mode(true)
	Hud.set_objective(_objective(), true)
	if not bool(GameState.get_flag("penthouse_entered", false)):
		GameState.set_flag("penthouse_entered", true)
		_thought.show_text(str(_d.get("enter", "")), THOUGHT_TIME + 1.0)


func _after_intro() -> void:
	Letterbox.hide_bars()
	Hud.set_hud_visible(true)
	Hud.show_stamina(true)
	Hud.set_walk_mode(true)
	Hud.set_objective(_objective(), true)
	_thought.show_text(str(_d.get("after_enter", "")), THOUGHT_TIME)


func _exit_tree() -> void:
	Hud.show_stamina(false)
	Hud.set_walk_mode(false)


func _build_ui() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	add_child(ui)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	_prompt = Button.new()
	_prompt.flat = true
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.85))
	_prompt.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.6))
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st: String in ["normal", "hover", "pressed", "focus"]:
		_prompt.add_theme_stylebox_override(st, empty)
	_prompt.visible = false
	_prompt.pressed.connect(func() -> void: _interact(_near))
	root.add_child(_prompt)
	_thought = ThoughtBox.new()
	root.add_child(_thought)


func _process(_delta: float) -> void:
	_update_camera()
	_update_near()


func _update_camera() -> void:
	var cx: float = clampf(_player.position.x + CAM_OFFSET_X, CAM_MIN_X, CAM_MAX_X)
	_cam.position = Vector3(roundf(cx / PX) * PX, _cam_y, _cam_z)


func _update_near() -> void:
	var px: float = _player.position.x
	var best: String = ""
	var best_d: float = INF
	var best_s: Dictionary = {}
	if not _busy:
		for s: Dictionary in _spots:
			var r: Array = s["x"]
			if px >= float(r[0]) - NEAR_MARGIN and px <= float(r[1]) + NEAR_MARGIN:
				var d: float = absf(px - (float(r[0]) + float(r[1])) / 2.0)
				if d < best_d:
					best_d = d
					best = str(s["id"])
					best_s = s
	if _ringing and not _busy:
		best = "answer"
		best_s = {"name": str(_d.get("answer_label", "Ответить")), "x": [_player.position.x, _player.position.x], "top": 2.7}
	_near = best
	_prompt.visible = best != "" and not Hud.is_blocking()
	if _prompt.visible:
		var r2: Array = best_s["x"]
		var top: Vector3 = Vector3((float(r2[0]) + float(r2[1])) / 2.0, float(best_s.get("top", 1.6)), -0.6)
		_prompt.text = "E — " + str(best_s["name"])
		_prompt.reset_size()
		var p: Vector2 = _cam.unproject_position(top)
		_prompt.position = Vector2(clampf(roundf(p.x - _prompt.size.x / 2.0), 4.0, 636.0 - _prompt.size.x), clampf(roundf(p.y - 14.0), 46.0, 300.0))


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _near == "" or Hud.is_blocking():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_interact(_near)


func _interact(id: String) -> void:
	if id == "" or _busy:
		return
	if id == "answer":
		_answer()
		return
	if id == "viktor":
		if _clues_seen():
			_start_talk()
		else:
			_thought.show_text(str(_d.get("need_clues", "")), THOUGHT_TIME)
		return
	if id == "window":
		_at_window()
		return
	for s: Dictionary in _spots:
		if str(s["id"]) == id:
			_seen[id] = true
			if str(s.get("kind", "")) == "closeup":
				var cu: String = str(s["closeup"]) if ResourceLoader.exists(str(s["closeup"])) else ""
				Hud.open_closeup({"closeup": cu, "text": "" if cu != "" else str(s["texts"][0]["text"]), "texts": s.get("texts", []), "reaction": str(s.get("reaction", ""))})
			else:
				_thought.show_text(str(s.get("thought", "")), THOUGHT_TIME)
			break
	Hud.set_objective(_objective())


func _clues_seen() -> bool:
	for c: Variant in _d.get("clues", []):
		if not _seen.has(str(c)):
			return false
	return true


func _objective() -> String:
	if _ringing:
		return str(_d.get("objective_ring", ""))
	if _after:
		return str(_d.get("objective_after", ""))
	return str(_d.get("objective_talk" if _clues_seen() else "objective", ""))


func _start_talk() -> void:
	_busy = true
	_player.frozen = true
	GameState.set_flag("penthouse_x", _player.position.x)
	GameState.set_flag("penthouse_seen", _seen.keys())
	Hud.set_hud_visible(false)
	SceneRouter.go_to(TALK_SCENE, 0.3)


func _at_window() -> void:
	if bool(GameState.get_flag("window_done", false)):
		return
	GameState.set_flag("window_done", true)
	_busy = true
	var vd: String = str(_d.get("view_down", ""))
	if ResourceLoader.exists(vd):
		Hud.open_closeup({"closeup": vd, "reaction": str(_d.get("window_b", ""))})
		while Hud.is_closeup_open() and is_inside_tree():
			await get_tree().process_frame
	else:
		_thought.show_text(str(_d.get("window_b", "")), THOUGHT_TIME)
		await get_tree().create_timer(THOUGHT_TIME).timeout
	if not is_inside_tree():
		return
	if not bool(GameState.get_flag("argument_1", false)) and not GameState.owns_item("confession"):
		_thought.show_text(str(_d.get("envelope_pick", "")), THOUGHT_TIME)
		GameState.add_item("confession")
		await get_tree().create_timer(THOUGHT_TIME).timeout
		var fin: String = str(DialogueData.load_file("s03_viktor").get("final_thought", ""))
		_thought.show_text(fin, 0.0)
		await get_tree().create_timer(7.0).timeout
	if not is_inside_tree():
		return
	_thought.hide_box()
	_busy = false
	_ring()


func _ring() -> void:
	_ringing = true
	Hud.set_objective(_objective(), true)
	while _ringing and is_inside_tree():
		Audio.sfx(RING, -6.0)
		await get_tree().create_timer(2.4).timeout


func _answer() -> void:
	_ringing = false
	_busy = true
	_player.frozen = true
	Hud.set_hud_visible(false)
	SceneRouter.go_to(CALL_SCENE, 0.4)


func _place_props() -> void:
	for pr: Dictionary in _d.get("props", []):
		var path: String = str(pr["tex"])
		if not ResourceLoader.exists(path):
			continue
		var s: Sprite3D = Sprite3D.new()
		s.texture = load(path)
		s.pixel_size = float(pr.get("w", 0.5)) / float(s.texture.get_width())
		s.centered = true
		s.offset = Vector2(0, s.texture.get_height() / 2.0)
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = false
		s.modulate = _player.tint
		s.position = Vector3(float(pr["x"]), 0.0, float(pr["z"]))
		add_child(s)


func _go_dark(set_scene: Node3D) -> void:
	for l: Node in set_scene.find_children("*", "Light3D", true, false):
		(l as Light3D).visible = false
	var env: WorldEnvironment = set_scene.get_node_or_null("WorldEnvironment")
	if env and env.environment:
		env.environment = env.environment.duplicate()
		env.environment.ambient_light_energy = 0.4
		env.environment.ambient_light_color = Color(0.35, 0.42, 0.6)
		env.environment.adjustment_enabled = true
		env.environment.adjustment_saturation = 0.35
	for g: Node in set_scene.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = g
		for i: int in mi.get_surface_override_material_count():
			var m: Material = mi.get_active_material(i)
			if m is StandardMaterial3D and ((m as StandardMaterial3D).emission_enabled or (m as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED):
				var dm: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
				dm.emission_enabled = false
				dm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				dm.albedo_color = dm.albedo_color.darkened(0.7)
				mi.set_surface_override_material(i, dm)
	for shade: Node in set_scene.find_children("*Lampshade*", "", true, false):
		for g2: Node in shade.find_children("*", "MeshInstance3D", true, false) + ([shade] if shade is MeshInstance3D else []):
			var mi2: MeshInstance3D = g2
			for i2: int in mi2.get_surface_override_material_count():
				var m2: Material = mi2.get_active_material(i2)
				if m2 is StandardMaterial3D:
					var d2: StandardMaterial3D = (m2 as StandardMaterial3D).duplicate()
					d2.emission_enabled = false
					d2.albedo_color = Color(0.12, 0.11, 0.1)
					mi2.set_surface_override_material(i2, d2)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 0.95)
	moon.light_energy = 0.3
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-30, 180, 0)
	add_child(moon)
	if ResourceLoader.exists(GLASS_HOLE):
		var h: Sprite3D = Sprite3D.new()
		h.texture = load(GLASS_HOLE)
		h.pixel_size = 2.0 / float(h.texture.get_width())
		h.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		h.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		h.shaded = false
		h.position = Vector3(1.9, 1.7, -2.2)
		add_child(h)



func save_state() -> Dictionary:
	return {"penthouse_x": _player.position.x, "penthouse_z": _player.position.z, "penthouse_seen": _seen.keys(), "penthouse_state": "after" if _after else ""}


func _place_viktor() -> void:
	var v: Dictionary = _d.get("viktor", {})
	if v.is_empty():
		return
	var s: Sprite3D = Sprite3D.new()
	_viktor = s
	s.name = "Viktor"
	s.texture = load(VIKTOR_SHEET)
	s.hframes = 7
	s.frame = int(v.get("pose", 0))
	s.pixel_size = _player.height_m / 190.0
	s.offset = Vector2(0, 100)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.modulate = _player.tint
	s.position = Vector3(float(v.get("x", -3.0)), 0.0, float(v.get("z", -1.95)))
	add_child(s)
