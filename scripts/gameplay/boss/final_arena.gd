extends Node3D

const SFX: String = "res://assets/audio/story/"
const RAIN: String = "res://assets/audio/music/877124__adamdavidsmith__ambience_rain_thunder-2.ogg"
const TITLE: String = "res://scenes/menu/title.tscn"
const ARGUMENTS: Array[Dictionary] = [
	{
		"item": "confession",
		"name": "Право на искупление",
		"proof": "Виктор признался. Семь лет он помогал семье Глебова. Ты убила его, а Глебов так и остался в камере. Кому помог твой приговор?",
		"fallback": "Глебов до сих пор в камере. Ещё одна смерть этого не исправит.",
	},
	{
		"item": "journal",
		"name": "Закон без исключений",
		"proof": "В журнале Ивана записаны твои приговоры. Ты не делала исключений. Кто тогда вправе судить тебя?",
		"fallback": "Кто проверяет твои приговоры? Где их можно оспорить? Ты одна решаешь, кого наказать.",
	},
	{
		"item": "dmitry_recorder",
		"name": "Цикл страданий",
		"proof": "На записи Дмитрия слышно, как Михаил требует признания. Он хотел освободить брата. После твоего приговора его семья потеряла ещё одного человека.",
		"fallback": "Посмотри на Михаила. Ты хотела прекратить боль, а теперь ещё одна семья будет оплакивать близкого.",
	},
]
const PHASE_PATTERNS: Array[Array] = [[0, 1, 2, 3], [0, 2, 0, 2, 3], [1, 3, 1, 2, 3], [0, 1, 2, 3, 0, 2]]
const RESISTANCE: Array[int] = [100, 75, 100, 125]
const INTERVALS: Array[float] = [3.4, 3.0, 2.7, 2.35]

@onready var _boss: BossScales = $BossScales
@onready var _player: BossPlayer = $BossPlayer
@onready var _conveyor: OverheadConveyor = $OverheadConveyor
@onready var _hud: BossHud = $BossHud
@onready var _camera: Camera3D = $Camera3D

var _phase: int = 0
var _fighting: bool = false
var _started: bool = false
var _camera_center: float = 10.0
var _camera_y: float
var _impact: float = 0.0
var _last_health: int
var _overlay: CanvasLayer
var _panel: PanelContainer
var _speaker: Label
var _line: Label
var _next: Button
var _shade: ColorRect
var _ending: TextureRect
var _crane: AudioStreamPlayer
var _levitation: AudioStreamPlayer
var _glitches: AudioStreamPlayer
var _intro: AudioStreamPlayer


func _ready() -> void:
	Hud.set_hud_visible(false)
	Hud.set_walk_mode(false)
	Letterbox.hide_bars()
	_camera.make_current()
	for light: Node in $Factory.find_children("*", "Light3D", true, false):
		(light as Light3D).light_energy *= 0.57
	var surroundings: WorldEnvironment = $Factory/WorldEnvironment
	surroundings.environment = surroundings.environment.duplicate()
	surroundings.environment.ambient_light_energy *= 0.72
	_camera_y = _camera.position.y
	_last_health = _player.health
	_build_dialogue()
	_crane = _audio_player("SFX", -19.0)
	_levitation = _audio_player("SFX", -23.0)
	_glitches = _audio_player("SFX", -24.0)
	_intro = _audio_player("Music", -12.0)
	_crane.finished.connect(_switch_to_crane_loop)
	_intro.finished.connect(func() -> void:
		if _fighting:
			Audio.play_track(SFX + "no_mercy_active.wav", 0.0, -12.0))
	_boss.phase_broken.connect(_on_phase_broken)
	_player.died.connect(_on_defeat)
	_player.health_changed.connect(_on_health_changed)
	_boss.resistance_changed.connect(_on_resistance_changed)
	_conveyor.container_crashed.connect(_on_container_crashed)
	_set_combat(false)
	Audio.play_track(SFX + "no_mercy_passive.wav", 0.8, -15.0)
	_play_sound(_levitation, "levitation.wav", true)
	_play_sound(_glitches, "random_glitch.wav", true)
	_opening.call_deferred()


func _process(delta: float) -> void:
	var framing: float = clampf(_player.position.x + 2.8, 8.0, 19.5)
	_camera_center = lerpf(_camera_center, framing, 1.0 - exp(-7.0 * delta))
	_impact = move_toward(_impact, 0.0, 0.65 * delta)
	_camera.position.x = _camera_center + randf_range(-_impact, _impact)
	_camera.position.y = _camera_y + randf_range(-_impact, _impact)


func _on_health_changed(health: int, _maximum: int) -> void:
	if health < _last_health:
		_impact = maxf(_impact, 0.11)
	_last_health = health


func _on_resistance_changed(resistance: int, maximum: int) -> void:
	if resistance < maximum:
		_impact = maxf(_impact, 0.07)


func _opening() -> void:
	await _say("Сущность", "ТЫ ЗАЩИЩАЕШЬ ВИНОВНОГО. ТЫ РАЗДЕЛЯЕШЬ ЕГО ГРЕХ. ТЫ — ПРЕПЯТСТВИЕ.", "В бой")
	_start_phase()


func _start_phase() -> void:
	_set_combat(true)
	var pattern: Array[int] = []
	pattern.assign(PHASE_PATTERNS[_phase])
	_hud.set_phase_title("ФАЗА %d / 4" % (_phase + 1))
	_boss.start_phase(RESISTANCE[_phase], INTERVALS[_phase], pattern)
	if _started:
		Audio.play_track(SFX + "no_mercy_active.wav", 0.35, -12.0)
	else:
		_started = true
		Audio.stop_music(0.0)
		_play_sound(_intro, "no_mercy_intro.wav", false)
		_play_sound(_crane, "crane_mechanic_intro.wav", false)


func _switch_to_crane_loop() -> void:
	if _started and _phase < ARGUMENTS.size() + 1:
		_play_sound(_crane, "crane_mechanic_loop.wav", true)


func _set_combat(active: bool) -> void:
	_fighting = active
	_hud.visible = active
	_player.combat_enabled = active
	_player.set_physics_process(active)
	$BossPlayer/AimMarker.visible = active
	_conveyor.set_armed(active)
	_panel.visible = not active
	if not active:
		for child: Node in get_children():
			if child is Bullet:
				child.queue_free()


func _on_container_crashed(hit_boss: bool, damage: int, _position: Vector3) -> void:
	if hit_boss and _fighting:
		_boss.apply_environment_damage(damage)


func _on_phase_broken() -> void:
	_interlude.call_deferred()


func _interlude() -> void:
	if not _fighting or not _player.is_alive():
		return
	_set_combat(false)
	_intro.stop()
	Audio.play_track(SFX + "no_mercy_passive.wav", 0.45, -15.0)
	while _phase < ARGUMENTS.size():
		var argument: Dictionary = ARGUMENTS[_phase]
		_phase += 1
		var has_evidence: bool = GameState.has_story_evidence(str(argument["item"]))
		var speaker: String = "Алексей"
		if has_evidence:
			speaker += " · %s" % argument["name"]
		await _say(speaker, str(argument["proof"] if has_evidence else argument["fallback"]))
		if not has_evidence:
			_start_phase()
			return
	await _verdict()


func _on_defeat() -> void:
	_defeat.call_deferred()


func _defeat() -> void:
	_boss.stop_phase()
	_set_combat(false)
	_intro.stop()
	_crane.stop()
	_levitation.stop()
	_glitches.stop()
	Audio.stop_music(0.4)
	_shade.color.a = 0.85
	await _say("Алексей", "Я не смог остановить Весы.", "Повторить бой")
	SceneRouter.go_to(scene_file_path)


func _verdict() -> void:
	_phase = ARGUMENTS.size() + 1
	_crane.stop()
	Audio.sfx(SFX + "crane_mechanic_final.wav", -13.0)
	Audio.play_track(SFX + "no_mercy_final.wav", 0.7, -14.0)
	await _say("Алексей", "Твоя цель — чтобы люди перестали страдать. Так?")
	await _say("Сущность", "ДА.")
	await _say("Алексей", "Глебов ещё за решёткой, а его близкие продолжают страдать. Твои приговоры тоже причиняют боль. По твоему же правилу ты должна ответить. Каков твой приговор самой себе?")
	_panel.hide()
	Audio.stop_music(0.35)
	_levitation.stop()
	_glitches.stop()
	Audio.sfx(SFX + "random_glitch_out.mp3", -17.0)
	Audio.sfx(SFX + "boss_death.wav", -12.0)
	var entity: Sprite3D = _boss.get_node("BossBase/Entity")
	(entity.get_node("Ash") as CPUParticles3D).emitting = false
	var fade: Tween = create_tween()
	fade.tween_property(entity, "modulate:a", 0.0, 1.7)
	fade.parallel().tween_property(_shade, "color:a", 1.0, 2.5).set_delay(0.65)
	await fade.finished
	Audio.play_track(RAIN, 0.6, -23.0)
	await _say("Алексей", "Она рассыпалась в пепел. Я стоял посреди склада и впервые услышал тишину. Только дождь по крыше и дыхание отца.")
	await _say("Алексей", "Отца я арестовал сам. Дмитрий отказался от мести. Иван — от своих формул.")
	await _say("Три месяца спустя", "Дело Глебова пересмотрено.")
	Audio.stop_music(0.35)
	_ending.show()
	var reveal: Tween = create_tween()
	reveal.tween_property(_ending, "modulate:a", 1.0, 2.65).set_trans(Tween.TRANS_SINE)
	await reveal.finished
	await get_tree().create_timer(0.7, false).timeout
	Audio.play_track(SFX + "after_the_verdict.wav", 1.5, -12.0, false)
	await _say("Алексей", "Вот она — настоящая справедливость. Человек, который провёл семь лет в камере за чужое преступление, наконец свободен.")
	await _say("Мера вины", "Конец", "В главное меню")
	SceneRouter.go_to(TITLE)


func _audio_player(bus_name: String, db: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus_name
	player.volume_db = db
	add_child(player)
	return player


func _play_sound(player: AudioStreamPlayer, filename: String, loop: bool) -> void:
	var stream: AudioStreamWAV = (load(SFX + filename) as AudioStreamWAV).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	if loop:
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	player.stream = stream
	player.play()


func _build_dialogue() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 9
	add_child(_overlay)
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_shade)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ending = TextureRect.new()
	_ending.texture = preload("res://assets/backgrounds/s07/glebov_reunion.png")
	_ending.size = Vector2(640, 360)
	_ending.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ending.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_ending.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending.modulate.a = 0.0
	_ending.hide()
	_overlay.add_child(_ending)
	_panel = PanelContainer.new()
	_panel.position = Vector2(58, 220)
	_panel.custom_minimum_size.x = 524
	_panel.add_theme_stylebox_override("panel", MenuUI.panel_style())
	_overlay.add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_speaker = Label.new()
	_speaker.add_theme_color_override("font_color", Color(0.89, 0.77, 0.55))
	column.add_child(_speaker)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_line)
	_next = MenuUI.button("Далее")
	column.add_child(_next)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END


func _say(speaker: String, line: String, button: String = "Далее") -> void:
	_speaker.text = speaker
	_line.text = line
	_next.text = button
	_panel.show()
	_panel.reset_size()
	_panel.position.y = minf(220.0, 350.0 - _panel.size.y)
	_next.grab_focus()
	await _next.pressed
	_panel.hide()