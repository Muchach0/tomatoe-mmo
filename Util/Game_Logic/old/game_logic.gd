extends Node2D

@onready var star: Area2D = $Star

# @onready var player: Area2D = $PlayerShip
# @onready var init_player_position: Vector2 = player.position

@onready var bullets: Node2D = $Bullets
@onready var init_bullet_count: int = 0
const INCREMENT_BULLET_COUNT = 50
var current_level := 1

# bool to store if a game with bullets is currently running
# We hide the player connecting in case a round is already running, necessary as the bullets are instantiated locally on round start.
var is_a_game_with_bullets_currently_running: bool = false 

@onready var bonus_node: Area2D = $Bonus
var bonus_number: int = 0 # This will hold the number of bonuses collected by the player



var players: Dictionary = {} # This will hold player data for synchronization



func _ready() -> void:
    # Connect signals to the event bus
    EventBus.connect("player_hit", _on_player_hit)
    EventBus.connect("star_touched", send_star_touched_on_all_peers)
    EventBus.connect("add_player", add_player)
    EventBus.connect("remove_player", remove_player)
    EventBus.connect("set_player_node_name_and_init_position", set_player_node_name_and_init_position)
    EventBus.connect("bonus_touched", on_bonus_touched_by_player)
    EventBus.connect("bonus_used", server_handles_bonus_used_by_player)

    if multiplayer.is_server():
        EventBus.emit_signal("is_server_label_visible", true)
    # EventBus.connect("player_respawned", self, "_on_player_respawned")



func add_player(player_id, player_info) -> void:
    if !multiplayer.is_server():
        return

    # if player_id != 1:
    player_info["reach_star"] = false
    players[player_id] = player_info
    print("game_logic.gd - add_player() - Players data: %s" % str(players))

func set_player_node_name_and_init_position(player_id, player_node_name, init_position) -> void:
    if !multiplayer.is_server():
        return
    if player_id not in players:
        print("game_logic.gd - set_player_node_name() - Player ID %d not found in players dictionary." % player_id)
        return
    # Setting the player node name and initial position in the players dictionary
    players[player_id]["player_node_name"] = player_node_name  # Store the player node name
    players[player_id]["init_position"] = init_position  # Store the initial position of the player
    print("game_logic.gd - set_player_node_name() - Player %d node name set to %s" % [player_id, player_node_name])
        
    # if a player join during a game with bullets, we hide the player, set the player has reach_star to true
    if not is_a_game_with_bullets_currently_running:
        return
    players[player_id]["reach_star"] = true
    hide_player_from_server_to_all_peers.rpc(player_node_name) # Hide the player from all peers
    show_display_server_busy_label.rpc_id(player_id, is_a_game_with_bullets_currently_running)  # Notify the server that a player has joined a currently running game with bullets
    show_current_level_and_bullet_count.rpc_id(player_id, current_level, init_bullet_count)  # Show the current level and bullet count on the UI on the client when joining a game



# Called on signal _on_player_disconnected
func delete_player_node_on_server(player_id) -> void:
    if !multiplayer.is_server():
        return
    if player_id in players:
        var player_node_name = players[player_id].get("player_node_name")
        if player_node_name:
            var player_node = get_node_or_null(NodePath(player_node_name))
            if player_node:
                player_node.queue_free()  # Free the player node if it exists
                print("game_logic.gd - delete_player_on_server() - Player node %s removed." % player_node_name)
            else:
                print("game_logic.gd - delete_player_on_server() - Player node %s not found." % player_node_name)
        else:
            print("game_logic.gd - delete_player_on_server() - Player node name not found for ID %d." % player_id)
    else:
        print("game_logic.gd - delete_player_on_server() - Player ID %d not found in players dictionary." % player_id)

# Called on signal _on_player_disconnected
func remove_player(player_id) -> void:
    if !multiplayer.is_server():
        return
    delete_player_node_on_server(player_id)  # Call the function to delete the player on the server
    if player_id in players:
        players.erase(player_id)  # Remove the player from the players dictionary
    if len(players) == 0: # If no players are left, we reset the game state
        reset_game_state_on_server()
        return
    if all_players_reached_star(): # Checking if the game should finish
        print("All players reached the star, finishing the game.")
        finish_game.rpc(true) # Call finish_game with is_win set to true
    


# Called by the authoritative player when a player is hit
func _on_player_hit(player_owner_id, player_name, number_of_life: int) -> void:
    print("game_logic - Player hit! Remaining lives: %d" % number_of_life)

    EventBus.audio_explosion_play.emit()
    if multiplayer.is_server():
        players[player_owner_id]["number_of_life"] = number_of_life
        if number_of_life <= 0:
            print("game_logic - Player %s hit and has no lives left, finishing game." % name)
            hide_player_from_server_to_all_peers.rpc(player_name)  # Hide the player from all peers
            # get_node(NodePath(player_name)).queue_free()
            # When a player is dead, we call finish_game with is_win set to false to all the players
            finish_game.rpc(false)  # Call finish_game with is_win set to false
        else:
            print("game_logic - Player %s hit! Remaining lives: %d" % [name, number_of_life])

    # Handle player hit logic here, e.g., update UI or play sound
    # player_was_hit.rpc(player_name, number_of_life)



# The button is restart is pressed by the player (local)
func _on_button_restart_pressed() -> void:
    print("game_logic - Restart button pressed")
    restart_game.rpc()
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
    # Reset players' reach_star status
    for peer_id in players.keys():
        players[peer_id]["reach_star"] = false

    # Reset the star visibility
    star.visible = true

    # Reset the game over screen and the server busy label
    # game_over_screen.visible = false
    EventBus.emit_signal("game_over_screen_text_and_visibility", "", false)

    show_display_server_busy_label(false)  # Hide the server busy label

    if multiplayer.is_server():
        is_a_game_with_bullets_currently_running = true  # Starting a level with bullets, so setting the flag to true
        reset_bonus() # Move the bonus to a random position in the viewport and put back bonus count to 0
        
        for player_id in players.keys():
            # delete_player_node_on_server(player_id) # Delete the player node on the server if it still exists
            respawn_player.rpc(player_id, players[player_id], players[player_id]["init_position"])  # Call respawn_player to respawn the player
            # EventBus.emit_signal("respawn_player", player_id, players[player_id], players[player_id]["init_position"]) # Emit a signal to notify to respawn the player

        EventBus.emit_signal("bullets_init_and_start", current_level, init_bullet_count) # Emit a signal to spawn bullets
        


@rpc("any_peer", "call_local", "reliable")
func finish_game(is_win:= true) -> void:
    print("Game finished.")
    # Handle game finish logic here, e.g., show a win screen or play a sound
    if is_win:
        # Play win sound
        EventBus.audio_win_play.emit()
        star.visible = false
        EventBus.game_over_screen_text_and_visibility.emit("Victory!", "Next Level", true)
        init_bullet_count += INCREMENT_BULLET_COUNT
        current_level += 1
    else :
        EventBus.game_over_screen_text_and_visibility.emit("Round Over!", "Restart", true)

    # Flush all the bullets currently on the screen
    bullets._exit_tree()


func all_players_reached_star() -> bool:
    # Check if all players have reached the star
    for peer_id in players.keys():
        if not players[peer_id].get("reach_star", false):
            return false
    return true


@rpc("any_peer", "call_local", "reliable")
func star_touched(player_name) -> void: # This function is called when a star is touched by any peer
    var peer_id = multiplayer.get_remote_sender_id()
    print(str(multiplayer.get_unique_id()) + " - game_logic.gd - star_touched() - Star touched by peer: %s" % peer_id)
    # Get the player node from the peer ID
    

    # Play the star touched sound when someone touches the star
    EventBus.audio_win_play.emit()

    
    # print("Player node: ", player)
    if multiplayer.is_server(): # only the server should delete the player
        players[peer_id]["reach_star"] = true # Update the player's reach_star status
        # get_node(NodePath(player_name)).queue_free() # maybe not the best to queue_free the player, but it works for now - throw some errors.
        hide_player_from_server_to_all_peers.rpc(player_name) # Hide the player from all peers
        if all_players_reached_star():
            print("All players reached the star, finishing the game.")
            finish_game.rpc(true) # Call finish_game with is_win set to true

func send_star_touched_on_all_peers(player_name) -> void:
    print("game_logic.gd - send_star_touched_on_all_peers() - Player touched the star: %s" % player_name)
    star_touched.rpc(player_name)
    # Handle star touched logic here, e.g., increase score or play a sound


@rpc("any_peer", "call_local", "reliable")
func hide_player_from_server_to_all_peers(player_name) -> void:
    print("game_logic.gd - hide_player_from_server_to_all_peers() - Hiding player: %s" % player_name)
    var player = get_node_or_null(NodePath(player_name))
    if player:
        player.hide_player()  # Call the hide_player function on the player node
        # Optionally, you can also queue_free the player node if you want to remove it
    # player.queue_free()

# @rpc("any_peer", "call_local", "reliable")


@rpc("any_peer", "call_local", "reliable")
func respawn_player(player_id, player_info, init_position) -> void:
    print("game_logic.gd - respawn_player() - Respawning player %d at position %s" % [player_id, str(init_position)])
    var player_node_name = player_info.get("player_node_name")
    if player_node_name:
        var player_node = get_node_or_null(NodePath(player_node_name))
        if player_node:
            player_node.reset_player(init_position)  # Call the reset_player function on the player node
            print("game_logic.gd - respawn_player() - Player %d respawned at position %s" % [player_id, str(init_position)])
        else:
            print("game_logic.gd - respawn_player() - Player node %s not found." % player_node_name)
    else:
        print("game_logic.gd - respawn_player() - Player node name not found for ID %d." % player_id)


@rpc("any_peer", "reliable")
func show_display_server_busy_label(should_display_server_busy_label) -> void: # called from server to connecting peer to indicate that a game with bullets is currently running
    EventBus.emit_signal("is_server_running_a_busy_round", should_display_server_busy_label) # Emit a signal to notify the UI that a game with bullets is currently running

@rpc("any_peer", "reliable")
func show_current_level_and_bullet_count(current_level_from_server, nb_bullets) -> void:
    EventBus.emit_signal("start_level", current_level_from_server, nb_bullets) # Emit a signal to notify the UI to update the current level and number of bullets


func reset_game_state_on_server() -> void: # Called when the game is reset, e.g., when all players are disconnected or when a new game starts
    print("game_logic.gd - reset_game_state_on_server() - Resetting game state")
    current_level = 1
    init_bullet_count = 0
    is_a_game_with_bullets_currently_running = false  # Reset the game state
    players.clear()  # Clear the players dictionary
    # Reset the star visibility
    star.visible = true



######################## BONUS SECTION ########################
# Called from the player.gd script when a bonus is touched by the player - local from player
func on_bonus_touched_by_player(bonus_node_name: String) -> void:
    print("game_logic.gd - on_bonus_touched() - Bonus touched: %s" % bonus_node_name)
    server_handles_bonus_touched_by_player.rpc(bonus_node_name)  # Call the server function to handle the bonus touch

@rpc("any_peer", "call_local", "reliable")
func server_handles_bonus_touched_by_player(bonus_node_name: String) -> void: # The server handles the bonus touch (make it disapear + store the bonus count)
    if not multiplayer.is_server():
        return  # Only the server should handle the bonus touch
    print("game_logic.gd - handles_bonus_touched_on_all_peers() - Bonus touched: %s" % bonus_node_name)
    var bonus_node = get_node_or_null(NodePath(bonus_node_name))
    if not bonus_node:
        print("game_logic.gd - handles_bonus_touched_on_all_peers() - Bonus node %s not found." % bonus_node_name)
        return
    bonus_node.position = Vector2(-1000, -1000)  # Move the bonus node out of the viewport to make it disappear
    bonus_number += 1  # Increment the bonus count
    sync_bonus_count_on_peers.rpc(bonus_number, true)  # Call the function to refresh the bonus count on all peers

func server_handles_bonus_used_by_player() -> void: # The server handles the bonus used by the player (make it disapear + store the bonus count)
    if not multiplayer.is_server():
        return  # Only the server should handle the bonus touch
    print("game_logic.gd - server_handles_bonus_used_by_player() - Bonus used by player")
    bonus_number -= 1  # Decrement the bonus count
    sync_bonus_count_on_peers.rpc(bonus_number, false)  # Call the function to refresh the bonus count on all peers

@rpc("any_peer", "call_local", "reliable")
func sync_bonus_count_on_peers(bonus_number_from_server: int, is_bonus_picked_up: bool) -> void: # Function called from server to all peers to synchronize the bonus count
    print("game_logic.gd - sync_bonus_count_on_peers() - Sync bonus count on peers: %d" % bonus_number_from_server)
    bonus_number = bonus_number_from_server
    EventBus.emit_signal("sync_bonus_count", bonus_number, is_bonus_picked_up) # Emit a signal to notify the UI that a bonus was touched - run on all peers except the server

func reset_bonus() -> void: # This function is called to reset the bonus count and move the bonus node to a random position in the viewport
    print("game_logic.gd - reset_bonus() - Resetting bonus count and moving bonus node")
    if not multiplayer.is_server():
        return  # Only the server should move the bonus
    bonus_number = 0  # Reset the bonus count
    sync_bonus_count_on_peers.rpc(bonus_number, false)  # Call the function to refresh the bonus count on all peers
    server_move_bonus_in_random_viewport_position()  # Move the bonus to a random position in the viewport

func server_move_bonus_in_random_viewport_position() -> void: # This function is called to move the bonus to a random position in the viewport
    if not multiplayer.is_server(): # Check if the multiplayer is server and if the bonus node exists
        return  # Only the server should move the bonus
    if not bonus_node:
        print("game_logic.gd - move_bonus_in_random_viewport_position() - Bonus node not found.")
        return
    var viewport_size = get_viewport_rect().size
    var random_position = Vector2(randf_range(0, viewport_size.x), randf_range(viewport_size.y / 2, viewport_size.y - 160)) # place the bonus in the lower half of the viewport
    bonus_node.position = random_position  # Move the bonus to a random position in the viewport
    print("game_logic.gd - move_bonus_in_random_viewport_position() - Bonus moved to: %s" % str(random_position))
