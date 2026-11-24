extends VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var _name: Label = Label.new()
	_name.add_theme_font_size_override("font_size", 8)
	_name.name = "Speaker"
	add_child(_name)
	var _text: RichTextLabel = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(250, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	_text.name = "Line"
	add_child(_text)
