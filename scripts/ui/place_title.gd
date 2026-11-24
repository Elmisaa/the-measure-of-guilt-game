extends CanvasLayer


func show_lines(lines: Array, delay: float = 1.2) -> void:
	layer = 60
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(28, 16)
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	var labels: Array[Label] = []
	for i: int in lines.size():
		var l: Label = Label.new()
		l.text = str(lines[i])
		l.visible_characters = 0
		l.add_theme_color_override("font_color", Color(0.93, 0.9, 0.82) if i == 0 else Color(0.62, 0.86, 0.72))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		if i == 0:
			l.add_theme_font_size_override("font_size", 16)
		box.add_child(l)
		labels.append(l)
	await get_tree().create_timer(delay).timeout
	for l: Label in labels:
		for c: int in l.text.length():
			if not is_inside_tree():
				return
			l.visible_characters = c + 1
			if l.text[c] != " ":
				Audio.sfx("res://assets/audio/sfx/key_tick.wav", -20.0, randf_range(0.9, 1.1))
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(4.0).timeout
	var f: Tween = create_tween()
	f.tween_property(box, "modulate:a", 0.0, 1.2)
	await f.finished
	queue_free()
