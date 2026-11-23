class_name SaveSlotsPanel
extends Control

signal closed
signal loading

var mode: String = "load"
var _panel: PanelContainer
var _col: VBoxContainer
var _title: Label
var _status: Label
var _buttons: Array[Button] = []


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
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 4)
	_panel.add_child(_col)


func open(m: String) -> void:
	mode = m
	for c: Node in _col.get_children():
		c.queue_free()
	_buttons.clear()
	_title = Label.new()
	_title.text = "Сохранить игру" if mode == "save" else "Загрузить игру"
	_title.add_theme_color_override("font_color", Color(0.7, 0.78, 0.82))
	_col.add_child(_title)
	var sg: Node = get_node("/root/SaveGame")
	for slot: String in sg.SLOTS:
		if mode == "save" and slot == sg.AUTO:
			continue
		var empty: bool = (sg.info(slot) as Dictionary).is_empty()
		var b: Button = MenuUI.button(_row_text(slot))
		b.custom_minimum_size = Vector2(300, 0)
		b.disabled = mode == "load" and empty
		b.pressed.connect(_on_slot.bind(slot, b))
		_col.add_child(b)
		_buttons.append(b)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.62, 0.86, 0.72))
	_status.text = "" if mode == "load" or sg.can_save() else "Здесь сохраниться нельзя"
	_col.add_child(_status)
	var back: Button = MenuUI.button("Назад")
	back.pressed.connect(close)
	_col.add_child(back)
	_buttons.append(back)
	var live: Array[Button] = _buttons.filter(func(x: Button) -> bool: return not x.disabled)
	for i: int in live.size():
		live[i].focus_neighbor_top = live[i].get_path_to(live[(i - 1 + live.size()) % live.size()])
		live[i].focus_neighbor_bottom = live[i].get_path_to(live[(i + 1) % live.size()])
	visible = true
	await get_tree().process_frame
	var s: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = s
	_panel.position = ((Vector2(640, 360) - s) / 2.0).floor()
	live[0].grab_focus()


func _row_text(slot: String) -> String:
	var sg: Node = get_node("/root/SaveGame")
	return "%s:  %s" % [sg.slot_name(slot), sg.describe(slot)]


func _on_slot(slot: String, b: Button) -> void:
	var sg: Node = get_node("/root/SaveGame")
	if mode == "save":
		if sg.save(slot):
			b.text = "› " + _row_text(slot)
			_status.text = "Сохранено: " + sg.slot_name(slot)
		else:
			_status.text = "Здесь сохраниться нельзя"
		return
	visible = false
	loading.emit()
	sg.load_slot(slot)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	MenuUI.wasd_to_focus(event, get_viewport())
