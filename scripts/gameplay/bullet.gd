class_name Bullet
extends Area3D
## 3D-пуля (2.5D): летит по direction в плоскости коридора и сама удаляется по таймеру.
## Слои: 5 = PlayerBullet (жёлтая), 6 = EnemyBullet (ярко-красная).
## Пуля игрока: маска 1 | 4 | 8 (World, Enemy, Cover) — своего игрока не задевает.
## Пуля врага: маска 1 | 2 | 8 (World, Player, Cover).
## Попадание: Cover — take_hit(1), Enemy/Player — take_damage(damage), World — просто гасим пулю.

## Слои/маски 3D-боя: 1 = World, 2 = Player, 3 = Enemy, 4 = Cover, 5 = PlayerBullet, 6 = EnemyBullet.
const LAYER_PLAYER_BULLET: int = 16
const LAYER_ENEMY_BULLET: int = 32
const MASK_PLAYER_BULLET: int = 1 | 4 | 8
const MASK_ENEMY_BULLET: int = 1 | 2 | 8
const PLAYER_COLOR: Color = Color(1, 0.93, 0.4, 1)
const PLAYER_EMISSION: Color = Color(1, 0.85, 0.3, 1)
const ENEMY_COLOR: Color = Color(1, 0.32, 0.12, 1)
const ENEMY_EMISSION: Color = Color(1, 0.25, 0.08, 1)
const EMISSION_ENERGY: float = 3.0

@export var speed: float = 22.0
@export var lifetime: float = 1.5
@export var damage: int = 25
## true — пуля врага (слой 6, красная, бьёт игрока); false — пуля игрока (слой 5).
var is_enemy: bool = false
## Выбранная игроком цель: сквозь остальных врагов пуля пролетает, не нанося урона.
var intended_target: Node3D = null

var direction: Vector3 = Vector3.RIGHT

var _life: Timer
var _plane_z: float = 0.0


func _ready() -> void:
	_plane_z = global_position.z
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


## Настройка пули до добавления в сцену: направление, сторона, урон и скорость.
## Сторона задаёт слой/маску (свои пули не задевают своего стрелка) и цвет.
## intended_target — выбранный игроком враг: сквозь других врагов пуля пролетает.
@warning_ignore("shadowed_variable")
func configure(dir: Vector3, is_enemy: bool, dmg: int, spd: float, target: Node3D = null) -> void:
	direction = dir
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


## Цвет и свечение: игрок — жёлтая, враг — ярко-красная/оранжевая.
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


## Длинная сторона бокса лежит по X: поворачиваем её на угол направления в плоскости XY.
func _orient() -> void:
	var flat: Vector3 = Vector3(direction.x, direction.y, 0.0)
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	rotation.z = atan2(flat.y, flat.x)


func _physics_process(delta: float) -> void:
	var step: Vector3 = direction * speed * delta
	global_position += Vector3(step.x, step.y, 0.0)
	global_position.z = _plane_z


func _on_body_entered(body: Node3D) -> void:
	if body != null:
		if _fly_through(body):
			return
		if body.has_method("take_hit"):
			body.call("take_hit", 1)
		elif body.has_method("take_damage"):
			body.call("take_damage", damage)
	queue_free()


## Пуля игрока с выбранной целью пролетает мимо остальных врагов (без урона и удаления).
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
	if area != null and area.has_method("take_hit"):
		area.call("take_hit", 1)
		queue_free()
