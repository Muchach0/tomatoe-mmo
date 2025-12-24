class_name Player
extends CharacterBody2D
# This demo is an example of controling a high number of 2D objects with logic
# and collision without using nodes in the scene. This technique is a lot more
# efficient than using instancing and nodes, but requires more programming and
# is less visual. Bullets are managed together in the `bullets.gd` script.


@export var INIT_NUMBER_OF_LIFE := 5
## The number of bullets currently touched by the player.
var touching := 0


@export var speed: float = 300.0

@onready var sprite_size: Vector2 = ($Sprite2D.texture.get_size() * scale) / 2

var number_of_life := INIT_NUMBER_OF_LIFE
var is_invincible: bool = false # used with safe zone, can be used later to make the player invincible for a short time after being hit.
var is_hidden: bool = false # used when the player should be hidden

var init_position = position
@export var synced_position := Vector2()
# Interpolation variables for smooth remote player movement
@export var interpolation_speed: float = 10.0  # Adjust this value to control interpolation speed (higher = faster, recommended: 8-15)
var target_position: Vector2 = Vector2()
# @onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Array of BulletStrategy holding all the strategies applied to the player
@export var bullet_strategies: Array[BulletStrategy] = []

# Skills available to the player
# Index 0: SimpleShootSkill (left click)
# Index 1: AOEShootSkill (right click)
@export var skills: Array[Skill] = []

@onready var state_machine : Node = $StateMachine
@onready var sprite: Sprite2D = $Sprite2D

var peer_id = 0
var motion:= Vector2()
var last_nonzero_motion: Vector2 = Vector2.DOWN

# Mapping from cardinal direction to Sprite2D horizontal frame index (hframe)
# Adjust these values in the editor to match your spritesheet layout.
@export var direction_frames := {"down": 0, "right": 1, "left": 2, "up": 3,}

var is_force_field_enabled: bool = false # used to enable/disable the force field effect
@onready var force_field_area: Area2D = $ForceFieldArea
@onready var force_field_timer: Timer = $ForceFieldArea/ForceFieldTimer
var bonus_number: int = 0 # The number of bonuses picked up by the player

@onready var sync = $MultiplayerSynchronizer
@onready var timer_glow: Timer = $TimerGlow
@onready var health_bar: ProgressBar = $HealthBar

@onready var current_zone = "zone0" # Starting zone

var inventory: Inventory = Inventory.new()
var current_world: String = ""

@onready var visibility_area: Area2D = $VisibilityArea2D # variable to store the visibility area of the player

const MAX_DISTANCE_TO_TELEPORT: float = 100.0

func _ready() -> void:
    # Duplicate the shader material to make individual modifications
    if material != null:
        material = material.duplicate()
        material.set_shader_parameter("enable_effect", false)
    print("player.gd - _ready() - id: " + str(peer_id) + " - is_multiplayer_authority: " + str(is_multiplayer_authority()))
    EventBus.connect("sync_bonus_count", on_sync_bonus_count)
    EventBus.add_upgrade_to_player.connect(on_add_upgrade_to_player)
    # EventBus.refresh_visibility.connect(on_refresh_visibility)

    # Initialize interpolation target
    target_position = position
    synced_position = position

    # Enable camera for local player only
    # Use a timer to ensure multiplayer authority is properly set
    await get_tree().process_frame
    setup_camera()
    if timer_glow != null:
        timer_glow.timeout.connect(stop_glow)
    if health_bar != null:
        health_bar.value = number_of_life

    if multiplayer != null and is_multiplayer_authority():
        EventBus.attach_inventory_to_ui.emit(inventory)
    # add_sync_visibility_filter()

    # Initialize default skills if not already set
    if skills.size() == 0:
        skills.append(SimpleShootSkill.new())
        skills.append(AOEShootSkill.new())

    if visibility_area != null and multiplayer.is_server(): # only server deals with visibility area
        visibility_area.body_entered.connect(on_visibility_area_body_entered)
        visibility_area.body_exited.connect(on_visibility_area_body_exited)
        EventBus.sync_visibility_after_player_moved_to_new_world.connect(sync_visibility_after_player_moved_to_new_world)

    EventBus.move_player_to_destination_world.connect(move_player_to_destination_world)
    
    on_refresh_visibility(1, true) # Refresh visibility for the player with the server - useful for the first time the player connects to the server.

    # EventBus.connect("player_respawned", _on_player_respawned)
    # The player follows the mouse cursor automatically, so there's no point
    # in displaying the mouse cursor.
    # Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func setup_camera() -> void:
    # Only enable camera for the local player (the one with multiplayer authority)
    if multiplayer == null or is_multiplayer_authority():
        EventBus.set_player_camera.emit(self)
        # emit_signal("set_player_camera", self)
        # camera.enabled = true
        # camera.make_current()
        # print("Camera enabled for local player: " + str(peer_id))
    # else:
    #     camera.enabled = false
    #     print("Camera disabled for remote player: " + str(peer_id))

func on_sync_bonus_count(bonus_number_from_server: int, _is_bonus_picked_up: bool = false) -> void:
    bonus_number = bonus_number_from_server

func main_action_pressed() -> void:
    # This function is called when the main action is pressed (e.g., spacebar).
    # It can be used to trigger an action, such as shooting or interacting.
    print("Main action pressed")
    
    if multiplayer != null and not is_multiplayer_authority():
        print("Not the authority, cannot perform main action")
        return

    # TODO: CHECKING HERE IF WE ARE ALLOWED TO DO THAT - we should check if a bonus is available - ignoring for now
    if bonus_number <= 0:
        print("No bonus available, cannot perform main action")
        return
    activation_of_force_field.rpc(true)  # Call the function to activate the force field effect on all peers
    force_field_timer.start()  # Start the force field timer to disable the effect after a certain time

    # Add your custom logic for main action here, e.g., shoot, interact, etc.



func _physics_process(_delta: float) -> void:
    if is_hidden:
        return  # If the player is hidden, we don't process anything.
    if multiplayer == null or is_multiplayer_authority():
        var x_input = Input.get_axis("ui_left", "ui_right")
        var y_input = Input.get_axis("ui_up", "ui_down")
        var input_vector = Vector2(x_input, y_input)
        motion = input_vector.normalized() if input_vector.length() > 0.01 else Vector2.ZERO
        synced_position = position
        target_position = position  # Keep target in sync for local player

        if motion.length() > 0.01:
            last_nonzero_motion = motion
            _update_sprite_direction_from_motion(last_nonzero_motion)

        if Input.is_action_just_pressed("ui_accept"):
            main_action_pressed()
            # Add your custom logic for ui_accept here, e.g., interact, shoot, etc.

    else:
        # Smooth interpolation for remote players to avoid jitter
        if target_position != synced_position:
            target_position = synced_position
        
        # Interpolate position smoothly instead of snapping
        if target_position.distance_to(position) < MAX_DISTANCE_TO_TELEPORT:
            position = position.lerp(target_position, interpolation_speed * _delta)
        else:
            # Just teleport player if target position is too different from the current position
            # This is useful for world transition : we don't want to interpolate the player position if it's too far away.
            # This is to avoid jittering / aggro of enemies when the player is teleported to a new world.
            position = target_position

    # TODO: Fix state machine later
    # # If the player is not moving, we don't need to update the state machine
    # if x_input == 0 and y_input == 0 and state_machine.current_state is not PlayerIdle:
    #     state_machine.current_state.emit_signal("transitioned", state_machine.current_state, "PlayerIdle")
    # elif x_input != 0 or y_input != 0:
    #     # If the player is moving, we can transition to the walking state
    #     if state_machine.current_state is not PlayerWandering:
    #         state_machine.current_state.emit_signal("transitioned", state_machine.current_state, "PlayerWandering")

    # Move the player according to the inputs
    
    # synced_position = position
    # else:
    #     position = synced_position
        # If this is not the authority, we just update the position
        # based on the motion vector.
    # position += motion * delta
    
    # Getting the movement of the mouse so the sprite can follow its position.
    # if event is InputEventMouseMotion:
    #     position = event.position - Vector2(0, 16)

    # # Get input from the joystick
    # var x_input = Input.get_axis("ui_left", "ui_right")
    # var y_input = Input.get_axis("ui_up", "ui_down")

    # If the player is not moving, we don't need to update the state machine
    if not motion and state_machine.current_state is not PlayerIdle:
        state_machine.current_state.emit_signal("transitioned", state_machine.current_state, "PlayerIdle")
    elif motion:
        # If the player is moving, we can transition to the walking state
        if state_machine.current_state is not PlayerWandering:
            state_machine.current_state.emit_signal("transitioned", state_machine.current_state, "PlayerWandering")
        

    # Move the player according to the inputs
    # var direction = Vector2(x_input, y_input).normalized()
    velocity = motion * speed
    move_and_slide()
    # position += motion * speed * delta

    # # Clamp the player's position to stay within the screen bounds
    # var screen_size = get_viewport_rect().size
    # position.x = clamp(position.x, 0 + sprite_size.x , screen_size.x - sprite_size.x)
    # position.y = clamp(position.y, 0 + sprite_size.y, screen_size.y - sprite_size.y)


# func _on_body_shape_exited(_body_id: RID, _body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
#     touching -= 1
#     # When non of the bullets are touching the player,
#     # sprite changes to happy face.
#     if touching == 0:
#         material.set_shader_parameter("enable_effect", false)
#         # sprite.frame = 0

func _isPlayerCrossingAnAreaWithZoneName(area: Area2D) -> String:
    if area == null:
        return ""
    for group in area.get_groups():
        if group.begins_with("zone"):
            return group
    return ""

# func _on_area_entered(area: Area2D) -> void:
func _on_hitbox_area_entered(area: Area2D) -> void:
    if "star" in area.get_groups():
        if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
            EventBus.emit_signal("star_touched", name)
    if "safeZone" in area.get_groups():
        if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
            is_invincible = true
    if "bonus" in area.get_groups():
        if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
            EventBus.emit_signal("bonus_touched", area.name)  # Emit a signal to notify the game logic that the player touched a bonus
    if "upgrade" in area.get_groups():
        if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
            EventBus.upgrade_touched_on_authority_player.emit(area.name, area.bullet_strategy, name)  # Emit a signal to notify the game logic that the player touched a bonus
            # bullet_strategies.append(area.bullet_strategy) # Adding the upgrade to the player's bullet strategies
            # print("Bullet strategies: ", bullet_strategies)

            # TODO: Adding the upgrade to the player's bullet strategies should be handled by the server and broadcasted.
            # TODO: The server should also remove the upgrade from the scene.
    
    
    # # Zone transition detection
    # var zone_name = _isPlayerCrossingAnAreaWithZoneName(area)
    # if zone_name != "":
    #     if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
    #         zone_entering(zone_name)


    pass # Replace with function body.


func _on_hitbox_area_exited(area: Area2D) -> void:
    if "safeZone" in area.get_groups():
        if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
            is_invincible = false

    # # Zone transition detection
    # var zone_name = _isPlayerCrossingAnAreaWithZoneName(area)
    # if zone_name != "":
    #     if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
    #         zone_exiting(zone_name)


    pass # Replace with function body.


func stop_glow() -> void:
    material.set_shader_parameter("enable_effect", false)
func start_glow() -> void:
    material.set_shader_parameter("enable_effect", true)
    timer_glow.start()

func take_damage(damage:int, from_player_id: int) -> void:
    # print("Player.gd - take_damage() - Taking damage: ", damage, " from player id: ", from_player_id)
    if multiplayer != null and not is_multiplayer_authority(): # If this is not the authority, we don't process the hit.
        # print("Player.gd - take_damage() - Not the authority, cannot take damage")
        return
    if is_invincible: # Do nothing if the player is invincible.
        # print("Player.gd - take_damage() - Player is invincible")
        return
    
    # Check if the bullet belongs to this player (prevent self-damage)
    if peer_id == from_player_id:
        # print("Player avoided self-damage from own bullet")
        return

    sync_take_damage_on_all_peers.rpc(number_of_life, damage, from_player_id)
    # If the player is invincible, we don't want to decrease the number of lives.
    # print("Player touched by a bullet")
    # touching += 1
    # start_glow()
    # number_of_life -= damage
    # print("Player took damage: ", damage, " from player id: ", from_player_id)
    # EventBus.emit_signal("player_hit", name, number_of_life)
    # # if touching >= 1:
    # #     material.set_shader_parameter("enable_effect", true)
    #     # sprite.frame = 1
    return # Replace with function body.


@rpc("any_peer", "call_local", "reliable") # Function called on local authority to all players to sync take damage
func sync_take_damage_on_all_peers(number_of_life_from_owner:int, damage:int, from_player_id: int) -> void:
    # print("player.gd - sync_take_damage_on_all_peers() - Player took damage: ", damage, " from player id: ", from_player_id)
    number_of_life = number_of_life_from_owner - damage
    health_bar.value = number_of_life
    start_glow()
    var player_owner_id = multiplayer.get_remote_sender_id()
    EventBus.player_hit.emit(player_owner_id, name, number_of_life)
    return

func hide_player() -> void:
    # This function is called when the player is hit and should be hidden.
    # It can be used to hide the player sprite or disable player controls.
    print("Hiding player: " + name)
    is_hidden = true
    visible = false
    # Hide the player sprite
    $Sprite2D.visible = false
    # $DetectionArea.monitoring = false
    # $DetectionArea.monitorable = false
    # Disable player controls
    $StateMachine.current_state.emit_signal("transitioned", $StateMachine.current_state, "PlayerIdle")
    $Hitbox.monitoring = false
    $Hitbox.monitorable = false
    EventBus.player_died.emit(peer_id)
    if health_bar != null:
        health_bar.visible = false

func reset_player(new_position: Vector2) -> void:
    # This function is called when the player is respawned.
    is_hidden = false
    visible = true
    position = new_position
    synced_position = new_position
    target_position = new_position  # Reset interpolation target
    number_of_life = INIT_NUMBER_OF_LIFE
    is_invincible = false  # Reset the invincibility state
    touching = 0  # Reset the number of bullets touching the player
    # Showing the player sprite and enabling the detection area
    $Sprite2D.visible = true
    # $DetectionArea.monitoring = true
    # $DetectionArea.monitorable = true
    $Hitbox.monitoring = true
    $Hitbox.monitorable = true
    material.set_shader_parameter("enable_effect", false)
    # Ensure camera is properly set up after respawn
    setup_camera()
    if health_bar != null:
        health_bar.visible = true
        health_bar.value = number_of_life


####################### FORCE FIELD SECTION #######################
@rpc("any_peer", "call_local", "reliable")
func activation_of_force_field(should_activate_force_field) -> void:
    # This function is called to activate the force field effect.
    if should_activate_force_field:
        print("Activating force field")
        is_force_field_enabled = true
        force_field_area.visible = true
        force_field_area.monitorable = true
        force_field_area.monitoring = true
        EventBus.emit_signal("bonus_used")  # Notify the game logic that a bonus was used
        

    else:
        print("Deactivating force field")
        is_force_field_enabled = false
        force_field_area.visible = false
        force_field_area.monitorable = false
        force_field_area.monitoring = false
    # material.set_shader_parameter("enable_effect", true)  # Enable the force field effect in the shader
    # sprite.frame = 1  # Change the sprite frame to indicate the force field is


func _on_force_field_timer_timeout() -> void: # When the timer of force field is over, we disable the force field effect on all peers from the authority.
    if multiplayer != null and not is_multiplayer_authority():
        print("Not the authority, cannot perform main action")
        return
    activation_of_force_field.rpc(false)


########################### UPGRADE SECTION #######################
func on_add_upgrade_to_player(bullet_strategy: BulletStrategy, player_name: String) -> void:
    if player_name != name:
        return
    print("player.gd - on_add_upgrade_to_player() - Adding upgrade to player: ", player_name)
    bullet_strategies.append(bullet_strategy)
    print("Bullet strategies: ", bullet_strategies)


# ------------------------- SPRITE DIRECTION SECTION -------------------------
func _get_cardinal_from_vector(direction: Vector2) -> String:
    # Returns one of: "left", "right", "up", "down"
    # Chooses the dominant axis to avoid flickering on diagonals
    if absf(direction.x) >= absf(direction.y):
        return "right" if direction.x > 0.0 else "left"
    else:
        return "down" if direction.y > 0.0 else "up"


func _update_sprite_direction_from_motion(direction: Vector2) -> void:
    if sprite == null:
        return
    # Only attempt to change frames if the texture is set up as a spritesheet
    if sprite.hframes <= 1 and sprite.vframes <= 1:
        return

    var dir_name := _get_cardinal_from_vector(direction)
    var target_frame: int = int(direction_frames.get(dir_name, 0))
    sprite.frame = target_frame
    # In Godot 4, set the horizontal frame using frame_coords.x
    # var coords := sprite.frame_coords
    # coords.x = target_hframe
    # sprite.frame_coords = coords





#region VISIBILITY SYNCHRONIZER SECTION =================================================================

func move_player_to_destination_world(player_id: int, destination_world: String, destination_offset: Vector2) -> void:
    if player_id != peer_id:
        return
    current_world = destination_world
    if EventBus.move_player_inside_world.is_connected(move_player_inside_world):
        return
    EventBus.move_player_inside_world.connect(move_player_inside_world)
    return

func move_player_inside_world(spawn_point: Vector2, world_name: String) -> void:
    position = spawn_point
    synced_position = spawn_point
    target_position = spawn_point
    
    current_world = world_name
    EventBus.current_world_player_location = world_name
    return

func sync_visibility_after_player_moved_to_new_world() -> void:
    if not multiplayer.is_server(): # Only the server handles the visibility synchronization.
        return
    for body in visibility_area.get_overlapping_bodies():
        if body is not Player:
            continue
        if body.peer_id == peer_id:
            continue
        if EventBus.players[body.peer_id]["current_world"] == EventBus.players[peer_id]["current_world"]:
            on_refresh_visibility.rpc(body.peer_id, true)
        else:
            on_refresh_visibility.rpc(body.peer_id, false)

# 1.a - A zone is entered on server area
func on_visibility_area_body_entered(body: Node2D) -> void: 
    # print(peer_id, " - player.gd - zone_entering() - Zone entering: ", zone_name)
    if not multiplayer.is_server(): # Only the authority handles the visibility synchronization.
        return
    if body is not Player:
        return
    print(multiplayer.get_unique_id(), " - player.gd - on_visibility_area_body_entered() - Body entered: ", body.name, " - body peer id: ", body.peer_id, " - peer id: ", peer_id)

    if body.peer_id == peer_id:
        return
    
    if EventBus.players[body.peer_id]["current_world"] != EventBus.players[peer_id]["current_world"]:
        return
    on_refresh_visibility.rpc(body.peer_id, true)
    # EventBus.zone_touched.emit(peer_id, body.peer_id, true)
    # sync.add_visibility_filter(visibility_filter)

# 1.b - A zone is exited on local client
func on_visibility_area_body_exited(body: Node2D) -> void: 
    # print(peer_id, " - player.gd - zone_exiting() - Zone exiting: ", zone_name)
    if not multiplayer.is_server(): # Only the authority handles the visibility synchronization.
        return
    if body is not Player:
        return
    if body.peer_id == peer_id:
        return
    # EventBus.zone_touched.emit(peer_id, body.peer_id, false)
    on_refresh_visibility.rpc(body.peer_id, false)



@rpc("any_peer", "call_local", "reliable")
func on_refresh_visibility(body_peer_id: int, is_entering: bool) -> void:

    if is_multiplayer_authority(): # Only the authority handles the visibility synchronization.
        print(multiplayer.get_unique_id(), " - player.gd - on_refresh_visibility() - AUTHORITY - Refreshing visibility for peer: ", body_peer_id, " - is entering: ", is_entering)
        visible = true
        sync.set_visibility_for(1, true)
        sync.set_visibility_for(body_peer_id, is_entering)
        return
    else:
        print(multiplayer.get_unique_id(), " - player.gd - on_refresh_visibility() - Refreshing visibility for peer: ", body_peer_id, " - is entering: ", is_entering)
        if is_entering or multiplayer.is_server():
            visible = true
        else:
            visible = false
            # TODO: should also disable collision with the player
            # sync.set_visibility_for(body_peer_id, false)

    # if not multiplayer.is_server(): # Only the authority handles the visibility synchronization.
    #     return
    # if peer_id == 0 or peer_id == peer_id:
    #     return
    # if "zone" not in EventBus.players[peer_id] or "zone" not in EventBus.players[peer_id]:
    #     return
    # # EventBus.zone_touched.emit(peer_id, body.peer_id, false)
    # return

# 5.a. Called on all the clients to refresh the visibility of the players with the new players dict
# @rpc("any_peer", "call_local", "reliable")
# func on_refresh_visibility(players_dict: Dictionary) -> void:
#     # if not is_multiplayer_authority():
#     #     return

#     if is_multiplayer_authority(): # local player is always visible on the server
#         sync.set_visibility_for(1, true)
    
#     # print(multiplayer.get_unique_id(), " - player.gd - on_refresh_visibility() - Players: ", players_dict)

#     for remote_peer_id in players_dict.keys():
#         if remote_peer_id == 0 or remote_peer_id == peer_id:
#             continue
#         if "zone" not in players_dict[remote_peer_id] or "zone" not in players_dict[peer_id]:
#             continue

#         # Check if the remote player and the local player have a common zone
#         if has_a_common_zone_with_player(players_dict, remote_peer_id, peer_id): # players in the same zone
#             # print(multiplayer.get_unique_id(), " - player.gd - on_refresh_visibility() - setting visibility for remote peer id: ", remote_peer_id, " to true")
#             visible = true
#             if is_multiplayer_authority(): 
#                 sync.set_visibility_for(remote_peer_id, true)
#         else: # players not in the same zone
#             # print(multiplayer.get_unique_id(), " - player.gd - on_refresh_visibility() - setting visibility for remote peer id: ", remote_peer_id, " to false")
#             if is_multiplayer_authority():
#                 visible = true # local player is always visible
#                 sync.set_visibility_for(remote_peer_id, true)
#             else : # remote player
#                 visible = false
#     return


# # 5.b. Helper function to check if two players have a common zone
# func has_a_common_zone_with_player(players_dict: Dictionary, remote_peer_id: int, local_id: int) -> bool:
#     if "zone" not in players_dict[remote_peer_id] or "zone" not in players_dict[local_id]:
#         return false
#     for zone in players_dict[remote_peer_id]["zone"]:
#         if zone in players_dict[local_id]["zone"]:
#             return true
#     return false

#endregion
