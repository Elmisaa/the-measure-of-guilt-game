extends Node3D

signal dialogue_advanced

const PRESENT_SCENE: String = "res://scenes/s06/factory_present.tscn"
const SFX: String = "res://assets/audio/sfx/"
const ROOM_SPRITE_TINT: Color = Color(0.78, 0.78, 0.86)
const MOON_SPRITE: Color = Color(0.55, 0.62, 0.78)
const VOICE_PUNCTUATION: String = ".,!?…—-:;\"«»“”"
const ENTITY_NOISE: float = 0.24
const VOICE_PITCH: Dictionary = {"dmitry": 1.15, "fyodor": 0.83, "mikhail": 0.94}

@onready var _camera: Camera3D = $Camera3D
@onready var _dmitry: Sprite3D = $Dmitry
@onready var _fyodor: Sprite3D = $Fyodor
@onready var _mikhail: Sprite3D = $Mikhail
@onready var _entity: Sprite3D = $Entity
@onready var _knife: Node3D = $Knife
@onready var _overhead: OmniLight3D = $Overhead
@onready var _entry_light: OmniLight3D = $Room/Approach/EntranceLamp/EntryAmber
@onready var _lit_lamp: Sprite3D = $Room/Props/LampFarLeft
@onready var _screen_effect: ShaderMaterial = $Glitch/ScreenEffect.material
@onready var _speech: VBoxContainer = $UI/Speech
@onready var _speaker: Label = $UI/Speech/Speaker
@onready var _line: RichTextLabel = $UI/Speech/Line
@onready var _black: ColorRect = $Fade/Black
@onready var _caption: Label = $Fade/Caption

var _typing: Tween
var _awaiting_dialogue: bool = false


func _ready() -> void:
	Audio.play_track("res://assets/audio/story/weight_of_guilt.wav", 1.1, -17.0)
	Hud.set_hud_visible(false)
	Letterbox.hide_bars()
	$Music.finished.connect($Music.play)
	$EntityDrone.finished.connect($EntityDrone.play)
	$Heartbeat.finished.connect($Heartbeat.play)
	for actor: Sprite3D in [_dmitry, _fyodor, _mikhail]:
		actor.modulate = ROOM_SPRITE_TINT
	_caption.visible_characters = 0
	_play()


func _play() -> void:
	var data: Dictionary = DialogueData.load_file("s05_factory_flashback")
	await _wait(0.5)
	_caption.text = str(data["caption"])
	for index: int in _caption.text.length():
		_caption.visible_characters = index + 1
		if _caption.text[index] != " " and _caption.text[index] != "\n":
			Audio.sfx(SFX + "key_tick.wav", -20.0, randf_range(0.92, 1.08))
		await _wait(0.048)
	await _wait(0.9)
	_caption.hide()
	await _fade(0.0, 0.7)

	var names: Dictionary = data["names"]
	for reply: Dictionary in data["confrontation"]:
		var who: String = str(reply["say"])
		if who == "mikhail":
			await _walk(_mikhail, -10.12, 0.52)
		await _say(who, str(names[who]), str(reply["text"]))
	await _confrontation()
	await _say("dmitry", str(names["dmitry"]), str(data["intervention"]))
	await _lights_out()
	await _say_as_entity(str(data["judgment"]))
	await _psychic_strike()
	var audio_fade: Tween = create_tween().set_parallel()
	audio_fade.tween_property($EntityDrone, "volume_db", -60.0, 0.45)
	audio_fade.tween_property($Heartbeat, "volume_db", -60.0, 0.45)
	await _fade(1.0, 0.45)
	SceneRouter.go_to(PRESENT_SCENE)


func _say(who: String, speaker_name: String, text: String) -> void:
	_speaker.text = speaker_name
	_speaker.add_theme_color_override("font_color", Color(0.72, 0.8, 0.86))
	_speech.position = Vector2(374, 18) if who == "fyodor" else Vector2(16, 18)
	_speech.show()
	var pitch: float = VOICE_PITCH[who]
	var phone_voice: bool = who == "fyodor"
	for page: String in TextPager.pages(text, 110):
		_line.text = page
		_line.visible_characters = 0
		_awaiting_dialogue = true
		_play_blip(pitch, phone_voice)
		_typing = create_tween()
		_typing.tween_method(_show_characters.bind(page, pitch, phone_voice), 0, page.length(), float(page.length()) / 32.0)
		await dialogue_advanced
	_speech.hide()


func _show_characters(count: int, page: String, pitch: float, phone_voice: bool) -> void:
	var previous: int = _line.visible_characters
	_line.visible_characters = count
	for index: int in range(previous, count):
		var character: String = page[index]
		if (index + 1) % 2 == 0 and not character.strip_edges().is_empty() and character not in VOICE_PUNCTUATION:
			_play_blip(pitch, phone_voice)


func _play_blip(pitch: float, phone_voice: bool) -> void:
	if phone_voice:
		Audio.blip_phone(pitch)
	else:
		Audio.blip(pitch)


func _say_as_entity(text: String) -> void:
	var layer: Control = preload("res://scripts/ui/entity_speech.gd").show_in($UI/EntityOverlay, text, true)
	Audio.sfx(SFX + "entity_voice.wav", -3.0, randf_range(0.9, 1.0))
	await _wait(0.6)
	_awaiting_dialogue = true
	await dialogue_advanced
	var fade: Tween = create_tween()
	fade.tween_property(layer, "modulate:a", 0.0, 0.3)
	await fade.finished
	layer.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_dialogue:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	var key: InputEventKey = event as InputEventKey
	var clicked: bool = mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	var space: bool = key != null and key.pressed and not key.echo and key.physical_keycode == KEY_SPACE
	if not (clicked or space or event.is_action_pressed("ui_accept")):
		return
	get_viewport().set_input_as_handled()
	if _typing and _typing.is_running():
		_typing.kill()
		_line.visible_characters = -1
		return
	_awaiting_dialogue = false
	dialogue_advanced.emit()


func _confrontation() -> void:
	await _wait(0.2)
	Audio.sfx(SFX + "murmur_viktor_3.wav", -9.0, 1.22)
	_knife.position = _mikhail.position + Vector3(0.47, 0.85, 0.08)
	_knife.rotation_degrees.z = -52.0
	_knife.show()
	var rush: Tween = create_tween()
	rush.tween_property(_mikhail, "position:x", -6.65, 0.33).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rush.parallel().tween_property(_knife, "position:x", -6.18, 0.33).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rush.parallel().tween_callback(func() -> void: _mikhail.frame = 3)
	rush.parallel().tween_callback(func() -> void: _dmitry.frame = 7).set_delay(0.13)
	rush.parallel().tween_property(_dmitry, "position:x", -7.25, 0.26).set_delay(0.15)
	await rush.finished
	_fyodor.frame = 1
	Audio.sfx(SFX + "punch.wav", -10.0, 0.8)
	Audio.sfx(SFX + "murmur_viktor_2.wav", -5.0, 0.8)
	await _shake_camera(0.18, 0.05)
	var shove: Tween = create_tween().set_parallel()
	shove.tween_property(_mikhail, "position:x", -9.2, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shove.tween_property(_knife, "position:x", -8.86, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dmitry.flip_h = true
	_mikhail.frame = 0
	await shove.finished
	_dmitry.frame = 0


func _lights_out() -> void:
	Audio.sfx(SFX + "tune_static.ogg", -9.0)
	_screen_effect.set_shader_parameter("intensity", 0.72)
	for level: float in [0.2, 0.9, 0.08, 0.72, 0.0]:
		_overhead.light_energy = 1.7 * level
		_entry_light.light_energy = 2.2 * level
		await _wait(0.1)
	_lit_lamp.material_override = null
	$Music.stop()
	$EntityDrone.play()
	$Heartbeat.play()
	_screen_effect.set_shader_parameter("saturation", 0.0)
	for actor: Sprite3D in [_dmitry, _fyodor, _mikhail]:
		actor.modulate = MOON_SPRITE
	_entity.show()
	Audio.sfx(SFX + "entity_voice.wav", -4.0, 0.9)
	_entity.modulate = Color(0.68, 0.74, 0.9, 0.0)
	var reveal: Tween = create_tween().set_parallel()
	reveal.tween_property(_entity, "modulate:a", 0.96, 0.55)
	reveal.tween_method(func(amount: float) -> void: _screen_effect.set_shader_parameter("intensity", amount), 0.72, ENTITY_NOISE, 0.55)
	await reveal.finished


func _psychic_strike() -> void:
	Audio.sfx(SFX + "entity_whisper.wav", -7.0)
	_screen_effect.set_shader_parameter("intensity", 0.86)
	_mikhail.frame = 7
	var drop: Tween = create_tween().set_parallel()
	drop.tween_property(_knife, "position:y", 0.025, 0.31).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(_knife, "rotation_degrees:z", -90.0, 0.31)
	await _shake_camera(0.31, 0.07)
	Audio.sfx(SFX + "metal_clang.wav", -15.0, 1.25)
	_screen_effect.set_shader_parameter("intensity", ENTITY_NOISE)
	await _wait(0.75)


func _walk(actor: Sprite3D, x: float, duration: float) -> void:
	var start: float = actor.position.x
	actor.flip_h = x < start
	var walk: Tween = create_tween()
	walk.tween_method(
		func(progress: float) -> void:
			actor.position.x = lerpf(start, x, progress)
			actor.frame = 1 + int(progress * duration * 10.0) % 6,
		0.0, 1.0, duration
	)
	await walk.finished
	actor.frame = 0


func _shake_camera(duration: float, strength: float) -> void:
	var origin: Vector3 = _camera.position
	var shake: Tween = create_tween()
	shake.tween_method(
		func(amount: float) -> void:
			_camera.position = origin + Vector3(randf_range(-amount, amount), randf_range(-amount, amount), 0),
		strength, 0.0, duration
	)
	await shake.finished
	_camera.position = origin


func _fade(alpha: float, duration: float) -> void:
	var fade: Tween = create_tween()
	fade.tween_property(_black, "color:a", alpha, duration).set_trans(Tween.TRANS_SINE)
	await fade.finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
