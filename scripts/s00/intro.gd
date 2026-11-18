extends Node2D
## s00: intro cutscene. Window in the rain -> coffee on Alexei's desk -> s01.
## Letterbox bars stay until s01, which retracts them. Esc/click skips.

const NEXT_SCENE: String = "res://scenes/s01/exposition.tscn"
const FADE_IN: float = 1.0
const SHOT_TIME: float = 4.0
const CROSS_TIME: float = 0.5
const PAN_PX: float = 40.0  ## frames are 680 wide, view 640

@onready var _window: Node2D = $Shots/Window
@onready var _coffee: Node2D = $Shots/Coffee
@onready var _fade: ColorRect = $Fade/Black

var _leaving: bool = false


func _ready() -> void:
	Letterbox.show_bars()
	_coffee.visible = false
	_fade.color.a = 1.0
	_play()


func _play() -> void:
	_pan(_window, 0.0, -PAN_PX, FADE_IN + SHOT_TIME)
	await _fade_to(0.0, FADE_IN)
	await _wait(SHOT_TIME - CROSS_TIME)
	await _fade_to(1.0, CROSS_TIME)
	if _leaving:
		return
	_window.visible = false
	_coffee.visible = true
	_pan(_coffee, -PAN_PX, -PAN_PX / 2.0, SHOT_TIME + CROSS_TIME * 2.0)
	await _fade_to(0.0, CROSS_TIME)
	await _wait(SHOT_TIME)
	_leave()


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") or (mb and mb.pressed):
		get_viewport().set_input_as_handled()
		_leave()


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
