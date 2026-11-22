class_name Cover
extends StaticBody3D
## 3D-укрытие (2.5D): слой 4 — блокирует пули игрока.
## CoverZone (слой 7) замечает игрока рядом и регистрирует укрытие у него; игрок прячется за
## укрытие, отходя вглубь по Z на cover_depth_offset. Разрушаемое укрытие темнеет от попаданий
## и исчезает на нуле HP.

signal hit_blocked
signal damaged(hp_left: int)
signal destroyed(cover: Cover)

@export var max_hp: int = 4
@export var is_destructible: bool = true
@export var cover_depth_offset: float = -0.55
@export var cover_size: Vector3 = Vector3(1.4, 1.05, 0.45)
## Цвет корпуса: ящик — коричневый, бетон — серый (задаётся в сцене).
@export var body_color: Color = Color(0.62, 0.62, 0.66, 1)
## Насколько зона захвата игрока шире и глубже самого укрытия (м), чтобы хватало стоять на lane_z.
@export var zone_padding: Vector2 = Vector2(0.7, 0.9)

var hp: int = 0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _zone: Area3D = $CoverZone
@onready var _zone_shape: CollisionShape3D = $CoverZone/CollisionShape3D

var _material: StandardMaterial3D
var _base_color: Color = Color.WHITE


func _ready() -> void:
	hp = max_hp
	_build_geometry()
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)


## Размеры из @export применяем к мешу и обеим формам (у каждой сцены свои копии ресурсов).
func _build_geometry() -> void:
	var box: BoxMesh = _mesh.mesh.duplicate() as BoxMesh
	box.size = cover_size
	_mesh.mesh = box
	_mesh.position = Vector3(0, cover_size.y * 0.5, 0)
	_material = StandardMaterial3D.new()
	_base_color = body_color
	_material.albedo_color = _base_color
	_material.roughness = 0.9
	_mesh.material_override = _material

	var body_shape: BoxShape3D = BoxShape3D.new()
	body_shape.size = cover_size
	_shape.shape = body_shape
	_shape.position = Vector3(0, cover_size.y * 0.5, 0)

	var zone_shape: BoxShape3D = BoxShape3D.new()
	zone_shape.size = Vector3(cover_size.x + zone_padding.x, cover_size.y, cover_size.z + zone_padding.y)
	_zone_shape.shape = zone_shape
	_zone_shape.position = Vector3(0, cover_size.y * 0.5, 0)


## Пуля или враг: разрушаемое теряет HP и темнеет, неразрушаемое просто блокирует.
func take_hit(amount: int = 1) -> void:
	if amount <= 0:
		return
	if not is_destructible:
		hit_blocked.emit()
		return
	hp = maxi(0, hp - amount)
	damaged.emit(hp)
	_apply_damage_tint()
	if hp == 0:
		destroyed.emit(self)
		queue_free()


func _apply_damage_tint() -> void:
	if _material == null:
		return
	var k: float = 0.0
	if max_hp > 0:
		k = clampf(1.0 - float(hp) / float(max_hp), 0.0, 1.0)
	_material.albedo_color = _base_color.darkened(k * 0.55)


## Стоя на lane_z, игрок попадает в зону укрытия (зона шире и глубже корпуса).
func _on_body_entered(body: Node3D) -> void:
	if body != null and body.has_method("register_cover"):
		body.register_cover(self)


func _on_body_exited(body: Node3D) -> void:
	if body != null and body.has_method("unregister_cover"):
		body.unregister_cover(self)
