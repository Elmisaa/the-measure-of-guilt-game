class_name Player
extends CharacterBody3D
## Боевой игрок в 3D (2.5D-вид сбоку): X — влево/вправо, Y — вертикаль, Z — глубина.
## Ходьба A/D, стрельба по ЛКМ, перезарядка R, укрытие S/Space (зажимать), тазер Q, фонарь F.
## Прицела-режима нет: Visual всегда смотрит на точку прицела, ствол и AimMarker видны всегда.
## ПКМ (combat_melee) — пинок/дубинка: бьёт врагов рядом, отбрасывает их и станит.
## Выбор цели: ближайший живой враг у точки прицела подсвечивается TargetMarker, а выстрел
## корректируется ему в грудь (пуля пролетает мимо остальных врагов).
## Экшены регистрируются в рантайме (_ensure_combat_input), project.godot не трогаем.
## Движение по X: global_position.z удерживается на lane_z, в укрытии — на lane_z + offset укрытия.

enum State { IDLE, RUN, COVER, DEAD }

signal died
signal state_changed(state: State)
signal health_changed(health: int, max_health: int)
signal ammo_changed(current: int, max: int)
signal reload_started
signal reload_finished
## Перезарядка прервана (смерть, оглушение).
signal reload_cancelled
## Ближний бой и тазер.
signal melee_swung(direction: Vector3)
## Тазер попал в цель.
signal taser_fired(target: Node3D)
signal cover_changed(in_cover: bool)
signal flashlight_toggled(on: bool)
signal shoot_fired(direction: Vector3)
## Выбранная цель ближнего прицела сменилась (null — цели нет).
signal target_changed(target: Node3D)

const BulletScene: PackedScene = preload("res://scenes/gameplay/bullet.tscn")

## Слои коллизий (общие на проект): 1 = World, 2 = Player, 3 = Enemy, 4 = Cover,
## 5 = PlayerBullet, 6 = EnemyBullet, 7 = CoverZone. Игрок: слой 2, маска World + EnemyBullet.
const STICK_TO_FLOOR: float = -0.1
## Высота груди: точка прицела и вылета пули (м).
const CHEST_HEIGHT: float = 1.25
## Горизонтальный вылет пули от центра тела (м).
const MUZZLE_OFFSET: float = 0.45
## Фоллбэк прицела без камеры (headless-тесты): половина экрана = этот радиус в метрах.
const FALLBACK_AIM_RANGE: float = 5.0
## Шаг вглубь/обратно и присед в укрытии.
const COVER_Z_SPEED: float = 3.0
const COVER_CROUCH: float = 0.65
const COVER_CROUCH_SPEED: float = 4.0
## Центр врага для выбора цели (ноги стоят на Y = 0) и высота груди для выстрела в цель.
const TARGET_CENTER_HEIGHT: float = 0.9
const TARGET_CHEST_HEIGHT: float = 1.15
## Враг ближе этого расстояния считается «вплотную» и попадает под удар с любой стороны.
const CLOSE_MELEE_RANGE: float = 0.9
## Сколько секунд видна вспышка взмаха.
const MELEE_VISUAL_TIME: float = 0.14
## Сколько секунд виден разряд тазера.
const TASER_BEAM_TIME: float = 0.18

@export var speed: float = 3.5
@export var lane_z: float = 0.0
@export var max_health: int = 100
@export var ammo_max: int = 17
@export var gravity: float = 18.0
@export var reload_time: float = 1.5
## Радиус выбора цели вокруг точки прицела (м).
@export var target_select_radius: float = 1.4
@export var melee_range: float = 1.9
@export var melee_damage: int = 15
@export var melee_knockback: float = 9.5
@export var melee_stun: float = 0.65
@export var melee_cooldown: float = 0.55
## Тазер: число зарядов, радиус, длительность стана и кулдаун.
@export var taser_charges_max: int = 3
@export var taser_range: float = 4.2
@export var taser_stun_duration: float = 3.0
@export var taser_cooldown: float = 1.2
signal taser_charges_changed(current: int, max_charges: int)

@export var flashlight_enabled: bool = false

var state: State = State.IDLE
var health: int = 0
var ammo_current: int = 0
var is_reloading: bool = false
## Оглушение: внешняя система ставит true — ввод и перезарядка прерываются.
var stunned: bool = false
## Прячется за укрытием (State.COVER).
var in_cover: bool = false
var flashlight_on: bool = false
## Точка прицела извне (скриптовые сцены, тесты). null — по курсору мыши.
var aim_override: Variant = null
## Живой враг у точки прицела (пуля летит мимо остальных врагов именно в него).
var selected_target: Node3D = null
## Оставшиеся заряды тазера (пополняются только при рестарте сцены).
var taser_charges: int = 0

var _visual: Node3D
var _aim_marker: Node3D
var _target_marker: Node3D
var _melee_visual: Node3D
var _taser_beam: MeshInstance3D
var _flashlight: SpotLight3D
var _reload_timer: Timer
var _melee_timer: Timer
var _taser_timer: Timer
var _hud: Node
var _facing: float = 1.0
## Кулдаун ближнего боя: пока false, ПКМ игнорируется.
var _melee_ready: bool = true
var _melee_visual_left: float = 0.0
var _taser_beam_left: float = 0.0
## Укрытия, чьи CoverZone сейчас накрывают игрока.
var _covers: Array[Cover] = []
var _active_cover: Cover = null


func _ready() -> void:
	add_to_group("player")
	_ensure_combat_input()
	_ensure_reload_timer()
	_hud = get_node_or_null("/root/Hud")  # не глобальное имя: class_name компилируется раньше
	_visual = get_node_or_null("Visual") as Node3D
	_aim_marker = get_node_or_null("AimMarker") as Node3D
	if _aim_marker != null:
		_aim_marker.visible = true
	_ensure_melee_nodes()
	_ensure_taser_nodes()
	_flashlight = get_node_or_null("Flashlight") as SpotLight3D
	var barrel: Node3D = get_node_or_null("Visual/Barrel") as Node3D
	if barrel != null:
		barrel.visible = true
	global_position.z = lane_z
	health = max_health
	health_changed.emit(health, max_health)
	ammo_current = ammo_max
	ammo_changed.emit(ammo_current, ammo_max)
	taser_charges = maxi(taser_charges_max, 0)
	taser_charges_changed.emit(taser_charges, taser_charges_max)
	if flashlight_enabled:
		flashlight_on = true
		if _flashlight != null:
			_flashlight.set("enabled", true)
			_flashlight.visible = true
		flashlight_toggled.emit(true)


## Экшены боя по образцу walk_player.gd: недостающие добавляем в InputMap в рантайме.
## move_left / move_right переиспользуем (их создаёт и ходьба по участку).
func _ensure_combat_input() -> void:
	for pair: Array in [
		["move_left", [KEY_A, KEY_LEFT]],
		["move_right", [KEY_D, KEY_RIGHT]],
		["combat_reload", [KEY_R]],
		["combat_cover", [KEY_S, KEY_SPACE]],
		["combat_taser", [KEY_Q]],
		["combat_flashlight", [KEY_F]],
	]:
		var action: String = pair[0]
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in pair[1]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	for pair: Array in [["combat_shoot", MOUSE_BUTTON_LEFT], ["combat_melee", MOUSE_BUTTON_RIGHT]]:
		var action: String = pair[0]
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = pair[1]
		InputMap.action_add_event(action, ev)


## Перезарядка на узле Timer: её можно безопасно прервать в любой момент.
func _ensure_reload_timer() -> void:
	_reload_timer = get_node_or_null("ReloadTimer") as Timer
	if _reload_timer == null:
		_reload_timer = Timer.new()
		_reload_timer.name = "ReloadTimer"
		add_child(_reload_timer)
	_reload_timer.one_shot = true
	_reload_timer.wait_time = reload_time
	if not _reload_timer.timeout.is_connected(_on_reload_timeout):
		_reload_timer.timeout.connect(_on_reload_timeout)


## Кулдаун ПКМ и вспышка взмаха: узлы берём из сцены, при их отсутствии создаём сами.
func _ensure_melee_nodes() -> void:
	_melee_timer = get_node_or_null("MeleeCooldownTimer") as Timer
	if _melee_timer == null:
		_melee_timer = Timer.new()
		_melee_timer.name = "MeleeCooldownTimer"
		add_child(_melee_timer)
	_melee_timer.one_shot = true
	if not _melee_timer.timeout.is_connected(_on_melee_timeout):
		_melee_timer.timeout.connect(_on_melee_timeout)
	_melee_visual = get_node_or_null("MeleeVisual") as Node3D
	if _melee_visual == null:
		var swing: MeshInstance3D = MeshInstance3D.new()
		swing.name = "MeleeVisual"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.85, 0.16, 0.08)
		swing.mesh = box
		swing.material_override = _make_melee_material()
		add_child(swing)
		_melee_visual = swing
	_melee_visual.visible = false
	_ensure_target_marker()


## Яркое кольцо на выбранном враге (top_level — живёт в мировых координатах).
func _ensure_target_marker() -> void:
	_target_marker = get_node_or_null("TargetMarker") as Node3D
	if _target_marker == null:
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.name = "TargetMarker"
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.28
		torus.outer_radius = 0.38
		marker.mesh = torus
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(1, 0.1, 0.1, 1)
		material.emission_enabled = true
		material.emission = Color(1, 0.05, 0.05, 1)
		material.emission_energy_multiplier = 3.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		marker.material_override = material
		marker.rotation.x = PI * 0.5
		marker.top_level = true
		add_child(marker)
		_target_marker = marker
	_target_marker.visible = false


func _make_melee_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.9, 1.0, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.55, 0.8, 1.0, 1)
	material.emission_energy_multiplier = 1.5
	return material


func _on_melee_timeout() -> void:
	_melee_ready = true


## Тазер: узел-таймер кулдауна и тонкий светящийся луч в мировых координатах.
func _ensure_taser_nodes() -> void:
	_taser_timer = get_node_or_null("TaserCooldownTimer") as Timer
	if _taser_timer == null:
		_taser_timer = Timer.new()
		_taser_timer.name = "TaserCooldownTimer"
		add_child(_taser_timer)
	_taser_timer.one_shot = true
	_taser_timer.wait_time = taser_cooldown
	_taser_beam = get_node_or_null("TaserBeam") as MeshInstance3D
	if _taser_beam == null:
		_taser_beam = MeshInstance3D.new()
		_taser_beam.name = "TaserBeam"
		var beam_box: BoxMesh = BoxMesh.new()
		beam_box.size = Vector3(1.0, 0.035, 0.035)
		_taser_beam.mesh = beam_box
		add_child(_taser_beam)
	_taser_beam.material_override = _make_taser_material()
	_taser_beam.top_level = true
	_taser_beam.visible = false


func _make_taser_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.95, 1.0, 1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.35, 0.85, 1.0, 1)
	material.emission_energy_multiplier = 5.0
	material.no_depth_test = true
	return material


func _tick_taser_visual(delta: float) -> void:
	if _taser_beam_left > 0.0:
		_taser_beam_left -= delta
		if _taser_beam_left <= 0.0 and _taser_beam != null:
			_taser_beam.visible = false


func _physics_process(delta: float) -> void:
	_tick_melee_visual(delta)
	_tick_taser_visual(delta)
	var blocked: bool = _ui_blocked() or stunned
	var dead: bool = state == State.DEAD
	var move_axis: float = 0.0
	if not dead and not blocked:
		_update_aim()  # прицела-режима нет: разворот и маркер всегда за точкой прицела
		_update_cover_input()
	if not dead and not blocked and not in_cover:
		move_axis = Input.get_axis("move_left", "move_right")

	velocity.x = move_axis * speed
	if is_on_floor():
		velocity.y = STICK_TO_FLOOR
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	_update_depth(delta)  # 2.5D: ходим по X, Z держим на lane_z или глубине укрытия

	if dead:
		return
	if in_cover:
		_set_state(State.COVER)
	else:
		_set_state(State.RUN if not is_zero_approx(move_axis) else State.IDLE)


## UI (пауза, история, инвентарь, крупный план) забирает ввод у игры.
func _ui_blocked() -> bool:
	if _hud == null:
		_hud = get_node_or_null("/root/Hud")
	return _hud != null and _hud.is_blocking()


# --- 2.5D-глубина и присед ------------------------------------------------

## Z: за укрытием уходим на его глубину, иначе плавно возвращаемся на lane_z.
func _update_depth(delta: float) -> void:
	var target_z: float = lane_z
	if in_cover and is_instance_valid(_active_cover):
		target_z = lane_z + _active_cover.cover_depth_offset
	global_position.z = move_toward(global_position.z, target_z, COVER_Z_SPEED * delta)
	if _visual != null:
		var target_scale: float = COVER_CROUCH if in_cover else 1.0
		_visual.scale.y = move_toward(_visual.scale.y, target_scale, COVER_CROUCH_SPEED * delta)


# --- укрытия --------------------------------------------------------------

## CoverZone сообщает, что игрок рядом с укрытием.
func register_cover(cover: Cover) -> void:
	if cover == null or not is_instance_valid(cover):
		return
	if not _covers.has(cover):
		_covers.append(cover)
	if not cover.destroyed.is_connected(_on_cover_destroyed):
		cover.destroyed.connect(_on_cover_destroyed)


func unregister_cover(cover: Cover) -> void:
	_covers.erase(cover)
	if in_cover and _active_cover == cover:
		exit_cover()


func has_cover_nearby() -> bool:
	return nearby_cover() != null


## Ближайшее доступное укрытие (по X), либо null.
func nearby_cover() -> Cover:
	var best: Cover = null
	var best_distance: float = INF
	for cover: Cover in _covers:
		if not is_instance_valid(cover):
			continue
		var distance: float = absf(cover.global_position.x - global_position.x)
		if distance < best_distance:
			best_distance = distance
			best = cover
	return best


func enter_cover(cover: Cover) -> bool:
	if not is_alive() or cover == null or not is_instance_valid(cover):
		return false
	_active_cover = cover
	if not cover.destroyed.is_connected(_on_cover_destroyed):
		cover.destroyed.connect(_on_cover_destroyed)
	if not in_cover:
		in_cover = true
		cover_changed.emit(true)
	_set_state(State.COVER)
	return true


func exit_cover() -> void:
	if not in_cover:
		return
	in_cover = false
	_active_cover = null
	cover_changed.emit(false)
	_set_state(State.IDLE)


func is_in_cover() -> bool:
	return in_cover


## Укрытие, за которым игрок прячется сейчас (null, если не в укрытии или оно разрушено).
func get_active_cover() -> Cover:
	if in_cover and is_instance_valid(_active_cover):
		return _active_cover
	return null


## Зажимаем combat_cover рядом с укрытием — прячемся; отпустили — выходим.
func _update_cover_input() -> void:
	var held: bool = Input.is_action_pressed("combat_cover")
	if in_cover:
		if not held or not is_instance_valid(_active_cover):
			exit_cover()
	elif held:
		var cover: Cover = nearby_cover()
		if cover != null:
			enter_cover(cover)


func _on_cover_destroyed(cover: Cover) -> void:
	_covers.erase(cover)
	if in_cover and _active_cover == cover:
		exit_cover()


# --- прицел в 2.5D --------------------------------------------------------

## Точка прицела: луч активной Camera3D до плоскости Z = lane_z.
## Без камеры (headless) — проекция курсора на ту же плоскость вокруг игрока.
func aim_point() -> Vector3:
	if aim_override is Vector3:
		var fixed_point: Vector3 = aim_override as Vector3
		fixed_point.z = lane_z
		return fixed_point
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var mouse: Vector2 = get_viewport().get_mouse_position()
		var origin: Vector3 = cam.project_ray_origin(mouse)
		var dir: Vector3 = cam.project_ray_normal(mouse)
		var hit: Variant = Plane(Vector3.BACK, lane_z).intersects_ray(origin, dir)
		if hit != null:
			var point: Vector3 = hit as Vector3
			point.z = lane_z
			return point
	return _fallback_aim_point()


func _fallback_aim_point() -> Vector3:
	var aim_y: float = global_position.y + CHEST_HEIGHT
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	if vp == null:  # совсем без дерева (юнит-вызовы): смотрим туда, куда развёрнуты
		return Vector3(global_position.x + _facing * FALLBACK_AIM_RANGE, aim_y, lane_z)
	var screen: Vector2 = vp.get_visible_rect().size
	var mouse: Vector2 = vp.get_mouse_position()
	var half: float = maxf(screen.x * 0.5, 1.0)
	var k: float = clampf((mouse.x - half) / half, -1.0, 1.0)
	return Vector3(global_position.x + k * FALLBACK_AIM_RANGE, aim_y, lane_z)


func _update_aim() -> void:
	var point: Vector3 = aim_point()
	_face_point(point)
	if _aim_marker != null:
		_aim_marker.global_position = Vector3(point.x, point.y, lane_z)
	_aim_flashlight(point)
	_update_target_selection(point)


## Ближайший живой враг, чей центр (x, y + 0.9) лежит в target_select_radius от прицела.
## Работает и в COVER: цель можно выбрать заранее, из-за укрытия.
func _update_target_selection(point: Vector3) -> void:
	var best: Node3D = null
	var best_distance: float = target_select_radius
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			if node is not Node3D:
				continue
			var enemy: Node3D = node as Node3D
			if not _is_enemy_alive(enemy):
				continue
			var center: Vector2 = Vector2(enemy.global_position.x, enemy.global_position.y + TARGET_CENTER_HEIGHT)
			var distance: float = center.distance_to(Vector2(point.x, point.y))
			if distance < best_distance:
				best_distance = distance
				best = enemy
	if best != selected_target:
		selected_target = best
		_update_target_marker()
		target_changed.emit(selected_target)
	elif selected_target != null:
		_update_target_marker()


## Жив ли враг: is_dead() у наших врагов, иначе запасной вариант по health.
func _is_enemy_alive(enemy: Node3D) -> bool:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return false
	if not enemy.is_inside_tree():
		return false
	if enemy.has_method("is_dead"):
		return not bool(enemy.call("is_dead"))
	var health_value: Variant = enemy.get("health")
	if health_value == null:
		return true
	return int(health_value) > 0


func _update_target_marker() -> void:
	if _target_marker == null:
		return
	if selected_target == null or not is_instance_valid(selected_target) or selected_target.is_queued_for_deletion():
		_target_marker.visible = false
		return
	_target_marker.visible = true
	_target_marker.global_position = Vector3(
		selected_target.global_position.x,
		selected_target.global_position.y + TARGET_CENTER_HEIGHT,
		lane_z)


func _tick_melee_visual(delta: float) -> void:
	if _melee_visual_left <= 0.0:
		return
	_melee_visual_left -= delta
	if _melee_visual_left <= 0.0 and _melee_visual != null:
		_melee_visual.visible = false


func _hide_target_marker() -> void:
	selected_target = null
	if _target_marker != null:
		_target_marker.visible = false


## Направление от груди к точке прицела (для пули/ближнего боя).
func aim_direction() -> Vector3:
	var from: Vector3 = Vector3(global_position.x, global_position.y + CHEST_HEIGHT, lane_z)
	var to: Vector3 = aim_point()
	var dir: Vector3 = to - from
	if dir.length_squared() < 0.0001:
		return Vector3(_facing, 0.0, 0.0)
	dir.z = 0.0  # пули летают в плоскости коридора
	return dir.normalized()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.DEAD or stunned or _ui_blocked():
		return
	if event.is_action_pressed("combat_shoot"):
		get_viewport().set_input_as_handled()
		shoot()
	elif event.is_action_pressed("combat_melee"):
		get_viewport().set_input_as_handled()
		melee()
	elif event.is_action_pressed("combat_taser"):
		get_viewport().set_input_as_handled()
		taser()
	elif event.is_action_pressed("combat_reload"):
		get_viewport().set_input_as_handled()
		reload()
	elif event.is_action_pressed("combat_flashlight"):
		get_viewport().set_input_as_handled()
		toggle_flashlight()


# --- действия -------------------------------------------------------------

func shoot() -> void:
	if not is_alive() or is_reloading or stunned:
		return
	if in_cover:  # за укрытием можно только целиться, но не стрелять
		return
	if ammo_current <= 0:
		print("Click")  # холостой щелчок: звук появится с ассетами
		return
	ammo_current -= 1
	ammo_changed.emit(ammo_current, ammo_max)
	var target: Node3D = selected_target if _is_enemy_alive(selected_target) else null
	var direction: Vector3 = _shot_direction(target)
	_face_direction(direction.x)
	_spawn_bullet(direction, target)
	shoot_fired.emit(direction)


## Выбранная цель важнее точки прицела: пуля летит ей в грудь (y + 1.15).
func _shot_direction(target: Node3D) -> Vector3:
	if target != null:
		var origin: Vector3 = Vector3(global_position.x, global_position.y + CHEST_HEIGHT, lane_z)
		var chest: Vector3 = Vector3(target.global_position.x, target.global_position.y + TARGET_CHEST_HEIGHT, lane_z)
		var to_target: Vector3 = chest - origin
		to_target.z = 0.0
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()
	return aim_direction()


## ПКМ: пинок/дубинка. Работает даже во время перезарядки и из укрытия (встаём и бьём).
func melee() -> void:
	if not is_alive() or stunned or not _melee_ready:
		return
	_melee_ready = false
	if _melee_timer != null:
		_melee_timer.start(maxf(melee_cooldown, 0.01))
	if in_cover:
		exit_cover()
	var direction: Vector3 = aim_direction()
	_face_direction(direction.x)
	_show_melee_visual()
	melee_swung.emit(direction)
	_apply_melee_hits()


## Публичный алиас для скриптовых сцен и тестов.
func perform_melee() -> void:
	melee()


func _show_melee_visual() -> void:
	if _melee_visual == null:
		return
	_melee_visual.position = Vector3(_facing * 0.7, CHEST_HEIGHT - 0.15, 0.0)
	_melee_visual.visible = true
	_melee_visual_left = MELEE_VISUAL_TIME


## Все живые враги в melee_range со стороны взгляда (вплотную — с любой стороны).
func _apply_melee_hits() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is not Node3D:
			continue
		var enemy: Node3D = node as Node3D
		if not _is_enemy_alive(enemy):
			continue
		var dx: float = enemy.global_position.x - global_position.x
		var distance: float = absf(dx)
		if distance > melee_range:
			continue
		var in_front: bool = (dx > 0.0 and _facing > 0.0) or (dx < 0.0 and _facing < 0.0)
		if not in_front and distance >= CLOSE_MELEE_RANGE:
			continue
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", melee_damage)
		if enemy.has_method("apply_knockback"):
			var dir_x: float = dx if not is_zero_approx(dx) else _facing
			enemy.call("apply_knockback", dir_x, melee_knockback, melee_stun)


## Тазер (Q): бьёт выбранную цель или ближайшего активного врага со стороны взгляда.
func taser() -> void:
	if not is_alive() or stunned or in_cover:
		return
	if _taser_timer == null or not _taser_timer.is_stopped():
		return
	if taser_charges <= 0:
		return
	var target: Node3D = null
	if _taser_target_valid(selected_target, true) and absf(selected_target.global_position.x - global_position.x) <= taser_range:
		target = selected_target
	else:
		target = _find_taser_target()
	if target == null:  # нет цели — заряд не тратим
		return
	taser_charges -= 1
	_taser_timer.start(maxf(taser_cooldown, 0.01))
	_face_direction(target.global_position.x - global_position.x)
	_show_taser_beam(target)
	if target.has_method("apply_stun"):
		target.call("apply_stun", taser_stun_duration)
	taser_fired.emit(target)
	taser_charges_changed.emit(taser_charges, taser_charges_max)


## Пригоден ли враг как цель тазера.
func _taser_target_valid(enemy: Node3D, allow_surrendered: bool) -> bool:
	if not _is_enemy_alive(enemy):
		return false
	if enemy.has_method("is_arrested") and bool(enemy.call("is_arrested")):
		return false
	if not allow_surrendered and enemy.has_method("is_surrendered") and bool(enemy.call("is_surrendered")):
		return false
	return true


func _find_taser_target() -> Node3D:
	var best: Node3D = null
	var best_distance: float = taser_range
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is not Node3D:
			continue
		var enemy: Node3D = node as Node3D
		if not _taser_target_valid(enemy, false):
			continue
		var dx: float = enemy.global_position.x - global_position.x
		var distance: float = absf(dx)
		if distance > best_distance or dx * _facing < -0.001:
			continue
		best_distance = distance
		best = enemy
	return best


## Тонкий яркий луч от груди игрока до груди цели (виден даже поверх стен).
func _show_taser_beam(target: Node3D) -> void:
	if _taser_beam == null:
		return
	var from: Vector2 = Vector2(global_position.x, global_position.y + CHEST_HEIGHT)
	var to: Vector2 = Vector2(target.global_position.x, target.global_position.y + TARGET_CHEST_HEIGHT)
	var span: Vector2 = to - from
	var beam_length: float = span.length()
	if beam_length < 0.001:
		return
	_taser_beam.global_position = Vector3((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, lane_z)
	_taser_beam.rotation.z = atan2(span.y, span.x)
	_taser_beam.scale = Vector3(beam_length, 1.0, 1.0)
	_taser_beam.visible = true
	_taser_beam_left = TASER_BEAM_TIME


func toggle_flashlight() -> void:
	if not is_alive():
		return
	flashlight_on = not flashlight_on
	if _flashlight != null:
		_flashlight.set("enabled", flashlight_on)
		_flashlight.visible = flashlight_on
	flashlight_toggled.emit(flashlight_on)


func reload() -> void:
	if is_reloading or not is_alive() or stunned or ammo_current >= ammo_max:
		return
	is_reloading = true
	_reload_timer.start(reload_time)
	reload_started.emit()


func _on_reload_timeout() -> void:
	is_reloading = false
	if not is_alive():
		return
	ammo_current = ammo_max
	ammo_changed.emit(ammo_current, ammo_max)
	reload_finished.emit()


## Прерывание перезарядки (смерть, оглушение): таймер останавливаем, патроны не выдаём.
func cancel_reload() -> void:
	if not is_reloading:
		return
	is_reloading = false
	if _reload_timer != null:
		_reload_timer.stop()
	reload_cancelled.emit()


func set_stunned(value: bool) -> void:
	stunned = value
	if stunned:
		cancel_reload()
		velocity.x = 0.0


func _spawn_bullet(direction: Vector3, target: Node3D = null) -> void:
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_parent()
	if world == null:
		return
	var at: Vector3 = Vector3(global_position.x, global_position.y + CHEST_HEIGHT, lane_z) + direction * MUZZLE_OFFSET
	var bullet: Node3D = BulletScene.instantiate() as Node3D
	var parent_3d: Node3D = world as Node3D
	if parent_3d != null:
		bullet.position = parent_3d.to_local(at)
	else:
		bullet.global_position = at
	if bullet.has_method("configure"):
		bullet.call("configure", direction, false, int(bullet.get("damage")), float(bullet.get("speed")), target)
	else:
		bullet.set("direction", direction)
	world.add_child(bullet)


# --- поворот и стейт ------------------------------------------------------

## Разворот спрайта по знаку X (scale.x = -1 влево): ствол смотрит на прицел.
func _face_direction(direction_x: float) -> void:
	if is_zero_approx(direction_x):
		return
	_facing = -1.0 if direction_x < 0.0 else 1.0
	if _visual != null:
		_visual.scale.x = _facing
	# Flashlight is no longer under Visual, so it doesn't inherit the scale flip.
	# Its rotation is handled by _aim_flashlight().


func _face_point(point: Vector3) -> void:
	_face_direction(point.x - global_position.x)


## Направляет фонарик на точку прицела (aim_point) с лёгким наклоном вниз.
## SpotLight3D в Godot светит вдоль локальной -Z, поэтому используем look_at().
## Фонарик позиционируется чуть ВПЕРЕДИ героя (x = facing * 0.45), чтобы луч не утыкался в модель.
func _aim_flashlight(target_point: Vector3) -> void:
	if _flashlight == null or not _flashlight.visible:
		return
	# Позиционируем фонарик чуть вперёд от центра игрока по направлению взгляда
	var flashlight_local_x: float = _facing * 0.45
	_flashlight.position = Vector3(flashlight_local_x, 1.25, 0.05)
	# Направляем луч на точку минимум в 3.0 м вперёд (с лёгким наклоном вниз -0.25)
	var from_pos: Vector3 = _flashlight.global_position
	var to_pos: Vector3 = Vector3(target_point.x, target_point.y - 0.25, target_point.z)
	var dir: Vector3 = (to_pos - from_pos).normalized()
	var look_at_pos: Vector3 = from_pos + dir * 3.0
	_flashlight.look_at(look_at_pos, Vector3.UP)


func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	state_changed.emit(state)


func is_alive() -> bool:
	return health > 0


## Возвращает направление взгляда игрока: -1.0 (влево) или 1.0 (вправо).
func get_facing_direction() -> float:
	return _facing


func take_damage(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()


func _die() -> void:
	cancel_reload()
	stunned = false
	exit_cover()
	_hide_target_marker()
	_taser_beam_left = 0.0
	if _taser_beam != null:
		_taser_beam.visible = false
	velocity = Vector3.ZERO
	_set_state(State.DEAD)
	died.emit()
