extends Node
## Music and UI sounds. Autoload: Audio.
## Music starts at game launch and loops across scenes.

const MUSIC: String = "res://assets/audio/music/866779__logicmoon__star-gazers.wav"
const BLIP: String = "res://assets/audio/sfx/voice_blip.wav"
const MUSIC_DB: float = -10.0
const BLIP_DB: float = -14.0
const BLIP_VOICES: int = 4

var _music: AudioStreamPlayer
var _blips: Array[AudioStreamPlayer] = []
var _next_blip: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.stream = load(MUSIC)
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
	play_music()


func play_music(fade: float = 2.5) -> void:
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, fade)


## Speech blip; pitch ~1.0 per speaker, randomized a little so it sounds like syllables.
func blip(pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _blips[_next_blip]
	_next_blip = (_next_blip + 1) % _blips.size()
	p.pitch_scale = pitch * randf_range(0.9, 1.12)
	p.play()
