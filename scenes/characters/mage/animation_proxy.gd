extends Node

@export var mage: MageCharacter

func execute_spell() -> void:
	mage.abilities.release()
