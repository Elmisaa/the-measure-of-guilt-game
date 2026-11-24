extends Node

const MUSIC: String = "res://assets/audio/music/866779__logicmoon__star-gazers.wav"
const START_AMBIENCE_ID: String = "877124"
const BLIP: String = "res://assets/audio/sfx/voice_blip.wav"
const MUSIC_DB: float = -10.0
const BLIP_DB: float = -8.0
const BLIP_VOICES: int = 4
const UI_HOVER: String = "res://assets/audio/sfx/ui_hover.wav"
const UI_CLICK: String = "res://assets/audio/sfx/ui_click.wav"
const UI_DB: float = -12.0
const ICON_DB: float = -26.0
const PHONE_RING: String = "res://assets/audio/sfx/629201__audacitier__phone-ringing-5.mp3"

const HMMS: Array[String] = ["res://assets/audio/sfx/hmm_1.wav", "res://assets/audio/sfx/hmm_2.wav", "res://assets/audio/sfx/hmm_3.wav", "res://assets/audio/sfx/hmm_4.wav", "res://assets/audio/sfx/hmm_5.wav"]
const HMM_CHANCE: float = 0.35
const HMM_DB: float = -9.0
var _hmm_last: int = -1
var _hmm_ready_at: float = 4.0
var _music: AudioStreamPlayer
var _music_fade: Tween
var _music_loops: bool = true
var _blips: Array[AudioStreamPlayer] = []
var _next_blip: int = 0
var _ui_hover: AudioStreamPlayer
var _ui_click: AudioStreamPlayer
var _icon_click: AudioStreamPlayer
var _loop: AudioStreamPlayer
var _phone_blips: Array[AudioStreamPlayer] = []
var _sfx: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = -60.0
	_music.finished.connect(func() -> void:
		if _music_loops:
			_music.play())
	_loop = AudioStreamPlayer.new()
	add_child(_music)
	var blip: AudioStream = load(BLIP)
	for i in BLIP_VOICES:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = blip
		p.volume_db = BLIP_DB
		add_child(p)
		_blips.append(p)
	_ui_hover = _make_player(UI_HOVER, UI_DB - 4.0)
	_ui_click = _make_player(UI_CLICK, UI_DB)
	_icon_click = _make_player(UI_CLICK, ICON_DB)
	add_child(_loop)
	_loop.finished.connect(_loop.play)
	for i in BLIP_VOICES:
		_phone_blips.append(_make_player("res://assets/audio/sfx/blip_phone.wav", BLIP_DB - 2.0))
	for i in 4:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	for c: Node in get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).bus = "SFX"
	_music.bus = "Music"


func _make_player(path: String, db: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	return p


func ui_hover() -> void:
	_ui_hover.pitch_scale = randf_range(0.97, 1.03)
	_ui_hover.play()


func ui_click() -> void:
	_ui_click.play()


func bind_icon(b: BaseButton) -> void:
	b.pressed.connect(func() -> void:
		_icon_click.pitch_scale = 1.3
		_icon_click.play())


func stop_music(fade: float = 0.6) -> void:
	_cancel_music_fade()
	if fade <= 0.0:
		_music.stop()
		return
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", -60.0, fade)
	_music_fade.tween_callback(_music.stop)


func play_loop(path: String, db: float = -4.0) -> void:
	var s: AudioStream = load(path)
	if "loop" in s:
		s.set("loop", true)
	_loop.stream = s
	_loop.volume_db = db
	_loop.play()


func stop_loop() -> void:
	_loop.stop()


func bind_button(c: Control) -> void:
	c.mouse_entered.connect(ui_hover)
	if c is BaseButton:
		(c as BaseButton).pressed.connect(ui_click)


func _find_start_ambience() -> String:
	for dir_path: String in ["res://assets/audio/music/", "res://assets/audio/"]:
		var d: DirAccess = DirAccess.open(dir_path)
		if d == null:
			continue
		for f: String in d.get_files():
			var name: String = f.trim_suffix(".import").trim_suffix(".remap")
			if name.begins_with(START_AMBIENCE_ID) and (name.ends_with(".wav") or name.ends_with(".ogg") or name.ends_with(".mp3")):
				return dir_path + name
	return MUSIC


func play_start_ambience(fade: float = 2.5) -> void:
	if _music.playing and _music.stream != null:
		var current_path: String = _music.stream.get_path()
		if current_path != "" and START_AMBIENCE_ID in current_path:
			return
	play_track(_find_start_ambience(), fade)


func play_music(fade: float = 2.5) -> void:
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, fade)


func blip_phone(pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _phone_blips[_next_blip]
	_next_blip = (_next_blip + 1) % _phone_blips.size()
	p.pitch_scale = pitch * randf_range(0.88, 1.15)
	p.play()


func thought_hum() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _hmm_ready_at or randf() > HMM_CHANCE:
		return
	var i: int = randi() % HMMS.size()
	if i == _hmm_last:
		i = (i + 1 + randi() % (HMMS.size() - 1)) % HMMS.size()
	_hmm_last = i
	_hmm_ready_at = now + randf_range(12.0, 22.0)
	sfx(HMMS[i], HMM_DB, randf_range(0.97, 1.03))


func sfx(path: String, db: float = -6.0, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx.size()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func play_track(path: String, fade: float = 1.5, db: float = MUSIC_DB, loop: bool = true) -> void:
	_cancel_music_fade()
	_music.stop()
	_music_loops = loop
	var stream: AudioStream = load(path)
	_music.stream = stream.duplicate()
	if _music.stream is AudioStreamWAV:
		var wav: AudioStreamWAV = _music.stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop:
			wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	elif "loop" in _music.stream:
		_music.stream.set("loop", loop)
	_music.volume_db = -60.0 if fade > 0.0 else db
	_music.play()
	if fade > 0.0:
		_music_fade = create_tween()
		_music_fade.tween_property(_music, "volume_db", db, fade)


func _cancel_music_fade() -> void:
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()


func blip(pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _blips[_next_blip]
	_next_blip = (_next_blip + 1) % _blips.size()
	p.pitch_scale = pitch * randf_range(0.9, 1.12)
	p.play()


func duck_music(on: bool, fade: float = 0.8) -> void:
	if not _music.playing:
		return
	_cancel_music_fade()
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", MUSIC_DB - 14.0 if on else MUSIC_DB, fade)
