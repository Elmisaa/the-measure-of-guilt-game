class_name BossHud
extends CanvasLayer

var _player: BossPlayer = null
var _hp_bar: ProgressBar
var _hp_label: Label
var _ammo_label: Label
var _dash_label: Label
var _boss_bar: ProgressBar
var _boss_label: Label
var _phase_label: Label
var _hint_label: Label

var _boss_resistance: int = 100
var _boss_resistance_max: int = 100

func _ready() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is BossPlayer:
			_player = node as BossPlayer
			break
	
	if _player == null:
		push_warning("BossHud: BossPlayer not found in group 'player'")
		return
	
	_player.health_changed.connect(_on_health_changed)
	_player.ammo_changed.connect(_on_ammo_changed)
	_player.reload_started.connect(_on_reload_started)
	_player.reload_finished.connect(_on_reload_finished)
	_player.dash_started.connect(_on_dash_started)
	
	call_deferred("_connect_boss_signals")
	
	call_deferred("_build_ui")
	_update_all()

func _build_ui() -> void:
	var left_panel: Panel = Panel.new()
	left_panel.anchors_preset = Control.PRESET_TOP_LEFT
	left_panel.offset_left = 8
	left_panel.offset_top = 8
	left_panel.offset_right = 165
	left_panel.offset_bottom = 68
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.7)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	left_panel.add_theme_stylebox_override("panel", panel_style)
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_panel)
	
	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.anchors_preset = Control.PRESET_FULL_RECT
	left_vbox.offset_left = 6
	left_vbox.offset_top = 4
	left_vbox.offset_right = -6
	left_vbox.offset_bottom = -4
	left_vbox.add_theme_constant_override("separation", 2)
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_child(left_vbox)
	
	var hp_hbox: HBoxContainer = HBoxContainer.new()
	hp_hbox.add_theme_constant_override("separation", 4)
	hp_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(hp_hbox)
	
	_hp_bar = ProgressBar.new()
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.custom_minimum_size = Vector2(0, 12)
	_hp_bar.max_value = _player.max_health
	_hp_bar.value = _player.health
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_hbox.add_child(_hp_bar)
	
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 9)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_hbox.add_child(_hp_label)
	
	_ammo_label = Label.new()
	_ammo_label.add_theme_font_size_override("font_size", 9)
	_ammo_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(_ammo_label)
	
	_dash_label = Label.new()
	_dash_label.add_theme_font_size_override("font_size", 9)
	_dash_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(_dash_label)
	
	var right_panel: Panel = Panel.new()
	right_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	right_panel.offset_left = 370 - 640
	right_panel.offset_top = 8
	right_panel.offset_right = -8
	right_panel.offset_bottom = 48
	var right_style: StyleBoxFlat = StyleBoxFlat.new()
	right_style.bg_color = Color(0.1, 0, 0, 0.8)
	right_style.corner_radius_top_left = 4
	right_style.corner_radius_top_right = 4
	right_style.corner_radius_bottom_left = 4
	right_style.corner_radius_bottom_right = 4
	right_panel.add_theme_stylebox_override("panel", right_style)
	right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_panel.visible = true
	add_child(right_panel)
	
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.anchors_preset = Control.PRESET_FULL_RECT
	right_vbox.offset_left = 8
	right_vbox.offset_top = 4
	right_vbox.offset_right = -8
	right_vbox.offset_bottom = -4
	right_vbox.add_theme_constant_override("separation", 4)
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_panel.add_child(right_vbox)
	
	var phase_hbox: HBoxContainer = HBoxContainer.new()
	phase_hbox.add_theme_constant_override("separation", 8)
	phase_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(phase_hbox)
	
	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 9)
	_phase_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_label.text = "ФАЗА 1"
	phase_hbox.add_child(_phase_label)
	
	_boss_label = Label.new()
	_boss_label.add_theme_font_size_override("font_size", 9)
	_boss_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_hbox.add_child(_boss_label)
	
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(0, 14)
	_boss_bar.max_value = 100
	_boss_bar.value = 100
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(_boss_bar)
	
	_hint_label = Label.new()
	_hint_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_top = -18
	_hint_label.offset_bottom = -2
	_hint_label.offset_left = 8
	_hint_label.offset_right = -8
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 8)
	_hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.text = "WASD — движение | Пробел/Shift — рывок | ЛКМ — выстрел | R — перезарядка"
	add_child(_hint_label)

func _connect_boss_signals() -> void:
	for barrel in get_tree().get_nodes_in_group("boss_targets"):
		if barrel.get_class() == "ExplosiveBarrel" and barrel.has_signal("exploded"):
			barrel.exploded.connect(_on_barrel_exploded)
	
	for conveyor in get_tree().get_nodes_in_group("boss_targets"):
		if conveyor.get_class() == "OverheadConveyor" and conveyor.has_signal("container_crashed"):
			conveyor.container_crashed.connect(_on_container_crashed)
	
	for boss in get_tree().get_nodes_in_group("boss"):
		if boss.get_class() == "BossScales" and boss.has_signal("resistance_changed"):
			boss.resistance_changed.connect(_on_boss_resistance_changed)

func _on_barrel_exploded(near_boss: bool, boss_damage: int, world_pos: Vector3) -> void:
	if near_boss:
		_boss_resistance = maxi(0, _boss_resistance - boss_damage)
		set_boss_resistance(_boss_resistance, _boss_resistance_max)
		call_deferred("_respawn_barrel_at", world_pos)

func _on_container_crashed(hit_boss: bool, boss_damage: int, impact_pos: Vector3) -> void:
	if hit_boss:
		_boss_resistance = maxi(0, _boss_resistance - boss_damage)
		set_boss_resistance(_boss_resistance, _boss_resistance_max)

func _on_boss_resistance_changed(cur: int, max_val: int) -> void:
	_boss_resistance = cur
	_boss_resistance_max = max_val
	set_boss_resistance(cur, max_val)

func _respawn_barrel_at(pos: Vector3) -> void:
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	var barrel_scene: PackedScene = preload("res://scenes/gameplay/boss/explosive_barrel.tscn")
	var barrel: Node3D = barrel_scene.instantiate() as Node3D
	barrel.global_position = pos
	add_child(barrel)
	if barrel.has_signal("exploded"):
		barrel.exploded.connect(_on_barrel_exploded)

func _update_all() -> void:
	if _player == null:
		return
	_on_health_changed(_player.health, _player.max_health)
	_on_ammo_changed(_player.ammo_current, _player.ammo_max)
	_on_dash_cooldown(_player._dash_cooldown_timer.time_left if _player._dash_cooldown_timer != null else 0.0)
	set_boss_resistance(_boss_resistance, _boss_resistance_max)

func _on_health_changed(cur: int, max_h: int) -> void:
	if _hp_bar != null:
		_hp_bar.max_value = max_h
		_hp_bar.value = cur
	if _hp_label != null:
		_hp_label.text = "HP: %d / %d" % [cur, max_h]

func _on_ammo_changed(cur: int, max_a: int) -> void:
	if _ammo_label != null:
		if cur <= 0:
			_ammo_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
			_ammo_label.text = "AMMO: 0 / %d" % max_a
		else:
			_ammo_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			_ammo_label.text = "AMMO: %d / %d" % [cur, max_a]

func _on_reload_started() -> void:
	if _ammo_label != null:
		_ammo_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))
		_ammo_label.text = "RELOADING..."

func _on_reload_finished() -> void:
	if _ammo_label != null:
		_ammo_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		if _player != null:
			_ammo_label.text = "AMMO: %d / %d" % [_player.ammo_current, _player.ammo_max]

func _on_dash_started() -> void:
	_on_dash_cooldown(_player.dash_cooldown if _player != null else 0.85)

func _on_dash_cooldown(time_left: float) -> void:
	if _dash_label != null:
		if time_left > 0.01:
			_dash_label.add_theme_color_override("font_color", Color(1, 0.5, 0.2, 1))
			_dash_label.text = "DASH: CD %.1fs" % time_left
		else:
			_dash_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3, 1))
			_dash_label.text = "DASH: READY"

func _physics_process(delta: float) -> void:
	if _player != null and _player._dash_cooldown_timer != null:
		var left: float = _player._dash_cooldown_timer.time_left
		if left > 0.01:
			_on_dash_cooldown(left)
		elif _dash_label != null and _dash_label.text != "DASH: READY":
			_on_dash_cooldown(0.0)

func set_boss_resistance(cur: int, max_val: int) -> void:
	if _boss_bar != null:
		_boss_bar.max_value = max_val
		_boss_bar.value = cur
	if _boss_label != null:
		_boss_label.text = "ВЕСЫ: %d / %d" % [cur, max_val]

func set_phase_title(text: String) -> void:
	if _phase_label != null:
		_phase_label.text = text