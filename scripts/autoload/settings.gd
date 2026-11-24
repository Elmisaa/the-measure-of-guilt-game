extends Node

signal bindings_changed

const ACTIONS: Dictionary = {
	"move_left": ["Движение влево", [KEY_A, KEY_LEFT]],
	"move_right": ["Движение вправо", [KEY_D, KEY_RIGHT]],
	"move_up": ["Шаг вглубь", [KEY_W, KEY_UP]],
	"move_down": ["Шаг к камере", [KEY_S, KEY_DOWN]],
	"run": ["Бег", [KEY_SHIFT]],
	"interact": ["Взаимодействовать", [KEY_E]],
	"pickup_dropped": ["Поднять выброшенное", [KEY_G]],
	"inventory": ["Инвентарь", [KEY_I]],
	"stow_item": ["Убрать из рук", [KEY_Q]],
	"flashlight": ["Фонарь", [KEY_F]],
	"boss_dash": ["Рывок в бою", [KEY_SPACE, KEY_SHIFT]],
	"combat_reload": ["Перезарядка", [KEY_R]],
}
const KEY_NAMES: Dictionary = {
	KEY_LEFT: "←", KEY_RIGHT: "→", KEY_UP: "↑", KEY_DOWN: "↓",
	KEY_SPACE: "Пробел", KEY_ESCAPE: "Esc", KEY_ENTER: "Enter",
	KEY_KP_ENTER: "Enter (Num)", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl",
	KEY_BACKSPACE: "Backspace", KEY_TAB: "Tab",
}
const RESERVED_KEYS: Array[Key] = [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB]

const PATH: String = "user://settings.cfg"
const BUSES: Array[String] = ["Music", "SFX"]

var master: float = 1.0
var music: float = 0.8
var sfx: float = 1.0
var fullscreen: bool = false
var pixel_perfect: bool = false
var _key_overrides: Dictionary = {}


func _ready() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	load_settings()
	_apply_bindings()
	if not InputMap.has_action("combat_shoot"):
		InputMap.add_action("combat_shoot")
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("combat_shoot", mouse)
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
	_key_overrides.clear()
	for action: String in ACTIONS:
		var code: int = int(cf.get_value("controls", action, 0))
		if code > 0:
			_key_overrides[action] = code
	# Validate the completed profile so that swapping two keys survives a reload.
	for action: String in _key_overrides.keys():
		if not _binding_error(action, _key_overrides[action]).is_empty():
			_key_overrides.erase(action)


func save_settings() -> void:
	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("audio", "master", master)
	cf.set_value("audio", "music", music)
	cf.set_value("audio", "sfx", sfx)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("video", "pixel_perfect", pixel_perfect)
	for action: String in _key_overrides:
		cf.set_value("controls", action, _key_overrides[action])
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


func key_label(action: String, all: bool = false) -> String:
	var names: PackedStringArray = []
	for code: int in _keys(action):
		names.append(_key_name(code))
		if not all:
			break
	return " / ".join(names)


func format_keys(text: String) -> String:
	if not text.contains("{"):
		return text
	var labels: Dictionary = {}
	for action: String in ACTIONS:
		labels[action] = key_label(action)
	return text.format(labels)


func action_label(action: String) -> String:
	return str(ACTIONS[action][0])


func rebind(action: String, code: int) -> String:
	var error: String = _binding_error(action, code)
	if not error.is_empty():
		return error
	_key_overrides[action] = code
	_apply_bindings()
	save_settings()
	bindings_changed.emit()
	return ""


func reset_bindings() -> void:
	_key_overrides.clear()
	_apply_bindings()
	save_settings()
	bindings_changed.emit()


func _keys(action: String) -> Array:
	if _key_overrides.has(action):
		return [_key_overrides[action]]
	return ACTIONS[action][1]


func _key_name(code: int) -> String:
	if KEY_NAMES.has(code):
		return str(KEY_NAMES[code])
	return OS.get_keycode_string(code)


func _binding_error(action: String, code: int) -> String:
	if code <= 0 or code in RESERVED_KEYS or (code == KEY_SPACE and action != "boss_dash"):
		return "Эта клавиша используется в меню или диалогах."
	for other: String in ACTIONS:
		if other == action or code not in _keys(other):
			continue
		if code == KEY_SHIFT and action in ["run", "boss_dash"] and other in ["run", "boss_dash"]:
			continue
		return "Клавиша уже назначена: %s." % action_label(other)
	return ""


func _apply_bindings() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if Input.is_action_pressed(action):
			Input.action_release(action)
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		for code: int in _keys(action):
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
