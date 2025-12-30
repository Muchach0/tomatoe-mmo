extends Node

# @onready var star: Area2D = $Star

# @onready var player: Area2D = $EventBus.playership
# @onready var init_player_position: Vector2 = player.position

# @onready var bullets: Node2D = $Bullets
# @onready var init_bullet_count: int = 0
# const INCREMENT_BULLET_COUNT = 50

@onready var level_mmo_logic: Node2D = get_parent()
@onready var portal_instance: PortalInstance = get_node("../PortalInstance")

var current_level := 1

# Enemy spawner reference (optional - will fallback to direct instantiation if not found)
# @onready var enemy_spawner: MultiEventBus.playerspawner = get_node_or_null("EnemySpawner")

# Wave system variables
const TOTAL_WAVES = 5
var current_wave := 1
var enemies_in_current_wave := 0
var enemies_killed_in_current_wave := 0
var is_wave_active := false

const arena_dimension_x = [250, 850]
const arena_dimension_y = [100, 650]

# Global spawner names
const GLOBAL_SPAWNER_NAME = "Dungeon_Level_1_Global_Spawner"
const GLOBAL_SPAWNER_NAME_WITH_ID = "Dungeon_Level_1_Global_Spawner_1"

# Enemy spawn configuration per wave
var wave_config = {
    1: {"enemy_count": 3, "enemy_types": ["Dummy"]},
    2: {"enemy_count": 3, "enemy_types": ["Orc"]},
    3: {"enemy_count": 3, "enemy_types": ["Tomatoe_Wizard"]},
    4: {"enemy_count": 7, "enemy_types": ["Skeleton", "Necromancer", "Tomatoe_ennemy", "Dino_green", "Orc"]},
    5: {"enemy_count": 1, "enemy_types": ["Tomatoe_Seed_Boss"]},
}


# Enemy scene paths
var enemy_scenes = {
    "Dummy": "res://Prefab/Enemies/Dummy.tscn",
    "Skeleton": "res://Prefab/Enemies/Dungeon/Skeleton.tscn",
    "Tomatoe_Wizard": "res://Prefab/Enemies/Tomatoe/Tomatoe_Wizard.tscn",
    "Tomatoe_ennemy": "res://Prefab/Enemies/Tomatoe/Tomatoe_ennemy.tscn",
    "Dino": "res://Prefab/Enemies/Dino/Dino_Green.tscn",
    "Tomatoe_Seed_Boss": "res://Prefab/Enemies/Tomatoe/Tomatoe_Seed_Boss.tscn",
    "Orc": "res://Prefab/Enemies/Orc/Orc.tscn",
}


# bool to store if a game with bullets is currently running
# We hide the player connecting in case a round is already running, necessary as the bullets are instantiated locally on round start.
var is_a_game_with_bullets_currently_running: bool = false 

# @onready var bonus_node: Area2D = $Bonus
var bonus_number: int = 0 # This will hold the number of bonuses collected by the player



# var EventBus.players: Dictionary = {} # This will hold player data for synchronization

var current_world_name: String = "" # Name of the world - useful to start the waves only if a player entered the world

func _ready() -> void:
    # Connect signals to the event bus
    # EventBus.connect("player_hit", _on_player_hit)
    # EventBus.connect("star_touched", send_star_touched_on_all_peers)
    # EventBus.connect("add_player", add_player)
    EventBus.connect("remove_player", remove_player)
    EventBus.connect("set_player_node_name_and_init_position", set_player_node_name_and_init_position)
    # EventBus.connect("bonus_touched", on_bonus_touched_by_player)
    # EventBus.connect("bonus_used", server_handles_bonus_used_by_player)
    EventBus.connect("one_enemy_die", _on_enemy_died)
    # EventBus.connect("restart_button_pressed", _on_button_restart_pressed)
    
    # Setup enemy spawner
    # if enemy_spawner:
    #     enemy_spawner.spawn_function = _spawn_enemy_callback

    if multiplayer.is_server():
        EventBus.emit_signal("is_server_label_visible", true)
    # EventBus.connect("player_respawned", self, "_on_player_respawned")

    EventBus.sync_visibility_after_player_moved_to_new_world.connect(on_player_moved_inside_world)

    current_world_name = level_mmo_logic.name # Get the name of the parent node - the world
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - _ready() - Current world name: %s" % current_world_name)




func on_player_moved_inside_world() -> void:
    if !multiplayer.is_server():
        return

    # If no players are in the current world, do nothing
    if not Helper.get_players_id_in_current_world(current_world_name):
        return
    
    # Else, at least 1 player moved to the current world
    
    # if player_id != 1:
    # player_info["wave_completed"] = false
    # EventBus.players[player_id] = player_info
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - on_player_moved_inside_world() - EventBus.players data: %s" % str(EventBus.players))
    
    # Start the first wave when the first player joins (and no game is running)
    if not is_wave_active and not is_a_game_with_bullets_currently_running:
        print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - add_player() - First player joined, starting wave system")
        start_first_wave.call_deferred()

func set_player_node_name_and_init_position(player_id, player_node_name, init_position) -> void:
    if !multiplayer.is_server():
        return
    if player_id not in EventBus.players:
        print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - set_player_node_name() - Player ID %d not found in EventBus.players dictionary." % player_id)
        return
    # Setting the player node name and initial position in the EventBus.players dictionary
    # EventBus.players[player_id]["player_node_name"] = player_node_name  # Store the player node name
    # EventBus.players[player_id]["init_position"] = init_position  # Store the initial position of the player
    # print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - set_player_node_name() - Player %d node name set to %s" % [player_id, player_node_name])
        
    # if a player joins during an active wave, update them with current status
    if is_a_game_with_bullets_currently_running and is_wave_active:
        print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - set_player_node_name_and_init_position() - Player joining during active wave")
        # Don't mark as wave_completed - let them participate in current wave
        # show_display_server_busy_label.rpc_id(player_id, is_a_game_with_bullets_currently_running)  # Notify about ongoing game
        # show_current_level_and_wave_info.rpc_id(player_id, current_level, current_wave, enemies_killed_in_current_wave, enemies_in_current_wave)  # Show current wave info
        update_wave_ui.rpc_id(player_id, current_level, current_wave, enemies_killed_in_current_wave, enemies_in_current_wave)  # Show current wave status




# Called on signal _on_player_disconnected
func delete_player_node_on_server(player_id) -> void:
    if !multiplayer.is_server():
        return
    if player_id in EventBus.players:
        var player_node_name = EventBus.players[player_id].get("player_node_name")
        if player_node_name:
            var player_node = get_node_or_null(NodePath(player_node_name))
            if player_node:
                player_node.queue_free()  # Free the player node if it exists
                print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - delete_player_on_server() - Player node %s removed." % player_node_name)
            else:
                print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - delete_player_on_server() - Player node %s not found." % player_node_name)
        else:
            print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - delete_player_on_server() - Player node name not found for ID %d." % player_id)
    else:
        print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - delete_player_on_server() - Player ID %d not found in EventBus.players dictionary." % player_id)

# Called on signal _on_player_disconnected
func remove_player(player_id) -> void:
    if !multiplayer.is_server():
        return
    delete_player_node_on_server(player_id)  # Call the function to delete the player on the server
    if player_id in EventBus.players:
        EventBus.players.erase(player_id)  # Remove the player from the EventBus.players dictionary
    if len(EventBus.players) == 0: # If no EventBus.players are left, we reset the game state
        reset_game_state_on_server()
        return
    if all_players_completed_wave(): # Checking if the game should finish
        print("All EventBus.players completed the wave, finishing the game.")
        for peer_id in Helper.get_players_id_in_current_world(current_world_name):
            finish_game.rpc_id(peer_id, true) # Call finish_game with is_win set to true
    

# Called by the authoritative player when a player is hit
# func _on_player_hit(player_owner_id, player_name, number_of_life: int) -> void:
#     print("game_logic - Player hit! Remaining lives: %d" % number_of_life)

#     EventBus.audio_explosion_play.emit()
#     if multiplayer.is_server():
#         EventBus.players[player_owner_id]["number_of_life"] = number_of_life
#         if number_of_life <= 0:
#             print("game_logic - Player %s hit and has no lives left, finishing game." % name)
#             hide_player_from_server_to_all_peers.rpc(player_name)  # Hide the player from all peers
#             # get_node(NodePath(player_name)).queue_free()
#             # When a player is dead, we call finish_game with is_win set to false to all the EventBus.players
#             finish_game.rpc(false)  # Call finish_game with is_win set to false
#         else:
#             print("game_logic - Player %s hit! Remaining lives: %d" % [name, number_of_life])

    # Handle player hit logic here, e.g., update UI or play sound
    # player_was_hit.rpc(player_name, number_of_life)



# The button is restart is pressed by the player (local)
func _on_button_restart_pressed() -> void:
    print("game_logic - Restart button pressed")
    for player_id in Helper.get_players_id_in_current_world(current_world_name):
        restart_game.rpc_id(player_id)
    # EventBus.emit_signal("player_respawned")
    # player.visible = true
    

    # Freeing the bullets and re-instantiate it
    # bullets.queue_free()

    # # Spawning a new player
    # var player = preload("res://prefab/player_ship.tscn").instantiate()  # Create an instance of the food scene
    # # player.position = init_player_position
    # add_child.call_deferred(player)

    # Spawning the bullets
    # bullets = preload("res://prefab/bullets.tscn").instantiate()  # Create an instance of the bullets script
    # bullets.position = Vector2.ZERO
    # bullets.init_bullet_count = init_bullet_count
    # add_child.call_deferred(bullets)

@rpc("any_peer", "call_local", "reliable")
func restart_game() -> void:
    print("Game restarted.")
    # Handle game restart logic here, e.g., reset player positions, scores, etc.
    # Reset EventBus.players' wave_completed status
    for peer_id in EventBus.players.keys():
        EventBus.players[peer_id]["wave_completed"] = false

    # Hide the star since we're using wave-based gameplay
    # star.visible = false

    # Reset the game over screen and the server busy label
    # game_over_screen.visible = false
    EventBus.game_over_screen_text_and_visibility.emit("", "Restart", false)
    show_display_server_busy_label(false)  # Hide the server busy label

    if multiplayer.is_server():
        # Clear any existing enemies first
        clear_all_enemies()
        
        # Reset game state
        is_a_game_with_bullets_currently_running = true  # Starting a level with bullets, so setting the flag to true
        # reset_bonus() # Move the bonus to a random position in the viewport and put back bonus count to 0
        
        # Reset wave system
        current_wave = 1
        enemies_in_current_wave = 0
        enemies_killed_in_current_wave = 0
        is_wave_active = false
        
        for player_id in EventBus.players.keys():
            # delete_player_node_on_server(player_id) # Delete the player node on the server if it still exists
            for peer_id in Helper.get_players_id_in_current_world(current_world_name):
                respawn_player.rpc_id(peer_id, player_id, EventBus.players[player_id], EventBus.players[player_id]["init_position"])  # Call respawn_player to respawn the player
            # EventBus.emit_signal("respawn_player", player_id, EventBus.players[player_id], EventBus.players[player_id]["init_position"]) # Emit a signal to notify to respawn the player

        # Only start waves if there are EventBus.players
        if len(EventBus.players) > 0:
            EventBus.start_level.emit(current_level, current_wave, enemies_killed_in_current_wave, enemies_in_current_wave)
            # EventBus.emit_signal("bullets_init_and_start", current_level) # Emit a signal to spawn bullets
            start_wave.call_deferred(current_wave) # Start the first wave
        


@rpc("any_peer", "call_local", "reliable")
func finish_game(is_win:= true) -> void:
    print("Game finished.")
    # Handle game finish logic here, e.g., show a win screen or play a sound
    if is_win:
        # Play win sound
        EventBus.audio_win_play.emit()
        # star.visible = false
        # if current_wave >= TOTAL_WAVES:
        # EventBus.game_over_screen_text_and_visibility.emit("Level completed! Victory!", "Restart", true)
        enable_portal_instance() # Enable the portal instance when the game is won
        # Show return to forest button when dungeon level is completed
        EventBus.show_return_to_forest_button.emit()
        # else:
        #     EventBus.game_over_screen_text_and_visibility.emit("Victory!", "Next Level", true)
        # init_bullet_count += INCREMENT_BULLET_COUNT
        # current_level += 1
    else :
        EventBus.game_over_screen_text_and_visibility.emit("Round Over!", "Restart", true)

    # Clear all enemies and flush all the bullets currently on the screen
    clear_all_enemies()
    # bullets._exit_tree()
    is_wave_active = false


func all_players_completed_wave() -> bool:
    # Check if all EventBus.players have completed the current wave
    for peer_id in EventBus.players.keys():
        if not EventBus.players[peer_id].get("wave_completed", false):
            return false
    return true


# @rpc("any_peer", "call_local", "reliable")
# func star_touched(player_name) -> void: # This function is called when a star is touched by any peer
#     var peer_id = multiplayer.get_remote_sender_id()
#     print(str(multiplayer.get_unique_id()) + " - level_dungeon_1_game_logic.gd - star_touched() - Star touched by peer: %s" % peer_id)
#     # Get the player node from the peer ID
    

#     # Play the star touched sound when someone touches the star
#     EventBus.audio_win_play.emit()

    
#     # print("Player node: ", player)
#     if multiplayer.is_server(): # only the server should delete the player
#         EventBus.players[peer_id]["wave_completed"] = true # Update the player's wave_completed status
#         # get_node(NodePath(player_name)).queue_free() # maybe not the best to queue_free the player, but it works for now - throw some errors.
#         hide_player_from_server_to_all_peers.rpc(player_name) # Hide the player from all peers
#         if all_players_completed_wave():
#             print("All EventBus.players completed the wave, finishing the game.")
#             finish_game.rpc(true) # Call finish_game with is_win set to true

# func send_star_touched_on_all_peers(player_name) -> void:
#     print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - send_star_touched_on_all_peers() - Player touched the star: %s" % player_name)
#     star_touched.rpc(player_name)
#     # Handle star touched logic here, e.g., increase score or play a sound


@rpc("any_peer", "call_local", "reliable")
func hide_player_from_server_to_all_peers(player_name) -> void:
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - hide_player_from_server_to_all_peers() - Hiding player: %s" % player_name)
    var player = get_node_or_null(NodePath(player_name))
    if player:
        player.hide_player()  # Call the hide_player function on the player node
        # Optionally, you can also queue_free the player node if you want to remove it
    # player.queue_free()

# @rpc("any_peer", "call_local", "reliable")


@rpc("any_peer", "call_local", "reliable")
func respawn_player(player_id, player_info, init_position) -> void:
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - respawn_player() - Respawning player %d at position %s" % [player_id, str(init_position)])
    var player_node_name = player_info.get("player_node_name")
    if player_node_name:
        var player_node = get_node_or_null(NodePath(player_node_name))
        if player_node:
            player_node.reset_player(init_position)  # Call the reset_player function on the player node
            print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - respawn_player() - Player %d respawned at position %s" % [player_id, str(init_position)])
        else:
            print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - respawn_player() - Player node %s not found." % player_node_name)
    else:
        print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - respawn_player() - Player node name not found for ID %d." % player_id)


@rpc("any_peer", "reliable")
func show_display_server_busy_label(should_display_server_busy_label) -> void: # called from server to connecting peer to indicate that a game with bullets is currently running
    EventBus.emit_signal("is_server_running_a_busy_round", should_display_server_busy_label) # Emit a signal to notify the UI that a game with bullets is currently running

# Deprecated - replaced by show_current_level_and_wave_info
# @rpc("any_peer", "reliable")
# func show_current_level_and_bullet_count(current_level_from_server, nb_bullets) -> void:
#     EventBus.emit_signal("start_level", current_level_from_server, nb_bullets) # Emit a signal to notify the UI to update the current level and number of bullets


func reset_game_state_on_server() -> void: # Called when the game is reset, e.g., when all EventBus.players are disconnected or when a new game starts
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - reset_game_state_on_server() - Resetting game state")
    current_level = 1
    # init_bullet_count = 0
    is_a_game_with_bullets_currently_running = false  # Reset the game state
    EventBus.players.clear()  # Clear the EventBus.players dictionary
    # Hide the star since we're using wave-based gameplay
    # star.visible = false
    
    # Reset wave system
    current_wave = 1
    enemies_in_current_wave = 0
    enemies_killed_in_current_wave = 0
    is_wave_active = false
    clear_all_enemies()



######################## BONUS SECTION ########################
# Called from the player.gd script when a bonus is touched by the player - local from player
# func on_bonus_touched_by_player(bonus_node_name: String) -> void:
#     print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - on_bonus_touched() - Bonus touched: %s" % bonus_node_name)
#     server_handles_bonus_touched_by_player.rpc(bonus_node_name)  # Call the server function to handle the bonus touch

# @rpc("any_peer", "call_local", "reliable")
# func server_handles_bonus_touched_by_player(bonus_node_name: String) -> void: # The server handles the bonus touch (make it disapear + store the bonus count)
#     if not multiplayer.is_server():
#         return  # Only the server should handle the bonus touch
#     print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - handles_bonus_touched_on_all_peers() - Bonus touched: %s" % bonus_node_name)
#     var touched_bonus_node = get_node_or_null(NodePath(bonus_node_name))
#     if not touched_bonus_node:
#         print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - handles_bonus_touched_on_all_peers() - Bonus node %s not found." % bonus_node_name)
#         return
#     touched_bonus_node.position = Vector2(-1000, -1000)  # Move the bonus node out of the viewport to make it disappear
#     bonus_number += 1  # Increment the bonus count
#     sync_bonus_count_on_peers.rpc(bonus_number, true)  # Call the function to refresh the bonus count on all peers

# func server_handles_bonus_used_by_player() -> void: # The server handles the bonus used by the player (make it disapear + store the bonus count)
#     if not multiplayer.is_server():
#         return  # Only the server should handle the bonus touch
#     print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - server_handles_bonus_used_by_player() - Bonus used by player")
#     bonus_number -= 1  # Decrement the bonus count
#     sync_bonus_count_on_peers.rpc(bonus_number, false)  # Call the function to refresh the bonus count on all peers

# @rpc("any_peer", "call_local", "reliable")
# func sync_bonus_count_on_peers(bonus_number_from_server: int, is_bonus_picked_up: bool) -> void: # Function called from server to all peers to synchronize the bonus count
#     print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - sync_bonus_count_on_peers() - Sync bonus count on peers: %d" % bonus_number_from_server)
#     bonus_number = bonus_number_from_server
#     EventBus.emit_signal("sync_bonus_count", bonus_number, is_bonus_picked_up) # Emit a signal to notify the UI that a bonus was touched - run on all peers except the server

# func reset_bonus() -> void: # This function is called to reset the bonus count and move the bonus node to a random position in the viewport
#     print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - reset_bonus() - Resetting bonus count and moving bonus node")
#     if not multiplayer.is_server():
#         return  # Only the server should move the bonus
#     bonus_number = 0  # Reset the bonus count
#     sync_bonus_count_on_peers.rpc(bonus_number, false)  # Call the function to refresh the bonus count on all peers
#     server_move_bonus_in_random_viewport_position()  # Move the bonus to a random position in the viewport

# func server_move_bonus_in_random_viewport_position() -> void: # This function is called to move the bonus to a random position in the viewport
#     if not multiplayer.is_server(): # Check if the multiplayer is server and if the bonus node exists
#         return  # Only the server should move the bonus
#     if not bonus_node:
#         print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - move_bonus_in_random_viewport_position() - Bonus node not found.")
#         return
#     var viewport_size = get_viewport_rect().size
#     var random_position = Vector2(randf_range(0, viewport_size.x), randf_range(viewport_size.y / 2, viewport_size.y - 160)) # place the bonus in the lower half of the viewport
#     bonus_node.position = random_position  # Move the bonus to a random position in the viewport
#     print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - move_bonus_in_random_viewport_position() - Bonus moved to: %s" % str(random_position))

######################## WAVE SYSTEM ########################

# Initialize and start the first wave when first player joins
func start_first_wave() -> void:
    if not multiplayer.is_server():
        return
    
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - start_first_wave() - Initializing wave system")
    
    # Set game state flags
    is_a_game_with_bullets_currently_running = true
    
    # Reset wave system
    current_wave = 1
    enemies_in_current_wave = 0
    enemies_killed_in_current_wave = 0
    is_wave_active = false
    
    # Initialize bullets system if needed
    EventBus.start_level.emit(current_level, current_wave, enemies_killed_in_current_wave, enemies_in_current_wave)
    # EventBus.emit_signal("bullets_init_and_start", current_level) # Emit a signal to spawn bullets
    
    # Start the first wave
    start_wave(current_wave)

# Called when an enemy dies
func _on_enemy_died(enemy_group_names: Array[StringName]) -> void:
    if not multiplayer.is_server():
        return
    if not is_wave_active:
        return
    if not GLOBAL_SPAWNER_NAME in enemy_group_names:
        return
    
    enemies_killed_in_current_wave += 1
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - _on_enemy_died() - Enemy died. Killed: %d/%d" % [enemies_killed_in_current_wave, enemies_in_current_wave])
    for player_id in Helper.get_players_id_in_current_world(current_world_name):
        update_wave_ui.rpc_id(player_id, current_level, current_wave, enemies_killed_in_current_wave, enemies_in_current_wave)

    # Check if wave is completed
    if enemies_killed_in_current_wave >= enemies_in_current_wave:
        complete_current_wave()

# Start a wave with enemies
func start_wave(wave_number: int) -> void:
    if not multiplayer.is_server():
        return
    
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - start_wave() - Starting wave %d" % wave_number)
    current_wave = wave_number
    is_wave_active = true
    enemies_killed_in_current_wave = 0
    
    # Get wave configuration
    var wave_data = wave_config.get(wave_number, {"enemy_count": 5, "enemy_types": ["Dummy"]})
    enemies_in_current_wave = wave_data["enemy_count"]
    var enemy_types = wave_data["enemy_types"]
    
    # Reset all EventBus.players' wave completion status
    for peer_id in EventBus.players.keys():
        EventBus.players[peer_id]["wave_completed"] = false
    
    # Notify all clients about the new wave
    for player_id in Helper.get_players_id_in_current_world(current_world_name):
        update_wave_ui.rpc_id(player_id, current_level, current_wave, enemies_killed_in_current_wave, enemies_in_current_wave)

    # Spawn enemies

    spawn_enemies_in_wave(enemy_types, enemies_in_current_wave)

# # Spawn callback for MultiEventBus.playerspawner
# func _spawn_enemy_callback(data: Dictionary) -> Node:
#     var enemy_type = data.get("enemy_type", "Dummy")
#     var enemy_scene_path = enemy_scenes.get(enemy_type, "res://Prefab/Enemies/Dummy.tscn")
    
#     # Load and instantiate enemy
#     var enemy_scene = load(enemy_scene_path)
#     if not enemy_scene:
#         print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - _spawn_enemy_callback() - Could not load enemy scene: %s" % enemy_scene_path)
#         return null
    
#     var enemy = enemy_scene.instantiate()
#     enemy.global_position = data.position
#     enemy.add_to_group("wave_enemies")  # Add to group for easy tracking
    
#     # # Connect enemy death signal if available
#     # if enemy.has_signal("enemy_died"):
#     #     enemy.enemy_died.connect(_on_enemy_died)
    
#     print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - _spawn_enemy_callback() - Spawned %s at %s" % [enemy_type, data.position])
#     return enemy

# # Spawn enemies for the current wave
func spawn_enemies_in_wave(enemy_types: Array, count: int) -> void:
    if not multiplayer.is_server():
        return
    
    # var viewport_size = get_viewport_rect().size
    
    for i in range(count):
        # Pick a random enemy type
        var enemy_type = enemy_types[randi() % enemy_types.size()]
        
        # Set random spawn position (avoiding the center where EventBus.players might be)
        var spawn_position = Vector2(
            randf_range(arena_dimension_x[0], arena_dimension_x[1]),
            randf_range(arena_dimension_y[0], arena_dimension_y[1])
        )
        
        var spawner_name = GLOBAL_SPAWNER_NAME
        var spawner_name_with_id = GLOBAL_SPAWNER_NAME_WITH_ID
        var enemy_name = enemy_type
        var world_name_from_spawner = current_world_name
        var enemy_scene_path = enemy_scenes.get(enemy_type, "res://Prefab/Enemies/Dummy.tscn")

        spawn_enemies_on_global_spawner(spawner_name, spawner_name_with_id, enemy_name, spawn_position, world_name_from_spawner, enemy_scene_path)

func spawn_enemies_on_global_spawner(spawner_name: String, spawner_name_with_id: String, enemy_name: String, spawn_position: Vector2, world_name_from_spawner: String, enemy_scene_path: String) -> void:
    if not multiplayer.is_server(): # Only the server can spawn enemies
        return
    if world_name_from_spawner != current_world_name: # Do not spawn the enemy if the world is not the same as the world of the level
        return
    level_mmo_logic.spawn_enemies(spawner_name, spawner_name_with_id, enemy_name, spawn_position, world_name_from_spawner, enemy_scene_path)



# Called when current wave is completed
func complete_current_wave() -> void:
    if not multiplayer.is_server():
        return
    
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - complete_current_wave() - Wave %d completed!" % current_wave)
    is_wave_active = false
    current_wave += 1 # incrementing the current wave counter
    
    # Mark all EventBus.players as having completed the wave
    for peer_id in EventBus.players.keys():
        EventBus.players[peer_id]["wave_completed"] = true
    
    # Check if this was the final wave
    if current_wave > TOTAL_WAVES:
        print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - complete_current_wave() - All waves completed! Game won!")
        for player_id in Helper.get_players_id_in_current_world(current_world_name):
            finish_game.rpc_id(player_id, true)
    else:
        # Start next wave after a short delay
        for player_id in Helper.get_players_id_in_current_world(current_world_name):
            wave_completed_notification.rpc_id(player_id, current_wave - 1)
        await get_tree().create_timer(3.0).timeout  # 3 second delay between waves
        start_wave(current_wave)

# Clear all enemies from the scene
func clear_all_enemies() -> void:
    var enemies = get_tree().get_nodes_in_group("wave_enemies")
    for enemy in enemies:
        if enemy and is_instance_valid(enemy):
            enemy.queue_free()
    
    # Also clear any enemies that might be children of this node
    for child in get_children():
        if child.is_class("CharacterBody2D") and child.has_method("die"):
            child.queue_free()

@rpc("any_peer", "call_local", "reliable")
func update_wave_ui(current_level: int, wave_number: int, enemy_killed: int, enemy_total: int) -> void:
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - update_wave_ui() - Wave %d started with %d enemies" % [wave_number, enemy_total])
    EventBus.update_wave_ui.emit(current_level, wave_number, TOTAL_WAVES, enemy_killed, enemy_total)
    # TODO: Update UI to show current wave and enemy count
    # This can be connected to EventBus signals for UI updates
    
@rpc("any_peer", "call_local", "reliable")
func wave_completed_notification(wave_number: int) -> void:
    print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - wave_completed_notification() - Wave %d completed!" % wave_number)
    EventBus.wave_cleared.emit(wave_number, TOTAL_WAVES)
    # TODO: Show wave completion notification in UI
    
# @rpc("any_peer", "reliable")
# func show_current_level_and_wave_info(current_level_from_server: int, current_wave_from_server: int, enemies_killed_in_current_wave_from_server: int, enemies_in_current_wave_from_server: int) -> void:
#     EventBus.start_level.emit(current_level_from_server, current_wave_from_server, enemies_killed_in_current_wave_from_server, enemies_in_current_wave_from_server)
#     print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - show_current_level_and_wave_info() - Level %d, Wave %d" % [current_level_from_server, current_wave_from_server])


#region portal instance handling
func enable_portal_instance() -> void:
    if portal_instance:
        print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - enable_portal_instance() - Enabling portal instance")
        portal_instance.enable_portal()

func disable_portal_instance() -> void:
    if portal_instance:
        print(multiplayer.get_unique_id(), " - level_dungeon_1_game_logic.gd - disable_portal_instance() - Disabling portal instance")
        portal_instance.disable_portal()
# End of game logic and portal instance handling
#endregion
