extends Area3D

@export var speed: float = 20.0
@export var lifespan: float = 5.0
@export var dmg: float = 5.0

func _ready() -> void:
	get_tree().create_timer(lifespan).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	var forward = -global_transform.basis.z
	global_position += forward * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_dmg"):
		body.take_dmg(dmg)
	
	queue_free()
