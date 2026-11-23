class_name ClickZone
extends Control

signal activated

@export var outline: Color = Color(0.92, 0.95, 1.0, 0.55)
const BRACKET: float = 5.0

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
		var s: Vector2 = size - Vector2.ONE
		for corner: Vector2 in [Vector2.ZERO, Vector2(s.x, 0), Vector2(0, s.y), s]:
			var dx: float = BRACKET if corner.x == 0 else -BRACKET
			var dy: float = BRACKET if corner.y == 0 else -BRACKET
			draw_line(corner, corner + Vector2(dx, 0), outline, 1.0)
			draw_line(corner, corner + Vector2(0, dy), outline, 1.0)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if enabled and mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		activated.emit()
