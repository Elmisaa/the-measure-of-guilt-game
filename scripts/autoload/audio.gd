extends Node
## Music and UI sounds. Autoload: Audio.
## Music starts at game launch and loops across scenes.

const MUSIC: String = "res://assets/audio/music/866779__logicmoon__star-gazers.wav"
## Start ambience (rain + thunder). Found by its freesound id in assets/audio/ or
## assets/audio/music/, so the file can be dropped in as is; falls back to MUSIC.
const START_AMBIENCE_ID: String = "877124"
const BLIP: String = "res://assets/audio/sfx/voice_blip.wav"
const MUSIC_DB: float = -10.0
const BLIP_DB: float = -8.0
const BLIP_VOICES: int = 4
const UI_HOVER: String = "res://assets/audio/sfx/ui_hover.wav"
const UI_CLICK: String = "res://assets/audio/sfx/ui_click.wav"
const UI_DB: float = -12.0
const ICON_DB: float = -26.0  ## HUD icons: barely audible
const PHONE_RING: String = "res://assets/audio/sfx/629201__audacitier__phone-ringing-5.mp3"

var _music: AudioStreamPlayer
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
	var start: AudioStream = load(_find_start_ambience())
	if "loop" in start:
		start.set("loop", true)
	_music.stream = start
	_music.volume_db = -60.0
	_music.finished.connect(_music.play)  # loop
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
	_loop = AudioStreamPlayer.new()
	add_child(_loop)
	for i in BLIP_VOICES:
		_phone_blips.append(_make_player("res://assets/audio/sfx/blip_phone.wav", BLIP_DB - 2.0))
	for i in 4:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	play_music()


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


## HUD icons: no hover sound, a very quiet click.
func bind_icon(b: BaseButton) -> void:
	b.pressed.connect(func() -> void:
		_icon_click.pitch_scale = 1.3
		_icon_click.play())


func stop_music(fade: float = 0.6) -> void:
	var t: Tween = create_tween()
	t.tween_property(_music, "volume_db", -60.0, fade)
	t.tween_callback(_music.stop)


## Looping sound effect (phone ring), plays until stop_loop().
func play_loop(path: String, db: float = -4.0) -> void:
	var s: AudioStream = load(path)
	if "loop" in s:
		s.set("loop", true)
	_loop.stream = s
	_loop.volume_db = db
	_loop.play()


func stop_loop() -> void:
	_loop.stop()


## Hover + click sounds for any Button / clickable Control.
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


func play_music(fade: float = 2.5) -> void:
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, fade)


## Voice heard through a phone: buzzy, band-limited blip.
func blip_phone(pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _phone_blips[_next_blip]
	_next_blip = (_next_blip + 1) % _phone_blips.size()
	p.pitch_scale = pitch * randf_range(0.88, 1.15)
	p.play()


## One-shot sound effect.
func sfx(path: String, db: float = -6.0, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx.size()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## Switch background music to another looping track.
func play_track(path: String, fade: float = 1.5, db: float = MUSIC_DB) -> void:
	_music.stop()
	var s: AudioStream = load(path)
	if "loop" in s:
		s.set("loop", true)
	_music.stream = s
	_music.volume_db = -60.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", db, fade)


## Speech blip; pitch ~1.0 per speaker, randomized a little so it sounds like syllables.
func blip(pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _blips[_next_blip]
	_next_blip = (_next_blip + 1) % _blips.size()
	p.pitch_scale = pitch * randf_range(0.9, 1.12)
	p.play()
