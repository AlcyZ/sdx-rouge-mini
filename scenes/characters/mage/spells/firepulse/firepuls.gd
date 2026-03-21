extends Area3D

@export var dmg := 30.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_dmg"):
		body.take_dmg(dmg)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Init":
		queue_free()
