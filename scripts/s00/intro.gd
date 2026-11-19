extends Node2D
## s00: epigraph quote on black -> intro cutscene (window in the rain -> coffee on
## Alexei's desk) -> s01. Letterbox bars stay until s01, which retracts them.
## Neither the quote nor the cutscene can be skipped.

const NEXT_SCENE: String = "res://scenes/s01/exposition.tscn"
const FADE_IN: float = 1.0
const SHOT_TIME: float = 4.0
const CROSS_TIME: float = 0.5
const PAN_PX: float = 40.0  ## frames are 680 wide, view 640
const QUOTE_FADE: float = 1.6
const QUOTE_HOLD: float = 6.0
const QUOTE_GAP: float = 0.8
## Where and when: typed line by line at the lower left of the first shot (above the letterbox bar).
const PLACE_SHOT_TIME: float = 7.0
const PLACE_CHAR: float = 0.055
const PLACE_POS: Vector2 = Vector2(28, 250)
const TICK: String = "res://assets/audio/sfx/key_tick.wav"

@onready var _window: Node2D = $Shots/Window
@onready var _coffee: Node2D = $Shots/Coffee
@onready var _fade: ColorRect = $Fade/Black
@onready var _quote: Label = $Fade/Quote

var _leaving: bool = false
var _in_quote: bool = false
var _quote_skip: bool = false
var _place: VBoxContainer


func _ready() -> void:
	Letterbox.show_bars()
	Hud.set_hud_visible(false)
	_coffee.visible = false
	_fade.color.a = 1.0
	_quote.text = str(DialogueData.load_file("s00_intro").get("quote", ""))
	_quote.modulate.a = 0.0
	_build_place()
	await _show_quote()
	_play()


func _show_quote() -> void:
	_in_quote = true
	var t: Tween = create_tween()
	t.tween_property(_quote, "modulate:a", 1.0, QUOTE_FADE)
	t.tween_interval(QUOTE_HOLD)
	t.tween_property(_quote, "modulate:a", 0.0, QUOTE_FADE)
	t.tween_interval(QUOTE_GAP)
	while t.is_running() and not _quote_skip:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	if _quote_skip:
		t.kill()
		var out: Tween = create_tween()
		out.tween_property(_quote, "modulate:a", 0.0, 0.4)
		await out.finished
	_in_quote = false


func _play() -> void:
	_pan(_window, 0.0, -PAN_PX, FADE_IN + PLACE_SHOT_TIME)
	await _fade_to(0.0, FADE_IN)
	_type_place()
	await _wait(PLACE_SHOT_TIME - CROSS_TIME)
	var out: Tween = create_tween()
	out.tween_property(_place, "modulate:a", 0.0, CROSS_TIME)
	await _fade_to(1.0, CROSS_TIME)
	if _leaving:
		return
	_window.visible = false
	_coffee.visible = true
	_pan(_coffee, -PAN_PX, -PAN_PX / 2.0, SHOT_TIME + CROSS_TIME * 2.0)
	await _fade_to(0.0, CROSS_TIME)
	await _wait(SHOT_TIME)
	_leave()




func _build_place() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 81  # over the fade; it fades itself
	add_child(layer)
	_place = VBoxContainer.new()
	_place.position = PLACE_POS
	_place.add_theme_constant_override("separation", 2)
	layer.add_child(_place)
	var lines: Array = DialogueData.load_file("s00_intro").get("place", [])
	for i: int in lines.size():
		var l: Label = Label.new()
		l.text = str(lines[i])
		l.visible_characters = 0
		l.add_theme_color_override("font_color", Color(0.93, 0.9, 0.82) if i < 2 else Color(0.62, 0.86, 0.72))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		if i == 0:
			l.add_theme_font_size_override("font_size", 16)
		_place.add_child(l)


## Typewriter, line by line, with a soft key tick.
func _type_place() -> void:
	for l: Node in _place.get_children():
		var lab: Label = l as Label
		for c: int in lab.text.length():
			if _leaving:
				return
			lab.visible_characters = c + 1
			if lab.text[c] != " ":
				Audio.sfx(TICK, -20.0, randf_range(0.9, 1.1))
			await get_tree().create_timer(PLACE_CHAR).timeout
		await get_tree().create_timer(0.35).timeout


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	SceneRouter.go_to(NEXT_SCENE)


## Pans a shot horizontally on the 2px grid (no sub-pixel shimmer).
func _pan(shot: Node2D, from_x: float, to_x: float, time: float) -> void:
	var t: Tween = create_tween()
	t.tween_method(func(x: float) -> void: shot.position.x = roundf(x / 2.0) * 2.0, from_x, to_x, time)


func _fade_to(alpha: float, time: float) -> void:
	if _leaving:
		return
	var t: Tween = create_tween()
	t.tween_property(_fade, "color:a", alpha, time)
	await t.finished


func _wait(sec: float) -> void:
	if _leaving:
		return
	await get_tree().create_timer(sec).timeout
