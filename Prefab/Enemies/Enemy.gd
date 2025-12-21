class_name Enemy
extends CharacterBody2D

@export var MAX_DEFAULT_HEALTH = 3
const DEFAULT_SCORE = 1

@onready var animation_player = $AnimationPlayer if has_node("AnimationPlayer") else null # for the action of the player on the enemy (hit, die)

@onready var timer := $Timer if has_node("Timer") else null# timer to queue_free the enemy on dying
@onready var timer_glow := $TimerGlow if has_node("TimerGlow") else null
@onready var collision_shape := $CollisionShape2D if has_node("CollisionShape2D") else null

# onready var toto:= $toto if has_node("toto") else null # 
@onready var health_component := $HealthComponent if has_node("HealthComponent") else null

@onready var sprite := $Sprite2D if has_node("Sprite2D") else null
@export var should_flip_sprite: bool = false

var health
var score_given_by_this_enemy = DEFAULT_SCORE

# MOVING ENNEMY PART
# Define enemy states
# enum State { IDLE, AGGRO, ATTACK, DYING }
# var current_state = State.IDLE
# var is_moving = true # boolean to see if the ennemy is going to the target position
var player = null
var target_peer_id: int = 0 # The peer ID of the currently targeted player
@export var speed: float = 200  # Movement speed in pixels per second
@export var wander_speed: float = 10.0 # Movement speed in pixels per second when wandering
# var attack_range = 50 # Range within which enemy attacks

@export var should_be_able_to_move = true
@export var should_wander_on_idle = false # If true, the enemy will wander when idle
@export var should_glow_when_hit = true

# Ranged attacking part
@export var can_shoot_bullets: bool = false
@export var bullet_damage: float = 2.0
@export var bullet_speed: float = 200.0
var bullet_scene: PackedScene = preload("res://Prefab/Bullet/EnemyBullet.tscn")

# Attacking part
var is_attack_on_cooldown = false
@export var attack_cooldown: float = 1.0
@onready var timer_attack_cooldown : Timer = $TimerAttack if has_node("TimerAttack") else null
@onready var hurtbox := $Sprite2D/Hurtbox if has_node("Sprite2D/Hurtbox") else null
# @onready var hitbox_collision_shape := $HitBox/CollisionShape2D if has_node("HitBox/CollisionShape2D") else null
@onready var hurtbox_collision_shape := $Sprite2D/Hurtbox/CollisionShape2D if has_node("Sprite2D/Hurtbox/CollisionShape2D") else null
@onready var melee_attack_range_area := $Sprite2D/MeleeAttackRangeArea2D if has_node("Sprite2D/MeleeAttackRangeArea2D") else null
@onready var aggro_area := $AggroArea2D if has_node("AggroArea2D") else null

# Melee attack configuration
@export var can_melee_attack: bool = true
@onready var is_any_player_in_melee_range: bool = false

# Useful for flipping the sprite
@onready var init_scale: Vector2 = $Sprite2D.scale
# puppet var puppet_position = Vector2()

# Loot part
@export var loot_table: LootTable

@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
var current_world : String = ""


var item_drop: PackedScene = preload("res://Util/Items/item_drop.tscn")

signal enemy_died
signal player_in_melee_range
signal take_damage_signal # Signal to notify the enemy that it has taken damage.
signal target_changed(target_player: Node) # Signal emitted when the target player changes

func _ready() -> void:
    if timer != null:
        timer.timeout.connect(delete_enemy)
    if timer_glow != null:
        timer_glow.timeout.connect(stop_glow)
    health = MAX_DEFAULT_HEALTH

    if health_component != null:
        health_component.init_life_bar(MAX_DEFAULT_HEALTH)
    # animation_player.play("Idle")

    # Duplicate the shader to make individual modification
    if sprite != null:
        material = material.duplicate()
        material.set_shader_parameter("enable_effect", false)

    # Attack part
    if hurtbox != null:
        hurtbox.attack_landed_signal.connect(attack_landed)
    if timer_attack_cooldown != null:
        timer_attack_cooldown.wait_time = attack_cooldown
        timer_attack_cooldown.timeout.connect(reset_cooldown)

    if animation_player != null: # To keep playing the animation of the state machine when the animation is finished.
        animation_player.animation_finished.connect(_on_animation_player_animation_finished)

    if melee_attack_range_area != null:
        melee_attack_range_area.body_entered.connect(_on_melee_attack_range_area_body_entered)
        melee_attack_range_area.body_exited.connect(_on_melee_attack_range_area_body_exited)
    
    # Connect aggro area for player detection
    if aggro_area != null:
        aggro_area.body_entered.connect(_on_aggro_area_body_entered)

    if multiplayer and multiplayer.is_server():
        # sync.add_visibility_filter(visiblity_per_world_function_filter)
        # Ensure visibilities are computed immediately.
        force_visibility_update()

        # Default mode updates filters automatically during frames,
        # but you can also set VISIBILITY_PROCESS_NONE and call update_visibility() manually.
        # sync.visibility_update_mode = MultiplayerSynchronizer.VISIBILITY_PROCESS_IDLE

func flip_sprite(flip: bool) -> void:
    if not should_flip_sprite: # do nothing if the enemy should not flip the sprite
        return
    # Flip the spite by changing the x scale (instead of flip_h as we want the children to flip as well)
    # The hurtbox and the attack melee range should be flipped as well.
    if flip:
        sprite.scale.x = -init_scale.x
    else:
        sprite.scale.x = init_scale.x
    # sprite.flip_h = flip <-- does not flip the children as well

# ================ TAKING DAMAGE PART ================
func stop_glow() -> void:
    if sprite == null:
        return
    # sprite.material.set_shader_param("use_red_color", false)
    # sprite.material.set_shader_param("use_green_color", false)
    material.set_shader_parameter("enable_effect", false)

func start_red_glow() -> void:
    if sprite == null:
        return
    material.set_shader_parameter("enable_effect", true)
    # sprite.material.set_shader_param("use_red_color", true)
    timer_glow.start()


# Function to sync damage to all the peers (from the master of the node).
# The Enemy is supposed to always be owned by the server! (so server == master of the node).
# This is in 'remotesync' mode because we want also to use that function on the master.
@rpc("any_peer", "call_local", "reliable")
func sync_damage(damage: int, from_player_id:int, health_from_server: int) -> void:
    # print("Enemy.gd - sync_damage - damage: ", damage, " - from_player_id: ", from_player_id, " - health_from_server: ", health_from_server)
    health = health_from_server

    if animation_player != null:
        if animation_player.has_animation("hit") and animation_player.current_animation != "hit":
            animation_player.stop(true)
            animation_player.play("hit")
    health -= damage
    
    # Check if health_component is null or not:
    if health_component != null:
        health_component.update_life_bar(health, damage)
    
    if should_glow_when_hit:
        start_red_glow()

    if health <= 0:
        # Emit signal from state machine
        $StateMachine.current_state.emit_signal("transitioned", $StateMachine.current_state, "EnemyDying")
        die(from_player_id)

@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: int, from_player_id: int) -> void:
    # If we are in network mode, and this node is the master, then we sync the damage to everybody.
    if not multiplayer or not multiplayer.is_server() or from_player_id == 1: # from_player_id == 1 is the player id of the server
        return
    if multiplayer!= null and multiplayer.is_server():
        take_damage_signal.emit(from_player_id) # Sending the signal to the enemy to take damage.
        sync_damage.rpc(damage, from_player_id, health)
    # elif not EventBus.is_in_network_mode(): # If we are not in network mode, we just take the damage locally
    #     sync_damage(damage, from_player_id, health)
    # If we are in network mode, and this node is not the master, then we do nothing as the master will sync the damage to everybody.

# Not sure if that should be part of the enemy script or the EnemyDying script. 
# Keeping it here for now as it is related to the enemy damage above.
func die(_from_player_id: int) -> void:
    # current_state = State.DYING
    collision_shape.set_deferred("disabled", true) # Disabling the collision shape when the ennemy is dying
    # hitbox_collision_shape.set_deferred("disabled", true) # Disabling the hitbox when the ennemy is dying
    # hurtbox_collision_shape.set_deferred("disabled", true) # Disabling the hurtbox when the ennemy is dying

    emit_signal("enemy_died") # Not used right now - signal handling is done via the EventBus signal below (one_enemy_die)
    EventBus.emit_signal("one_enemy_die", get_groups()) # Sending as well the list of groups for spawner filtering
    EventBus.emit_signal("update_score", score_given_by_this_enemy, _from_player_id)
    # update_score()
    animation_player.stop(true)
    animation_player.play("die")
    # hurt_box.disabled = true
    # $Sprite.visible = false

    # Loot part
    drop_loot()

    timer.start()

# Function to delete the enemy - used when the enemy is killed by the player
func delete_enemy() -> void:
    if not multiplayer or not multiplayer.is_server():
        return
    queue_free()

#================ ATTACK PART ================
func attack_landed():
    is_attack_on_cooldown = true
    # hurtbox.set_deferred("disabled", true)
    hurtbox_collision_shape.set_deferred("disabled", true) # Disabling the hitbox when we landed an attack
    # hitbox_collision_shape.disabled = true
    timer_attack_cooldown.start()

    # Notify the current state if it's a melee attack state
    var current_state = $StateMachine.current_state
    if current_state != null and current_state.has_method("on_attack_hit"):
        current_state.on_attack_hit()

    if can_melee_attack: # if melee attack is enabled, managed by the EnemyMeleeAttack state
        return
    play_attack_animation()

func play_attack_animation():
    if animation_player == null :
        return
    if not animation_player.has_animation("attack"):
        return
    # animation_player.stop(true)
    animation_player.play("attack")

func reset_cooldown():
    is_attack_on_cooldown = false
    # hurtbox.set_deferred("disabled", false)
    if can_melee_attack: # if melee attack is enabled, the hurtbox is managed by the attack animation
        return
    hurtbox_collision_shape.set_deferred("disabled", false) # Disabling the hitbox when we landed an attack
    # hitbox_collision_shape.disabled = false
    
    # hitbox.set_deferred("disabled", false) # Re-enabling the hitbox after the cooldown is finished

#================ RANGED ATTACK PART ================
func shoot_bullet(direction: Vector2) -> void:
    """Shoot a bullet in the specified direction"""
    if not can_shoot_bullets or bullet_scene == null:
        return
    
    var bullet = bullet_scene.instantiate()
    var spawn_position = global_position + direction.normalized() * 25  # Offset from enemy center
    
    # Add bullet to the same parent as the enemy (usually the main scene)
    get_parent().add_child(bullet)
    
    # Initialize bullet with custom damage and speed
    bullet.initialize_bullet(spawn_position, direction, self)
    bullet.damage = bullet_damage
    bullet.speed = bullet_speed

    if animation_player == null :
        return
    if not animation_player.has_animation("attack"):
        return

    animation_player.play("attack")
    


#================ MELEE ATTACK PART ================
func _on_melee_attack_range_area_body_entered(body: Node2D) -> void:
    if body.is_in_group("Player"):
        is_any_player_in_melee_range = true
        player_in_melee_range.emit(true) 

func _on_melee_attack_range_area_body_exited(_body: Node2D) -> void:
    # if body.is_in_group("Player"):
    # # Check if we have still bodies player in the area
    #     if melee_attack_range_area.get_overlapping_bodies().size() == 0:
    #         player_in_melee_range.emit(false) 
    var bodies = melee_attack_range_area.get_overlapping_bodies()
    for body_remaining in bodies:
        if body_remaining.is_in_group("Player"):
            is_any_player_in_melee_range = true
            player_in_melee_range.emit(true) 
            return
    
    is_any_player_in_melee_range = false
    player_in_melee_range.emit(false) 

#================ END OF MELEE ATTACK PART ================



func _on_animation_player_animation_finished(anim_name: StringName) -> void:
    
    # Handle melee attack completion
    if anim_name == "attack":
        var current_state = $StateMachine.current_state
        if current_state != null and current_state.has_method("complete_attack"):
            current_state.complete_attack()
    
    # Resume state animation
    var new_animation = $StateMachine.current_state.state_animation_name
    if new_animation == null:
        return
    if not animation_player.has_animation(new_animation):
        return
    animation_player.play(new_animation)



#region Loot part
################ Loot part #################
func drop_loot() -> void:
    # Do nothing if the loot table is null or we are not in server mode
    if loot_table == null or not multiplayer or not multiplayer.is_server():
        return
    # print(multiplayer.get_unique_id(), " - Enemy.gd - drop_loot - Dropping loot")
    for stack: ItemStack in loot_table.roll_loot():
        # var spawned_item : ItemDrop = item_drop.instantiate()
        # print(multiplayer.get_unique_id(), " - Enemy.gd - drop_loot - Spawning item: ", stack.item.item_name, " - count: ", stack.count)
        EventBus.spawn_item_drop.emit(stack, global_position, current_world)
        # spawned_item.stack = stack
        # spawned_item.global_position = global_position
        # get_tree().current_scene.add_child.call_deferred(spawned_item)

#endregion Loot part

#================ TARGETING PART ================
# ===================== AGGRO AREA DETECTION =====================
func _on_aggro_area_body_entered(body: Node2D) -> void:
    """Called when a body enters the aggro area. Handles player detection and targeting."""
    if not body.is_in_group("Player"):
        return
    # Only the server decides which player is the focus, then tells all peers
    if multiplayer != null and multiplayer.is_server():
        var target_player = body
        if target_player.is_hidden:
            return
        # Broadcast target selection to all peers (and apply locally)
        set_target_peer.rpc(target_player.peer_id)
    else:
        # Non-server clients do not decide transitions; they wait for server RPC
        pass

# ===================== TARGETING (SERVER-AUTHORITATIVE) =====================
@rpc("authority", "call_local", "reliable")
func set_target_peer(new_target_peer_id: int) -> void:
    """Set the target player by peer ID. This is server-authoritative."""
    target_peer_id = new_target_peer_id
    var target_player = _find_player_by_peer_id(target_peer_id)
    if target_player == null:
        return
    if target_player.is_hidden:
        return
    player = target_player
    target_changed.emit(target_player)

func _find_player_by_peer_id(peer_id_to_find: int) -> Node:
    """Helper function to find a player node by their peer ID."""
    for n in get_tree().get_nodes_in_group("Player"):
        if n.peer_id == peer_id_to_find:
            return n
    return null

#================ END OF TARGETING PART ================


#region Visibility update between world

func server_send_state_transition_to_players_in_current_world(new_state_name: String) -> void:
    if not multiplayer or not multiplayer.is_server():
        return
    var players_id_in_current_world = Helper.get_players_id_in_current_world(current_world)
    for player_id in players_id_in_current_world:
        server_send_state_transition.rpc_id(player_id, new_state_name)
    # The server should also transition the state locally
    server_send_state_transition(new_state_name)

@rpc("authority", "call_local", "reliable")
func server_send_state_transition(new_state_name: String) -> void:
    $StateMachine.current_state.emit_signal("transitioned", $StateMachine.current_state, new_state_name)
#endregion

func force_visibility_update() -> void:
    if sync == null or not multiplayer or not multiplayer.is_server():
        return
    for players_id in EventBus.players:
        if players_id in Helper.get_players_id_in_current_world(current_world):
            sync.set_visibility_for(players_id, true)
        else:
            sync.set_visibility_for(players_id, false)
    # sync.update_visibility()
