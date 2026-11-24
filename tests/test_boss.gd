extends SceneTree
## Boss prototype tests: arena wiring, player combat, environmental damage and
## conveyor cargo cycle. Run with:
## godot --headless --path . -s res://tests/test_boss.gd

const ArenaScene: PackedScene = preload("res://scenes/gameplay/boss/_test_final_arena.tscn")
const BossScene: PackedScene = preload("res://scenes/gameplay/boss/boss_scales.tscn")
const BulletScene: PackedScene = preload("res://scenes/gameplay/bullet.tscn")
const BarrelScene: PackedScene = preload("res://scenes/gameplay/boss/explosive_barrel.tscn")
const SAFETY_TIMEOUT: float = 20.0

var _ok: bool = true


func _init() -> void:
	_run.call_deferred()
	create_timer(SAFETY_TIMEOUT).timeout.connect(func() -> void:
		push_error("BOSS TEST TIMEOUT")
		quit(2))


func _fail(message: String) -> void:
	push_error("FAIL " + message)
	_ok = false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _find_child_named(parent: Node, node_name: String) -> Node:
	for child in parent.get_children():
		if child.name == node_name:
			return child
	return null


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	var arena: Node3D = ArenaScene.instantiate() as Node3D
	_check(arena != null, "final boss arena did not load")
	if arena == null:
		print("BOSS TEST: FAILED")
		quit(1)
		return

	var conveyor: OverheadConveyor = arena.get_node_or_null("OverheadConveyor") as OverheadConveyor
	_check(conveyor != null, "arena has no overhead conveyor")
	if conveyor != null:
		# Keep the respawn assertion short without changing runtime defaults.
		conveyor.respawn_delay = 0.05
	var boss_before_ready: BossScales = arena.get_node_or_null("BossScales") as BossScales
	if boss_before_ready != null:
		boss_before_ready.attack_interval = 100.0
		boss_before_ready.phase_attack_intervals = [100.0, 100.0, 100.0, 100.0]
	root.add_child(arena)
	await _frames(4)

	var player: BossPlayer = arena.get_node_or_null("BossPlayer") as BossPlayer
	var boss: BossScales = arena.get_node_or_null("BossScales") as BossScales
	var hud: BossHud = arena.get_node_or_null("BossHud") as BossHud
	_check(player != null, "arena has no boss player")
	_check(boss != null, "arena has no Scales boss")
	_check(hud != null, "arena has no boss HUD")
	if player == null or boss == null or conveyor == null:
		arena.queue_free()
		await _frames(2)
		print("BOSS TEST: ", "OK" if _ok else "FAILED")
		quit(0 if _ok else 1)
		return

	_check(player.health == 100, "player should start at 100 health")
	_check(player.ammo_current == 6 and player.ammo_max == 6, "pistol should start with 6/6 ammo")
	_check(boss.current_resistance == 100, "boss should start at 100 resistance")
	_check(boss._conveyor == conveyor, "boss did not find the arena conveyor")
	_check(boss._barrels.size() >= 2, "boss did not find the arena barrels")
	_check(not conveyor.is_in_group("boss_targets"), "the conveyor root must not be a shootable aim target")

	# Spike shots originate above the floor and must angle down toward the player's chest.
	boss._fire_spikes(Vector3(0, 2.5, 0), 0.01, boss._phase_token)
	await create_timer(0.05).timeout
	var spike_bullet_count: int = 0
	for child in boss.get_children():
		if child is Bullet:
			spike_bullet_count += 1
			_check((child as Bullet).direction.y < 0.0,
				"spike bullets should travel downward toward the player's chest")
			child.queue_free()
	_check(spike_bullet_count == 3, "spike attack should fire a three-projectile fan")
	await _frames(1)

	# Telegraph must appear at the boss model (global_position + boss_x), not at the root.
	var spike_boss: BossScales = BossScene.instantiate() as BossScales
	spike_boss.attack_interval = 100.0
	spike_boss.phase_attack_intervals = [100.0, 100.0, 100.0, 100.0]
	root.add_child(spike_boss)
	await _frames(2)
	spike_boss._attack_spikes(spike_boss._phase_token)
	var telegraph: MeshInstance3D = spike_boss.get_node_or_null("Telegraph") as MeshInstance3D
	_check(telegraph != null, "spike attack should create a telegraph")
	if telegraph != null:
		var expected_x: float = spike_boss.global_position.x + spike_boss.boss_x
		_check(is_equal_approx(telegraph.global_position.x, expected_x),
			"spike telegraph should start at the boss model, not the scene root")
	spike_boss.queue_free()
	await _frames(2)

	# Sound-wave rings should spread across the floor, then clean themselves up.
	boss._create_shockwave_visual(-0.9, 0.9)
	var first_ripple: MeshInstance3D = boss.get_node_or_null("ShockwaveRing_0") as MeshInstance3D
	_check(first_ripple != null, "shockwave should create its first ripple ring")
	var ripple_start_scale: float = first_ripple.scale.x if first_ripple != null else 0.0
	await create_timer(0.12).timeout
	_check(is_instance_valid(first_ripple) and first_ripple.scale.x > ripple_start_scale,
		"sound-wave ring should expand over time")

	# Shooting spends a round; reload restores the magazine.
	player.shoot()
	_check(player.ammo_current == 5, "shooting should spend one round")
	player.reload_time = 0.05
	player.reload()
	_check(player.is_reloading, "reload should enter the reloading state")
	await create_timer(0.1).timeout
	_check(not player.is_reloading, "reload should finish")
	_check(player.ammo_current == player.ammo_max, "reload should refill the magazine")

	# A dash grants temporary invulnerability; damage applies after it expires.
	player._start_dash()
	var health_before_dash_hit: int = player.health
	player.take_damage(10)
	_check(player.health == health_before_dash_hit, "dash invulnerability should block damage")
	player._on_invuln_timeout()
	player.take_damage(10)
	_check(player.health == health_before_dash_hit - 10, "player should take damage after dash invulnerability")
	player._on_dash_timeout()

	# Direct fire is deflected; environmental damage reduces resistance and
	# reaching zero emits the phase-broken signal and stops the attack timer.
	var bullet: Bullet = BulletScene.instantiate() as Bullet
	arena.add_child(bullet)
	boss._on_bullet_hit_shield(bullet)
	_check(boss.current_resistance == 100, "direct bullets must not damage the boss")
	bullet.queue_free()

	var remote_barrel: ExplosiveBarrel = arena.get_node_or_null("ExplosiveBarrel1") as ExplosiveBarrel
	_check(remote_barrel != null, "arena has no first explosive barrel")
	if remote_barrel != null:
		var remote_barrel_position: Vector3 = remote_barrel.global_position
		_check(not remote_barrel.near_boss, "a barrel far from the boss must not start in the near-boss state")
		remote_barrel.take_bullet_hit()
		_check(boss.current_resistance == 100, "a remote barrel explosion must not damage the boss")
		await create_timer(3.1).timeout
		var remote_barrel_respawned: bool = false
		for target in get_nodes_in_group("boss_targets"):
			if target is ExplosiveBarrel:
				if (target as ExplosiveBarrel).global_position.distance_to(remote_barrel_position) < 0.1:
					remote_barrel_respawned = true
					_check(not (target as ExplosiveBarrel).near_boss,
						"a remote barrel respawn must remain outside the boss counterattack zone")
					_check(boss._barrels.has(target as ExplosiveBarrel),
						"a respawned barrel must stay registered as a boss target")
		_check(remote_barrel_respawned, "an exploded barrel should respawn")
		_check(not is_instance_valid(first_ripple), "sound-wave rings should be removed after fading")
	var near_barrel: ExplosiveBarrel = arena.get_node_or_null("ExplosiveBarrel2") as ExplosiveBarrel
	_check(near_barrel != null and near_barrel.near_boss, "the barrel beside the boss should be a counterattack target")

	# Бочка: зона фиксирует точку атаки в момент показа, взрыв происходит именно там.
	var dodge_boss: BossScales = BossScene.instantiate() as BossScales
	dodge_boss.attack_interval = 100.0
	dodge_boss.phase_attack_intervals = [100.0, 100.0, 100.0, 100.0]
	root.add_child(dodge_boss)
	await _frames(2)
	dodge_boss.remove_from_group("boss")  # тестовый босс не должен получать урон от бочек арены
	player.global_position = Vector3(-4.0, 0.0, 0.0)
	var health_before_barrel: int = player.health
	dodge_boss._attack_throw_barrel(dodge_boss._phase_token)
	var dodge_barrel: ExplosiveBarrel = null
	for barrel in dodge_boss._barrels:
		if dodge_boss._pulled_barrels.has(barrel):
			dodge_barrel = barrel
			break
	_check(dodge_barrel != null, "barrel attack should register a new dynamic barrel")
	var barrel_explosions: Array[Vector3] = []
	if dodge_barrel != null:
		dodge_barrel.exploded.connect(func(_near: bool, _dmg: int, pos: Vector3) -> void:
			barrel_explosions.append(pos))
	await create_timer(0.75).timeout
	var captured: Dictionary = dodge_boss._barrel_targets.get(dodge_barrel, {})
	var captured_pos: Vector3 = captured.get("pos", Vector3(-999.0, -999.0, -999.0))
	var captured_radius: float = captured.get("radius", 0.0)
	_check(captured_pos.distance_to(Vector3(-4.0, 0.0, 0.0)) < 0.1,
		"barrel zone must capture the player's position when the telegraph appears")
	_check(dodge_barrel != null and is_equal_approx(captured_radius, dodge_barrel.blast_radius),
		"barrel zone radius must match the blast radius")
	# Игрок ушёл из зоны: взрыв всё равно должен произойти в зафиксированной точке.
	player.global_position = Vector3(8.0, 0.0, 0.0)
	await create_timer(2.9).timeout
	_check(barrel_explosions.size() == 1, "a thrown barrel should explode exactly once")
	if barrel_explosions.size() == 1:
		_check(barrel_explosions[0].distance_to(captured_pos) < 0.05,
			"barrel must explode inside the telegraphed zone, not at the moved player")
	_check(player.health == health_before_barrel,
		"dodging outside the fixed barrel zone should avoid the blast")
	dodge_boss.queue_free()
	await _frames(2)

	# Динамическая бочка и реальный выстрел по ней: урон Весам применяется один раз.
	var shot_barrel: ExplosiveBarrel = BarrelScene.instantiate() as ExplosiveBarrel
	arena.add_child(shot_barrel)
	var shot_barrel_pos: Vector3 = Vector3(boss.global_position.x + boss.boss_x, 0.45, 0.0)
	shot_barrel.global_position = shot_barrel_pos
	shot_barrel.near_boss = true
	shot_barrel.boss_damage = 25
	boss.register_barrel(shot_barrel)  # HUD подключается через barrel_registered
	_check(boss._barrels.has(shot_barrel),
		"a dynamically created barrel must be registered as a valid boss target")
	var barrel_count_before_shot: int = boss._barrels.size()
	var shot_explosions: Array[Vector3] = []
	shot_barrel.exploded.connect(func(_near: bool, _dmg: int, pos: Vector3) -> void:
		shot_explosions.append(pos))
	player.global_position = Vector3(2.0, 0.0, 0.0)
	player._hovered_target = shot_barrel
	player.shoot()
	player._hovered_target = null
	await create_timer(0.4).timeout
	_check(shot_explosions.size() == 1, "a real boss-arena shot must hit and detonate the barrel")
	_check(boss.current_resistance == 75,
		"one shot on a near-boss barrel should deal exactly 25 resistance damage")
	if shot_explosions.size() == 1:
		_check(shot_explosions[0].distance_to(shot_barrel_pos) < 0.1,
			"the barrel must detonate at its own position")
	_check(not is_instance_valid(shot_barrel), "an exploded barrel should be removed from the arena")
	_check(boss._barrels.size() < barrel_count_before_shot,
		"an exploded barrel must leave the active target list")
	# Возрождённая бочка снова становится целью и снова подключена к HUD.
	await create_timer(3.1).timeout
	var shot_barrel_respawned: bool = false
	for target in get_nodes_in_group("boss_targets"):
		if target is ExplosiveBarrel and (target as ExplosiveBarrel).global_position.distance_to(shot_barrel_pos) < 0.1:
			shot_barrel_respawned = true
			_check(boss._barrels.has(target as ExplosiveBarrel),
				"a respawned dynamic barrel must be registered with the boss")
			_check((target as ExplosiveBarrel).near_boss,
				"a barrel respawning in the counterattack zone must stay a counterattack target")
	_check(shot_barrel_respawned, "a shot barrel should respawn")
	# Дальнейшие проверки фаз начинаются с полного сопротивления.
	boss.current_resistance = 100
	hud._on_boss_resistance_changed(100, 100)

	# Shoot a loaded conveyor carriage while it is over the boss.
	conveyor._carriages[0].global_position = Vector3(conveyor.boss_x, 0.0, 0.0)
	var cargo_bullet: Bullet = BulletScene.instantiate() as Bullet
	conveyor._on_container_hit(cargo_bullet, 0)
	_check(conveyor._dropping[0], "shooting a loaded carriage should start its drop")
	var player_health_before_drop: int = player.health
	# Stand just outside the boss collision volume but inside cargo blast radius.
	player.global_position = Vector3(conveyor.boss_x, 0.0, 1.2)
	await create_timer(0.5).timeout
	_check(boss.current_resistance == 50, "cargo dropped over the boss should deal 50 resistance damage")
	_check(hud._boss_resistance == 50, "boss HUD should update after a container counterattack")
	_check(player.health < player_health_before_drop, "a falling cargo should damage a player beneath it")
	_check(conveyor._has_container[0], "the conveyor should respawn dropped cargo")
	cargo_bullet.free()

	# Самосброс босса по каретке над ним: груз падает, но сопротивление не трогает.
	var conveyor_speed_before: float = conveyor.speed
	conveyor.speed = 0.0  # фиксируем каретки, чтобы тест был детерминированным
	var cargo_boss_hits: Array[int] = [0]
	conveyor.container_crashed.connect(func(hit_boss: bool, _dmg: int, _pos: Vector3) -> void:
		if hit_boss:
			cargo_boss_hits[0] += 1)
	await create_timer(0.1).timeout  # ждём респавн груза после предыдущего сброса
	conveyor._carriages[0].global_position = Vector3(conveyor.boss_x, 0.0, 0.0)
	var resistance_before_self_drop: int = boss.current_resistance
	boss._attack_drop_container(boss._phase_token)
	_check(conveyor._dropping[0], "boss self-drop should drop the loaded carriage over itself")
	await create_timer(0.4).timeout
	_check(boss.current_resistance == resistance_before_self_drop,
		"cargo dropped by the boss itself must not damage the boss")
	_check(cargo_boss_hits[0] == 0, "self-dropped cargo must not report a boss hit")

	# Реальный выстрел игрока по загруженной каретке над Весами: ровно 50 урона один раз.
	await create_timer(0.1).timeout
	conveyor._carriages[0].global_position = Vector3(conveyor.boss_x, 0.0, 0.0)
	conveyor._carriages[1].global_position = Vector3(-9.0, 0.0, 0.0)
	conveyor._carriages[2].global_position = Vector3(-6.0, 0.0, 0.0)
	boss.current_resistance = 100
	hud._on_boss_resistance_changed(100, 100)
	player.global_position = Vector3(conveyor.boss_x - 4.0, 0.0, 0.0)
	player._hovered_target = conveyor._container_hit_areas[0]
	player.shoot()
	player._hovered_target = null
	await create_timer(0.5).timeout
	_check(cargo_boss_hits[0] == 1, "a player shot should report exactly one boss cargo hit")
	_check(boss.current_resistance == 50,
		"a player-shot container over the boss should deal exactly 50 resistance damage")
	conveyor.speed = conveyor_speed_before

	# Запасной сброс без каретки: видимый контейнер падает в отмеченную точку и не ранит Весы.
	var fallback_boss: BossScales = BossScene.instantiate() as BossScales
	fallback_boss.attack_interval = 100.0
	fallback_boss.phase_attack_intervals = [100.0, 100.0, 100.0, 100.0]
	root.add_child(fallback_boss)
	await _frames(2)
	fallback_boss.remove_from_group("boss")
	fallback_boss._conveyor = null  # намеренно убираем конвейер, чтобы включить запасной вариант
	fallback_boss.fallback_container_fall_time = 0.6
	player.health = player.max_health
	player._on_invuln_timeout()
	player.global_position = Vector3(-3.0, 0.0, 0.0)
	var fallback_target: Vector3 = player.global_position
	var fallback_health_before: int = player.health
	var fallback_resistance_before: int = fallback_boss.current_resistance
	var fallback_resistance_signals: Array[int] = [0]
	fallback_boss.resistance_changed.connect(func(_cur: int, _max: int) -> void:
		fallback_resistance_signals[0] += 1)
	var fallback_landings: Array[Vector3] = []
	fallback_boss._attack_drop_container(fallback_boss._phase_token)
	var falling_container: MeshInstance3D = _find_child_named(fallback_boss, "FallbackContainer") as MeshInstance3D
	var fallback_zone: MeshInstance3D = _find_child_named(fallback_boss, "DropZone") as MeshInstance3D
	_check(falling_container != null, "fallback attack should spawn a visible container")
	_check(fallback_zone != null, "fallback attack should mark the impact zone")
	if fallback_zone != null:
		_check(Vector2(fallback_zone.global_position.x - fallback_target.x,
			fallback_zone.global_position.z - fallback_target.z).length() < 0.05,
			"fallback zone must mark the fixed impact point")
	var falling_start_y: float = -1.0
	if falling_container != null:
		falling_container.tree_exiting.connect(func() -> void:
			fallback_landings.append(falling_container.global_position))
		_check(falling_container.visible, "fallback container must be visible in the air")
		falling_start_y = falling_container.global_position.y
		_check(falling_start_y > 0.55, "fallback container must start in the air")
		_check(absf(falling_container.global_position.x - fallback_target.x) < 0.05 and
			absf(falling_container.global_position.z - fallback_target.z) < 0.05,
			"fallback container must fly over the marked point")
	await create_timer(0.2).timeout
	if falling_container != null and is_instance_valid(falling_container):
		_check(falling_container.global_position.y < falling_start_y - 0.1,
			"fallback container must descend during the warning")
	await create_timer(0.5).timeout  # 0.7с > 0.6с падения
	_check(not is_instance_valid(falling_container), "the landed container should be cleaned up")
	_check(player.health == fallback_health_before - 25,
		"fallback container must deal 25 damage to a player in the marked zone")
	_check(fallback_boss.current_resistance == fallback_resistance_before,
		"fallback container must not reduce the Scales resistance")
	_check(fallback_resistance_signals[0] == 0,
		"fallback container must not emit a resistance change")
	_check(fallback_landings.size() == 1,
		"fallback container should reach the marked point exactly once")
	if fallback_landings.size() == 1:
		_check(Vector2(fallback_landings[0].x - fallback_target.x,
			fallback_landings[0].z - fallback_target.z).length() < 0.05 and
			absf(fallback_landings[0].y - 0.55) < 0.01,
			"fallback container must land at the marked point on the floor")
	# Удаление босса во время падения не должно оставлять груз в сцене.
	fallback_boss._attack_drop_container(fallback_boss._phase_token)
	var in_flight_container: MeshInstance3D = _find_child_named(fallback_boss, "FallbackContainer") as MeshInstance3D
	_check(in_flight_container != null, "a second fallback attack should spawn another container")
	fallback_boss.queue_free()
	await _frames(2)
	_check(in_flight_container == null or not is_instance_valid(in_flight_container),
		"freeing the boss must clean up an in-flight fallback container")

	var phase_break_count: Array[int] = [0]
	boss.phase_broken.connect(func() -> void:
		phase_break_count[0] += 1)
	var phase_start_count: Array[int] = [0]
	boss.phase_started.connect(func(_phase: int) -> void:
		phase_start_count[0] += 1)
	var resistance_before_hit: int = boss.current_resistance
	boss.apply_environment_damage(25)
	_check(boss.current_resistance == maxi(0, resistance_before_hit - 25),
		"environmental hit should reduce resistance by its damage amount")
	boss.apply_environment_damage(100)
	_check(phase_break_count[0] == 1, "empty resistance should emit phase_broken once")
	_check(boss.current_phase == 2, "breaking phase 1 should advance to phase 2")
	_check(boss.current_resistance == 100, "a new phase should restore 100 resistance")
	_check(phase_start_count[0] == 1, "advancing should announce the new phase")
	_check(not boss._attack_timer.is_stopped(), "attacks should continue in the next phase")

	# Каждая следующая фаза также требует полного обнуления сопротивления.
	for expected_phase: int in [3, 4]:
		boss.apply_environment_damage(100)
		_check(boss.current_phase == expected_phase,
			"breaking a phase should advance to phase %d" % expected_phase)
		_check(boss.current_resistance == 100, "each new phase should start at full resistance")
	boss.apply_environment_damage(100)
	_check(phase_break_count[0] == 4, "all four phases should emit phase_broken")
	_check(boss.is_defeated, "breaking phase 4 should defeat the boss")
	_check(boss._attack_timer.is_stopped(), "boss attacks should stop after the final phase")
	boss.apply_environment_damage(25)
	_check(phase_break_count[0] == 4, "damage after defeat must not emit another phase break")
	_check(hud._phase_label.text == "ВЕСЫ ПОВЕРЖЕНЫ", "HUD should announce the defeat")

	# Допросы пропускают фазы 2–4; два допроса убирают фазы 2 и 3 из плана.
	var skip_boss: BossScales = BossScene.instantiate() as BossScales
	skip_boss.attack_interval = 100.0
	skip_boss.phase_attack_intervals = [100.0, 100.0, 100.0, 100.0]
	skip_boss.interrogation_count = 2
	root.add_child(skip_boss)
	await _frames(2)
	_check(skip_boss.current_phase == 1, "phase 1 stays active even when later phases are interrogated away")
	_check(skip_boss.is_phase_skipped(2) and skip_boss.is_phase_skipped(3) and not skip_boss.is_phase_skipped(4),
		"two interrogations should skip phases 2 and 3, leaving phase 4")
	_check(skip_boss.current_resistance == 100, "a boss start should still have full resistance")
	skip_boss.apply_environment_damage(100)
	_check(skip_boss.current_phase == 4, "breaking the mandatory phase should jump to phase 4")
	skip_boss.queue_free()
	await _frames(2)

	# Именная связь: Иван — фаза 3; обязательное вступление не пропускается.
	var named_boss: BossScales = BossScene.instantiate() as BossScales
	named_boss.attack_interval = 100.0
	named_boss.phase_attack_intervals = [100.0, 100.0, 100.0, 100.0]
	named_boss.configure_interrogations({"Иван": true})
	root.add_child(named_boss)
	await _frames(2)
	_check(named_boss.current_phase == 1, "phase 1 must stay mandatory")
	_check(named_boss.is_phase_skipped(3), "Ivan's interrogation should skip phase 3")
	_check(not named_boss.is_phase_skipped(1) and not named_boss.is_phase_skipped(2) and not named_boss.is_phase_skipped(4),
		"only the interrogated character's phase should be skipped")
	named_boss.apply_environment_damage(100)
	_check(named_boss.current_phase == 2, "boss should advance from phase 1 to phase 2")
	named_boss.set_interrogation_result("Виктор", true)
	_check(named_boss.current_phase == 4, "late Viktor interrogation should jump to phase 4")
	named_boss.set_interrogation_result("Дмитрий", true)
	_check(named_boss.is_defeated, "skipping the last active phase should finish the fight")
	named_boss.queue_free()
	await _frames(2)

	# Все три допроса пройдены: сражаемся только в обязательной фазе 1.
	var mandatory_boss: BossScales = BossScene.instantiate() as BossScales
	mandatory_boss.attack_interval = 100.0
	mandatory_boss.phase_attack_intervals = [100.0, 100.0, 100.0, 100.0]
	mandatory_boss.configure_interrogations({"Виктор": true, "Иван": true, "Дмитрий": true})
	root.add_child(mandatory_boss)
	await _frames(2)
	_check(mandatory_boss.current_phase == 1 and not mandatory_boss.is_phase_skipped(1),
		"phase 1 cannot be skipped even when every interrogation succeeds")
	mandatory_boss.apply_environment_damage(100)
	_check(mandatory_boss.is_defeated, "all character phases skipped should end the fight after phase 1")
	mandatory_boss.queue_free()
	await _frames(2)

	# Разные расписания: фаза 1 — все четыре атаки по одной, фаза 4 — связки.
	var beat_boss: BossScales = BossScene.instantiate() as BossScales
	beat_boss.attack_interval = 100.0
	beat_boss.phase_attack_intervals = [100.0, 100.0, 100.0, 100.0]
	root.add_child(beat_boss)
	await _frames(2)
	var beats: Array = beat_boss._phase_beats()
	_check(beats.size() == 4 and beats[0].size() == 1,
		"phase 1 should introduce all four attacks one at a time")
	var executed: Array[int] = []
	beat_boss.attack_executed.connect(func(_phase: int, attack: int) -> void:
		executed.append(attack))
	beat_boss._on_attack_timeout()
	_check(executed == [0], "phase 1 first beat should be spikes only")
	beat_boss._on_attack_timeout()
	_check(executed == [0, 1], "phase 1 second beat should be the shockwave")
	beat_boss._on_attack_timeout()
	_check(executed == [0, 1, 2], "phase 1 third beat should be the barrel")
	beat_boss._on_attack_timeout()
	_check(executed == [0, 1, 2, 3], "phase 1 fourth beat should be the container")
	# Два допроса (фазы 2–3): после обязательной фазы 1 остаётся фаза 4.
	beat_boss.set_interrogation_count(2)
	await _frames(2)
	beat_boss.apply_environment_damage(100)
	_check(beat_boss.current_phase == 4, "phase 4 should become active after the mandatory phase")
	var final_beats: Array = beat_boss._phase_beats()
	_check(final_beats.size() == 4 and final_beats[0].size() > 1,
		"phase 4 should use beats with several attacks")
	executed.clear()
	beat_boss._on_attack_timeout()
	await create_timer(0.4).timeout
	_check(executed.size() >= 2, "phase 4 beat should chain several attacks")
	_check(executed[0] == 0 and executed[1] == 1, "phase 4 first beat should chain spikes and shockwave")
	beat_boss.queue_free()
	await _frames(2)

	# Фаза 2 использует шипы и бочки чаще базового цикла и не пересекает зоны атак.
	var phase_boss: BossScales = BossScene.instantiate() as BossScales
	phase_boss.attack_interval = 100.0
	phase_boss.phase_attack_intervals = [100.0, 100.0, 100.0, 100.0]
	root.add_child(phase_boss)
	await _frames(2)
	phase_boss.remove_from_group("boss")
	var base_beats: Array = phase_boss._phase_beats()
	phase_boss.apply_environment_damage(100)
	_check(phase_boss.current_phase == 2, "breaking phase 1 should activate phase 2")
	var phase_two_beats: Array = phase_boss._phase_beats()
	var base_spikes: int = 0
	var base_barrels: int = 0
	for beat in base_beats:
		base_spikes += beat.count(0)
		base_barrels += beat.count(2)
	var phase_two_spikes: int = 0
	var phase_two_barrels: int = 0
	for beat in phase_two_beats:
		phase_two_spikes += beat.count(0)
		phase_two_barrels += beat.count(2)
		_check(not (beat.has(2) and (beat.has(1) or beat.has(3))),
			"phase 2 must not overlap a barrel zone with wave/container telegraphs")
	_check(phase_two_spikes > base_spikes and phase_two_barrels > base_barrels,
		"phase 2 should use spikes and barrels more often than the base cycle")
	phase_boss.queue_free()
	await _frames(2)

	# Диагональ не должна давать скорость выше осевой.
	Input.action_press("move_right")
	await _frames(3)
	var axial_speed: float = absf(player.velocity.x)
	Input.action_release("move_right")
	await _frames(2)
	Input.action_press("move_right")
	Input.action_press("move_up")
	await _frames(3)
	var diagonal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_right")
	Input.action_release("move_up")
	await _frames(2)
	_check(absf(axial_speed - player.speed) < 0.05, "axial movement should use the full configured speed")
	_check(diagonal_speed <= player.speed + 0.05,
		"diagonal movement must not be faster than movement along one axis")

	arena.queue_free()
	await _frames(2)
	print("BOSS TEST: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)
