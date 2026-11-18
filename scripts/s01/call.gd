extends Node2D
## s01 part 3: Fyodor's phone call. Tension grows line by line through the lamp,
## Fyodor's trembling text, screen interference and frame shakes — not through
## Alexei's face. Knock on the door -> line goes dead -> thoughts -> leave.

const CHARS_PER_SEC: float = 32.0
const START_DELAY: float = 0.8
const SFX: String = "res://assets/audio/sfx/"
const PUNCT: String = ".,!?…—-:;\"«»“”"

@onready var _frame: Node2D = $Frame
@onready var _lamp: LightFlicker = $Frame/Lights/LampLight
@onready var _glitch: ColorRect = $Glitch/Rect
@onready var _fyodor_box: Control = $UI/Root/Fyodor
@onready var _fyodor_name: Label = $UI/Root/Fyodor/Name
@onready var _fyodor_text: RichTextLabel = $UI/Root/Fyodor/Text
@onready var _alexei_box: Control = $UI/Root/Alexei
@onready var _alexei_name: Label = $UI/Root/Alexei/Name
@onready var _alexei_text: Label = $UI/Root/Alexei/Text
@onready var _thought: ThoughtBox = $UI/Root/ThoughtBox
@onready var _button: Button = $UI/Root/LeaveButton
@onready var _black: ColorRect = $Fade/Black
@onready var _end_label: Label = $Fade/End

var _all: Dictionary = {}
var _data: Dictionary = {}
var _lines: Array = []
var _index: int = -1
var _typing: Tween
var _typing_node: Control
var _shown: int = 0
var _blip_phone: bool = false
var _pitch: float = 1.0
var _busy: bool = true  # events / waiting: clicks ignored
var _tension: float = 0.0
var _glitch_spike: float = 0.0
var _shake_left: float = 0.0
var _shake_amp: int = 0
var _shake_step: float = 0.0
var _after_lines: bool = false
var _pages: PackedStringArray = PackedStringArray()
var _page: int = 0
var _page_is_fyodor: bool = false
var _page_is_thought: bool = false
var _fyodor_fmt: String = "%s"
var _say_count: int = 0
var _say_done: int = 0
var _saturation: float = 1.0
var _call_over: bool = false  ## line went dead: colours come back

const FYODOR_PAGE: int = 90
const ALEXEI_PAGE: int = 80
const THOUGHT_PAGE: int = 90
const MIN_SATURATION: float = 0.12


func _ready() -> void:
	_all = DialogueData.load_file("s01_precinct")
	_data = _all.get("call", {})
	_lines = _data.get("lines", [])
	Hud.set_hud_visible(true)
	Hud.set_objective(str(_data.get("objective", "")))
	_fyodor_box.modulate.a = 0.0
	_alexei_box.modulate.a = 0.0
	_button.visible = false
	_button.text = str(_data.get("button", ""))
	_button.pressed.connect(_on_leave)
	Audio.bind_button(_button)
	_black.color.a = 0.0
	_end_label.visible = false
	_set_tension(0.0)
	for l: Dictionary in _lines:
		if str(l.get("type", "")) == "say":
			_say_count += 1
	await get_tree().create_timer(START_DELAY).timeout
	_busy = false
	_next()


func _process(delta: float) -> void:
	# glitch intensity: base from tension + decaying spikes
	_glitch_spike = maxf(0.0, _glitch_spike - delta * 1.5)
	var gi: float = clampf(_tension * 0.45 + _glitch_spike, 0.0, 1.0)
	# colours drain toward black-and-white as the call goes on
	var target_sat: float = 1.0 if _call_over else lerpf(1.0, MIN_SATURATION, float(_say_done) / maxf(1.0, float(_say_count)))
	_saturation = move_toward(_saturation, target_sat, delta * (0.6 if _call_over else 0.15))
	_glitch.visible = gi > 0.01 or _saturation < 0.99
	var mat: ShaderMaterial = _glitch.material as ShaderMaterial
	mat.set_shader_parameter("intensity", gi)
	mat.set_shader_parameter("saturation", _saturation)
	# frame shake on whole pixels (4px grid of the frame art)
	if _shake_left > 0.0:
		_shake_left -= delta
		_shake_step -= delta
		if _shake_step <= 0.0:
			_shake_step = 0.04
			_frame.position = Vector2(randi_range(-_shake_amp, _shake_amp), randi_range(-_shake_amp, _shake_amp)) * 2.0
		if _shake_left <= 0.0:
			_frame.position = Vector2.ZERO
	_update_blips()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or Hud.is_blocking():
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if (mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _typing and _typing.is_running():
			_typing.kill()
			_set_ratio(_typing_node, 1.0)
		elif _page < _pages.size() - 1:
			_page += 1
			_show_page()
		else:
			_next()


func _next() -> void:
	if _after_lines:
		return
	_index += 1
	_pages = PackedStringArray()
	_page = 0
	if _index >= _lines.size():
		_after_lines = true
		_thought.hide_box()
		_show_button()
		return
	var line: Dictionary = _lines[_index]
	match str(line.get("type", "say")):
		"event":
			_event(str(line.get("event", "")))
		"think":
			_hide_speech()
			_page_is_thought = true
			_pages = TextPager.pages(str(line.get("text", "")), THOUGHT_PAGE)
			_show_page()
		_:
			_say(line)


func _say(line: Dictionary) -> void:
	_thought.hide_box()
	var speaker: String = str(line.get("speaker", ""))
	var text: String = str(line.get("text", ""))
	var color: Color = Color.from_string(str(_all.get("speakers", {}).get(speaker, "#ffffff")), Color.WHITE)
	if line.has("tension"):
		_set_tension(float(line["tension"]))
	if line.get("music", false):
		Audio.play_track(str(_data.get("music", "")), 2.0, -8.0)
	_pitch = float(_all.get("voice_pitch", {}).get(speaker, 1.0))
	Hud.log_say(speaker, text, str(_all.get("speakers", {}).get(speaker, "#ffffff")))
	_say_done += 1
	_page_is_thought = false
	_page_is_fyodor = speaker == "Фёдор"
	if line.get("caps", false):
		text = text.to_upper()
	if _page_is_fyodor:
		_blip_phone = true
		_fade(_alexei_box, 0.0)
		_fyodor_name.text = speaker
		_fyodor_name.add_theme_color_override("font_color", color)
		var level: int = int(lerpf(1.0, 6.0, _tension))
		var size: int = 18 if line.get("big", false) else 9
		_fyodor_fmt = "[font_size=%d][shake rate=18.0 level=%d connected=1]" % [size, level] + "%s[/shake][/font_size]"
		_fade(_fyodor_box, 1.0)
		_pages = TextPager.pages(text, FYODOR_PAGE)
	else:
		_blip_phone = false
		_fade(_fyodor_box, 0.0)
		_alexei_name.text = speaker
		_alexei_name.add_theme_color_override("font_color", color)
		_fade(_alexei_box, 1.0)
		_pages = TextPager.pages(text, ALEXEI_PAGE)
	_show_page()
	if "!" in text:
		_shake(1 + int(_tension * 2.0), 0.25)
		_glitch_spike = maxf(_glitch_spike, 0.35 * _tension)


func _event(name: String) -> void:
	_busy = true
	match name:
		"knock":
			_hide_speech()
			await get_tree().create_timer(0.5).timeout
			Audio.sfx(SFX + "knock.wav", 0.0)
			_shake(4, 0.6)
			_glitch_spike = 1.0
			_lamp_blackout(0.4)
			await get_tree().create_timer(1.0).timeout
		"hangup":
			await get_tree().create_timer(0.9).timeout
			_hide_speech()
			Audio.stop_music(0.05)
			Audio.sfx(SFX + "hangup.wav", -2.0)
			_shake(2, 0.3)
			_glitch_spike = 0.8
			_set_tension(0.0)
			_call_over = true
			_saturation = 1.0  # colour snaps back at once
			await get_tree().create_timer(0.8).timeout
			Audio.play_loop(SFX + "dialtone.wav", -10.0)
			await get_tree().create_timer(1.5).timeout
	_busy = false
	_next()


func _show_button() -> void:
	_busy = true
	_button.modulate.a = 0.0
	_button.visible = true
	_fade(_button, 1.0)


func _on_leave() -> void:
	_button.disabled = true
	_fade(_button, 0.0)
	_thought.hide_box()
	var t: Tween = create_tween()
	t.tween_method(func(db: float) -> void: Audio._loop.volume_db = db, -10.0, -50.0, 1.5)
	t.tween_callback(Audio.stop_loop)
	await get_tree().create_timer(0.6).timeout
	_thought.show_text(str(_data.get("leave_thought", "")))
	await get_tree().create_timer(4.5).timeout
	_thought.hide_box()
	Hud.set_hud_visible(false)
	var f: Tween = create_tween()
	f.tween_property(_black, "color:a", 1.0, 1.5)
	await f.finished
	_end_label.text = str(_data.get("end_stub", ""))
	_end_label.visible = true


# --- tension helpers ---------------------------------------------------

func _set_tension(t: float) -> void:
	_tension = t
	_lamp.flicker_every_min = lerpf(9.0, 0.8, t)
	_lamp.flicker_every_max = lerpf(14.0, 2.2, t)
	_lamp.flicker_length_max = lerpf(0.6, 1.2, t)
	if t <= 0.0:
		_lamp.flicker_every_min = 0.0
		_lamp.flicker_every_max = 0.0  # steady after the line goes dead


func _lamp_blackout(sec: float) -> void:
	_lamp.set_process(false)
	_lamp.energy = 0.0
	_lamp.dim_node.visible = true
	await get_tree().create_timer(sec).timeout
	_lamp.dim_node.visible = false
	_lamp.set_process(true)


func _shake(amp: int, sec: float) -> void:
	_shake_amp = maxi(_shake_amp if _shake_left > 0.0 else 0, amp)
	_shake_left = maxf(_shake_left, sec)


# --- text helpers --------------------------------------------------------

func _type(node: Control, length: int) -> void:
	_typing_node = node
	_shown = 0
	_set_ratio(node, 0.0)
	_typing = create_tween()
	_typing.tween_method(func(r: float) -> void: _set_ratio(node, r), 0.0, 1.0, maxf(0.1, length / CHARS_PER_SEC))


func _set_ratio(node: Control, r: float) -> void:
	node.set("visible_ratio", r)


func _update_blips() -> void:
	if not (_typing and _typing.is_running()) or _typing_node == null:
		return
	var n: int = int(_typing_node.get("visible_characters"))
	var text: String = _typing_node.get_parsed_text() if _typing_node is RichTextLabel else str(_typing_node.get("text"))
	if n < 0:
		n = text.length()
	while _shown < n and _shown < text.length():
		var c: String = text[_shown]
		_shown += 1
		if _shown % 2 == 0 and c.strip_edges() != "" and not c in PUNCT:
			if _blip_phone:
				Audio.blip_phone(_pitch)
			else:
				Audio.blip(_pitch)


## Shows the current page of the current line (speech or thought) with typing.
func _show_page() -> void:
	var s: String = _pages[_page]
	if _page_is_thought:
		_thought.show_text(s)
		return
	if _page_is_fyodor:
		_fyodor_text.text = _fyodor_fmt % s
		_type(_fyodor_text, s.length())
	else:
		_alexei_text.text = s
		_type(_alexei_text, s.length())
	if "!" in s and _page > 0:
		_shake(1 + int(_tension * 2.0), 0.25)


func _hide_speech() -> void:
	_fade(_fyodor_box, 0.0)
	_fade(_alexei_box, 0.0)


func _fade(node: CanvasItem, to: float) -> void:
	create_tween().tween_property(node, "modulate:a", to, 0.25)
