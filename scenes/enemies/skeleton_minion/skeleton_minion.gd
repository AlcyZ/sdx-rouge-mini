class_name SkeletonMinion extends CharacterBody3D

@export_group("Skeleton properties")
@export var data: EnemyData

@export_group("Patrol settings")
@export var wait_time: float = 5.0
@export var patrol_points: Array[Marker3D]

@export_group("Animation - General")
@export var anim_tree: AnimationTree
@export var path_playback_full_body: String
@export var path_playback_upper_body: String
@export var path_full_body_locomotion_blend: String
@export var path_upper_body_blend2: String

@export_group("Animation - State names")
@export var state_full_body_death: String

@export_group("Animation - Oneshot")
@export var path_oneshot_hit_weak: String
@export var path_oneshot_hit_strong: String
@export var path_oneshot_spawn_air: String
@export var path_oneshot_spawn_ground: String

@export_group("Animation - Thresholds")
@export var threshold_hit_strong: float = 12.5

@onready var pivot: Node3D = $Pivot
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var ui: EnemyUI = $EnemyViewport

var state_machine: SkeletonMinionStateMachine
var anim: Animator
var processor: Processor
var stats: EnemyStats

func _ready() -> void:
	state_machine = SkeletonMinionStateMachine.start_walking(
		self,
		data.walking_speed,
		wait_time,
	)
	anim = Animator.Factory.create_animator(
		anim_tree,
		path_playback_full_body,
		path_playback_upper_body,
		self,
		path_full_body_locomotion_blend,
		path_upper_body_blend2,
		path_oneshot_hit_weak,
		path_oneshot_hit_strong,
		path_oneshot_spawn_air,
		path_oneshot_spawn_ground,
	)
	processor = Processor.create(self, anim.blender)
	stats = EnemyStats.from_data(data)
	
	if ui is EnemyUI:
		stats.health_changed.connect(ui.update_health)
	stats.hp_reached_zero.connect(on_die)

func take_dmg(value: float) -> void:
	stats.take_dmg(value)
	
	if value >= threshold_hit_strong:
		anim.oneshot_hit_strong()
	else:
		anim.oneshot_hit_weak()

func on_die() -> void:
	print("oh nein ich muss sterben!")

func _physics_process(delta: float) -> void:
	processor.velicoty.process(delta)
	processor.blend.process(delta)
	move_and_slide()
	
class HasMinion extends RefCounted:
	var _minion: SkeletonMinion
		
	func _init(minion: SkeletonMinion) -> void:
		_minion = minion

class Processor:
	var velicoty: Velocity
	var blend: Blend
	
	func _init(p_velicoty: Velocity, p_blend: Blend) -> void:
		velicoty = p_velicoty
		blend = p_blend
	
	static func create(minion: SkeletonMinion, blender: SkeletonMinion.Animator.Blender):
		var arg_velicoty = Velocity.new(minion)
		var arg_blend = Blend.new(minion, blender)
		
		return Processor.new(arg_velicoty, arg_blend)
	
	class Velocity extends HasMinion:
		func process(delta: float) -> void:
			_process_gravity(delta)
			_process_patrol(delta)
		
		func _process_gravity(delta: float) -> void:
			if not _minion.is_on_floor():
				_minion.velocity += _minion.get_gravity() * delta
		
		func _process_patrol(delta: float) -> void:
			_minion.state_machine.process(delta)
	
	class Blend extends HasMinion:
		var _blender: SkeletonMinion.Animator.Blender
		var _movement_blend := 0.0
		
		func _init(minion: SkeletonMinion, blender: SkeletonMinion.Animator.Blender) -> void:
			super(minion)
			_blender = blender
		
		func process(delta: float) -> void:
			var movement_blend_target = _get_speed() / _minion.data.running_speed
			_movement_blend = lerp(_movement_blend, movement_blend_target, delta * 10)
			_blender.blend_loco(_movement_blend)
		
		func _get_speed() -> float:
			return Vector3(_minion.velocity.x, 0, _minion.velocity.z).length()

class Animator:
	var _full_body_playback: AnimationUtil.Playback
	var _upper_body_playback: AnimationUtil.Playback
	var _tree: AnimationTree
	
	var blender: Blender
	var paths: Paths
	
	func _init(
		full_body_playback: AnimationUtil.Playback,
		upper_body_playback: AnimationUtil.Playback,
		tree: AnimationTree,
		p_blender: Blender,
		p_paths: Paths,
	) -> void:
		_full_body_playback = full_body_playback
		_upper_body_playback = upper_body_playback
		_tree = tree
		blender = p_blender
		paths = p_paths
	
	func play_full_body(to_node: StringName, mode: AnimationUtil.Play = AnimationUtil.Play.Travel) -> void:
		_play(_full_body_playback, to_node, mode)
	
	func play_upper_body(to_node: StringName, mode: AnimationUtil.Play = AnimationUtil.Play.Travel) -> void:
		_play(_upper_body_playback, to_node, mode)
	
	func oneshot_hit_weak() -> void:
		_tree.set(paths.oneshot_hit_weak, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	func oneshot_hit_strong() -> void:
		_tree.set(paths.oneshot_hit_strong, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	func oneshot_spawn_air() -> void:
		_tree.set(paths.oneshot_hit, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	func oneshot_spawn_ground() -> void:
		_tree.set(paths.oneshot_hit, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	func _play(playback: AnimationUtil.Playback, to_node: StringName, mode: AnimationUtil.Play = AnimationUtil.Play.Travel):
		playback.play(to_node, mode)
	
	class Blender:
		var _minion: SkeletonMinion
		var _tree: AnimationTree
		var _paths: Paths
		
		func _init(minion: SkeletonMinion, tree: AnimationTree, paths: Paths) -> void:
			_minion = minion
			_tree = tree
			_paths = paths
		
		func blend_loco(value: float) -> void:
			_tree.set(_paths.full_body_locomotion, value)
		
		func blend2_upper_body(value: float, duration = 0.1) -> void:
			var tween = _minion.create_tween()
			tween.tween_property(_tree, _paths.upper_body_blend2, value, duration)
		
		func get_blend2_upper_body():
			return _tree.get(_paths.upper_body_blend2)
		
	class Paths:
		var full_body_locomotion: String
		var upper_body_blend2: String
		var oneshot_hit_weak: String
		var oneshot_hit_strong: String
		var oneshot_spawn_air: String
		var oneshot_spawn_ground: String
		
		func _init(
			p_full_body_locomotion: String,
			p_upper_body_blend2: String,
			p_oneshot_hit_weak: String,
			p_oneshot_hit_strong: String,
			p_oneshot_spawn_air: String,
			p_oneshot_spawn_ground: String,
		) -> void:
			full_body_locomotion = p_full_body_locomotion
			upper_body_blend2 = p_upper_body_blend2
			oneshot_hit_weak = p_oneshot_hit_weak
			oneshot_hit_strong = p_oneshot_hit_strong
			oneshot_spawn_air = p_oneshot_spawn_air
			oneshot_spawn_ground = p_oneshot_spawn_ground
	
	class Factory:
		static func create_animator(
			anim_tree: AnimationTree,
			path_playback_full_body: String,
			path_playback_upper_body: String,
			minion: SkeletonMinion,
			path_full_body_locomotion: String,
			path_upper_body_blend2: String,
			path_oneshot_hit_weak: String,
			path_oneshot_hit_strong: String,
			path_oneshot_spawn_air: String,
			path_oneshot_spawn_ground: String,
		) -> Animator:
			var full_body_playback = anim_tree.get(path_playback_full_body)
			var right_arm_playback = anim_tree.get(path_playback_upper_body)
			var prefix = "[ERROR][Animator.Factory::create_animator('%s', '%s')]" % [path_playback_full_body, path_playback_upper_body]
			
			assert(full_body_playback != null, "%s - full_body playback not found at '%s'" % [prefix, path_playback_full_body])
			assert(right_arm_playback != null, "%s - right_arm playback not found at '%s'" % [prefix, path_playback_upper_body])
			
			full_body_playback = AnimationUtil.Playback.new(full_body_playback)
			right_arm_playback = AnimationUtil.Playback.new(right_arm_playback)
			
			var paths = Animator.Paths.new(
				path_full_body_locomotion,
				path_upper_body_blend2,
				path_oneshot_hit_weak,
				path_oneshot_hit_strong,
				path_oneshot_spawn_air,
				path_oneshot_spawn_ground,
			)
			var blender = Animator.Blender.new(minion, anim_tree, paths)
			
			return Animator.new(full_body_playback, right_arm_playback, anim_tree, blender, paths)
