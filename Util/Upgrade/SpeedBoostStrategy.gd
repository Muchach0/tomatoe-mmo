extends BulletStrategy
class_name SpeedBoostStrategy

@export var speed_multiplier: float = 1.5

func apply_upgrade(bullet: BulletPlayer) -> void:
    bullet.speed *= speed_multiplier

# New method for multiplayer bullet system  
func modify_bullet_data(bullet_data: Dictionary) -> Dictionary:
    bullet_data["speed"] *= speed_multiplier
    return bullet_data


