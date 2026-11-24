extends CanvasLayer

const CURSOR: String = "res://assets/ui/cursor.png"
const CURSOR_HOVER: String = "res://assets/ui/cursor_hover.png"
const CONTROLS: Array = [
	["Ходьба", [["A / D,  ← →", "идти"], ["W / S,  ↑ ↓", "шаг к стене / от стены"], ["Shift", "бег (тратит силы)"],
		["E  или  клик", "взаимодействовать"], ["I", "вещи"], ["Q / ПКМ", "убрать вещь из рук"]]],
	["Сцены и диалоги", [["Клик", "осмотреть, выбрать"], ["Пробел / клик", "дальше по тексту"]]],
	["Меню", [["Esc", "пауза: задания, история, сохранение"], ["↑ ↓ / W S,  Enter", "выбор в меню"]]],
]
const WALK_CONTROLS: Array = [["A / D", "идти"], ["W / S", "шаг вглубь"], ["Shift", "бег"], ["E / клик", "действие"],
	["I", "вещи"], ["Esc", "меню"]]
const STAMINA_POS: Vector2 = Vector2(8, 346)
const STAMINA_SIZE: Vector2 = Vector2(64, 4)
const MARGIN: float = 8.0
const PANEL_BG: Color = Color(0.03, 0.03, 0.05, 0.94)
const THOUGHT_COLOR: String = "#9fb0b8"
const TASK_SHOW_TIME: float = 3.5
const TASK_ANNOUNCE_TIME: float = 5.0

var _root: Control
const TASK_MAX_W: float = 300.0
var _task_panel: PanelContainer
var _task_label: Label
var _task_hide_left: float = -1.0
var _overlay: Control
var _log_box: VBoxContainer
var _scroll: ScrollContainer
var _objective: String = ""
var _last_entry: String = ""
var _history_open: bool = false
var _done_objectives: Array[String] = []
var _log_entries: Array[String] = []
var _info: Control
var _info_box: VBoxContainer
var _info_panel: PanelContainer
var _saves: SaveSlotsPanel
var _controls_hint: PanelContainer
var _controls_tween: Tween
var _cursor_scale: int = 0
var _inventory: InventoryPanel
var _container: InventoryPanel
var _ground_pickup: Button
var _item_thought: ThoughtBox
var _closeup: DocumentView
var _stamina_root: Control
var _stamina_on: bool = false
var _stamina_fill: ColorRect
var _hud_on: bool = false
var _toasts: VBoxContainer
var held_item: String = ""
var _held_icon: TextureRect
var _held_label: Label
var _tut_panel: PanelContainer
var _pause: Control
var _pause_panel: PanelContainer
var _pause_first: Button
var _pause_settings: SettingsPanel
const TITLE_SCENE: String = "res://scenes/menu/title.tscn"
var walk_mode: bool = false
var _tut_label: Label
signal held_changed(item_id: String)
const TOAST_TIME: float = 2.8


func _ready() -> void:
	layer = 60
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_task_panel()
	_build_history()
	_build_stamina()
	_ground_pickup = preload("res://scripts/ui/ground_pickup.gd").new()
	_root.add_child(_ground_pickup)
	_item_thought = ThoughtBox.new()
	_root.add_child(_item_thought)
	_inventory = InventoryPanel.new()
	_root.add_child(_inventory)
	_inventory.action_chosen.connect(_on_item_action)
	_container = InventoryPanel.new()
	_root.add_child(_container)
	_container.action_chosen.connect(_on_container_action)
	_root.move_child(_item_thought, -1)
	_closeup = DocumentView.new()
	add_child(_closeup)
	_closeup.layer = layer + 5
	if not InputMap.has_action("inventory"):
		InputMap.add_action("inventory")
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = KEY_I
		InputMap.action_add_event("inventory", ev)
	GameState.stamina_changed.connect(_on_stamina)
	GameState.item_added.connect(show_item_taken)
	_build_held()
	_build_tutorial()
	_build_pause()
	_build_controls_hint()
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(MARGIN, MARGIN)
	_toasts.add_theme_constant_override("separation", 4)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	set_hud_visible(false)
	_setup_cursor()
	get_tree().root.size_changed.connect(_setup_cursor)


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
	_update_cursor()
	_ground_pickup.refresh(_hud_on and not is_blocking())
	if _held_icon.visible:
		_held_icon.position = (_root.get_global_mouse_position() + Vector2(6, 4)).floor()
		if not GameState.has_item(held_item):
			set_held("")
	if _task_hide_left > 0.0:
		_task_hide_left -= delta
		if _task_hide_left <= 0.0:
			_task_panel.visible = false


func _input(event: InputEvent) -> void:
	if _info.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") or event.is_action_pressed("inventory"):
			get_viewport().set_input_as_handled()
			_close_info()
		return
	if _history_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close_history()
		return
	if _pause.visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_G and _ground_pickup.visible and not is_blocking():
		get_viewport().set_input_as_handled()
		_ground_pickup.pick_up()
		return
	if not held_item.is_empty() and not is_blocking():
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var kq: InputEventKey = event as InputEventKey
		var drop_key: bool = kq != null and kq.pressed and not kq.echo and kq.physical_keycode == KEY_Q
		if event.is_action_pressed("ui_cancel") or drop_key or (mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT):
			get_viewport().set_input_as_handled()
			set_held("")
			return
	if event.is_action_pressed("inventory") and _hud_on and not _history_open and not _closeup.is_open():
		get_viewport().set_input_as_handled()
		toggle_inventory()
		return



func set_hud_visible(v: bool) -> void:
	_hud_on = v
	if not v:
		hide_controls_hint()
		for c: Node in _toasts.get_children():
			c.queue_free()
		_task_panel.visible = false
		close_history()
		_inventory.close()
		_container.close()
		_stamina_root.visible = false
		set_held("")
	else:
		_on_stamina(GameState.stamina)


func set_objective(text: String, announce: bool = false) -> void:
	if not _objective.is_empty() and _objective != text and not _done_objectives.has(_objective):
		_done_objectives.append(_objective)
	_objective = text
	_task_label.text = text
	if announce:
		announce_objective()


func announce_objective() -> void:
	(func() -> void:
		if _hud_on:
			_show_task(TASK_ANNOUNCE_TIME)).call_deferred()


func show_stamina(v: bool) -> void:
	_stamina_on = v
	_on_stamina(GameState.stamina)


func log_say(speaker: String, text: String, color: String = "#ffffff") -> void:
	_add_entry("[color=%s]%s:[/color] %s" % [color, speaker, text])


func log_thought(text: String) -> void:
	_add_entry("[color=%s]%s[/color]" % [THOUGHT_COLOR, text])


func is_blocking() -> bool:
	return _pause.visible or _history_open or _inventory.is_open() or _container.is_open() or _closeup.is_open()


func open_container(cid: String) -> void:
	close_history()
	_inventory.close()
	_task_panel.visible = false
	_container.container_id = cid
	_container.open()


func is_container_open() -> bool:
	return _container.is_open()


func _on_container_action(id: String, action: String) -> void:
	if action == "take":
		var lock: String = str(GameState.take_locks.get(_container.container_id, ""))
		if not lock.is_empty():
			_item_thought.show_text(lock, 3.5)
			return
		GameState.take_from(_container.container_id, id)
	else:
		_on_item_action(id, action)


func toggle_inventory() -> void:
	if _container.is_open():
		_container.close()
		return
	if _inventory.is_open():
		_inventory.close()
	else:
		close_history()
		hide_controls_hint()
		_task_panel.visible = false
		_inventory.open()


func is_inventory_open() -> bool:
	return _inventory.is_open()


func use_item(id: String, action: String) -> void:
	_on_item_action(id, action)


func toggle_history() -> void:
	if _history_open:
		close_history()
	else:
		open_history()


func open_history() -> void:
	_inventory.close()
	_history_open = true
	_overlay.visible = true
	_task_panel.visible = false
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func close_history() -> void:
	var was: bool = _history_open
	_history_open = false
	if _overlay:
		_overlay.visible = false
	if was and _pause and _pause.visible:
		_pause_first.grab_focus()


func clear_log() -> void:
	for c: Node in _log_box.get_children():
		c.queue_free()
	_last_entry = ""
	_log_entries.clear()


func get_objective() -> String:
	return _objective


func reset_journal() -> void:
	clear_log()
	_objective = ""
	_task_label.text = ""
	_done_objectives.clear()


func journal_to_dict() -> Dictionary:
	return {"objective": _objective, "done": Array(_done_objectives), "log": Array(_log_entries)}


func journal_from_dict(d: Dictionary) -> void:
	reset_journal()
	for t: Variant in d.get("done", []):
		_done_objectives.append(str(t))
	for e: Variant in d.get("log", []):
		_add_entry(str(e))
	_objective = str(d.get("objective", ""))
	_task_label.text = _objective



func _show_task(duration: float) -> void:
	if _objective.is_empty():
		return
	_task_panel.visible = true
	_fit_task_label()
	_task_hide_left = duration
	_place_task()
	await get_tree().process_frame
	_place_task()


func _place_task() -> void:
	_task_panel.reset_size()
	var s: Vector2 = _task_panel.get_combined_minimum_size()
	_task_panel.size = s
	_task_panel.position = Vector2(640.0 - MARGIN - s.x, MARGIN)


func _fit_task_label() -> void:
	var f: Font = _task_label.get_theme_font("font")
	var fs: int = _task_label.get_theme_font_size("font_size")
	var w: float = f.get_string_size(_task_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
	var wrap: bool = w > TASK_MAX_W
	_task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	_task_label.custom_minimum_size = Vector2(TASK_MAX_W if wrap else w, 0)
	_task_label.size = Vector2.ZERO
	_task_panel.size = Vector2.ZERO


func _add_entry(bbcode: String) -> void:
	if bbcode == _last_entry:
		return
	_last_entry = bbcode
	_log_entries.append(bbcode)
	var r: RichTextLabel = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(396, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = bbcode
	_log_box.add_child(r)


func _build_stamina() -> void:
	_stamina_root = Control.new()
	_stamina_root.position = STAMINA_POS
	_stamina_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stamina_root)
	var back: ColorRect = ColorRect.new()
	back.color = Color(0.02, 0.02, 0.03, 0.85)
	back.position = Vector2(-1, -1)
	back.size = STAMINA_SIZE + Vector2(2, 2)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_root.add_child(back)
	_stamina_fill = ColorRect.new()
	_stamina_fill.color = Color(0.62, 0.74, 0.7)
	_stamina_fill.size = STAMINA_SIZE
	_stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_root.add_child(_stamina_fill)
	_stamina_root.visible = false


func _on_stamina(v: float) -> void:
	_stamina_fill.size.x = roundf(STAMINA_SIZE.x * v)
	_stamina_fill.color = Color(0.62, 0.74, 0.7) if v > 0.25 else Color(0.78, 0.42, 0.36)
	_stamina_root.visible = _hud_on and _stamina_on


func _build_held() -> void:
	_held_icon = TextureRect.new()
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_icon.size = Vector2(32, 32)
	_held_icon.modulate = Color(1, 1, 1, 0.9)
	_held_icon.visible = false
	_held_label = Label.new()
	_held_label.add_theme_font_size_override("font_size", 8)
	_held_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	_held_label.position = Vector2(170, MARGIN + 2.0)
	_held_label.size = Vector2(300, 12)
	_held_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_label.visible = false
	_root.add_child(_held_icon)
	_root.add_child(_held_label)


func _build_pause() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	_root.add_child(_pause)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	_pause_panel = PanelContainer.new()
	_pause_panel.add_theme_stylebox_override("panel", MenuUI.panel_style())
	_pause.add_child(_pause_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_pause_panel.add_child(col)
	var t: Label = Label.new()
	t.text = "Пауза"
	t.add_theme_color_override("font_color", Color(0.7, 0.78, 0.82))
	col.add_child(t)
	var bs: Array[Button] = []
	var items: Array = [
		["Продолжить", close_pause],
		["Задания", _open_tasks],
		["История диалогов", open_history],
		["Вещи", func() -> void:
			close_pause()
			toggle_inventory()],
		["Управление", _open_controls],
		["Сохранить", func() -> void: _saves.open("save")],
		["Загрузить", func() -> void: _saves.open("load")],
		["Настройки", func() -> void: _pause_settings.open()],
		["В главное меню", _to_title],
	]
	for it: Array in items:
		var b: Button = MenuUI.button(str(it[0]))
		b.custom_minimum_size = Vector2(170, 0)
		b.pressed.connect(it[1])
		col.add_child(b)
		bs.append(b)
	for i: int in bs.size():
		bs[i].focus_neighbor_top = bs[i].get_path_to(bs[(i - 1 + bs.size()) % bs.size()])
		bs[i].focus_neighbor_bottom = bs[i].get_path_to(bs[(i + 1) % bs.size()])
	_pause_first = bs[0]
	_pause_settings = SettingsPanel.new()
	_root.add_child(_pause_settings)
	_pause_settings.closed.connect(func() -> void: bs[7].grab_focus())
	_saves = SaveSlotsPanel.new()
	_root.add_child(_saves)
	_saves.closed.connect(func() -> void: bs[5].grab_focus())
	_build_info()


func _build_info() -> void:
	_info = Control.new()
	_info.set_anchors_preset(Control.PRESET_FULL_RECT)
	_info.visible = false
	_info.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_info)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb and mb.pressed:
			_close_info())
	_info.add_child(dim)
	_info_panel = PanelContainer.new()
	_info_panel.add_theme_stylebox_override("panel", MenuUI.panel_style())
	_info.add_child(_info_panel)
	_info_box = VBoxContainer.new()
	_info_box.add_theme_constant_override("separation", 4)
	_info_panel.add_child(_info_box)


func _info_open(title: String) -> void:
	for c: Node in _info_box.get_children():
		c.queue_free()
	var t: Label = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", Color(0.7, 0.78, 0.82))
	_info_box.add_child(t)


func _info_line(text: String, color: Color, width: float = 380.0) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_color_override("font_color", color)
	_info_box.add_child(l)
	return l


func _info_show() -> void:
	var hint: Label = _info_line("Esc — назад", Color(0.45, 0.5, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.move_child(_info, -1)
	_info.visible = true
	await get_tree().process_frame
	_info_panel.reset_size()
	var s: Vector2 = _info_panel.get_combined_minimum_size()
	_info_panel.size = s
	_info_panel.position = ((Vector2(640, 360) - s) / 2.0).floor()


func _close_info() -> void:
	_info.visible = false
	if _pause.visible:
		_pause_first.grab_focus()


func _open_tasks() -> void:
	_info_open("Задания")
	_info_line("Сейчас:", Color(0.62, 0.86, 0.72))
	_info_line("• " + (_objective if not _objective.is_empty() else "—"), Color(0.95, 0.88, 0.66))
	if not _done_objectives.is_empty():
		_info_line("Выполнено:", Color(0.45, 0.5, 0.55))
		var from: int = maxi(0, _done_objectives.size() - 8)
		for i: int in range(_done_objectives.size() - 1, from - 1, -1):
			_info_line("✓ " + _done_objectives[i], Color(0.5, 0.54, 0.58))
	_info_show()


func _open_controls() -> void:
	_info_open("Управление")
	for sec: Array in CONTROLS:
		_info_line(str(sec[0]), Color(0.62, 0.86, 0.72))
		for kv: Array in sec[1]:
			_key_row(_info_box, str(kv[0]), str(kv[1]))
	_info_show()


func _key_row(parent: Control, key: String, what: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var k: Label = Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(130, 0)
	k.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66))
	row.add_child(k)
	var w: Label = Label.new()
	w.text = what
	w.add_theme_color_override("font_color", Color(0.72, 0.76, 0.8))
	row.add_child(w)


func _build_controls_hint() -> void:
	_controls_hint = PanelContainer.new()
	_controls_hint.add_theme_stylebox_override("panel", _panel_style(6.0))
	_controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_hint.visible = false
	_root.add_child(_controls_hint)


func show_controls_hint(sec: float = 9.0) -> void:
	for c: Node in _controls_hint.get_children():
		c.queue_free()
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_hint.add_child(col)
	var t: Label = Label.new()
	t.text = "Управление"
	t.add_theme_color_override("font_color", Color(0.62, 0.86, 0.72))
	col.add_child(t)
	for kv: Array in WALK_CONTROLS:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)
		var k: Label = Label.new()
		k.text = str(kv[0])
		k.custom_minimum_size = Vector2(62, 0)
		k.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66))
		row.add_child(k)
		var w: Label = Label.new()
		w.text = str(kv[1])
		w.add_theme_color_override("font_color", Color(0.72, 0.76, 0.8))
		row.add_child(w)
	_controls_hint.position = Vector2(MARGIN, 96)
	_controls_hint.modulate.a = 0.0
	_controls_hint.visible = true
	if _controls_tween:
		_controls_tween.kill()
	_controls_tween = create_tween()
	_controls_tween.tween_property(_controls_hint, "modulate:a", 1.0, 0.5)
	_controls_tween.tween_interval(sec)
	_controls_tween.tween_property(_controls_hint, "modulate:a", 0.0, 1.0)
	_controls_tween.tween_callback(func() -> void: _controls_hint.visible = false)


func hide_controls_hint() -> void:
	if _controls_tween:
		_controls_tween.kill()
	if _controls_hint:
		_controls_hint.visible = false


func controls_hint_visible() -> bool:
	return _controls_hint.visible


func open_pause() -> void:
	if _pause.visible:
		return
	_root.move_child(_pause, -1)
	_root.move_child(_pause_settings, -1)
	_root.move_child(_saves, -1)
	_root.move_child(_overlay, -1)
	_pause.visible = true
	_task_panel.visible = false
	hide_controls_hint()
	get_tree().paused = true
	await get_tree().process_frame
	var s: Vector2 = _pause_panel.get_combined_minimum_size()
	_pause_panel.size = s
	_pause_panel.position = ((Vector2(640, 360) - s) / 2.0).floor()
	_pause_first.grab_focus()


func close_pause() -> void:
	_pause_settings.close()
	_saves.close()
	_info.visible = false
	close_history()
	_pause.visible = false
	get_tree().paused = false


func is_paused() -> bool:
	return _pause.visible


func _to_title() -> void:
	close_pause()
	set_walk_mode(false)
	set_held("")
	hide_tutorial()
	SceneRouter.go_to(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _pause_settings.is_open() or _saves.is_open() or _info.visible or _history_open:
		return
	if _pause.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			close_pause()
		else:
			MenuUI.wasd_to_focus(event, get_viewport())
		return
	if _hud_on and event.is_action_pressed("ui_cancel") and not is_blocking() and held_item.is_empty():
		get_viewport().set_input_as_handled()
		open_pause()


func _build_tutorial() -> void:
	_tut_panel = PanelContainer.new()
	_tut_panel.add_theme_stylebox_override("panel", _panel_style(6.0))
	_tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_label = Label.new()
	_tut_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72))
	_tut_panel.add_child(_tut_label)
	_tut_panel.visible = false
	_root.add_child(_tut_panel)


func show_tutorial(text: String) -> void:
	_tut_label.text = text
	_tut_panel.visible = true
	_tut_panel.reset_size()
	var s: Vector2 = _tut_panel.get_combined_minimum_size()
	_tut_panel.position = Vector2(roundf((640.0 - s.x) / 2.0), MARGIN)


func hide_tutorial() -> void:
	_tut_panel.visible = false


func tutorial_text() -> String:
	return _tut_label.text if _tut_panel.visible else ""


func _held_text(id: String) -> String:
	var n: String = str(GameState.item_def(id).get("name", id))
	if walk_mode:
		return "В руке: %s   (E / клик у нужного места — применить, Q/ПКМ — убрать)" % n
	return "В руке: %s   (клик — применить, ПКМ/Esc — убрать)" % n


func set_walk_mode(v: bool) -> void:
	walk_mode = v
	if not held_item.is_empty():
		_held_label.text = _held_text(held_item)


func _update_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _setup_cursor() -> void:
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(CURSOR):
		return
	var f: int = clampi(roundi(float(get_tree().root.size.y) / 360.0), 1, 4)
	if f == _cursor_scale:
		return
	_cursor_scale = f
	for pair: Array in [[CURSOR, Input.CURSOR_ARROW], [CURSOR_HOVER, Input.CURSOR_POINTING_HAND]]:
		var img: Image = (load(str(pair[0])) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(img.get_width() * f, img.get_height() * f, Image.INTERPOLATE_NEAREST)
		Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), pair[1], Vector2.ZERO)


func set_held(id: String) -> void:
	held_item = id
	var on: bool = not id.is_empty()
	_held_icon.visible = on
	_held_label.visible = on
	if on:
		var path: String = str(GameState.item_def(id).get("icon", ""))
		if ResourceLoader.exists(path):
			_held_icon.texture = load(path)
		_held_label.text = _held_text(id)
	held_changed.emit(id)


func _on_item_action(id: String, action: String) -> void:
	if action == "drop":
		if _ground_pickup.drop(id):
			if held_item == id:
				set_held("")
			_inventory.close()
			_ground_pickup.refresh(_hud_on and not is_blocking())
		return
	if action == "hold":
		_inventory.close()
		set_held(id)
		return
	var text: String = GameState.item_thought(id, action)
	var closeup: String = str(GameState.item_def(id).get("closeup", ""))
	GameState.use_item(id, action)
	if action == "look" and not closeup.is_empty():
		var d: Dictionary = GameState.item_def(id)
		var doc: Dictionary = {"closeup": closeup, "text": str(d.get("closeup_text", "")), "reaction": text}
		for k: String in ["text_rect", "texts"]:
			if d.has(k):
				doc[k] = d[k]
		_closeup.open(doc)
	elif not text.is_empty():
		_item_thought.show_text(text, 3.5)


func open_closeup(doc: Dictionary) -> void:
	_closeup.open(doc)


func is_closeup_open() -> bool:
	return _closeup.is_open()


func show_item_taken(id: String) -> void:
	var d: Dictionary = GameState.item_def(id)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(4.0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = str(d.get("icon", ""))
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	row.add_child(icon)
	var l: Label = Label.new()
	l.text = "Взято: " + str(d.get("name", id))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	panel.modulate.a = 0.0
	_toasts.add_child(panel)
	Audio.sfx("res://assets/audio/sfx/ui_click.wav", -14.0, 0.8)
	var t: Tween = panel.create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.2)
	t.tween_interval(TOAST_TIME)
	t.tween_property(panel, "modulate:a", 0.0, 0.5)
	t.tween_callback(panel.queue_free)
