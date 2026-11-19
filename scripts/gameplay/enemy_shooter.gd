class_name EnemyShooter
extends CharacterBody3D
## Враг-стрелок в 2.5D: стоит в коридоре (lane_z), видит игрока и бьёт очередями.
## Цикл: IDLE → TELEGRAPH (вспышка на стволе) → SHOOTING (burst_count пуль) →
## COOLDOWN (окно для ответного огня) → снова TELEGRAPH. Все задержки — float-таймеры
## в _physics_process, без await: состояние можно прервать оглушением или смертью в любой кадр.
## Слои: 3 = Enemy (4), маска 1 | 5 (World + PlayerBullet).
## Если игрок в укрытии — враг целится в укрытие (ломает ящики), пока то цело.

enum State { IDLE, TELEGRAPH, SHOOTING, COOLDOWN, STUNNED, DEAD }

signal shot_telegraphed
signal shot_fired(direction: Vector3)
signal health_changed(current: int, max_hp: int)
signal died(enemy: EnemyShooter)
signal state_changed(old_state: State, new_state: State)

const BulletScene: PackedScene = preload("res://scenes/gameplay/bullet.tscn")
const STATE_NAMES: Array[String] = ["IDLE", "TELEGRAPH", "SHOOTING", "COOLDOWN", "STUNNED", "DEAD"]
const LAYER_ENEMY: int = 4
const MASK_ENEMY: int = 1 | 16
## Высота груди (точка вылета пуль) и вынос ствола вперёд, м.
const CHEST_HEIGHT: float = 1.25
const MUZZLE_OFFSET: float = 0.55
const GRAVITY: float = 18.0
## Трение горизонтальной скорости в STUNNED (отбрасывание дубинкой).
const KNOCKBACK_FRICTION: float = 20.0
## Длительность белой вспышки от попадания, сек.
const FLASH_TIME: float = 0.08
const WHITE: Color = Color(1, 1, 1, 1)

@export var max_health: int = 75
@export var lane_z: float = 0.0
@export var detection_range: float = 12.0
@export var telegraph_time: float = 0.4
@export var burst_count: int = 3
@export var burst_interval: float = 0.22
@export var cooldown_time: float = 2.0
@export var bullet_damage: int = 15
@export var bullet_speed: float = 16.0
## Дополнительная пауза перед первым циклом (чтобы враги не стреляли синхронно).
@export var start_cooldown: float = 0.0

var state: State = State.IDLE
var health: int = 0

var _state_time: float = 0.0
var _shots_left: int = 0
var _shot_timer: float = 0.0
var _player: Player = null
var _visual: Node3D
var _telegraph: Node3D
var _label: Label3D
var _body: MeshInstance3D
var _material: StandardMaterial3D
var _base_color: Color = WHITE
var _flash_left: float = 0.0
var _facing: float = -1.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = LAYER_ENEMY
	collision_mask = MASK_ENEMY
	health = max_health
	global_position.z = lane_z
	_visual = get_node_or_null("Visual") as Node3D
	_telegraph = get_node_or_null("Visual/TelegraphFlash") as Node3D
	_label = get_node_or_null("DebugLabel") as Label3D
	_body = get_node_or_null("Visual/Body") as MeshInstance3D
	if _telegraph != null:
		_telegraph.visible = false
	_setup_material()
	_update_label()
	health_changed.emit(health, max_health)
	if start_cooldown > 0.0:
		_set_state(State.COOLDOWN)
		_state_time = start_cooldown


func _physics_process(delta: float) -> void:
	_tick_flash(delta)
	if state == State.DEAD:
		return
	_refresh_player()
	if state == State.STUNNED:
		_tick_stunned(delta)
		_state_time -= delta
		if _state_time <= 0.0:
			velocity.x = 0.0
			_set_state(State.IDLE)
		return
	_tick_gravity(delta)
	_face_player()

	# Игрок умер/исчез — прерываем телеграф и очередь, возвращаемся в IDLE.
	if state != State.IDLE and not _is_player_alive():
		_reset_to_idle()
		return

	match state:
		State.IDLE:
			if _can_see_player():
				_begin_telegraph()
		State.TELEGRAPH:
			_state_time -= delta
			if _state_time <= 0.0:
				_begin_shooting()
		State.SHOOTING:
			_tick_shooting(delta)
		State.COOLDOWN:
			_state_time -= delta
			if _state_time <= 0.0:
				if _can_see_player():
					_begin_telegraph()
				else:
					_set_state(State.IDLE)


# --- цикл стрельбы --------------------------------------------------------

func _begin_telegraph() -> void:
	_set_state(State.TELEGRAPH)
	_state_time = maxf(telegraph_time, 0.0)
	if _telegraph != null:
		_telegraph.visible = true
	shot_telegraphed.emit()


func _begin_shooting() -> void:
	_set_state(State.SHOOTING)
	if _telegraph != null:
		_telegraph.visible = false
	_shots_left = maxi(burst_count, 0)
	_shot_timer = 0.0


func _tick_shooting(delta: float) -> void:
	if _shots_left <= 0:
		_enter_cooldown()
		return
	_shot_timer -= delta
	while _shot_timer <= 0.0 and _shots_left > 0:
		_fire()
		_shots_left -= 1
		_shot_timer += burst_interval
	if _shots_left <= 0:
		_enter_cooldown()


func _enter_cooldown() -> void:
	_set_state(State.COOLDOWN)
	_state_time = maxf(cooldown_time, 0.0)


func _reset_to_idle() -> void:
	if _telegraph != null:
		_telegraph.visible = false
	_shots_left = 0
	_set_state(State.IDLE)


## Точка прицела: активное укрытие игрока (бьём по нему, пока цело), иначе грудь игрока.
func _aim_point() -> Vector3:
	if _player != null and is_instance_valid(_player) and _player.is_in_cover():
		var cover: Cover = _player.get_active_cover()
		if cover != null and is_instance_valid(cover):
			var cover_y: float = minf(0.75, cover.cover_size.y * 0.6)
			return Vector3(cover.global_position.x, cover_y, lane_z)
	if _player != null and is_instance_valid(_player):
		return Vector3(_player.global_position.x, _player.global_position.y + CHEST_HEIGHT, lane_z)
	return Vector3(global_position.x + _facing, CHEST_HEIGHT, lane_z)


func _fire() -> void:
	var origin: Vector3 = Vector3(global_position.x, global_position.y + CHEST_HEIGHT, lane_z)
	var direction: Vector3 = _aim_point() - origin
	direction.z = 0.0
	if direction.length_squared() < 0.0001:
		direction = Vector3(_facing, 0.0, 0.0)
	direction = direction.normalized()
	_spawn_bullet(origin + direction * MUZZLE_OFFSET, direction)
	shot_fired.emit(direction)


func _spawn_bullet(at: Vector3, direction: Vector3) -> void:
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_parent()
	if world == null:
		return
	var bullet: Node3D = BulletScene.instantiate() as Node3D
	if bullet.has_method("configure"):
		bullet.call("configure", direction, true, bullet_damage, bullet_speed)
	var parent_3d: Node3D = world as Node3D
	if parent_3d != null:
		bullet.position = parent_3d.to_local(at)
	world.add_child(bullet)
	if parent_3d == null:
		bullet.global_position = at


# --- восприятие и поворот -------------------------------------------------

func _refresh_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as Player


func _is_player_alive() -> bool:
	return _player != null and is_instance_valid(_player) and _player.is_alive()


func _can_see_player() -> bool:
	if not _is_player_alive():
		return false
	return absf(_player.global_position.x - global_position.x) <= detection_range


## Разворот плоского визуала по X в сторону игрока (как у Player).
func _face_player() -> void:
	if _visual == null or _player == null or not is_instance_valid(_player):
		return
	var dx: float = _player.global_position.x - global_position.x
	if absf(dx) < 0.01:
		return
	_facing = -1.0 if dx < 0.0 else 1.0
	_visual.scale.x = _facing


func _tick_gravity(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	global_position.z = lane_z


## STUNNED после удара/тазера: горизонтальная скорость гаснет трением, враг отлетает.
func _tick_stunned(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	global_position.z = lane_z


# --- урон, оглушение, смерть ---------------------------------------------

func take_damage(amount: int) -> void:
	if state == State.DEAD or amount <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	_update_label()
	_start_flash()
	if health == 0:
		_die()


## Заготовка под тазер: прерывает телеграф/очередь и держит врага в STUNNED duration сек.
func apply_stun(duration: float) -> void:
	if state == State.DEAD or duration <= 0.0:
		return
	if _telegraph != null:
		_telegraph.visible = false
	_shots_left = 0
	velocity.x = 0.0
	_set_state(State.STUNNED)
	_state_time = duration


## Отбрасывание дубинкой/пинком: прерывает атаку, станит и толкает по X с трением.
func apply_knockback(dir_x: float, force: float, stun_duration: float = 0.6) -> void:
	if state == State.DEAD or force <= 0.0:
		return
	apply_stun(stun_duration)
	velocity.x = signf(dir_x) * force


func is_dead() -> bool:
	return state == State.DEAD


func _die() -> void:
	if state == State.DEAD:
		return
	if _telegraph != null:
		_telegraph.visible = false
	collision_layer = 0
	collision_mask = 0
	if _visual != null:
		_visual.rotation.z = PI * 0.5
		_visual.position.y = 0.1
	_set_state(State.DEAD)
	died.emit(self)


func _setup_material() -> void:
	if _body == null:
		return
	var source: Material = _body.material_override
	if source is StandardMaterial3D:
		_material = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
		_body.material_override = _material
		_base_color = _material.albedo_color


func _start_flash() -> void:
	_flash_left = FLASH_TIME
	if _material != null:
		_material.albedo_color = WHITE


func _tick_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0 and _material != null:
		_material.albedo_color = _base_color


# --- состояние и дебаг-метка ---------------------------------------------

func _set_state(next: State) -> void:
	if state == next:
		return
	var old_state: State = state
	state = next
	_update_label()
	state_changed.emit(old_state, next)


func _update_label() -> void:
	if _label == null:
		return
	var state_name: String = STATE_NAMES[state] if state >= 0 and state < STATE_NAMES.size() else "?"
	_label.text = "HP: %d | %s" % [health, state_name]
