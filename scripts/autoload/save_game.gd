extends Node

signal saved(slot: String)

const DIR_GAME: String = "user://saves/"
const DIR_TESTS: String = "user://saves_test/"
const VERSION: int = 1
const AUTO: String = "auto"
const SLOTS: Array[String] = ["auto", "1", "2", "3"]
const SCENES: Dictionary = {
	"res://scenes/s00/intro.tscn": "Пролог",
	"res://scenes/s01/exposition.tscn": "Участок. Ночная смена",
	"res://scenes/s01/desk.tscn": "Участок. Стол Алексея",
	"res://scenes/s01/walk.tscn": "Участок. Зал",
	"res://scenes/s01/restroom.tscn": "Участок. Туалет",
	"res://scenes/s01/call.tscn": "Звонок отца",
	"res://scenes/s02/drive.tscn": "Дорога к отцу",
	"res://scenes/s03/penthouse.tscn": "Пентхаус отца",
	"res://scenes/s03/viktor_talk.tscn": "Пентхаус. Виктор",
	"res://scenes/s03/ivan_call.tscn": "Звонок Ивана",
	"res://scenes/s04/ivan_flat.tscn": "Квартира Ивана",
	"res://scenes/s04/ivan_talk.tscn": "Квартира Ивана. Разговор",
	"res://scenes/s06/factory_present.tscn": "Заброшенный завод",
}

var _loading: bool = false
var DIR: String = DIR_GAME


func _ready() -> void:
	for a: String in OS.get_cmdline_args():
		if a.contains("res://tests/"):
			DIR = DIR_TESTS
	DirAccess.make_dir_recursive_absolute(DIR)


func wipe_test_saves() -> void:
	if DIR != DIR_TESTS:
		return
	for s: String in SLOTS:
		if FileAccess.file_exists(DIR + s + ".json"):
			DirAccess.remove_absolute(DIR + s + ".json")


func can_save() -> bool:
	var sc: Node = get_tree().current_scene
	return sc != null and SCENES.has(sc.scene_file_path)


func save(slot: String) -> bool:
	if not can_save():
		return false
	var sc: Node = get_tree().current_scene
	var gs: Dictionary = GameState.to_dict()
	if sc.has_method("save_state"):
		var extra: Dictionary = sc.call("save_state")
		var fl: Dictionary = gs["flags"]
		for k: String in extra:
			fl[k] = extra[k]
	var data: Dictionary = {
		"version": VERSION,
		"time": Time.get_unix_time_from_system(),
		"date": Time.get_datetime_string_from_system(false, true),
		"scene": sc.scene_file_path,
		"title": str(SCENES[sc.scene_file_path]),
		"game": gs,
		"hud": Hud.journal_to_dict(),
	}
	var f: FileAccess = FileAccess.open(DIR + slot + ".json", FileAccess.WRITE)
	if f == null:
		push_error("SaveGame: cannot write slot %s" % slot)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	saved.emit(slot)
	return true


func autosave() -> void:
	if _loading:
		return
	save(AUTO)


func info(slot: String) -> Dictionary:
	if not FileAccess.file_exists(DIR + slot + ".json"):
		return {}
	var txt: String = FileAccess.get_file_as_string(DIR + slot + ".json")
	var d: Variant = JSON.parse_string(txt)
	if not (d is Dictionary) or not (d as Dictionary).has("scene"):
		return {}
	return d


func has_any() -> bool:
	return not latest().is_empty()


func latest() -> String:
	var best: String = ""
	var best_t: float = -1.0
	for s: String in SLOTS:
		var d: Dictionary = info(s)
		if not d.is_empty() and float(d.get("time", 0.0)) > best_t:
			best_t = float(d["time"])
			best = s
	return best


func load_slot(slot: String) -> bool:
	var d: Dictionary = info(slot)
	if d.is_empty() or not ResourceLoader.exists(str(d["scene"])):
		return false
	_loading = true
	get_tree().paused = false
	Hud.close_pause()
	Hud.set_held("")
	Hud.hide_tutorial()
	Audio.stop_loop()
	GameState.from_dict(d.get("game", {}))
	Hud.journal_from_dict(d.get("hud", {}))
	await SceneRouter.go_to(str(d["scene"]), 0.2)
	_loading = false
	return true


func describe(slot: String) -> String:
	var d: Dictionary = info(slot)
	if d.is_empty():
		return "— пусто —"
	var date: String = str(d.get("date", ""))
	var nice: String = date
	if date.length() >= 16:
		nice = "%s.%s %s" % [date.substr(8, 2), date.substr(5, 2), date.substr(11, 5)]
	return "%s — %s" % [str(d.get("title", "")), nice]


func slot_name(slot: String) -> String:
	return "Автосохранение" if slot == AUTO else "Слот " + slot
