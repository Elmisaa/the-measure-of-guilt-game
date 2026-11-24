class_name Bullet
extends Area3D

const LAYER_PLAYER_BULLET: int = 16
const LAYER_ENEMY_BULLET: int = 32
const MASK_PLAYER_BULLET: int = 1 | 4 | 128
const MASK_ENEMY_BULLET: int = 1 | 2 | 8
const PLAYER_COLOR: Color = Color(1, 0.93, 0.4, 1)
const PLAYER_EMISSION: Color = Color(1, 0.85, 0.3, 1)
const ENEMY_COLOR: Color = Color(1, 0.32, 0.12, 1)
const ENEMY_EMISSION: Color = Color(1, 0.25, 0.08, 1)
const EMISSION_ENERGY: float = 3.0

@export var speed: float = 40.0
@export var lifetime: float = 2.0
@export var damage: int = 25
var is_enemy: bool = false
var swept: bool = false
var intended_target: Node3D = null

var direction: Vector3 = Vector3.RIGHT

var _life: Timer

func _ready() -> void:
	_orient()
	_apply_visual()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_life = get_node_or_null("Lifetime") as Timer
	if _life == null:
		_life = Timer.new()
		_life.name = "Lifetime"
		add_child(_life)
	_life.one_shot = true
	_life.timeout.connect(queue_free)
	_life.start(lifetime)

@warning_ignore("shadowed_variable")
func configure(dir: Vector3, is_enemy: bool, dmg: int, spd: float, target: Node3D = null) -> void:
	direction = dir.normalized()
	self.is_enemy = is_enemy
	damage = dmg
	speed = spd
	intended_target = target
	if is_enemy:
		collision_layer = LAYER_ENEMY_BULLET
		collision_mask = MASK_ENEMY_BULLET
	else:
		collision_layer = LAYER_PLAYER_BULLET
		collision_mask = MASK_PLAYER_BULLET
	_orient()
	_apply_visual()

func _apply_visual() -> void:
	var mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = ENEMY_COLOR if is_enemy else PLAYER_COLOR
	material.emission_enabled = true
	material.emission = ENEMY_EMISSION if is_enemy else PLAYER_EMISSION
	material.emission_energy_multiplier = EMISSION_ENERGY
	mesh.material_override = material

func _orient() -> void:
	if direction.length_squared() < 0.0001:
		return
	var forward: Vector3 = direction.normalized()
	var up: Vector3 = Vector3.UP
	if abs(forward.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var right: Vector3 = forward.cross(up).normalized()
	var actual_up: Vector3 = right.cross(forward).normalized()
	var basis: Basis = Basis(right, actual_up, -forward)
	rotation = basis.get_euler()

func _physics_process(delta: float) -> void:
	var destination: Vector3 = global_position + direction * speed * delta
	if swept:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, destination, collision_mask, [get_rid()])
		query.collide_with_areas = true
		query.hit_from_inside = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var collider: Node3D = hit["collider"] as Node3D
			if collider != null and not _fly_through(collider):
				global_position = hit["position"]
				if collider is Area3D:
					_on_area_entered(collider)
				else:
					_on_body_entered(collider)
				return
	global_position = destination

func _on_body_entered(body: Node3D) -> void:
	if is_queued_for_deletion():
		return
	if body != null:
		if _fly_through(body):
			return
		if body.has_method("take_bullet_hit"):
			body.call("take_bullet_hit")
		elif body.has_method("take_hit"):
			body.call("take_hit", 1)
		elif body.has_method("take_damage"):
			body.call("take_damage", damage)
	queue_free()

func _fly_through(body: Node3D) -> bool:
	if is_enemy or intended_target == null:
		return false
	if not is_instance_valid(intended_target) or intended_target.is_queued_for_deletion():
		intended_target = null
		return false
	if body == intended_target:
		return false
	return body.is_in_group("enemies")

func _on_area_entered(area: Area3D) -> void:
	if is_queued_for_deletion():
		return
	if area != null:
		if not is_enemy and area.is_in_group("conveyor_mount"):
			var conveyor: Node = get_tree().get_first_node_in_group("boss_conveyor")
			if conveyor:
				conveyor.call("hit_mount", area)
		if area.has_method("take_bullet_hit"):
			area.call("take_bullet_hit")
		elif area.has_method("take_hit"):
			area.call("take_hit", 1)
		queue_free()