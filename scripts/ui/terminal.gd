class_name Terminal
extends CanvasLayer
## Alexei's CRT computer: an in-world 1998 police records terminal.
## Search the database, read the «Весы» cases and memos, file the report (a choice).
## Content: data/dialogues/s01_terminal.json. Keys: digits pick, Esc goes back.

signal closed
signal report_filed(choices: Dictionary)

const GREEN: Color = Color(0.32, 1.0, 0.48)
const GREEN_DIM: Color = Color(0.2, 0.62, 0.3)
const SCREEN_BG: Color = Color(0.03, 0.07, 0.04)
const BEZEL: Color = Color(0.74, 0.7, 0.58)
const TEXT_W: float = 488.0

var report_unlocked: bool = false
var report_done: bool = false

var _d: Dictionary = {}
var _root: Control
var _body: VBoxContainer
var _footer: Label
var _hotkeys: Dictionary = {}
var _back: Callable = Callable()
var _choices: Dictionary = {}
var _open: bool = false
var _btn_normal: StyleBoxEmpty = StyleBoxEmpty.new()
var _btn_hover: StyleBoxFlat


func _ready() -> void:
	layer = 10
	_d = DialogueData.load_file("s01_terminal")
	_btn_hover = StyleBoxFlat.new()
	_btn_hover.bg_color = GREEN
	_build()
	visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var bezel: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = SCREEN_BG
	sb.border_color = BEZEL
	sb.set_border_width_all(8)
	sb.set_corner_radius_all(6)
	sb.anti_aliasing = false
	sb.set_content_margin_all(14)
	bezel.add_theme_stylebox_override("panel", sb)
	bezel.position = Vector2(52, 38)
	bezel.size = Vector2(536, 308)
	_root.add_child(bezel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	bezel.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	col.add_child(head)
	var title: Label = _label(str(_d.get("header", "")), GREEN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label(str(_d.get("clock", "")), GREEN_DIM))
	var line: ColorRect = ColorRect.new()
	line.color = GREEN_DIM
	line.custom_minimum_size = Vector2(0, 1)
	col.add_child(line)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(TEXT_W, 224)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	scroll.add_child(_body)
	_footer = _label("ESC — НАЗАД", GREEN_DIM)
	col.add_child(_footer)
	# scanlines over the screen
	var scan: ColorRect = ColorRect.new()
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan.position = bezel.position + Vector2(8, 8)
	scan.size = bezel.size - Vector2(16, 16)
	var sh: Shader = Shader.new()
	sh.code = "shader_type canvas_item; void fragment(){ float l = step(0.5, fract(FRAGCOORD.y / 4.0)); COLOR = vec4(0.0, 0.0, 0.0, 0.18 * l); }"
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = sh
	scan.material = sm
	_root.add_child(scan)


# --- public --------------------------------------------------------------

func open() -> void:
	_open = true
	visible = true
	_audio("sfx", "res://assets/audio/sfx/crt_on.wav", -6.0)
	_clear()
	_footer.visible = false
	for l: String in _d.get("boot", []):
		_body.add_child(_label(l, GREEN))
		_audio("sfx", "res://assets/audio/sfx/key_tick.wav", -18.0)
		await get_tree().create_timer(0.18).timeout
		if not _open:
			return
	await get_tree().create_timer(0.5).timeout
	if _open:
		_show_menu()


func is_open() -> bool:
	return _open


func close() -> void:
	_open = false
	visible = false
	closed.emit()


# --- screens -------------------------------------------------------------

func _show_menu() -> void:
	_screen(Callable(self, "close"))
	for it: Dictionary in _d.get("menu", []):
		var id: String = str(it["id"])
		var label: String = str(it["label"])
		var cb: Callable
		match id:
			"search": cb = _show_search
			"cases": cb = func() -> void: _show_list(str(_d["cases_title"]), _d["cases"], _show_menu)
			"inbox": cb = func() -> void: _show_list(str(_d["inbox_title"]), _d["memos"], _show_menu)
			"report": cb = _show_report_entry
			_: cb = close
		_item(label, cb, label.substr(0, 1))


func _show_search() -> void:
	_screen(_show_menu)
	_body.add_child(_label(str(_d.get("search_prompt", "")), GREEN))
	var le: LineEdit = LineEdit.new()
	le.custom_minimum_size = Vector2(220, 0)
	le.max_length = 20
	le.add_theme_color_override("font_color", GREEN)
	le.add_theme_color_override("caret_color", GREEN)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.12, 0.06)
	sb.border_color = GREEN_DIM
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_stylebox_override("focus", sb)
	le.text_submitted.connect(func(q: String) -> void: _show_result(q))
	le.text_changed.connect(func(_t: String) -> void: _audio("sfx", "res://assets/audio/sfx/key_tick.wav", -16.0))
	_body.add_child(le)
	le.grab_focus.call_deferred()


func _show_result(query: String) -> void:
	var key: String = _lookup(query)
	_screen(_show_search)
	_body.add_child(_label("> " + query.to_upper(), GREEN_DIM))
	var text: String = str(_d["records"].get(key, _d.get("not_found", ""))) if key != "" else str(_d.get("not_found", ""))
	_body.add_child(_text(text))
	_body.add_child(_gap())
	_item("1. НОВЫЙ ПОИСК", _show_search, "1")
	_item("0. В МЕНЮ", _show_menu, "0")


func _show_list(title: String, items: Array, back: Callable) -> void:
	_screen(back)
	_body.add_child(_label(title, GREEN_DIM))
	var i: int = 1
	for it: Dictionary in items:
		var text: String = str(it["text"])
		var again: Callable = func() -> void: _show_list(title, items, back)
		_item("%d. %s" % [i, str(it["label"])], func() -> void: _show_page(text, again), str(i))
		i += 1
	_item("0. НАЗАД", back, "0")


func _show_page(text: String, back: Callable) -> void:
	_screen(back)
	_body.add_child(_text(text))
	_body.add_child(_gap())
	_item("0. НАЗАД", back, "0")


func _show_report_entry() -> void:
	if report_done:
		_show_page(str(_d.get("report_done", "")), _show_menu)
	elif not report_unlocked:
		_show_page(str(_d.get("report_locked", "")), _show_menu)
	else:
		_choices = {}
		_show_question(0)


func _show_question(i: int) -> void:
	var r: Dictionary = _d["report"]
	var qs: Array = r["questions"]
	if i >= qs.size():
		_show_sign()
		return
	var q: Dictionary = qs[i]
	_screen(_show_menu if i == 0 else func() -> void: _show_question(i - 1))
	_body.add_child(_label(str(r["title"]), GREEN_DIM))
	_body.add_child(_label("%d/%d  %s" % [i + 1, qs.size(), str(q["field"])], GREEN))
	for opt: String in ["a", "b"]:
		var n: String = "1" if opt == "a" else "2"
		_item("%s. %s" % [n, str(q[opt])], func() -> void:
			_choices[str(q["id"])] = opt
			_show_question(i + 1), n)


func _show_sign() -> void:
	var r: Dictionary = _d["report"]
	_screen(func() -> void: _show_question(r["questions"].size() - 1))
	_body.add_child(_label(str(r["title"]), GREEN_DIM))
	for q: Dictionary in r["questions"]:
		_body.add_child(_text("%s\n  %s" % [str(q["field"]), str(q[_choices.get(str(q["id"]), "a")])]))
	_item("1. " + str(r["sign"]), _file_report, "1")
	_item("0. ИЗМЕНИТЬ", func() -> void: _show_question(0), "0")


func _file_report() -> void:
	report_done = true
	_audio("ui_click")
	_screen(_show_menu)
	_body.add_child(_label(str(_d["report"]["filed"]), GREEN))
	_item("0. ВЫХОД", close, "0")
	report_filed.emit(_choices.duplicate())


# --- helpers -------------------------------------------------------------

func _lookup(query: String) -> String:
	var q: String = query.strip_edges().to_upper()
	var aliases: Dictionary = {"КОУЛ": "COLE", "АЛЬВАРЕС": "ALVAREZ", "АЛЬВАРЕЗ": "ALVAREZ", "КЛЯЙН": "KLEIN", "КЛЕЙН": "KLEIN", "КАРАМАЗОВ": "KARAMAZOV"}
	for a: String in aliases:
		if q.begins_with(a):
			return str(aliases[a])
	for k: String in _d.get("records", {}):
		if q != "" and (q.begins_with(k) or k.begins_with(q)) and q.length() >= 3:
			return k
	return ""


func _screen(back: Callable) -> void:
	_clear()
	_hotkeys = {}
	_back = back
	_footer.visible = true


func _clear() -> void:
	for c: Node in _body.get_children():
		c.queue_free()


func _label(text: String, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


func _gap() -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, 6)
	return c


func _text(text: String) -> Label:
	var l: Label = _label(text, GREEN)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_W, 0)
	return l


func _item(text: String, cb: Callable, hotkey: String) -> void:
	var b: Button = Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for s: String in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, _btn_normal)
	b.add_theme_stylebox_override("hover", _btn_hover)
	b.add_theme_color_override("font_color", GREEN)
	b.add_theme_color_override("font_hover_color", SCREEN_BG)
	b.add_theme_color_override("font_pressed_color", GREEN)
	b.pressed.connect(func() -> void:
		_audio("sfx", "res://assets/audio/sfx/key_tick.wav", -12.0)
		cb.call())
	_body.add_child(b)
	_hotkeys[hotkey] = cb


func _audio(method: String, path: String = "", db: float = 0.0) -> void:
	var a: Node = get_node_or_null("/root/Audio")
	if a == null:
		return
	if method == "sfx":
		a.sfx(path, db)
	else:
		a.call(method)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _back.is_valid():
			_back.call()
		return
	var ch: String = char(k.unicode) if k.unicode > 0 else ""
	if _hotkeys.has(ch) and get_viewport().gui_get_focus_owner() == null:
		get_viewport().set_input_as_handled()
		_audio("sfx", "res://assets/audio/sfx/key_tick.wav", -12.0)
		(_hotkeys[ch] as Callable).call()
