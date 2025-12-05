class_name ItemSlot
extends Control

@onready var sprite : Sprite2D = $ItemSprite
@onready var label : Label = $Label

var stack : ItemStack:
	set(val):
		stack = val
		sprite.texture = stack.item.sprite
		label.text = str(val.count)
