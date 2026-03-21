extends Node

@export var mage: MageCharacter
@export var ui: PlayerUI

@export var skeleton_minion_scene: PackedScene
@export var skeleton_minion_patrol_points: Array[Marker3D]

@onready var timer: Timer = $MobTimer
@onready var spawn_location: PathFollow3D = $SpawnPath/SpawnLocation

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mage.health_changed.connect(ui.update_health)
	mage.mana_changed.connect(ui.update_mana)
	mage.casting_started.connect(ui.show_skill_progress)
	mage.casting_end.connect(ui.hide_skill_progress)
	mage.casting_progressed.connect(ui.update_skill_progress)
	
	ui.skill_activated.connect(mage.processor.input.use_skill)
	
	timer.timeout.connect(_on_mob_timer_timeout)

func _on_mob_timer_timeout() -> void:
	var minion: SkeletonMinion = skeleton_minion_scene.instantiate()
	
	var patrol_points = skeleton_minion_patrol_points.duplicate()
	patrol_points.shuffle()
	minion.patrol_points = patrol_points
	
	spawn_location.progress_ratio = randf()
	
	add_child(minion)
	
	minion.global_position = spawn_location.position
	minion.died.connect(func(): _weg_ist_es(minion))
	
	minion.anim.oneshot_spawn_ground()

func _weg_ist_es(node: SkeletonMinion):
	print("und weg ist er: ", node)
