class_name NetworkManager
extends Node

#region 0. Init =================================================================

# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected(peer_id, local_player_info)
signal player_disconnected(peer_id)
signal server_disconnected


var url = "wss://tomatoe-mmo-server.muchacho.app:443"
# var url = "wss://multi-server-1036179882263.europe-west1.run.app:443"
# var url = "ws://localhost:" + str(DEFAULT_PORT) # Default URL for local testing

const DEFAULT_PORT = 10567
const TIMEOUT = 1.0
const NUMBER_OF_RETRY = 10
var current_number_of_retry = 0


# var client = null

# This will contain player info for every player,
# with the keys being each player's unique IDs.
# Names for remote players in {id:{"name": <name>, "ready": <true/false>, "char_index": 1}} format.
# var players = {}

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
var local_player_info = {"name": "Toto", "ready": true, "char_index": 1, "current_world": EventBus.DEFAULT_WORLD_NAME}

var server = null
var client = null
var is_client = true


const PLAYER_INIT_POSITION : Vector2 = Vector2(347, 815) # This can be set to the desired initial position of the player.

# @onready var world = $"../Shower"
# @onready var player_spawner = $"../../PlayerSpawner"
# @onready var spawn_points_parent = $"../../SpawnPoints"
# const player_scene = preload("res://Prefab/Player/player_ship.tscn") # The player scene to instantiate when a new player connects.

# var spawn_points = []

func _ready():
    multiplayer.peer_connected.connect(_on_player_connected)
    multiplayer.peer_disconnected.connect(_on_player_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_ok)
    multiplayer.connection_failed.connect(_on_connected_fail)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

    # EventBus.connect("respawn_player", instantiate_player_scene)
    # player_spawner.spawn_function = _spawn_player
    # get_spawn_points() # Initialize the spawn points

    if "--local" in OS.get_cmdline_args():
        url = "ws://localhost:" + str(DEFAULT_PORT)
    
    if "--server" in OS.get_cmdline_args():
        print("Server starting up detected")
        is_client = false
        host_game()
    else: # if is a client
        print("Client starting up detected")
        client_start()

#endregion

#region 1. SIGNAL HANDLING  =================================================================



# <<< Player Movement


# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id):
    print("NetworkManager.gd - _on_player_connected(id) - id: " + str(id))

    _register_player.rpc_id(id, local_player_info)
# >>>


@rpc("any_peer", "call_local", "reliable")
func _register_player(new_player_info):
    print("NetworkManager.gd - _register_player() - new_player_info: " + str(new_player_info))
    var new_player_id = multiplayer.get_remote_sender_id()
    EventBus.players[new_player_id] = new_player_info
    EventBus.emit_signal("add_player", new_player_id, new_player_info) # Emit the signal to synchronize player data across peers

    instantiate_player_scene(new_player_id, new_player_info, null)
    print("NetworkManager.gd - _register_player(id) - players: " + str(EventBus.players))
    
    player_connected.emit(new_player_id, new_player_info)

func _on_player_disconnected(id):
    print("NetworkManager.gd - _on_player_disconnected(id) - id: " + str(id))
    EventBus.players.erase(id)
    player_disconnected.emit(id)
    EventBus.emit_signal("remove_player", id)


func _on_connected_ok():
    print("NetworkManager.gd - _on_connected_ok()")
    var peer_id = multiplayer.get_unique_id()
    EventBus.players[peer_id] = local_player_info
    player_connected.emit(peer_id, local_player_info)

func _on_connected_fail():
    print("NetworkManager.gd - _on_connected_fail()")
    multiplayer.multiplayer_peer = null

    if current_number_of_retry < NUMBER_OF_RETRY:
        current_number_of_retry += 1
        print("NetworkManager.gd - Retrying connection... Attempt: " + str(current_number_of_retry))
        await get_tree().create_timer(TIMEOUT).timeout
        client_start()  # Retry connecting
    else:
        print("NetworkManager.gd - Failed to connect after " + str(NUMBER_OF_RETRY) + " attempts.")
        multiplayer.multiplayer_peer = null


func _on_server_disconnected():
    print("NetworkManager.gd - _on_server_disconnected()")
    multiplayer.multiplayer_peer = null
    EventBus.players.clear()
    server_disconnected.emit()


#endregion

#region 2. SERVER HANDLING =================================================================
func host_game():
    print("NetworkManager.gd - host_game() - Server starting listening to port : " + str(DEFAULT_PORT))
    server = WebSocketMultiplayerPeer.new()
    server.create_server(DEFAULT_PORT)
    multiplayer.multiplayer_peer = server

func begin_game() -> void:
    print("NetworkManager.gd - begin_game()")
    assert(multiplayer.is_server())

# func _spawn_player(data: Dictionary): # called at .spawn()
#     print("NetworkManager.gs - _spawn_player()  Spawning player with dict: " + str(data))
#     var player := player_scene.instantiate()
#     # # Rather than changing the authority of the player itself,
#     # # change the body and its children (recursively)
#     # # to allow the player's position to be synchronized
#     # # but not the visibility
#     # # More information about visibility here: https://gist.github.com/Meshiest/1274c6e2e68960a409698cf75326d4f6
#     # player.get_node("CharacterBody3D").set_multiplayer_authority(id)
#     player.set_multiplayer_authority(data["id"])
#     player.global_position = data["position"]
#     # player.info = data["info"] - not used for now
#     player.peer_id = data["id"] # I like to also store this on players
#     return player

func instantiate_player_scene(unique_id, player_info, init_position = null):
    print("NetworkManager.gd - instantiate_player_scene() for unique_id: " + str(unique_id) + " - info: " + str(player_info))
    if multiplayer.is_server():
        EventBus.spawn_player.emit(unique_id, player_info, init_position)


# func get_spawn_points():
#     print("NetworkManager.gd - get_spawn_points()")
#     for child in spawn_points_parent.get_children():
#         if child is Node2D:
#             spawn_points.append(child.global_position)

#endregion

#region 3. CLIENT HANDLING =================================================================
########### 3. CLIENT HANDLING ###########
func client_start():
    print("NetworkManager.gd - client_start() - Client connecting to url: " + url)
    client = WebSocketMultiplayerPeer.new()
    client.create_client(url)
    multiplayer.multiplayer_peer = client

#endregion
