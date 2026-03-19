extends Node

@export var mage: MageCharacter
@export var ui: PlayerUI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mage.health_changed.connect(ui.update_health)
	mage.mana_changed.connect(ui.update_mana)
	mage.casting_started.connect(ui.show_skill_progress)
	mage.casting_end.connect(ui.hide_skill_progress)
	mage.casting_progressed.connect(ui.update_skill_progress)
	
	ui.skill_activated.connect(mage.processor.input.use_skill)
