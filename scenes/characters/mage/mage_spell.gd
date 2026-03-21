class_name MageAbilities

var registry: Registry
var _active_spell: BaseSpell
var _buffered_spell: BaseSpell
var _attack_anim_names: Array[String]

func _init(p_registry: Registry, attack_anim_names: Array[String]) -> void:
	registry = p_registry
	_attack_anim_names = attack_anim_names

static func create(
	mage: MageCharacter,
	attack_anim_names: Array[String]
) -> MageAbilities:
	var player: AnimationPlayer = mage.anim_tree.get_node(mage.anim_tree.anim_player)
	
	var firebolt = Firebolt.new(mage, SpellAnimation.create(
		mage.firebolt_data,
		mage.animation_shoot,
		player,
	))
	
	var firepulse = Firepulse.new(mage, SpellAnimation.create(
		mage.firepulse_data,
		mage.animation_shoot,
		player,
	))
	
	var meteor = Meteor.new(mage, SpellAnimation.create(
		mage.meteor_data,
		mage.animation_raise,
		player,
	))
	
	return MageAbilities.new(Registry.new(firebolt, firepulse, meteor), attack_anim_names)

func prepare_spell(spell: BaseSpell) -> void:
	if _active_spell != null:
		_active_spell.cancel()
	_active_spell = spell
	_active_spell.prepare()

func handle_input(event: InputEvent) -> bool:
	if _active_spell != null:
		return _active_spell.handle_input(event)
	return false

func preparing(delta: float) -> void:
	if _active_spell != null:
		_active_spell.preparing(delta)
	
	if _buffered_spell != null:
		_buffered_spell.casting()

func buffer_spell(spell: BaseSpell) -> void:
	if _buffered_spell != null:
		_buffered_spell.cancel()
	_buffered_spell = spell

func buffer_active_spell() -> void:
	if _active_spell != null:
		buffer_spell(_active_spell)
		_active_spell = null

func is_buffered(spell: BaseSpell) -> bool:
	return _buffered_spell == spell

func release() -> void:
	if _buffered_spell != null:
		_buffered_spell.release()
		_buffered_spell = null

func is_attack_anim_name(name: StringName) -> bool:
	return _attack_anim_names.has(name)

func unset_when_active(spell: BaseSpell) -> void:
	if _active_spell == spell:
		_active_spell = null

class HasMage:
	var _mage: MageCharacter
	
	func _init(mage: MageCharacter):
		_mage = mage

class Registry:
	var bolt: Firebolt
	var pulse: Firepulse
	var meteor: Meteor
	
	func _init(p_bolt: Firebolt, p_pulse: Firepulse, p_meteor: Meteor) -> void:
		bolt = p_bolt
		pulse = p_pulse
		meteor = p_meteor

class SpellAnimation:
	var scene: PackedScene
	var state_name: StringName
	var anim_name: StringName
	var cast_point: float
	
	func _init(
		p_scene: PackedScene,
		p_state_name: StringName,
		p_anim_name: StringName,
		p_cast_point: float
	) -> void:
		scene = p_scene
		state_name = p_state_name
		anim_name = p_anim_name
		cast_point = p_cast_point
	
	static func create(
		resource: SpellResource,
		animation: SpellAnimationData,
		player: AnimationPlayer,
	) -> SpellAnimation:
		var c_point = animation.try_get_call_method_track_time(player)
		if c_point == null:
			c_point = 0.01
		
		return SpellAnimation.new(
			resource.scene,
			animation.state_name,
			animation.animation_name,
			c_point,
		)

enum CQueueTask {
	FinishAttack,
}

class BaseSpell extends HasMage:
	var anim: SpellAnimation
	
	func _init(mage: MageCharacter, p_anim: SpellAnimation):
		super(mage)
		anim = p_anim
	
	func prepare() -> void: push_error("[MageCharacter][Spell][BaseSpell].prepare() must be overriden by child implementations")
	func preparing(_delta: float) -> void: push_error("[MageCharacter][Spell][BaseSpell].preparing() must be overriden by child implementations")
	func release() -> void: push_error("[MageCharacter][Spell][BaseSpell].release() must be overriden by child implementations")
	func cancel() -> void: push_error("[MageCharacter][Spell][BaseSpell].cancel() must be overriden by child implementations")
	func handle_input(_event: InputEvent) -> bool: 
		push_error("[MageCharacter][Spell][BaseSpell].push_error() must be overriden by child implementations")
		return false
	func progress(): push_error("[MageCharacter][Spell][BaseSpell].progress() must be overriden by child implementations")
	
	func casting() -> void:
		_mage.notify_casting_progressed(
			_mage.anim.get_current_upper_body_play_position(),
			anim.cast_point,
		)
	
	func _init_at_wand_spawnpoint(scene: PackedScene) -> Node3D:
		var node = _init_scene(scene)
		node.global_position = _mage.wandspawn_node.global_position
		
		node.global_basis = _mage.pivot.global_basis
		node.global_basis = node.global_basis.rotated(Vector3.UP, PI)
		node.global_basis.z.y = 0
		node.global_basis = node.global_basis.orthonormalized()
		
		return node
	
	func _init_scene(scene: PackedScene) -> Node3D:
		var node = scene.instantiate()
		_mage.get_tree().current_scene.add_child(node)
		return node
	
	func _handle_upper_body_blend2():
		_mage.anim.blender.blend2_upper_body(1.0, 0.075)
		
		_mage.conditional_queue.queue(
			CQueueTask,
			CQueueTask.FinishAttack,
			func(_d, task: ConditionalQueue.ConditionalQueueTask) -> bool:
				var current = _mage.anim.get_current_upper_body_node()
				var is_attack_animation = _mage.abilities.is_attack_anim_name(current)
				var is_started = task.data.get("started", false)
				
				# playback travel occures after the setup of this callback,
				# therefore it is necessary to check if the queue was started yet
				if not is_started and is_attack_animation:
					task.data.set("started", true)
					return false
				
				return is_started and not is_attack_animation,
				func(_d): _mage.anim.blender.blend2_upper_body(0.0)
		)

class InstantSpell extends BaseSpell:
	func preparing(_delta: float) -> void: pass
	func cancel() -> void: pass
	func handle_input(_event: InputEvent) -> bool: return false
	
class Firepulse extends InstantSpell:
	func release():
		_mage.notify_casting_end()
		var node = _init_at_wand_spawnpoint(anim.scene)
		node.scale = Vector3(3, 3, 3)
		
		var distance = 1.75
		var forward = _mage.pivot.global_transform.basis.z
		
		node.global_position += forward * distance
	
	func prepare() -> void:
		_handle_upper_body_blend2()
		_mage.anim.play_upper_body(anim.state_name, AnimationUtil.Play.Start)
		_mage.abilities.buffer_active_spell()
		_mage.notify_casting_started()

class Firebolt extends InstantSpell:
	func release():
		_mage.notify_casting_end()
		_init_at_wand_spawnpoint(anim.scene)
	
	func prepare():
		_handle_upper_body_blend2()
		_mage.anim.play_upper_body(anim.state_name, AnimationUtil.Play.Start)
		_mage.abilities.buffer_active_spell()
		_mage.notify_casting_started()

class Meteor extends BaseSpell:
	var _aim_pos := Vector3.ZERO
	
	func release():
		_mage.notify_casting_end()
		
		var node = anim.scene.instantiate()
		node.position = _aim_pos
		_mage.get_tree().current_scene.add_child(node)
	
	func prepare():
		_mage.camera_node.use_visible_mouse()
		_mage.aim_decal.visible = true
	
	func cancel() -> void:
		_mage.camera_node.use_captured_mouse()
		_mage.aim_decal.visible = false
		_mage.abilities.unset_when_active(self)
	
	func handle_input(event: InputEvent) -> bool:
		if event.is_action_pressed("ui_cancel"):
			cancel()
			return true
		
		if event.is_action_pressed("attack"):
			_handle_upper_body_blend2()
			_mage.anim.play_upper_body(anim.state_name, AnimationUtil.Play.Start)
			_mage.camera_node.use_visible_mouse()
			_mage.aim_decal.visible = false
			
			_mage.abilities.buffer_active_spell()
			_mage.camera_node.use_captured_mouse()
			_mage.notify_casting_started()
			
			return true
		
		return false
	
	func preparing(_delta: float) -> void:
		var cast_range = 20.0 # Todo: replace with configurable value
		var mouse_pos = _mage.get_viewport().get_mouse_position()
		var camera = _mage.get_viewport().get_camera_3d()
		
		var origin = camera.project_ray_origin(mouse_pos)
		var end = origin + camera.project_ray_normal(mouse_pos) * cast_range
		
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.exclude = [_mage.get_rid()]
		
		var result = _mage.get_world_3d().direct_space_state.intersect_ray(query)
		
		if result:
			_mage.aim_decal.global_position = result.position
			_aim_pos = result.position
