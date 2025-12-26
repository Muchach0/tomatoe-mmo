extends Node

@export var boss_room_world_resources_list: Array[WorldSceneRessourceClass] = [] # List of world resources to load when the phase is finished and the boss room is reached
@export var default_forest_world_ressource: WorldSceneRessourceClass # Default world resource to load when the phase is finished and the forest is reached


var current_phase: int = 0

func _ready() -> void:
    EventBus.go_to_boss_room_button_pressed.connect(on_go_to_boss_room_button_pressed)
    EventBus.return_to_forest_button_pressed.connect(on_return_to_forest_button_pressed)
    EventBus.update_level_number.emit(current_phase)

func on_go_to_boss_room_button_pressed() -> void:
    if current_phase >= boss_room_world_resources_list.size():
        return

    # broadcast to all the peers
    print(multiplayer.get_unique_id(), " - phase_manager.gd - on_go_to_boss_room_button_pressed() - Moving all players to boss room: ", EventBus.players.keys())
    for player_id in EventBus.players.keys():
        move_player_to_boss_room.rpc_id(player_id)

@rpc("any_peer", "call_local", "reliable")
func move_player_to_boss_room() -> void:
    if multiplayer.is_server(): # server doesn't have a player
        return
    var player_id = multiplayer.get_unique_id()
    var world_scene_path = boss_room_world_resources_list[current_phase].world_scene_path
    var world_offset = boss_room_world_resources_list[current_phase].world_offset

    EventBus.move_player_to_destination_world.emit(player_id, world_scene_path, world_offset)
    EventBus.hide_go_boss_room_button.emit()

func on_return_to_forest_button_pressed() -> void:
    # Broadcast to all the peers to teleport back to Forest
    for player_id in EventBus.players.keys():
        move_player_to_forest.rpc_id(player_id)

@rpc("any_peer", "call_local", "reliable")
func move_player_to_forest() -> void:
    # Increment the phase on all peers (including server)
    current_phase += 1
    EventBus.update_level_number.emit(current_phase)
    if multiplayer.is_server(): # server doesn't have a player, so we don't need to move it to the forest
        return
    var player_id = multiplayer.get_unique_id()
    var world_scene_path = default_forest_world_ressource.world_scene_path
    var world_offset = default_forest_world_ressource.world_offset
    EventBus.move_player_to_destination_world.emit(player_id, world_scene_path, world_offset)
    EventBus.hide_return_to_forest_button.emit()
