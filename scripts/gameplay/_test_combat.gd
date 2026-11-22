extends Node3D
## Тестовая арена первой перестрелки: камера следит за игроком по X,
## ножевик впереди и два стрелка справа (победа — по всем врагам группы "enemies").
## Смерть игрока / зачистка арены показывают текст и ждут Enter для перезапуска сцены.

const RESULT_DIED: String = "YOU DIED — Enter to restart"
const RESULT_CLEAR: String = "AREA CLEAR — Enter to restart"
const CAMERA_Y: float = 1.9
const CAMERA_Z: float = 7.5
const CAMERA_FOLLOW_SPEED: float = 5.0
const ENEMY_DEAD_STATE: int = 5  # EnemyShooter.State.DEAD

var _player: Player
var _camera: Camera3D
var _enemies: Array[Node3D] = []
var _result_label: Label
var _finished: bool = false


func _ready() -> void:
	_player = get_node_or_null("Player") as Player
	_camera = get_node_or_null("Camera3D") as Camera3D
	_build_result_label()
	_collect_enemies()


func _process(delta: float) -> void:
	if _camera == null or _player == null:
		return
	var k: float = clampf(delta * CAMERA_FOLLOW_SPEED, 0.0, 1.0)
	_camera.global_position = Vector3(
		lerpf(_camera.global_position.x, _player.global_position.x, k),
		CAMERA_Y,
		CAMERA_Z)


func _unhandled_input(event: InputEvent) -> void:
	if not _finished:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func _collect_enemies() -> void:
	_enemies.clear()
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is not CharacterBody3D or not node.has_method("apply_stun"):
			continue
		var enemy: Node3D = node as Node3D
		_enemies.append(enemy)
		if not enemy.is_connected("died", _on_enemy_died):
			enemy.connect("died", _on_enemy_died)
	if _player != null and not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)


func _on_player_died() -> void:
	_show_result(RESULT_DIED)


func _on_enemy_died(_enemy: Node3D) -> void:
	if _enemies.is_empty():
		return
	for enemy: Node3D in _enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_dead") and not bool(enemy.call("is_dead")):
			return
		if int(enemy.get("state")) != ENEMY_DEAD_STATE:
			return
	_show_result(RESULT_CLEAR)


func _show_result(text: String) -> void:
	if _finished:
		return
	_finished = true
	if _result_label != null:
		_result_label.text = text
		_result_label.visible = true


func _build_result_label() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ResultLayer"
	layer.layer = 60
	add_child(layer)
	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 16)
	_result_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1))
	_result_label.visible = false
	layer.add_child(_result_label)
	_result_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
