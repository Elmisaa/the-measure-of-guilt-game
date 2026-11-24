extends Node2D

const INTRO: String = "res://scenes/s00/intro.tscn"
const BACKGROUND: String = "res://assets/backgrounds/menu/title_board.png"
const SWAY: Vector2 = Vector2(40, 22)
const SENSITIVITY: float = 2.5

var _menu: VBoxContainer
var _settings: SettingsPanel
var _saves: SaveSlotsPanel
var _ui: CanvasLayer
var _starting: bool = false
var _status: Label
var _bg: Sprite2D
var _sway_t: float = 0.0


func _ready() -> void:
	Hud.set_hud_visible(false)
	Letterbox.hide_bars()
	Audio.play_track("res://assets/audio/story/traces.wav", 1.5, -12.0)
	var bg: Sprite2D = Sprite2D.new()
	bg.texture = load(BACKGROUND)
	bg.centered = false
	bg.position = -SWAY
	add_child(bg)
	_bg = bg
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.02, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)
	var title: Label = Label.new()
	title.text = "МЕРА ВИНЫ"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.93, 0.9, 0.82))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.position = Vector2(372, 92)
	_ui.add_child(title)
	var sub: Label = Label.new()
	sub.text = "Нью-Йорк, 1998"
	sub.add_theme_color_override("font_color", Color(0.62, 0.86, 0.72))
	sub.position = Vector2(376, 136)
	_ui.add_child(sub)
	_menu = VBoxContainer.new()
	_menu.position = Vector2(372, 172)
	_menu.add_theme_constant_override("separation", 4)
	_ui.add_child(_menu)
	var items: Array = []
	if SaveGame.has_any():
		items.append(["Продолжить", _continue])
	items.append(["Новая игра", _new_game])
	if SaveGame.has_any():
		items.append(["Загрузить", func() -> void: _saves.open("load")])
	items.append_array([["Настройки", _open_settings], ["Выход", func() -> void: get_tree().quit()]])
	var buttons: Array[Button] = []
	for it: Array in items:
		var b: Button = MenuUI.button(str(it[0]))
		b.custom_minimum_size = Vector2(150, 0)
		b.pressed.connect(it[1])
		_menu.add_child(b)
		buttons.append(b)
	for i: int in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
	_settings = SettingsPanel.new()
	_ui.add_child(_settings)
	var settings_btn: Button = buttons[buttons.size() - 2]
	_settings.closed.connect(func() -> void: settings_btn.grab_focus())
	_saves = SaveSlotsPanel.new()
	_ui.add_child(_saves)
	_saves.closed.connect(func() -> void: buttons[0].grab_focus())
	_saves.loading.connect(func() -> void: _starting = true)
	_saves.load_failed.connect(func() -> void: _starting = false)
	_status = Label.new()
	_status.custom_minimum_size.x = 225
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.hide()
	_menu.add_child(_status)
	buttons[0].grab_focus.call_deferred()


func _new_game() -> void:
	if _starting:
		return
	_starting = true
	GameState.new_game()
	Hud.reset_journal()
	if not await SceneRouter.go_to(INTRO, 0.3):
		_starting = false


func _continue() -> void:
	if _starting:
		return
	_starting = true
	_status.hide()
	if not await SaveGame.load_slot(SaveGame.latest()):
		_starting = false
		_status.text = "Не удалось загрузить сохранение."
		_status.show()


func _open_settings() -> void:
	_settings.open()


func _input(event: InputEvent) -> void:
	if _settings.is_open() or _saves.is_open() or _starting:
		return
	MenuUI.wasd_to_focus(event, get_viewport())


func _process(delta: float) -> void:
	if _bg == null:
		return
	_sway_t += delta
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var m: Vector2 = (get_viewport().get_mouse_position() / vp - Vector2(0.5, 0.5)) * 2.0 * SENSITIVITY
	m = m.clamp(Vector2(-1, -1), Vector2(1, 1))
	var breathe: Vector2 = Vector2(sin(_sway_t * 0.4) * 2.0, sin(_sway_t * 0.27) * 1.5)
	var target: Vector2 = -SWAY - m * SWAY * 0.9 + breathe
	_bg.position = _bg.position.lerp(target, clampf(delta * 4.0, 0.0, 1.0)).round()
