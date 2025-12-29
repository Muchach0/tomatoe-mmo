class_name SkillSlot
extends Control

@onready var sprite : Sprite2D = $SkillSprite
@onready var level_label : Label = $LevelLabel

var skill : Skill:
    set(val):
        skill = val
        if skill == null:
            sprite.texture = null
            level_label.text = ""
            return
        sprite.texture = skill.icon
        level_label.text = str(skill.level)
