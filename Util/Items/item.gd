# Item in the inventory (Resource)
class_name Item
extends Resource


@export var item_name : String = ""
@export var sprite : Texture2D = AtlasTexture.new()


func _to_string() -> String:
	return item_name
