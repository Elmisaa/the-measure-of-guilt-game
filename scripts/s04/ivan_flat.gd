extends Node3D

const SET_SCENE: String = "res://scenes/s04/ivan_set.tscn"
const NEAR_MARGIN: float = 0.35
const THOUGHT_TIME: float = 4.5
const CAM_SIZE: float = 4.35
const CAM_DROP: float = 0.05
const CAM_OFFSET_X: float = -1.0
const CAM_MIN_X: float = -17.3
const CAM_MAX_X: float = 9.7
const PX: float = CAM_SIZE / 360.0
const REVEAL_TIME: float = 3.5
const MUSIC: String = "res://assets/audio/music/ivan_theme.wav"
const IVAN_SHEET: String = "res://assets/characters/ivan/ivan_poses.png"
const TALK_SCENE: String = "res://scenes/s04/ivan_talk.tscn"
const TITLE_SCENE: String = "res://scenes/menu/title.tscn"
const TICK: String = "res://assets/audio/sfx/key_tick.wav"

var _d: Dictionary = {}
var _player: ExplorePlayer3D
var _cam: Camera3D
var _thought: ThoughtBox
var _prompt: Button
var _black: ColorRect
var _spots: Array = []
var _near: String = ""
var _seen: Dictionary = {}
var _busy: bool = false
var _cam_y: float = 4.5
var _cam_z: float = 28.86
var _after: bool = false


func _ready() -> void:
	_d = DialogueData.load_file("s04_ivan")
	var set_scene: Node3D = (load(SET_SCENE) as PackedScene).instantiate()
	set_scene.name = "Set"
	add_child(set_scene)
	_brighten(set_scene)
	var ref: Camera3D = set_scene.get_node_or_null("Camera3D3")
	for c: Node in set_scene.find_children("*", "Camera3D", true, false):
		(c as Camera3D).current = false
	_player = ExplorePlayer3D.new()
	_player.name = "Player"
	var b: Array = _d.get("bounds", [-19.3, 12.6])
	_player.min_x = float(b[0])
	_player.max_x = float(b[1])
	var lane: Array = _d.get("lane", [2.1, 3.0])
	_player.z_far = float(lane[0])
	_player.z_near = float(lane[1])
	add_child(_player)
	_player.position = Vector3(float(_d.get("spawn_x", -18.6)), 0.0, float(_d.get("spawn_z", 2.6)))
	var back_x: Variant = GameState.get_flag("ivan_x")
	if back_x != null:
		_player.position.x = float(back_x)
	for id: Variant in GameState.get_flag("ivan_seen", []):
		_seen[str(id)] = true
	_spots = _d.get("spots", [])
	_after = str(GameState.get_flag("ivan_state", "")) == "after"
	_place_ivan()
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = CAM_SIZE
	_cam.near = 0.05
	_cam.far = 80.0
	if ref:
		_cam.basis = ref.basis
		_cam_y = ref.position.y - CAM_DROP
		_cam_z = ref.position.z
	add_child(_cam)
	_cam.make_current()
	_build_ui()
	_update_camera()
	Audio.play_track(MUSIC, 3.0, -16.0)
	_intro()


func _intro() -> void:
	_busy = true
	_player.frozen = true
	Hud.set_hud_visible(false)
	Letterbox.hide_bars()
	var slow: bool = bool(GameState.get_flag("ivan_flat_slow_reveal", false))
	GameState.set_flag("ivan_flat_slow_reveal", false)
	var t: Tween = create_tween()
	t.tween_property(_black, "color:a", 0.0, REVEAL_TIME if slow else 0.6).set_trans(Tween.TRANS_SINE)
	if not bool(GameState.get_flag("ivan_place_shown", false)):
		GameState.set_flag("ivan_place_shown", true)
		_type_place()
	await t.finished
	if not is_inside_tree():
		return
	_busy = false
	_player.frozen = false
	Hud.set_hud_visible(true)
	Hud.show_stamina(true)
	Hud.set_walk_mode(true)
	Hud.set_objective(_objective(), true)
	if _after and not bool(GameState.get_flag("ivan_after_seen", false)):
		GameState.set_flag("ivan_after_seen", true)
		_thought.show_text(str(_d.get("ivan_after_thought", "")), THOUGHT_TIME)
	elif not bool(GameState.get_flag("ivan_entered", false)):
		GameState.set_flag("ivan_entered", true)
		_thought.show_text(str(_d.get("enter", "")), THOUGHT_TIME + 1.0)


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
	var top: CanvasLayer = CanvasLayer.new()
	top.layer = 50
	add_child(top)
	_black = ColorRect.new()
	_black.size = Vector2(640, 360)
	_black.color = Color(0, 0, 0, 1)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_black)


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
	_near = best
	_prompt.visible = best != "" and not Hud.is_blocking()
	if _prompt.visible:
		var r2: Array = best_s["x"]
		var top: Vector3 = Vector3((float(r2[0]) + float(r2[1])) / 2.0, float(best_s.get("top", 2.2)), 1.0)
		_prompt.text = "E — " + (str(_d.get("leave_label", "Уйти")) if best == "exit" and _after else str(best_s["name"]))
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
	if id == "ivan":
		if _after:
			_thought.show_text(str(_d.get("ivan_after_thought", "")), THOUGHT_TIME)
		else:
			_start_talk()
		return
	if id == "exit" and _after:
		_leave()
		return
	for s: Dictionary in _spots:
		if str(s["id"]) == id:
			_seen[id] = true
			_thought.show_text(str(s.get("thought", "")), THOUGHT_TIME)
			break
	Hud.set_objective(_objective())


func _objective() -> String:
	return str(_d.get("objective_after" if _after else "objective", ""))


func _place_ivan() -> void:
	var v: Dictionary = _d.get("ivan", {})
	if v.is_empty() or not ResourceLoader.exists(IVAN_SHEET):
		return
	var s: Sprite3D = Sprite3D.new()
	s.name = "Ivan"
	s.texture = load(IVAN_SHEET)
	s.hframes = 4
	s.frame = int(v.get("pose_after", 3)) if _after else int(v.get("pose", 0))
	s.pixel_size = _player.height_m / 190.0 * float(v.get("scale", 1.0))
	s.offset = Vector2(0, 100)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.modulate = _player.tint
	s.position = Vector3(float(v.get("x", 3.0)), 0.0, float(v.get("z", 1.6)))
	add_child(s)


func _start_talk() -> void:
	_busy = true
	_player.frozen = true
	GameState.set_flag("ivan_x", _player.position.x)
	GameState.set_flag("ivan_seen", _seen.keys())
	Hud.set_hud_visible(false)
	SceneRouter.go_to(TALK_SCENE, 0.3)


func _leave() -> void:
	_busy = true
	_player.frozen = true
	Hud.set_hud_visible(false)
	for i: int in 6:
		Audio.sfx("res://assets/audio/sfx/body_thud.wav", -24.0, randf_range(1.6, 1.9))
		await get_tree().create_timer(0.38).timeout
	Audio.sfx("res://assets/audio/sfx/door.wav", -2.0, 0.8)
	var t: Tween = create_tween()
	t.tween_property(_black, "color:a", 1.0, 0.25)
	await t.finished
	Audio.stop_music(1.5)
	await get_tree().create_timer(1.6).timeout
	var end: Label = Label.new()
	end.text = str(_d.get("end_stub", ""))
	end.size = Vector2(640, 20)
	end.position = Vector2(0, 170)
	end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	end.modulate.a = 0.0
	_black.get_parent().add_child(end)
	var e: Tween = create_tween()
	e.tween_property(end, "modulate:a", 1.0, 1.0)
	e.tween_interval(2.5)
	e.tween_property(end, "modulate:a", 0.0, 1.0)
	await e.finished
	if is_inside_tree():
		SceneRouter.go_to(TITLE_SCENE)


func save_state() -> Dictionary:
	return {"ivan_x": _player.position.x, "ivan_seen": _seen.keys(), "ivan_state": "after" if _after else ""}


func _brighten(set_scene: Node3D) -> void:
	var env: WorldEnvironment = set_scene.get_node_or_null("WorldEnvironment")
	if env and env.environment:
		env.environment = env.environment.duplicate()
		env.environment.ambient_light_energy = maxf(env.environment.ambient_light_energy, 0.2) * 1.5
		env.environment.adjustment_enabled = true
		env.environment.adjustment_brightness = 1.12
	for l: Node in set_scene.find_children("*", "Light3D", true, false):
		(l as Light3D).light_energy *= 1.15


func _type_place() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(28, 16)
	box.add_theme_constant_override("separation", 2)
	layer.add_child(box)
	var labels: Array[Label] = []
	var lines: Array = _d.get("place", [])
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
	await get_tree().create_timer(1.2).timeout
	for l: Label in labels:
		for c: int in l.text.length():
			if not is_inside_tree():
				return
			l.visible_characters = c + 1
			if l.text[c] != " ":
				Audio.sfx(TICK, -20.0, randf_range(0.9, 1.1))
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(4.0).timeout
	var f: Tween = create_tween()
	f.tween_property(box, "modulate:a", 0.0, 1.2)
	await f.finished
	layer.queue_free()
