extends BulletStrategy
class_name DamageBoostStrategy

@export var damage_bonus: float = 2.0

func apply_upgrade(bullet: BulletPlayer) -> void:
    bullet.damage += damage_bonus

# New method for multiplayer bullet system
func modify_bullet_data(bullet_data: Dictionary) -> Dictionary:
    bullet_data["damage"] += damage_bonus
    return bullet_data


