extends Node2D
## s01: after the report Alexei wants coffee — walk through the hall (side view).
## Coffee: pour into the empty cup at the machine, drink it from the inventory (I) → a second cup →
## "time to go home" → the player explores freely and decides when to go to the desk → pack things →
## the phone rings right there → answer → the call. Kowalski's desk has a radio (stations, off).
## After the call ("Подняться"), state "leave": take the coat from the locker, put it on (I → «Надеть»),
## go out through the exit → the drive cutscene (s02).
## Spots and thoughts: data/dialogues/s01_walk.json. A/D or arrows walk, Shift run, E/click use (Space only pages thoughts), I things.

const CALL_SCENE: String = "res://scenes/s01/call.tscn"
const DRIVE_SCENE: String = "res://scenes/s02/drive.tscn"
const RING: String = "res://assets/audio/sfx/629201__audacitier__phone-ringing-5.mp3"
const PICKUP: String = "res://assets/audio/sfx/pickup.wav"
const POUR: String = "res://assets/audio/sfx/pour.wav"
const DOOR: String = "res://assets/audio/sfx/door.wav"
## Things Alexei must take from his locker before he can pack up at the desk (the cassette is optional).
const HOME_THINGS: Array[String] = ["keys", "notebook", "umbrella"]
const NEAR_MARGIN: float = 40.0
const THOUGHT_TIME: float = 3.5
const HALF_SCREEN: float = 320.0
const ENTER_THOUGHT_TIME: float = 6.0
## The city behind the hall windows moves slower than the room (tools/make_window_parallax.py).
const WINDOW_SHADER: String = "res://scripts/fx/window_parallax.gdshader"
const WINDOW_MASK: String = "res://assets/backgrounds/s01/walk_windows_mask.png"
const WINDOW_CITY: String = "res://assets/backgrounds/s01/walk_windows_city.png"
const WINDOW_CENTER_X: float = 640.0  ## camera x where the city sits as painted
const WINDOW_PARALLAX: float = 0.14  ## city shift per px of camera move (the margin is 48 px)
const WINDOW_MARGIN: float = 48.0

@onready var _player: WalkPlayer = $World/Player
@onready var _camera: Camera2D = $World/Camera
@onready var _spots_root: Node2D = $World/Spots
@onready var _prompt: Label = $World/Prompt
@onready var _thought: ThoughtBox = $UI/Root/ThoughtBox
@onready var _radio: Radio = $World/Radio

var _d: Dictionary = {}
var _spots: Dictionary = {}  # id -> {marker, rect, name, thought, data}
var _state: String = "wash"
var _busy: bool = false
var _near: String = ""
var _room_w: float = 2012.0
var _window_mat: ShaderMaterial


func _ready() -> void:
	_d = DialogueData.load_file("s01_walk")
	_room_w = ($World/Background as Sprite2D).texture.get_width()
	_setup_windows()
	var b: Array = _d.get("bounds", [70, 1950])
	_player.min_x = b[0]
	_player.max_x = b[1]
	_player.position.x = float(_d.get("spawn_x", 360))
	var dep: Dictionary = _d.get("depth", {})
	_player.y_far = float(dep.get("y_far", 346))
	_player.y_near = float(dep.get("y_near", 346))
	_player.scale_far = float(dep.get("scale_far", 1.0))
	_player.position.y = _player.y_near
	var back_x: Variant = GameState.get_flag("walk_return_x")
	if not bool(GameState.get_flag("controls_hint_shown", false)):  # the key legend: once per game
		GameState.set_flag("controls_hint_shown", true)
		Hud.show_controls_hint.call_deferred()
	if back_x == null and GameState.get_flag("walk_state") == "leave":
		_player.position.x = float(_d["leave"]["spawn_x"])  # just got up from the desk after the call
	if back_x != null:  # coming back from the restroom: stand at its door
		_player.position.x = float(back_x)
		GameState.set_flag("walk_return_x", null)
	for s: Dictionary in _d.get("spots", []):
		_add_spot(s)
	Hud.set_hud_visible(true)
	Hud.show_stamina(true)
	Hud.set_walk_mode(true)
	GameState.item_used.connect(_on_item_used)
	if not (GameState.has_item("cup_old") or GameState.has_item("cup_empty") or GameState.has_item("cup_full")):
		GameState.items.append("cup_old")  # started here directly (tests/debug): the cup from the desk
	GameState.inventory_changed.connect(_check_locker)
	var saved: Variant = GameState.get_flag("walk_state")
	var returning: bool = saved != null
	_state = str(saved) if returning else ("wash" if GameState.has_item("cup_old") else "coffee1")
	if _state == "leave":
		GameState.item_thoughts["coat:wear"] = str(_d["leave"]["worn"])
	Hud.set_objective(_objective(), true)
	_update_locker_lock()
	_radio.set_station(int(GameState.get_flag("radio_station", -1)))  # still playing when he comes back
	_update_camera()
	_tutorial_start(returning)


## The first time in the hall only: where the coffee is (the key legend on the left is the HUD's).
## After the call: "put the coat on and go". Neither comes back on later entries.
func _tutorial_start(_returning: bool) -> void:
	Hud.hide_tutorial()
	if _state == "leave":
		if not bool(GameState.get_flag("leave_entered", false)):
			GameState.set_flag("leave_entered", true)
			_thought.show_text(str(_d["leave"]["enter"]), ENTER_THOUGHT_TIME)
		return
	if not bool(GameState.get_flag("walk_intro_seen", false)):
		GameState.set_flag("walk_intro_seen", true)
		_thought.show_text(str(_d["tutorial"]["enter"]), ENTER_THOUGHT_TIME)


func _exit_tree() -> void:
	Hud.hide_tutorial()
	Hud.show_stamina(false)
	Hud.set_walk_mode(false)


func _add_spot(s: Dictionary) -> void:
	var r: Array = s["rect"]
	var m: HintMarker = HintMarker.new()
	m.marker_id = str(s["id"])
	m.position = Vector2(r[0], r[1])
	m.size = Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
	_spots_root.add_child(m)
	m.custom_minimum_size = m.size
	m.mouse_enabled = true  # click works on spots Alexei is near (E too)
	m.activated.connect(func(id: String) -> void: _interact(id))
	_spots[m.marker_id] = {"marker": m, "rect": r, "name": str(s["name"]), "thought": str(s.get("thought", "")), "data": s}


func _process(delta: float) -> void:
	_update_camera()
	_update_near()


func _update_camera() -> void:
	var cx: float = clampf(_player.position.x, HALF_SCREEN, _room_w - HALF_SCREEN)
	_camera.position = Vector2(roundf(cx / 4.0) * 4.0, 180.0)
	if _window_mat:  # the far city drifts a little: it is a window, not a painting
		var off: float = clampf((_camera.position.x - WINDOW_CENTER_X) * WINDOW_PARALLAX, -WINDOW_MARGIN, WINDOW_MARGIN)
		_window_mat.set_shader_parameter("offset_px", WINDOW_MARGIN + roundf(off / 4.0) * 4.0)


func _setup_windows() -> void:
	if not (ResourceLoader.exists(WINDOW_MASK) and ResourceLoader.exists(WINDOW_CITY)):
		return
	var city: Texture2D = load(WINDOW_CITY)
	_window_mat = ShaderMaterial.new()
	_window_mat.shader = load(WINDOW_SHADER)
	_window_mat.set_shader_parameter("mask_tex", load(WINDOW_MASK))
	_window_mat.set_shader_parameter("city_tex", city)
	_window_mat.set_shader_parameter("bg_size", Vector2(_room_w, 360.0))
	_window_mat.set_shader_parameter("city_origin", Vector2(476.0, 96.0))
	_window_mat.set_shader_parameter("city_size", Vector2(city.get_width(), city.get_height()))
	($World/Background as Sprite2D).material = _window_mat


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
		_prompt.position = Vector2(clampf(roundf((float(r2[0]) + float(r2[2])) / 2.0 - _prompt.size.x / 2.0), 4.0, _room_w - _prompt.size.x - 4.0), float(r2[1]) - 16.0)


func _label_for(id: String) -> String:
	if not Hud.held_item.is_empty() and id == "coffee":
		return "%s → %s" % [str(GameState.item_def(Hud.held_item).get("name", "")), str(_spots[id]["name"])]
	if id == "desk" and _state == "phone":
		return str(_d["coffee"]["desk_answer"])
	if id == "desk" and _state == "home":
		return str(_d["coffee"]["desk_pack"])
	if id == "coffee" and _state in ["coffee1", "coffee2"] and GameState.has_item("cup_empty"):
		return str(_d["coffee"]["pour_label"])
	if id == "exit" and _state == "leave":
		return str(_d["leave"]["exit_label"])
	if id == "radio":
		var r: Dictionary = _d["radio"]
		if not _radio.is_on():
			return str(r["on"])
		return str(r["off"]) if _radio.station() == _radio.stations.size() - 1 else str(r["next"])
	return str(_spots[id]["name"])


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _near == "" or Hud.is_blocking():
		return
	if event.is_action_pressed("interact"):  # E only (Space pages thoughts)
		get_viewport().set_input_as_handled()
		_interact(_near)


func _interact(id: String) -> void:
	if _busy or not _spots.has(id):
		return
	if not Hud.held_item.is_empty() and id != "coffee" and str(_spots[id]["data"].get("kind", "")) != "door":
		Hud.set_held("")  # the thing goes back to the bag; Alexei just looks / opens as usual
	match id:
		"coffee":
			_coffee()
		"radio":
			_use_radio()
		"exit" when _state == "leave":
			if not _has_home_things():
				_thought.show_text(str(_d["leave"]["no_things"]), THOUGHT_TIME)
			elif not bool(GameState.get_flag("coat_on", false)):
				_thought.show_text(str(_d["leave"]["no_coat"]), THOUGHT_TIME)
			else:
				_leave_precinct()
		"desk":
			if _state == "phone":
				_answer_phone()
			elif _state == "back_to_desk":
				_pack()
			elif _state == "home":
				_thought.show_text(str(_d["coffee"]["need_things"]), THOUGHT_TIME)
			else:
				_thought.show_text(str(_spots[id]["thought"]), THOUGHT_TIME)
		_:
			var sd: Dictionary = _spots[id]["data"]
			match str(sd.get("kind", "")):
				"closeup":
					_open_closeup(sd)
					return
				"container":
					Hud.open_container(str(sd["container"]))
					return
				"door":
					_go_through(sd)
					return
			var t: String = str(_spots[id]["thought"])
			if not t.is_empty():
				_thought.show_text(t, THOUGHT_TIME)


## The coffee machine takes the clean cup from Alexei's hand (inventory -> "Взять в руку").
func _coffee() -> void:
	var c: Dictionary = _d["coffee"]
	var held: String = Hud.held_item
	if held.is_empty() and (GameState.has_item("cup_empty") or GameState.has_item("cup_old")) and _state in ["wash", "coffee1", "coffee2"]:
		_thought.show_text(str(c["need_cup"]), THOUGHT_TIME)
		return
	if GameState.has_item("cup_full"):
		_thought.show_text(str(c["cup_full"]), THOUGHT_TIME)
		return
	if GameState.has_item("cup_old"):
		_thought.show_text(str(c["need_wash"]), THOUGHT_TIME)
		return
	if not (_state in ["coffee1", "coffee2"]) or not GameState.has_item("cup_empty"):
		_thought.show_text(str(c["enough"]), THOUGHT_TIME)
		return
	_busy = true
	_player.frozen = true
	Hud.set_held("")
	Audio.sfx(POUR, -6.0)
	await get_tree().create_timer(1.4).timeout
	GameState.replace_item("cup_empty", "cup_full")
	var first: bool = _state == "coffee1"
	GameState.item_thoughts["cup_full:drink"] = str(c["drink_first" if first else "drink_second"])
	_thought.show_text(str(c["poured_first" if first else "poured_second"]), THOUGHT_TIME)
	_state = "drink1" if first else "drink2"
	Hud.set_objective(str(_d["objectives"][_state]))
	_player.frozen = false
	_busy = false


func _open_closeup(sd: Dictionary) -> void:
	var doc: Dictionary = {"closeup": str(sd["closeup"]), "text": str(sd.get("text", "")), "reaction": str(sd.get("reaction", ""))}
	for k: String in ["text_rect", "texts", "text_rects"]:
		if sd.has(k):
			doc[k] = sd[k]
	Hud.open_closeup(doc)


## A door to another room: remember where we are in the story, then go.
func _go_through(sd: Dictionary) -> void:
	_busy = true
	_player.frozen = true
	GameState.set_flag("walk_state", _state)
	GameState.set_flag("walk_return_x", _player.position.x)
	GameState.set_flag("radio_station", _radio.station())
	if _radio.is_on():
		Audio.duck_music(false)
	Audio.sfx(DOOR, -6.0)
	SceneRouter.go_to(str(sd["target"]), 0.3)


## The locker can be looked through any time; the things are taken only after the coffee.
func _update_locker_lock() -> void:
	if _state in ["wash", "coffee1", "drink1", "coffee2", "drink2"]:
		GameState.take_locks["alexei_locker"] = str(_d["locker_wait"])
	else:
		GameState.take_locks.erase("alexei_locker")


## All the things from the locker are on him: now back to the desk.
func _check_locker() -> void:
	if _state == "leave":
		Hud.set_objective(_objective())
		return
	if _state != "home":
		return
	for t: String in HOME_THINGS:
		if not GameState.has_item(t):
			return
	_state = "back_to_desk"
	Hud.set_objective(str(_d["objectives"][_state]))
	_thought.show_text(str(_d["locker_done"]), THOUGHT_TIME)


## Drinking happens in the inventory; the scene only moves the story on.
func _on_item_used(id: String, action: String) -> void:
	if id == "coat" and action == "wear":  # Alexei's thought comes from the inventory (item_thoughts)
		GameState.set_flag("coat_on", true)
		GameState.item_thoughts.erase("coat:wear")
		_player.set_coat(true)
		if _state == "leave":
			Hud.set_objective(_objective())
		return
	if id != "cup_full" or action != "drink":
		return
	GameState.item_thoughts.erase("cup_full:drink")
	match _state:
		"drink1":
			_state = "coffee2"
		"drink2":
			_state = "home"  # free to explore; he goes to the desk when the player decides
		_:
			return
	Hud.set_objective(_objective())
	_update_locker_lock()


func _use_radio() -> void:
	var i: int = _radio.cycle()
	var th: Array = _d["radio"]["thoughts"]
	if i >= 0 and i < th.size():
		var coded: bool = bool(_radio.stations[i].get("code", false))  # its caption is over the radio
		_thought.show_text(str(th[i]) if coded else "%s.  %s" % [_radio.station_name(), str(th[i])], THOUGHT_TIME)
	else:
		_thought.hide_box()


## Packing up at the desk — and the phone rings right next to him.
func _pack() -> void:
	_busy = true
	_player.frozen = true
	if _radio.is_on():
		_radio.turn_off()
	_thought.show_text(str(_d["coffee"]["pack"]))
	await get_tree().create_timer(2.6).timeout
	GameState.set_flag("walk_state", null)
	GameState.set_flag("radio_station", -1)
	Audio.play_loop(RING, -4.0)
	_thought.show_text(str(_d["coffee"]["phone_thought"]), THOUGHT_TIME)
	_state = "phone"
	Hud.set_objective(str(_d["objectives"]["phone"]))
	_busy = false


func _answer_phone() -> void:
	_busy = true
	_player.frozen = true
	Audio.stop_loop()
	Audio.sfx(PICKUP, -4.0)
	SceneRouter.go_to(CALL_SCENE, 1.2)


func _objective() -> String:
	if _state == "leave":
		if not _has_home_things():
			return str(_d["objectives"]["leave_things"])
		if not bool(GameState.get_flag("coat_on", false)):
			return str(_d["objectives"]["leave"])
		return str(_d["objectives"]["leave_go"])
	return str(_d["objectives"][_state])


## Keys, notebook, umbrella with him and the coat taken (or already on).
func _has_home_things() -> bool:
	for t: String in HOME_THINGS:
		if not GameState.has_item(t):
			return false
	return GameState.has_item("coat") or bool(GameState.get_flag("coat_on", false))


## Out through the precinct door into the rain → the drive.
func _leave_precinct() -> void:
	_busy = true
	_player.frozen = true
	if _radio.is_on():
		_radio.turn_off()
	GameState.set_flag("walk_state", null)
	GameState.set_flag("walk_return_x", null)
	Audio.sfx(DOOR, -6.0)
	SceneRouter.go_to(DRIVE_SCENE, 1.0)


## For a save: where Alexei stands and the story step (SaveGame merges these flags).
func save_state() -> Dictionary:
	var st: String = _state
	if st == "phone":
		st = "back_to_desk"  # the ringing is not saved: he packs up again and the phone rings again
	return {"walk_state": st, "walk_return_x": _player.position.x, "radio_station": _radio.station()}
