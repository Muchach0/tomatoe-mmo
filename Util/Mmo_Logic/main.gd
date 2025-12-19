extends Node2D

var players: Dictionary = {} # This will hold player data for synchronization

# World scene paths
@onready var forest_scene = preload("res://Scenes/level_mmo_forest.tscn")
@onready var test_scene = preload("res://Scenes/level_instance_test_1.tscn")

# Control whether server instantiates all worlds
@export var server_worlds_enabled: bool = true

# Default world for clients
var default_world = forest_scene

# World position offsets to prevent overlap
const FOREST_WORLD_OFFSET: Vector2 = Vector2(0, 0)
const TEST_WORLD_OFFSET: Vector2 = Vector2(0, 0)  # Offset test world to the right
# const TEST_WORLD_OFFSET: Vector2 = Vector2(0, 0)  # Offset test world to the right


func _ready() -> void:
    EventBus.connect("add_player", add_player)
    EventBus.connect("remove_player", remove_player)
    EventBus.move_player_to_destination_world.connect(delete_and_instantiate_world)
    # EventBus.connect("set_player_node_name_and_init_position", set_player_node_name_and_init_position)
    
    # Instantiate worlds based on server/client status
    # Check command line args to determine if this is a server (same as NetworkManager)
    if multiplayer and multiplayer.is_server():
        # Server instantiates both worlds
        if server_worlds_enabled:
            var forest_world = forest_scene.instantiate()
            var test_world = test_scene.instantiate()
            forest_world.position = FOREST_WORLD_OFFSET
            test_world.position = TEST_WORLD_OFFSET
            add_child(forest_world, true)
            add_child(test_world, true)
            print("main.gd - _ready() - Server: Instantiated both forest and test worlds with offsets")
    else:
        # # FOREST IS DEFAULT
        var forest_world = forest_scene.instantiate()
        forest_world.position = FOREST_WORLD_OFFSET
        EventBus.current_world_player_location = "LevelForest"
        add_child(forest_world, true)
        
        # TEST WITH TEST_WORLD
        # var test_world = test_scene.instantiate()
        # test_world.position = TEST_WORLD_OFFSET
        # EventBus.current_world_player_location = "level_instance_1_world"
        # add_child(test_world, true)



        print("main.gd - _ready() - Client: Instantiated default forest world")

func add_player(player_id, player_info) -> void:
    if !multiplayer.is_server():
        return
    players[player_id] = player_info

# Called on signal _on_player_disconnected
func remove_player(player_id) -> void:
    if !multiplayer.is_server():
        return
    # delete_player_node_on_server(player_id)  # Call the function to delete the player on the server
    if player_id in players:
        players.erase(player_id)  # Remove the player from the players dictionary
    if len(players) == 0: # If no players are left, we reset the game state
        # reset_game_state_on_server()
        return
    # if all_players_completed_wave(): # Checking if the game should finish
    #     print("All players completed the wave, finishing the game.")
    #     finish_game.rpc(true) # Call finish_game with is_win set to true
    
func delete_and_instantiate_world(player_id: int, world_scene_path: String, world_offset: Vector2) -> void:
    # EventBus.players[player_id]["current_world"] = new_world_scene.name
    if player_id != multiplayer.get_unique_id(): # Only the client authority player should delete and instantiate the new world
        return
   
    print(multiplayer.get_unique_id(), " - main.gd - delete_and_instantiate_world() - Deleting current world and instantiating new world: %s for peer: %d - old world: %s" % [world_scene_path, player_id, EventBus.current_world_player_location])
   
    # Delete the current world
    var current_world := get_node(NodePath(String(EventBus.current_world_player_location)))

    # var current_world = get_node(EventBus.current_world_player_location)
    if current_world != null:
        current_world.queue_free()
    var new_world_scene = load(world_scene_path).instantiate()
    var new_world_name = new_world_scene.name
    EventBus.current_world_player_location = new_world_name

    print(multiplayer.get_unique_id(), " - main.gd - delete_and_instantiate_world() - Deleting current world and instantiating new world: %s" % new_world_name)


    new_world_scene.position = world_offset
    add_child.call_deferred(new_world_scene)
    broadcast_set_current_world_player_location.rpc(multiplayer.get_unique_id(), new_world_name)

@rpc("any_peer", "call_local", "reliable")
func broadcast_set_current_world_player_location(peer_id: int, world_name: String) -> void:
    print(multiplayer.get_unique_id(), " - main.gd - broadcast_set_current_world_player_location() - Setting current world for player %d to %s" % [peer_id, world_name])
    EventBus.players[peer_id]["current_world"] = world_name

    # Server should trigger the sync of enemies + items after the player has moved to the new world
    if multiplayer.is_server():
        EventBus.sync_visibility_after_player_moved_to_new_world.emit()


#region Handling of visibility sync around a player

# func on_zone_touched(player_id: int, target_player_id: int, is_entering: bool): # 2. Signal received on the authority client - and send change of zone to server
#     # if is_entering, the player is entering a zone
#     # is not is_entering, the player is exiting a zone
#     update_players_dict_on_server.rpc_id(0, zone_name, is_entering)
    

# @rpc("any_peer", "call_local", "reliable") # 3. Update the players dict on the server
# func update_players_dict_on_server(zone_name: String, is_entering: bool) -> void:
#     if !multiplayer.is_server():
#         return
#     var peer_id = multiplayer.get_remote_sender_id()
#     if peer_id not in EventBus.players:
#         print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - update_players_dict_on_server() - Player ID %d not found in players dictionary." % peer_id)
#         return
#     if "zone" not in EventBus.players[peer_id]:
#         EventBus.players[peer_id]["zone"] = [] # Initialize the zone list
    
#     if is_entering and zone_name not in EventBus.players[peer_id]["zone"]:
#         EventBus.players[peer_id]["zone"].append(zone_name)
#     elif not is_entering and zone_name in EventBus.players[peer_id]["zone"]:
#         EventBus.players[peer_id]["zone"].erase(zone_name)

#     print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - update_players_dict_on_authority_client - new players dict: ", EventBus.players)
#     broadcast_players_dict_from_serv_then_send_refresh_visibility.rpc(EventBus.players)


# @rpc("any_peer", "call_local", "reliable") # 4. Broadcast of change of zone and refresh visibility everywhere
# func broadcast_players_dict_from_serv_then_send_refresh_visibility(players_dict: Dictionary) -> void:
#     print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - broadcast_players_dict_then_send_refresh_visibility - players dict: ", players_dict)
#     EventBus.refresh_visibility.emit(players_dict)



#endregion
