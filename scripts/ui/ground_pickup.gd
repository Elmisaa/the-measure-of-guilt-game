extends Button

const REACH_2D: float = 85.0
const REACH_3D: float = 1.15

var _item_id: String = ""


func _ready() -> void:
	hide()
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", 9)
	add_theme_constant_override("icon_max_width", 20)
	Audio.bind_button(self)
	pressed.connect(pick_up)


func drop(id: String) -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	var player: Node = _find_player(scene)
	var point: Array = []
	if player is Node2D:
		var pos: Vector2 = player.global_position
		point = [pos.x, pos.y]
	elif player is Node3D:
		var pos: Vector3 = player.global_position
		point = [pos.x, pos.y, pos.z]
	return GameState.drop_item(id, scene.scene_file_path, point)


func refresh(can_interact: bool) -> void:
	var scene: Node = get_tree().current_scene
	if not can_interact or scene == null or GameState.dropped_items.is_empty():
		hide()
		return
	var player: Node = _find_player(scene)
	var nearest: String = ""
	var nearest_distance: float = INF
	var screen_point: Vector2 = Vector2(320, 305)
	for id: String in GameState.dropped_items:
		var drop_data: Dictionary = GameState.dropped_items[id]
		if drop_data["scene"] != scene.scene_file_path:
			continue
		var point: Array = drop_data["position"]
		var distance: float = 0.0
		var projected: Vector2 = Vector2(320, 305)
		if point.size() == 2:
			if not player is Node2D:
				continue
			var pos: Vector2 = Vector2(float(point[0]), float(point[1]))
			distance = player.global_position.distance_to(pos)
			if distance > REACH_2D:
				continue
			projected = player.get_canvas_transform() * pos
		elif point.size() == 3:
			var camera: Camera3D = get_viewport().get_camera_3d()
			if not player is Node3D or camera == null:
				continue
			var pos: Vector3 = Vector3(float(point[0]), float(point[1]), float(point[2]))
			distance = player.global_position.distance_to(pos)
			if distance > REACH_3D or camera.is_position_behind(pos):
				continue
			projected = camera.unproject_position(pos)
		if distance < nearest_distance:
			nearest = id
			nearest_distance = distance
			screen_point = projected
	if nearest.is_empty():
		hide()
		return
	if nearest != _item_id:
		_item_id = nearest
		var item: Dictionary = GameState.item_def(nearest)
		text = "G — Поднять: " + str(item.get("name", nearest))
		var path: String = str(item.get("icon", ""))
		icon = load(path) if ResourceLoader.exists(path) else null
		reset_size()
	position = Vector2(
		clampf(screen_point.x - size.x * 0.5, 4.0, 636.0 - size.x),
		clampf(screen_point.y - size.y - 5.0, 4.0, 328.0 - size.y)
	).round()
	show()


func pick_up() -> void:
	refresh(visible)
	if not visible:
		return
	GameState.take_dropped_item(_item_id, get_tree().current_scene.scene_file_path)
	refresh(true)


func _find_player(scene: Node) -> Node:
	var player: Node = scene.get_node_or_null("Player")
	if player == null:
		player = scene.get_node_or_null("World/Player")
	return player
