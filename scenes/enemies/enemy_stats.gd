class_name EnemyStats extends RefCounted

signal hp_reached_zero()
signal health_changed(current: float, total: float)

var _max_health: float
var _current_health: float

func _init(max_health: float, current_health: float) -> void:
	_max_health = max_health
	_current_health = current_health

static func from_data(data: EnemyData) -> EnemyStats:
	return EnemyStats.new(data.max_health, data.max_health)

func take_dmg(value: float) -> void:
	if _current_health <= 0: return
	_apply_health_modifier(-value)

func heal(value: float) -> void:
	_apply_health_modifier(value)

func _apply_health_modifier(delta: float) -> void:
	var old = _current_health
	_current_health = clamp(_current_health + delta, 0, _max_health)
	
	if old != _current_health:
		health_changed.emit(_current_health, _max_health)
		
		if _current_health <= 0:
			hp_reached_zero.emit()
