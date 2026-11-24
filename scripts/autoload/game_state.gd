extends Node

signal inventory_changed
signal item_added(item_id: String)
signal item_used(item_id: String, action: String)
signal stamina_changed(value: float)

const EVIDENCE_FLAGS: Dictionary = {
	"confession": "argument_1",
	"journal": "argument_2",
	"dmitry_recorder": "argument_3",
}
const ITEMS_PATH: String = "res://data/items.json"

var flags: Dictionary = {}
var items: Array[String] = []
var item_thoughts: Dictionary = {}
var stamina: float = 1.0:
	set(v):
		var nv: float = clampf(v, 0.0, 1.0)
		if not is_equal_approx(nv, stamina):
			stamina = nv
			stamina_changed.emit(stamina)

var _defs: Dictionary = {}
var containers: Dictionary = {}
var dropped_items: Dictionary = {}
var take_locks: Dictionary = {}


func _ready() -> void:
	var f: FileAccess = FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if f:
		_defs = JSON.parse_string(f.get_as_text())
	reset_inventory()


func new_game() -> void:
	flags.clear()
	item_thoughts.clear()
	stamina = 1.0
	reset_inventory()


func set_flag(key: String, value: Variant) -> void:
	flags[key] = value
	if value is bool and not value:
		for id: String in EVIDENCE_FLAGS:
			if EVIDENCE_FLAGS[id] == key:
				dropped_items.erase(id)
				remove_item(id)
				break


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)



func to_dict() -> Dictionary:
	return {"flags": flags.duplicate(true), "items": Array(items), "containers": containers.duplicate(true),
		"dropped_items": dropped_items.duplicate(true),
		"stamina": stamina, "item_thoughts": item_thoughts.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	new_game()
	flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	items.clear()
	var definitions: Dictionary = _defs.get("items", {})
	for it: Variant in d.get("items", []):
		if definitions.has(str(it)) and _evidence_allowed(str(it)):
			items.append(str(it))
	var saved_drops: Dictionary = d.get("dropped_items", {})
	for id: String in saved_drops:
		if definitions.has(id) and _evidence_allowed(id):
			dropped_items[id] = saved_drops[id].duplicate(true)
	var cs: Dictionary = d.get("containers", {})
	for cid: String in cs:
		var arr: Array[String] = []
		for it: Variant in cs[cid]:
			arr.append(str(it))
		containers[cid] = arr
	item_thoughts = (d.get("item_thoughts", {}) as Dictionary).duplicate(true)
	stamina = float(d.get("stamina", 1.0))
	inventory_changed.emit()



func _evidence_allowed(id: String) -> bool:
	var flag: String = str(EVIDENCE_FLAGS.get(id, ""))
	return flag.is_empty() or bool(get_flag(flag, true))


func has_story_evidence(id: String) -> bool:
	return EVIDENCE_FLAGS.has(id) and has_item(id) and _evidence_allowed(id)


func reset_inventory() -> void:
	items.clear()
	for id: Variant in _defs.get("start", []):
		items.append(str(id))
	containers.clear()
	dropped_items.clear()
	take_locks.clear()
	for cid: String in _defs.get("containers", {}):
		var arr: Array[String] = []
		for it: Variant in _defs["containers"][cid].get("items", []):
			arr.append(str(it))
		containers[cid] = arr
	inventory_changed.emit()



func container_items(cid: String) -> Array:
	return containers.get(cid, [])


func container_title(cid: String) -> String:
	return str(_defs.get("containers", {}).get(cid, {}).get("title", cid))


func container_can_take(cid: String) -> bool:
	return not bool(_defs.get("containers", {}).get(cid, {}).get("no_take", false))


func take_from(cid: String, id: String) -> void:
	var arr: Array = containers.get(cid, [])
	if arr.has(id) and not dropped_items.has(id):
		arr.erase(id)
		add_item(id)


func item_def(id: String) -> Dictionary:
	return _defs.get("items", {}).get(id, {})


func action_label(action: String) -> String:
	return str(_defs.get("actions", {}).get(action, action))


func item_actions(id: String) -> Array[String]:
	var out: Array[String] = []
	for a: Variant in item_def(id).get("actions", {}).keys():
		out.append(str(a))
	return out


func has_item(id: String) -> bool:
	return items.has(id)


func owns_item(id: String) -> bool:
	return has_item(id) or dropped_items.has(id)


func drop_item(id: String, scene_path: String, position: Array) -> bool:
	if scene_path.is_empty() or not has_item(id):
		return false
	dropped_items[id] = {"scene": scene_path, "position": position.duplicate()}
	remove_item(id)
	return true


func take_dropped_item(id: String, scene_path: String) -> void:
	var drop: Dictionary = dropped_items.get(id, {})
	if drop.is_empty() or drop["scene"] != scene_path:
		return
	dropped_items.erase(id)
	add_item(id)


func add_item(id: String) -> void:
	if _evidence_allowed(id) and not owns_item(id):
		items.append(id)
		inventory_changed.emit()
		item_added.emit(id)


func remove_item(id: String) -> void:
	if items.has(id):
		items.erase(id)
		inventory_changed.emit()


func replace_item(old_id: String, new_id: String) -> void:
	if old_id == new_id:
		return
	if dropped_items.has(old_id):
		if not owns_item(new_id):
			dropped_items[new_id] = dropped_items[old_id]
		dropped_items.erase(old_id)
		return
	var i: int = items.find(old_id)
	if i < 0:
		add_item(new_id)
		return
	if owns_item(new_id):
		remove_item(old_id)
		return
	items[i] = new_id
	inventory_changed.emit()


func item_thought(id: String, action: String) -> String:
	var key: String = id + ":" + action
	if item_thoughts.has(key):
		return str(item_thoughts[key])
	return str(item_def(id).get("actions", {}).get(action, ""))


func use_item(id: String, action: String) -> void:
	var d: Dictionary = item_def(id)
	var fx: Dictionary = d.get("effects", {}).get(action, {})
	if fx.has("stamina"):
		stamina = float(fx["stamina"])
	if fx.has("sfx"):
		var audio: Node = get_node_or_null("/root/Audio")
		if audio:
			audio.sfx(str(fx["sfx"]), -6.0)
	var becomes: Dictionary = d.get("becomes", {})
	if becomes.has(action):
		if str(becomes[action]).is_empty():
			remove_item(id)
		else:
			replace_item(id, str(becomes[action]))
	item_used.emit(id, action)
