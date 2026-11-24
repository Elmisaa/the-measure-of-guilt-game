class_name BossScales
extends Node3D

signal attack_started(index: int)
signal resistance_changed(cur: int, max_val: int)
signal phase_broken
signal bullet_deflected(hit_pos: Vector3)

@export var auto_start: bool = true
@export var max_resistance: int = 100
@export var attack_interval: float = 2.6
@export var boss_x: float = 6.2
@export var boss_z: float = 0.0
@export var shield_flash_time: float = 0.15

var current_resistance: int = 100
var _attack_timer: Timer
var _attack_index: int = 0
var _pattern: Array[int] = [0, 1, 2, 3]
var _phase_generation: int = 0
var _shield_mesh: MeshInstance3D
var _shield_timer: Timer
var _is_shield_flashing: bool = false
var _player: Node3D = null
var _conveyor: OverheadConveyor = null
var _barrels: Array[ExplosiveBarrel] = []
var _active_attack: int = -1
var _attack_warning: MeshInstance3D = null
var _warning_timer: Timer = null

func _ready() -> void:
	add_to_group("boss")
	current_resistance = max_resistance
	resistance_changed.emit(current_resistance, max_resistance)
	
	_build_boss_visual()
	_ensure_timers()
	_find_player_and_systems()
	
	if auto_start:
		_attack_timer.start(attack_interval)
	else:
		current_resistance = 0

func start_phase(resistance: int, interval: float, pattern: Array[int]) -> void:
	_phase_generation += 1
	current_resistance = resistance
	max_resistance = resistance
	attack_interval = interval
	_pattern = pattern
	_attack_index = 0
	resistance_changed.emit(resistance, resistance)
	_attack_timer.start(1.3)

func stop_phase() -> void:
	_phase_generation += 1
	current_resistance = 0
	_stop_attacks()
	for child: Node in get_children():
		if child is Bullet or (child is ExplosiveBarrel and not child._is_exploding):
			child.queue_free()
		elif child.is_in_group("boss_wave"):
			child.queue_free()

func _build_boss_visual() -> void:
	var base: StaticBody3D = StaticBody3D.new()
	base.name = "BossBase"
	base.collision_layer = 4
	base.collision_mask = 1 | 16 | 32
	var base_shape: BoxShape3D = BoxShape3D.new()
	base_shape.size = Vector3(2.0, 3.2, 1.0)
	var base_col: CollisionShape3D = CollisionShape3D.new()
	base_col.shape = base_shape
	base_col.position = Vector3(0, 1.6, 0)
	base.add_child(base_col)
	
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	base.add_child(visual)
	
	var post: MeshInstance3D = MeshInstance3D.new()
	var post_box: BoxMesh = BoxMesh.new()
	post_box.size = Vector3(0.4, 3.2, 0.4)
	post.mesh = post_box
	var post_mat: StandardMaterial3D = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.25, 0.05, 0.08, 1)
	post.material_override = post_mat
	post.position = Vector3(0, 1.6, 0)
	visual.add_child(post)
	
	var beam: MeshInstance3D = MeshInstance3D.new()
	var beam_box: BoxMesh = BoxMesh.new()
	beam_box.size = Vector3(2.0, 0.3, 0.3)
	beam.mesh = beam_box
	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.3, 0.08, 0.1, 1)
	beam.material_override = beam_mat
	beam.position = Vector3(0, 3.2, 0)
	visual.add_child(beam)
	
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
	
	var right_pan: MeshInstance3D = MeshInstance3D.new()
	right_pan.mesh = pan_shape.duplicate()
	right_pan.material_override = pan_mat.duplicate()
	right_pan.position = Vector3(0.9, 2.6, 0)
	visual.add_child(right_pan)
	
	for i in range(4):
		var chain: MeshInstance3D = MeshInstance3D.new()
		var chain_box: BoxMesh = BoxMesh.new()
		chain_box.size = Vector3(0.08, 0.8, 0.08)
		chain.mesh = chain_box
		var chain_mat: StandardMaterial3D = StandardMaterial3D.new()
		chain_mat.albedo_color = Color(0.2, 0.2, 0.25, 1)
		chain.material_override = chain_mat
		chain.position = Vector3(-0.9 + i % 2 * 1.8, 2.9 - (i / 2) * 0.4, 0)
		visual.add_child(chain)
	
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
	
	var hit_area: Area3D = Area3D.new()
	hit_area.name = "HitArea"
	hit_area.collision_layer = 4
	hit_area.collision_mask = 16
	var hit_shape: BoxShape3D = BoxShape3D.new()
	hit_shape.size = Vector3(2.5, 3.5, 1.5)
	var hit_col: CollisionShape3D = CollisionShape3D.new()
	hit_col.shape = hit_shape
	hit_col.position = Vector3(0, 1.6, 0)
	hit_area.add_child(hit_col)
	hit_area.area_entered.connect(_on_bullet_hit_shield)
	base.add_child(hit_area)
	
	if not auto_start:
		visual.hide()
		var entity: Sprite3D = Sprite3D.new()
		entity.name = "Entity"
		entity.texture = preload("res://assets/characters/entity/entity.png")
		entity.pixel_size = 5.0 / entity.texture.get_height()
		entity.position.y = 2.5
		entity.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		base.add_child(entity)
		var ash: CPUParticles3D = CPUParticles3D.new()
		ash.name = "Ash"
		ash.position = Vector3(0, 2.3, 0.2)
		ash.amount = 32
		ash.lifetime = 1.6
		ash.preprocess = 1.6
		ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		ash.emission_box_extents = Vector3(1.0, 1.7, 0.33)
		ash.direction = Vector3.UP
		ash.gravity = Vector3(0, 0.15, 0)
		ash.initial_velocity_min = 0.2
		ash.initial_velocity_max = 0.6
		var grain: BoxMesh = BoxMesh.new()
		grain.size = Vector3(0.06, 0.06, 0.06)
		var soot: StandardMaterial3D = StandardMaterial3D.new()
		soot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		soot.albedo_color = Color("#454458")
		grain.material = soot
		ash.mesh = grain
		entity.add_child(ash)
	base.position = Vector3(boss_x, 0, boss_z)
	add_child(base)

func _ensure_timers() -> void:
	_attack_timer = Timer.new()
	_attack_timer.name = "AttackTimer"
	_attack_timer.one_shot = true
	_attack_timer.wait_time = attack_interval
	_attack_timer.timeout.connect(_on_attack_timeout)
	add_child(_attack_timer)
	
	_shield_timer = Timer.new()
	_shield_timer.name = "ShieldTimer"
	_shield_timer.one_shot = true
	_shield_timer.wait_time = shield_flash_time
	_shield_timer.timeout.connect(_on_shield_flash_timeout)
	add_child(_shield_timer)

func _find_player_and_systems() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			_player = node as Node3D
			break
	
	for node in get_tree().get_nodes_in_group("boss_conveyor"):
		if node is OverheadConveyor:
			_conveyor = node as OverheadConveyor
			if auto_start:
				_conveyor.container_crashed.connect(_on_test_container_crashed)
			break
	
	for node in get_tree().get_nodes_in_group("boss_targets"):
		if node is ExplosiveBarrel:
			_barrels.append(node as ExplosiveBarrel)
			node.exploded.connect(_on_barrel_exploded)

func _on_attack_timeout() -> void:
	if current_resistance <= 0:
		return
	_execute_attack(_pattern[_attack_index])
	_attack_index = (_attack_index + 1) % _pattern.size()
	_attack_timer.start(attack_interval)

func _execute_attack(index: int) -> void:
	_active_attack = index
	attack_started.emit(index)
	match index:
		0: _attack_spikes()
		1: _attack_shockwave()
		2: _attack_throw_barrel()
		3: _attack_drop_container()

func _attack_spikes() -> void:
	var hand_pos: Vector3 = to_global(Vector3(boss_x - 1.4, 1.65, boss_z))
	_create_telegraph(hand_pos, 0.45, Color(1, 0.2, 0.2, 0.8))
	
	_fire_spikes(hand_pos, 0.45)

func _fire_spikes(origin: Vector3, delay: float) -> void:
	var phase: int = _phase_generation
	await get_tree().create_timer(delay, false).timeout
	if phase != _phase_generation or current_resistance <= 0:
		return
	
	if _player == null:
		return
	
	get_node("/root/Audio").sfx("res://assets/audio/story/metanie.wav", -10.0)
	var dir_to_player: Vector3 = (_player.global_position + Vector3.UP * 0.9 - origin).normalized()
	if dir_to_player.length_squared() < 0.001:
		dir_to_player = Vector3(-1, 0, 0)
	
	var angles: Array[float] = [-0.25, 0.0, 0.25]
	for angle in angles:
		var rotated_dir: Vector3 = dir_to_player.rotated(Vector3.UP, angle)
		_spawn_enemy_bullet(origin + rotated_dir * 0.5, rotated_dir, 15)

func _attack_shockwave() -> void:
	if _player == null:
		return
	
	var player_z: float = _player.global_position.z
	var warn_z_min: float = player_z - 0.9
	var warn_z_max: float = player_z + 0.9
	
	_create_floor_warning(warn_z_min, warn_z_max, 0.75)
	
	_execute_shockwave(warn_z_min, warn_z_max, 0.75)

func _execute_shockwave(z_min: float, z_max: float, delay: float) -> void:
	var phase: int = _phase_generation
	await get_tree().create_timer(delay, false).timeout
	if phase != _phase_generation or current_resistance <= 0:
		return
	
	get_node("/root/Audio").sfx("res://assets/audio/story/shockwave.wav", -10.0)
	var player: BossPlayer = _player as BossPlayer
	if player:
		_create_shockwave(z_min, z_max, player.arena_min.x - 0.4)
		_create_shockwave(z_min, z_max, player.arena_max.x + 0.4)

func _attack_throw_barrel() -> void:
	if _player == null:
		return
	
	var barrel: ExplosiveBarrel = _get_available_barrel()
	if barrel == null:
		return
	
	var barrel_pos: Vector3 = Vector3(boss_x - 2.0, 1.3, clampf(_player.global_position.z, -1.8, 1.8))
	barrel.global_position = barrel_pos
	barrel.near_boss = true
	barrel.boss_damage = 25
	barrel.player_damage = 20
	get_node("/root/Audio").sfx("res://assets/audio/story/telekines.wav", -12.0)
	barrel.visible = true
	
	_create_drop_zone_visual(_player.global_position, 2.54)
	
	_on_barrel_throw_timeout(barrel, _player.global_position, 2.2)

func _on_barrel_throw_timeout(barrel: ExplosiveBarrel, target_pos: Vector3, delay: float) -> void:
	var phase: int = _phase_generation
	await get_tree().create_timer(delay, false).timeout
	if phase != _phase_generation or not is_instance_valid(barrel) or barrel._is_exploding:
		return
	
	if barrel.is_inside_tree() and barrel.get_parent() != null:
		barrel.near_boss = false
		var launch: Tween = barrel.create_tween()
		launch.tween_property(barrel, "global_position", target_pos, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await launch.finished
		if is_instance_valid(barrel):
			barrel.take_bullet_hit()

func _attack_drop_container() -> void:
	if _conveyor != null and _player != null:
		if _conveyor.threaten(_player.global_position.x):
			return
	_drop_own_container()

func _drop_own_container() -> void:
	if _player == null:
		return
	
	var drop_pos: Vector3 = _player.global_position
	_create_drop_zone_visual(drop_pos, 1.0)
	var cargo: Sprite3D = Sprite3D.new()
	cargo.texture = preload("res://assets/3d/factory/workshop/art/01_suspended_load.png")
	cargo.pixel_size = 1.45 / cargo.texture.get_width()
	cargo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(cargo)
	cargo.global_position = drop_pos + Vector3.UP * 4.1
	var fall: Tween = create_tween()
	fall.tween_property(cargo, "position:y", cargo.position.y - 3.55, 0.4).set_delay(0.60).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(cargo.queue_free)
	_execute_container_drop(drop_pos, 1.0)

func _execute_container_drop(pos: Vector3, delay: float) -> void:
	var phase: int = _phase_generation
	await get_tree().create_timer(delay, false).timeout
	if phase != _phase_generation or current_resistance <= 0:
		return
	
	_create_impact_flash(pos)
	
	if _player != null:
		var dist: float = _player.global_position.distance_to(pos)
		if dist <= 1.5 and _player.has_method("take_damage"):
			_player.call("take_damage", 25)

func _get_available_barrel() -> ExplosiveBarrel:
	for barrel in _barrels:
		if is_instance_valid(barrel) and not barrel._is_exploding:
			return barrel
	
	var barrel_scene: PackedScene = preload("res://scenes/gameplay/boss/explosive_barrel.tscn")
	var new_barrel: ExplosiveBarrel = barrel_scene.instantiate() as ExplosiveBarrel
	add_child(new_barrel)
	new_barrel.exploded.connect(_on_barrel_exploded)
	_barrels.append(new_barrel)
	return new_barrel

func _on_test_container_crashed(hit_boss: bool, amount: int, _pos: Vector3) -> void:
	if hit_boss:
		apply_environment_damage(amount)

func _on_barrel_exploded(near_boss: bool, damage: int, _pos: Vector3) -> void:
	if near_boss:
		apply_environment_damage(damage)

func apply_environment_damage(amount: int) -> void:
	if current_resistance <= 0:
		return
	
	current_resistance = maxi(0, current_resistance - amount)
	resistance_changed.emit(current_resistance, max_resistance)
	
	_flash_white()
	
	if current_resistance <= 0:
		stop_phase()
		phase_broken.emit()

func _stop_attacks() -> void:
	if _attack_timer != null:
		_attack_timer.stop()

func _on_bullet_hit_shield(area: Area3D) -> void:
	if area is Bullet:
		_flash_shield()
		bullet_deflected.emit(area.global_position)

func _flash_shield() -> void:
	if _is_shield_flashing:
		return
	_is_shield_flashing = true
	_shield_mesh.visible = true
	_shield_timer.start()

func _on_shield_flash_timeout() -> void:
	_shield_mesh.visible = false
	_is_shield_flashing = false

func _flash_white() -> void:
	var entity: Sprite3D = get_node_or_null("BossBase/Entity")
	if entity == null:
		_flash_shield()
		return
	entity.modulate = Color(1.85, 1.85, 1.85)
	create_tween().tween_property(entity, "modulate", Color.WHITE, 0.18)

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
	add_child(telegraph)
	telegraph.global_position = pos
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(telegraph, "material_override:emission_energy_multiplier", 0.0, duration)
	tween.tween_property(telegraph, "scale", Vector3(2.0, 2.0, 2.0), duration)
	tween.chain().tween_callback(telegraph.queue_free)

func _lane_center_x() -> float:
	var actor: BossPlayer = _player as BossPlayer
	return (actor.arena_min.x + actor.arena_max.x) * 0.5 if actor else 0.0


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
	_attack_warning.global_position = Vector3(_lane_center_x(), 0.04, (z_min + z_max) * 0.5)
	
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

func _create_shockwave(z_min: float, z_max: float, end_x: float) -> void:
	var wave: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = Vector3(0.42, 0.32, z_max - z_min)
	wave.mesh = shape
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.64, 0.27, 0.74)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.31, 0.07)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wave.material_override = material
	wave.add_to_group("boss_wave")
	add_child(wave)
	wave.global_position = Vector3(boss_x, 0.18, (z_min + z_max) * 0.5)
	var flight: Tween = wave.create_tween()
	flight.tween_method(_wave_at.bind(wave, z_min, z_max), boss_x, end_x, absf(end_x - boss_x) / 25.0)
	flight.tween_callback(wave.queue_free)


func _wave_at(x: float, wave: MeshInstance3D, z_min: float, z_max: float) -> void:
	wave.global_position.x = x
	if current_resistance <= 0 or _player == null or wave.has_meta("struck"):
		return
	var at: Vector3 = _player.global_position
	if absf(at.x - x) < 0.6 and at.z >= z_min and at.z <= z_max:
		wave.set_meta("struck", true)
		_player.call("take_damage", 20)


func _create_drop_zone_visual(pos: Vector3, duration: float) -> void:
	var zone: MeshInstance3D = MeshInstance3D.new()
	zone.name = "DropZone"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(3.0, 0.1, 3.0)
	zone.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.1, 0.1, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.0, 0.0, 1)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone.material_override = mat
	add_child(zone)
	zone.global_position = Vector3(pos.x, 0.05, pos.z)
	
	var tween: Tween = create_tween()
	tween.tween_callback(zone.queue_free.bind()).set_delay(duration)

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
	add_child(flash)
	flash.global_position = Vector3(pos.x, 0.5, pos.z)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "material_override:emission_energy_multiplier", 0.0, 0.3)
	tween.tween_property(flash, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.chain().tween_callback(flash.queue_free)

func _spawn_enemy_bullet(pos: Vector3, dir: Vector3, dmg: int) -> void:
	var bullet_scene: PackedScene = preload("res://scenes/gameplay/bullet.tscn")
	var bullet: Node3D = bullet_scene.instantiate() as Node3D
	bullet.position = to_local(pos)
	if bullet.has_method("configure"):
		bullet.call("configure", dir, true, dmg, 30.0, null)
	bullet.collision_mask = 1 | 2
	add_child(bullet)