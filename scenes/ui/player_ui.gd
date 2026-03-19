class_name PlayerUI extends CanvasLayer

signal skill_activated(index: int)

@onready var health_bar := $MarginContainer/Control/StatContainer/Health
@onready var mana_bar := $MarginContainer/Control/StatContainer/Mana
@onready var skill_progress := $MarginContainer/Control/VBoxContainer/CenterContainer/SkillProgres
@onready var skill_1 := $MarginContainer/Control/VBoxContainer/SkillsContainer/Skill1
@onready var skill_2 := $MarginContainer/Control/VBoxContainer/SkillsContainer/Skill2
@onready var skill_3 := $MarginContainer/Control/VBoxContainer/SkillsContainer/Skill3

func _ready() -> void:
	skill_1.pressed.connect(func(): skill_activated.emit(0))
	skill_2.pressed.connect(func(): skill_activated.emit(1))
	skill_3.pressed.connect(func(): skill_activated.emit(2))

func update_health(current: float, total: float) -> void:
	health_bar.value = current
	health_bar.max_value = total

func update_mana(current: float, total: float) -> void:
	mana_bar.value = current
	mana_bar.max_value = total

func update_skill_progress(current: float, total: float) -> void:
	skill_progress.value = current
	skill_progress.max_value = total

func show_skill_progress() -> void:
	skill_progress.visible = true

func hide_skill_progress() -> void:
	skill_progress.visible = false
