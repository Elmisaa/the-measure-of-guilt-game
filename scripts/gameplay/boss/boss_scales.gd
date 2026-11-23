class_name BossScales
extends Node3D

signal resistance_changed(cur: int, max_val: int)
signal phase_broken
signal bullet_deflected(hit_pos: Vector3)

@export var max_resistance: int = 100
@export var attack_interval: float = 2.6
@export var boss_x: float = 6.2
@export var shield_flash_time: float = 0.15

var current_resistance: int = 100
var _attack_timer: Timer
var _attack_index: int = 0
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
	
	_attack_timer.start(attack_interval)

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
	
	base.position = Vector3(boss_x, 0, 0)
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
	
	for node in get_tree().get_nodes_in_group("boss_targets"):
		if node.get_class() == "OverheadConveyor":
			_conveyor = node as OverheadConveyor
			break
	
	for node in get_tree().get_nodes_in_group("boss_targets"):
		if node.get_class() == "ExplosiveBarrel":
			_barrels.append(node as ExplosiveBarrel)

func _on_attack_timeout() -> void:
	if current_resistance <= 0:
		return
	_attack_index = (_attack_index + 1) % 4
	_execute_attack(_attack_index)
	_attack_timer.start(attack_interval)

func _execute_attack(index: int) -> void:
	_active_attack = index
	match index:
		0: _attack_spikes()
		1: _attack_shockwave()
		2: _attack_throw_barrel()
		3: _attack_drop_container()

func _attack_spikes() -> void:
	var hand_pos: Vector3 = global_position + Vector3(0, 2.5, 0)
	_create_telegraph(hand_pos, 0.45, Color(1, 0.2, 0.2, 0.8))
	
	var tween: Tween = create_tween()
	tween.tween_callback(_fire_spikes.bind(hand_pos).bind(0.45))

func _fire_spikes(origin: Vector3, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or current_resistance <= 0:
		return
	
	if _player == null:
		return
	
	var dir_to_player: Vector3 = (_player.global_position - origin).normalized()
	dir_to_player.y = 0
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
	
	var tween: Tween = create_tween()
	tween.tween_callback(_execute_shockwave.bind(warn_z_min, warn_z_max).bind(0.75))

func _execute_shockwave(z_min: float, z_max: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or current_resistance <= 0:
		return
	
	if _player != null:
		var pz: float = _player.global_position.z
		if pz >= z_min and pz <= z_max and _player.has_method("take_damage"):
			_player.call("take_damage", 20)
	
	_create_shockwave_visual(z_min, z_max)

func _attack_throw_barrel() -> void:
	if _player == null:
		return
	
	var barrel: ExplosiveBarrel = _get_available_barrel()
	if barrel == null:
		return
	
	var barrel_pos: Vector3 = Vector3(4.2, 1.3, _player.global_position.z)
	barrel.global_position = barrel_pos
	barrel.near_boss = true
	barrel.boss_damage = 25
	barrel.player_damage = 20
	barrel.add_to_group("boss_targets")
	barrel.visible = true
	
	_create_drop_zone_visual(_player.global_position, 2.2)
	
	var tween: Tween = create_tween()
	tween.tween_callback(_on_barrel_throw_timeout.bind(barrel, _player.global_position).bind(2.2))

func _on_barrel_throw_timeout(barrel: ExplosiveBarrel, target_pos: Vector3, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or not is_instance_valid(barrel):
		return
	
	if barrel.is_inside_tree() and barrel.get_parent() != null:
		barrel.global_position = target_pos
		barrel.near_boss = false
		barrel.take_bullet_hit()

func _attack_drop_container() -> void:
	if _conveyor == null:
		_drop_own_container()
		return
	
	var dropped: bool = false
	for i in _conveyor._carriages.size():
		if _conveyor._has_container[i] and not _conveyor._dropping[i]:
			var carriage: Node3D = _conveyor._carriages[i]
			if abs(carriage.global_position.x - boss_x) <= 2.5:
				_conveyor._start_drop(i)
				dropped = true
				break
	
	if not dropped:
		_drop_own_container()

func _drop_own_container() -> void:
	if _player == null:
		return
	
	var drop_pos: Vector3 = _player.global_position
	_create_drop_zone_visual(drop_pos, 1.0)
	
	var tween: Tween = create_tween()
	tween.tween_callback(_execute_container_drop.bind(drop_pos).bind(1.0))

func _execute_container_drop(pos: Vector3, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or current_resistance <= 0:
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
	_barrels.append(new_barrel)
	return new_barrel

func apply_environment_damage(amount: int) -> void:
	if current_resistance <= 0:
		return
	
	current_resistance = maxi(0, current_resistance - amount)
	resistance_changed.emit(current_resistance, max_resistance)
	
	_flash_white()
	
	if current_resistance <= 0:
		phase_broken.emit()
		_stop_attacks()

func _stop_attacks() -> void:
	if _attack_timer != null:
		_attack_timer.stop()

func _on_bullet_hit_shield(area: Area3D) -> void:
	if area is Bullet:
		_flash_shield(area.global_position)
		bullet_deflected.emit(area.global_position)

func _flash_shield(hit_pos: Vector3) -> void:
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
	tween.tween_callback(_restore_colors.bind(original_colors).bind(0.1))

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
	telegraph.global_position = pos
	add_child(telegraph)
	
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
	_attack_warning.global_position = Vector3(0, 0.04, (z_min + z_max) * 0.5)
	add_child(_attack_warning)
	
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
	wave.global_position = Vector3(0, 0.3, (z_min + z_max) * 0.5)
	add_child(wave)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "material_override:emission_energy_multiplier", 0.0, 0.3)
	tween.tween_property(wave, "scale", Vector3(1.0, 0.1, 1.0), 0.3)
	tween.tween_callback(wave.queue_free.bind())

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
	zone.global_position = Vector3(pos.x, 0.05, pos.z)
	add_child(zone)
	
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
	flash.global_position = Vector3(pos.x, 0.5, pos.z)
	add_child(flash)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "material_override:emission_energy_multiplier", 0.0, 0.3)
	tween.tween_property(flash, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.tween_callback(flash.queue_free.bind())

func _spawn_enemy_bullet(pos: Vector3, dir: Vector3, dmg: int) -> void:
	var bullet_scene: PackedScene = preload("res://scenes/gameplay/bullet.tscn")
	var bullet: Node3D = bullet_scene.instantiate() as Node3D
	bullet.global_position = pos
	if bullet.has_method("configure"):
		bullet.call("configure", dir, true, dmg, 30.0, null)
	bullet.collision_mask = 1 | 2 | 4
	add_child(bullet)