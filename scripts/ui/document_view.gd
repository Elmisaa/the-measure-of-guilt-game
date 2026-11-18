class_name DocumentView
extends CanvasLayer
## Close-up of a document: dimmed scene, enlarged paper with text drawn by Godot,
## then the hero's reaction at the bottom. Click/Space: show reaction -> close. Esc: close.

signal closed

const FADE_TIME: float = 0.25
const REACTION_DELAY: float = 1.0
const INK: Color = Color(0.13, 0.11, 0.1, 1)

var _root: Control
var _dim: ColorRect
var _paper: TextureRect
var _text: Label
var _thought: ThoughtBox
var _stage: int = 0  # 0 closed, 1 reading, 2 reaction shown
var _reaction: String = ""
var _timer: SceneTreeTimer


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.75)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	_root.add_child(_dim)
	_paper = TextureRect.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_paper)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", INK)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_text.add_theme_constant_override("line_spacing", 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_text)
	_thought = ThoughtBox.new()
	_root.add_child(_thought)
	_root.modulate.a = 0.0
	visible = false


## doc: {"closeup": res path, "text_rect": [x, y, w, h] in close-up pixels, "text": "...", "reaction": "..."}
func open(doc: Dictionary) -> void:
	var audio: Node = get_node_or_null("/root/Audio")
	if audio:
		audio.sfx("res://assets/audio/sfx/page_flip.wav", -8.0, randf_range(0.95, 1.05))
	var closeup: String = str(doc.get("closeup", ""))
	if closeup.is_empty():
		_open_placeholder(doc)
	else:
		var tex: Texture2D = load(closeup)
		_paper.texture = tex
		_paper.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		var s: Vector2 = tex.get_size()
		_paper.size = s
		_paper.position = Vector2(floorf((640.0 - s.x) / 4.0) * 2.0, floorf((330.0 - s.y) / 4.0) * 2.0)  # keep on the 2px grid
		var r: Array = doc.get("text_rect", [0, 0, s.x, s.y])
		_text.position = _paper.position + Vector2(r[0], r[1])
		_text.size = Vector2(r[2], r[3])
		_set_text_style(false)
	_text.text = str(doc.get("text", ""))
	_reaction = str(doc.get("reaction", ""))
	_thought.hide_box()
	visible = true
	_stage = 1
	create_tween().tween_property(_root, "modulate:a", 1.0, FADE_TIME)
	_timer = get_tree().create_timer(REACTION_DELAY)
	_timer.timeout.connect(_show_reaction)


## No close-up art yet: the desk sprite at 2x on the left, text on a dark panel on the right.
func _open_placeholder(doc: Dictionary) -> void:
	var tex: Texture2D = load(str(doc.get("sprite", "")))
	var s: Vector2 = tex.get_size() * 2.0
	_paper.texture = tex
	_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paper.stretch_mode = TextureRect.STRETCH_SCALE
	_paper.size = s
	_paper.position = Vector2(40.0, floorf((330.0 - s.y) / 4.0) * 2.0)
	_text.position = Vector2(_paper.position.x + s.x + 20.0, 24.0)
	_text.size = Vector2(640.0 - _text.position.x - 24.0, 290.0)
	_set_text_style(true)


func _set_text_style(on_panel: bool) -> void:
	if on_panel:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.07, 0.95)
		sb.set_content_margin_all(8.0)
		_text.add_theme_stylebox_override("normal", sb)
		_text.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	else:
		_text.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_text.add_theme_color_override("font_color", INK)


func is_open() -> bool:
	return _stage != 0


func _show_reaction() -> void:
	if _stage != 1:
		return
	_stage = 2
	if not _reaction.is_empty():
		_thought.show_text(_reaction)


func _step() -> void:
	if _stage == 1:
		_show_reaction()
	elif _stage == 2:
		close()


func close() -> void:
	if _stage == 0:
		return
	_stage = 0
	_thought.hide_box()
	var t: Tween = create_tween()
	t.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	t.tween_callback(func() -> void:
		visible = false
		closed.emit())


func _on_dim_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_step()


func _unhandled_input(event: InputEvent) -> void:
	if _stage == 0:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_step()
