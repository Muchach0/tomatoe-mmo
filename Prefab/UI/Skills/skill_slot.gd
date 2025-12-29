class_name SkillSlot
extends Control

@onready var sprite : Sprite2D = $SkillSprite

var skill : Skill:
	set(val):
		skill = val
		sprite.texture = skill.icon
