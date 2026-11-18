extends Node2D
## s01 format 2: Alexei's desk. Documents lift/twitch on hover; click -> close-up.

const THOUGHT_DELAY: float = 0.8
const NOT_READY_TIME: float = 3.0
const MARKER_THOUGHT_TIME: float = 4.0
const PHONE_DELAY: float = 1.5
const DOC_COUNT: int = 3

@onready var _thought: ThoughtBox = $UI/Root/ThoughtBox
@onready var _docs: Node2D = $Documents
@onready var _view: DocumentView = $DocumentView
@onready var _markers: Control = $UI/Root/Markers
@onready var _answer: Button = $UI/Root/AnswerButton

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
	if _viewed.size() >= DOC_COUNT and not _phone_ringing:
		_phone_ringing = true
		await get_tree().create_timer(PHONE_DELAY).timeout
		_start_phone()
	else:
		_set_docs_interactive(true)


## All documents read: the background music stops, only the phone rings until answered.
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
	create_tween().tween_property(_answer, "modulate:a", 0.0, 0.3)
	_thought.show_text(str(_data.get("after_answer", "")))


func _set_docs_interactive(value: bool) -> void:
	for d: Node in _docs.get_children():
		if d is DeskDocument:
			(d as DeskDocument).set_interactive(value)
