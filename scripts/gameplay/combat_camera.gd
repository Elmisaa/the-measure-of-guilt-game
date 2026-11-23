class_name CombatCamera
extends Camera3D

@export var follow_speed: float = 6.0
@export var look_ahead_x: float = 1.2
@export var min_x: float = -6.0
@export var max_x: float = 10.0

var _player: Player = null


func _ready() -> void:
	_rebind_player()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_rebind_player()
		return

	var facing_dir: float = 0.0
	if _player.has_method("get_facing_direction"):
		facing_dir = _player.get_facing_direction()
	else:
		if _player.velocity.x != 0.0:
			facing_dir = signf(_player.velocity.x)
		else:
			facing_dir = _get_player_facing()

	var target_x: float = _player.global_position.x + facing_dir * look_ahead_x
	target_x = clampf(target_x, min_x, max_x)

	var current_pos: Vector3 = global_position
	var new_x: float = lerpf(current_pos.x, target_x, follow_speed * delta)
	global_position = Vector3(new_x, current_pos.y, current_pos.z)


func _rebind_player() -> void:
	if not is_inside_tree():
		return
	_player = get_tree().get_first_node_in_group("player") as Player


func _get_player_facing() -> float:
	if _player == null:
		return 0.0
	var facing_val: Variant = _player.get("_facing")
	if facing_val != null:
		return float(facing_val)
	return 0.0