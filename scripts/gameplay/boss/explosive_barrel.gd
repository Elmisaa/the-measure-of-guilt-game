class_name ExplosiveBarrel
extends Area3D
## Взрывная бочка для босс-арены. Слой 128 (BossTarget), группа "boss_targets".
## Красный цилиндр (0.6×0.9 м) + яркое кольцо-мишень сверху.
## При попадании: взрыв -25 урона боссу, -20 игроку в радиусе 2.2 м.

signal exploded(near_boss: bool, boss_damage: int, world_pos: Vector3)

@export var boss_damage: int = 25
@export var player_damage: int = 20
@export var blast_radius: float = 2.2
@export var near_boss: bool = true

var _body: MeshInstance3D
var _target_ring: MeshInstance3D
var _explosion_sphere: MeshInstance3D
var _explosion_timer: Timer
var _is_exploding: bool = false

func _ready() -> void:
	collision_layer = 128
	collision_mask = 1 | 4 | 128
	add_to_group("boss_targets")
	
	_body = get_node_or_null("Body") as MeshInstance3D
	_target_ring = get_node_or_null("TargetRing") as MeshInstance3D
	_explosion_sphere = get_node_or_null("ExplosionSphere") as MeshInstance3D
	
	if _explosion_sphere != null:
		_explosion_sphere.visible = false
	
	_explosion_timer = get_node_or_null("ExplosionTimer") as Timer
	if _explosion_timer == null:
		_explosion_timer = Timer.new()
		_explosion_timer.name = "ExplosionTimer"
		add_child(_explosion_timer)
	_explosion_timer.one_shot = true
	_explosion_timer.wait_time = 0.25
	if not _explosion_timer.timeout.is_connected(_on_explosion_timeout):
		_explosion_timer.timeout.connect(_on_explosion_timeout)
	
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if area is Bullet:
		take_bullet_hit()

func take_bullet_hit(_dmg: int = 0) -> void:
	if _is_exploding:
		return
	_is_exploding = true
	
	remove_from_group("boss_targets")
	
	if _target_ring != null:
		_target_ring.visible = false
	if _body != null:
		_body.visible = false
	
	# Показать сферу взрыва
	if _explosion_sphere != null:
		_explosion_sphere.visible = true
		var mat: StandardMaterial3D = _explosion_sphere.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			_explosion_sphere.material_override = mat
		mat.albedo_color = Color(1, 0.5, 0.0, 0.8)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.4, 0.0, 1)
		mat.emission_energy_multiplier = 10.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	_explosion_timer.start()
	
	# Урон игроку в радиусе
	_damage_player_in_radius()
	
	# Сигнал для босса
	exploded.emit(near_boss, boss_damage, global_position)

func _damage_player_in_radius() -> void:
	var p: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if p != null and p.global_position.distance_to(global_position) <= blast_radius and p.has_method("take_damage"):
		p.call("take_damage", player_damage)

func _on_explosion_timeout() -> void:
	if _explosion_sphere != null:
		_explosion_sphere.visible = false
	queue_free()