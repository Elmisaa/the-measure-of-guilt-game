extends CanvasLayer

const FADE_TIME: float = 0.35

var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func is_transitioning() -> bool:
	return _busy


func go_to(path: String, hold: float = 0.0, before_ready: Callable = Callable()) -> bool:
	if _busy:
		return false
	var scene: PackedScene = ResourceLoader.load(path, "PackedScene") as PackedScene
	if scene == null:
		push_error("SceneRouter: cannot load %s as a scene" % path)
		return false
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t: Tween = create_tween()
	t.tween_property(_rect, "modulate:a", 1.0, FADE_TIME)
	await t.finished
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout
	var err: Error = get_tree().change_scene_to_packed(scene)
	if err != OK:
		push_error("SceneRouter: cannot open %s (%s)" % [path, error_string(err)])
	else:
		# Packed scenes enter the tree on the next frame.
		if before_ready.is_valid():
			before_ready.call()
		await get_tree().scene_changed
		await get_tree().process_frame
		var sg: Node = get_node_or_null("/root/SaveGame")
		if sg:
			sg.autosave()
	t = create_tween()
	t.tween_property(_rect, "modulate:a", 0.0, FADE_TIME)
	await t.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	return err == OK
