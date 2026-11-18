class_name ClickZone
extends Control
## Invisible clickable area over something painted into the background (e.g. the CRT
## monitor). Shows a faint outline on hover; emits activated on click.

signal activated

@export var outline: Color = Color(0.8, 0.9, 1.0, 0.35)

var _hover: bool = false
var enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())


func set_enabled(v: bool) -> void:
	enabled = v
	mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
	_hover = false
	queue_redraw()


func _draw() -> void:
	if _hover and enabled:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1), outline, false, 2.0)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if enabled and mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		activated.emit()
