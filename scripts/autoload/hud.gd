extends CanvasLayer
## Gameplay HUD. Autoload: Hud.
## Top-right icons: current task (hover/click shows it) and dialogue history (click opens log).

const TASK_ICON: String = "res://assets/ui/icon_task.png"
const HISTORY_ICON: String = "res://assets/ui/icon_history.png"
const ICON_SIZE: Vector2 = Vector2(24, 24)
const MARGIN: float = 8.0
const PANEL_BG: Color = Color(0.03, 0.03, 0.05, 0.94)
const THOUGHT_COLOR: String = "#9fb0b8"
const TASK_SHOW_TIME: float = 3.5

var _root: Control
var _task_btn: TextureButton
var _history_btn: TextureButton
var _task_panel: PanelContainer
var _task_label: Label
var _task_hide_left: float = -1.0
var _overlay: Control
var _log_box: VBoxContainer
var _scroll: ScrollContainer
var _objective: String = ""
var _last_entry: String = ""
var _history_open: bool = false


func _ready() -> void:
	layer = 60
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_task_btn = _make_icon(TASK_ICON, Vector2(640.0 - MARGIN - ICON_SIZE.x, MARGIN), "!")
	_history_btn = _make_icon(HISTORY_ICON, Vector2(640.0 - MARGIN * 1.5 - ICON_SIZE.x * 2.0, MARGIN), "≡")
	_task_btn.mouse_entered.connect(func() -> void: _show_task(-1.0))
	_task_btn.mouse_exited.connect(func() -> void: _task_hide_left = 0.6)
	_task_btn.pressed.connect(func() -> void: _show_task(TASK_SHOW_TIME))
	_history_btn.pressed.connect(toggle_history)
	_build_task_panel()
	_build_history()
	set_hud_visible(false)


func _make_icon(path: String, pos: Vector2, fallback: String) -> TextureButton:
	var b: TextureButton = TextureButton.new()
	b.position = pos
	b.size = ICON_SIZE
	b.custom_minimum_size = ICON_SIZE
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.modulate = Color(1, 1, 1, 0.8)
	if ResourceLoader.exists(path):
		b.texture_normal = load(path)
	else:  # placeholder until the icon art exists
		var l: Label = Label.new()
		l.text = fallback
		l.size = ICON_SIZE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	b.mouse_entered.connect(func() -> void: b.modulate = Color.WHITE)
	b.mouse_exited.connect(func() -> void: b.modulate = Color(1, 1, 1, 0.8))
	Audio.bind_icon(b)
	_root.add_child(b)
	return b


func _panel_style(margin: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.22, 0.24, 0.28, 1)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(margin)
	return sb


func _build_task_panel() -> void:
	_task_panel = PanelContainer.new()
	_task_panel.add_theme_stylebox_override("panel", _panel_style(6.0))
	_task_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_label = Label.new()
	_task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_label.custom_minimum_size = Vector2(200, 0)
	_task_panel.add_child(_task_label)
	_task_panel.visible = false
	_root.add_child(_task_panel)


func _build_history() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_root.add_child(_overlay)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb and mb.pressed:
			close_history())
	_overlay.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(8.0))
	panel.position = Vector2(110, 40)
	panel.size = Vector2(420, 280)
	_overlay.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var title: Label = Label.new()
	title.text = "История"
	title.add_theme_color_override("font_color", Color(0.7, 0.78, 0.82))
	col.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(404, 236)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_theme_constant_override("separation", 5)
	_scroll.add_child(_log_box)


func _process(delta: float) -> void:
	if _task_hide_left > 0.0:
		_task_hide_left -= delta
		if _task_hide_left <= 0.0:
			_task_panel.visible = false


func _input(event: InputEvent) -> void:
	if not _history_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		close_history()


# --- API ---------------------------------------------------------------

func set_hud_visible(v: bool) -> void:
	_task_btn.visible = v
	_history_btn.visible = v
	if not v:
		_task_panel.visible = false
		close_history()


func set_objective(text: String, announce: bool = true) -> void:
	if text == _objective:
		return
	_objective = text
	_task_label.text = text
	if announce and _task_btn.visible:
		var t: Tween = create_tween()
		t.tween_property(_task_btn, "scale", Vector2(1.25, 1.25), 0.12)
		t.tween_property(_task_btn, "scale", Vector2.ONE, 0.2)
		_show_task(TASK_SHOW_TIME)


func log_say(speaker: String, text: String, color: String = "#ffffff") -> void:
	_add_entry("[color=%s]%s:[/color] %s" % [color, speaker, text])


func log_thought(text: String) -> void:
	_add_entry("[color=%s]%s[/color]" % [THOUGHT_COLOR, text])


func is_blocking() -> bool:
	return _history_open


func toggle_history() -> void:
	if _history_open:
		close_history()
	else:
		open_history()


func open_history() -> void:
	_history_open = true
	_overlay.visible = true
	_task_panel.visible = false
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func close_history() -> void:
	_history_open = false
	if _overlay:
		_overlay.visible = false


func clear_log() -> void:
	for c: Node in _log_box.get_children():
		c.queue_free()
	_last_entry = ""


# --- internals ---------------------------------------------------------

func _show_task(duration: float) -> void:
	if _objective.is_empty():
		return
	_task_panel.visible = true
	_task_panel.reset_size()
	var s: Vector2 = _task_panel.get_combined_minimum_size()
	_task_panel.position = Vector2(640.0 - MARGIN - s.x, MARGIN + ICON_SIZE.y + 4.0)
	_task_hide_left = duration


func _add_entry(bbcode: String) -> void:
	if bbcode == _last_entry:
		return
	_last_entry = bbcode
	var r: RichTextLabel = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(396, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = bbcode
	_log_box.add_child(r)
