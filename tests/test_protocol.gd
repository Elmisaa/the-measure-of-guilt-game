extends SceneTree

const PlayerScript: Script = preload("res://scripts/gameplay/player.gd")
const EnemyScript: Script = preload("res://scripts/gameplay/enemy_shooter.gd")
const MeleeScript: Script = preload("res://scripts/gameplay/enemy_melee.gd")
const SAFETY_TIMEOUT: float = 60.0

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


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _make_floor(world: Node3D) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.position = Vector3(0, -0.25, 0)
	floor_body.collision_layer = 1
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(40, 0.5, 8)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	world.add_child(floor_body)


func _make_enemy(world: Node3D, at: Vector3, cfg: Dictionary) -> Node3D:
	var enemy: Node3D = (load("res://scenes/gameplay/enemy_shooter.tscn") as PackedScene).instantiate() as Node3D
	for key: Variant in cfg:
		enemy.set(String(key), cfg[key])
	enemy.position = at
	world.add_child(enemy)
	return enemy


func _make_melee(world: Node3D, at: Vector3, cfg: Dictionary) -> Node3D:
	var enemy: Node3D = (load("res://scenes/gameplay/enemy_melee.tscn") as PackedScene).instantiate() as Node3D
	for key: Variant in cfg:
		enemy.set(String(key), cfg[key])
	enemy.position = at
	world.add_child(enemy)
	return enemy


func _clear_enemies() -> void:
	for node: Node in get_nodes_in_group("enemies"):
		node.queue_free()


func _run() -> void:
	var world: Node3D = Node3D.new()
	world.name = "ProtocolWorld"
	root.add_child(world)
	_make_floor(world)
	var player: Player = (load("res://scenes/gameplay/player.tscn") as PackedScene).instantiate() as Player
	world.add_child(player)
	player.global_position = Vector3(0, 0, 0)
	var hud: CombatHud = (load("res://scenes/gameplay/combat_hud.tscn") as PackedScene).instantiate() as CombatHud
	root.add_child(hud)
	await _frames(6)

	var tracker: ProtocolTracker = hud.get_node("ProtocolTracker") as ProtocolTracker
	_check(tracker != null, "HUD has no ProtocolTracker node")
	var taser_text: Label = hud.find_child("TaserText", true, false) as Label
	var protocol_text: Label = hud.find_child("ProtocolText", true, false) as Label
	_check(taser_text != null and protocol_text != null, "HUD has no TaserText/ProtocolText")
	if taser_text != null:
		_check(taser_text.text == "TASER: 3 / 3", "initial taser HUD line is wrong: " + taser_text.text)
	if protocol_text != null:
		_check(protocol_text.text == "PROTOCOL: 0", "initial protocol HUD line is wrong: " + protocol_text.text)

	var reasons: Array[String] = []
	var deltas: Array[int] = []
	tracker.score_changed.connect(func(new_score: int, delta: int, reason: String) -> void:
		reasons.append(reason)
		deltas.append(delta)
		if protocol_text != null:
			_check(protocol_text.text == "PROTOCOL: %d" % new_score, "protocol HUD line did not follow the score")
	)

	_check(player.get_node_or_null("TaserCooldownTimer") is Timer, "no TaserCooldownTimer node")
	_check(player.get_node_or_null("TaserBeam") is MeshInstance3D, "no TaserBeam node")
	_check(player.get_node_or_null("ShoutLabel") is Label3D, "no ShoutLabel node")
	_check(player.taser_charges_max == 3, "wrong taser charge default")
	player.aim_override = Vector3(5.0, 1.25, 0.0)
	await _frames(4)
	var target: Node3D = _make_enemy(world, Vector3(3.0, 0, 0), {"detection_range": 0.0})
	await _frames(2)
	var fired: Array[Node3D] = []
	player.taser_fired.connect(func(hit: Node3D) -> void: fired.append(hit))
	var beam: MeshInstance3D = player.get_node("TaserBeam") as MeshInstance3D
	var cooldown: Timer = player.get_node("TaserCooldownTimer") as Timer
	player.taser()
	_check(player.taser_charges == 2, "taser did not spend a charge: %d" % player.taser_charges)
	_check(fired.size() == 1 and fired[0] == target, "taser_fired did not report the target")
	_check(int(target.get("state")) == EnemyScript.State.STUNNED, "taser did not stun the enemy")
	_check(beam.visible, "TaserBeam is not visible after the shot")
	_check(cooldown.time_left > 0.0, "TaserCooldownTimer was not started")
	_check(reasons.has("TASER STUN +50"), "no TASER STUN +50 score reason")
	if taser_text != null:
		_check(taser_text.text == "TASER: 2 / 3", "taser HUD line did not update: " + taser_text.text)
	player.taser()
	_check(player.taser_charges == 2, "taser ignored its cooldown")

	target.queue_free()
	await create_timer(1.3).timeout
	await _frames(2)
	_check(cooldown.is_stopped(), "TaserCooldownTimer did not finish")
	player.taser()
	_check(player.taser_charges == 2, "taser spent a charge without a target")

	var shout: Label3D = player.get_node("ShoutLabel") as Label3D
	var yielder: Node3D = _make_enemy(world, Vector3(1.2, 0, 0), {
		"detection_range": 0.0, "surrenders_on_warning": true,
	})
	await _frames(2)
	var surrendered_seen: Array[Node3D] = []
	yielder.connect("surrendered", func(enemy: Node3D) -> void: surrendered_seen.append(enemy))
	player.interact()
	_check(bool(yielder.call("is_surrendered")), "E order did not make the enemy surrender")
	_check(surrendered_seen.size() == 1, "surrendered signal was not emitted")
	_check((yielder.get_node("DebugLabel") as Label3D).text == "SURRENDERED [E - ARREST]", "surrender label is wrong")
	_check(shout.visible and shout.text == "NYPD! DROP IT!", "shout label does not show the order")
	_check(reasons.has("SURRENDER +50"), "no SURRENDER +50 score reason")
	var score_before_arrest: int = tracker.score
	player.interact()
	_check(bool(yielder.call("is_arrested")), "E at close range did not arrest the enemy")
	_check((yielder.get_node("DebugLabel") as Label3D).text == "ARRESTED", "arrest label is wrong")
	_check(yielder.collision_layer == 0 and yielder.collision_mask == 0, "arrested enemy still collides")
	_check(shout.text == "ARRESTED!", "shout label does not show the arrest")
	_check(tracker.score == score_before_arrest + 150, "arrest did not add 150 points")
	_check(reasons.has("ARREST +150"), "no ARREST +150 score reason")
	_clear_enemies()
	await _frames(2)

	var last: Node3D = _make_enemy(world, Vector3(5.0, 0, 0), {"detection_range": 0.0})
	await _frames(2)
	player.interact()
	_check(bool(last.get("warned")), "order did not warn the enemy")
	_check(bool(last.call("is_surrendered")), "last standing enemy did not surrender")

	var violations: Array[String] = []
	last.connect("protocol_violation", func(reason: String, _delta: int) -> void: violations.append(reason))
	last.call("take_damage", 5, true)
	_check(violations.has("SHOT_SURRENDERED"), "shooting a surrendered enemy is not a violation")
	_check(reasons.has("SHOT SURRENDERED -250"), "no -250 score reason for shooting a surrendered enemy")
	_clear_enemies()
	await _frames(2)

	var fresh: Node3D = _make_enemy(world, Vector3(6.0, 0, 0), {
		"max_health": 100, "detection_range": 0.0,
	})
	await _frames(2)
	var fresh_violations: Array[String] = []
	fresh.connect("protocol_violation", func(reason: String, _delta: int) -> void: fresh_violations.append(reason))
	fresh.call("take_damage", 10, true)
	_check(fresh_violations.has("NO_WARNING"), "shooting without a warning is not a violation")
	_check(not bool(fresh.get("warned")), "harmless hit warned the enemy too early")
	_check(reasons.has("NO WARNING -100"), "no -100 score reason for an unwarned shot")
	_check(not bool(fresh.call("is_surrendered")), "enemy surrendered too early")
	fresh.call("take_damage", 50, true)
	_check(bool(fresh.call("is_surrendered")), "enemy did not surrender at low HP")
	_check(bool(fresh.get("warned")), "surrender at low HP must set warned")
	_clear_enemies()
	await _frames(2)

	var melee: Node3D = _make_melee(world, Vector3(4.0, 0, 0), {"detection_range": 0.0})
	await _frames(2)
	var melee_surrendered: Array[Node3D] = []
	melee.connect("surrendered", func(enemy: Node3D) -> void: melee_surrendered.append(enemy))
	_check(not bool(melee.call("is_neutralized")), "melee enemy is neutralized from the start")
	_check(bool(melee.call("receive_surrender_order", true)), "melee enemy did not surrender as last standing")
	_check(melee_surrendered.size() == 1, "melee surrendered signal was not emitted")
	_check((melee.get_node("DebugLabel") as Label3D).text == "SURRENDERED [E - ARREST]", "melee surrender label is wrong")
	_check(bool(melee.call("arrest")), "melee enemy was not arrested")
	_check(bool(melee.call("is_neutralized")), "arrested melee enemy is not neutralized")
	_check(melee.collision_layer == 0, "arrested melee enemy still collides")
	_clear_enemies()
	await _frames(2)

	if protocol_text != null:
		_check(protocol_text.text == "PROTOCOL: %d" % tracker.score, "final protocol HUD line is wrong")
	_check(deltas.has(50) and deltas.has(150) and deltas.has(-100) and deltas.has(-250), "score deltas are incomplete")

	print("PROTOCOL TEST: ", "OK" if _ok else "FAILED")
	hud.queue_free()
	player.queue_free()
	world.queue_free()
	await _frames(2)
	quit(0 if _ok else 1)
