class_name BossBullet
extends Bullet
## Снаряд финальной арены: inherits Bullet, но решает свои попадания сам.
## Длинная ось X мешалки совпадает с траекторией, а быстрый Area3D не может
## проскочить узкий хитбокс — путь проверяется непрерывным лучом.
## Обычные combat-скрипты не меняются: вся логика живёт здесь и в сценах boss/.

const TARGET_MASK: int = 128  # BossTarget
const ENEMY_MASK: int = 1 | 2 | 8  # World, Player, Cover
const SWEEP_PADDING: float = 0.1
const MAX_SWEEP_HITS: int = 4

var _boss_hit_processed: bool = false

## Маска и слой выставляются здесь, чтобы подписка HUD/conveyor на Bullet работала как раньше.
@warning_ignore("shadowed_variable")
func configure(dir: Vector3, enemy: bool, dmg: int, spd: float, target: Node3D = null) -> void:
	super.configure(dir, enemy, dmg, spd, target)
	collision_layer = Bullet.LAYER_ENEMY_BULLET if enemy else Bullet.LAYER_PLAYER_BULLET
	collision_mask = ENEMY_MASK if enemy else TARGET_MASK
	_orient()

## Поворот длинной оси (X) по вектору полёта: Basis(X=forward, Y=up, Z=right).
func _orient() -> void:
	if direction.length_squared() < 0.0001:
		return
	var forward: Vector3 = direction.normalized()
	var up: Vector3 = Vector3.UP
	if absf(forward.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var z_axis: Vector3 = forward.cross(up).normalized()
	var y_axis: Vector3 = z_axis.cross(forward).normalized()
	rotation = Basis(forward, y_axis, z_axis).get_euler()

func _physics_process(delta: float) -> void:
	if _boss_hit_processed:
		return
	var from: Vector3 = global_position
	var to: Vector3 = from + direction * speed * delta
	if _sweep_hit(from, to):
		return
	global_position = to

## Непрерывная проверка отрезка previous → next по слою арены.
func _sweep_hit(from: Vector3, to: Vector3) -> bool:
	var world: World3D = get_world_3d()
	if world == null:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from - direction * SWEEP_PADDING, to + direction * SWEEP_PADDING)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var excluded: Array[RID] = [get_rid()]
	query.exclude = excluded
	for _i in MAX_SWEEP_HITS:
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return false
		var collider: Object = hit.get("collider")
		var node: Node3D = collider as Node3D
		if node == null:
			return false
		if _consume_hit(node):
			return true
		# Контейнер конвейера обрабатывается своим area_entered — пролетаем дальше.
		if collider is CollisionObject3D:
			excluded.append((collider as CollisionObject3D).get_rid())
			query.exclude = excluded
	return false

func _consume_hit(node: Node3D) -> bool:
	if is_enemy:
		if node.is_in_group("player") and node.has_method("take_damage"):
			node.call("take_damage", damage)
		_finish_hit()
		return true
	# Пуля игрока: взрыв бочки/сбитие контейнера. У чужих area нет take_bullet_hit.
	if node.has_method("take_bullet_hit"):
		node.call("take_bullet_hit")
		_finish_hit()
		return true
	var shield: BossScales = node.get_meta("boss_shield") as BossScales if node.has_meta("boss_shield") else null
	if is_instance_valid(shield):
		shield.deflect_bullet(global_position)
		_finish_hit()
		return true
	return false

func _on_body_entered(body: Node3D) -> void:
	if body == null or _boss_hit_processed or not is_enemy:
		return
	_consume_hit(body)

func _on_area_entered(area: Area3D) -> void:
	if area == null or _boss_hit_processed:
		return
	if is_enemy:
		if area.is_in_group("player"):
			_consume_hit(area)
		return
	if area.has_method("take_bullet_hit") or area.has_meta("boss_shield"):
		_consume_hit(area)

func _finish_hit() -> void:
	if _boss_hit_processed:
		return
	_boss_hit_processed = true
	queue_free()
