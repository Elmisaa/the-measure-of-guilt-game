class_name Player
extends CharacterBody2D
## Игрок: стейт-машина IDLE / RUN / AIM, ходьба A/D, прицел по ПКМ, стрельба по ЛКМ.
## Вид сбоку, координаты и скорости рассчитаны под 640x360.
## Графика — заглушка ColorRect 32x32 внутри узла Visual (его и отражаем).

enum State { IDLE, RUN, AIM }

signal state_changed(state: State)
signal died
signal health_changed(health: int, max_health: int)
signal shoot_fired(direction: Vector2)
signal ammo_changed(current: int, max: int)
signal reload_started
signal reload_finished

const BulletScene: PackedScene = preload("res://scenes/gameplay/bullet.tscn")

@export var speed: float = 100.0
@export var gravity: float = 900.0
@export var max_health: int = 100
@export var aim_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var ammo_max: int = 17
@export var reload_time: float = 1.5

var state: State = State.IDLE
var health: int = 0
var ammo_current: int = 0
var is_reloading: bool = false

var _visual: Node2D
var _barrel: CanvasItem
var _aim_marker: Node2D
var _facing: float = 1.0


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Node2D
	_barrel = get_node_or_null("Visual/Barrel") as CanvasItem
	_aim_marker = get_node_or_null("AimMarker") as Node2D
	_show_aim(false, Vector2.ZERO)
	health = max_health
	health_changed.emit(health, max_health)
	ammo_current = ammo_max
	ammo_changed.emit(ammo_current, ammo_max)


func _physics_process(delta: float) -> void:
	var move_axis: float = _read_move_axis()
	var aiming: bool = Input.is_mouse_button_pressed(aim_button)

	velocity.x = move_axis * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta
	move_and_slide()

	# Прицел важнее ходьбы: пока держат ПКМ — AIM.
	if aiming:
		var aim_point: Vector2 = get_global_mouse_position()
		_face_position(aim_point)
		_show_aim(true, aim_point)
		_set_state(State.AIM)
	else:
		_show_aim(false, Vector2.ZERO)
		if not is_zero_approx(move_axis):
			_face_direction(move_axis)
			_set_state(State.RUN)
		else:
			_set_state(State.IDLE)


## Видимые признаки прицела: ствол у персонажа и перекрестие под курсором.
func _show_aim(enabled: bool, point: Vector2) -> void:
	if _barrel != null:
		_barrel.visible = enabled
	if _aim_marker != null:
		_aim_marker.visible = enabled
		if enabled:
			_aim_marker.global_position = point


func is_aiming() -> bool:
	return state == State.AIM


## Направление на курсор; если курсор ровно на игроке — по текущему развороту.
func aim_direction() -> Vector2:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 0.0001:
		return Vector2(_facing, 0.0)
	return to_mouse.normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			shoot()
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var is_reload_key: bool = (
			key_event.keycode == KEY_R or key_event.physical_keycode == KEY_R
		)
		if key_event.pressed and not key_event.echo and is_reload_key:
			reload()


func shoot() -> void:
	if not is_alive() or is_reloading:
		return
	if ammo_current <= 0:
		print("Click")
		return
	ammo_current -= 1
	ammo_changed.emit(ammo_current, ammo_max)
	var direction: Vector2 = aim_direction()
	_face_direction(direction.x)
	_spawn_bullet(direction)
	shoot_fired.emit(direction)


func reload() -> void:
	if is_reloading or not is_alive() or ammo_current >= ammo_max:
		return
	is_reloading = true
	reload_started.emit()
	await get_tree().create_timer(reload_time).timeout
	if not is_inside_tree():
		return
	is_reloading = false
	ammo_current = ammo_max
	ammo_changed.emit(ammo_current, ammo_max)
	reload_finished.emit()


func _spawn_bullet(direction: Vector2) -> void:
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_parent()
	if world == null:
		return
	var bullet: Node2D = BulletScene.instantiate() as Node2D
	bullet.set("direction", direction)
	world.add_child(bullet)
	bullet.global_position = global_position + direction * 18.0


func _read_move_axis() -> float:
	var axis: float = 0.0
	if (Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
			or Input.is_action_pressed("ui_left")):
		axis -= 1.0
	if (Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
			or Input.is_action_pressed("ui_right")):
		axis += 1.0
	return axis


## Отражает спрайт по знаку направления (scale.x = -1 влево).
func _face_direction(direction: float) -> void:
	if is_zero_approx(direction):
		return
	_facing = -1.0 if direction < 0.0 else 1.0
	if _visual != null:
		_visual.scale.x = _facing


## Поворот в сторону мировой точки (курсора).
func _face_position(world_position: Vector2) -> void:
	_face_direction(world_position.x - global_position.x)


func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	state_changed.emit(state)


func is_alive() -> bool:
	return health > 0


func take_damage(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()
