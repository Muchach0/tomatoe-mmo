class_name Hitbox 
extends Area2D

############################################################
# TRUE: Hitbox component - Take damage. 
# This gets hit by the hurtbox.
############################################################


func _ready() -> void:
    area_entered.connect(on_area_entered)


func on_area_entered(hurtbox: Node):
    if hurtbox == null or not hurtbox is Hurtbox:
        return
    if owner.get_multiplayer_authority() == hurtbox.from_player_id: # This is to avoid self-damage
        return

    if owner.has_method("take_damage"):
        print_debug("Hitbox.gd - on_area_entered - owner has a take_damage method")
        owner.take_damage(hurtbox.damage, hurtbox.from_player_id)
        hurtbox.attack_landed()
    if hurtbox.should_disapear_on_hit:
        hurtbox.get_parent().queue_free()
