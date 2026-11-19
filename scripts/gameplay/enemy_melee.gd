class_name EnemyMelee
extends CharacterBody3D
## Враг ближнего боя в 2.5D: бежит по X к игроку и бьёт его «ножом/битой».
## Цикл: IDLE → CHASE (бежит даже к игроку в укрытии!) → WINDUP (красная вспышка,
## сигнал melee_telegraphed — окно для контрудара дубинкой) → ATTACK (урон, выбивает
## из укрытия) → COOLDOWN. Все задержки — float-таймеры в _physics_process, без await:
## состояние можно прервать оглушением, отбрасыванием или смертью в любой кадр.
## Слои: 3 = Enemy (4), маска 1 | 5 (World + PlayerBullet).

enum State { IDLE, CHASE, WINDUP, ATTACK, COOLDOWN, STUNNED, DEAD }

signal melee_telegraphed
signal attacked(target: Node3D)
signal health_changed(current: int, max_hp: int)
signal died(enemy: EnemyMelee)
signal state_changed(old_state: State, new_state: State)

const STATE_NAMES: Array[String] = ["IDLE", "CHASE", "WINDUP", "ATTACK", "COOLDOWN", "STUNNED", "DEAD"]
const LAYER_ENEMY: int = 4
const MASK_ENEMY: int = 1 | 16
const GRAVITY: float = 18.0
## Трение горизонтальной скорости в STUNNED (отбрасывание).
const KNOCKBACK_FRICTION: float = 20.0
## Длительность белой вспышки от попадания, сек.
const FLASH_TIME: float = 0.08
## Сколько длится кадр ATTACK после попадания.
const ATTACK_LINGER: float = 0.12
## Насколько дальше attack_range достаёт удар (игрок успел отойти — промах).
const HIT_REACH: float = 0.4
const WHITE: Color = Color(1, 1, 1, 1)

@export var max_health: int = 60
@export var move_speed: float = 2.8
@export var attack_range: float = 1.25
@export var windup_time: float = 0.45
@export var attack_damage: int = 20
@export var attack_cooldown: float = 1.0
@export var detection_range: float = 12.0
@export var lane_z: float = 0.0
## Дополнительная пауза перед первым броском (чтобы враги не бежали синхронно).
@export var start_cooldown: float = 0.0

var state: State = State.IDLE
var health: int = 0

var _state_time: float = 0.0
var _player: Player = null
var _visual: Node3D
var _windup_flash: Node3D
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
	_windup_flash = get_node_or_null("Visual/WindupFlash") as Node3D
	_label = get_node_or_null("DebugLabel") as Label3D
	_body = get_node_or_null("Visual/Body") as MeshInstance3D
	if _windup_flash != null:
		_windup_flash.visible = false
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
	_update_state(delta)
	_move(delta)
	_face_player()


# --- поведение ------------------------------------------------------------

func _update_state(delta: float) -> void:
	match state:
		State.IDLE:
			velocity.x = 0.0
			if _player_in_detection():
				_set_state(State.CHASE)
		State.CHASE:
			_tick_chase()
		State.WINDUP:
			velocity.x = 0.0
			_state_time -= delta
			if _state_time <= 0.0:
				_begin_attack()
		State.ATTACK:
			velocity.x = 0.0
			_state_time -= delta
			if _state_time <= 0.0:
				_enter_cooldown()
		State.COOLDOWN:
			velocity.x = 0.0
			_state_time -= delta
			if _state_time <= 0.0:
				if _player_in_attack_range():
					_begin_windup()
				else:
					_set_state(State.CHASE)
		State.STUNNED:
			velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
			_state_time -= delta
			if _state_time <= 0.0:
				velocity.x = 0.0
				_set_state(State.IDLE)


## Бежит по X к игроку, даже если тот прячется за укрытием — выгоняет его оттуда.
func _tick_chase() -> void:
	if not _is_player_alive():
		_reset_to_idle()
		return
	var dx: float = _player.global_position.x - global_position.x
	if absf(dx) <= attack_range:
		_begin_windup()
		return
	velocity.x = signf(dx) * move_speed


func _begin_windup() -> void:
	_set_state(State.WINDUP)
	_state_time = maxf(windup_time, 0.01)
	velocity.x = 0.0
	if _windup_flash != null:
		_windup_flash.visible = true
	melee_telegraphed.emit()


func _begin_attack() -> void:
	_set_state(State.ATTACK)
	_state_time = ATTACK_LINGER
	if _windup_flash != null:
		_windup_flash.visible = false
	_resolve_attack()


## Удар: урон игроку и выбивание из укрытия (если он всё ещё в радиусе attack_range + 0.4).
func _resolve_attack() -> void:
	if not _is_player_alive():
		return
	var dx: float = _player.global_position.x - global_position.x
	if absf(dx) > attack_range + HIT_REACH:
		return
	_player.take_damage(attack_damage)
	if _player.is_in_cover():
		_player.exit_cover()
	attacked.emit(_player)


func _enter_cooldown() -> void:
	_set_state(State.COOLDOWN)
	_state_time = maxf(attack_cooldown, 0.0)


func _reset_to_idle() -> void:
	if _windup_flash != null:
		_windup_flash.visible = false
	velocity.x = 0.0
	_set_state(State.IDLE)


func _move(delta: float) -> void:
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	global_position.z = lane_z


# --- восприятие и поворот -------------------------------------------------

func _refresh_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as Player


func _is_player_alive() -> bool:
	return _player != null and is_instance_valid(_player) and _player.is_alive()


func _player_in_detection() -> bool:
	if not _is_player_alive():
		return false
	return absf(_player.global_position.x - global_position.x) <= detection_range


func _player_in_attack_range() -> bool:
	if not _is_player_alive():
		return false
	return absf(_player.global_position.x - global_position.x) <= attack_range


## Разворот плоского визуала по X в сторону игрока (как у Player).
func _face_player() -> void:
	if _visual == null or _player == null or not is_instance_valid(_player):
		return
	var dx: float = _player.global_position.x - global_position.x
	if absf(dx) < 0.01:
		return
	_facing = -1.0 if dx < 0.0 else 1.0
	_visual.scale.x = _facing


# --- урон, оглушение, отбрасывание, смерть --------------------------------

func take_damage(amount: int) -> void:
	if state == State.DEAD or amount <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	_update_label()
	_start_flash()
	if health == 0:
		_die()


## Оглушение: прерывает замах/удар и держит врага в STUNNED duration сек.
func apply_stun(duration: float) -> void:
	if state == State.DEAD or duration <= 0.0:
		return
	if _windup_flash != null:
		_windup_flash.visible = false
	velocity.x = 0.0
	_set_state(State.STUNNED)
	_state_time = duration


## Отбрасывание дубинкой/пинком: прерывает замах, станит и толкает по X с трением.
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
	if _windup_flash != null:
		_windup_flash.visible = false
	collision_layer = 0
	collision_mask = 0
	velocity.x = 0.0
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
	_label.text = "MELEE | HP: %d | %s" % [health, state_name]
