class_name WalkPlayer
extends Node2D

signal moved(x: float)

@export var sheet: Texture2D
@export var frames: int = 10
@export var depth_rows: int = 1
@export var speed: float = 130.0
@export var run_speed: float = 315.0
@export var grid: float = 4.0
@export var run_sheet: Texture2D
@export var run_frames: int = 8
@export var run_fps: float = 18.0
@export var run_seconds: float = 14.0
@export var recover_seconds: float = 7.0
const RUN_AGAIN: float = 0.35
const RECOVER_DELAY: float = 0.7
const BREATH: String = "res://assets/audio/sfx/breath.wav"

var y_far: float = 346.0
var y_near: float = 346.0
var scale_far: float = 1.0
@export var depth_speed: float = 40.0
var min_x: float = 0.0
var max_x: float = 2000.0
var frozen: bool = false

const COAT_WALK: String = "res://assets/characters/alexei/walk_side_depth_coat.png"
const COAT_RUN: String = "res://assets/characters/alexei/run_side_depth_coat.png"

var _sprite: Sprite2D
var _plain_sheet: Texture2D
var _plain_run: Texture2D
var _t: float = 0.0
var _walking: bool = false
var _row: int = 0
var _running: bool = false
var _winded: bool = false
var _rest: float = 0.0
var _gs: Node
var _hud: Node


func _ready() -> void:
	_ensure_actions()
	_gs = get_node_or_null("/root/GameState")
	_hud = get_node_or_null("/root/Hud")
	_sprite = Sprite2D.new()
	_sprite.texture = sheet
	_sprite.hframes = frames
	_sprite.vframes = depth_rows
	_sprite.centered = true
	_sprite.offset = Vector2(0, -sheet.get_height() / float(depth_rows) / 2.0)
	add_child(_sprite)
	_plain_sheet = sheet
	_plain_run = run_sheet
	if _gs != null and bool(_gs.get_flag("coat_on", false)):
		set_coat(true)


func set_coat(on: bool) -> void:
	if on and not (ResourceLoader.exists(COAT_WALK) and ResourceLoader.exists(COAT_RUN)):
		return
	var was_run: bool = _sprite.texture == run_sheet and run_sheet != null
	sheet = load(COAT_WALK) if on else _plain_sheet
	run_sheet = load(COAT_RUN) if on else _plain_run
	_sprite.texture = null
	_set_sheet(was_run)


func _ensure_actions() -> void:
	for pair: Array in [["move_left", [KEY_A, KEY_LEFT]], ["move_right", [KEY_D, KEY_RIGHT]], ["move_up", [KEY_W, KEY_UP]], ["move_down", [KEY_S, KEY_DOWN]], ["interact", [KEY_E]], ["run", [KEY_SHIFT]]]:
		var action: String = pair[0]
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in pair[1]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	var stop: bool = frozen or (_hud != null and _hud.is_blocking())
	var dir: float = 0.0 if stop else Input.get_axis("move_left", "move_right")
	var vdir: float = 0.0 if stop or y_far == y_near else Input.get_axis("move_up", "move_down")
	_walking = absf(dir) > 0.1 or absf(vdir) > 0.1
	_running = _walking and Input.is_action_pressed("run") and not _winded
	_update_stamina(delta)
	if absf(dir) > 0.1:
		position.x = clampf(position.x + dir * (run_speed if _running else speed) * delta, min_x, max_x)
		_sprite.flip_h = dir < 0.0
		moved.emit(position.x)
	if absf(vdir) > 0.1:
		position.y = clampf(position.y + vdir * depth_speed * delta, y_far, y_near)
	_apply_depth()
	_t += delta
	if _running and run_sheet != null:
		_set_sheet(true)
		_sprite.frame = _row * run_frames + int(_t * run_fps) % run_frames
	else:
		_set_sheet(false)
		var col: int = 2 + int(_t * (18.0 if _running else 13.0)) % (frames - 2) if _walking else int(_t * 1.5) % 2
		_sprite.frame = _row * frames + col
	_sprite.position.x = roundf(position.x / grid) * grid - position.x


func _set_sheet(run: bool) -> void:
	_set_sheet_tex(run_sheet if run else sheet, run_frames if run else frames)


func _set_sheet_tex(tex: Texture2D, n: int) -> void:
	if _sprite.texture == tex:
		return
	_sprite.texture = tex
	_sprite.hframes = n
	_sprite.vframes = depth_rows


func _update_stamina(delta: float) -> void:
	if _gs == null:
		return
	if _running:
		_rest = 0.0
		_gs.stamina -= delta / run_seconds
		if _gs.stamina <= 0.0:
			_winded = true
			_running = false
			var audio: Node = get_node_or_null("/root/Audio")
			if audio:
				audio.sfx(BREATH, -10.0, randf_range(0.95, 1.05))
	else:
		_rest += delta
		if _rest >= RECOVER_DELAY:
			_gs.stamina += delta / recover_seconds
	if _winded and _gs.stamina >= RUN_AGAIN:
		_winded = false


func is_winded() -> bool:
	return _winded


func _apply_depth() -> void:
	if y_far == y_near or depth_rows <= 1:
		return
	var k: float = clampf((position.y - y_far) / (y_near - y_far), 0.0, 1.0)
	_row = clampi(int(roundf((1.0 - k) * float(depth_rows - 1))), 0, depth_rows - 1)
	z_index = int(position.y)


func is_running() -> bool:
	return _running


func depth_row() -> int:
	return _row


func face_right(v: bool) -> void:
	_sprite.flip_h = not v


func is_walking() -> bool:
	return _walking
