class_name SkillSlot
extends Control

@onready var sprite : Sprite2D = $SkillSprite
@onready var level_label : Label = $LevelLabel
@onready var skill_level_up_control: Control = $ControlLevelUp

func _ready():
    EventBus.leveled_up.connect(show_skill_level_up_button)
    EventBus.one_skill_level_up.connect(hide_skill_level_up_button)

var skill : Skill:
    set(val):
        skill = val
        if skill == null:
            sprite.texture = null
            level_label.text = ""
            return
        sprite.texture = skill.icon
        level_label.text = str(skill.level)

func _on_skill_level_up_button_pressed():
    if skill == null:
        return
    print("skill_slot.gd - _on_skill_level_up_button_pressed() - skill: %s" % skill.skill_name)
    skill.level_up()
    EventBus.one_skill_level_up.emit(skill)
    


func hide_skill_level_up_button(_skill: Skill):
    skill_level_up_control.hide()

func show_skill_level_up_button(_level: int, _levels_gained: int, _skill_points: int):
    if skill == null:
        return
    skill_level_up_control.show()
