extends Node

const PATH: String = "user://settings.cfg"
const BUSES: Array[String] = ["Music", "SFX"]

var master: float = 1.0
var music: float = 0.8
var sfx: float = 1.0
var fullscreen: bool = false
var pixel_perfect: bool = false


func _ready() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	load_settings()
	apply()


func load_settings() -> void:
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	master = float(cf.get_value("audio", "master", master))
	music = float(cf.get_value("audio", "music", music))
	sfx = float(cf.get_value("audio", "sfx", sfx))
	fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
	pixel_perfect = bool(cf.get_value("video", "pixel_perfect", pixel_perfect))


func save_settings() -> void:
	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("audio", "master", master)
	cf.set_value("audio", "music", music)
	cf.set_value("audio", "sfx", sfx)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("video", "pixel_perfect", pixel_perfect)
	cf.save(PATH)


func apply() -> void:
	_set_bus("Master", master)
	_set_bus("Music", music)
	_set_bus("SFX", sfx)
	get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if DisplayServer.get_name() == "headless":
		return
	var want: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


func _set_bus(bus: String, v: float) -> void:
	var i: int = AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))
