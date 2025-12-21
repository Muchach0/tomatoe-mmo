extends State
class_name EnemyMeleeAttack

var enemy: Enemy
var player: CharacterBody2D
var direction_to_player: Vector2

var attack_cooldown: float

var last_attack_time: float = 0.0
var is_attacking: bool = false
var attack_hit_registered: bool = false  # Prevent multiple hits per attack
var state_animation_name: String = "attack"

func Enter():
    print_debug("%d - EnemyMeleeAttack.gd - Enter - Entering melee attack state" % multiplayer.get_unique_id())
    enemy = get_parent().get_parent() # Getting the enemy node
    player = enemy.player
    
    if not player or not is_instance_valid(player):
        enemy.server_send_state_transition_to_players_in_current_world("EnemyIdle")
        # transition_state("EnemyIdle")
        return
    
    # Get initial direction to player
    direction_to_player = (player.global_position - enemy.global_position).normalized()
    
    # Connect to player death signal
    if not EventBus.is_connected("player_died", player_died):
        EventBus.connect("player_died", player_died)
    
    # Stop movement during attack
    enemy.velocity = Vector2.ZERO
    attack_cooldown = enemy.attack_cooldown
    
    # Start attack immediately if not on cooldown
    var current_time = Time.get_unix_time_from_system()
    if current_time - last_attack_time >= attack_cooldown:
        perform_melee_attack()

    # Connect to the player in melee range signal
    # if enemy.melee_attack_range_area != null and not enemy.player_in_melee_range.is_connected(player_in_range):
    #     enemy.player_in_melee_range.connect(player_in_range)

func Update(_delta: float):
    if not enemy or not player or not is_instance_valid(enemy) or not is_instance_valid(player):
        enemy.server_send_state_transition_to_players_in_current_world("EnemyIdle")
        # transition_state("EnemyIdle")
        return
    
    # var distance_to_player = enemy.global_position.distance_to(player.global_position)
    
    # # If player moved out of attack range and we're not currently attacking, follow them
    # if distance_to_player > attack_range and not is_attacking:
    #     transition_state("EnemyFollowing")
    #     return
    if not is_attacking and not enemy.is_any_player_in_melee_range:
        enemy.server_send_state_transition_to_players_in_current_world("EnemyFollowing")
        # transition_state("EnemyFollowing")
        return

    # Check if we can attack again
    var current_time = Time.get_unix_time_from_system()
    if current_time - last_attack_time >= attack_cooldown and not is_attacking:
        perform_melee_attack()

func Physics_Update(_delta: float):
    if not enemy or not player or not is_instance_valid(enemy) or not is_instance_valid(player):
        return
    
    # Update direction to player
    direction_to_player = (player.global_position - enemy.global_position).normalized()
    
    # Face the player
    flip_sprite_if_necessary()
    
    # Stop movement during attack
    enemy.velocity = Vector2.ZERO

func flip_sprite_if_necessary():
    if not enemy.should_flip_sprite:
        return
    
    if direction_to_player.x < 0:
        enemy.flip_sprite(true)
    else:
        enemy.flip_sprite(false)

func perform_melee_attack():
    print_debug("EnemyMeleeAttack.gd - perform_melee_attack - Starting melee attack")
    
    is_attacking = true
    attack_hit_registered = false
    last_attack_time = Time.get_unix_time_from_system()
    # enemy.melee_attack_range_area.set_deferred("disabled", true)
    
    # Enable the hurtbox for damage detection
    # if enemy.hurtbox and enemy.hurtbox_collision_shape:
    #     enemy.hurtbox.damage = melee_damage
        # Don't enable collision here - let animation handle it
    
    enemy.play_attack_animation()
    
    # # Play attack animation
    # if enemy.animation_player != null:
    #     print_debug("EnemyMeleeAttack.gd - perform_melee_attack - Enemy animation player is not null")
    #     if enemy.animation_player.has_animation("attack"):
    #         print_debug("EnemyMeleeAttack.gd - perform_melee_attack - Enemy animation player has the attack animation")
    #         enemy.animation_player.play("attack")
    #     else:
    #         print_debug("EnemyMeleeAttack.gd - perform_melee_attack - Enemy animation player does not have the attack animation")
    #         # Fallback if no attack animation
    #         complete_attack()

func complete_attack():
    """Called when attack animation finishes or immediately if no animation"""
    print_debug("EnemyMeleeAttack.gd - complete_attack - Attack completed")
    is_attacking = false
    # enemy.melee_attack_range_area.set_deferred("disabled", false) # re-enable the melee attack range area to detect the player
    
    # # Disable hurtbox collision
    # if enemy.hurtbox_collision_shape:
    #     enemy.hurtbox_collision_shape.set_deferred("disabled", true)

func on_attack_hit():
    """Called when the attack successfully hits a player"""
    if attack_hit_registered:
        return  # Prevent multiple hits per attack
    
    attack_hit_registered = true
    print_debug("EnemyMeleeAttack.gd - on_attack_hit - Melee attack hit player!")

func player_died(player_id):
    if player != null and player.has_method("get") and player.get("peer_id") != null:
        if player_id == player.peer_id:
            enemy.server_send_state_transition_to_players_in_current_world("EnemyIdle")
            # transition_state("EnemyIdle")
    else:
        # Single player mode - just transition to idle
        enemy.server_send_state_transition_to_players_in_current_world("EnemyIdle")
        # transition_state("EnemyIdle")

func Exit():
    """Called when leaving this state"""
    is_attacking = false
    
    # Make sure hurtbox is disabled when leaving
    # if enemy and enemy.hurtbox_collision_shape:
    #     enemy.hurtbox_collision_shape.set_deferred("disabled", true)



# func player_in_range(is_player_in_range: bool):
#     is_any_player_in_range = is_player_in_range
#     return
    
