class_name SkeletonMinionStateMachine extends RefCounted

var _state: SkeletonState

func _init(state: SkeletonState) -> void:
	_state = state

static func start_walking(
	minion: SkeletonMinion,
	walking_speed: float,
	wait_time: float,
) -> SkeletonMinionStateMachine:
	var controller = PatrolController.new(minion)
	controller.init_patrol_point()
	
	var data =  StateData.new(minion, walking_speed, wait_time, controller)
	var state = WalkingState.new(data)
	
	return SkeletonMinionStateMachine.new(state)

func process(delta: float) -> void:
	var new_state = _state.process(delta)
	if new_state != null:
		_state = new_state

class SkeletonState:
	func process(_delta: float) -> SkeletonState:
		return null

class WalkingState extends SkeletonState:
	var _data: StateData
	
	func _init(data: StateData) -> void:
		_data = data
	
	func process(delta: float) -> SkeletonState:
		if _data.minion.agent.is_navigation_finished():
			_data.minion.velocity.x = move_toward(_data.minion.velocity.x, 0, _data.walking_speed)
			_data.minion.velocity.z = move_toward(_data.minion.velocity.z, 0, _data.walking_speed)
			
			if abs(_data.minion.velocity.x) < 0.01 and abs(_data.minion.velocity.z) < 0.01:
				return WaitingState.new(_data)
			else:
				return null
		
		var next_pos = _data.minion.agent.get_next_path_position()
		var dir = (next_pos - _data.minion.global_position).normalized()
		dir.y = 0
		_data.minion.velocity = dir * _data.walking_speed
		
		_look_at(dir, delta)
		
		return null
		
	func _look_at(direction: Vector3, delta: float) -> void:
		var target_rotation = atan2(direction.x, direction.z)
		_data.minion.pivot.rotation.y = lerp_angle(_data.minion.pivot.rotation.y, target_rotation, delta * 10.5)

class WaitingState extends SkeletonState:
	var _data: StateData
	var _wait_time: float
	
	func _init(data: StateData) -> void:
		_data = data
		_wait_time = data.wait_time
	
	func process(delta: float) -> WalkingState:
		_wait_time -= delta
		if _wait_time <= 0:
			_data.controller.next_patrol_point()
			return WalkingState.new(_data)
		return null

class StateData:
	var wait_time: float
	var minion: SkeletonMinion
	var walking_speed: float
	var controller: PatrolController
	
	func _init(
		p_minion: SkeletonMinion,
		p_walking_speed: float,
		p_wait_time: float,
		p_controller: PatrolController,
	) -> void:
		minion = p_minion
		walking_speed = p_walking_speed
		wait_time = p_wait_time
		controller = p_controller

class PatrolController:
	var _minion: SkeletonMinion
	var _patrol_point_size: int
	var _patrol_index = 0
	
	func _init(minion: SkeletonMinion) -> void:
		_minion = minion
		_patrol_point_size = minion.patrol_points.size()
	
	func next_patrol_point():
		if _patrol_index + 1 >= _patrol_point_size:
			_patrol_index = 0
		else:
			_patrol_index += 1
		
		var patrol_point = _minion.patrol_points[_patrol_index]
		_minion.agent.target_position = patrol_point.global_position

	func init_patrol_point() -> void:
		if _patrol_point_size == 0:
			return
	
		_patrol_index = 0
		var patrol_point = _minion.patrol_points[_patrol_index]
		_minion.agent.target_position = patrol_point.global_position
