class_name ExplorePlayer3D
extends CharacterBody3D

signal moved(x: float)

const WALK_SHEET: String = "res://assets/characters/alexei/story_walk_coat.png"
const RUN_SHEET: String = "res://assets/characters/alexei/story_run.png"

@export var speed: float = 1.6
@export var run_speed: float = 3.9
@export var min_x: float = -19.6
@export var max_x: float = 5.5
@export var z_far: float = 0.0
@export var z_near: float = 1.0
@export var depth_speed: float = 3.2
@export var floor_y: float = 0.0
@export var height_m: float = 2.10
@export var run_seconds: float = 14.0
@export var recover_seconds: float = 7.0
@export var tint: Color = Color.WHITE

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
	collision_layer = 0
	_gs = get_node_or_null("/root/GameState")
	_hud = get_node_or_null("/root/Hud")
	_walk_tex = load(WALK_SHEET)
	_run_tex = load(RUN_SHEET)
	_sprite = Sprite3D.new()
	_sprite.name = "AnimatedSprite"
	_sprite.texture = _walk_tex
	_sprite.hframes = 10
	_sprite.vframes = 3
	_sprite.pixel_size = height_m / 190.0
	_sprite.offset = Vector2(0, 100)
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = true
	_sprite.modulate = tint
	_sprite.double_sided = false
	add_child(_sprite)
	position.y = floor_y


func is_walking() -> bool:
	return _walking


func is_running() -> bool:
	return _running


func _physics_process(delta: float) -> void:
	var stop: bool = frozen or (_hud != null and _hud.is_blocking())
	var input: Vector2 = Vector2.ZERO if stop else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sprint: bool = Input.is_action_pressed("run") and not _winded
	var previous: Vector3 = position
	if not is_zero_approx(input.x):
		var target_x: float = clampf(position.x + input.x * (run_speed if sprint else speed) * delta, min_x, max_x)
		move_and_collide(Vector3(target_x - position.x, 0, 0))
		_sprite.flip_h = input.x < 0.0
	if not is_zero_approx(input.y):
		var target_z: float = clampf(position.z + input.y * depth_speed * (1.55 if sprint else 1.0) * delta, z_far, z_near)
		move_and_collide(Vector3(0, 0, target_z - position.z))
	_walking = previous.distance_squared_to(position) > 0.000001
	_running = _walking and sprint
	_update_stamina(delta)
	if not is_equal_approx(previous.x, position.x):
		moved.emit(position.x)
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
