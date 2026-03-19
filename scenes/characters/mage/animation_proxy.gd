extends Node

@export var mage: MageCharacter

func execute_spell() -> void:
	mage.spell.release()
