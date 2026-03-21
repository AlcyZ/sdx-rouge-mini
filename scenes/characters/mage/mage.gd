class_name MageCharacter extends CharacterBody3D

signal health_changed(current: float, total: float)
signal mana_changed(current: float, total: float)
signal casting_started()
signal casting_end()
signal casting_progressed(current: float, total: float)

@export_group("Player properties")
@export var max_speed = 5.0
@export var look_at_weight := 10.0

@export_group("Spell resources")
@export var firebolt_data: SpellResource
@export var firepulse_data: SpellResource
@export var meteor_data: SpellResource

@export_group("Camera")
@export var camera_node: ThirdPersonCam

@export_group("Animation - General")
@export var anim_tree: AnimationTree
@export var path_playback_full_body: String
@export var path_playback_upper_body: String
@export var path_full_body_locomotion_blend: String
@export var path_upper_body_blend2: String

@export_group("Animation - data")
@export var animation_shoot: SpellAnimationData
@export var animation_raise: SpellAnimationData

@onready var pivot := $Pivot
@onready var wandspawn_node := $Pivot/Rig_Medium/Skeleton3D/Mage_HandslotRight/Mage_WeaponContainerRight/Mage_Wand/Mage_WandSpawn
@onready var aim_decal := $AimTarget

var stats: Stats

var queue: SimpleQueue
var conditional_queue: ConditionalQueue
var lock: SimpleLock

var anim: Animator
var processor: Processor

var abilities: MageAbilities

func _ready() -> void:
	stats = Stats.new(self)
	queue = SimpleQueue.new()
	conditional_queue = ConditionalQueue.new()
	lock = SimpleLock.new()
	
	anim = Animator.Factory.create_animator(
		anim_tree,
		path_playback_full_body,
		path_playback_upper_body,
		self,
		path_full_body_locomotion_blend,
		path_upper_body_blend2,
	)
	processor = Processor.new(self, anim.blender)
	
	abilities = MageAbilities.create(self,  [animation_shoot.state_name, animation_raise.state_name])

func notify_health_changed(current: float, total: float) -> void:
	health_changed.emit(current, total)

func notify_mana_changed(current: float, total: float) -> void:
	mana_changed.emit(current, total)

func notify_casting_started() -> void:
	casting_started.emit()

func notify_casting_end() -> void:
	casting_end.emit()

func notify_casting_progressed(current: float, total: float) -> void:
	casting_progressed.emit(current, total)

func _process(delta: float) -> void:
	conditional_queue.process(delta)
	abilities.preparing(delta)

func _unhandled_input(event: InputEvent) -> void:
	processor.input.handle(event)

func _physics_process(delta: float) -> void:
	processor.velocity.process(delta)
	processor.blend.process(delta)
	move_and_slide()

func _physics_process_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

class HasMage extends RefCounted:
	var _mage: MageCharacter
		
	func _init(mage: MageCharacter) -> void:
		_mage = mage

class Processor:
	var input: InputHandler
	var velocity: Velocity
	var blend: Blend
	
	func _init(mage: MageCharacter, blender: MageCharacter.Animator.Blender):
		input = InputHandler.new(mage)
		velocity = Velocity.new(mage)
		blend = Blend.new(mage, blender)
	
	class InputHandler extends HasMage:
		func handle(event: InputEvent) -> void:
			if _mage.abilities.handle_input(event):
				_mage.get_viewport().set_input_as_handled()
				return
			
			if event.is_action_pressed("attack"):
				_mage.get_viewport().set_input_as_handled()
				_mage.abilities.prepare_spell(_mage.abilities.registry.pulse)
				return
			
			_mage.camera_node.handle_input(event)
		
		func use_skill(index: int) -> void:
			match index:
				0: _mage.abilities.prepare_spell(_mage.abilities.registry.bolt)
				1: print("Todo: implement skill 1")
				2: _mage.abilities.prepare_spell(_mage.abilities.registry.meteor)
	
	class Velocity extends HasMage:
		func process(delta: float) -> void:
			_process_gravity(delta)
			_process_movement(delta)
		
		func _process_gravity(delta: float) -> void:
			if not _mage.is_on_floor():
				_mage.velocity += _mage.get_gravity() * delta
		
		func _process_movement(delta: float) -> void:
			var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			var direction = _calculate_movement_direction(input_dir)
			
			if direction:
				_mage.velocity.x = direction.x * _mage.max_speed
				_mage.velocity.z = direction.z * _mage.max_speed
				_look_at(direction, delta)
			else:
				_mage.velocity.x = move_toward(_mage.velocity.x, 0, _mage.max_speed)
				_mage.velocity.z = move_toward(_mage.velocity.z, 0, _mage.max_speed)
		
		func _look_at(direction: Vector3, delta: float) -> void:
			var target_rotation = atan2(direction.x, direction.z)
			_mage.pivot.rotation.y = lerp_angle(_mage.pivot.rotation.y, target_rotation, delta * _mage.look_at_weight)
		
		func _calculate_movement_direction(input_dir: Vector2) -> Vector3:
			if _mage.camera_node == null:
				return (_mage.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			
			var cam_forward = _mage.camera_node.global_transform.basis.z
			cam_forward.y = 0
			cam_forward = cam_forward.normalized()
			
			var cam_right = _mage.camera_node.global_transform.basis.x
			cam_right.y = 0
			cam_right = cam_right.normalized()
			
			var direction = (cam_right * input_dir.x) + (cam_forward * input_dir.y)
			if direction.length() > 0:
				direction = direction.normalized()
			
			return direction
	
	class Blend extends HasMage:
		var _blender: MageCharacter.Animator.Blender
		var _movement_blend := 0.0
		
		func _init(mage: MageCharacter, blender: MageCharacter.Animator.Blender) -> void:
			super(mage)
			_blender = blender
		
		func process(delta: float) -> void:
			var movement_blend_target = _get_speed() / _mage.max_speed
			_movement_blend = lerp(_movement_blend, movement_blend_target, delta * 10)
			_blender.blend_loco(_movement_blend)
		
		func _get_speed() -> float:
			return Vector3(_mage.velocity.x, 0, _mage.velocity.z).length()

class Stats extends HasMage:
	var _max_health := 100.0
	var _max_mana := 100.0
	
	var _health := 100.0
	var _mana := 100.0
	
	func take_dmg(value: float) -> void:
		_health = max(_health - value, 0)
		_mage.notify_health_changed(_health, _max_health)
	
	func heal(value: float) -> void:
		_health = min(_health + value, _max_health)
		_mage.notify_health_changed(_health, _max_health)
	
	func use_mana(value: float) -> void:
		_mana = max(_mana - value, 0)
		_mage.notify_mana_changed(_mana, _max_mana)
	
	func restore_mana(value: float) -> void:
		_mana = min(_mana + value, _max_mana)
		_mage.notify_mana_changed(_mana, _max_mana)

class Animator:
	var _full_body_playback: AnimationUtil.Playback
	var _upper_body_playback: AnimationUtil.Playback
	
	var blender: Blender
	
	func _init(
		full_body_playback: AnimationUtil.Playback,
		upper_body_playback: AnimationUtil.Playback,
		p_blender: Blender
	) -> void:
		_full_body_playback = full_body_playback
		_upper_body_playback = upper_body_playback
		blender = p_blender
	
	func play_full_body(to_node: StringName, mode: AnimationUtil.Play = AnimationUtil.Play.Travel) -> void:
		_play(_full_body_playback, to_node, mode)
	
	func play_upper_body(to_node: StringName, mode: AnimationUtil.Play = AnimationUtil.Play.Travel) -> void:
		_play(_upper_body_playback, to_node, mode)
	
	func _play(playback: AnimationUtil.Playback, to_node: StringName, mode: AnimationUtil.Play = AnimationUtil.Play.Travel):
		playback.play(to_node, mode)
	
	func get_current_full_body_node() -> StringName:
		return _full_body_playback.get_current_node()
	
	func get_current_full_body_play_position():
		return _full_body_playback.get_current_play_position()
	
	func get_current_upper_body_node() -> StringName:
		return _upper_body_playback.get_current_node()
	
	func get_current_upper_body_play_position():
		return _upper_body_playback.get_current_play_position()
	
	class Blender:
		var _mage: MageCharacter
		var _tree: AnimationTree
		var _paths: Paths
		
		func _init(mage: MageCharacter, tree: AnimationTree, paths: Paths) -> void:
			_mage = mage
			_tree = tree
			_paths = paths
		
		func blend_loco(value: float) -> void:
			_tree.set(_paths.full_body_locomotion, value)
		
		func blend2_upper_body(value: float, duration = 0.1) -> void:
			var tween = _mage.create_tween()
			tween.tween_property(_tree, _paths.upper_body_blend2, value, duration)
		
		func get_blend2_upper_body():
			return _tree.get(_paths.upper_body_blend2)
		
		class Paths:
			var full_body_locomotion: String
			var upper_body_blend2: String
			
			func _init(
				p_full_body_locomotion: String,
				p_upper_body_blend2: String,
			) -> void:
				full_body_locomotion = p_full_body_locomotion
				upper_body_blend2 = p_upper_body_blend2
	
	class Factory:
		static func create_animator(
			anim_tree: AnimationTree,
			path_playback_full_body: String,
			path_playback_upper_body: String,
			mage: MageCharacter,
			path_full_body_locomotion: String,
			path_upper_body_blend2: String,
		) -> Animator:
			var full_body_playback = anim_tree.get(path_playback_full_body)
			var right_arm_playback = anim_tree.get(path_playback_upper_body)
			var prefix = "[ERROR][Animator.Factory::create_animator('%s', '%s')]" % [path_playback_full_body, path_playback_upper_body]
			
			assert(full_body_playback != null, "%s - full_body playback not found at '%s'" % [prefix, path_playback_full_body])
			assert(right_arm_playback != null, "%s - right_arm playback not found at '%s'" % [prefix, path_playback_upper_body])
			
			full_body_playback = AnimationUtil.Playback.new(full_body_playback)
			right_arm_playback = AnimationUtil.Playback.new(right_arm_playback)
			
			var paths = Animator.Blender.Paths.new(
				path_full_body_locomotion,
				path_upper_body_blend2,
			)
			var blender = Animator.Blender.new(mage, anim_tree, paths)
			
			return Animator.new(full_body_playback, right_arm_playback, blender)
