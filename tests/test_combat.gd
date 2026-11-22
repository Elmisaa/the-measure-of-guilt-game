extends SceneTree
## Smoke test for the enemy shooter and the first firefight:
## bullet.configure layers/colors, IDLE → TELEGRAPH (flash) → SHOOTING (3 enemy bullets) → COOLDOWN,
## enemy bullet damages an open player, cover soaks the burst and breaks after 4 hits (player unharmed),
## 3 player shots (25 dmg) kill a 75 HP enemy, apply_stun interrupts TELEGRAPH.
## godot --headless --path . -s res://tests/test_combat.gd

const PlayerScript: Script = preload("res://scripts/gameplay/player.gd")
const EnemyScript: Script = preload("res://scripts/gameplay/enemy_shooter.gd")
const MeleeScript: Script = preload("res://scripts/gameplay/enemy_melee.gd")
const SAFETY_TIMEOUT: float = 90.0

## 1 = World, 2 = Player, 3 = Enemy, 4 = Cover, 5 = PlayerBullet, 6 = EnemyBullet.
const LAYER_PLAYER_BULLET: int = 16
const MASK_PLAYER_BULLET: int = 1 | 4 | 8
const LAYER_ENEMY_BULLET: int = 32
const MASK_ENEMY_BULLET: int = 1 | 2 | 8
const LAYER_ENEMY: int = 4
const MASK_ENEMY: int = 1 | 16

var _ok: bool = true


func _init() -> void:
	_run.call_deferred()
	create_timer(SAFETY_TIMEOUT).timeout.connect(func() -> void:
		push_error("TEST TIMEOUT")
		quit(2))


func _fail(message: String) -> void:
	push_error("FAIL " + message)
	_ok = false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


## Process frames: input state and deferred frees are flushed by the main loop.
func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _make_floor(world: Node3D) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector3(0, -0.25, 0)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(24, 0.5, 8)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	world.add_child(floor_body)


func _make_cover(world: Node3D, at: Vector3, size: Vector3, destructible: bool) -> Cover:
	var scene: PackedScene = load("res://scenes/gameplay/cover.tscn") as PackedScene
	var cover: Cover = scene.instantiate() as Cover
	cover.max_hp = 4
	cover.is_destructible = destructible
	cover.cover_size = size
	cover.position = at
	world.add_child(cover)
	return cover


func _make_enemy(world: Node3D, at: Vector3, cfg: Dictionary) -> Node3D:
	var scene: PackedScene = load("res://scenes/gameplay/enemy_shooter.tscn") as PackedScene
	var enemy: Node3D = scene.instantiate() as Node3D
	for key: Variant in cfg:
		enemy.set(String(key), cfg[key])
	enemy.position = at
	world.add_child(enemy)
	return enemy


func _make_melee(world: Node3D, at: Vector3, cfg: Dictionary) -> Node3D:
	var scene: PackedScene = load("res://scenes/gameplay/enemy_melee.tscn") as PackedScene
	var enemy: Node3D = scene.instantiate() as Node3D
	for key: Variant in cfg:
		enemy.set(String(key), cfg[key])
	enemy.position = at
	world.add_child(enemy)
	return enemy


func _clear_enemies() -> void:
	for node: Node in get_nodes_in_group("enemies"):
		node.queue_free()


func _clear_bullets(world: Node3D) -> void:
	for child: Node in world.get_children():
		if child is Area3D:
			child.queue_free()


func _first_bullet(world: Node) -> Node3D:
	for child: Node in world.get_children():
		if child is Area3D:
			return child as Node3D
	return null


func _wait_for_state(enemy: Node3D, wanted: int, max_frames: int) -> bool:
	var guard: int = 0
	while int(enemy.get("state")) != wanted and guard < max_frames:
		await _frames(1)
		guard += 1
	return int(enemy.get("state")) == wanted


func _run() -> void:
	# --- configure(): слои, маски, урон и сторона пули --------------------
	var bullet_scene: PackedScene = load("res://scenes/gameplay/bullet.tscn") as PackedScene
	var player_bullet: Node3D = bullet_scene.instantiate() as Node3D
	player_bullet.call("configure", Vector3.RIGHT, false, 25, 22.0)
	_check(player_bullet.collision_layer == LAYER_PLAYER_BULLET, "player bullet layer is not 5: %d" % player_bullet.collision_layer)
	_check(player_bullet.collision_mask == MASK_PLAYER_BULLET, "player bullet mask is not 1|3|4: %d" % player_bullet.collision_mask)
	_check(int(player_bullet.get("damage")) == 25, "player bullet damage was not applied")
	_check(is_equal_approx(float(player_bullet.get("speed")), 22.0), "player bullet speed was not applied")
	_check(not bool(player_bullet.get("is_enemy")), "player bullet is marked as enemy")
	player_bullet.free()
	var enemy_bullet: Node3D = bullet_scene.instantiate() as Node3D
	enemy_bullet.call("configure", Vector3.LEFT, true, 15, 16.0)
	_check(enemy_bullet.collision_layer == LAYER_ENEMY_BULLET, "enemy bullet layer is not 6: %d" % enemy_bullet.collision_layer)
	_check(enemy_bullet.collision_mask == MASK_ENEMY_BULLET, "enemy bullet mask is not 1|2|4: %d" % enemy_bullet.collision_mask)
	_check(int(enemy_bullet.get("damage")) == 15, "enemy bullet damage was not applied")
	_check(is_equal_approx(float(enemy_bullet.get("speed")), 16.0), "enemy bullet speed was not applied")
	_check(bool(enemy_bullet.get("is_enemy")), "enemy bullet is not marked as enemy")
	enemy_bullet.free()

	# --- мир: пол, игрок ---------------------------------------------------
	var world: Node3D = Node3D.new()
	world.name = "CombatWorld"
	root.add_child(world)
	_make_floor(world)
	var player: Player = (load("res://scenes/gameplay/player.tscn") as PackedScene).instantiate() as Player
	world.add_child(player)
	player.global_position = Vector3(0, 0, 0)
	await _frames(4)
	_check(player.get_active_cover() == null, "get_active_cover() is not null outside cover")

	# --- цикл врага: IDLE → TELEGRAPH → SHOOTING (3 пули) → COOLDOWN -------
	var shot_dirs: Array[Vector3] = []
	var bullet_layers: Array[int] = []
	var enemy: Node3D = _make_enemy(world, Vector3(3.5, 0, 0), {})
	var initial_flash: Node3D = enemy.get_node_or_null("Visual/TelegraphFlash") as Node3D
	_check(initial_flash != null, "enemy has no Visual/TelegraphFlash")
	if initial_flash != null:
		_check(not initial_flash.visible, "telegraph flash is visible in IDLE")
	_check(int(enemy.get("state")) == EnemyScript.State.IDLE, "enemy did not start in IDLE")
	enemy.connect("shot_fired", func(direction: Vector3) -> void:
		shot_dirs.append(direction)
		var newest: Area3D = null
		for child: Node in world.get_children():
			if child is Area3D and bool(child.get("is_enemy")):
				newest = child as Area3D
		if newest != null:
			bullet_layers.append(newest.collision_layer))
	await _frames(2)
	_check(enemy.is_in_group("enemies"), "enemy did not join the 'enemies' group")
	_check(enemy.collision_layer == LAYER_ENEMY, "enemy layer is not 3: %d" % enemy.collision_layer)
	_check(enemy.collision_mask == MASK_ENEMY, "enemy mask is not 1|5: %d" % enemy.collision_mask)
	_check(int(enemy.get("health")) == 75, "enemy health is not 75: %d" % int(enemy.get("health")))
	var debug_label: Label3D = enemy.get_node("DebugLabel") as Label3D
	_check(debug_label != null, "enemy has no DebugLabel")
	if debug_label != null:
		_check(debug_label.text.begins_with("HP: 75"), "debug label text is wrong: " + debug_label.text)
	var flash: Node3D = enemy.get_node("Visual/TelegraphFlash") as Node3D
	_check(flash != null, "enemy has no Visual/TelegraphFlash")

	_check(await _wait_for_state(enemy, EnemyScript.State.TELEGRAPH, 120), "enemy did not enter TELEGRAPH")
	if flash != null:
		_check(flash.visible, "telegraph flash is not visible in TELEGRAPH")
	_check(await _wait_for_state(enemy, EnemyScript.State.SHOOTING, 180), "enemy did not enter SHOOTING")
	if flash != null:
		_check(not flash.visible, "telegraph flash stayed visible in SHOOTING")
	_check(await _wait_for_state(enemy, EnemyScript.State.COOLDOWN, 300), "enemy did not enter COOLDOWN")
	_check(shot_dirs.size() == 3, "enemy fired %d bullets instead of 3" % shot_dirs.size())
	_check(bullet_layers.size() == 3, "could not observe 3 enemy bullets (%d)" % bullet_layers.size())
	for layer: int in bullet_layers:
		_check(layer == LAYER_ENEMY_BULLET, "enemy bullet layer is not 6: %d" % layer)
	if debug_label != null:
		_check(debug_label.text.contains("COOLDOWN"), "debug label does not show COOLDOWN: " + debug_label.text)

	# Пуля врага ранит открытого игрока
	await create_timer(0.4).timeout
	_check(player.health < 100, "open player took no damage from enemy bullets: %d" % player.health)
	_check(player.health > 0, "open player died from a single burst")

	# --- укрытие: пули бьют по ящику, игрок не ранен ----------------------
	enemy.queue_free()
	_clear_bullets(world)
	await _frames(2)
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	player.global_position = Vector3(-2.5, 0, 0)
	await _frames(2)
	var crate: Cover = _make_cover(world, Vector3(-2.5, 0, 0.35), Vector3(1.4, 1.05, 1.0), true)
	var crate_hits: Array[int] = [0]
	crate.damaged.connect(func(_hp: int) -> void: crate_hits[0] += 1)
	await _frames(2)
	Input.action_press("combat_cover")
	await _frames(2)
	_check(player.enter_cover(crate), "player did not enter cover")
	await create_timer(0.45).timeout
	_check(player.is_in_cover(), "player is not in cover")
	_check(player.get_active_cover() == crate, "get_active_cover() does not return the crate")
	var hp_before: int = player.health
	var cover_enemy: Node3D = _make_enemy(world, Vector3(3.5, 0, 0), {
		"telegraph_time": 0.1,
		"burst_count": 4,
		"burst_interval": 0.2,
		"cooldown_time": 10.0,
	})
	await create_timer(1.8).timeout
	Input.action_release("combat_cover")
	_check(crate_hits[0] == 4, "crate took %d hits instead of 4" % crate_hits[0])
	_check(not is_instance_valid(crate), "crate survived 4 hits")
	_check(player.health == hp_before, "player took damage through the cover: %d -> %d" % [hp_before, player.health])
	_check(not player.is_in_cover(), "player stayed in cover after the crate broke")
	_check(player.get_active_cover() == null, "get_active_cover() is not null after the crate broke")

	# --- 3 выстрела игрока убивают врага (75 HP) --------------------------
	cover_enemy.queue_free()
	_clear_bullets(world)
	await _frames(2)
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	player.global_position = Vector3(0, 0, 0)
	player.aim_override = Vector3(3.5, 1.25, 0.0)
	await _frames(4)
	var victim: Node3D = _make_enemy(world, Vector3(3.5, 0, 0), {"detection_range": 0.0})
	var died_count: Array[int] = [0]
	victim.connect("died", func(_enemy: Node3D) -> void: died_count[0] += 1)
	await _frames(2)
	for i in 3:
		player.shoot()
		await create_timer(0.25).timeout
	_check(int(victim.get("health")) == 0, "enemy survived 3 player shots: %d HP" % int(victim.get("health")))
	_check(int(victim.get("state")) == EnemyScript.State.DEAD, "enemy is not DEAD after 3 shots")
	_check(died_count[0] == 1, "died signal fired %d times" % died_count[0])
	_check(victim.collision_layer == 0, "dead enemy still has a collision layer: %d" % victim.collision_layer)
	var victim_flash: Node3D = victim.get_node("Visual/TelegraphFlash") as Node3D
	if victim_flash != null:
		_check(not victim_flash.visible, "telegraph flash is visible on a dead enemy")

	# --- apply_stun прерывает TELEGRAPH -----------------------------------
	var stunned_enemy: Node3D = _make_enemy(world, Vector3(3.5, 0, 0), {"telegraph_time": 5.0})
	var stun_flash: Node3D = stunned_enemy.get_node("Visual/TelegraphFlash") as Node3D
	_check(await _wait_for_state(stunned_enemy, EnemyScript.State.TELEGRAPH, 120), "enemy did not enter TELEGRAPH before stun")
	if stun_flash != null:
		_check(stun_flash.visible, "telegraph flash is not visible before stun")
	stunned_enemy.call("apply_stun", 0.8)
	_check(int(stunned_enemy.get("state")) == EnemyScript.State.STUNNED, "apply_stun did not switch to STUNNED")
	if stun_flash != null:
		_check(not stun_flash.visible, "telegraph flash stayed visible after stun")
	await create_timer(0.2).timeout
	_check(int(stunned_enemy.get("state")) == EnemyScript.State.STUNNED, "stun ended too early")
	await create_timer(0.8).timeout
	_check(int(stunned_enemy.get("state")) != EnemyScript.State.STUNNED, "stun did not end")

	# --- выбор цели: пуля летит мимо ножевика в выбранного стрелка --------
	_clear_enemies()
	_clear_bullets(world)
	await _frames(2)
	player.global_position = Vector3(0, 0, 0)
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	player.exit_cover()
	player.aim_override = Vector3(-4.0, 1.25, 0.0)
	await _frames(4)
	_check(player.selected_target == null, "selected target is not null without enemies")
	var target_signals: Array[Node3D] = []
	player.target_changed.connect(func(target: Node3D) -> void: target_signals.append(target))
	var blocker: Node3D = _make_melee(world, Vector3(2.0, 0, 0), {"detection_range": 0.0})
	var far: Node3D = _make_enemy(world, Vector3(4.5, 0, 0), {"detection_range": 0.0})
	await _frames(2)
	player.aim_override = Vector3(4.5, 1.25, 0.0)
	await _frames(6)
	_check(player.selected_target == far, "selected target is not the far shooter")
	_check(target_signals.size() > 0 and target_signals.back() == far, "target_changed did not report the far shooter")
	var marker: Node3D = player.get_node_or_null("TargetMarker") as Node3D
	_check(marker != null, "player has no TargetMarker")
	if marker != null:
		_check(marker.visible, "TargetMarker is hidden with a selected target")
		_check(is_equal_approx(marker.global_position.x, 4.5), "TargetMarker is not on the enemy: %.2f" % marker.global_position.x)
	var far_hp: int = int(far.get("health"))
	var blocker_hp: int = int(blocker.get("health"))
	player.shoot()
	var aimed_bullet: Node3D = _first_bullet(world)
	_check(aimed_bullet != null, "no bullet spawned with a selected target")
	if aimed_bullet != null:
		_check(aimed_bullet.get("intended_target") == far, "bullet did not receive intended_target")
	await create_timer(0.6).timeout
	_check(int(far.get("health")) < far_hp, "selected shooter took no damage: %d" % int(far.get("health")))
	_check(int(blocker.get("health")) == blocker_hp, "melee blocker took damage instead of the selected shooter")

	# --- выбор цели работает в COVER -------------------------------------
	var cover_target: Cover = _make_cover(world, Vector3(0, 0, 0.35), Vector3(1.4, 1.05, 1.0), false)
	await _frames(2)
	Input.action_press("combat_cover")
	await _frames(2)
	_check(player.enter_cover(cover_target), "player did not enter cover for target selection")
	await _frames(6)
	_check(player.state == PlayerScript.State.COVER, "player is not in COVER")
	_check(player.selected_target == far, "target selection broke in COVER")
	Input.action_release("combat_cover")
	player.exit_cover()
	cover_target.queue_free()
	await _frames(2)

	# --- EnemyMelee: CHASE → WINDUP → ATTACK, выбивает игрока из укрытия --
	_clear_enemies()
	_clear_bullets(world)
	await _frames(2)
	player.global_position = Vector3(0, 0, 0)
	player.health = player.max_health
	player.aim_override = Vector3(3.0, 1.25, 0.0)
	var cover_ai: Cover = _make_cover(world, Vector3(0, 0, 0.35), Vector3(1.4, 1.05, 1.0), false)
	await _frames(2)
	var melee_ai: Node3D = _make_melee(world, Vector3(3.0, 0, 0), {})
	await _frames(2)
	_check(melee_ai.is_in_group("enemies"), "EnemyMelee did not join the 'enemies' group")
	_check(melee_ai.collision_layer == LAYER_ENEMY, "melee layer is not 4: %d" % melee_ai.collision_layer)
	_check(melee_ai.collision_mask == MASK_ENEMY, "melee mask is not 1|16: %d" % melee_ai.collision_mask)
	_check(int(melee_ai.get("health")) == 60, "melee health is not 60")
	var melee_label: Label3D = melee_ai.get_node_or_null("DebugLabel") as Label3D
	_check(melee_label != null and melee_label.text.begins_with("MELEE"), "melee debug label is wrong")
	Input.action_press("combat_cover")
	_check(player.enter_cover(cover_ai), "player did not enter cover for the melee attack")
	var telegraphs: Array[int] = [0]
	var attacks: Array[int] = [0]
	melee_ai.connect("melee_telegraphed", func() -> void: telegraphs[0] += 1)
	melee_ai.connect("attacked", func(_target: Node3D) -> void:
		attacks[0] += 1
		Input.action_release("combat_cover"))
	var hp_before_ai: int = player.health
	var guard: int = 0
	while attacks[0] == 0 and guard < 360:
		await _frames(1)
		guard += 1
	_check(telegraphs[0] >= 1, "EnemyMelee never telegraphed")
	_check(attacks[0] >= 1, "EnemyMelee never attacked")
	_check(player.health < hp_before_ai, "melee attack did not damage the player: %d" % player.health)
	_check(not player.is_in_cover(), "melee attack did not knock the player out of cover")
	var ai_state: int = int(melee_ai.get("state"))
	_check(ai_state == MeleeScript.State.ATTACK or ai_state == MeleeScript.State.COOLDOWN, "melee state after attack: %d" % ai_state)
	player.exit_cover()
	cover_ai.queue_free()
	await _frames(2)

	# --- ПКМ: 15 урона, прерывание WINDUP, стан и отбрасывание > 1 м ------
	_clear_enemies()
	_clear_bullets(world)
	await _frames(2)
	player.global_position = Vector3(0, 0, 0)
	player.aim_override = Vector3(3.0, 1.25, 0.0)
	var melee_target: Node3D = _make_melee(world, Vector3(1.5, 0, 0), {})
	await _frames(4)
	_check(await _wait_for_state(melee_target, MeleeScript.State.WINDUP, 240), "EnemyMelee did not enter WINDUP")
	var windup_flash: Node3D = melee_target.get_node_or_null("Visual/WindupFlash") as Node3D
	_check(windup_flash != null and windup_flash.visible, "WindupFlash is not visible in WINDUP")
	var swings: Array[int] = [0]
	player.melee_swung.connect(func(_direction: Vector3) -> void: swings[0] += 1)
	var x_before: float = melee_target.global_position.x
	player.perform_melee()
	_check(swings[0] == 1, "perform_melee did not emit melee_swung")
	_check(int(melee_target.get("health")) == 45, "melee damaged for %d HP instead of 15" % (60 - int(melee_target.get("health"))))
	_check(int(melee_target.get("state")) == MeleeScript.State.STUNNED, "WINDUP was not interrupted by the baton")
	_check(windup_flash == null or not windup_flash.visible, "WindupFlash stayed visible after the counter")
	await create_timer(0.4).timeout
	var delta_x: float = melee_target.global_position.x - x_before
	_check(delta_x > 1.0, "knockback moved the enemy only %.2f m" % delta_x)
	_clear_enemies()
	_clear_bullets(world)
	await _frames(2)

	# --- тестовая арена собирается ----------------------------------------
	var combat_scene: PackedScene = load("res://scenes/gameplay/_test_combat.tscn") as PackedScene
	_check(combat_scene != null, "_test_combat.tscn did not load")
	if combat_scene != null:
		var arena: Node = combat_scene.instantiate()
		_check(arena.get_node_or_null("Player") != null, "arena has no Player")
		_check(arena.get_node_or_null("Melee") != null, "arena has no Melee")
		_check(arena.get_node_or_null("Enemy1") != null, "arena has no Enemy1")
		_check(arena.get_node_or_null("Enemy2") != null, "arena has no Enemy2")
		_check(arena.get_node_or_null("CombatHud") != null, "arena has no CombatHud")
		arena.free()

	print("COMBAT TEST: ", "OK" if _ok else "FAILED")
	world.queue_free()
	await _frames(2)
	quit(0 if _ok else 1)
