extends Node3D

const SET_SCENE: String = "res://scenes/s04/ivan_set.tscn"
const NEAR_MARGIN: float = 0.35
const THOUGHT_TIME: float = 4.5
const CAM_SIZE: float = 5.6
const CAM_OFFSET_X: float = -1.0
const CAM_MIN_X: float = -17.3
const CAM_MAX_X: float = 9.7
const PX: float = CAM_SIZE / 360.0
const REVEAL_TIME: float = 3.5
const MUSIC: String = "res://assets/audio/music/ivan_theme.wav"
const IVAN_SHEET: String = "res://assets/characters/ivan/full_poses.png"
const TALK_SCENE: String = "res://scenes/s04/ivan_talk.tscn"
const FLASHBACK_SCENE: String = "res://scenes/s05/factory_flashback.tscn"
const WALK_COLLISION_LAYER: int = 2

var _d: Dictionary = {}
var _player: ExplorePlayer3D
var _cam: Camera3D
var _thought: ThoughtBox
var _prompt: Button
var _leave_button: Button
var _black: ColorRect
var _spots: Array = []
var _near: String = ""
var _seen: Dictionary = {}
var _busy: bool = false
var _cam_y: float = 7.1
var _cam_z: float = 20.0
var _after: bool = false


func _ready() -> void:
	_d = DialogueData.load_file("s04_ivan")
	var set_scene: Node3D = (load(SET_SCENE) as PackedScene).instantiate()
	set_scene.name = "Set"
	add_child(set_scene)
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
	_player.collision_mask = WALK_COLLISION_LAYER
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.1
	var body: CollisionShape3D = CollisionShape3D.new()
	body.shape = capsule
	body.position.y = capsule.height * 0.5
	_player.add_child(body)
	add_child(_player)
	_player.position = Vector3(float(_d.get("spawn_x", -18.6)), 0.0, float(_d.get("spawn_z", 2.6)))
	var back_x: Variant = GameState.get_flag("ivan_x")
	if back_x != null:
		_player.position.x = clampf(float(back_x), _player.min_x, _player.max_x)
		_player.position.z = clampf(float(GameState.get_flag("ivan_z", _player.position.z)), _player.z_far, _player.z_near)
		_restore_safe_position()
	for id: Variant in GameState.get_flag("ivan_seen", []):
		_seen[str(id)] = true
	_spots = _d.get("spots", [])
	_after = str(GameState.get_flag("ivan_state", "")) == "after"
	_place_ivan()
	_player.get_node("AnimatedSprite").layers = 2
	var character_fill: DirectionalLight3D = DirectionalLight3D.new()
	character_fill.name = "CharacterFill"
	character_fill.rotation_degrees = Vector3(-25, -15, 0)
	character_fill.light_color = Color("#859cc7")
	character_fill.light_energy = 0.35
	character_fill.light_cull_mask = 2
	add_child(character_fill)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = CAM_SIZE
	_cam.near = 0.05
	_cam.far = 75.0
	_cam.rotation.x = -0.28
	add_child(_cam)
	_cam.make_current()
	_build_ui()
	_update_camera()
	Audio.play_track(MUSIC, 3.0, -16.0)
	_intro()


func _restore_safe_position() -> void:
	await get_tree().physics_frame
	var pose: Transform3D = _player.global_transform
	if not _player.test_move(pose, Vector3.ZERO, null, _player.safe_margin, true):
		return
	for depth: float in [_player.z_near, _player.z_far]:
		pose.origin.z = depth
		if not _player.test_move(pose, Vector3.ZERO, null, _player.safe_margin, true):
			_player.global_position = pose.origin
			return
	_player.position = Vector3(float(_d.get("spawn_x", -18.6)), 0.0, float(_d.get("spawn_z", 2.6)))


func _intro() -> void:
	_busy = true
	_player.frozen = true
	Hud.set_hud_visible(false)
	Letterbox.hide_bars()
	if _after:
		_leave_button.show()
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
	_leave_button = Button.new()
	_leave_button.name = "LeaveButton"
	_leave_button.text = str(_d.get("factory_button", "Отправиться на завод"))
	_leave_button.position = Vector2(232, 290)
	_leave_button.size = Vector2(176, 28)
	_leave_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_leave_button.hide()
	_leave_button.pressed.connect(_go_to_factory)
	Audio.bind_button(_leave_button)
	root.add_child(_leave_button)
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
		_prompt.text = Settings.key_label("interact") + " — " + (str(_d.get("leave_label", "Уйти")) if best == "exit" and _after else str(best_s["name"]))
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
		_go_to_factory()
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
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.shaded = true
	s.layers = 2
	s.modulate = _player.tint
	s.position = Vector3(float(v.get("x", 3.0)), 0.0, float(v.get("z", 1.6)))
	add_child(s)


func _start_talk() -> void:
	_busy = true
	_player.frozen = true
	GameState.set_flag("ivan_x", _player.position.x)
	GameState.set_flag("ivan_z", _player.position.z)
	GameState.set_flag("ivan_seen", _seen.keys())
	Hud.set_hud_visible(false)
	SceneRouter.go_to(TALK_SCENE, 0.3)


func _go_to_factory() -> void:
	if _leave_button.disabled or Hud.is_blocking():
		return
	_busy = true
	_player.frozen = true
	Hud.set_hud_visible(false)
	_leave_button.disabled = true
	Audio.sfx("res://assets/audio/sfx/door.wav", -4.0, 0.9)
	Audio.stop_music(0.6)
	SceneRouter.go_to(FLASHBACK_SCENE, 0.15)


func save_state() -> Dictionary:
	return {"ivan_x": _player.position.x, "ivan_z": _player.position.z, "ivan_seen": _seen.keys(), "ivan_state": "after" if _after else ""}


func _type_place() -> void:
	var title: CanvasLayer = preload("res://scripts/ui/place_title.gd").new()
	add_child(title)
	title.show_lines(_d.get("place", []))
