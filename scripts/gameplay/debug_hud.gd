extends Label

@export var player_path: NodePath = ^"../Player"
@export var hint_text: String = "A/D — ходьба, ЛКМ — выстрел, ПКМ — ближний бой, R — перезарядка, Q — тазер, S/Space — укрытие, F — фонарь"

const STATE_NAMES: Array[String] = ["IDLE", "RUN", "COVER", "DEAD"]


func _process(_delta: float) -> void:
	var player: Player = get_node_or_null(player_path) as Player
	if player == null:
		text = "Player: —\n" + hint_text
		return
	var state_name: String = STATE_NAMES[player.state] if player.state < STATE_NAMES.size() else "?"
	var reload: String = "  [RELOADING]" if player.is_reloading else ""
	var flags: String = ""
	if player.in_cover:
		flags += " [COVER]"
	if player.stunned:
		flags += " [STUN]"
	if player.flashlight_on:
		flags += " [LIGHT]"
	text = "State: %s  HP: %d/%d  Ammo: %d/%d%s%s\n%s" % [
		state_name,
		player.health,
		player.max_health,
		player.ammo_current,
		player.ammo_max,
		flags,
		reload,
		hint_text,
	]
