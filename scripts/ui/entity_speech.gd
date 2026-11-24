extends RefCounted


static func show_in(parent: Control, text: String, wrap: bool = false) -> Control:
	var layer: Control = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	layer.name = "EntitySpeech"
	var offs: Array[Vector2] = [Vector2(-3, -1), Vector2(3, 1), Vector2(0, 0)]
	var alphas: Array[float] = [0.35, 0.35, 0.95]
	for i: int in 3:
		var l: RichTextLabel = RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
		l.size = Vector2(600, 60) if wrap else Vector2(640, 60)
		l.position = (Vector2(20, 128) if wrap else Vector2(0, 140)) + offs[i]
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.text = "[center][font_size=36][shake rate=14.0 level=%d connected=0][color=#e8e8ee]%s[/color][/shake][/font_size][/center]" % [4 + i * 3, text]
		l.modulate.a = 0.0
		layer.add_child(l)
		layer.create_tween().tween_property(l, "modulate:a", alphas[i], 0.5)
	return layer
