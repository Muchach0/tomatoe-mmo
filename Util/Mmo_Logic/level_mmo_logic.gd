extends Node2D


# Enemy spawner reference (optional - will fallback to direct instantiation if not found)
# @onready var enemy_spawner: MultiplayerSpawner = get_node_or_null("EnemySpawner")
# @onready var item_drop_spawner: MultiplayerSpawner = get_node_or_null("ItemDropSpawner")
# @onready var player_spawner: MultiplayerSpawner = get_node_or_null("PlayerSpawner")
@onready var spawn_points_parent: Node2D = get_node_or_null("SpawnPoints")
@onready var mob_spawners: Node = get_node_or_null("Encounter_Area_Manager")
# const player_scene = preload("res://Prefab/Player/player_ship.tscn") # The player scene to instantiate when a new player connects.

# var players: Dictionary = {} # This will hold player data for synchronization

var spawn_points = []

# # Enemy scene paths
# var enemy_scenes = {
#     "Dummy": "res://Prefab/Enemies/Dummy.tscn",
#     "Skeleton": "res://Prefab/Enemies/Dungeon/Skeleton.tscn",
#     "Tomatoe_Wizard": "res://Prefab/Enemies/Tomatoe/Tomatoe_Wizard.tscn",
#     "Tomatoe_ennemy": "res://Prefab/Enemies/Tomatoe/Tomatoe_ennemy.tscn",
#     "Dino": "res://Prefab/Enemies/Dino/Dino_Green.tscn",
#     "Tomatoe_Seed_Boss": "res://Prefab/Enemies/Tomatoe/Tomatoe_Seed_Boss.tscn",
#     "Orc": "res://Prefab/Enemies/Orc/Orc.tscn",
# }

# var item_drop_scene = preload("res://Util/Items/item_drop.tscn")


func _ready() -> void:
    # player_spawner.spawn_function = _spawn_player_callback
    # Connect signals to the event bus
    # EventBus.connect("player_hit", _on_player_hit)
    # EventBus.connect("star_touched", send_star_touched_on_all_peers)
    EventBus.connect("add_player", add_player)
    EventBus.connect("remove_player", remove_player)
    EventBus.connect("set_player_node_name_and_init_position", set_player_node_name_and_init_position)
    # EventBus.connect("zone_touched", on_zone_touched)
    # EventBus.connect("bonus_touched", on_bonus_touched_by_player)
    # EventBus.connect("bonus_used", server_handles_bonus_used_by_player)
    # EventBus.connect("one_enemy_die", _on_enemy_died)
    # EventBus.connect("restart_button_pressed", _on_button_restart_pressed)
    EventBus.spawn_player.connect(instantiate_player_scene)
    EventBus.respawn_player.connect(instantiate_player_scene)
    get_spawn_points()
    EventBus.move_player_inside_world.emit(spawn_points[(len(EventBus.players) - 1 ) % 11], name)
    

    EventBus.spawn_enemy.connect(spawn_enemies)


    set_world_name_variable_on_mob_spawners()

    # # Setup enemy spawner
    # if enemy_spawner:
    #     enemy_spawner.spawn_function = _spawn_enemy_callback

    # # Setup item drop spawner
    # if item_drop_spawner:
    #     item_drop_spawner.spawn_function = _spawn_item_drop_callback

    if multiplayer.is_server():
        EventBus.emit_signal("is_server_label_visible", true)
    # EventBus.connect("player_respawned", self, "_on_player_respawned")

    EventBus.spawn_item_drop.connect(on_spawn_item_drop)


#regionstart START player synchronization

# func _spawn_player_callback(data: Dictionary): # called at .spawn()
#     print("level_mmo_logic.gd - _spawn_player()  Spawning player with dict: " + str(data))
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

func instantiate_player_scene(player_id, player_info, init_position) -> void:
    print("level_mmo_logic.gd - instantiate_player_scene() for unique_id: " + str(player_id) + " - info: " + str(player_info))
    if not multiplayer.is_server():
        print("level_mmo_logic.gd - instantiate_player_scene() - Not a server, skipping instantiation.")
        # print(" level_mmo_logic.gd - instantiate_player_scene() - Spawning on server - get_spawnable_scene: " + str(player_spawner.get_spawnable_scene(0)))
    
    # 
    if EventBus.current_world_player_location != name: # Do not instantiate the player if the player is not in this world.
        return
    
    if not init_position: # if the position is not provided (new player), compute the init position
        init_position = spawn_points[(len(EventBus.players) - 1 ) % 11]
        # init_position = PLAYER_INIT_POSITION + len(players) * Vector2(50, 0)
    init_position = init_position # Adding offset of the map
    
    var data = {"id": player_id, "info": player_info, "position": init_position} # Adding a small offset to avoid overlap
    print("level_mmo_logic.gd - instantiate_player_scene() - data: " + str(data))
    # var new_player_node = player_spawner.spawn(data) # Spawning players with a small offset to avoid overlap
    EventBus.spawn_player_on_global_spawner.emit(data)
    
    EventBus.emit_signal("set_player_node_name_and_init_position", player_id, player_id, init_position) # Emit the signal to set the player node name
    # var player_ship = preload("res://prefab/player_ship.tscn").instantiate()
    # player_ship.position = PLAYER_INIT_POSITION
    # player_ship.name = "Player_" + str(unique_id)
    # world.add_child(player_ship)
    # player_ship.init_player_info(players[multiplayer.get_unique_id()])
        

func get_spawn_points():
    print("level_mmo_logic.gd - get_spawn_points()")
    for child in spawn_points_parent.get_children():
        if child is Node2D:
            spawn_points.append(child.global_position)


func add_player(player_id, player_info) -> void:
    if !multiplayer.is_server():
        return

    # if player_id != 1:
    player_info["wave_completed"] = false
    EventBus.players[player_id] = player_info
    print("game_logic.gd - add_player() - Players data: %s" % str(EventBus.players))
    
    # # Start the first wave when the first player joins (and no game is running)
    # if len(players) == 1 and not is_wave_active and not is_a_game_with_bullets_currently_running:
    #     print("game_logic.gd - add_player() - First player joined, starting wave system")
    #     start_first_wave.call_deferred()


func set_player_node_name_and_init_position(player_id, player_node_name, init_position) -> void:
    if !multiplayer.is_server():
        return
    if player_id not in EventBus.players:
        print("game_logic.gd - set_player_node_name() - Player ID %d not found in players dictionary." % player_id)
        return
    # Setting the player node name and initial position in the players dictionary
    EventBus.players[player_id]["player_node_name"] = player_node_name  # Store the player node name
    EventBus.players[player_id]["init_position"] = init_position  # Store the initial position of the player
    print("game_logic.gd - set_player_node_name() - Player %d node name set to %s" % [player_id, player_node_name])
        
    # # if a player joins during an active wave, update them with current status
    # if is_a_game_with_bullets_currently_running and is_wave_active:
    #     print("game_logic.gd - set_player_node_name_and_init_position() - Player joining during active wave")
    #     # Don't mark as wave_completed - let them participate in current wave
    #     # show_display_server_busy_label.rpc_id(player_id, is_a_game_with_bullets_currently_running)  # Notify about ongoing game
    #     # show_current_level_and_wave_info.rpc_id(player_id, current_level, current_wave, enemies_killed_in_current_wave, enemies_in_current_wave)  # Show current wave info
    #     update_wave_ui.rpc_id(player_id, current_level, current_wave, enemies_killed_in_current_wave, enemies_in_current_wave)  # Show current wave status



# Called on signal _on_player_disconnected
func delete_player_node_on_server(player_id) -> void:
    if !multiplayer.is_server():
        return
    
    var found_player: Player = Helper.find_player_by_peer_id(player_id)
    

    if not found_player:
        print("game_logic.gd - delete_player_on_server() - Could not find player node for ID %d." % player_id)
        return
    
    if found_player.current_world != "":
        found_player.remove_from_group(found_player.current_world)
    found_player.queue_free()
    print("game_logic.gd - delete_player_on_server() - Player removed for ID %d." % player_id)

# Called on signal _on_player_disconnected
func remove_player(player_id) -> void:
    if !multiplayer.is_server():
        return
    delete_player_node_on_server(player_id)  # Call the function to delete the player on the server
    if player_id in EventBus.players:
        EventBus.players.erase(player_id)  # Remove the player from the players dictionary
    if len(EventBus.players) == 0: # If no players are left, we reset the game state
        # reset_game_state_on_server()
        return
    # if all_players_completed_wave(): # Checking if the game should finish
    #     print("All players completed the wave, finishing the game.")
    #     finish_game.rpc(true) # Call finish_game with is_win set to true
    

# ===================================================
# Spawn callback for MultiplayerSpawner

func move_player_between_world(player_id: int, destination_world: String, _world_offset: Vector2) -> void:
    if not multiplayer.is_server():
        return
    print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - move_player_between_world() - Moving player %d to destination world: %s" % [player_id, destination_world])
    var player = EventBus.players[player_id]
    if player == null:
        return
    
    # player.travel_to_destination_world(destination_world)

    # Delete current world and instanciate the new world


#endregion


#region VISIBILITY SYNCHRONIZER SECTION =================================================================

# func on_zone_touched(zone_name, is_entering: bool): # 2. Signal received on the authority client - and send change of zone to server
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




#region SPAWN ENEMY SECTION =================================================================

func set_world_name_variable_on_mob_spawners() -> void:
    if not mob_spawners:
        return
    for child in mob_spawners.get_children():
        if child is Area2D and child.has_method("set_world_name"):
            child.set_world_name(name)

# func _spawn_enemy_callback(data: Dictionary) -> Node:
#     var enemy_type = data.get("enemy_type", "Dummy")
#     var enemy_scene_path = enemy_scenes.get(enemy_type, "res://Prefab/Enemies/Dummy.tscn")
    
#     # Load and instantiate enemy
#     var enemy_scene = load(enemy_scene_path)
#     if not enemy_scene:
#         print("game_logic.gd - _spawn_enemy_callback() - Could not load enemy scene: %s" % enemy_scene_path)
#         return null
    
#     var enemy = enemy_scene.instantiate()
#     enemy.global_position = data.position
#     print("game_logic.gd - _spawn_enemy_callback() - Adding enemy to group: ", data)
#     enemy.add_to_group(data.spawner_name)  # Add to group for easy tracking (quests)
#     enemy.add_to_group(data.spawner_name_with_id) # Add to group for easy tracking (mob_spawner)
    
#     # # Connect enemy death signal if available
#     # if enemy.has_signal("enemy_died"):
#     #     enemy.enemy_died.connect(_on_enemy_died)
    
#     print("game_logic.gd - _spawn_enemy_callback() - Spawned %s at %s" % [enemy_type, data.position])
#     return enemy    


func spawn_enemies(spawner_name: String, spawner_name_with_id: String, enemy_name: String, spawn_position: Vector2, world_name_from_spawner: String, enemy_scene_path: String) -> void:
    if not multiplayer.is_server(): # Only the server can spawn enemies
        return
    if world_name_from_spawner != name: # Do not spawn the enemy if the world is not the same as the world of the level
        return
    var global_spawn_position = spawn_position + position # Adding the world offset to the spawn position
    print("level_mmo_logic.gd - _on_spawn_enemy() - Spawning enemy: ", enemy_name, " at position: ", global_spawn_position, " from spawner: ", spawner_name, " in world: ", world_name_from_spawner)
    # var enemy = null
    
    # if enemy_spawner:
        # Use MultiplayerSpawner if available
    var spawn_data = {
        "enemy_type": enemy_name,
        "position": global_spawn_position, # Adding the world offset to the spawn position
        "spawner_name": spawner_name, 
        "spawner_name_with_id": spawner_name_with_id,
        "current_world_name": world_name_from_spawner, 
        "enemy_scene_path": enemy_scene_path
    }
    EventBus.spawn_enemy_on_global_spawner.emit(spawn_data)
    # enemy = enemy_spawner.spawn(spawn_data)
    
    # if enemy:
    #     print("game_logic.gd - spawn_enemies() - Spawned %s at %s" % [enemy_name, spawn_position])
    # else:
    #     print("game_logic.gd - spawn_enemies() - Failed to spawn %s" % enemy_name)


#endregion

#region SPAWN ITEM DROP SECTION =================================================================

# Function connected to the EventBus.spawn_item_drop signal
func on_spawn_item_drop(item_stack: ItemStack, spawn_position: Vector2, world_name_from_enemy: String) -> void:
    if not multiplayer.is_server(): # Only the server can spawn item drops
        return
    if world_name_from_enemy != name: # Do not spawn the enemy if the world is not the same as the world of the level
        return

    print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - on_spawn_item_drop() - Spawning item drop: ", item_stack.item.item_name, " at position: ", spawn_position)

    var spawn_data = {
        "item_name": item_stack.item.item_name,
        "item_sprite_path": item_stack.item.sprite.get_path(),
        "count": item_stack.count,
        "spawn_position": spawn_position, # Here, there is no need to add world offset, as the enemy is spawned by the Global spawner, which is a level above the World level
        "current_world_name": name
    }
    EventBus.spawn_item_drop_on_global_spawner.emit(spawn_data)
    # item_drop_spawner.spawn.call_deferred(spawn_data)
    # if item_drop_node:
    #     print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - on_spawn_item_drop() - Spawned item drop: ", item_stack.item.item_name, " at position: ", spawn_position)
    # else:
    #     print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - on_spawn_item_drop() - Failed to spawn item drop: ", item_stack.item.item_name, " at position: ", spawn_position)

# func _spawn_item_drop_callback(data: Dictionary) -> Node:
#     var item_name = data.get("item_name", "")
#     var item_sprite_path = data.get("item_sprite_path", null)
#     var count = data.get("count", 0)
#     var spawn_position = data.get("spawn_position", Vector2.ZERO)
    
#     var item_sprite = load(item_sprite_path)
#     if not item_sprite:
#         print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - _spawn_item_drop_callback() - Could not load item sprite: ", item_sprite_path)
#         return null
    
#     var item = Item.new()
#     item.item_name = item_name
#     item.sprite = item_sprite
#     var item_stack = ItemStack.new(item, count)
#     var item_drop = item_drop_scene.instantiate()
#     item_drop.stack = item_stack
#     item_drop.global_position = spawn_position
#     return item_drop

#endregion
