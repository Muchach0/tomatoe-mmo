extends State
class_name EnemyIdle

var enemy : Enemy
var target_peer_id: int = 0

var state_animation_name: String = "idle"

const AGGRO_AREA_NAME = "AggroArea2D"

func _on_Area2D_body_entered(body):
    if not body.is_in_group("Player"):
        return
    # Only the server decides which player is the focus, then tells all peers
    if multiplayer != null and multiplayer.is_server():
        var target_player = body
        if target_player.is_hidden:
            return
        # Broadcast target selection to all peers (and apply locally)
        set_target_peer.rpc(target_player.peer_id)
        print_debug("EnemyIdle.gd - _on_Area2D_body_entered - Server set target peer:", target_player.peer_id)
    else:
        # Non-server clients do not decide transitions; they wait for server RPC
        pass

# When taking damage, we trasition to the EnemyFollowing state, and the enemy target the enemy that attacked it.
func on_take_damage(from_player_id: int):
    if multiplayer != null and multiplayer.is_server():
        print("EnemyIdle.gd - on_take_damage - Enemy has taken damage")
        set_target_peer.rpc(from_player_id)
# func _on_Area2D_area_entered(area):
#     if not area.is_in_group("Player"):
#         return
#     # print_debug("EnemyIdle.gd - _on_Area2D_area_entered - Player entered the area")
#     enemy.player = area.get_parent()
#     if enemy.player.is_hidden:
#         return
#     print_debug("EnemyIdle.gd - _on_Area2D_area_entered - Player entered the area - Player: ", enemy.player)

#     if enemy.get_node("StateMachine").states.has("EnemyAttackingDistance".to_lower()):
#         print_debug("EnemyIdle.gd - _on_Area2D_body_entered - Player entered the area - Transitioning to EnemyAttackingDistance")
#         emit_signal("transitioned", self, "EnemyAttackingDistance")
#         return
    
#     if enemy.get_node("StateMachine").states.has("EnemyFollowing".to_lower()):
#         print_debug("EnemyIdle.gd - _on_Area2D_body_entered - Player entered the area - Transitioning to EnemyFollowing")
#         emit_signal("transitioned", self, "EnemyFollowing")
#         return


func Enter():
    enemy = get_parent().get_parent() # Getting the grand-parent of the script, i.e. the KinematicBody2D node to move it
    # Connecting the enemy aggro area to the function _on_Area2D_body_entered
    # i.e. this is to be able to detect enemy entering the aggro area

    # Check if enemy.get_node("Area2D") is already connected:
    if enemy.has_node(AGGRO_AREA_NAME):
        print("Connecting Connecting the enemy aggro area to the function _on_Area2D_body_entered")
        # if enemy.get_node(AGGRO_AREA_NAME).is_connected("body_entered", _on_Area2D_body_entered) == false:
        #     print("Connecting Connecting the enemy aggro area to the function _on_Area2D_body_entered")
        #     enemy.get_node(AGGRO_AREA_NAME).connect("body_entered", _on_Area2D_body_entered)
        
        if enemy.get_node(AGGRO_AREA_NAME).is_connected("body_entered", _on_Area2D_body_entered) == false:
            print("Connecting Connecting the enemy aggro area to the function _on_Area2D_body_entered")
            enemy.get_node(AGGRO_AREA_NAME).connect("body_entered", _on_Area2D_body_entered)


    if not enemy.take_damage_signal.is_connected(on_take_damage):
        enemy.take_damage_signal.connect(on_take_damage)

    if enemy.get_node("AnimationPlayer").has_animation("idle"):
        enemy.get_node("AnimationPlayer").play("idle")

func Exit():
    if enemy.has_node(AGGRO_AREA_NAME):
        if enemy.get_node(AGGRO_AREA_NAME).is_connected("body_entered", _on_Area2D_body_entered):
            enemy.get_node(AGGRO_AREA_NAME).disconnect("body_entered", _on_Area2D_body_entered)


# ===================== TARGETING (SERVER-AUTHORITATIVE) =====================
@rpc("authority", "call_local", "reliable")
func set_target_peer(new_target_peer_id: int) -> void:
    target_peer_id = new_target_peer_id
    var target_player = _find_player_by_peer_id(target_peer_id)
    if target_player == null:
        print_debug("EnemyIdle.gd - set_target_peer - Target player not found for peer_id:", target_peer_id)
        return
    if target_player.is_hidden:
        print_debug("EnemyIdle.gd - set_target_peer - Target player is hidden; ignoring")
        return
    enemy.player = target_player

    var sm = enemy.get_node_or_null("StateMachine")
    if sm == null:
        return
    if sm.states.has("EnemyRangedAttack".to_lower()):
        emit_signal("transitioned", self, "EnemyRangedAttack")
        return
    if sm.states.has("EnemyFollowing".to_lower()):
        emit_signal("transitioned", self, "EnemyFollowing")


func _find_player_by_peer_id(peer_id_to_find: int) -> Node:
    for n in get_tree().get_nodes_in_group("Player"):
        if n.peer_id == peer_id_to_find:
            return n
    return null
