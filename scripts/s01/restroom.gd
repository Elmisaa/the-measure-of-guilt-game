extends Node2D

const HALL: String = "res://scenes/s01/walk.tscn"
const WATER: String = "res://assets/audio/sfx/water.wav"
const DOOR: String = "res://assets/audio/sfx/door.wav"
const NEAR_MARGIN: float = 30.0
const THOUGHT_TIME: float = 3.5

@onready var _player: WalkPlayer = $World/Player
@onready var _spots_root: Node2D = $World/Spots
@onready var _prompt: Label = $World/Prompt
@onready var _thought: ThoughtBox = $UI/Root/ThoughtBox

var _d: Dictionary = {}
var _spots: Dictionary = {}
var _busy: bool = false
var _near: String = ""


func _ready() -> void:
	GameState.item_used.connect(func(id: String, action: String) -> void:
		if id == "coat" and action == "wear":
			GameState.set_flag("coat_on", true)
			_player.set_coat(true))
	_d = DialogueData.load_file("s01_restroom")
	var b: Array = _d.get("bounds", [40, 600])
	_player.min_x = b[0]
	_player.max_x = b[1]
	_player.position.x = float(_d.get("spawn_x", 64))
	var dep: Dictionary = _d.get("depth", {})
	_player.y_far = float(dep.get("y_far", 346))
	_player.y_near = float(dep.get("y_near", 346))
	_player.position.y = _player.y_near
	_player.face_right(true)
	for s: Dictionary in _d.get("spots", []):
		_add_spot(s)
	Hud.set_hud_visible(true)
	Hud.show_stamina(true)
	Hud.set_walk_mode(true)
	Hud.announce_objective()


func _add_spot(s: Dictionary) -> void:
	var r: Array = s["rect"]
	var m: HintMarker = HintMarker.new()
	m.marker_id = str(s["id"])
	m.position = Vector2(r[0], r[1])
	m.size = Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
	_spots_root.add_child(m)
	m.custom_minimum_size = m.size
	m.mouse_enabled = true
	m.activated.connect(func(id: String) -> void: _interact(id))
	_spots[m.marker_id] = {"marker": m, "rect": r, "data": s}


func _process(_delta: float) -> void:
	var px: float = _player.position.x
	var best: String = ""
	var best_d: float = INF
	for id: String in _spots:
		var r: Array = _spots[id]["rect"]
		var near: bool = px >= float(r[0]) - NEAR_MARGIN and px <= float(r[2]) + NEAR_MARGIN
		var mk: HintMarker = _spots[id]["marker"]
		mk.set_active(near and not _busy)
		if near:
			var dd: float = absf(px - (float(r[0]) + float(r[2])) / 2.0) - 100.0 * float(_spots[id]["data"].get("priority", 0))
			if dd < best_d:
				best_d = dd
				best = id
	_near = best if not _busy else ""
	_prompt.visible = _near != ""
	if _prompt.visible:
		var r2: Array = _spots[_near]["rect"]
		_prompt.text = "E — " + _label_for(_near)
		var room_w: float = ($World/Background as Sprite2D).texture.get_width()
		_prompt.position = Vector2(clampf(roundf((float(r2[0]) + float(r2[2])) / 2.0 - _prompt.size.x / 2.0), 4.0, room_w - _prompt.size.x - 4.0), maxf(4.0, float(r2[1]) - 16.0))


func _label_for(id: String) -> String:
	if not Hud.held_item.is_empty() and str(_spots[id]["data"].get("kind", "")) == "sink":
		return "%s → %s" % [str(GameState.item_def(Hud.held_item).get("name", "")), str(_spots[id]["data"]["name"])]
	if id == "sink" and GameState.has_item("cup_old"):
		return str(_d["sink"]["wash_label"])
	return str(_spots[id]["data"]["name"])


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _near == "" or Hud.is_blocking():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_interact(_near)


func _interact(id: String) -> void:
	if _busy or not _spots.has(id):
		return
	var sd: Dictionary = _spots[id]["data"]
	if not Hud.held_item.is_empty() and not (str(sd.get("kind", "")) in ["sink", "door"]):
		Hud.set_held("")
	match str(sd.get("kind", "")):
		"door":
			_busy = true
			_player.frozen = true
			Audio.sfx(DOOR, -6.0)
			SceneRouter.go_to(str(sd["target"]), 0.3)
		"sink":
			_sink()
		_:
			var t: String = str(sd.get("thought", ""))
			if not t.is_empty():
				_thought.show_text(t, THOUGHT_TIME)


func _sink() -> void:
	if Hud.held_item != "cup_old":
		if not Hud.held_item.is_empty():
			_thought.show_text(str(_d["sink"]["no_use"]), THOUGHT_TIME)
		elif GameState.has_item("cup_old"):
			_thought.show_text(str(_d["sink"]["need_cup"]), THOUGHT_TIME)
		else:
			_thought.show_text(str(_d["sink"]["nothing"]), THOUGHT_TIME)
		return
	Hud.set_held("")
	_busy = true
	_player.frozen = true
	Audio.sfx(WATER, -16.0)
	await get_tree().create_timer(2.0).timeout
	GameState.replace_item("cup_old", "cup_empty")
	if GameState.get_flag("walk_state") == "wash":
		GameState.set_flag("walk_state", "coffee1")
	_thought.show_text(str(_d["sink"]["washed"]), THOUGHT_TIME)
	_player.frozen = false
	_busy = false


func _exit_tree() -> void:
	Hud.show_stamina(false)
	Hud.set_walk_mode(false)
