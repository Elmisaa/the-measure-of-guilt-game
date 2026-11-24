extends Node3D

signal advanced
signal choice_selected(index: int)

const SFX: String = "res://assets/audio/sfx/"
const BANDAGED_FLAG: String = "factory_fyodor_bandaged"
const PULSE_FLAG: String = "factory_mikhail_pulse_checked"
const RECORDER_ITEM: String = "dmitry_recorder"
const CHOICE_FLAG: String = "factory_recorder_choice"
# Hand coordinates in one cell of Alexei's walk and run sprite sheets.
const WALK_HAND: Array[Vector2] = [
	Vector2(47, 115), Vector2(43, 115), Vector2(70, 107), Vector2(59, 107), Vector2(70, 105),
	Vector2(69, 101), Vector2(67, 107), Vector2(70, 105), Vector2(69, 105), Vector2(73, 100),
]
const RUN_HAND: Array[Vector2] = [
	Vector2(113, 84), Vector2(98, 112), Vector2(108, 85), Vector2(118, 61),
	Vector2(113, 110), Vector2(100, 111), Vector2(116, 86), Vector2(119, 61),
]
const PUNCTUATION: String = ".,!?…—-:;\"«»“”"

@onready var _player: ExplorePlayer3D = $Player
@onready var _camera: Camera3D = $Camera3D
@onready var _beam: SpotLight3D = $Player/WarehouseBeam
@onready var _torch: Node3D = $Player/HandTorch
@onready var _player_sprite: Sprite3D = $Player/AnimatedSprite
@onready var _ui: Control = $UI/Root
@onready var _speech: VBoxContainer = $UI/Root/Speech
@onready var _speaker: Label = $UI/Root/Speech/Speaker
@onready var _line: RichTextLabel = $UI/Root/Speech/Line
@onready var _prompt: Button = $UI/Root/InteractionPrompt
@onready var _mikhail: Sprite3D = $Mikhail
@onready var _fyodor: Sprite3D = $Fyodor
@onready var _bandage: MeshInstance3D = $Fyodor/Bandage
@onready var _lens: MeshInstance3D = $Player/HandTorch/Lens
@onready var _recorder_focus: TextureRect = $UI/Root/RecorderFocus
@onready var _recorder: Sprite3D = $Dmitry/Recorder

var _location: CanvasLayer
var _target: Sprite3D
var _interacting: bool = false
var _data: Dictionary
var _thought: ThoughtBox
var _typing: Tween
var _waiting: bool = false
var _talking: bool = false
var _noticed_factory: bool = false
var _noticed_mikhail: bool = false
var _noticed_fyodor: bool = false
var _choice: int = -1


func _ready() -> void:
	_data = DialogueData.load_file("s06_factory_present")
	_choice = int(GameState.get_flag(CHOICE_FLAG, -1))
	_noticed_factory = bool(GameState.get_flag("factory_noticed_surroundings", false))
	_noticed_mikhail = bool(GameState.get_flag("factory_noticed_mikhail", false))
	_noticed_fyodor = bool(GameState.get_flag("factory_noticed_fyodor", false))
	_player.position.x = clampf(float(GameState.get_flag("factory_player_x", _player.position.x)), _player.min_x, _player.max_x)
	_player.position.z = clampf(float(GameState.get_flag("factory_player_z", _player.position.z)), _player.z_far, _player.z_near)
	_recorder.visible = _choice < 0
	_thought = ThoughtBox.new()
	_ui.add_child(_thought)
	Letterbox.hide_bars()
	Hud.set_hud_visible(true)
	Hud.set_walk_mode(true)
	Hud.show_stamina(true)
	Hud.set_objective("Осмотрите завод" if _choice < 0 else "Место происшествия")
	$Room/Approach/EntranceLamp/EntryAmber.light_energy = 0.20
	$Room/WorldEnvironment/moonlight.light_energy = 0.08
	var world: WorldEnvironment = $Room/WorldEnvironment
	world.environment = world.environment.duplicate()
	world.environment.ambient_light_energy *= 0.45
	$Room/Props/LampFarLeft.material_override = null
	_bandage.visible = bool(GameState.get_flag(BANDAGED_FLAG, false))
	_prompt.add_theme_font_size_override("font_size", 9)
	_prompt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_prompt.pressed.connect(_interact)
	Audio.bind_button(_prompt)
	_update_hand_torch()
	_update_camera()
	_location = preload("res://scripts/ui/place_title.gd").new()
	add_child(_location)
	_location.show_lines(_data["place"], 0.35)


func _exit_tree() -> void:
	Hud.show_stamina(false)
	Hud.set_walk_mode(false)


func save_state() -> Dictionary:
	return {
		"factory_player_x": _player.position.x,
		"factory_player_z": _player.position.z,
		"factory_noticed_surroundings": _noticed_factory,
		"factory_noticed_mikhail": _noticed_mikhail,
		"factory_noticed_fyodor": _noticed_fyodor,
	}


func _process(_delta: float) -> void:
	_update_hand_torch()
	_update_camera()
	_update_interaction_prompt()
	if _talking or _interacting or Hud.is_blocking():
		return
	var x: float = _player.position.x
	if not _noticed_factory and x >= -14.7:
		_noticed_factory = true
		_thought.show_text(str(_data["surroundings"]), 4.0)
	if not _noticed_mikhail and x >= -11.1:
		_noticed_mikhail = true
		_thought.show_text(str(_data["mikhail"]), 2.7)
	if not _noticed_fyodor and x >= -7.75:
		_noticed_fyodor = true
		_thought.show_text(str(_data["fyodor"]), 2.7)
	if _choice < 0 and x >= -5.45:
		_talk_to_dmitry()


func _update_camera() -> void:
	var pixel: float = _camera.size / 360.0
	var target: float = clampf(_player.position.x + 1.15, -14.05, -6.1)
	_camera.position.x = snappedf(target, pixel)


func _update_hand_torch() -> void:
	var hands: Array[Vector2] = RUN_HAND if _player.is_running() else WALK_HAND
	var columns: int = _player_sprite.hframes
	var hand: Vector2 = hands[_player_sprite.frame % columns]
	var cell: Vector2 = _player_sprite.texture.get_size() / Vector2(columns, _player_sprite.vframes)
	var offset: Vector2 = hand - cell * 0.5
	var facing: float = -1.0 if _player_sprite.flip_h else 1.0
	_torch.position = Vector3(
		offset.x * facing * _player_sprite.pixel_size,
		(_player_sprite.offset.y - offset.y) * _player_sprite.pixel_size,
		0.065
	)
	_torch.rotation_degrees.y = 206.0 if _player_sprite.flip_h else -26.0
	_beam.position.x = 0.15 * facing
	_beam.look_at(_beam.global_position + Vector3(3.2 * facing, -0.68, -2.6))


func _update_interaction_prompt() -> void:
	_target = null
	if not _talking and not _interacting and not Hud.is_blocking():
		if not GameState.get_flag(PULSE_FLAG, false) and absf(_player.position.x - _mikhail.position.x) <= 1.2:
			_target = _mikhail
			_prompt.text = "E — Проверить пульс"
		elif not _bandage.visible and absf(_player.position.x - _fyodor.position.x) <= 1.25:
			_target = _fyodor
			_prompt.text = "E — Перевязать рану" if GameState.has_item("bandage") else "E — Осмотреть Фёдора"
	_prompt.visible = _target != null
	if _target != null:
		_prompt.reset_size()
		var height: float = 0.7 if _target == _mikhail else 1.4
		var point: Vector2 = _camera.unproject_position(_target.global_position + Vector3(0, height, 0))
		_prompt.position = (point - Vector2(_prompt.size.x * 0.5, _prompt.size.y)).round()


func _interact() -> void:
	if _target == null or _talking or _interacting or Hud.is_blocking():
		return
	var checking_pulse: bool = _target == _mikhail
	if not checking_pulse and not GameState.has_item("bandage"):
		_thought.show_text(str(_data["no_bandage"]), 3.0)
		return
	_interacting = true
	_player.frozen = true
	_prompt.hide()
	if not checking_pulse:
		GameState.remove_item("bandage")
		GameState.set_flag(BANDAGED_FLAG, true)
		if Hud.held_item == "bandage":
			Hud.set_held("")
	_thought.show_text(str(_data["pulse_check" if checking_pulse else "bandaging"]))
	await get_tree().create_timer(0.9 if checking_pulse else 1.15).timeout
	if checking_pulse:
		GameState.set_flag(PULSE_FLAG, true)
	else:
		_bandage.show()
	_thought.show_text(str(_data["pulse_result" if checking_pulse else "bandaged"]), 4.0)
	_interacting = false
	_player.frozen = false
	SaveGame.autosave()


func _talk_to_dmitry() -> void:
	_talking = true
	_player.frozen = true
	if is_instance_valid(_location):
		_location.hide()
	_thought.hide_box()
	Hud.set_hud_visible(false)

	await _say("Алексей", str(_data["alexei"]), false)
	await _say("Дмитрий", str(_data["dmitry"]), true)
	_recorder_focus.show()
	_thought.show_text(str(_data["recorder_thought"]))
	await _wait_for_advance()
	_thought.hide_box()
	_recorder_focus.hide()

	var options: Array = _data["choices"]
	_show_choices(options)
	var selected: int = await choice_selected
	var option: Dictionary = options[selected]
	await _say("Алексей", str(option["text"]), false)
	await _resolve_recorder(selected)
	await _say("Дмитрий", str(option["reply"]), true)

	_choice = selected
	GameState.set_flag(CHOICE_FLAG, selected)
	var received: bool = selected == 2
	GameState.set_flag("argument_3", received)
	_player.frozen = false
	_talking = false
	Hud.set_hud_visible(true)
	Hud.set_objective("Место происшествия")
	if received:
		GameState.add_item(RECORDER_ITEM)
	else:
		_thought.show_text("Улика не получена.", 3.0)
	SaveGame.autosave()


func _say(name_text: String, text: String, is_dmitry: bool) -> void:
	_speaker.text = name_text
	_speaker.add_theme_color_override("font_color", Color(0.72, 0.8, 0.86) if is_dmitry else Color(0.95, 0.88, 0.66))
	_speech.position = Vector2(374, 18) if is_dmitry else Vector2(16, 18)
	_speech.show()
	var pitch: float = 1.15 if is_dmitry else 1.0
	for page: String in TextPager.pages(text, 110):
		_line.text = page
		_line.visible_characters = 0
		Audio.blip(pitch)
		_typing = create_tween()
		_typing.tween_method(_type_line.bind(page, pitch), 0, page.length(), maxf(0.1, page.length() / 32.0))
		await _wait_for_advance()
	_speech.hide()


func _type_line(count: int, page: String, pitch: float) -> void:
	var previous: int = _line.visible_characters
	_line.visible_characters = count
	for index: int in range(previous, count):
		var character: String = page[index]
		if (index + 1) % 2 == 0 and not character.strip_edges().is_empty() and character not in PUNCTUATION:
			Audio.blip(pitch)


func _wait_for_advance() -> void:
	_waiting = true
	await advanced


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting:
		if _talking or _interacting or Hud.is_blocking():
			return
		if event.is_action_pressed("interact") and _target != null:
			get_viewport().set_input_as_handled()
			_interact()
		elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
			get_viewport().set_input_as_handled()
			_beam.visible = not _beam.visible
			_lens.visible = _beam.visible
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if not event.is_action_pressed("ui_accept") and not (mouse and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed):
		return
	get_viewport().set_input_as_handled()
	if _typing and _typing.is_running():
		_typing.kill()
		_line.visible_characters = -1
		return
	_waiting = false
	advanced.emit()


func _show_choices(options: Array) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "RecorderChoices"
	panel.position = Vector2(65, 0)
	panel.custom_minimum_size.x = 510
	panel.add_theme_stylebox_override("panel", MenuUI.panel_style())
	_ui.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	for index: int in options.size():
		var option: Dictionary = options[index]
		var button: Button = MenuUI.button("%d. %s" % [index + 1, option["text"]])
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(486, 48)
		button.pressed.connect(func() -> void:
			panel.hide()
			panel.queue_free()
			choice_selected.emit(index))
		column.add_child(button)
	panel.reset_size()
	panel.position.y = floorf((360.0 - panel.size.y) / 2.0)
	var first: Button = column.get_child(0) as Button
	first.grab_focus()


func _resolve_recorder(selected: int) -> void:
	if selected == 2:
		_recorder.hide()
		return
	var motion: Tween = create_tween()
	match selected:
		0:
			motion.tween_property(_recorder, "position", Vector3(0.32, 0.1, -0.1), 0.24)
		1:
			motion.tween_property(_recorder, "position", Vector3(-0.48, -0.77, 0.18), 0.19)
			motion.parallel().tween_property(_recorder, "rotation_degrees:z", -85.0, 0.19)
			await motion.finished
			Audio.sfx(SFX + "metal_clang.wav", -10.0)
			motion = create_tween()
			motion.tween_property(_recorder, "position", Vector3(0.32, 0.1, -0.1), 0.23)
	await motion.finished
	_recorder.hide()
