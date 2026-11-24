extends Node2D

const THOUGHT_DELAY: float = 0.8
const NOT_READY_TIME: float = 3.0
const MARKER_THOUGHT_TIME: float = 4.0
const PHONE_DELAY: float = 1.5
const DOC_COUNT: int = 3
const CALL_SCENE: String = "res://scenes/s01/call.tscn"
const WALK_SCENE: String = "res://scenes/s01/walk.tscn"
const PICKUP_SFX: String = "res://assets/audio/sfx/pickup.wav"
const PICKUP_HOLD: float = 1.2
const DESK_NO_MUG: String = "res://assets/backgrounds/s01/desk_nomug.png"
const LED_POS: Vector2 = Vector2(524, 120)
const LED_PERIOD: float = 1.4
const DARK: Color = Color(0.3, 0.33, 0.46)
const DARK_PAPER: Color = Color(0.42, 0.45, 0.58)
const SWITCH_SFX: String = "res://assets/audio/sfx/radio_click.wav"

@onready var _thought: ThoughtBox = $UI/Root/ThoughtBox
@onready var _docs: Node2D = $Documents
@onready var _view: DocumentView = $DocumentView
@onready var _markers: Control = $UI/Root/Markers
@onready var _answer: Button = $UI/Root/AnswerButton
@onready var _computer: ClickZone = $UI/Root/ComputerZone
@onready var _terminal: Terminal = $Terminal

var _term: Dictionary = {}
var _terminal_seen: bool = false
var _report_choices: Dictionary = {}

var _viewed: Dictionary = {}
var _current_doc: String = ""
var _phone_ringing: bool = false

var _data: Dictionary = {}
var _led: ColorRect
var _led_glow: ColorRect
var _led_t: float = 0.0
var _lamp_on: bool = true
var _lamp_lines: Dictionary = {}
var _dark: CanvasModulate
@onready var _lamp_light: PointLight2D = $Lights/LampLight


func _ready() -> void:
	Audio.play_start_ambience()
	_data = DialogueData.load_file("s01_precinct").get("desk", {})
	_build_led()
	_dark = CanvasModulate.new()
	_dark.color = Color.WHITE
	add_child(_dark)
	_answer.visible = false
	_answer.text = str(_data.get("answer_button", ""))
	_answer.pressed.connect(_on_answer)
	Audio.bind_button(_answer)
	Hud.set_hud_visible(true)
	Hud.set_objective(str(_data.get("objective", "")), true)
	for d: Node in _docs.get_children():
		if d is DeskDocument:
			(d as DeskDocument).clicked.connect(_on_doc_clicked)
	_view.closed.connect(_on_view_closed)
	_term = DialogueData.load_file("s01_terminal")
	_computer.activated.connect(_open_terminal)
	_terminal.first_thought = str(_data.get("markers", {}).get("computer", ""))
	_terminal.closed.connect(_on_terminal_closed)
	_terminal.report_filed.connect(func(c: Dictionary) -> void: _report_choices = c)
	for m: Node in _markers.get_children():
		if m is HintMarker:
			(m as HintMarker).activated.connect(_on_marker)
	_restore()
	if bool(GameState.get_flag("desk_lamp_off", false)):
		_set_lamp(false, 0.0)
	if bool(GameState.get_flag("desk_report_done", false)):
		_terminal.report_done = true
		_phone_ringing = true
		_computer.set_enabled(false)
		_set_docs_interactive(false)
		_coffee_break()
		return
	await get_tree().create_timer(THOUGHT_DELAY).timeout
	_thought.show_text(str(_data.get("intro_thought", "")))


func save_state() -> Dictionary:
	return {"desk_viewed": _viewed.keys(), "desk_report_unlocked": _terminal.report_unlocked,
		"desk_terminal_seen": _terminal_seen, "desk_report_done": _terminal.report_done, "desk_lamp_off": not _lamp_on}


func _set_lamp(on: bool, time: float) -> void:
	_lamp_on = on
	GameState.set_flag("desk_lamp_off", not on)
	if time > 0.0:
		Audio.sfx(SWITCH_SFX, -8.0, 1.3 if on else 1.1)
	var t: Tween = create_tween()
	t.tween_property(_dark, "color", Color.WHITE if on else DARK, maxf(time, 0.01))
	_lamp_light.set("base_energy", 0.16 if on else 0.0)
	_lamp_light.energy = 0.16 if on else 0.0
	_lamp_light.visible = on


func _lamp_line(kind: String) -> String:
	var lines: Array = _data.get("lamp", {}).get(kind, [])
	if lines.is_empty():
		return ""
	var i: int = int(_lamp_lines.get(kind, 0))
	_lamp_lines[kind] = (i + 1) % lines.size()
	return str(lines[i])


func _restore() -> void:
	for k: Variant in GameState.get_flag("desk_viewed", []):
		_viewed[str(k)] = true
	_terminal_seen = bool(GameState.get_flag("desk_terminal_seen", false))
	if bool(GameState.get_flag("desk_report_unlocked", false)):
		_terminal.report_unlocked = true
		Hud.set_objective(str(_data.get("report_objective", "")))


func _on_doc_clicked(doc_id: String) -> void:
	var docs: Dictionary = _data.get("documents", {})
	var doc: Dictionary = docs.get(doc_id, {})
	if doc.is_empty():
		return
	_current_doc = doc_id
	_thought.hide_box()
	_set_docs_interactive(false)
	_view.shade = Color.WHITE if _lamp_on else DARK_PAPER
	if not _lamp_on:
		doc = doc.duplicate()
		doc["reaction"] = _lamp_line("dark_read") + "\n" + str(doc.get("reaction", ""))
	_view.open(doc)


func _on_marker(marker_id: String) -> void:
	if marker_id == "family" and not _view.is_open():
		_thought.hide_box()
		_current_doc = ""
		_view.shade = Color.WHITE if _lamp_on else DARK_PAPER
		_view.open(_data["family"])
		return
	if marker_id == "lamp":
		_set_lamp(not _lamp_on, 0.35)
		_thought.show_text(_lamp_line("on" if _lamp_on else "off"), MARKER_THOUGHT_TIME)
		return
	var markers: Dictionary = _data.get("markers", {})
	if markers.has(marker_id):
		_thought.show_text(str(markers[marker_id]), MARKER_THOUGHT_TIME)


func _on_view_closed() -> void:
	_set_docs_interactive(true)
	if _current_doc.is_empty():
		return
	_viewed[_current_doc] = true
	if _viewed.size() >= DOC_COUNT and not _terminal.report_unlocked:
		_terminal.report_unlocked = true
		Hud.set_objective(str(_data.get("report_objective", "")))


func _build_led() -> void:
	_led_glow = ColorRect.new()
	_led_glow.position = LED_POS - Vector2(2, 2)
	_led_glow.size = Vector2(8, 6)
	_led_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_led_glow)
	_led = ColorRect.new()
	_led.position = LED_POS
	_led.size = Vector2(4, 2)
	_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_led)
	move_child(_led_glow, $Background.get_index() + 1)
	move_child(_led, _led_glow.get_index() + 1)


func _process(delta: float) -> void:
	_led_t += delta
	if _terminal.is_open():
		_led.color = Color(0.45, 1.0, 0.5)
		_led_glow.color = Color(0.45, 1.0, 0.5, 0.25)
	else:
		var k: float = 0.5 + 0.5 * sin(_led_t * TAU / LED_PERIOD)
		_led.color = Color(1.0, 0.62, 0.18).lerp(Color(0.3, 0.16, 0.06), 1.0 - k)
		_led_glow.color = Color(1.0, 0.6, 0.2, 0.22 * k)


func _open_terminal() -> void:
	if _phone_ringing or _view.is_open():
		return
	_thought.hide_box()
	_set_docs_interactive(false)
	_computer.set_enabled(false)
	_terminal.open()


func _on_terminal_closed() -> void:
	_computer.set_enabled(true)
	_set_docs_interactive(true)
	if _terminal.report_done and not _phone_ringing:
		_phone_ringing = true
		_computer.set_enabled(false)
		_set_docs_interactive(false)
		_thought.show_text(_report_thought(), 0.0)
		await get_tree().create_timer(PHONE_DELAY + 2.0).timeout
		_coffee_break()
	elif not _terminal_seen:
		_thought.show_text(str(_term.get("thoughts", {}).get("computer_first_exit", "")), MARKER_THOUGHT_TIME)
	_terminal_seen = true


func _coffee_break() -> void:
	_thought.show_text(str(_data.get("coffee_thought", "")), 0.0)
	await get_tree().create_timer(0.8).timeout
	var take: Button = _action_button(str(_data.get("take_cup_button", "")))
	await take.pressed
	take.queue_free()
	GameState.add_item("cup_old")
	var mug: Control = _markers.get_node_or_null("Mug")
	if mug:
		mug.visible = false
	($Background as Sprite2D).texture = load(DESK_NO_MUG)
	await get_tree().create_timer(0.5).timeout
	var stand: Button = _action_button(str(_data.get("stand_button", "")))
	await stand.pressed
	stand.disabled = true
	_thought.hide_box()
	SceneRouter.go_to(WALK_SCENE)


func _action_button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.position = _answer.position
	b.custom_minimum_size = _answer.size
	b.modulate.a = 0.0
	_answer.get_parent().add_child(b)
	Audio.bind_button(b)
	create_tween().tween_property(b, "modulate:a", 1.0, 0.4)
	return b


func _report_thought() -> String:
	var closed_votes: int = 0
	for v: String in _report_choices.values():
		if v == "a":
			closed_votes += 1
	GameState.set_flag("report_cole", _report_choices)
	GameState.set_flag("report_cole_closed", closed_votes == _report_choices.size())
	var th: Dictionary = _term.get("thoughts", {})
	if closed_votes == _report_choices.size():
		return str(th.get("report_closed", ""))
	if closed_votes == 0:
		return str(th.get("report_open", ""))
	return str(th.get("report_mixed", ""))


func _start_phone() -> void:
	Audio.stop_music(0.5)
	Audio.play_loop(Audio.PHONE_RING)
	Hud.set_objective(str(_data.get("phone_objective", "")))
	_answer.modulate.a = 0.0
	_answer.visible = true
	create_tween().tween_property(_answer, "modulate:a", 1.0, 0.4)


func _on_answer() -> void:
	_answer.disabled = true
	Audio.stop_loop()
	Audio.sfx(PICKUP_SFX, -4.0)
	SceneRouter.go_to(CALL_SCENE, PICKUP_HOLD)


func _set_docs_interactive(value: bool) -> void:
	for d: Node in _docs.get_children():
		if d is DeskDocument:
			(d as DeskDocument).set_interactive(value)
