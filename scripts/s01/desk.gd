extends Node2D
## s01 format 2: Alexei's desk. Documents lift/twitch on hover; click -> close-up.

const THOUGHT_DELAY: float = 0.8
const NOT_READY_TIME: float = 3.0
const MARKER_THOUGHT_TIME: float = 4.0
const PHONE_DELAY: float = 1.5
const DOC_COUNT: int = 3
const CALL_SCENE: String = "res://scenes/s01/call.tscn"
const PICKUP_SFX: String = "res://assets/audio/sfx/pickup.wav"
const PICKUP_HOLD: float = 1.2

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


func _ready() -> void:
	_data = DialogueData.load_file("s01_precinct").get("desk", {})
	_answer.visible = false
	_answer.text = str(_data.get("answer_button", ""))
	_answer.pressed.connect(_on_answer)
	Audio.bind_button(_answer)
	Hud.set_hud_visible(true)
	Hud.set_objective(str(_data.get("objective", "")))
	for d: Node in _docs.get_children():
		if d is DeskDocument:
			(d as DeskDocument).clicked.connect(_on_doc_clicked)
	_view.closed.connect(_on_view_closed)
	_term = DialogueData.load_file("s01_terminal")
	_computer.activated.connect(_open_terminal)
	_terminal.closed.connect(_on_terminal_closed)
	_terminal.report_filed.connect(func(c: Dictionary) -> void: _report_choices = c)
	for m: Node in _markers.get_children():
		if m is HintMarker:
			(m as HintMarker).activated.connect(_on_marker)
	await get_tree().create_timer(THOUGHT_DELAY).timeout
	_thought.show_text(str(_data.get("intro_thought", "")))


func _on_doc_clicked(doc_id: String) -> void:
	var docs: Dictionary = _data.get("documents", {})
	var doc: Dictionary = docs.get(doc_id, {})
	if doc.is_empty():
		return
	_current_doc = doc_id
	_thought.hide_box()
	_set_docs_interactive(false)
	_view.open(doc)


func _on_marker(marker_id: String) -> void:
	var markers: Dictionary = _data.get("markers", {})
	if markers.has(marker_id):
		_thought.show_text(str(markers[marker_id]), MARKER_THOUGHT_TIME)


func _on_view_closed() -> void:
	_viewed[_current_doc] = true
	_set_docs_interactive(true)
	if _viewed.size() >= DOC_COUNT and not _terminal.report_unlocked:
		_terminal.report_unlocked = true  # all materials read -> the report can be filed
		Hud.set_objective(str(_data.get("report_objective", "")))


func _open_terminal() -> void:
	if _phone_ringing or _view.is_open():
		return
	_thought.hide_box()
	_set_docs_interactive(false)
	_computer.set_enabled(false)
	_terminal.open()


## Closing the computer: first time — a thought; after the report — Alexei weighs
## his choice, then the phone rings.
func _on_terminal_closed() -> void:
	_computer.set_enabled(true)
	_set_docs_interactive(true)
	if _terminal.report_done and not _phone_ringing:
		_phone_ringing = true
		_computer.set_enabled(false)
		_set_docs_interactive(false)
		_thought.show_text(_report_thought(), 0.0)
		await get_tree().create_timer(PHONE_DELAY + 2.0).timeout
		_thought.hide_box()
		_start_phone()
	elif not _terminal_seen:
		_thought.show_text(str(_term.get("thoughts", {}).get("computer_first_exit", "")), MARKER_THOUGHT_TIME)
	_terminal_seen = true


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


## All documents read: the background music stops, only the phone rings until answered.
func _start_phone() -> void:
	Audio.stop_music(0.5)
	Audio.play_loop(Audio.PHONE_RING)
	Hud.set_objective(str(_data.get("phone_objective", "")))
	_answer.modulate.a = 0.0
	_answer.visible = true
	create_tween().tween_property(_answer, "modulate:a", 1.0, 0.4)


## Phone answered: ring stops, black screen while Alexei picks up the receiver, then the call.
func _on_answer() -> void:
	_answer.disabled = true
	Audio.stop_loop()
	Audio.sfx(PICKUP_SFX, -4.0)
	SceneRouter.go_to(CALL_SCENE, PICKUP_HOLD)


func _set_docs_interactive(value: bool) -> void:
	for d: Node in _docs.get_children():
		if d is DeskDocument:
			(d as DeskDocument).set_interactive(value)
