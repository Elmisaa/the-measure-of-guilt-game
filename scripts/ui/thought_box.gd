class_name ThoughtBox
extends PanelContainer
## Hero's thoughts: dark plate at the bottom centre of the screen.

const BOTTOM_MARGIN: float = 8.0
const FADE_TIME: float = 0.25
const MAX_LINE_CHARS: int = 95

var _label: Label
var _tween: Tween
var _hide_left: float = -1.0


func _ready() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.92)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	if _hide_left > 0.0:
		_hide_left -= delta
		if _hide_left <= 0.0:
			hide_box()


## duration <= 0: stays until hide_box().
func show_text(text: String, duration: float = 0.0) -> void:
	_label.text = _two_lines(text) if text.length() > MAX_LINE_CHARS else text
	var hud: Node = get_node_or_null("/root/Hud")  # not the global name: class_name scripts may compile before autoloads
	if hud and not text.is_empty():
		hud.log_thought(text)
	update_minimum_size()
	var ms: Vector2 = get_combined_minimum_size().ceil()
	offset_left = -floorf(ms.x / 2.0)
	offset_right = offset_left + ms.x
	offset_bottom = -BOTTOM_MARGIN
	offset_top = -BOTTOM_MARGIN - ms.y
	visible = true
	_fade(1.0)
	_hide_left = duration


## Long thoughts: break once at the space nearest the middle (autowrap would
## size the plate before it knows its width and blow it up to full screen).
func _two_lines(text: String) -> String:
	var mid: int = text.length() / 2
	for d in mid:
		for i: int in [mid - d, mid + d]:
			if i > 0 and i < text.length() and text[i] == " ":
				return text.substr(0, i) + "\n" + text.substr(i + 1)
	return text


func hide_box() -> void:
	_hide_left = -1.0
	if visible:
		_fade(0.0)


func is_showing() -> bool:
	return visible and modulate.a > 0.0


func _fade(to: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", to, FADE_TIME)
	if to == 0.0:
		_tween.tween_callback(func() -> void: visible = false)
