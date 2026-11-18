extends Node2D
## s01 format 2: Alexei's desk. Documents lift/twitch on hover; click -> close-up.

const THOUGHT_DELAY: float = 0.8
const NOT_READY_TIME: float = 3.0
const MARKER_THOUGHT_TIME: float = 4.0

@onready var _hint: Label = $UI/Root/Hint
@onready var _thought: ThoughtBox = $UI/Root/ThoughtBox
@onready var _docs: Node2D = $Documents
@onready var _view: DocumentView = $DocumentView
@onready var _markers: Control = $UI/Root/Markers

var _data: Dictionary = {}


func _ready() -> void:
	_data = DialogueData.load_file("s01_precinct").get("desk", {})
	_hint.text = str(_data.get("hint", ""))
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
	if str(doc.get("closeup", "")).is_empty():
		_thought.show_text(str(_data.get("not_ready", "")), NOT_READY_TIME)
		return
	_thought.hide_box()
	_set_docs_interactive(false)
	_view.open(doc)


func _on_marker(marker_id: String) -> void:
	var markers: Dictionary = _data.get("markers", {})
	if markers.has(marker_id):
		_thought.show_text(str(markers[marker_id]), MARKER_THOUGHT_TIME)


func _on_view_closed() -> void:
	_set_docs_interactive(true)


func _set_docs_interactive(value: bool) -> void:
	for d: Node in _docs.get_children():
		if d is DeskDocument:
			(d as DeskDocument).set_interactive(value)
