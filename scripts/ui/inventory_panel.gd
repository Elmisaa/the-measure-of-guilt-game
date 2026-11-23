class_name InventoryPanel
extends Control

signal action_chosen(item_id: String, action: String)
signal closed

const COLS: int = 6
const ROWS: int = 2
const SLOT: float = 40.0
const GAP: float = 4.0
const PANEL_BG: Color = Color(0.03, 0.03, 0.05, 0.94)
const BORDER: Color = Color(0.22, 0.24, 0.28, 1)
const SLOT_BG: Color = Color(0.08, 0.09, 0.11, 1)
const SLOT_HOVER: Color = Color(0.92, 0.95, 1.0, 0.55)
const NAME_COLOR: Color = Color(0.85, 0.78, 0.62)
const HINT_COLOR: Color = Color(0.6, 0.68, 0.72)

var _panel: PanelContainer
var _grid: GridContainer
var _tip: PanelContainer
var _tip_name: Label
var _tip_desc: Label
var _tip_actions: Label
var _menu: PanelContainer
var _menu_box: VBoxContainer
var _menu_item: String = ""
var _gs: Node
var container_id: String = ""
var _title: Label
var _take_all: Button
var _hint: Label
var _slots: Array[Panel] = []
var _sel: int = 0
var _menu_sel: int = 0
var _on_take: bool = false
const MENU_SEL: Color = Color(0.36, 0.4, 0.46, 1)


func _ready() -> void:
	_gs = get_node("/root/GameState")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb and mb.pressed:
			if _menu.visible:
				_close_menu()
			else:
				close())
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(PANEL_BG, 8.0))
	add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	_title = Label.new()
	_title.text = "Вещи"
	_title.add_theme_color_override("font_color", Color(0.7, 0.78, 0.82))
	col.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	col.add_child(_grid)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	col.add_child(bottom)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55))
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_hint)
	_take_all = Button.new()
	_take_all.text = "Взять всё"
	_take_all.focus_mode = Control.FOCUS_NONE
	_take_all.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_take_all.pressed.connect(func() -> void:
		for it: Variant in _gs.container_items(container_id).duplicate():
			action_chosen.emit(str(it), "take"))
	bottom.add_child(_take_all)
	_build_tip()
	_build_menu()
	_gs.inventory_changed.connect(func() -> void:
		if visible or container_id.is_empty():
			_refresh())
	_refresh()


func _style(bg: Color, margin: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(margin)
	return sb


func _build_tip() -> void:
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", _style(Color(0.02, 0.02, 0.03, 0.97), 6.0))
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(col)
	_tip_name = Label.new()
	_tip_name.add_theme_color_override("font_color", NAME_COLOR)
	col.add_child(_tip_name)
	_tip_desc = Label.new()
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.custom_minimum_size = Vector2(190, 0)
	col.add_child(_tip_desc)
	_tip_actions = Label.new()
	_tip_actions.add_theme_color_override("font_color", HINT_COLOR)
	col.add_child(_tip_actions)


func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", _style(Color(0.02, 0.02, 0.03, 0.98), 3.0))
	_menu.visible = false
	add_child(_menu)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 1)
	_menu.add_child(_menu_box)


func _refresh() -> void:
	for c: Node in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var items: Array = _gs.items if container_id.is_empty() else _gs.container_items(container_id)
	_title.text = "Вещи" if container_id.is_empty() else _gs.container_title(container_id)
	var can_take: bool = not container_id.is_empty() and _gs.container_can_take(container_id)
	_take_all.visible = can_take and not items.is_empty()
	if container_id.is_empty():
		_hint.text = "Стрелки / WASD — выбор, Enter или клик — действия.  I / Esc — закрыть"
	elif items.is_empty():
		_hint.text = "Пусто.  Esc — закрыть"
	else:
		_hint.text = "Стрелки / WASD, Enter или клик — действия.  Esc — закрыть"
	_slots.clear()
	for i: int in COLS * ROWS:
		var sl: Panel = _make_slot(str(items[i]) if i < items.size() else "")
		_slots.append(sl)
		_grid.add_child(sl)
	var s: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = s
	_panel.position = ((Vector2(640, 360) - s) / 2.0).floor()
	if visible:
		_select(mini(_sel, _slots.size() - 1), false)


func _make_slot(id: String) -> Panel:
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	var sb: StyleBoxFlat = _style(SLOT_BG, 0.0)
	slot.add_theme_stylebox_override("panel", sb)
	if id.is_empty():
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return slot
	var d: Dictionary = _gs.item_def(id)
	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = str(d.get("icon", ""))
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	icon.position = Vector2(4, 4)
	icon.size = Vector2(32, 32)
	slot.add_child(icon)
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.set_meta("item_id", id)
	slot.mouse_entered.connect(func() -> void:
		_select(_slots.find(slot), false)
		var audio: Node = get_node_or_null("/root/Audio")
		if audio:
			audio.ui_hover())
	slot.mouse_exited.connect(func() -> void:
		_tip.visible = false)
	slot.gui_input.connect(func(e: InputEvent) -> void:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_open_menu(id, slot))
	return slot


func _show_tip(id: String, slot: Control) -> void:
	if _menu.visible:
		return
	var d: Dictionary = _gs.item_def(id)
	_tip_name.text = str(d.get("name", id))
	_tip_desc.text = str(d.get("desc", ""))
	var names: PackedStringArray = PackedStringArray()
	for a: String in _actions_for(id):
		names.append(_gs.action_label(a))
	_tip_actions.text = "Можно: " + " · ".join(names)
	_tip.visible = true
	_tip.reset_size()
	var s: Vector2 = _tip.get_combined_minimum_size()
	var r: Rect2 = slot.get_global_rect()
	var pos: Vector2 = Vector2(r.position.x, r.end.y + 4.0)
	if pos.y + s.y > 356.0:
		pos.y = r.position.y - s.y - 4.0
	pos.x = clampf(pos.x, 4.0, 636.0 - s.x)
	_tip.position = pos.floor()


func _open_menu(id: String, slot: Control) -> void:
	_tip.visible = false
	_menu_item = id
	for c: Node in _menu_box.get_children():
		_menu_box.remove_child(c)
		c.queue_free()
	for a: String in _actions_for(id):
		var b: Button = Button.new()
		b.text = _gs.action_label(a)
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func() -> void: choose(id, a))
		var idx: int = _menu_box.get_child_count()
		b.mouse_entered.connect(func() -> void: _menu_select(idx))
		var audio: Node = get_node_or_null("/root/Audio")
		if audio:
			audio.bind_button(b)
		_menu_box.add_child(b)
	_menu.visible = true
	_menu.reset_size()
	var r: Rect2 = slot.get_global_rect()
	_menu.position = Vector2(minf(r.end.x + 2.0, 636.0 - _menu.get_combined_minimum_size().x), r.position.y).floor()
	_menu_select(0)


func _actions_for(id: String) -> Array[String]:
	var out: Array[String] = []
	if not container_id.is_empty() and _gs.container_can_take(container_id):
		out.append("take")
	for a: String in _gs.item_actions(id):
		out.append(a)
	return out


func _select(i: int, from_keys: bool) -> void:
	if i < 0 or i >= _slots.size():
		return
	if _on_take:
		_set_take_focus(false)
	_sel = i
	for k: int in _slots.size():
		var sb: StyleBoxFlat = _slots[k].get_theme_stylebox("panel") as StyleBoxFlat
		sb.border_color = SLOT_HOVER if k == i else BORDER
	var sl: Panel = _slots[i]
	if sl.has_meta("item_id"):
		_show_tip(str(sl.get_meta("item_id")), sl)
		if from_keys:
			var audio: Node = get_node_or_null("/root/Audio")
			if audio:
				audio.ui_hover()
	else:
		_tip.visible = false


func _set_take_focus(on: bool) -> void:
	_on_take = on
	if on:
		_tip.visible = false
		for k: int in _slots.size():
			(_slots[k].get_theme_stylebox("panel") as StyleBoxFlat).border_color = BORDER
		var st: StyleBoxFlat = _style(MENU_SEL, 3.0)
		_take_all.add_theme_stylebox_override("normal", st)
		_take_all.add_theme_color_override("font_color", NAME_COLOR)
		var audio: Node = get_node_or_null("/root/Audio")
		if audio:
			audio.ui_hover()
	else:
		_take_all.remove_theme_stylebox_override("normal")
		_take_all.remove_theme_color_override("font_color")


func _menu_select(i: int) -> void:
	var bs: Array[Node] = _menu_box.get_children()
	if bs.is_empty():
		return
	_menu_sel = clampi(i, 0, bs.size() - 1)
	for k: int in bs.size():
		var b: Button = bs[k] as Button
		if k == _menu_sel:
			var st: StyleBoxFlat = _style(MENU_SEL, 2.0)
			st.border_width_left = 0
			st.border_width_right = 0
			st.border_width_top = 0
			st.border_width_bottom = 0
			b.add_theme_stylebox_override("normal", st)
			b.add_theme_stylebox_override("hover", st)
			b.add_theme_color_override("font_color", NAME_COLOR)
			b.add_theme_color_override("font_hover_color", NAME_COLOR)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.remove_theme_color_override("font_color")
			b.remove_theme_color_override("font_hover_color")


func _nav_dir(event: InputEvent) -> Vector2i:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed:
		return Vector2i.ZERO
	match k.physical_keycode:
		KEY_LEFT, KEY_A:
			return Vector2i(-1, 0)
		KEY_RIGHT, KEY_D:
			return Vector2i(1, 0)
		KEY_UP, KEY_W:
			return Vector2i(0, -1)
		KEY_DOWN, KEY_S:
			return Vector2i(0, 1)
	return Vector2i.ZERO


func _is_enter(event: InputEvent) -> bool:
	var k: InputEventKey = event as InputEventKey
	return k != null and k.pressed and not k.echo and k.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]


func _close_menu() -> void:
	_menu.visible = false
	_menu_item = ""


func choose(id: String, action: String) -> void:
	_close_menu()
	if action == "hold":
		close()
	action_chosen.emit(id, action)


func open() -> void:
	_refresh()
	_tip.visible = false
	_close_menu()
	visible = true
	_sel = 0
	_set_take_focus(false)
	_select(0, false)


func close() -> void:
	if not visible:
		return
	visible = false
	_tip.visible = false
	_close_menu()
	closed.emit()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var hud: Node = get_node_or_null("/root/Hud")
	if hud and hud.is_closeup_open():
		return
	var step: Vector2i = _nav_dir(event)
	if step != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		if _menu.visible:
			if step.y != 0:
				_menu_select(_menu_sel + step.y)
			elif step.x < 0:
				_close_menu()
		elif _on_take:
			if step.y < 0:
				_set_take_focus(false)
				_select(_sel, true)
		else:
			var c: int = _sel % COLS
			var r: int = _sel / COLS
			if step.y > 0 and r == ROWS - 1 and _take_all.visible:
				_set_take_focus(true)
				return
			c = clampi(c + step.x, 0, COLS - 1)
			r = clampi(r + step.y, 0, ROWS - 1)
			_select(r * COLS + c, true)
		return
	if _is_enter(event):
		get_viewport().set_input_as_handled()
		if _menu.visible:
			var bs: Array[Node] = _menu_box.get_children()
			if _menu_sel < bs.size():
				(bs[_menu_sel] as Button).pressed.emit()
		elif _on_take:
			_take_all.pressed.emit()
			_set_take_focus(_take_all.visible)
		elif _sel < _slots.size() and _slots[_sel].has_meta("item_id"):
			_open_menu(str(_slots[_sel].get_meta("item_id")), _slots[_sel])
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _menu.visible:
			_close_menu()
		else:
			close()
