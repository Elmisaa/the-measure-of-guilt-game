extends CanvasLayer

const FADE_TIME: float = 0.35

var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func go_to(path: String, hold: float = 0.0) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t: Tween = create_tween()
	t.tween_property(_rect, "modulate:a", 1.0, FADE_TIME)
	await t.finished
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: cannot open %s (%s)" % [path, error_string(err)])
	await get_tree().process_frame
	await get_tree().process_frame
	var sg: Node = get_node_or_null("/root/SaveGame")
	if sg:
		sg.autosave()
	t = create_tween()
	t.tween_property(_rect, "modulate:a", 0.0, FADE_TIME)
	await t.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
