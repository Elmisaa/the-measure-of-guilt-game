extends SceneTree
## Smoke test for the 3D (2.5D) combat player: structure, input actions, states, mouse aim,
## shooting in the Z = lane_z plane, reload on a Timer node, combat HUD, covers in depth,
## collision layers and UI blocking.
## godot --headless --path . -s res://tests/test_player.gd

const PlayerScript: Script = preload("res://scripts/gameplay/player.gd")
const SAFETY_TIMEOUT: float = 60.0

## 1 = World, 2 = Player, 3 = Enemy, 4 = Cover, 5 = PlayerBullet, 6 = EnemyBullet, 7 = CoverZone.
const LAYER_PLAYER: int = 2
const MASK_PLAYER: int = 1 | 32  # World + EnemyBullet
const LAYER_PLAYER_BULLET: int = 16
const MASK_PLAYER_BULLET: int = 1 | 4 | 8  # World + Enemy + Cover
const COVER_LAYER: int = 8
const COVER_ZONE_LAYER: int = 64
const COVER_ZONE_MASK: int = 2

var _ok: bool = true
var _died_count: int = 0
var _blocked_hits: int = 0


func _init() -> void:
	_run.call_deferred()
	create_timer(SAFETY_TIMEOUT).timeout.connect(func() -> void:
		push_error("TEST TIMEOUT")
		quit(2))


func _fail(message: String) -> void:
	push_error("FAIL " + message)
	_ok = false


## Process frames: input state is flushed by the main loop, not by physics_frame.
func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _key(keycode: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse(button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _click() -> void:
	_mouse(MOUSE_BUTTON_LEFT, true)
	_mouse(MOUSE_BUTTON_LEFT, false)


func _bullet_count(world: Node) -> int:
	var count: int = 0
	for child in world.get_children():
		if child is Area3D and not child is Cover:
			count += 1
	return count


func _first_bullet(world: Node) -> Node3D:
	for child in world.get_children():
		if child is Area3D and not child is Cover:
			return child as Node3D
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _label(root_node: Node, label_name: String) -> Label:
	return root_node.find_child(label_name, true, false) as Label


## Пол: верхняя грань на Y = 0, слой 1 (World).
func _make_floor(world: Node3D) -> StaticBody3D:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector3(0, -0.25, 0)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(40, 0.5, 8)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	world.add_child(floor_body)
	return floor_body


func _make_cover(world: Node3D, cover_name: String, at: Vector3, size: Vector3, destructible: bool) -> Cover:
	var scene: PackedScene = load("res://scenes/gameplay/cover.tscn")
	var cover: Cover = scene.instantiate() as Cover
	cover.name = cover_name
	cover.max_hp = 4
	cover.is_destructible = destructible
	cover.cover_size = size
	cover.position = at
	world.add_child(cover)
	return cover


func _run() -> void:
	var world: Node3D = Node3D.new()
	world.name = "World"
	root.add_child(world)
	_make_floor(world)
	var scene: PackedScene = load("res://scenes/gameplay/player.tscn")
	var player: CharacterBody3D = scene.instantiate() as CharacterBody3D
	world.add_child(player)
	player.global_position = Vector3(0, 0, 0)

	# Структура сцены
	_check(player is CharacterBody3D, "player is not a CharacterBody3D")
	_check(player.is_in_group("player"), "player did not join the 'player' group")
	_check(player.get_node_or_null("Visual/Body") is MeshInstance3D, "no Visual/Body MeshInstance3D")
	_check(player.get_node_or_null("Visual/Barrel") is MeshInstance3D, "no Visual/Barrel MeshInstance3D")
	_check(player.get_node_or_null("AimMarker") is MeshInstance3D, "no 3D AimMarker")
	var shape_node: CollisionShape3D = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_check(shape_node != null, "no CollisionShape3D")
	if shape_node != null:
		var capsule: CapsuleShape3D = shape_node.shape as CapsuleShape3D
		_check(capsule != null, "collision shape is not a CapsuleShape3D")
		if capsule != null:
			_check(is_equal_approx(capsule.height, 1.7), "capsule height is not 1.7: %.2f" % capsule.height)
		_check(is_equal_approx(shape_node.position.y, 0.85), "collision center is not at Y = 0.85")
	var body_mesh: MeshInstance3D = player.get_node_or_null("Visual/Body") as MeshInstance3D
	if body_mesh != null and body_mesh.mesh is BoxMesh:
		var box: BoxMesh = body_mesh.mesh as BoxMesh
		_check((box.size - Vector3(0.5, 1.7, 0.15)).length() < 0.001, "body box is not 0.5 x 1.7 x 0.15: %s" % str(box.size))

	# Параметры и слои
	_check(is_equal_approx(player.speed, 3.5), "speed default is not 3.5: %.2f" % player.speed)
	_check(is_equal_approx(player.lane_z, 0.0), "lane_z default is not 0")
	_check(player.max_health == 100, "max_health default is not 100")
	_check(player.health == 100, "health is not initialized to max")
	_check(player.collision_layer == LAYER_PLAYER, "player layer is not 2: %d" % player.collision_layer)
	_check(player.collision_mask == MASK_PLAYER, "player mask is not 1|6: %d" % player.collision_mask)

	# Экшены боя зарегистрированы в рантайме
	for action: String in ["move_left", "move_right", "combat_shoot", "combat_melee", "combat_reload", "combat_cover", "combat_taser", "combat_flashlight"]:
		_check(InputMap.has_action(action), "action not registered: " + action)

	var visual: Node3D = player.get_node("Visual") as Node3D
	var marker: Node3D = player.get_node("AimMarker") as Node3D
	var reload_timer: Timer = player.get_node("ReloadTimer") as Timer
	player.died.connect(func() -> void: _died_count += 1)

	# Боевой HUD сам находит игрока и сразу показывает его значения
	var hud: CombatHud = (load("res://scenes/gameplay/combat_hud.tscn") as PackedScene).instantiate() as CombatHud
	root.add_child(hud)
	await _frames(4)
	_check(hud.target_player() == player, "combat HUD did not find the player in the group")
	var hp_text: Label = _label(hud, "HpText")
	var ammo_text: Label = _label(hud, "AmmoText")
	var state_text: Label = _label(hud, "StateText")
	var reload_text: Label = _label(hud, "ReloadText")
	var hp_bar: ProgressBar = hud.find_child("HpBar", true, false) as ProgressBar
	_check(hp_text != null and ammo_text != null and state_text != null, "combat HUD labels are missing")
	if hp_text != null:
		_check(hp_text.text.contains("100 / 100"), "HUD HP text is wrong: " + hp_text.text)
	if ammo_text != null:
		_check(ammo_text.text.begins_with("GLOCK 19:"), "HUD weapon name is wrong: " + ammo_text.text)
		_check(ammo_text.text.contains("17 / 17"), "HUD ammo text is wrong: " + ammo_text.text)
	if state_text != null:
		_check(state_text.text.contains("IDLE"), "HUD state text is wrong: " + state_text.text)
	if hp_bar != null:
		_check(hp_bar.max_value == 100.0 and hp_bar.value == 100.0, "HUD HP bar is not at 100")

	# Стоит на полу, ноги на Y = 0
	await create_timer(0.4).timeout
	_check(player.is_on_floor(), "player did not land on the floor")
	_check(absf(player.global_position.y) < 0.06, "feet are not at Y = 0: %.3f" % player.global_position.y)
	_check(player.state == PlayerScript.State.IDLE, "expected IDLE, got %d" % player.state)

	# RUN влево: A
	_key(KEY_A, true)
	await _frames(6)
	_check(player.state == PlayerScript.State.RUN, "A did not switch to RUN")
	_check(player.velocity.x < 0.0, "A did not move left")
	_key(KEY_A, false)
	await _frames(6)
	_check(player.state == PlayerScript.State.IDLE, "release A did not return to IDLE")

	# RUN вправо: D, глубина Z не уезжает
	var start_x: float = player.global_position.x
	_key(KEY_D, true)
	await _frames(12)
	_check(player.state == PlayerScript.State.RUN, "D did not switch to RUN")
	_check(player.global_position.x > start_x + 0.05, "body did not move right: %.2f -> %.2f" % [start_x, player.global_position.x])
	_check(is_equal_approx(player.global_position.z, player.lane_z), "player left the lane: z = %.3f" % player.global_position.z)
	_key(KEY_D, false)
	await _frames(6)

	# Прицел: точка задаётся через aim_override (в игре её даёт луч Camera3D по курсору;
	# в headless курсор мыши не совпадает с координатами viewport).
	player.aim_override = Vector3(4.0, 0.9, 0.0)
	await _frames(4)
	_check(is_equal_approx(visual.scale.x, 1.0), "visual did not face the aim point on the right: %.1f" % visual.scale.x)
	_check(is_equal_approx(marker.global_position.x, 4.0), "aim marker did not follow the aim point: %.2f" % marker.global_position.x)
	_check(is_equal_approx(marker.global_position.z, player.lane_z), "aim marker left the lane: z = %.3f" % marker.global_position.z)
	player.aim_override = Vector3(-4.0, 0.9, 0.0)
	await _frames(4)
	_check(is_equal_approx(visual.scale.x, -1.0), "visual did not face the aim point on the left: %.1f" % visual.scale.x)
	# Без камеры и без override фоллбэк отдаёт точку в плоскости lane_z
	player.aim_override = null
	await _frames(2)
	var fallback: Vector3 = player.aim_point()
	_check(is_equal_approx(fallback.z, player.lane_z), "fallback aim point is not in the lane: z = %.3f" % fallback.z)
	_check(is_finite(fallback.x) and is_finite(fallback.y), "fallback aim point is not finite")
	# С камерой точка прицела считается лучом до плоскости Z = lane_z (не падает)
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.8, 7.5), Vector3(0, 0.9, 0))
	camera.current = true
	await _frames(2)
	var ray_point: Vector3 = player.aim_point()
	_check(is_equal_approx(ray_point.z, player.lane_z), "camera aim point is not in the lane: z = %.3f" % ray_point.z)
	_check(is_finite(ray_point.x) and is_finite(ray_point.y), "camera aim point is not finite")
	camera.queue_free()
	player.aim_override = Vector3(4.0, 1.25, 0.0)
	await _frames(2)

	# Стрелки работают так же, как A/D
	_key(KEY_RIGHT, true)
	await _frames(4)
	_check(player.state == PlayerScript.State.RUN, "RIGHT arrow did not switch to RUN")
	_key(KEY_RIGHT, false)
	_key(KEY_LEFT, true)
	await _frames(4)
	_check(player.state == PlayerScript.State.RUN, "LEFT arrow did not switch to RUN")
	_key(KEY_LEFT, false)
	await _frames(6)
	_check(player.state == PlayerScript.State.IDLE, "release LEFT arrow did not return to IDLE")

	# ПКМ больше не включает прицел: это заготовка ближнего боя
	var melee_dirs: Array[Vector3] = []
	player.melee_swung.connect(func(direction: Vector3) -> void: melee_dirs.append(direction))
	_mouse(MOUSE_BUTTON_RIGHT, true)
	await _frames(3)
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await _frames(2)
	_check(melee_dirs.size() == 1, "RMB did not emit melee_swung (%d)" % melee_dirs.size())
	_check(player.state == PlayerScript.State.IDLE, "RMB changed the state")
	_check(player.ammo_current == 17, "RMB spent ammo")
	_check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), "RMB stuck in Input")

	# Фонарь (F)
	_key(KEY_F, true)
	await _frames(2)
	_key(KEY_F, false)
	await _frames(2)
	_check(player.flashlight_on, "F did not toggle the flashlight")
	player.toggle_flashlight()

	# Стрельба: ЛКМ тратит патрон, спавнит 3D-пулю на высоте груди и испускает shoot_fired
	_check(player.ammo_current == 17, "ammo_current default is not 17")
	var directions: Array[Vector3] = []
	player.shoot_fired.connect(func(direction: Vector3) -> void: directions.append(direction))
	_click()
	await _frames(4)
	_check(player.ammo_current == 16, "shot did not spend ammo")
	_check(directions.size() == 1, "shoot_fired emitted %d times" % directions.size())
	_check(_bullet_count(world) == 1, "bullet was not created")
	if ammo_text != null:
		_check(ammo_text.text.contains("16 / 17"), "HUD ammo did not update: " + ammo_text.text)
	var bullet: Node3D = _first_bullet(world)
	if bullet != null:
		_check(bullet is Area3D, "bullet is not an Area3D")
		_check(is_equal_approx(float(bullet.get("speed")), 22.0), "bullet speed is not 22")
		_check(int(bullet.get("damage")) == 25, "bullet damage is not 25")
		_check(bullet.collision_layer == LAYER_PLAYER_BULLET, "bullet layer is not 5: %d" % bullet.collision_layer)
		_check(bullet.collision_mask == MASK_PLAYER_BULLET, "bullet mask is not 1|3|4: %d" % bullet.collision_mask)
		_check(is_equal_approx(bullet.global_position.z, player.lane_z), "bullet left the Z = lane_z plane")
		_check(absf(bullet.global_position.y - 1.25) < 0.05, "bullet is not spawned at chest height: %.2f" % bullet.global_position.y)
		var bullet_start: Vector3 = bullet.global_position
		await _frames(4)
		_check(bullet.global_position.distance_to(bullet_start) > 0.05, "bullet does not fly")
	if directions.size() > 0:
		_check(is_equal_approx(directions[0].length(), 1.0), "shoot direction is not normalized")
		_check(is_zero_approx(directions[0].z), "shoot direction has a Z component")

	# Пустой магазин: выстрела и пули нет
	player.ammo_current = 0
	player.ammo_changed.emit(player.ammo_current, player.ammo_max)
	_click()
	await _frames(4)
	_check(player.ammo_current == 0, "shot fired with empty ammo")
	_check(_bullet_count(world) == 1, "bullet spawned with empty ammo")
	if ammo_text != null:
		_check(ammo_text.text.contains("0 / 17"), "HUD ammo (empty) did not update: " + ammo_text.text)
		_check(ammo_text.get_theme_color("font_color").r > 0.9, "HUD ammo is not red at zero")

	# Перезарядка на узле Timer: 1.5 с нельзя стрелять, потом полный магазин
	_check(reload_timer.one_shot, "ReloadTimer is not one_shot")
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(3)
	_check(player.is_reloading, "R did not start reload")
	_check(reload_timer.time_left > 0.0, "ReloadTimer was not started")
	if reload_text != null:
		_check(reload_text.visible, "HUD does not show RELOADING")
	_click()
	await _frames(4)
	_check(player.ammo_current == 0, "shot during reload spent ammo")
	await create_timer(1.6).timeout
	_check(not player.is_reloading, "reload did not finish")
	_check(player.ammo_current == 17, "reload did not refill: %d" % player.ammo_current)
	if reload_text != null:
		_check(not reload_text.visible, "HUD still shows RELOADING")
	if ammo_text != null:
		_check(ammo_text.text.contains("17 / 17"), "HUD ammo after reload is wrong: " + ammo_text.text)

	# Пуля удаляется сама (lifetime 1.5 с)
	await create_timer(1.7).timeout
	_check(_bullet_count(world) == 0, "bullet did not free itself")

	# Блокировка от UI: при открытой истории игрок не ходит и не стреляет
	var hud_autoload: Node = root.get_node("Hud")
	hud_autoload.toggle_history()
	await _frames(4)
	_check(hud_autoload.is_blocking(), "Hud.is_blocking() is false with history open")
	var blocked_x: float = player.global_position.x
	_key(KEY_D, true)
	await _frames(8)
	_check(absf(player.global_position.x - blocked_x) < 0.01, "player moved while the UI was blocking")
	var ammo_before: int = player.ammo_current
	_click()
	await _frames(4)
	_check(player.ammo_current == ammo_before, "player shot while the UI was blocking")
	_key(KEY_D, false)
	hud_autoload.close_history()
	await _frames(4)
	_check(not hud_autoload.is_blocking(), "Hud.is_blocking() stayed true after closing the history")

	# --- укрытия ---------------------------------------------------------
	var crate: Cover = _make_cover(world, "Crate", Vector3(-2.5, 0, 0.35), Vector3(1.4, 1.05, 1.0), true)
	var column: Cover = _make_cover(world, "Column", Vector3(2.5, 0, 0.35), Vector3(0.9, 2.2, 0.9), false)
	await _frames(2)
	_check(crate.collision_layer == COVER_LAYER, "cover layer is not 4: %d" % crate.collision_layer)
	_check(crate.collision_mask == 0, "cover mask is not 0: %d" % crate.collision_mask)
	var zone: Area3D = crate.get_node("CoverZone") as Area3D
	_check(zone.collision_layer == COVER_ZONE_LAYER, "cover zone layer is not 7: %d" % zone.collision_layer)
	_check(zone.collision_mask == COVER_ZONE_MASK, "cover zone mask is not 2: %d" % zone.collision_mask)
	_check(crate.hp == 4, "cover hp was not set from max_hp")
	column.hit_blocked.connect(func() -> void: _blocked_hits += 1)

	# 4 попадания разрушают деревянный ящик (сначала целимся сверху вниз по ящику)
	player.global_position = Vector3(-1.0, 0, 0)
	player.aim_override = Vector3(-2.5, 0.55, 0.0)
	await create_timer(0.1).timeout
	for i in 4:
		_click()
		await create_timer(0.15).timeout
		if i < 3:
			_check(crate.hp == 3 - i, "crate hp after hit %d is %d, expected %d" % [i + 1, crate.hp, 3 - i])
	_check(not is_instance_valid(crate), "crate is not destroyed after 4 hits")

	# Вход в COVER: зажимаем S рядом с укрытием — шаг вглубь и присед
	var crate2: Cover = _make_cover(world, "Crate2", Vector3(-2.5, 0, 0.35), Vector3(1.4, 1.05, 1.0), true)
	await _frames(2)
	player.global_position = Vector3(-1.55, 0, 0)
	await create_timer(0.15).timeout
	_check(player.has_cover_nearby(), "player does not see the nearby cover")
	_key(KEY_S, true)
	await create_timer(0.4).timeout
	_check(player.state == PlayerScript.State.COVER, "S near cover did not switch to COVER (%d)" % player.state)
	_check(player.is_in_cover(), "is_in_cover() is false in COVER")
	_check(player.global_position.z < -0.4, "player did not step into depth: z = %.2f" % player.global_position.z)
	_check(visual.scale.y < 0.75, "player did not crouch in cover: scale.y = %.2f" % visual.scale.y)
	if state_text != null:
		_check(state_text.text.contains("COVER"), "HUD state is not COVER: " + state_text.text)

	# В COVER: нельзя ходить по X и стрелять, но прицел двигается
	var cover_ammo: int = player.ammo_current
	var cover_x: float = player.global_position.x
	var cover_bullets: int = _bullet_count(world)
	player.aim_override = Vector3(3.0, 1.6, 0.0)
	await _frames(4)
	_key(KEY_D, true)
	await _frames(6)
	_check(absf(player.global_position.x - cover_x) < 0.01, "player walked in COVER")
	_click()
	await _frames(4)
	_check(player.ammo_current == cover_ammo, "player shot in COVER")
	_check(_bullet_count(world) == cover_bullets, "bullet spawned in COVER")
	_check(is_equal_approx(marker.global_position.x, 3.0), "aim marker froze in COVER: %.2f" % marker.global_position.x)
	_key(KEY_D, false)

	# Укрытие разрушено, пока игрок за ним: COVER сразу прерывается
	crate2.take_hit(4)
	await _frames(4)
	_check(not is_instance_valid(crate2), "crate2 survived 4 hits")
	_check(not player.is_in_cover(), "player stayed in cover after it was destroyed")
	_check(player.state == PlayerScript.State.IDLE, "state is not IDLE after the cover broke (%d)" % player.state)

	# Отпустили S: возврат на lane_z и полный рост
	_key(KEY_S, false)
	await create_timer(0.4).timeout
	_check(absf(player.global_position.z - player.lane_z) < 0.05, "player did not return to the lane: z = %.2f" % player.global_position.z)
	_check(visual.scale.y > 0.95, "player did not stand up: scale.y = %.2f" % visual.scale.y)

	# Неразрушаемое укрытие не ломается и блокирует пулю
	player.global_position = Vector3(1.2, 0, 0)
	player.aim_override = Vector3(2.5, 1.2, 0.0)
	await create_timer(0.1).timeout
	_click()
	await create_timer(0.2).timeout
	_check(_blocked_hits == 1, "indestructible cover did not report a blocked hit (%d)" % _blocked_hits)
	_check(is_instance_valid(column), "indestructible cover was destroyed")
	_check(column.hp == 4, "indestructible cover lost hp: %d" % column.hp)
	_check(_bullet_count(world) == 0, "bullet did not die on the cover")

	# Оглушение прерывает перезарядку
	player.ammo_current = 5
	player.reload()
	await _frames(2)
	_check(player.is_reloading, "reload (stun case) did not start")
	player.set_stunned(true)
	_check(not player.is_reloading, "stun did not cancel the reload")
	_check(reload_timer.time_left == 0.0, "ReloadTimer was not stopped on stun")
	player.set_stunned(false)

	# Урон и смерть
	player.take_damage(40)
	_check(player.health == 60, "take_damage: expected 60, got %d" % player.health)
	_check(_died_count == 0, "died fired too early")
	if hp_text != null:
		_check(hp_text.text.contains("60 / 100"), "HUD HP text did not update: " + hp_text.text)

	# Смерть во время перезарядки: таймер останавливаем, патроны не выдаём
	player.reload()
	await _frames(2)
	_check(player.is_reloading, "reload (death case) did not start")
	player.take_damage(60)
	_check(player.health == 0, "health did not reach 0")
	_check(_died_count == 1, "died fired %d times" % _died_count)
	_check(player.state == PlayerScript.State.DEAD, "state is not DEAD after death")
	_check(not player.is_reloading, "death did not cancel the reload")
	_check(reload_timer.time_left == 0.0, "ReloadTimer was not stopped on death")
	if state_text != null:
		_check(state_text.text.contains("DEAD"), "HUD state is not DEAD: " + state_text.text)
	if hp_bar != null:
		_check(hp_bar.value == 0.0, "HUD HP bar is not empty after death")

	# Мёртвый не стреляет и не ходит
	var dead_x: float = player.global_position.x
	_click()
	_key(KEY_D, true)
	await _frames(8)
	_key(KEY_D, false)
	_check(absf(player.global_position.x - dead_x) < 0.01, "dead player moved")
	_check(player.ammo_current == 5, "dead player shot")

	print("PLAYER TEST: ", "OK" if _ok else "FAILED")
	hud.queue_free()
	player.queue_free()
	world.queue_free()
	await _frames(2)
	quit(0 if _ok else 1)
