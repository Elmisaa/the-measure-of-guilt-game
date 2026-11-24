class_name DocumentView
extends CanvasLayer

signal closed

const FADE_TIME: float = 0.25
const REACTION_DELAY: float = 1.0
const INK: Color = Color(0.13, 0.11, 0.1, 1)

var _root: Control
var _dim: ColorRect
var _paper: TextureRect
var _text: Label
var _extra: Array[Label] = []
var _photos: Array[TextureRect] = []
var _drag: TextureRect
var _drag_off: Vector2
var _thought: ThoughtBox
var _stage: int = 0
var _reaction: String = ""
var shade: Color = Color.WHITE
var _pages: PackedStringArray = PackedStringArray()
var _page: int = 0

const REACTION_PAGE: int = 90
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
		_paper.position = Vector2(floorf((640.0 - s.x) / 4.0) * 2.0, floorf((330.0 - s.y) / 4.0) * 2.0)
		var r: Array = doc.get("text_rect", [0, 0, s.x, s.y])
		_text.position = _paper.position + Vector2(r[0], r[1])
		_text.size = Vector2(r[2], r[3])
		_set_text_style(false)
	_text.text = str(doc.get("text", ""))
	for l: Label in _extra:
		l.queue_free()
	_extra.clear()
	if closeup != "":
		for t: Variant in doc.get("texts", []):
			_add_extra(t as Dictionary)
	for ph: TextureRect in _photos:
		ph.queue_free()
	_photos.clear()
	for ph2: Variant in doc.get("photos", []):
		_add_photo(ph2 as Dictionary)
	_reaction = str(doc.get("reaction", ""))
	_paper.modulate = shade
	_text.modulate = shade
	for l2: Label in _extra:
		l2.modulate = shade
	for ph3: TextureRect in _photos:
		ph3.modulate = shade
	_thought.hide_box()
	visible = true
	_stage = 1
	create_tween().tween_property(_root, "modulate:a", 1.0, FADE_TIME)
	_timer = get_tree().create_timer(REACTION_DELAY)
	_timer.timeout.connect(_show_reaction)


func _open_placeholder(doc: Dictionary) -> void:
	var path: String = str(doc.get("sprite", ""))
	var tex: Texture2D = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	var s: Vector2 = tex.get_size() * 2.0 if tex else Vector2.ZERO
	_paper.texture = tex
	_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paper.stretch_mode = TextureRect.STRETCH_SCALE
	_paper.size = s
	_paper.position = Vector2(40.0, floorf((330.0 - s.y) / 4.0) * 2.0)
	_text.position = Vector2(_paper.position.x + s.x + 20.0, 24.0)
	_text.size = Vector2(640.0 - _text.position.x - 24.0, 290.0)
	_set_text_style(true)


func _add_extra(t: Dictionary) -> void:
	var r: Array = t.get("rect", [0, 0, 100, 20])
	var l: Label = Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", INK)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_constant_override("line_spacing", 0)
	if t.has("size"):
		l.add_theme_font_size_override("font_size", int(t["size"]))
	if bool(t.get("light", false)):
		l.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
	if bool(t.get("center", false)):
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = _paper.position + Vector2(r[0], r[1])
	l.size = Vector2(r[2], r[3])
	l.text = str(t.get("text", ""))
	_root.add_child(l)
	_root.move_child(l, _thought.get_index())
	_extra.append(l)


func _add_photo(d: Dictionary) -> void:
	var tr: TextureRect = TextureRect.new()
	tr.texture = load(str(d["tex"]))
	tr.size = tr.texture.get_size()
	var pos: Array = d.get("pos", [20, 20])
	tr.position = Vector2(pos[0], pos[1])
	tr.mouse_filter = Control.MOUSE_FILTER_STOP
	tr.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tr.gui_input.connect(func(e: InputEvent) -> void: _photo_input(tr, e))
	_root.add_child(tr)
	_root.move_child(tr, _thought.get_index())
	_photos.append(tr)


func _photo_input(tr: TextureRect, e: InputEvent) -> void:
	var mb: InputEventMouseButton = e as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_drag = tr
			_drag_off = tr.get_global_mouse_position() - tr.position
			_root.move_child(tr, _thought.get_index() - 1)
			var audio: Node = get_node_or_null("/root/Audio")
			if audio:
				audio.sfx("res://assets/audio/sfx/paper_rustle.wav", -14.0, randf_range(1.05, 1.2))
		else:
			_drag = null
		tr.accept_event()
	var mm: InputEventMouseMotion = e as InputEventMouseMotion
	if mm and _drag == tr:
		var p: Vector2 = tr.get_global_mouse_position() - _drag_off
		p = p.clamp(Vector2(-tr.size.x / 2.0, -tr.size.y / 2.0), Vector2(640.0 - tr.size.x / 2.0, 360.0 - tr.size.y / 2.0))
		tr.position = (p / 2.0).floor() * 2.0
		tr.accept_event()


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


func is_fully_read() -> bool:
	return _stage == 2 and _page >= _pages.size() - 1


func is_open() -> bool:
	return _stage != 0


func _show_reaction() -> void:
	if _stage != 1:
		return
	_stage = 2
	_page = 0
	_pages = TextPager.pages(_reaction, REACTION_PAGE) if not _reaction.is_empty() else PackedStringArray()
	if _pages.size() > 0:
		_thought.show_text(_pages[0], 0.0, _pages.size() > 1)


func _step() -> void:
	if _stage == 1:
		_show_reaction()
	elif _stage == 2:
		if _page < _pages.size() - 1:
			_page += 1
			_thought.show_text(_pages[_page], 0.0, _page < _pages.size() - 1)
		else:
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
		if is_fully_read():
			close()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_step()
