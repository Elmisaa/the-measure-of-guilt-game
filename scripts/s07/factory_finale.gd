extends Node3D

signal advanced

const SCENE_PATH: String = "res://scenes/s07/factory_finale.tscn"
const APPROACH_PATH: String = "res://scenes/s06/factory_present.tscn"
const SFX: String = "res://assets/audio/sfx/"
const ENTITY_SPEECH: GDScript = preload("res://scripts/ui/entity_speech.gd")
const ENTITY: Texture2D = preload("res://assets/characters/entity/entity.png")
const WALK: Texture2D = preload("res://assets/characters/alexei/walk_side_depth_coat.png")
const TALK: Texture2D = preload("res://assets/characters/alexei/alexei_talk.png")
const DRUM: Texture2D = preload("res://assets/3d/factory/final_workshop/art/02_red_drum.png")
const CONTAINER: Texture2D = preload("res://assets/3d/factory/final_workshop/art/04_freight_container.png")
const ARENA_TARGET: Vector3 = Vector3(0, 2.25, 0)
const COUNTER_HINT: String = "Выстрелите по бочке, пока она находится рядом с сущностью"

@onready var _camera: Camera3D = $Camera
@onready var _player: BossPlayer = $BossPlayer
@onready var _boss: BossScales = $BossScales
@onready var _conveyor: OverheadConveyor = $OverheadConveyor
@onready var _hud: BossHud = $BossHud
@onready var _music: AudioStreamPlayer = $BattleMusic
@onready var _pixel: ShaderMaterial = $PostFX/Pixel.material as ShaderMaterial
@onready var _speech: VBoxContainer = $UI/Root/Speech
@onready var _speaker: Label = $UI/Root/Speech/Speaker
@onready var _line: RichTextLabel = $UI/Root/Speech/Line
@onready var _entity_line: Label = $UI/Root/EntityLine
@onready var _bark: Label = $UI/Root/Bark

var _data: Dictionary
var _hero: Sprite3D
var _entity: Sprite3D
var _hum: AudioStreamPlayer
var _typing: Tween
var _waiting: bool = false
var _combat: bool = false
var _deflected: bool = false
var _countered: bool = false
var _disintegrating: bool = false
var _approaching: bool = false
var _phase: int = 0
var _clock: float = 0.0
var _bark_time: float = 0.0
var _recoil_time: float = 0.0
var _bark_queue: Array = []
var _phase_barks: Array = []
var _first_attack: bool = false
var _half_resistance: bool = false


func _ready() -> void:
	_data = DialogueData.load_file("s07_factory_finale")
	Hud.set_hud_visible(false)
	Letterbox.hide_bars()
	Audio.stop_music()
	Audio.stop_loop()
	_camera.make_current()
	for body: Node in $Workshop.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 0
	_camera.position = Vector3(-0.5, 3.05, 15)
	_camera.look_at(Vector3(-0.5, 2.0, 0))
	_build_visuals()
	_speech.position = Vector2(28, 45)
	_entity_line.hide()
	_bark.hide()
	_combat_controls(false)
	_boss.counter_window_opened.connect(_on_counter_window)
	_boss.attack_executed.connect(_on_attack)
	_boss.resistance_changed.connect(_on_resistance)
	_boss.bullet_deflected.connect(_on_deflected)
	_boss.barrel_registered.connect(_dress_barrel)
	_player.ammo_changed.connect(_on_ammo_changed)
	_player.died.connect(_on_died)
	var wind: AudioStreamWAV = _loop_wav(preload("res://assets/audio/sfx/wind_loop.wav"))
	$Wind.stream = wind
	$Wind.play()
	_music.stream = _loop_wav(_music.stream as AudioStreamWAV)
	_hum = AudioStreamPlayer.new()
	_hum.stream = preload("res://assets/audio/sfx/entity_drone.wav")
	_hum.bus = &"SFX"
	_hum.volume_db = -16.0
	add_child(_hum)
	_run.call_deferred()


func _loop_wav(source: AudioStreamWAV) -> AudioStreamWAV:
	var stream: AudioStreamWAV = source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


func _build_visuals() -> void:
	var visual: Node3D = _player.get_node("Visual")
	for part: Node in visual.get_children():
		(part as Node3D).hide()
	_hero = _sprite(TALK, visual, 2.3, 200.0)
	_hero.position.y = 0.0
	var base: Node3D = _boss.get_node("BossBase")
	base.get_node("Visual").hide()
	_entity = _sprite(ENTITY, base, 4.2)
	_entity.position.y = 2.13
	_entity.modulate = Color(0.83, 0.86, 0.92, 0.0)
	_conveyor.get_node("Rail").hide()
	for container: Node in _conveyor.find_children("Container", "MeshInstance3D", true, false):
		(container as MeshInstance3D).mesh = null
		_sprite(CONTAINER, container, 1.15)


func _sprite(texture: Texture2D, parent: Node, height: float, cell_height: float = 0.0) -> Sprite3D:
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = height / (cell_height if cell_height > 0.0 else float(texture.get_height()))
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite


func _dress_barrel(barrel: ExplosiveBarrel) -> void:
	var body: MeshInstance3D = barrel.get_node("Body")
	body.mesh = null
	_sprite(DRUM, body, 0.92)
	body.position.y = 0.0
	barrel.get_node("CollisionShape3D").position.y = 0.0
	var ring: MeshInstance3D = barrel.get_node("TargetRing")
	ring.position.y = 0.0
	ring.hide()


func _process(delta: float) -> void:
	_clock += delta
	_recoil_time = maxf(0.0, _recoil_time - delta)
	var moving: bool = Vector2(_player.velocity.x, _player.velocity.z).length_squared() > 0.1
	if moving or _approaching:
		_hero.texture = WALK
		_hero.hframes = 10
		_hero.vframes = 3
		var row: int = 0
		if absf(_player.velocity.z) > absf(_player.velocity.x):
			row = 1 if _player.velocity.z > 0.0 else 2
		_hero.frame = row * 10 + 2 + int(_clock * (19.0 if _player.is_dashing else 12.0)) % 8
	else:
		_hero.texture = TALK
		_hero.vframes = 1
		_hero.hframes = 4
		_hero.frame = (1 if _recoil_time > 0.0 else 0) if _combat else 2
	_hero.position.y = 1.15
	if not _disintegrating:
		_entity.position.y = 2.13 + sin(_clock * 1.6) * 0.13
	if not _combat:
		return
	_bark_time -= delta
	if _bark_time > 0.0:
		return
	if _bark_queue.is_empty():
		_bark.hide()
		return
	var entry: Array = _bark_queue.pop_front()
	var is_entity: bool = entry[0] == "Весы"
	_bark.text = "%s\n%s" % entry
	_bark.modulate = Color(1.0, 0.83, 0.77) if is_entity else Color(1.0, 0.94, 0.8)
	_bark.show()
	_voice(is_entity, -15.0)
	_bark_time = clampf(str(entry[1]).length() / 22.0, 1.4, 3.6)


func _run() -> void:
	await get_tree().create_timer(0.45).timeout
	_hum.play()
	Audio.sfx(SFX + "entity_voice.wav", -4.0, 0.88)
	_pixel.set_shader_parameter("intensity", 0.45)
	_pixel.set_shader_parameter("saturation", 0.35)
	await create_tween().tween_property(_entity, "modulate:a", 1.0, 0.8).finished
	await _dialogue(_data["intro"])
	var camera_motion: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	var camera_position: Vector3 = ARENA_TARGET + Vector3(0, sin(deg_to_rad(27.0)), cos(deg_to_rad(27.0))) * 15.8
	camera_motion.tween_method(_place_camera, _camera.position, camera_position, 0.9)
	await camera_motion.finished
	await _run_phase(1, [])
	for index: int in _data["stages"].size():
		var stage: Dictionary = _data["stages"][index]
		await _dialogue(stage["common"])
		if _has_argument(stage):
			await _dialogue(stage["evidence"])
		else:
			await _dialogue(stage["missing"])
			await _run_phase(index + 2, stage["barks"])
			await _dialogue(stage["earned"])
		GameState.set_flag("factory_final_" + str(stage["flag"]), true)
		await _destabilize()
	_approaching = true
	_player.get_node("Visual").scale.x = 1.0
	var approach: Tween = create_tween()
	approach.tween_property(_player, "position", Vector3(1.5, 0, 0.45), 1.8)
	approach.parallel().tween_method(_place_camera, _camera.position, Vector3(2.3, 6.0, 10.0), 1.8)
	await approach.finished
	_approaching = false
	await _dialogue(_data["climax"])
	await _dissolve()
	GameState.set_flag("factory_finale_return", true)
	SceneRouter.go_to(APPROACH_PATH, 0.3)


func _place_camera(at: Vector3) -> void:
	_camera.position = at
	_camera.look_at(ARENA_TARGET)


func _has_argument(stage: Dictionary) -> bool:
	return bool(GameState.get_flag(str(stage["flag"]), false)) or GameState.has_item(str(stage["item"]))


func _run_phase(phase: int, lines: Array) -> void:
	_phase = phase
	_phase_barks = lines
	_first_attack = false
	_half_resistance = false
	_bark_time = 0.0
	if not lines.is_empty():
		_bark_queue.append(lines[0])
	_combat_controls(true)
	if not _music.playing:
		_music.play()
	create_tween().tween_property(_music, "volume_db", -17.0 + float(phase) * 2.0, 0.5)
	_boss.start_story_phase(phase)
	await _boss.phase_broken
	_combat_controls(false)
	for node: Node in get_children():
		if node is BossBullet:
			node.queue_free()
	create_tween().tween_property(_music, "volume_db", -30.0, 0.7)
	await _destabilize()


func _combat_controls(enabled: bool) -> void:
	_combat = enabled
	_player.controls_locked = not enabled
	_player.get_node("AimMarker").visible = enabled
	_conveyor.set_physics_process(enabled)
	_hud.visible = enabled
	_pixel.set_shader_parameter("intensity", 0.12 if enabled else 0.27)
	_pixel.set_shader_parameter("saturation", 0.86 if enabled else 0.66)
	if not enabled:
		_conveyor.cancel_drops()
		_bark_queue.clear()
		_bark.hide()
		_hud.set_hint()


func _on_attack(_current_phase: int, attack: int) -> void:
	if not _phase_barks.is_empty() and not _first_attack:
		_first_attack = true
		_bark_queue.append_array(_phase_barks.slice(1, 3))
	if attack == 0:
		create_tween().tween_property(_entity, "rotation:z", -0.09, 0.18).set_trans(Tween.TRANS_SINE)
		create_tween().tween_property(_entity, "rotation:z", 0.0, 0.22).set_delay(0.5)


func _on_counter_window() -> void:
	_hud.set_hint(COUNTER_HINT)
	await get_tree().create_timer(2.2).timeout
	if _combat:
		_hud.set_hint()


func _on_resistance(current: int, maximum: int) -> void:
	if current == maximum or current <= 0:
		return
	if _phase == 1 and _boss.story_counter_succeeded and not _countered:
		_countered = true
		_bark_queue.append_array(_data["counter"])
	if not _phase_barks.is_empty() and not _half_resistance and current <= maximum / 2.0:
		_half_resistance = true
		_bark_queue.append_array(_phase_barks.slice(3))


func _on_deflected(_position: Vector3) -> void:
	if not _combat:
		return
	var flash: Tween = create_tween()
	flash.tween_property(_entity, "modulate", Color(1.4, 1.5, 1.7), 0.06)
	flash.tween_property(_entity, "modulate", Color(0.83, 0.86, 0.92), 0.14)
	if not _deflected:
		_deflected = true
		_bark_queue.append_array(_data["deflection"])


func _on_ammo_changed(current: int, _maximum: int) -> void:
	if _combat and not _player.is_reloading and current < _player.ammo_max:
		_recoil_time = 0.16
		Audio.sfx(SFX + "gunshot.wav", -9.0, randf_range(0.93, 1.05))


func _on_died() -> void:
	_boss.stop_story_phase()
	_combat_controls(false)
	_music.stop()
	_entity_line.text = "АЛЕКСЕЙ ПОГИБ"
	_entity_line.show()
	var retry: Button = MenuUI.button("Повторить бой")
	retry.position = Vector2(235, 306)
	retry.custom_minimum_size.x = 170
	$UI/Root.add_child(retry)
	retry.pressed.connect(func() -> void: SceneRouter.go_to(SCENE_PATH))
	retry.grab_focus()


func _dialogue(entries: Array) -> void:
	for entry: Array in entries:
		if entry.size() > 2:
			await get_tree().create_timer(float(entry[2])).timeout
		var is_entity: bool = entry[0] == "Весы"
		var text: String = str(entry[1])
		Hud.log_say(str(entry[0]), text)
		_speech.visible = not is_entity
		if is_entity:
			for page: String in TextPager.pages(text, 78):
				var overlay: Control = ENTITY_SPEECH.show_in($UI/Root, page, true)
				_voice(true)
				_typing = null
				_waiting = true
				await advanced
				overlay.queue_free()
			continue
		_speaker.text = str(entry[0])
		_speaker.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66))
		for page: String in TextPager.pages(text, 125):
			_line.text = page
			_line.visible_characters = 0
			_voice(false)
			_typing = create_tween()
			_typing.tween_method(_type_line.bind(page), 0, page.length(), maxf(0.14, page.length() / 39.0))
			_waiting = true
			await advanced
	_speech.hide()


func _type_line(count: int, page: String) -> void:
	var previous: int = _line.visible_characters
	_line.visible_characters = count
	for index: int in range(previous, count):
		if index % 2 == 0 and not page[index].strip_edges().is_empty() and page[index] not in ".,!?…—«»":
			Audio.blip()


func _voice(is_entity: bool, db: float = -7.0) -> void:
	if is_entity:
		Audio.sfx(SFX + "entity_voice.wav", db, randf_range(0.87, 0.99))
	else:
		Audio.blip()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Hud.open_pause()
		return
	if not _waiting:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if not event.is_action_pressed("ui_accept") and not (click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	if _typing and _typing.is_running():
		_typing.kill()
		_line.visible_characters = -1
		return
	_waiting = false
	advanced.emit()


func _destabilize() -> void:
	_pixel.set_shader_parameter("intensity", 0.67)
	Audio.sfx(SFX + "entity_drone.wav", -17.0, 0.8)
	var tremor: Tween = create_tween()
	tremor.tween_property(_entity, "rotation:z", 0.075, 0.11)
	tremor.tween_property(_entity, "rotation:z", -0.093, 0.13)
	tremor.tween_property(_entity, "rotation:z", 0.0, 0.4)
	await tremor.finished
	_pixel.set_shader_parameter("intensity", 0.24)


func _dissolve() -> void:
	_disintegrating = true
	_music.stop()
	$Rain.play()
	await get_tree().create_timer(2.0).timeout
	_hum.pitch_scale = 0.65
	_hum.play()
	_pixel.set_shader_parameter("saturation", 0.2)
	await get_tree().create_timer(3.0).timeout
	var dissolve: Tween = create_tween()
	for pulse: int in range(8):
		dissolve.tween_property(_entity, "modulate:a", 0.12, 0.11)
		dissolve.tween_property(_entity, "modulate:a", 0.95 - 0.08 * pulse, 0.25)
	_pixel.set_shader_parameter("intensity", 0.62)
	await dissolve.finished
	_ash()
	await create_tween().tween_property(_entity, "modulate:a", 0.0, 1.5).finished
	_hum.stop()
	_pixel.set_shader_parameter("saturation", 1.0)
	_pixel.set_shader_parameter("intensity", 0.0)
	await get_tree().create_timer(3.6).timeout


func _ash() -> void:
	var ash: CPUParticles3D = CPUParticles3D.new()
	ash.amount = 120
	ash.lifetime = 4.0
	ash.one_shot = true
	ash.explosiveness = 0.55
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(0.62, 1.4, 0.18)
	ash.direction = Vector3(1.0, 0.23, 0.0)
	ash.spread = 28.0
	ash.initial_velocity_min = 0.22
	ash.initial_velocity_max = 1.5
	ash.gravity = Vector3(0.45, -0.2, 0.0)
	ash.scale_amount_min = 0.25
	ash.scale_amount_max = 1.1
	var grain: BoxMesh = BoxMesh.new()
	grain.size = Vector3.ONE * 0.055
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grain.material = material
	ash.mesh = grain
	var colors: Gradient = Gradient.new()
	colors.set_color(0, Color(0.1, 0.09, 0.12))
	colors.set_color(1, Color(0.47, 0.48, 0.5, 0.0))
	ash.color_ramp = colors
	add_child(ash)
	ash.global_position = _entity.global_position
	ash.emitting = true
