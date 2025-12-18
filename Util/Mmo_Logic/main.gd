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
const TEST_WORLD_OFFSET: Vector2 = Vector2(2000, 0)  # Offset test world to the right
# const TEST_WORLD_OFFSET: Vector2 = Vector2(0, 0)  # Offset test world to the right


func _ready() -> void:
    EventBus.connect("add_player", add_player)
    EventBus.connect("remove_player", remove_player)
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
        # var forest_world = forest_scene.instantiate()
        # forest_world.position = FOREST_WORLD_OFFSET
        # EventBus.current_world_player_location = "forest_world"
        # add_child(forest_world, true)
        
        # TEST WITH TEST_WORLD
        var test_world = test_scene.instantiate()
        test_world.position = TEST_WORLD_OFFSET
        EventBus.current_world_player_location = "level_instance_1_world"
        add_child(test_world, true)



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
    
