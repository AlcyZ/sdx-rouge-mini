class_name SkeletonMinionStateMachine extends RefCounted

var _handler: StateHandler

func _init(handler: StateHandler) -> void:
	_handler = handler

static func start_walking(
	minion: SkeletonMinion,
	walking_speed: float,
	wait_time: float,
) -> SkeletonMinionStateMachine:
	var controller = PatrolController.new(minion)
	controller.init_patrol_point()
	
	var data =  States.Data.new(minion, walking_speed, wait_time, controller)
	
	var walking_state = States.Alive.Walking.new(data)
	var waiting_state = States.Alive.Waiting.new(data)
	
	var alive_state = States.Alive.new(walking_state)
	var alive_handler = StateHandler.Alive.new(alive_state)
	
	var dead_state = States.Dead.new(data)
	var dead_handler = StateHandler.Dead.new(alive_handler, minion, dead_state)
	
	var registry = States.Registry.new(walking_state, waiting_state)
	var handler = StateHandler.new(dead_handler, registry)
	
	return SkeletonMinionStateMachine.new(handler)

func process(delta: float) -> void:
	_handler.handle(delta)

class SkeletonState:
	func process(_delta: float) -> SkeletonState:
		return null

class States:
	class Data:
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
	
	class Registry:
		var walking: Alive.Walking
		var wating: Alive.Waiting
		
		func _init(
			p_walking: Alive.Walking,
			p_wating: Alive.Waiting,
		) -> void:
			walking = p_walking
			wating = p_wating
	
	class Base:
		func process(_delta: float, _registry: Registry) -> Base: return null
		func enter() -> void: pass
	
	class Alive:
		var _state: Base
		
		func _init(state: Base) -> void:
			_state = state
		
		func process(delta: float, registry: Registry) -> void:
			var new_state = _state.process(delta, registry)
			if new_state != null:
				_state = new_state
				_state.enter()
		
		class Walking extends Base:
			var _data: Data
			
			func _init(data: Data) -> void:
				_data = data
			
			func process(delta: float, registry: Registry) -> Base:
				if _data.minion.agent.is_navigation_finished():
					_data.minion.velocity.x = move_toward(_data.minion.velocity.x, 0, _data.walking_speed)
					_data.minion.velocity.z = move_toward(_data.minion.velocity.z, 0, _data.walking_speed)
					
					if abs(_data.minion.velocity.x) < 0.01 and abs(_data.minion.velocity.z) < 0.01:
						return registry.wating
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
		
		class Waiting extends Base:
			var _data: Data
			var _wait_time: float
			
			func _init(data: Data) -> void:
				_data = data
				_wait_time = data.wait_time
			
			func enter() -> void:
				_wait_time = _data.wait_time
			
			func process(delta: float, registry: Registry) -> Walking:
				_wait_time -= delta
				if _wait_time <= 0:
					_data.controller.next_patrol_point()
					return registry.walking
				return null
	
	class Dead extends Base:
		var _data: Data
		
		func _init(data: Data) -> void:
			_data = data
		
		func process(_delta: float, _registry: Registry) -> Base:
			if _data.minion.velocity.length() > 0:
				_data.minion.velocity = Vector3.ZERO
			return null

class StateHandler:
	var _root: BaseHandler
	var _registry: States.Registry
	
	func _init(root: BaseHandler, registry: States.Registry) -> void:
		_root = root
		_registry = registry
	
	func handle(delta: float) -> void:
		_root.handle(delta, _registry)
	
	class BaseHandler:
		func handle(_delta: float, _registry: States.Registry) -> void: push_error("[SkeletonMinionStateMachine::StateHandler::BaseHandler.handle()] - must be overriden!")
	
	class Alive extends BaseHandler:
		var _state: States.Alive
		
		func _init(state: States.Alive) -> void:
			_state = state
		
		func handle(delta: float, registry: States.Registry) -> void:
			_state.process(delta, registry)
	
	class Dead extends BaseHandler:
		var _next: Alive
		var _minion: SkeletonMinion
		var _state: States.Dead
		
		func _init(next: Alive, minion: SkeletonMinion, state: States.Dead) -> void:
			_next = next
			_minion = minion
			_state = state
		
		func handle(delta: float, registry: States.Registry):
			if _minion.is_alive():
				_next.handle(delta, registry)
				return
			_state.process(delta, registry)

class PatrolController:
	var _minion: SkeletonMinion
	var _patrol_point_size: int
	var _patrol_index = 0
	
	func _init(minion: SkeletonMinion) -> void:
		_minion = minion
		_patrol_point_size = minion.patrol_points.size()
	
	func next_patrol_point():
		if _patrol_point_size == 0:
			return
		
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
