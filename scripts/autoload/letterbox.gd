extends CanvasLayer
## Cinematic black bars (top/bottom). Autoload: Letterbox.
## show_bars() for cutscenes; retract() slides the top bar up and the bottom bar down.

const BAR_HEIGHT: float = 44.0

var _top: ColorRect
var _bottom: ColorRect
var _shown: bool = false


func _ready() -> void:
	layer = 90
	_top = _make_bar()
	_bottom = _make_bar()
	_place(0.0)


func _make_bar() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(640.0, BAR_HEIGHT)
	add_child(r)
	return r


## amount: 1 = bars fully in, 0 = hidden off-screen.
func _place(amount: float) -> void:
	var off: float = roundf(BAR_HEIGHT * (1.0 - amount))
	_top.position = Vector2(0.0, -off)
	_bottom.position = Vector2(0.0, 360.0 - BAR_HEIGHT + off)


func show_bars() -> void:
	_shown = true
	_place(1.0)


func hide_bars() -> void:
	_shown = false
	_place(0.0)


func is_shown() -> bool:
	return _shown


func retract(duration: float = 0.8) -> void:
	if not _shown:
		return
	_shown = false
	var t: Tween = create_tween()
	t.tween_method(_place, 1.0, 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
