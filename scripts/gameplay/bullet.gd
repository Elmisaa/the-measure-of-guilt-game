class_name Bullet
extends Area3D
## 3D-пуля: летит по полному 3D-вектору direction, сама удаляется по таймеру.
## Слои: 16 = PlayerBullet, 32 = EnemyBullet.
## Пуля игрока: маска 1 | 4 | 128 (World, Cover, BossTarget).
## Пуля врага: маска 1 | 2 | 8 (World, Player, Cover).
## Попадание: Body/Area с take_bullet_hit() — вызываем и удаляем пулю.

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

## Настройка пули: направление, сторона, урон, скорость, цель.
## intended_target — выбранная цель: пуля пролетает сквозь других врагов.
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

## Ориентация пули по полному 3D-вектору direction.
func _orient() -> void:
	if direction.length_squared() < 0.0001:
		return
	# Поворачиваем длинную ось (X) в сторону direction
	var forward: Vector3 = direction.normalized()
	var up: Vector3 = Vector3.UP
	# Если летим почти вертикально — используем другой up
	if abs(forward.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var right: Vector3 = forward.cross(up).normalized()
	var actual_up: Vector3 = right.cross(forward).normalized()
	var basis: Basis = Basis(right, actual_up, -forward)
	rotation = basis.get_euler()

func _physics_process(delta: float) -> void:
	var step: Vector3 = direction * speed * delta
	global_position += step

func _on_body_entered(body: Node3D) -> void:
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

## Пуля игрока с выбранной целью пролетает мимо остальных врагов.
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
	if area != null:
		if area.has_method("take_bullet_hit"):
			area.call("take_bullet_hit")
		elif area.has_method("take_hit"):
			area.call("take_hit", 1)
		queue_free()