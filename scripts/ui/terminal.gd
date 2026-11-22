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
## Shown once, the first time the computer boots (set by the scene).
var first_thought: String = ""
var _first_thought_done: bool = false

var _d: Dictionary = {}
var _root: Control
var _body: VBoxContainer
var _footer: Label
var _hotkeys: Dictionary = {}
var _searched: Dictionary = {}  ## record keys already found: the hints suggest others
var _back: Callable = Callable()
var _choices: Dictionary = {}
var _open: bool = false
var _crt: Control
var _flash: ColorRect
var _closing: bool = false
var _booted: bool = false
var _boot_gen: int = 0
const CRT_OFF: String = "res://assets/audio/sfx/crt_off.wav"
var _btn_normal: StyleBoxEmpty = StyleBoxEmpty.new()
var _btn_hover: StyleBoxFlat
var _thought: ThoughtBox
var _clock: Label
## In-game time on the computer: starts at 01:47:00 and keeps running (real seconds).
var _clock_secs: float = 1.0 * 3600.0 + 47.0 * 60.0
const CLOCK_DATE: String = "18.11.98"

const CHOICE_THOUGHT_TIME: float = 3.0


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
	bezel.position = Vector2(52, 36)
	bezel.size = Vector2(532, 288)
	_crt = Control.new()
	_crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt.pivot_offset = bezel.position + bezel.size / 2.0
	_root.add_child(_crt)
	_crt.add_child(bezel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	bezel.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	col.add_child(head)
	var title: Label = _label(str(_d.get("header", "")), GREEN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_clock = _label(_clock_text(), GREEN_DIM)
	head.add_child(_clock)
	var line: ColorRect = ColorRect.new()
	line.color = GREEN_DIM
	line.custom_minimum_size = Vector2(0, 1)
	col.add_child(line)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(TEXT_W, 204)
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
	_crt.add_child(scan)
	# white glow for switching off (the picture collapses into a line, then a dot)
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.position = scan.position
	_flash.size = scan.size
	_flash.color = Color(0.85, 1.0, 0.88, 0.0)
	_crt.add_child(_flash)
	# Alexei's thoughts while he works at the computer (below the monitor)
	_thought = ThoughtBox.new()
	_root.add_child(_thought)


# --- public --------------------------------------------------------------

func open() -> void:
	if _closing:
		return
	_open = true
	visible = true
	_crt.scale = Vector2.ONE
	_flash.color.a = 0.0
	_audio("sfx", "res://assets/audio/sfx/crt_on.wav", -6.0)
	_clear()
	_footer.visible = false
	var lines: Array = _d.get("boot", []) if not _booted else _d.get("resume", [])
	_boot_gen += 1
	var gen: int = _boot_gen  # closing and reopening during the boot starts it again
	for l: Variant in lines:
		if not _open or gen != _boot_gen:
			return
		if l is Dictionary:
			await _boot_step(l)
		else:
			_body.add_child(_label(str(l), GREEN))
			_audio("sfx", "res://assets/audio/sfx/key_tick.wav", -18.0)
			await get_tree().create_timer(0.35 if _booted else 0.3).timeout
	if not _open or gen != _boot_gen:
		return
	_booted = true
	await get_tree().create_timer(0.7).timeout
	if _open:
		_show_menu()
		if not _first_thought_done and not first_thought.is_empty():
			_first_thought_done = true
			_thought.show_text(first_thought, 5.0)


## One animated boot line: memory counter, or dots appearing then a result.
func _boot_step(l: Dictionary) -> void:
	var lab: Label = _label(str(l.get("text", "")), GREEN)
	_body.add_child(lab)
	var base: String = lab.text
	if l.has("mem"):
		var total: int = int(l["mem"])
		var kb: int = 0
		while kb < total and _open and is_instance_valid(lab):
			kb = mini(total, kb + 32)
			lab.text = "%s %d" % [base, kb]
			_audio("sfx", "res://assets/audio/sfx/key_tick.wav", -24.0)
			await get_tree().create_timer(0.06).timeout
		if not is_instance_valid(lab):
			return
		lab.text = "%s %d%s" % [base, total, str(l.get("result", ""))]
	else:
		var dt: float = float(l.get("dot_time", 0.16))
		if l.get("modem", false):
			_audio("sfx", "res://assets/audio/sfx/dialtone.wav", -22.0)
		for i: int in int(l.get("dots", 3)):
			if not _open or not is_instance_valid(lab):
				return
			lab.text = base + " " + ".".repeat(i + 1)
			await get_tree().create_timer(dt).timeout
		if not is_instance_valid(lab):
			return
		lab.text = lab.text + str(l.get("result", ""))
	_audio("sfx", "res://assets/audio/sfx/key_tick.wav", -16.0)
	await get_tree().create_timer(0.25).timeout


func is_open() -> bool:
	return _open


## Switching off like an old CRT: a flash, the picture collapses to a line, then to a dot.
func close() -> void:
	if _closing:
		return
	_closing = true
	_thought.hide_box()
	_open = false
	_audio("sfx", CRT_OFF, -8.0)
	var t: Tween = create_tween()
	t.tween_property(_flash, "color:a", 0.9, 0.06)
	t.tween_property(_crt, "scale", Vector2(1.0, 0.012), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_crt, "scale", Vector2(0.004, 0.012), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_interval(0.12)
	t.tween_property(_crt, "modulate:a", 0.0, 0.1)
	await t.finished
	visible = false
	_crt.scale = Vector2.ONE
	_crt.modulate.a = 1.0
	_flash.color.a = 0.0
	_closing = false
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
			"cards": cb = func() -> void: _show_list(str(_d["cards_title"]), _cards(), _show_menu)
			"news": cb = func() -> void: _show_list(str(_d["news_title"]), _d["news"], _show_menu)
			"inbox": cb = func() -> void: _show_list(str(_d["inbox_title"]), _d["memos"], _show_menu)
			"report": cb = _show_report_entry
			_: cb = close
		_item(label, cb, label.substr(0, 1))


func _show_search() -> void:
	_screen(_show_menu)
	_body.add_child(_label(str(_d.get("search_prompt", "")), GREEN))
	var le: LineEdit = LineEdit.new()
	le.custom_minimum_size = Vector2(220, 0)
	le.max_length = 24
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
	# what to look for: a few names not searched yet (click = search)
	_body.add_child(_gap())
	var help: Label = _text(str(_d.get("search_help", "")))
	help.add_theme_color_override("font_color", GREEN_DIM)
	_body.add_child(help)
	var shown: int = 0
	for h: Variant in _d.get("search_hints", []):
		var name: String = str(h)
		if _searched.has(_lookup(name)) or shown >= 4:
			continue
		shown += 1
		_item("  › " + name, _show_result.bind(name), "")


func _show_result(query: String) -> void:
	var key: String = _lookup(query)
	if key != "":
		_searched[key] = true
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
		_item("%s. %s" % [n, str(q[opt])], func() -> void: _choose(i, q, opt), n)


## A choice: one short thought from Alexei, and the next question right away (no waiting).
func _choose(i: int, q: Dictionary, opt: String) -> void:
	_choices[str(q["id"])] = opt
	var think: String = str(q.get("think_" + opt, ""))
	_show_question(i + 1)
	if not think.is_empty() and _open:
		_thought.show_text(think, CHOICE_THOUGHT_TIME)


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
	_body.add_child(_label(str(_d["report"]["filed"]).replace("01:52", clock_hm()), GREEN))
	_item("0. ВЫХОД", close, "0")
	report_filed.emit(_choices.duplicate())


# --- helpers -------------------------------------------------------------

## Cards = records by key, shown as a list.
func _cards() -> Array:
	var out: Array = []
	for c: Dictionary in _d.get("cards", []):
		out.append({"label": str(c["label"]), "text": str(_d["records"].get(str(c["key"]), ""))})
	return out


func _lookup(query: String) -> String:
	var q: String = " ".join(query.strip_edges().to_upper().split(" ", false)).replace(",", "")
	var aliases: Dictionary = _d.get("aliases", {})
	var keys: Array = aliases.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())  # "КАРАМАЗОВ ИВАН" before "КАРАМАЗОВ"
	for a: String in keys:
		if q.begins_with(a):
			return str(aliases[a])
	# "ИВАН КАРАМАЗОВ": the first name first
	var parts: PackedStringArray = q.split(" ")
	if parts.size() == 2 and aliases.has(parts[1] + " " + parts[0]):
		return str(aliases[parts[1] + " " + parts[0]])
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


func _process(delta: float) -> void:
	_clock_secs += delta  # time passes even while the computer is off
	if _open:
		_clock.text = _clock_text()


func _clock_text() -> String:
	var s: int = int(_clock_secs) % 86400
	return "%s  %02d:%02d:%02d" % [CLOCK_DATE, s / 3600, (s / 60) % 60, s % 60]


func clock_hm() -> String:
	var s: int = int(_clock_secs) % 86400
	return "%02d:%02d" % [s / 3600, (s / 60) % 60]


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
