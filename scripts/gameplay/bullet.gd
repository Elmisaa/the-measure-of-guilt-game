class_name Bullet
extends Area2D
## Пуля: летит по направлению direction со скоростью speed и сама удаляется.

@export var speed: float = 300.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	rotation = direction.angle()
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
