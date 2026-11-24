extends PanelContainer

var _settings: Node
var _buttons: Dictionary = {}
var _status: Label
var _editing: String = ""


func _ready() -> void:
	hide()
	_settings = get_node("/root/Settings")
	add_theme_stylebox_override("panel", MenuUI.panel_style())
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var title: Label = Label.new()
	title.text = "Клавиши"
	column.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	column.add_child(grid)
	for action: String in _settings.ACTIONS:
		var button: Button = MenuUI.button("")
		button.custom_minimum_size.x = 230
		button.pressed.connect(_begin_capture.bind(action))
		grid.add_child(button)
		_buttons[action] = button
	_status = Label.new()
	column.add_child(_status)
	var footer: HBoxContainer = HBoxContainer.new()
	column.add_child(footer)
	var reset: Button = MenuUI.button("Сбросить клавиши")
	reset.pressed.connect(func() -> void:
		_editing = ""
		_settings.reset_bindings()
		_refresh()
		_status.text = "Стандартные клавиши восстановлены.")
	footer.add_child(reset)
	var back: Button = MenuUI.button("Назад")
	back.pressed.connect(hide)
	footer.add_child(back)


func open() -> void:
	_editing = ""
	_refresh()
	show()
	reset_size()
	position = ((Vector2(640, 360) - size) * 0.5).floor()
	_buttons.values()[0].grab_focus()


func handle_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _editing.is_empty():
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			hide()
		else:
			MenuUI.wasd_to_focus(event, get_viewport())
		return
	get_viewport().set_input_as_handled()
	if key.physical_keycode == KEY_ESCAPE:
		_editing = ""
		_refresh()
		return
	var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	var error: String = _settings.rebind(_editing, code)
	if not error.is_empty():
		_status.text = error + " Выберите другую клавишу."
		return
	_editing = ""
	_refresh()


func _begin_capture(action: String) -> void:
	_editing = action
	_status.text = "%s: нажмите клавишу. Esc — отмена." % _settings.action_label(action)


func _refresh() -> void:
	for action: String in _buttons:
		var b: Button = _buttons[action]
		b.text = "%s%s  ·  %s" % ["› " if b.has_focus() else "  ", _settings.action_label(action), _settings.key_label(action, true)]
	_status.text = "Выберите действие. ЛКМ — выстрел. Esc — назад."