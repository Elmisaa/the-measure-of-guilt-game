class_name BossScales
extends Node3D
## Сущность «Весы» — босс Заброшенного цеха.
## 4 фазы по 100 сопротивления; атаки и интервалы меняются от фазы к фазе.
## Прямые пули не наносят урон: контратаки окружения (бочка -25, контейнер -50).
## Обнуление сопротивления завершает фазу; после последней активной фазы босс повержен.
## Фаза 1 — обязательное вступление; фазы 2–4 привязаны к Виктору, Ивану и Дмитрию.
## Успешный допрос пропускает фазу персонажа; interrogation_count — запасной вариант: первые N из фаз 2–4.

signal resistance_changed(cur: int, max_val: int)
## Бочка зарегистрирована (в том числе созданная во время боя) — HUD подключает её exploded.
signal barrel_registered(barrel: ExplosiveBarrel)
signal phase_broken
signal phase_started(phase: int)
signal phase_skipped(phase: int)
signal boss_defeated
signal attack_executed(phase: int, attack_index: int)
signal bullet_deflected(hit_pos: Vector3)
signal counter_window_opened

const BossBulletScene: PackedScene = preload("res://scenes/gameplay/boss/boss_bullet.tscn")
## Геометрия груза с потолочного конвейера (совпадает с OverheadConveyor).
const FALLBACK_CONTAINER_SIZE: Vector3 = Vector3(1.6, 1.1, 1.0)

const PHASE_COUNT: int = 4
const SHOCKWAVE_RIPPLE_COUNT: int = 3
## Индекс 0 — обязательная фаза 1 без персонажа; фазы 2–4 — допросы братьев.
const PHASE_CHARACTERS: Array[String] = ["", "Виктор", "Иван", "Дмитрий"]
## Такты атак: каждый такт — combo из индексов атак (0 — шипы, 1 — волна,
## 2 — бочка, 3 — контейнер). У фаз разные последовательности и связки.
const PHASE_BEATS: Array = [
	[[0], [1], [2], [3]],                              # Ф1: все четыре атаки по одной (обучение)
	[[0], [2], [0, 1], [2]],                           # Ф2: шипы и бочки чаще; зоны не пересекаются
	[[3], [0, 1], [2], [1, 3]],                        # Ф3: контейнер и пары
	[[0, 1], [2, 3], [0], [1, 2, 3]],                  # Ф4: плотные связки
]
## Пауза после каждого такта — своя для каждой фазы.
const PHASE_BEAT_INTERVALS: Array = [
	[2.8, 2.4, 2.6, 2.6],
	[2.0, 2.0, 2.2, 2.0],
	[2.0, 2.0, 1.8, 2.2],
	[1.4, 1.6, 1.2, 1.8],
]
## Задержка между атаками внутри одной связки.
const PHASE_COMBO_DELAY: Array[float] = [0.0, 0.45, 0.35, 0.25]

@export var max_resistance: int = 100
@export var story_controlled: bool = false
@export var thrown_prop_texture: Texture2D
@export var attack_interval: float = 2.6
## >0 — переопределить паузу фазы (тесты/отладка); 0 — использовать расписание тактов.
@export var phase_attack_intervals: Array[float] = [0.0, 0.0, 0.0, 0.0]
@export var interrogation_count: int = 0  # fallback без имён: первые N фаз после вступления
@export var interrogation_results: Dictionary = {}  # {"Виктор": true, "Иван": false, "Дмитрий": true}
@export var boss_x: float = 6.2
@export var barrel_counter_radius: float = 2.5
@export var shield_flash_time: float = 0.15
## Запасной сброс, когда над боссом нет загруженной каретки.
@export var fallback_container_fall_time: float = 1.0
@export var fallback_container_spawn_height: float = 3.4  # как контейнер на рельсе
@export var fallback_container_damage: int = 25
@export var fallback_container_hit_radius: float = 1.5

var current_phase: int = 1
var current_resistance: int = 100
var is_defeated: bool = false
var story_phase_active: bool = false
var story_counter_succeeded: bool = false
var _attack_timer: Timer
var _beat_index: int = -1
var _phase_token: int = 0
var _phase_plan: Array[int] = []  # активные фазы в порядке прохождения
var _skipped_phases: Array[int] = []
var _shield_mesh: MeshInstance3D
var _shield_timer: Timer
var _is_shield_flashing: bool = false
var _player: Node3D = null
var _conveyor: OverheadConveyor = null
var _barrels: Array[ExplosiveBarrel] = []
var _pulled_barrels: Array[ExplosiveBarrel] = []  # бочки в процессе телекинеза
## Цель броска фиксируется в момент показа зоны.
## ExplosiveBarrel -> {"pos": Vector3, "radius": float, "token": int}
var _barrel_targets: Dictionary = {}
var _active_attack: int = -1
var _attack_warning: MeshInstance3D = null
var _warning_timer: Timer = null
## FallbackContainer -> {"tween": Tween, "zone": MeshInstance3D, "token": int}
var _fallback_drops: Dictionary = {}

func _ready() -> void:
	add_to_group("boss")
	_build_boss_visual()
	_ensure_timers()
	_find_player_and_systems()
	
	# План фаз строится по результатам допросов (обязательная фаза 1 всегда остаётся).
	_build_phase_plan(true)
	if not story_controlled:
		_enter_phase(_phase_plan[0])

func _exit_tree() -> void:
	_clear_fallback_drops()

func _build_boss_visual() -> void:
	# База (StaticBody3D для коллизии пуль, слой 4)
	var base: StaticBody3D = StaticBody3D.new()
	base.name = "BossBase"
	base.collision_layer = 4
	base.collision_mask = 1 | 16 | 32  # World, PlayerBullet, EnemyBullet
	var base_shape: BoxShape3D = BoxShape3D.new()
	base_shape.size = Vector3(2.0, 3.2, 1.0)
	var base_col: CollisionShape3D = CollisionShape3D.new()
	base_col.shape = base_shape
	base_col.position = Vector3(0, 1.6, 0)
	base.add_child(base_col)
	
	# Визуал босса — силуэт весов
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	base.add_child(visual)
	
	# Стойка
	var post: MeshInstance3D = MeshInstance3D.new()
	var post_box: BoxMesh = BoxMesh.new()
	post_box.size = Vector3(0.4, 3.2, 0.4)
	post.mesh = post_box
	var post_mat: StandardMaterial3D = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.25, 0.05, 0.08, 1)
	post.material_override = post_mat
	post.position = Vector3(0, 1.6, 0)
	visual.add_child(post)
	
	# Перекладина
	var beam: MeshInstance3D = MeshInstance3D.new()
	var beam_box: BoxMesh = BoxMesh.new()
	beam_box.size = Vector3(2.0, 0.3, 0.3)
	beam.mesh = beam_box
	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.3, 0.08, 0.1, 1)
	beam.material_override = beam_mat
	beam.position = Vector3(0, 3.2, 0)
	visual.add_child(beam)
	
	# Левая чаша
	var left_pan: MeshInstance3D = MeshInstance3D.new()
	var pan_shape: CylinderMesh = CylinderMesh.new()
	pan_shape.height = 0.6
	pan_shape.top_radius = 0.6
	pan_shape.bottom_radius = 0.25
	left_pan.mesh = pan_shape
	var pan_mat: StandardMaterial3D = StandardMaterial3D.new()
	pan_mat.albedo_color = Color(0.35, 0.1, 0.12, 1)
	left_pan.material_override = pan_mat
	left_pan.position = Vector3(-0.9, 2.6, 0)
	visual.add_child(left_pan)
	
	# Правая чаша
	var right_pan: MeshInstance3D = MeshInstance3D.new()
	right_pan.mesh = pan_shape.duplicate()
	right_pan.material_override = pan_mat.duplicate()
	right_pan.position = Vector3(0.9, 2.6, 0)
	visual.add_child(right_pan)
	
	# Цепочки
	for i in range(4):
		var chain: MeshInstance3D = MeshInstance3D.new()
		var chain_box: BoxMesh = BoxMesh.new()
		chain_box.size = Vector3(0.08, 0.8, 0.08)
		chain.mesh = chain_box
		var chain_mat: StandardMaterial3D = StandardMaterial3D.new()
		chain_mat.albedo_color = Color(0.2, 0.2, 0.25, 1)
		chain.material_override = chain_mat
		chain.position = Vector3(-0.9 + i % 2 * 1.8, 2.9 - (i / 2.0) * 0.4, 0)
		visual.add_child(chain)
	
	# Щит (невидимый по умолчанию)
	_shield_mesh = MeshInstance3D.new()
	_shield_mesh.name = "Shield"
	var shield_shape: SphereMesh = SphereMesh.new()
	shield_shape.radius = 2.0
	_shield_mesh.mesh = shield_shape
	var shield_mat: StandardMaterial3D = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.2, 0.6, 1.0, 0.3)
	shield_mat.emission_enabled = true
	shield_mat.emission = Color(0.1, 0.4, 1.0, 1)
	shield_mat.emission_energy_multiplier = 5.0
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shield_mesh.material_override = shield_mat
	_shield_mesh.position = Vector3(0, 1.6, 0)
	_shield_mesh.visible = false
	base.add_child(_shield_mesh)
	
	# Area3D для обнаружения попаданий пуль (слой 4, маска пуль игрока)
	var hit_area: Area3D = Area3D.new()
	hit_area.name = "HitArea"
	hit_area.collision_layer = 4
	hit_area.collision_mask = 16  # PlayerBullet layer
	var hit_shape: BoxShape3D = BoxShape3D.new()
	hit_shape.size = Vector3(2.5, 3.5, 1.5)
	var hit_col: CollisionShape3D = CollisionShape3D.new()
	hit_col.shape = hit_shape
	hit_col.position = Vector3(0, 1.6, 0)
	hit_area.add_child(hit_col)
	if story_controlled:
		hit_area.collision_layer = 128
		hit_area.position.y = 1.6
		hit_col.position.y = 0.0
		hit_area.set_meta("boss_shield", self)
		hit_area.add_to_group("boss_targets")
	else:
		hit_area.area_entered.connect(_on_bullet_hit_shield)
	base.add_child(hit_area)
	
	base.position = Vector3(boss_x, 0, 0)
	add_child(base)

func _ensure_timers() -> void:
	# Timer цикла атак
	_attack_timer = Timer.new()
	_attack_timer.name = "AttackTimer"
	_attack_timer.one_shot = true
	_attack_timer.wait_time = attack_interval
	_attack_timer.timeout.connect(_on_attack_timeout)
	add_child(_attack_timer)
	
	# Timer вспышки щита
	_shield_timer = Timer.new()
	_shield_timer.name = "ShieldTimer"
	_shield_timer.one_shot = true
	_shield_timer.wait_time = shield_flash_time
	_shield_timer.timeout.connect(_on_shield_flash_timeout)
	add_child(_shield_timer)

## Результат допроса: true — допрос пройден, фаза персонажа пропускается.
func set_interrogation_result(character: String, completed: bool) -> void:
	interrogation_results[character] = completed
	_apply_interrogation_changes()

## Пакетная настройка результатов допросов (обычно до старта схватки).
func configure_interrogations(results: Dictionary) -> void:
	interrogation_results = results.duplicate()
	_apply_interrogation_changes()

## Запасной способ без имён: первые N фаз пропускаются.
func set_interrogation_count(value: int) -> void:
	interrogation_count = maxi(0, value)
	_apply_interrogation_changes()

func _apply_interrogation_changes() -> void:
	_build_phase_plan(true)
	if _attack_timer == null or is_defeated or _phase_plan.is_empty():
		return
	if _phase_plan.has(current_phase):
		return
	# Текущая фаза исключена допросом — переходим к следующей активной.
	var next: int = -1
	for phase in _phase_plan:
		if phase > current_phase:
			next = phase
			break
	if next != -1:
		_enter_phase(next)
	else:
		# Активных фаз позже нет (например, допрошен Дмитрий в фазе 4) — схватка завершена.
		_defeat_boss()

func _is_interrogation_complete(phase: int) -> bool:
	if phase <= 1 or phase > PHASE_COUNT:  # вступление не пропускается
		return false
	var character: String = PHASE_CHARACTERS[phase - 1]
	if character.is_empty():
		return false
	if interrogation_results.has(character):
		return bool(interrogation_results[character])
	return phase - 1 <= maxi(0, interrogation_count)  # fallback без имён: фазы 2..N+1

func _build_phase_plan(announce: bool) -> void:
	var old_skipped: Array[int] = _skipped_phases.duplicate()
	_phase_plan.clear()
	_skipped_phases.clear()
	for phase in range(1, PHASE_COUNT + 1):
		if _is_interrogation_complete(phase):
			_skipped_phases.append(phase)
			if announce and not old_skipped.has(phase):
				phase_skipped.emit(phase)
		else:
			_phase_plan.append(phase)

func _next_active_phase() -> int:
	var idx: int = _phase_plan.find(current_phase)
	if idx != -1 and idx + 1 < _phase_plan.size():
		return _phase_plan[idx + 1]
	return -1

func is_phase_skipped(phase: int) -> bool:
	return _skipped_phases.has(phase)

func _phase_beats() -> Array:
	if story_controlled and current_phase == 1:
		return [[0], [2], [4], [1], [3]]
	if PHASE_BEATS.size() >= current_phase:
		return PHASE_BEATS[current_phase - 1]
	return [[0]]

func _phase_intervals() -> Array:
	if story_controlled and current_phase == 1:
		return [3.0, 4.0, 3.6, 2.6, 2.6]
	if PHASE_BEAT_INTERVALS.size() >= current_phase:
		return PHASE_BEAT_INTERVALS[current_phase - 1]
	return [attack_interval]

func _combo_delay() -> float:
	if PHASE_COMBO_DELAY.size() >= current_phase:
		return PHASE_COMBO_DELAY[current_phase - 1]
	return 0.4

func _beat_interval(beat_index: int) -> float:
	if phase_attack_intervals.size() >= current_phase:
		var override: float = phase_attack_intervals[current_phase - 1]
		if override > 0.0:
			return maxf(0.1, override)
	var intervals: Array = _phase_intervals()
	if intervals.is_empty():
		return attack_interval
	return maxf(0.1, intervals[beat_index % intervals.size()])

func _enter_phase(phase: int) -> void:
	current_phase = clampi(phase, 1, PHASE_COUNT)
	_phase_token += 1
	current_resistance = max_resistance
	_beat_index = -1
	resistance_changed.emit(current_resistance, max_resistance)
	if _attack_timer != null:
		_attack_timer.start(_beat_interval(0))
	phase_started.emit(current_phase)

## Отсекает отложенные атаки предыдущей фазы после перехода/победы.
func _is_attack_valid(token: int) -> bool:
	return not is_defeated and token == _phase_token and current_resistance > 0 and (not story_controlled or story_phase_active)


func start_story_phase(phase: int) -> void:
	story_phase_active = true
	story_counter_succeeded = false
	_enter_phase(phase)


func stop_story_phase() -> void:
	story_phase_active = false
	_phase_token += 1
	_stop_attacks()
	_clear_floor_warning()
	_clear_fallback_drops()
	for barrel: ExplosiveBarrel in _barrels.duplicate():
		if is_instance_valid(barrel):
			barrel.queue_free()
	_pulled_barrels.clear()
	_barrel_targets.clear()
	for child: Node in get_children():
		if child is BossBullet or child.has_meta("attack_effect"):
			child.queue_free()

func _find_player_and_systems() -> void:
	# Игрок
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			_player = node as Node3D
			break
	
	# Конвейер не является стреляемой целью — для него отдельная группа.
	for node in get_tree().get_nodes_in_group("boss_conveyors"):
		if node is OverheadConveyor:
			_conveyor = node
			break
	
	# Бочки
	for node in get_tree().get_nodes_in_group("boss_targets"):
		if node is ExplosiveBarrel:
			register_barrel(node as ExplosiveBarrel)

## Единая регистрация бочек: начальные, созданные боссом и заспавненные HUD.
## Повторный вызов не дублирует сигналы и не добавляет бочку в список дважды.
func register_barrel(barrel: ExplosiveBarrel) -> void:
	if barrel == null or not is_instance_valid(barrel) or _barrels.has(barrel):
		return
	_barrels.append(barrel)
	if not barrel.tree_exiting.is_connected(_on_barrel_tree_exiting):
		barrel.tree_exiting.connect(_on_barrel_tree_exiting.bind(barrel))
	barrel_registered.emit(barrel)

func _on_barrel_tree_exiting(barrel: ExplosiveBarrel) -> void:
	_barrels.erase(barrel)
	_pulled_barrels.erase(barrel)
	_barrel_targets.erase(barrel)
	## Взрыв — это queue_free(), поэтому список чистим здесь, пока объект ещё валиден.
	_drop_barrel_from_lists(barrel)

func _drop_barrel_from_lists(barrel: ExplosiveBarrel) -> void:
	if barrel == null or not is_instance_valid(barrel):
		return
	while _barrels.has(barrel):
		_barrels.erase(barrel)
	while _pulled_barrels.has(barrel):
		_pulled_barrels.erase(barrel)
	_barrel_targets.erase(barrel)

func _on_attack_timeout() -> void:
	if is_defeated or current_resistance <= 0:
		return
	var beats: Array = _phase_beats()
	_beat_index = (_beat_index + 1) % beats.size()
	var beat: Array = beats[_beat_index]
	var token: int = _phase_token
	var delay_step: float = _combo_delay()
	for i in beat.size():
		var attack_index: int = beat[i]
		if i == 0:
			_execute_attack(attack_index, token)
		else:
			_schedule_linked_attack(attack_index, token, i * delay_step)
	_attack_timer.start(_beat_interval(_beat_index))

## Атака внутри связки: держит свою задержку и отменяется при смене фазы.
func _schedule_linked_attack(attack_index: int, token: int, delay: float) -> void:
	if delay <= 0.0:
		_execute_attack(attack_index, token)
		return
	await get_tree().create_timer(delay).timeout
	if not _is_attack_valid(token):
		return
	_execute_attack(attack_index, token)

func _execute_attack(index: int, token: int) -> void:
	_active_attack = index
	attack_executed.emit(current_phase, index)
	match index:
		0: _attack_spikes(token)
		1: _attack_shockwave(token)
		2: _attack_throw_barrel(token)
		3: _attack_drop_container(token)
		4: _throw_prop(token)


func _throw_prop(token: int) -> void:
	var origin: Vector3 = global_position + Vector3(boss_x - 0.65, 1.65, 0.0)
	_create_telegraph(origin, 0.65, Color(1.0, 0.55, 0.18, 0.8))
	await get_tree().create_timer(0.65).timeout
	if not _is_attack_valid(token) or not is_instance_valid(_player):
		return
	var target: Vector3 = _player.global_position + Vector3(0.0, 1.0, 0.0)
	var projectile: BossBullet = BossBulletScene.instantiate() as BossBullet
	projectile.position = to_local(origin)
	add_child(projectile)
	projectile.configure((target - origin).normalized(), true, 18, 13.0)
	if thrown_prop_texture != null:
		projectile.get_node("Mesh").hide()
		var sprite: Sprite3D = Sprite3D.new()
		sprite.texture = thrown_prop_texture
		sprite.pixel_size = 0.72 / thrown_prop_texture.get_width()
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		projectile.add_child(sprite)

func _attack_spikes(token: int) -> void:
	# 1) Шипы: 0.45с телеграф на руке → веер из 3 снарядов в сторону игрока.
	# Модель Весов стоит на boss_x (локальное смещение дочерней базы), а не в корне,
	# поэтому точка старта должна учитывать и корень сцены, и это смещение.
	var hand_pos: Vector3 = global_position + Vector3(boss_x, 2.5, 0)
	_create_telegraph(hand_pos, 0.45, Color(1, 0.2, 0.2, 0.8))
	
	var tween: Tween = create_tween()
	tween.tween_callback(func(): _fire_spikes(hand_pos, 0.45, token))

func _fire_spikes(origin: Vector3, delay: float, token: int) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or not _is_attack_valid(token):
		return
	
	if _player == null:
		return
	
	# Aim at the player's chest, not at the feet. Keeping the vertical
	# component makes a spike launched above the player intersect the capsule.
	var target_pos: Vector3 = _player.global_position + Vector3(0, 1.15, 0)
	var dir_to_player: Vector3 = (target_pos - origin).normalized()
	if dir_to_player.length_squared() < 0.001:
		dir_to_player = Vector3(-1, -0.2, 0).normalized()
	
	# Веер из 3 снарядов: центр, влево, вправо
	var angles: Array[float] = [-0.25, 0.0, 0.25]
	for angle in angles:
		var rotated_dir: Vector3 = dir_to_player.rotated(Vector3.UP, angle)
		_spawn_enemy_bullet(origin + rotated_dir * 0.5, rotated_dir, 15)

func _attack_shockwave(token: int) -> void:
	# 2) Ударная волна по полу: полоса Z игрока (ширина 1.8м, вся длина X)
	# 0.75с предупреждение на полу Y=0.04 → удар 20 урона
	if _player == null:
		return
	
	var player_z: float = _player.global_position.z
	var warn_z_min: float = player_z - 0.9
	var warn_z_max: float = player_z + 0.9
	
	# Рисуем предупреждение на полу
	_create_floor_warning(warn_z_min, warn_z_max, 0.75)
	
	var tween: Tween = create_tween()
	tween.tween_callback(func(): _execute_shockwave(warn_z_min, warn_z_max, 0.75, token))

func _execute_shockwave(z_min: float, z_max: float, delay: float, token: int) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or not _is_attack_valid(token):
		return
	
	# Урон игроку, если он на этой полосе Z
	if _player != null:
		var pz: float = _player.global_position.z
		if pz >= z_min and pz <= z_max and _player.has_method("take_damage"):
			_player.call("take_damage", 20)
	
	# Визуал ударной волны
	_create_shockwave_visual(z_min, z_max)

func _attack_throw_barrel(token: int) -> void:
	# 3) Бросок взрывной бочки (контратака -25)
	# Босс притягивает бочку телекинезом из её текущей позиции, затем бросает в игрока.
	if _player == null:
		return
	
	# Найти доступную бочку или создать новую на арене
	var barrel: ExplosiveBarrel = _get_available_barrel()
	if barrel == null:
		return
	
	# Исходная позиция бочки (откуда телекинез притягивает)
	var barrel_pos: Vector3 = Vector3(3.9, 0.9, clampf(_player.global_position.z + 0.8, -2.8, 3.2)) if story_controlled else Vector3(4.2, 1.3, _player.global_position.z)

	_pulled_barrels.append(barrel)
	barrel.near_boss = false
	barrel.boss_damage = 0
	barrel.player_damage = 20
	barrel.visible = true
	barrel.add_to_group("boss_targets")

	# Телекинез: притяжение (tween — ребёнок бочки)
	var tween: Tween = barrel.create_tween()
	tween.tween_property(barrel, "global_position", barrel_pos, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_barrel_pulled.bind(barrel, barrel_pos, _player, token))

func _on_barrel_pulled(barrel: ExplosiveBarrel, barrel_pos: Vector3, player: Node3D, token: int) -> void:
	if not is_instance_valid(barrel) or not is_inside_tree() or not _is_attack_valid(token):
		_pulled_barrels.erase(barrel)
		return
	if barrel._is_exploding:
		_pulled_barrels.erase(barrel)
		return

	_pulled_barrels.erase(barrel)
	barrel.global_position = barrel_pos
	barrel.near_boss = true
	barrel.boss_damage = 25
	barrel.player_damage = 20
	if story_controlled:
		barrel.get_node("TargetRing").show()
		counter_window_opened.emit()

	# Зона показывается один раз и фиксирует точку взрыва. Дальше игрок может
	# уйти, но бочка летит именно сюда — телеграф всегда совпадает с ударом.
	var target_pos: Vector3 = barrel_pos
	if player != null and is_instance_valid(player):
		target_pos = Vector3(player.global_position.x, 0.0, player.global_position.z)
	var target_radius: float = maxf(0.1, barrel.blast_radius)
	_barrel_targets[barrel] = {"pos": target_pos, "radius": target_radius, "token": token}
	_create_drop_zone_visual(target_pos, 2.2, target_radius)

	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 2.2
	barrel.add_child(timer)
	timer.timeout.connect(_do_barrel_throw.bind(barrel, token))
	timer.start()

func _do_barrel_throw(barrel: ExplosiveBarrel, token: int) -> void:
	if not is_instance_valid(barrel) or barrel._is_exploding or not _is_attack_valid(token):
		return
	barrel.near_boss = false
	barrel.boss_damage = 0
	if story_controlled:
		barrel.get_node("TargetRing").hide()

	var target: Dictionary = _barrel_targets.get(barrel, {})
	var target_pos: Vector3 = target.get("pos", barrel.global_position)
	var throw_tween: Tween = barrel.create_tween()
	throw_tween.tween_property(barrel, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	throw_tween.finished.connect(_on_barrel_thrown.bind(barrel, token))

func _on_barrel_thrown(barrel: ExplosiveBarrel, token: int) -> void:
	if not is_instance_valid(barrel) or barrel._is_exploding or not _is_attack_valid(token):
		return
	var target: Dictionary = _barrel_targets.get(barrel, {})
	var target_pos: Vector3 = target.get("pos", barrel.global_position)
	barrel.global_position = target_pos
	_barrel_targets.erase(barrel)
	barrel.take_bullet_hit()

func _attack_drop_container(token: int) -> void:
	# 4) Обрушение с конвейера + контратака (-50)
	# Когда игрок сбивает клешню над боссом (abs(x - boss_x) <= 2.5) — контейнер вызывает apply_environment_damage(50)!
	# Также босс сам сбрасывает груз над позицией игрока; без каретки — свой видимый контейнер (25 урона).
	if _conveyor == null:
		# Fallback: видимый контейнер падает с потолка в зону под игроком.
		_drop_own_container(token)
		return
	
	# Проверяем, есть ли контейнер над зоной босса
	var dropped: bool = false
	for i in _conveyor._carriages.size():
		if _conveyor._has_container[i] and not _conveyor._dropping[i]:
			var carriage: Node3D = _conveyor._carriages[i]
			if abs(carriage.global_position.x - boss_x) <= 2.5:
				# Босс сбрасывает груз сам — это атака по игроку, а не контратака.
				# Отметка false не даст _finish_drop начислить урон самым Весам.
				_conveyor._start_drop(i, false)
				dropped = true
				break
	
	if not dropped:
		_drop_own_container(token)

func _drop_own_container(token: int) -> void:
	# Нет загруженной каретки — роняем свой груз с потолка в зафиксированную точку.
	if _player == null or not is_instance_valid(_player):
		return
	
	var impact_pos: Vector3 = Vector3(_player.global_position.x, 0.0, _player.global_position.z)
	var fall_time: float = maxf(0.1, fallback_container_fall_time)
	var zone: MeshInstance3D = _create_drop_zone_visual(impact_pos, fall_time, fallback_container_hit_radius)
	_execute_container_drop(impact_pos, fall_time, token, zone)

func _execute_container_drop(pos: Vector3, delay: float, token: int, zone: MeshInstance3D = null) -> void:
	# Груз виден в воздухе весь телеграф; удар применяется один раз по завершении падения.
	var container: MeshInstance3D = MeshInstance3D.new()
	container.name = "FallbackContainer"
	var box: BoxMesh = BoxMesh.new()
	box.size = FALLBACK_CONTAINER_SIZE
	container.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.25, 0.15, 1)  # ржавый, как на конвейере
	container.material_override = mat
	add_child(container)
	container.global_position = Vector3(pos.x, fallback_container_spawn_height, pos.z)
	
	var landing_y: float = FALLBACK_CONTAINER_SIZE.y * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(container, "global_position", Vector3(pos.x, landing_y, pos.z), delay) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(container, "rotation_degrees", Vector3(20.0, 35.0, 12.0), delay) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fallback_drops[container] = {"tween": tween, "zone": zone, "token": token}
	tween.finished.connect(_on_fallback_container_landed.bind(container, pos, token))

func _on_fallback_container_landed(container: MeshInstance3D, pos: Vector3, token: int) -> void:
	var state: Dictionary = _fallback_drops.get(container, {})
	_fallback_drops.erase(container)
	_dispose_fallback_container(container, state.get("tween") as Tween, state.get("zone") as MeshInstance3D)
	if not is_inside_tree() or not _is_attack_valid(token):
		return
	
	_create_impact_flash(pos)
	if _player == null or not is_instance_valid(_player) or not _player.has_method("take_damage"):
		return
	var player_xz: Vector2 = Vector2(_player.global_position.x, _player.global_position.z)
	var impact_xz: Vector2 = Vector2(pos.x, pos.z)
	if player_xz.distance_to(impact_xz) <= fallback_container_hit_radius:
		_player.call("take_damage", fallback_container_damage)

func _dispose_fallback_container(container: MeshInstance3D, tween: Tween, zone: MeshInstance3D) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	if zone != null and is_instance_valid(zone) and not zone.is_queued_for_deletion():
		# Зону убирает её собственный таймер; здесь только прекращаем подсветку.
		zone.visible = false
	if is_instance_valid(container) and not container.is_queued_for_deletion():
		container.queue_free()

func _clear_fallback_drops() -> void:
	for container in _fallback_drops.keys():
		var state: Dictionary = _fallback_drops[container]
		_dispose_fallback_container(container as MeshInstance3D,
			state.get("tween") as Tween, state.get("zone") as MeshInstance3D)
	_fallback_drops.clear()

func _get_available_barrel() -> ExplosiveBarrel:
	for barrel in _barrels:
		if is_instance_valid(barrel) and not barrel._is_exploding and not _pulled_barrels.has(barrel) and (not story_controlled or not _barrel_targets.has(barrel)):
			return barrel
	
	# Создать новую на арене (не у босса), чтобы телекинез был виден
	var barrel_scene: PackedScene = preload("res://scenes/gameplay/boss/explosive_barrel.tscn")
	var new_barrel: ExplosiveBarrel = barrel_scene.instantiate() as ExplosiveBarrel
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	parent.add_child(new_barrel)
	# Случайная точка на арене
	var rx: float = randf_range(-8.0, 8.0)
	var rz: float = randf_range(-3.0, 3.0)
	new_barrel.global_position = Vector3(rx, 0.45, rz)
	register_barrel(new_barrel)
	return new_barrel

func apply_environment_damage(amount: int) -> void:
	if is_defeated or current_resistance <= 0 or (story_controlled and not story_phase_active):
		return
	
	current_resistance = maxi(0, current_resistance - amount)
	resistance_changed.emit(current_resistance, max_resistance)
	
	# Мигание белым
	_flash_white()
	
	if current_resistance > 0:
		return

	if story_controlled:
		stop_story_phase()
		phase_broken.emit()
		return
	phase_broken.emit()
	var next: int = _next_active_phase()
	if next != -1:
		_enter_phase(next)
	else:
		_defeat_boss()

func _defeat_boss() -> void:
	is_defeated = true
	_phase_token += 1
	_stop_attacks()
	boss_defeated.emit()

func _stop_attacks() -> void:
	if _attack_timer != null:
		_attack_timer.stop()

func _on_bullet_hit_shield(area: Area3D) -> void:
	if area is Bullet:
		deflect_bullet(area.global_position)


func deflect_bullet(hit: Vector3) -> void:
	_flash_shield(hit)
	bullet_deflected.emit(hit)

func _flash_shield(_hit_pos: Vector3) -> void:
	if _is_shield_flashing:
		return
	_is_shield_flashing = true
	_shield_mesh.visible = true
	_shield_timer.start()

func _on_shield_flash_timeout() -> void:
	_shield_mesh.visible = false
	_is_shield_flashing = false

func _flash_white() -> void:
	var visual: Node3D = get_node_or_null("BossBase/Visual") as Node3D
	if visual == null:
		return
	
	var original_colors: Dictionary = {}
	for child in visual.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = child.material_override as StandardMaterial3D
			original_colors[child] = mat.albedo_color
			mat.albedo_color = Color(1, 1, 1, 1)
	
	var tween: Tween = create_tween()
	tween.tween_callback(func(): _restore_colors(original_colors, 0.1))

func _restore_colors(colors: Dictionary, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	for child in colors:
		if is_instance_valid(child) and child.material_override is StandardMaterial3D:
			(child.material_override as StandardMaterial3D).albedo_color = colors[child]

func _create_telegraph(pos: Vector3, duration: float, color: Color) -> void:
	var telegraph: MeshInstance3D = MeshInstance3D.new()
	telegraph.name = "Telegraph"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.4
	telegraph.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 8.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph.material_override = mat
	telegraph.set_meta("attack_effect", true)
	add_child(telegraph)
	telegraph.global_position = pos
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(telegraph, "material_override:emission_energy_multiplier", 0.0, duration)
	tween.tween_property(telegraph, "scale", Vector3(2.0, 2.0, 2.0), duration)
	tween.tween_callback(telegraph.queue_free.bind())

func _create_floor_warning(z_min: float, z_max: float, duration: float) -> void:
	_attack_warning = MeshInstance3D.new()
	_attack_warning.name = "FloorWarning"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(24.0, 0.08, z_max - z_min)
	_attack_warning.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.5, 0.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.4, 0.0, 1)
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_attack_warning.material_override = mat
	add_child(_attack_warning)
	_attack_warning.global_position = Vector3(0, 0.04, (z_min + z_max) * 0.5)
	
	_warning_timer = Timer.new()
	_warning_timer.one_shot = true
	_warning_timer.wait_time = duration
	_warning_timer.timeout.connect(_clear_floor_warning)
	add_child(_warning_timer)
	_warning_timer.start()

func _clear_floor_warning() -> void:
	if _attack_warning != null and is_instance_valid(_attack_warning):
		_attack_warning.queue_free()
		_attack_warning = null
	if _warning_timer != null:
		_warning_timer.queue_free()
		_warning_timer = null

func _create_shockwave_visual(z_min: float, z_max: float) -> void:
	var wave: MeshInstance3D = MeshInstance3D.new()
	wave.name = "Shockwave"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(24.0, 0.5, z_max - z_min)
	wave.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.6, 0.1, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.5, 0.0, 1)
	mat.emission_energy_multiplier = 10.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wave.material_override = mat
	wave.set_meta("attack_effect", true)
	add_child(wave)
	wave.global_position = Vector3(0, 0.3, (z_min + z_max) * 0.5)
	wave.scale = Vector3(0.05, 1.0, 1.0)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector3(1.0, 0.15, 1.0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave, "material_override:emission_energy_multiplier", 0.0, 0.8)
	tween.tween_property(wave, "material_override:albedo_color", Color(1.0, 0.6, 0.1, 0.0), 0.8)
	tween.chain().tween_callback(wave.queue_free.bind())

	# Несколько плоских фронтов расходятся по полу от источника удара.
	_create_shockwave_ripples((z_min + z_max) * 0.5)

func _create_shockwave_ripples(center_z: float) -> void:
	for i in range(SHOCKWAVE_RIPPLE_COUNT):
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.name = "ShockwaveRing_%d" % i
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.68
		torus.outer_radius = 0.7
		torus.rings = 48
		torus.ring_segments = 8
		ring.mesh = torus

		var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
		var alpha: float = 0.85 - i * 0.12
		ring_mat.albedo_color = Color(1.0, 0.62, 0.18, alpha)
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(1.0, 0.42, 0.08, 1.0)
		ring_mat.emission_energy_multiplier = 10.0 - i * 1.5
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = ring_mat
		ring.set_meta("attack_effect", true)
		add_child(ring)
		ring.global_position = Vector3(boss_x, 0.09, center_z)
		ring.scale = Vector3(0.025, 0.2, 0.025)

		var delay: float = i * 0.14
		var duration: float = 0.9
		var tween: Tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(ring, "scale", Vector3(26.0, 0.2, 26.0), duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(ring, "material_override:albedo_color", Color(1.0, 0.62, 0.18, 0.0), duration)
		tween.parallel().tween_property(ring, "material_override:emission_energy_multiplier", 0.0, duration)
		tween.tween_callback(ring.queue_free.bind())

## Круглая зона удара: радиус совпадает с радиусом поражения (бочка — blast_radius).
func _create_drop_zone_visual(pos: Vector3, duration: float, radius: float = 1.5) -> MeshInstance3D:
	var zone: MeshInstance3D = MeshInstance3D.new()
	zone.name = "DropZone"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = maxf(0.1, radius)
	disc.bottom_radius = maxf(0.1, radius)
	disc.height = 0.08
	disc.radial_segments = 32
	disc.rings = 1
	zone.mesh = disc
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.1, 0.1, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.0, 0.0, 1)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone.material_override = mat
	zone.set_meta("attack_effect", true)
	add_child(zone)
	zone.global_position = Vector3(pos.x, 0.05, pos.z)
	
	var tween: Tween = create_tween()
	tween.tween_callback(zone.queue_free.bind()).set_delay(duration)
	return zone

func _create_impact_flash(pos: Vector3) -> void:
	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.name = "ImpactFlash"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.5
	flash.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.8, 0.2, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.6, 0.1, 1)
	mat.emission_energy_multiplier = 15.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = mat
	flash.set_meta("attack_effect", true)
	add_child(flash)
	flash.global_position = Vector3(pos.x, 0.5, pos.z)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "material_override:emission_energy_multiplier", 0.0, 0.3)
	tween.tween_property(flash, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.tween_callback(flash.queue_free.bind())

func _spawn_enemy_bullet(pos: Vector3, dir: Vector3, dmg: int) -> void:
	var bullet: Node3D = BossBulletScene.instantiate() as Node3D
	add_child(bullet)
	bullet.global_position = pos
	if bullet.has_method("configure"):
		bullet.call("configure", dir, true, dmg, 30.0, null)
	bullet.collision_mask = 1 | 2 | 4  # World, Player, Cover
