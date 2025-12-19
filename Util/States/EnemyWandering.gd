extends State
class_name EnemyWandering

var enemy : Enemy
@export var move_speed := 10.0
@export var min_wander_time := 2.5
@export var max_wander_time := 10.0

var rng = RandomNumberGenerator.new() # useful for randomize functions
var move_direction : Vector2
var wander_timer : Timer

var state_animation_name: String = "wandering"

func randomize_wander_and_add_timer():
    move_direction = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
    wander_timer = Timer.new()
    wander_timer.wait_time = rng.randf_range(min_wander_time, max_wander_time)
    wander_timer.timeout.connect(on_timer_finished)
    wander_timer.autostart = true
    add_child(wander_timer)

# When taking damage, we transition to the EnemyFollowing state, and the enemy targets the player that attacked it.
func on_take_damage(from_player_id: int):
    if multiplayer != null and multiplayer.is_server():
        print("EnemyWandering.gd - on_take_damage - Enemy has taken damage")
        enemy.set_target_peer.rpc(from_player_id)

func Enter():
    enemy = get_parent().get_parent() # Getting the grand-parent of the script, i.e. the KinematicBody2D node to move it
    if multiplayer != null and multiplayer.is_server():
        rng.randomize()
        randomize_wander_and_add_timer()
        if enemy:
            if move_direction.x < 0:
                enemy.flip_sprite(true)
            else:
                enemy.flip_sprite(false)


    # Connect to take_damage_signal to react to damage
    if not enemy.take_damage_signal.is_connected(on_take_damage):
        enemy.take_damage_signal.connect(on_take_damage)
    
    # Connect to target_changed signal to handle state transitions
    if not enemy.target_changed.is_connected(_on_target_changed):
        enemy.target_changed.connect(_on_target_changed)

    if enemy.get_node("AnimationPlayer").has_animation("wandering"):
        enemy.get_node("AnimationPlayer").play("wandering")
    



func Physics_Update(_delta: float):
    if enemy and multiplayer != null and multiplayer.is_server():
        enemy.velocity = move_direction * move_speed
        enemy.move_and_slide()
        # enemy.look_at(enemy.position + move_direction)
        # enemy.play("walk")

func Exit():
    if multiplayer != null and multiplayer.is_server() and wander_timer != null:
        wander_timer.stop()
        wander_timer.timeout.disconnect(on_timer_finished)
        wander_timer.queue_free()
        wander_timer = null
    if enemy.target_changed.is_connected(_on_target_changed):
        enemy.target_changed.disconnect(_on_target_changed)

func on_timer_finished():
    if multiplayer != null and multiplayer.is_server():
        enemy.server_send_state_transition_to_players_in_current_world("EnemyIdle")
    

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



# @rpc("any_peer", "call_local", "reliable")
# func server_broadcast_exit_state():
#     emit_signal("transitioned", self, "EnemyIdle")
