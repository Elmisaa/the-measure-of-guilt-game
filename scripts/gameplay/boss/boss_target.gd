class_name BossTarget
extends Area3D

signal hit

@export var blink_duration: float = 0.2

var _mesh: MeshInstance3D
var _blink_timer: Timer
var _original_color: Color
var _hit_count: int = 0

func _ready() -> void:
	collision_layer = 128
	collision_mask = 1 | 4 | 128
	
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh != null and _mesh.material_override is StandardMaterial3D:
		_original_color = (_mesh.material_override as StandardMaterial3D).albedo_color
	
	_blink_timer = get_node_or_null("BlinkTimer") as Timer
	if _blink_timer == null:
		_blink_timer = Timer.new()
		_blink_timer.name = "BlinkTimer"
		add_child(_blink_timer)
	_blink_timer.one_shot = true
	_blink_timer.wait_time = blink_duration
	if not _blink_timer.timeout.is_connected(_on_blink_timeout):
		_blink_timer.timeout.connect(_on_blink_timeout)
	
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if area is Bullet:
		take_bullet_hit()

func take_bullet_hit() -> void:
	_hit_count += 1
	print("HIT #", _hit_count)
	hit.emit()
	_start_blink()

func _start_blink() -> void:
	if _mesh == null:
		return
	var mat: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		_mesh.material_override = mat
	mat.albedo_color = Color(1, 1, 0, 1)
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 0, 1)
	mat.emission_energy_multiplier = 5.0
	_blink_timer.start()

func _on_blink_timeout() -> void:
	if _mesh != null and _mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
		mat.albedo_color = _original_color
		mat.emission_enabled = false