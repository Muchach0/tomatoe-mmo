extends State
class_name EnemyIdle

var enemy : Enemy

var state_animation_name: String = "idle"

# When taking damage, we transition to the EnemyFollowing state, and the enemy targets the player that attacked it.
func on_take_damage(from_player_id: int):
    if multiplayer != null and multiplayer.is_server():
        print("EnemyIdle.gd - on_take_damage - Enemy has taken damage")
        enemy.set_target_peer.rpc(from_player_id)


func Enter():
    enemy = get_parent().get_parent() # Getting the grand-parent of the script, i.e. the KinematicBody2D node to move it
    
    # Connect to take_damage_signal to react to damage
    if not enemy.take_damage_signal.is_connected(on_take_damage):
        enemy.take_damage_signal.connect(on_take_damage)
    
    # Connect to target_changed signal to handle state transitions
    if not enemy.target_changed.is_connected(_on_target_changed):
        enemy.target_changed.connect(_on_target_changed)

    if enemy.get_node("AnimationPlayer").has_animation("idle"):
        enemy.get_node("AnimationPlayer").play("idle")

func Exit():
    if enemy.target_changed.is_connected(_on_target_changed):
        enemy.target_changed.disconnect(_on_target_changed)

# ===================== TARGETING HANDLING =====================
func _on_target_changed(_target_player: Node) -> void:
    """Called when the enemy's target changes. Handles state transitions."""
    var sm = enemy.get_node_or_null("StateMachine")
    if sm == null:
        return
    if sm.states.has("EnemyRangedAttack".to_lower()):
        emit_signal("transitioned", self, "EnemyRangedAttack")
        return
    if sm.states.has("EnemyFollowing".to_lower()):
        emit_signal("transitioned", self, "EnemyFollowing")
