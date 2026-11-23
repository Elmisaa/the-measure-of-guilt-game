class_name OverheadConveyor
extends Node3D
## Потолочный конвейер: балка-рельса Y=4.8, X от -11 до +11, Z=-0.5.
## 3 каретки едут зацикленно (speed=2.6 м/с). 2 несут контейнеры, 1 — пустая.
## При попадании в контейнер он падает (14 м/с), красная зона на полу и урон игроку при ударе.
## Урон Весам (container_crashed) наносит только контейнер, сбитый выстрелом игрока;
## груз, сброшенный самим боссом, бьёт только по игроку.
## Через 4 сек на каретке спавнится новый контейнер.

signal container_crashed(hit_boss: bool, boss_damage: int, impact_pos: Vector3)

@export var speed: float = 2.6
@export var rail_length: float = 22.0  # X от -11 до +11
@export var rail_y: float = 4.6
@export var rail_z: float = 0.0
@export var carriage_count: int = 3
@export var carriage_spacing: float = 7.0
@export var boss_x: float = 5.5
@export var boss_hit_half_width: float = 2.5
@export var boss_damage: int = 50
@export var player_damage: int = 25
@export var player_hit_radius: float = 1.5
@export var drop_speed: float = 14.0
@export var respawn_delay: float = 4.0

var _rail_mesh: MeshInstance3D
var _carriages: Array[Node3D] = []
var _container_meshes: Array[MeshInstance3D] = []
var _attachment_targets: Array[Area3D] = []
var _container_hit_areas: Array[Area3D] = []
var _has_container: Array[bool] = []
var _dropping: Array[bool] = []
## true — падение вызвано выстрелом игрока; false — сброс самим боссом.
var _drop_from_player_shot: Array[bool] = []
var _respawn_timers: Array[Timer] = []
var _drop_zone_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("boss_conveyors")
	_build_rail()
	_build_carriages()
	# Начальные позиции: равномерно распределяем
	for i in _carriages.size():
		var x: float = -rail_length * 0.5 + i * carriage_spacing
		_carriages[i].position = Vector3(x, 0, 0)
		_has_container[i] = (i != 1)  # 2-я каретка (индекс 1) пустая
		_update_carriage_visual(i)

func _build_rail() -> void:
	_rail_mesh = MeshInstance3D.new()
	_rail_mesh.name = "Rail"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(rail_length, 0.3, 0.3)
	_rail_mesh.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.25, 1)
	_rail_mesh.material_override = mat
	_rail_mesh.position = Vector3(0, rail_y, rail_z)
	add_child(_rail_mesh)

func _get_claw_y() -> float:
	return rail_y - 0.5  # 4.1

func _get_container_y() -> float:
	return _get_claw_y() - 0.7  # 3.4

func _get_target_y() -> float:
	return _get_claw_y() - 0.3  # 3.8

func _build_carriages() -> void:
	for i in range(carriage_count):
		var carriage: Node3D = Node3D.new()
		carriage.name = "Carriage_%d" % i
		add_child(carriage)
		_carriages.append(carriage)
		
		# Клешня (BoxMesh)
		var claw: MeshInstance3D = MeshInstance3D.new()
		claw.name = "Claw"
		var claw_box: BoxMesh = BoxMesh.new()
		claw_box.size = Vector3(0.5, 0.3, 0.5)
		claw.mesh = claw_box
		var claw_mat: StandardMaterial3D = StandardMaterial3D.new()
		claw_mat.albedo_color = Color(0.3, 0.3, 0.35, 1)
		claw.material_override = claw_mat
		claw.position = Vector3(0, _get_claw_y(), 0)
		carriage.add_child(claw)
		
		# Контейнер (невидимый по умолчанию)
		var container: MeshInstance3D = MeshInstance3D.new()
		container.name = "Container"
		var cont_box: BoxMesh = BoxMesh.new()
		cont_box.size = Vector3(1.6, 1.1, 1.0)
		container.mesh = cont_box
		var cont_mat: StandardMaterial3D = StandardMaterial3D.new()
		cont_mat.albedo_color = Color(0.35, 0.25, 0.15, 1)  # ржавый
		container.material_override = cont_mat
		container.position = Vector3(0, _get_container_y(), 0)
		container.visible = false
		carriage.add_child(container)
		_container_meshes.append(container)
		
		# Мишень крепления (Area3D на слое 128)
		var target: Area3D = Area3D.new()
		target.name = "AttachmentTarget"
		target.collision_layer = 0
		target.collision_mask = 0  # визуальный индикатор, не цель для стрельбы
		var target_shape: SphereShape3D = SphereShape3D.new()
		target_shape.radius = 0.5
		var target_col: CollisionShape3D = CollisionShape3D.new()
		target_col.shape = target_shape
		target_col.position = Vector3(0, 0, 0)
		target.add_child(target_col)
		# Визуал мишени — сфера
		var target_vis: MeshInstance3D = MeshInstance3D.new()
		target_vis.name = "TargetVisual"
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.45
		target_vis.mesh = sphere
		var target_mat: StandardMaterial3D = StandardMaterial3D.new()
		target_mat.albedo_color = Color(0.2, 0.8, 0.2, 0.7)
		target_mat.emission_enabled = true
		target_mat.emission = Color(0.1, 0.6, 0.1, 1)
		target_mat.emission_energy_multiplier = 2.0
		target_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		target_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		target_vis.material_override = target_mat
		target_vis.position = Vector3(0, 0, 0)
		target_vis.visible = false
		target.add_child(target_vis)
		target.position = Vector3(0, _get_target_y(), 0)
		carriage.add_child(target)
		_attachment_targets.append(target)
		
		# Зона попадания по контейнеру (BoxShape) — цель для стрельбы
		var container_hit: Area3D = Area3D.new()
		container_hit.name = "ContainerHit"
		container_hit.collision_layer = 128
		container_hit.collision_mask = 149
		var hit_box_shape: BoxShape3D = BoxShape3D.new()
		hit_box_shape.size = Vector3(1.6, 1.1, 1.0)
		var hit_box_col: CollisionShape3D = CollisionShape3D.new()
		hit_box_col.shape = hit_box_shape
		container_hit.add_child(hit_box_col)
		container_hit.position = Vector3(0, _get_container_y(), 0)
		carriage.add_child(container_hit)
		container_hit.add_to_group("boss_targets")
		_container_hit_areas.append(container_hit)
		container_hit.area_entered.connect(_on_container_hit.bind(i))

		# Сигнал попадания
		# target больше не цель для стрельбы
		
		# Таймер респавна
		var timer: Timer = Timer.new()
		timer.name = "RespawnTimer_%d" % i
		timer.one_shot = true
		timer.wait_time = respawn_delay
		timer.timeout.connect(_on_respawn_timeout.bind(i))
		carriage.add_child(timer)
		_respawn_timers.append(timer)
		
		_has_container.append(false)
		_dropping.append(false)
		_drop_from_player_shot.append(false)
		
		# Зона падения на полу (невидимая)
		var drop_zone: MeshInstance3D = MeshInstance3D.new()
		drop_zone.name = "DropZone"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(3.0, 0.1, 3.0)
		drop_zone.mesh = box
		var dz_mat: StandardMaterial3D = StandardMaterial3D.new()
		dz_mat.albedo_color = Color(1, 0.1, 0.1, 0.5)
		dz_mat.emission_enabled = true
		dz_mat.emission = Color(1, 0.0, 0.0, 1)
		dz_mat.emission_energy_multiplier = 3.0
		dz_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dz_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drop_zone.material_override = dz_mat
		drop_zone.position = Vector3(0, 0.05, 0)
		drop_zone.visible = false
		add_child(drop_zone)
		_drop_zone_meshes.append(drop_zone)

func _physics_process(delta: float) -> void:
	# Движение кареток
	for i in _carriages.size():
		if _dropping[i]:
			_process_drop(i, delta)
		else:
			_move_carriage(i, delta)
	
	# Проверка зоны босса для подсветки мишеней
	_update_boss_zone_highlight()

func _move_carriage(index: int, delta: float) -> void:
	var carriage: Node3D = _carriages[index]
	var pos: Vector3 = carriage.position
	pos.x += speed * delta  # конвейер всегда вправо (зацикленно)
	
	# Зацикливание: при выходе за правый край телепортируем на левый
	var half_len: float = rail_length * 0.5
	if pos.x > half_len:
		pos.x -= rail_length
	
	carriage.position = pos

func _process_drop(index: int, delta: float) -> void:
	var container: MeshInstance3D = _container_meshes[index]
	
	# Контейнер падает относительно каретки
	var container_pos: Vector3 = container.position
	container_pos.y -= drop_speed * delta
	container.position = container_pos
	
	# Проверка удара о пол (Y = 0), контейнер 1.1 высоты, центр на 0.55 = низ на 0
	if container_pos.y <= 0.55:
		container_pos.y = 0.55
		container.position = container_pos
		_finish_drop(index)

func _finish_drop(index: int) -> void:
	var carriage: Node3D = _carriages[index]
	var container: MeshInstance3D = _container_meshes[index]
	var drop_zone: MeshInstance3D = _drop_zone_meshes[index]
	var target: Area3D = _attachment_targets[index]
	
	_dropping[index] = false
	container.visible = false
	drop_zone.visible = false
	target.visible = false
	
	# Урон Весам возможен только когда игрок сбил груз над боссом.
	# Сброс самим боссом (атака контейнера) не должен снимать его сопротивление.
	var impact_x: float = carriage.global_position.x
	var hit_boss: bool = _drop_from_player_shot[index] and absf(impact_x - boss_x) <= boss_hit_half_width
	
	# Вспышка удара
	_create_impact_flash(carriage.global_position)
	
	# Сигнал
	container_crashed.emit(hit_boss, boss_damage if hit_boss else 0, carriage.global_position)
	_damage_player_at(carriage.global_position)
	
	# Запуск респавна
	_respawn_timers[index].start()

func _damage_player_at(impact_pos: Vector3) -> void:
	var impact_xz: Vector2 = Vector2(impact_pos.x, impact_pos.z)
	for player in get_tree().get_nodes_in_group("player"):
		if player is Node3D:
			var player_xz: Vector2 = Vector2(player.global_position.x, player.global_position.z)
			if player_xz.distance_to(impact_xz) <= player_hit_radius and player.has_method("take_damage"):
				player.call("take_damage", player_damage)
				return

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
	flash.position = Vector3(pos.x, 0.5, pos.z)
	add_child(flash)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "material_override:emission_energy_multiplier", 0.0, 0.3)
	tween.tween_property(flash, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.tween_callback(flash.queue_free.bind())

func _on_container_hit(area: Area3D, carriage_index: int) -> void:
	if area is Bullet and _has_container[carriage_index] and not _dropping[carriage_index]:
		_start_drop(carriage_index)

func _start_drop(index: int, from_player_shot: bool = true) -> void:
	if _dropping[index]:
		return
	_dropping[index] = true
	_has_container[index] = false
	_drop_from_player_shot[index] = from_player_shot
	
	var target: Area3D = _attachment_targets[index]
	target.visible = false
	# Падающий контейнер больше не цель: убираем из группы прицеливания босса.
	var container_hit: Area3D = _container_hit_areas[index]
	container_hit.set_deferred("monitoring", false)
	container_hit.remove_from_group("boss_targets")
	container_hit.visible = false
	
	# Показать зону падения
	var drop_zone: MeshInstance3D = _drop_zone_meshes[index]
	drop_zone.position = Vector3(_carriages[index].global_position.x, 0.05, _carriages[index].global_position.z)
	drop_zone.visible = true

func _on_respawn_timeout(carriage_index: int) -> void:
	_has_container[carriage_index] = true
	_container_meshes[carriage_index].position = Vector3(0, _get_container_y(), 0)
	_update_carriage_visual(carriage_index)

func _update_carriage_visual(index: int) -> void:
	var container: MeshInstance3D = _container_meshes[index]
	var target: Area3D = _attachment_targets[index]
	var container_hit: Area3D = _container_hit_areas[index]
	var active: bool = _has_container[index] and not _dropping[index]
	container.visible = _has_container[index]
	target.visible = active
	container_hit.monitoring = active
	container_hit.visible = active  # BossPlayer пропускает невидимые цели
	if active:
		container_hit.add_to_group("boss_targets")
	else:
		container_hit.remove_from_group("boss_targets")

func _update_boss_zone_highlight() -> void:
	for i in _attachment_targets.size():
		if not _has_container[i] or _dropping[i]:
			continue
		var carriage: Node3D = _carriages[i]
		var target_vis: MeshInstance3D = _attachment_targets[i].get_node_or_null("TargetVisual") as MeshInstance3D
		if target_vis == null or target_vis.material_override is not StandardMaterial3D:
			continue
		var mat: StandardMaterial3D = target_vis.material_override as StandardMaterial3D
		var in_boss_zone: bool = abs(carriage.global_position.x - boss_x) <= boss_hit_half_width
		if in_boss_zone:
			mat.albedo_color = Color(0.2, 1.0, 0.3, 0.9)
			mat.emission = Color(0.1, 1.0, 0.2, 1)
			mat.emission_energy_multiplier = 8.0
		else:
			mat.albedo_color = Color(0.2, 0.8, 0.2, 0.7)
			mat.emission = Color(0.1, 0.6, 0.1, 1)
			mat.emission_energy_multiplier = 2.0
