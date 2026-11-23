class_name CombatEncounter
extends Node

signal encounter_won
signal encounter_lost

@export var victory_flag: String = ""
@export var next_scene_id: String = ""
@export var allow_restart_on_enter: bool = true

var _player: Player = null
var _enemies: Array[Node3D] = []
var _victory_banner: Control = null
var _defeat_banner: Control = null
var _encounter_ended: bool = false


func _ready() -> void:
	_rebind()
	call_deferred("_connect_player_died")


func _process(delta: float) -> void:
	if _encounter_ended:
		return
	_check_victory()


func _input(event: InputEvent) -> void:
	if _encounter_ended and allow_restart_on_enter:
		if event is InputEventKey and event.pressed:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER] or event.is_action("ui_accept"):
				get_tree().reload_current_scene()


func _connect_player_died() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)


func _rebind() -> void:
	if not is_inside_tree():
		return
	_player = get_tree().get_first_node_in_group("player") as Player
	_enemies.clear()
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is Node3D and is_instance_valid(node):
			_enemies.append(node as Node3D)


func _check_victory() -> void:
	if _encounter_ended:
		return
	var all_dead: bool = true
	for enemy: Node3D in _enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_dead"):
			if not bool(enemy.call("is_dead")):
				all_dead = false
				break
		elif is_instance_valid(enemy):
			all_dead = false
			break
	if all_dead and _enemies.size() > 0:
		_on_victory()


func _on_victory() -> void:
	_encounter_ended = true
	encounter_won.emit()
	if victory_flag != "":
		var game_state: Node = get_node_or_null("/root/GameState")
		if game_state != null and game_state.has_method("set_flag"):
			game_state.call("set_flag", victory_flag, true)
	_show_victory_banner()
	if next_scene_id != "":
		var scene_router: Node = get_node_or_null("/root/SceneRouter")
		if scene_router != null and scene_router.has_method("change_scene"):
			scene_router.call_deferred("change_scene", next_scene_id)


func _on_player_died() -> void:
	_encounter_ended = true
	encounter_lost.emit()
	_show_defeat_banner()


func _show_victory_banner() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 60
	add_child(canvas)
	var center_container: CenterContainer = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center_container)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_banner_style(Color(0.1, 0.4, 0.1, 0.95)))
	center_container.add_child(panel)
	var label: Label = Label.new()
	label.text = "AREA CLEAR\nPress ENTER to restart"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)


func _show_defeat_banner() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 60
	add_child(canvas)
	var center_container: CenterContainer = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center_container)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_banner_style(Color(0.4, 0.1, 0.1, 0.95)))
	center_container.add_child(panel)
	var label: Label = Label.new()
	label.text = "YOU DIED\nPress ENTER to restart"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)


func _make_banner_style(bg_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.6, 0.6, 0.6, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	return style