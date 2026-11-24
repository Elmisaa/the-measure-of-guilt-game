class_name MenuUI
extends RefCounted

const COLOR: Color = Color(0.62, 0.66, 0.7)
const COLOR_ON: Color = Color(0.95, 0.88, 0.66)
const COLOR_OFF: Color = Color(0.35, 0.37, 0.4)


static func button(text: String) -> Button:
	var b: Button = Button.new()
	set_button_text(b, text)
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_color_override("font_color", COLOR)
	b.add_theme_color_override("font_hover_color", COLOR)
	b.add_theme_color_override("font_disabled_color", COLOR_OFF)
	b.focus_entered.connect(func() -> void:
		b.text = "› " + b.text.substr(2)
		b.add_theme_color_override("font_color", COLOR_ON)
		b.add_theme_color_override("font_hover_color", COLOR_ON)
		b.add_theme_color_override("font_focus_color", COLOR_ON)
		var audio: Node = b.get_node_or_null("/root/Audio")
		if audio:
			audio.ui_hover())
	b.focus_exited.connect(func() -> void:
		b.text = "  " + b.text.substr(2)
		b.add_theme_color_override("font_color", COLOR)
		b.add_theme_color_override("font_hover_color", COLOR))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.pressed.connect(func() -> void:
		var audio: Node = b.get_node_or_null("/root/Audio")
		if audio:
			audio.ui_click())
	return b


static func set_button_text(b: Button, text: String) -> void:
	b.text = ("› " if b.has_focus() else "  ") + text


static func wasd_to_focus(event: InputEvent, vp: Viewport) -> bool:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed:
		return false
	var map: Dictionary = {KEY_W: "ui_up", KEY_S: "ui_down", KEY_A: "ui_left", KEY_D: "ui_right"}
	if not map.has(k.physical_keycode):
		return false
	var a: InputEventAction = InputEventAction.new()
	a.action = map[k.physical_keycode]
	a.pressed = true
	Input.parse_input_event(a)
	vp.set_input_as_handled()
	return true


static func panel_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.94)
	sb.border_color = Color(0.22, 0.24, 0.28, 1)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(12)
	return sb
