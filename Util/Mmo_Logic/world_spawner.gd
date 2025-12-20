extends Node2D

@export var world_scene_ressource_list: Array[WorldSceneRessourceClass]
@export var default_world_scene_ressource: WorldSceneRessourceClass


func _ready() -> void:
    EventBus.connect("add_player", add_player)
    EventBus.move_player_to_destination_world.connect(delete_and_instantiate_world)
    
    if multiplayer and multiplayer.is_server():
        server_instanciate_all_worlds()
    else: # Client only instantiates the default world
        client_instanciate_default_world()


func server_instanciate_all_worlds() -> void:
    for world_scene_ressource in world_scene_ressource_list:
        var world_scene = load(world_scene_ressource.world_scene_path).instantiate()
        world_scene.position = world_scene_ressource.world_offset
        add_child(world_scene, true)

func client_instanciate_default_world() -> void:
    var default_world_scene = load(default_world_scene_ressource.world_scene_path).instantiate()
    default_world_scene.position = default_world_scene_ressource.world_offset
    add_child(default_world_scene, true)
    EventBus.current_world_player_location = default_world_scene.name


func add_player(_player_id, _player_info) -> void:
    if !multiplayer.is_server():
        return
    # Server should trigger the sync of enemies + items after the player has moved to a new world
    EventBus.sync_visibility_after_player_moved_to_new_world.emit()

    
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
