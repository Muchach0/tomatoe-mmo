class_name Hurtbox
extends Area2D

############################################################
# TRUE: Hurtbox component - Deals damage. 
# Logic is handled by the hitbox.
############################################################


@export var damage: int = 1 # default damage value
@export var should_disapear_on_hit: bool = false # default value - should be true for projectiles, but false for melee attacks
var from_player_id: int = 1 # default value - should be the player id who shot the bullet

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal attack_landed_signal

# func _ready():
#     # Connect to area_entered signal to detect player hits
#     area_entered.connect(_on_area_entered)

# func _on_area_entered(area: Area2D):
#     """Handle collision with player hitbox"""
#     # Check if this is a player hitbox
#     if not area.is_in_group("player_hitbox"):
#         return
    
#     # Get the player from the hitbox owner
#     var player = area.owner
#     if not player or not player.has_method("take_damage"):
#         return
    
#     # Avoid self-damage in multiplayer
#     if player.has_method("get") and player.get("peer_id") != null:
#         if player.peer_id == from_player_id:
#             return
    
#     # Deal damage to player
#     print_debug("Hurtbox.gd - _on_area_entered - Dealing damage to player: ", damage)
#     player.take_damage(damage, from_player_id)
    
#     # Notify that attack landed
#     attack_landed()

func attack_landed():
    attack_landed_signal.emit()