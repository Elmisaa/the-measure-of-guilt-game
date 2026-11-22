class_name CombatHud
extends CanvasLayer
## Боевой HUD под 640x360: HP, патроны, заряды тазера, состояние, подсказки.
## Игрока находит сам — по player_path или через группу "player" (add_to_group в Player._ready).
## Значения берёт из сигналов игрока и сразу инициализирует их, поэтому "Player: -" не бывает.

const WEAPON_NAME: String = "GLOCK 19"
const HINT_TEXT: String = "A/D — шаг | S/Space — укрытие | ЛКМ — выстрел | R — перезарядка | ПКМ — удар | Q — тазер"
const STATE_NAMES: Array[String] = ["IDLE", "RUN", "COVER", "DEAD"]
const TEXT_COLOR: Color = Color(0.9, 0.93, 0.96, 1)
const MUTED_COLOR: Color = Color(0.62, 0.67, 0.72, 1)
const AMMO_EMPTY_COLOR: Color = Color(1, 0.42, 0.38, 1)
const RELOAD_COLOR: Color = Color(1, 0.85, 0.35, 1)
const COVER_COLOR: Color = Color(0.55, 0.9, 1, 1)
const DEAD_COLOR: Color = Color(1, 0.4, 0.4, 1)
const PANEL_BG: Color = Color(0.03, 0.03, 0.05, 0.82)
const PANEL_BORDER: Color = Color(0.45, 0.48, 0.55, 0.55)
const TASER_COLOR: Color = Color(0.55, 0.9, 1, 1)
const TASER_EMPTY_COLOR: Color = Color(1, 0.42, 0.38, 1)
## Сколько кадров ждём появления игрока в группе (игрок может появиться позже HUD).
const MAX_BIND_TRIES: int = 120

@export var player_path: NodePath

var _player: Player = null
var _bind_tries: int = 0
var _hp_bar: ProgressBar
var _hp_text: Label
var _ammo_text: Label
var _taser_text: Label
var _state_text: Label
var _reload_text: Label
var _hint_text: Label


func _ready() -> void:
	layer = 50
	_build_ui()
	_bind_player()


# --- построение UI --------------------------------------------------------

func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(8, 8)
	panel.custom_minimum_size = Vector2(206, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top_row)
	_hp_text = _make_label("HpText", TEXT_COLOR)
	top_row.add_child(_hp_text)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)
	_state_text = _make_label("StateText", MUTED_COLOR)
	top_row.add_child(_state_text)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.custom_minimum_size = Vector2(190, 5)
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.add_theme_stylebox_override("background", _bar_style(Color(0.12, 0.12, 0.15, 1)))
	_hp_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.72, 0.28, 0.26, 1)))
	column.add_child(_hp_bar)

	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom_row)
	_ammo_text = _make_label("AmmoText", TEXT_COLOR)
	bottom_row.add_child(_ammo_text)
	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(spacer2)
	_reload_text = _make_label("ReloadText", RELOAD_COLOR)
	_reload_text.text = "RELOADING..."
	_reload_text.visible = false
	bottom_row.add_child(_reload_text)

	_taser_text = _take_label("TaserText", TASER_COLOR, column)

	_hint_text = _make_label("HintText", MUTED_COLOR)
	_hint_text.name = "HintText"
	_hint_text.text = HINT_TEXT
	_hint_text.position = Vector2(8, 340)
	_hint_text.size = Vector2(624, 12)
	add_child(_hint_text)


func _make_label(node_name: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 8)
	return label


## Метки TaserText/ProtocolText приходят из сцены; fallback — создаём кодом.
func _take_label(node_name: String, color: Color, parent: Node) -> Label:
	var label: Label = get_node_or_null(node_name) as Label
	if label == null:
		label = _make_label(node_name, color)
		parent.add_child(label)
		return label
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 8)
	if label.get_parent() != parent:
		label.reparent(parent)
	return label


func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _bar_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(1)
	return style


# --- привязка к игроку ----------------------------------------------------

func _bind_player() -> void:
	var found: Player = null
	if not player_path.is_empty():
		found = get_node_or_null(player_path) as Player
	if found == null and is_inside_tree():
		found = get_tree().get_first_node_in_group("player") as Player
	if found == null:
		_bind_tries += 1
		if _bind_tries <= MAX_BIND_TRIES:
			call_deferred("_bind_player")
		return
	_player = found
	_player.health_changed.connect(_on_health_changed)
	_player.ammo_changed.connect(_on_ammo_changed)
	_player.taser_charges_changed.connect(_on_taser_charges_changed)
	_player.state_changed.connect(_on_state_changed)
	_player.reload_started.connect(_on_reload_started)
	_player.reload_finished.connect(_on_reload_finished)
	_player.reload_cancelled.connect(_on_reload_cancelled)
	_player.cover_changed.connect(_on_cover_changed)
	_on_health_changed(_player.health, _player.max_health)
	_on_ammo_changed(_player.ammo_current, _player.ammo_max)
	_on_taser_charges_changed(_player.taser_charges, _player.taser_charges_max)
	_on_state_changed(_player.state)
	_on_reload_finished()


## Игрок, к которому привязан HUD (null, пока не найден).
func target_player() -> Player:
	return _player


# --- сигналы игрока -------------------------------------------------------

func _on_health_changed(health: int, max_health: int) -> void:
	_hp_text.text = "HP: %d / %d" % [health, max_health]
	_hp_bar.max_value = maxi(max_health, 1)
	_hp_bar.value = clampi(health, 0, max_health)


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	_ammo_text.text = "%s: %d / %d" % [WEAPON_NAME, current, max_ammo]
	_ammo_text.add_theme_color_override("font_color", AMMO_EMPTY_COLOR if current <= 0 else TEXT_COLOR)


func _on_taser_charges_changed(current: int, max_charges: int) -> void:
	if _taser_text == null:
		return
	_taser_text.text = "TASER: %d / %d" % [current, max_charges]
	_taser_text.add_theme_color_override("font_color", TASER_EMPTY_COLOR if current <= 0 else TASER_COLOR)


func _on_state_changed(state: int) -> void:
	var state_name: String = STATE_NAMES[state] if state >= 0 and state < STATE_NAMES.size() else "?"
	_state_text.text = "STATE: %s" % state_name
	var color: Color = MUTED_COLOR
	if state == Player.State.COVER:
		color = COVER_COLOR
	elif state == Player.State.DEAD:
		color = DEAD_COLOR
	_state_text.add_theme_color_override("font_color", color)


func _on_reload_started() -> void:
	_reload_text.visible = true


func _on_reload_finished() -> void:
	_reload_text.visible = false


func _on_reload_cancelled() -> void:
	_reload_text.visible = false


func _on_cover_changed(in_cover: bool) -> void:
	# Само состояние COVER приходит через state_changed; здесь подсвечиваем подсказку.
	if _hint_text != null:
		_hint_text.add_theme_color_override("font_color", COVER_COLOR if in_cover else MUTED_COLOR)
