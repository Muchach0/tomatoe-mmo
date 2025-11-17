extends State
class_name BossIdle

var enemy: Enemy
var aggro_timer: float = 0.0
var aggro_check_interval: float = 1.0

var state_animation_name: String = "idle"

const AGGRO_AREA_NAME = "AggroArea2D"

func _on_Area2D_body_entered(body):
    if not body.is_in_group("Player"):
        return
    
    enemy.player = body
    if enemy.player.is_hidden:
        return
    
    print_debug("BossIdle.gd - _on_Area2D_body_entered - Player entered boss area - Player: ", enemy.player)
    
    # Boss starts with rolling attack when player enters
    emit_signal("transitioned", self, "BossRolling")

func Enter():
    enemy = get_parent().get_parent()
    aggro_timer = 0.0
    
    # Connect to aggro area if available
    if enemy.has_node(AGGRO_AREA_NAME):
        print_debug("BossIdle.gd - Enter - Connecting boss aggro area")
        if not enemy.get_node(AGGRO_AREA_NAME).is_connected("body_entered", _on_Area2D_body_entered):
            enemy.get_node(AGGRO_AREA_NAME).connect("body_entered", _on_Area2D_body_entered)
    
    # Play idle animation
    if enemy.animation_player and enemy.animation_player.has_animation("idle"):
        enemy.animation_player.play("idle")

func Update(_delta: float):
    if not enemy:
        return
    

func Exit():
    if enemy and enemy.has_node(AGGRO_AREA_NAME):
        if enemy.get_node(AGGRO_AREA_NAME).is_connected("body_entered", _on_Area2D_body_entered):
            enemy.get_node(AGGRO_AREA_NAME).disconnect("body_entered", _on_Area2D_body_entered)
