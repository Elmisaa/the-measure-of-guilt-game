class_name ExplorePlayer3D
extends Node3D

signal moved(x: float)

const WALK_SHEET: String = "res://assets/characters/alexei/walk_side_depth_coat.png"
const RUN_SHEET: String = "res://assets/characters/alexei/run_side_depth_coat.png"
const PLAIN_WALK: String = "res://assets/characters/alexei/walk_side_depth.png"
const PLAIN_RUN: String = "res://assets/characters/alexei/run_side_depth.png"

@export var speed: float = 1.6
@export var run_speed: float = 3.9
@export var min_x: float = -19.6
@export var max_x: float = 5.5
@export var z_far: float = 0.0
@export var z_near: float = 1.0
@export var depth_speed: float = 0.5
@export var floor_y: float = 0.0
@export var height_m: float = 2.3
@export var run_seconds: float = 14.0
@export var recover_seconds: float = 7.0
@export var tint: Color = Color(0.78, 0.78, 0.86)

var frozen: bool = false

var _sprite: Sprite3D
var _walk_tex: Texture2D
var _run_tex: Texture2D
var _t: float = 0.0
var _walking: bool = false
var _running: bool = false
var _winded: bool = false
var _rest: float = 0.0
var _row: int = 0
var _gs: Node
var _hud: Node


func _ready() -> void:
	_ensure_actions()
	_gs = get_node_or_null("/root/GameState")
	_hud = get_node_or_null("/root/Hud")
	var coat: bool = _gs == null or bool(_gs.get_flag("coat_on", true))
	_walk_tex = load(WALK_SHEET if coat else PLAIN_WALK)
	_run_tex = load(RUN_SHEET if coat else PLAIN_RUN)
	_sprite = Sprite3D.new()
	_sprite.texture = _walk_tex
	_sprite.hframes = 10
	_sprite.vframes = 3
	_sprite.pixel_size = height_m / 190.0
	_sprite.offset = Vector2(0, 100)
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = false
	_sprite.modulate = tint
	_sprite.double_sided = false
	add_child(_sprite)
	position.y = floor_y


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


func is_walking() -> bool:
	return _walking


func is_running() -> bool:
	return _running


func _process(delta: float) -> void:
	var stop: bool = frozen or (_hud != null and _hud.is_blocking())
	var dir: float = 0.0 if stop else Input.get_axis("move_left", "move_right")
	var vdir: float = 0.0 if stop else Input.get_axis("move_up", "move_down")
	_walking = absf(dir) > 0.1 or absf(vdir) > 0.1
	_running = _walking and Input.is_action_pressed("run") and not _winded
	_update_stamina(delta)
	if absf(dir) > 0.1:
		position.x = clampf(position.x + dir * (run_speed if _running else speed) * delta, min_x, max_x)
		_sprite.flip_h = dir < 0.0
		moved.emit(position.x)
	if absf(vdir) > 0.1:
		position.z = clampf(position.z + vdir * depth_speed * delta, z_far, z_near)
	var k: float = 0.0 if z_near == z_far else (position.z - z_far) / (z_near - z_far)
	_row = clampi(int(roundf((1.0 - k) * 2.0)), 0, 2)
	_t += delta
	if _running:
		_set_tex(_run_tex, 8)
		_sprite.frame = _row * 8 + int(_t * 18.0) % 8
	else:
		_set_tex(_walk_tex, 10)
		var col: int = 2 + int(_t * 13.0) % 8 if _walking else int(_t * 1.5) % 2
		_sprite.frame = _row * 10 + col


func _set_tex(tex: Texture2D, n: int) -> void:
	if _sprite.texture == tex:
		return
	_sprite.texture = tex
	_sprite.hframes = n
	_sprite.vframes = 3


func _update_stamina(delta: float) -> void:
	if _gs == null:
		return
	if _running:
		_rest = 0.0
		_gs.stamina -= delta / run_seconds
		if _gs.stamina <= 0.0:
			_winded = true
			_running = false
	else:
		_rest += delta
		if _rest > 0.6:
			_gs.stamina += delta / recover_seconds
		if _winded and _gs.stamina >= 0.35:
			_winded = false
