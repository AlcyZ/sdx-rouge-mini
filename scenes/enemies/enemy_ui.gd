class_name EnemyUI extends SubViewport

@export var health_bar: ProgressBar

func update_health(current: float, total: float):
	health_bar.max_value = total
	health_bar.value = current
