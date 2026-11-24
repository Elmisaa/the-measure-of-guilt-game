class_name ExplosiveBarrel
extends Area3D

signal exploded(near_boss: bool, boss_damage: int, world_pos: Vector3)

@export var boss_damage: int = 25
@export var player_damage: int = 20
@export var blast_radius: float = 2.2
@export var near_boss: bool = true

var _body: Node3D
var _target_ring: MeshInstance3D
var _explosion_sphere: MeshInstance3D
var _explosion_timer: Timer
var _is_exploding: bool = false

func _ready() -> void:
	collision_layer = 128
	collision_mask = 1 | 4 | 128
	add_to_group("boss_targets")
	
	var mesh: MeshInstance3D = get_node_or_null("Body")
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = preload("res://assets/3d/factory/workshop/art/02_red_drum.png")
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = 1.0 / sprite.texture.get_height()
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(sprite)
	if mesh:
		sprite.position = mesh.position
		mesh.hide()
	_body = sprite
	_target_ring = get_node_or_null("TargetRing") as MeshInstance3D
	_explosion_sphere = get_node_or_null("ExplosionSphere") as MeshInstance3D
	
	if _explosion_sphere != null:
		_explosion_sphere.visible = false
	
	_explosion_timer = get_node_or_null("ExplosionTimer") as Timer
	if _explosion_timer == null:
		_explosion_timer = Timer.new()
		_explosion_timer.name = "ExplosionTimer"
		add_child(_explosion_timer)
	_explosion_timer.one_shot = true
	_explosion_timer.wait_time = 0.25
	if not _explosion_timer.timeout.is_connected(_on_explosion_timeout):
		_explosion_timer.timeout.connect(_on_explosion_timeout)
	


func take_bullet_hit(_dmg: int = 0) -> void:
	if _is_exploding:
		return
	_is_exploding = true
	get_node("/root/Audio").sfx("res://assets/audio/story/vzryv.wav", -8.0)
	
	remove_from_group("boss_targets")
	
	if _target_ring != null:
		_target_ring.visible = false
	if _body != null:
		_body.visible = false
	
	if _explosion_sphere != null:
		_explosion_sphere.visible = true
		var mat: StandardMaterial3D = _explosion_sphere.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			_explosion_sphere.material_override = mat
		mat.albedo_color = Color(1, 0.5, 0.0, 0.8)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.4, 0.0, 1)
		mat.emission_energy_multiplier = 10.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	_explosion_timer.start()
	
	_damage_player_in_radius()
	
	exploded.emit(near_boss, boss_damage, global_position)

func _damage_player_in_radius() -> void:
	var p: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if p != null and p.global_position.distance_to(global_position) <= blast_radius and p.has_method("take_damage"):
		p.call("take_damage", player_damage)

func _on_explosion_timeout() -> void:
	if _explosion_sphere != null:
		_explosion_sphere.visible = false
	queue_free()
