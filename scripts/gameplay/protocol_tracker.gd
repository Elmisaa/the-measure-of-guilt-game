class_name ProtocolTracker
extends Node
## Лёгкий счётчик полицейского протокола. Висит отдельным узлом (обычно под CombatHud),
## сам находит игрока и всех врагов группы "enemies" — в том числе появившихся позже.
## Очки: тазер +50, сдача +50, арест +150; штрафы приходят от врагов сигналом protocol_violation.

signal score_changed(new_score: int, delta: int, reason: String)

const TASER_POINTS: int = 50
const SURRENDER_POINTS: int = 50
const ARREST_POINTS: int = 150
## Коды нарушений от врагов → читаемые подписи для HUD/тестов.
const VIOLATION_LABELS: Dictionary = {
	"NO_WARNING": "NO WARNING",
	"SHOT_SURRENDERED": "SHOT SURRENDERED",
}

var score: int = 0

var _player: Player = null
## Ключ — instance id врага, значение — сам узел (чтобы не терять связи при смене группы).
var _enemies: Dictionary = {}


func _ready() -> void:
	_rebind()


func _process(_delta: float) -> void:
	_rebind()


## Подписка на игрока и на всех врагов; отписываемся от исчезнувших из группы.
func _rebind() -> void:
	if not is_inside_tree():
		return
	var found_player: Player = get_tree().get_first_node_in_group("player") as Player
	if found_player != null and found_player != _player:
		_bind_player(found_player)
	var current: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		var id: int = node.get_instance_id()
		current[id] = true
		if not _enemies.has(id):
			_enemies[id] = node
			_bind_enemy(node)
	for id: int in _enemies.keys():
		if not current.has(id):
			_enemies.erase(id)


func _bind_player(node: Player) -> void:
	if is_instance_valid(_player):
		if _player.taser_fired.is_connected(_on_taser_fired):
			_player.taser_fired.disconnect(_on_taser_fired)
	_player = node
	if not node.taser_fired.is_connected(_on_taser_fired):
		node.taser_fired.connect(_on_taser_fired)


func _bind_enemy(enemy: Node) -> void:
	# No more surrender/protocol_violation signals in simplified combat
	pass


func _on_taser_fired(_target: Node3D) -> void:
	_add_score(TASER_POINTS, "TASER STUN +50")


func _add_score(delta: int, reason: String) -> void:
	score += delta
	score_changed.emit(score, delta, reason)


## Сброс между сценами/раундами (сигнал не шлём — HUD обновит при следующем начислении).
func reset() -> void:
	score = 0
