extends Node2D
## s01 format 1: side view of the precinct. Speech lines -> "Изучить документы" -> desk.

const DESK_SCENE: String = "res://scenes/s01/desk.tscn"
const CHARS_PER_SEC: float = 30.0
const START_DELAY: float = 1.2
const MARKER_THOUGHT_TIME: float = 4.0

@onready var _speech: Control = $UI/Root/Speech
@onready var _speaker: Label = $UI/Root/Speech/Speaker
@onready var _line: Label = $UI/Root/Speech/Line
@onready var _thought: ThoughtBox = $UI/Root/ThoughtBox
@onready var _button: Button = $UI/Root/StudyButton
@onready var _markers: Control = $UI/Root/Markers

var _data: Dictionary = {}
var _data_all: Dictionary = {}
var _speakers: Dictionary = {}
var _lines: Array = []
var _index: int = -1
var _typing: Tween
var _typing_label: Label
var _started: bool = false
var _done: bool = false
var _voice_pitch: float = 1.0
var _shown_chars: int = 0


func _ready() -> void:
	var all: Dictionary = DialogueData.load_file("s01_precinct")
	_data_all = all
	_data = all.get("exposition", {})
	_speakers = all.get("speakers", {})
	_lines = _data.get("lines", [])
	_speech.modulate.a = 0.0
	_button.visible = false
	_button.text = str(_data.get("button", ""))
	Hud.set_hud_visible(true)
	Hud.set_objective(str(_data.get("objective", "")), false)
	_button.pressed.connect(_on_study_pressed)
	Audio.bind_button(_button)
	for m: Node in _markers.get_children():
		if m is HintMarker:
			(m as HintMarker).activated.connect(_on_marker)
	if Letterbox.is_shown():
		await get_tree().create_timer(0.4).timeout
		await Letterbox.retract()
	await get_tree().create_timer(START_DELAY).timeout
	_started = true
	_next_line()


func _unhandled_input(event: InputEvent) -> void:
	if not _started or _done or Hud.is_blocking():
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var click: bool = mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()


## Speech blips: one soft blip every 2 letters while the line is being typed.
func _process(_delta: float) -> void:
	if not (_typing and _typing.is_running()) or _typing_label != _line:
		return
	var n: int = _line.visible_characters
	if n < 0:
		n = _line.text.length()
	while _shown_chars < n:
		var c: String = _line.text[_shown_chars]
		_shown_chars += 1
		if _shown_chars % 2 == 0 and c.strip_edges() != "" and not c in ".,!?…—-:;\"«»“”":
			Audio.blip(_voice_pitch)


func _advance() -> void:
	if _typing and _typing.is_running():
		_typing.kill()
		_typing_label.visible_ratio = 1.0
		return
	_next_line()


func _next_line() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[_index]
	var text: String = str(line.get("text", ""))
	if line.get("type", "say") == "think":
		_fade(_speech, 0.0)
		_thought.show_text(text)
		return
	_thought.hide_box()
	var speaker: String = str(line.get("speaker", ""))
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color", Color.from_string(str(_speakers.get(speaker, "#ffffff")), Color.WHITE))
	_line.text = text
	Hud.log_say(speaker, text, str(_speakers.get(speaker, "#ffffff")))
	_voice_pitch = float(_data_all.get("voice_pitch", {}).get(speaker, 1.0))
	_shown_chars = 0
	_fade(_speech, 1.0)
	_type(_line)


func _type(label: Label) -> void:
	_typing_label = label
	label.visible_ratio = 0.0
	_typing = create_tween()
	_typing.tween_property(label, "visible_ratio", 1.0, maxf(0.1, label.text.length() / CHARS_PER_SEC))


func _finish() -> void:
	_done = true
	Hud.set_objective(str(_data.get("objective_done", "")))
	_thought.hide_box()
	_fade(_speech, 0.0)
	_button.modulate.a = 0.0
	_button.visible = true
	_fade(_button, 1.0)


func _on_marker(marker_id: String) -> void:
	var markers: Dictionary = _data.get("markers", {})
	if not markers.has(marker_id):
		return
	if not _done and _index >= 0 and _index < _lines.size() and _lines[_index].get("type", "say") == "think":
		return  # don't cover a story thought
	_thought.show_text(str(markers[marker_id]), MARKER_THOUGHT_TIME)


func _on_study_pressed() -> void:
	_button.disabled = true
	SceneRouter.go_to(DESK_SCENE)


func _fade(node: CanvasItem, to: float) -> void:
	create_tween().tween_property(node, "modulate:a", to, 0.3)
