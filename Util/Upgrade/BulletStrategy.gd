extends Resource
class_name BulletStrategy

@export var texture: Texture2D = preload("res://Art/Sprites/test/carrot.png")
@export var upgrade_text: String = "Speed"

## Base strategy for modifying a spawned bullet.
## Implementors should override `apply_upgrade` to change bullet behavior or properties.
func apply_upgrade(_bullet: BulletPlayer) -> void:
    pass


# New method for multiplayer bullet system  
func modify_bullet_data(bullet_data: Dictionary) -> Dictionary:
    return bullet_data