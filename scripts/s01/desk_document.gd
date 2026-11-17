class_name DeskDocument
extends Sprite2D
## A document on the desk: lifts and twitches under the mouse, click -> clicked(doc_id).
## Place it in the scene by its top-left corner; the script recentres it for rotation.

signal clicked(doc_id: String)

@export var doc_id: String = ""
@export var lift: float = 2.0
@export var twitch_degrees: float = 1.5

const SHADOW_REST: Vector2 = Vector2(4, 4)
const SHADOW_LIFTED: Vector2 = Vector2(4, 6)

var interactive: bool = true
var _img: Image
var _rest: Vector2
var _hover: bool = false
var _tween: Tween
var _shadow: Sprite2D


func _ready() -> void:
	_img = texture.get_image()
	if _img.is_compressed():
		_img.decompress()
	var half: Vector2 = (texture.get_size() / 2.0).floor()
	centered = true
	offset = Vector2.ZERO
	position += half
	_rest = position
	_shadow = Sprite2D.new()
	_shadow.texture = texture
	_shadow.modulate = Color(0, 0, 0, 0.45)
	_shadow.position = SHADOW_REST
	_shadow.show_behind_parent = true
	add_child(_shadow)


func _process(_delta: float) -> void:
	var over: bool = interactive and _is_mouse_over()
	if over != _hover:
		_hover = over
		_animate(over)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over else Input.CURSOR_ARROW)


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if _hover and mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit(doc_id)


func set_interactive(value: bool) -> void:
	interactive = value
	if not value and _hover:
		_hover = false
		_animate(false)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _is_mouse_over() -> bool:
	var p: Vector2 = get_local_mouse_position() + texture.get_size() / 2.0
	var ip: Vector2i = Vector2i(p.floor())
	if ip.x < 0 or ip.y < 0 or ip.x >= _img.get_width() or ip.y >= _img.get_height():
		return false
	return _img.get_pixelv(ip).a > 0.5


func _animate(up: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if up:
		_tween.set_parallel(true)
		_tween.tween_property(self, "position", _rest + Vector2(0, -lift), 0.08)
		_tween.tween_property(_shadow, "position", SHADOW_LIFTED, 0.08)
		_tween.set_parallel(false)
		var r: float = deg_to_rad(twitch_degrees)
		_tween.tween_property(self, "rotation", r, 0.06)
		_tween.tween_property(self, "rotation", -r * 0.7, 0.08)
		_tween.tween_property(self, "rotation", r * 0.35, 0.07)
		_tween.tween_property(self, "rotation", 0.0, 0.07)
	else:
		_tween.set_parallel(true)
		_tween.tween_property(self, "position", _rest, 0.12)
		_tween.tween_property(self, "rotation", 0.0, 0.12)
		_tween.tween_property(_shadow, "position", SHADOW_REST, 0.12)
