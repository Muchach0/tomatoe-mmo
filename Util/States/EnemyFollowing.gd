extends State
class_name EnemyFollowing

var enemy : CharacterBody2D
var player: CharacterBody2D
var move_speed := 100.0 # default value - overridden in the Enter function

var direction = Vector2() # Direction that is taking the enemy to the player

# puppet var puppet_position = Vector2()
# puppet var puppet_direction = Vector2()
# var puppet_position = Vector2()
# var puppet_direction = Vector2()

var state_animation_name: String = "walk"

func Enter():
    print("EnemyFollowing.gd - Enter - Entering EnemyFollowing state") 
    enemy = get_parent().get_parent() # Getting the grand-parent of the script, i.e. the KinematicBody2D node to move it
    move_speed = enemy.speed
    player = enemy.player
    if not EventBus.is_connected("player_died", player_died):
        EventBus.connect("player_died", player_died)

    # Test if the animation player of the nemy has the walk animation
    if enemy.get_node("AnimationPlayer").has_animation("walk"):
        print_debug("EnemyFollowing.gd - Enter - Enemy has the walk animation - playing it")
        enemy.get_node("AnimationPlayer").play("walk")

    # Connect to the player in melee range signal
    if enemy.melee_attack_range_area != null and not enemy.player_in_melee_range.is_connected(player_in_melee_range):
        enemy.player_in_melee_range.connect(player_in_melee_range)
    
# func Update(delta: float):

func flip_sprite_if_necessary(dir):
    # Part to handle the sprite flip (set to false by default)
    if not enemy.should_flip_sprite or not is_multiplayer_authority():
        return
    if dir.x < 0:
        enemy.flip_sprite(true)
        # enemy.get_node("Sprite2D").flip_h = true
        # var sprite: Sprite2D = enemy.get_node("Sprite2D")
        # sprite.flip_h = true
    else:
        enemy.flip_sprite(false)
        # enemy.get_node("Sprite2D").flip_h = false


func Physics_Update(_delta: float):
    if not enemy or not player:
        return

    if multiplayer == null or is_multiplayer_authority():
    # if not EventBus.is_in_network_mode() or is_multiplayer_authority(): # If in local mode or master, move the ennemy as regular
        # print_debug("EnemyFollowing.gd - Physics_Update - Not in network mode or is network master")
        direction = player.global_position - enemy.global_position
        
        # # Check if we should transition to melee attack
        var distance_to_player = direction.length()
        # if enemy.can_perform_melee_attack() and enemy.is_player_in_melee_range():
        #     enemy.server_send_state_transition_to_players_in_current_world("EnemyMeleeAttack")
        #     return
        
        # Check if we should transition to ranged attack (if enemy can shoot)
        if enemy.can_shoot_bullets and distance_to_player > enemy.melee_attack_range and distance_to_player <= 300.0:
            enemy.server_send_state_transition_to_players_in_current_world("EnemyRangedAttack")
            return
        
        # if multiplayer:
        # # if EventBus.is_in_network_mode(): # if in network mode, the master sync to puppets
        #     print("EnemyFollowing.gd - Physics_Update - TOFIX")
            # rset_unreliable("puppet_position", enemy.position)
            # rset_unreliable("puppet_direction", direction)

    # In multiplayer mode, the puppet moves the enemy based on the info from from the master
    # if multiplayer and not is_multiplayer_authority():
    # # if EventBus.is_in_network_mode() and not is_multiplayer_authority():
    #     enemy.position = puppet_position
    #     direction = puppet_direction

        if enemy.should_be_able_to_move: # Moving the ennemy if the flag is set to true
            enemy.velocity = direction.normalized() * move_speed
            enemy.move_and_slide()

    # if multiplayer and not is_multiplayer_authority():
    # # if EventBus.is_in_network_mode() and not is_multiplayer_authority():
    #     puppet_position = enemy.position # to avoid jitter

    # In all case flip the sprite if necessary	
    flip_sprite_if_necessary(direction)


    # Play the walk animation
    # if direction.length() > 0:
    # 	enemy.look_at(enemy.position + direction)
    # 	enemy.play("walk")

        # enemy.look_at(enemy.position + move_direction)
        # enemy.play("walk")
func player_died(player_id):
    if player_id == player.peer_id: # if the player we are attacking dies, goes to Idle State
        emit_signal("transitioned", self, "EnemyIdle")

# Transition to the melee attack state if the player is in melee range
func player_in_melee_range(is_player_in_range: bool):
    if not is_player_in_range:
        return
    enemy.server_send_state_transition_to_players_in_current_world("EnemyMeleeAttack")
