extends Node

# Encounter manager is responsible for assigning an encounter to each child node. 
# Each encounter needs to be added in the encounter_resources array. 

@export var encounter_resources: Array[EncounterResource] = []
var encounter_chosen: Array[EncounterResource] = []

func _ready() -> void:
    # Assign an encounter to each child node and activate it (only on the server).
    if not multiplayer.is_server():
        return

    for child in get_children():
        if child is Node2D:
            var encounter = encounter_resources.pick_random()
            if encounter == null:
                return
            encounter_chosen.append(encounter)
            child.enemy_spawner_resource = encounter.spawner
            child.quest_resources_list = encounter.quests
            child.activate_encounter()
    EventBus.add_player.connect(server_activate_quest_on_connecting_player)

func server_activate_quest_on_connecting_player(player_id, _player_info) -> void:
    if not multiplayer.is_server():
        return
    for encounter in encounter_chosen:
        for quest in encounter.quests:
            if quest == null:
                continue
            activate_quest_on_connecting_player.rpc_id(player_id, quest.resource_path)
            


@rpc("any_peer", "call_local", "reliable")
func activate_quest_on_connecting_player(quest_resource_path: String) -> void:
    print(multiplayer.get_unique_id(), "EncounterManager.gd - activate_quest_on_connecting_player() - quest_resource_path: " + str(quest_resource_path))
    var quest_resource = load(quest_resource_path)
    if quest_resource == null:
        return
    EventBus.add_quest_defined.emit(quest_resource, "")
    # EventBus.add_quest_defined.emit(quest_resources_from_server)
