extends Node2D
## s01: after the report Alexei wants coffee — walk through the hall (side view).
## Coffee → a second cup → the phone rings at his desk → walk back → answer → the call.
## Spots and thoughts: data/dialogues/s01_walk.json. A/D or arrows walk, E/Space/click use.

const CALL_SCENE: String = "res://scenes/s01/call.tscn"
const RING: String = "res://assets/audio/sfx/629201__audacitier__phone-ringing-5.mp3"
const PICKUP: String = "res://assets/audio/sfx/pickup.wav"
const NEAR_MARGIN: float = 40.0
const THOUGHT_TIME: float = 3.5
const HALF_SCREEN: float = 320.0

@onready var _player: WalkPlayer = $World/Player
@onready var _camera: Camera2D = $World/Camera
@onready var _spots_root: Node2D = $World/Spots
@onready var _prompt: Label = $World/Prompt
@onready var _thought: ThoughtBox = $UI/Root/ThoughtBox

var _d: Dictionary = {}
var _spots: Dictionary = {}  # id -> {marker, rect, name, thought}
var _state: String = "coffee1"
var _busy: bool = false
var _near: String = ""
var _room_w: float = 2012.0


func _ready() -> void:
	_d = DialogueData.load_file("s01_walk")
	_room_w = ($World/Background as Sprite2D).texture.get_width()
	var b: Array = _d.get("bounds", [70, 1950])
	_player.min_x = b[0]
	_player.max_x = b[1]
	_player.position.x = float(_d.get("spawn_x", 360))
	for s: Dictionary in _d.get("spots", []):
		_add_spot(s)
	Hud.set_hud_visible(true)
	Hud.set_objective(str(_d["objectives"]["coffee1"]))
	_update_camera()
	await get_tree().create_timer(0.6).timeout
	_thought.show_text(str(_d.get("enter_thought", "")), THOUGHT_TIME)


func _add_spot(s: Dictionary) -> void:
	var r: Array = s["rect"]
	var m: HintMarker = HintMarker.new()
	m.marker_id = str(s["id"])
	m.position = Vector2(r[0], r[1])
	m.size = Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
	_spots_root.add_child(m)
	m.custom_minimum_size = m.size
	m.activated.connect(func(id: String) -> void: _interact(id))
	_spots[m.marker_id] = {"marker": m, "rect": r, "name": str(s["name"]), "thought": str(s.get("thought", ""))}


func _process(_delta: float) -> void:
	_update_camera()
	_update_near()


func _update_camera() -> void:
	var cx: float = clampf(_player.position.x, HALF_SCREEN, _room_w - HALF_SCREEN)
	_camera.position = Vector2(roundf(cx / 4.0) * 4.0, 180.0)


## Hints only on spots Alexei can reach; the nearest gets a prompt.
func _update_near() -> void:
	var px: float = _player.position.x
	var best: String = ""
	var best_d: float = INF
	for id: String in _spots:
		var r: Array = _spots[id]["rect"]
		var near: bool = px >= float(r[0]) - NEAR_MARGIN and px <= float(r[2]) + NEAR_MARGIN
		(_spots[id]["marker"] as HintMarker).set_active(near and not _busy)
		if near:
			var d: float = absf(px - (float(r[0]) + float(r[2])) / 2.0)
			if d < best_d:
				best_d = d
				best = id
	_near = best if not _busy else ""
	_prompt.visible = _near != ""
	if _prompt.visible:
		var r2: Array = _spots[_near]["rect"]
		_prompt.text = "E — " + _label_for(_near)
		_prompt.position = Vector2(roundf((float(r2[0]) + float(r2[2])) / 2.0 - _prompt.size.x / 2.0), float(r2[1]) - 16.0)


func _label_for(id: String) -> String:
	if id == "desk" and _state == "phone":
		return str(_d["coffee"]["desk_answer"])
	return str(_spots[id]["name"])


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _near == "" or Hud.is_blocking():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_interact(_near)


func _interact(id: String) -> void:
	if _busy or not _spots.has(id):
		return
	match id:
		"coffee":
			_coffee()
		"desk":
			if _state == "phone":
				_answer_phone()
			else:
				_thought.show_text(str(_spots[id]["thought"]), THOUGHT_TIME)
		_:
			var t: String = str(_spots[id]["thought"])
			if not t.is_empty():
				_thought.show_text(t, THOUGHT_TIME)


func _coffee() -> void:
	var c: Dictionary = _d["coffee"]
	match _state:
		"coffee1":
			_busy = true
			_player.frozen = true
			for line: String in c["first"]:
				_thought.show_text(line)
				await get_tree().create_timer(2.6).timeout
			_thought.hide_box()
			_state = "coffee2"
			Hud.set_objective(str(_d["objectives"]["coffee2"]))
			_player.frozen = false
			_busy = false
		"coffee2":
			_busy = true
			_player.frozen = true
			_thought.show_text(str(c["second"]))
			await get_tree().create_timer(2.8).timeout
			Audio.play_loop(RING, -12.0)  # far away, at his desk
			_thought.show_text(str(c["phone_thought"]), THOUGHT_TIME)
			_state = "phone"
			Hud.set_objective(str(_d["objectives"]["phone"]))
			_player.frozen = false
			_busy = false
		_:
			pass


func _answer_phone() -> void:
	_busy = true
	_player.frozen = true
	Audio.stop_loop()
	Audio.sfx(PICKUP, -4.0)
	SceneRouter.go_to(CALL_SCENE, 1.2)
