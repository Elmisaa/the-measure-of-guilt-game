class_name HintMarker
extends Control
## Small dim square that rarely blinks; click shows the hero's thought about the spot.

signal activated(marker_id: String)

@export var marker_id: String = ""
@export var base_alpha: float = 0.35
@export var peak_alpha: float = 0.9
@export var min_interval: float = 3.0
@export var max_interval: float = 8.0
@export var blink_time: float = 1.4

const HIT_SIZE: Vector2 = Vector2(12, 12)

var _alpha: float = 0.0
var _wait: float = 0.0
var _phase: float = -1.0
var _hover: bool = false


func _ready() -> void:
	custom_minimum_size = HIT_SIZE
	size = HIT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)
	_wait = randf_range(0.5, max_interval)


func _process(delta: float) -> void:
	if _phase < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_phase = 0.0
	else:
		_phase += delta / blink_time
		if _phase >= 1.0:
			_phase = -1.0
			_wait = randf_range(min_interval, max_interval)
	var a: float = base_alpha
	if _phase >= 0.0:
		a = lerpf(base_alpha, peak_alpha, sin(PI * _phase))
	if _hover:
		a = 1.0
	if not is_equal_approx(a, _alpha):
		_alpha = a
		queue_redraw()


func _draw() -> void:
	# 2x pixel grid: 4x4 light core inside a 2px dark border.
	draw_rect(Rect2(Vector2(2, 2), Vector2(8, 8)), Color(0.0, 0.0, 0.0, _alpha * 0.6))
	draw_rect(Rect2(Vector2(4, 4), Vector2(4, 4)), Color(0.85, 0.95, 1.0, _alpha))


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		activated.emit(marker_id)
		accept_event()
