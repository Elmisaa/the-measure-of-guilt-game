class_name HintMarker
extends Control
## An interactive spot over a painted object. No visible marker: on hover thin corner
## brackets appear and the cursor becomes a hand. Click -> activated(id).
## (The periodic light glint is off — the user didn't like it; glint_enabled turns it back on.)
## The Control's rect should cover the object.

signal activated(marker_id: String)

@export var marker_id: String = ""
@export var glint_enabled: bool = false
@export var glint_every_min: float = 7.0
@export var glint_every_max: float = 14.0
@export var glint_time: float = 0.9
@export var glint_alpha: float = 0.22

const BRACKET: float = 5.0
const BRACKET_COLOR: Color = Color(0.92, 0.95, 1.0, 0.55)

var _hover: bool = false
## Inactive spots show no hints and ignore the mouse (e.g. Alexei is too far away).
var active: bool = true
var _wait: float = 0.0
var _glint: float = -1.0  # -1 idle, 0..1 sweep progress


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())
	_wait = randf_range(1.5, glint_every_max)


## Walking scenes have no cursor: markers there only light up, they are used with E.
var mouse_enabled: bool = true:
	set(v):
		mouse_enabled = v
		if not v:
			mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_active(v: bool) -> void:
	if v == active:
		return
	active = v
	mouse_filter = Control.MOUSE_FILTER_STOP if v and mouse_enabled else Control.MOUSE_FILTER_IGNORE
	if not v:
		_hover = false
		_glint = -1.0
	queue_redraw()


func _process(delta: float) -> void:
	if not active or not glint_enabled:
		return
	if _glint < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_glint = 0.0
	else:
		_glint += delta / glint_time
		if _glint >= 1.0:
			_glint = -1.0
			_wait = randf_range(glint_every_min, glint_every_max)
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	if _glint >= 0.0:
		# a narrow diagonal sheen sweeping left -> right, faded at both ends
		var w: float = 6.0
		var x: float = lerpf(-size.y - w, size.x, _glint)
		var a: float = glint_alpha * sin(PI * _glint)
		var pts: PackedVector2Array = PackedVector2Array([Vector2(x, size.y), Vector2(x + w, size.y), Vector2(x + w + size.y, 0), Vector2(x + size.y, 0)])
		draw_colored_polygon(pts, Color(1.0, 0.97, 0.9, a))
	if _hover:
		var s: Vector2 = size - Vector2.ONE
		var c: Color = BRACKET_COLOR
		for corner: Vector2 in [Vector2.ZERO, Vector2(s.x, 0), Vector2(0, s.y), s]:
			var dx: float = BRACKET if corner.x == 0 else -BRACKET
			var dy: float = BRACKET if corner.y == 0 else -BRACKET
			draw_line(corner, corner + Vector2(dx, 0), c, 1.0)
			draw_line(corner, corner + Vector2(0, dy), c, 1.0)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		activated.emit(marker_id)
		accept_event()
