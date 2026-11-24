class_name SettingsPanel
extends Control

signal closed

var _panel: PanelContainer
var _first: Control
var _rows: Array[Control] = []
var _bindings: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", MenuUI.panel_style())
	add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	var title: Label = Label.new()
	title.text = "Настройки"
	title.add_theme_color_override("font_color", Color(0.7, 0.78, 0.82))
	col.add_child(title)
	var st: Node = get_node("/root/Settings")
	_first = _slider_row(col, "Общая громкость", st.master, func(v: float) -> void: st.master = v)
	_slider_row(col, "Музыка", st.music, func(v: float) -> void: st.music = v)
	_slider_row(col, "Звуки и голоса", st.sfx, func(v: float) -> void: st.sfx = v)
	var full: Button = MenuUI.button(_full_text(st.fullscreen))
	full.pressed.connect(func() -> void:
		st.fullscreen = not st.fullscreen
		full.text = full.text.substr(0, 2) + _full_text(st.fullscreen)
		_changed())
	col.add_child(full)
	_rows.append(full)
	var px: Button = MenuUI.button(_px_text(st.pixel_perfect))
	px.pressed.connect(func() -> void:
		st.pixel_perfect = not st.pixel_perfect
		px.text = px.text.substr(0, 2) + _px_text(st.pixel_perfect)
		_changed())
	col.add_child(px)
	_rows.append(px)
	var keys: Button = MenuUI.button("Клавиши")
	col.add_child(keys)
	_rows.append(keys)
	_bindings = preload("res://scripts/ui/key_bindings_panel.gd").new()
	add_child(_bindings)
	keys.pressed.connect(func() -> void:
		_panel.hide()
		_bindings.open())
	_bindings.visibility_changed.connect(func() -> void:
		if not _bindings.visible and visible:
			_panel.show()
			keys.grab_focus())
	var hint: Label = Label.new()
	hint.text = "↑↓ — выбор, ←→ — изменить, Esc — назад"
	hint.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55))
	col.add_child(hint)
	var back: Button = MenuUI.button("Назад")
	back.pressed.connect(close)
	col.add_child(back)
	_rows.append(back)
	for i: int in _rows.size():
		_rows[i].focus_neighbor_top = _rows[i].get_path_to(_rows[(i - 1 + _rows.size()) % _rows.size()])
		_rows[i].focus_neighbor_bottom = _rows[i].get_path_to(_rows[(i + 1) % _rows.size()])


func _px_text(on: bool) -> String:
	return "Чёткие пиксели (с рамкой): " + ("да" if on else "нет")


func _full_text(on: bool) -> String:
	return "Полный экран: " + ("да" if on else "нет")


func _slider_row(parent: Control, label: String, value: float, setter: Callable) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l: Label = Label.new()
	l.text = "  " + label
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_color_override("font_color", MenuUI.COLOR)
	row.add_child(l)
	var s: HSlider = HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.1
	s.value = value
	s.custom_minimum_size = Vector2(110, 12)
	s.focus_mode = Control.FOCUS_ALL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var pct: Label = Label.new()
	pct.text = "%d%%" % roundi(value * 100.0)
	pct.custom_minimum_size = Vector2(30, 0)
	pct.add_theme_color_override("font_color", MenuUI.COLOR)
	row.add_child(pct)
	s.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		pct.text = "%d%%" % roundi(v * 100.0)
		_changed()
		var audio: Node = get_node_or_null("/root/Audio")
		if audio:
			audio.ui_hover())
	s.focus_entered.connect(func() -> void:
		l.text = "› " + label
		l.add_theme_color_override("font_color", MenuUI.COLOR_ON))
	s.focus_exited.connect(func() -> void:
		l.text = "  " + label
		l.add_theme_color_override("font_color", MenuUI.COLOR))
	s.mouse_entered.connect(func() -> void: s.grab_focus())
	_rows.append(s)
	return s


func _changed() -> void:
	var st: Node = get_node("/root/Settings")
	st.apply()
	st.save_settings()


func open() -> void:
	visible = true
	await get_tree().process_frame
	var s: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = s
	_panel.position = ((Vector2(640, 360) - s) / 2.0).floor()
	_first.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_bindings.hide()
	_panel.show()
	closed.emit()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _bindings.visible:
		_bindings.handle_input(event)
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	MenuUI.wasd_to_focus(event, get_viewport())
