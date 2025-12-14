extends Node2D


var players: Dictionary = {} # This will hold player data for synchronization

# Enemy spawner reference (optional - will fallback to direct instantiation if not found)
@onready var enemy_spawner: MultiplayerSpawner = get_node_or_null("EnemySpawner")
@onready var item_drop_spawner: MultiplayerSpawner = get_node_or_null("ItemDropSpawner")

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

var item_drop_scene = preload("res://Util/Items/item_drop.tscn")


func _ready() -> void:
    # Connect signals to the event bus
    # EventBus.connect("player_hit", _on_player_hit)
    # EventBus.connect("star_touched", send_star_touched_on_all_peers)
    EventBus.connect("add_player", add_player)
    EventBus.connect("remove_player", remove_player)
    EventBus.connect("set_player_node_name_and_init_position", set_player_node_name_and_init_position)
    EventBus.connect("zone_touched", on_zone_touched)
    # EventBus.connect("bonus_touched", on_bonus_touched_by_player)
    # EventBus.connect("bonus_used", server_handles_bonus_used_by_player)
    # EventBus.connect("one_enemy_die", _on_enemy_died)
    # EventBus.connect("restart_button_pressed", _on_button_restart_pressed)
    

    EventBus.spawn_enemy.connect(spawn_enemies)
    # Setup enemy spawner
    if enemy_spawner:
        enemy_spawner.spawn_function = _spawn_enemy_callback

    # Setup item drop spawner
    if item_drop_spawner:
        item_drop_spawner.spawn_function = _spawn_item_drop_callback

    if multiplayer.is_server():
        EventBus.emit_signal("is_server_label_visible", true)
    # EventBus.connect("player_respawned", self, "_on_player_respawned")

    EventBus.spawn_item_drop.connect(on_spawn_item_drop)




func add_player(player_id, player_info) -> void:
    if !multiplayer.is_server():
        return

    # if player_id != 1:
    player_info["wave_completed"] = false
    players[player_id] = player_info
    print("game_logic.gd - add_player() - Players data: %s" % str(players))
    
    # # Start the first wave when the first player joins (and no game is running)
    # if len(players) == 1 and not is_wave_active and not is_a_game_with_bullets_currently_running:
    #     print("game_logic.gd - add_player() - First player joined, starting wave system")
    #     start_first_wave.call_deferred()


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
        # reset_game_state_on_server()
        return
    # if all_players_completed_wave(): # Checking if the game should finish
    #     print("All players completed the wave, finishing the game.")
    #     finish_game.rpc(true) # Call finish_game with is_win set to true
    

# ===================================================
# Spawn callback for MultiplayerSpawner


#region VISIBILITY SYNCHRONIZER SECTION =================================================================

func on_zone_touched(zone_name, is_entering: bool): # 2. Signal received on the authority client - and send change of zone to server
    # if is_entering, the player is entering a zone
    # is not is_entering, the player is exiting a zone
    update_players_dict_on_server.rpc_id(0, zone_name, is_entering)
    

@rpc("any_peer", "call_local", "reliable") # 3. Update the players dict on the server
func update_players_dict_on_server(zone_name: String, is_entering: bool) -> void:
    if !multiplayer.is_server():
        return
    var peer_id = multiplayer.get_remote_sender_id()
    if peer_id not in players:
        print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - update_players_dict_on_server() - Player ID %d not found in players dictionary." % peer_id)
        return
    if "zone" not in players[peer_id]:
        players[peer_id]["zone"] = [] # Initialize the zone list
    
    if is_entering and zone_name not in players[peer_id]["zone"]:
        players[peer_id]["zone"].append(zone_name)
    elif not is_entering and zone_name in players[peer_id]["zone"]:
        players[peer_id]["zone"].erase(zone_name)

    print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - update_players_dict_on_authority_client - new players dict: ", players)
    broadcast_players_dict_from_serv_then_send_refresh_visibility.rpc(players)


@rpc("any_peer", "call_local", "reliable") # 4. Broadcast of change of zone and refresh visibility everywhere
func broadcast_players_dict_from_serv_then_send_refresh_visibility(players_dict: Dictionary) -> void:
    print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - broadcast_players_dict_then_send_refresh_visibility - players dict: ", players_dict)
    EventBus.refresh_visibility.emit(players_dict)

#endregion




#region SPAWN ENEMY SECTION =================================================================

func _spawn_enemy_callback(data: Dictionary) -> Node:
    var enemy_type = data.get("enemy_type", "Dummy")
    var enemy_scene_path = enemy_scenes.get(enemy_type, "res://Prefab/Enemies/Dummy.tscn")
    
    # Load and instantiate enemy
    var enemy_scene = load(enemy_scene_path)
    if not enemy_scene:
        print("game_logic.gd - _spawn_enemy_callback() - Could not load enemy scene: %s" % enemy_scene_path)
        return null
    
    var enemy = enemy_scene.instantiate()
    enemy.global_position = data.position
    print("game_logic.gd - _spawn_enemy_callback() - Adding enemy to group: ", data)
    enemy.add_to_group(data.spawner_name)  # Add to group for easy tracking (quests)
    enemy.add_to_group(data.spawner_name_with_id) # Add to group for easy tracking (mob_spawner)
    
    # # Connect enemy death signal if available
    # if enemy.has_signal("enemy_died"):
    #     enemy.enemy_died.connect(_on_enemy_died)
    
    print("game_logic.gd - _spawn_enemy_callback() - Spawned %s at %s" % [enemy_type, data.position])
    return enemy    


func spawn_enemies(spawner_name: String, spawner_name_with_id: String, enemy_name: String, spawn_position: Vector2) -> void:
    if not multiplayer.is_server(): # Only the server can spawn enemies
        return
    print("level_mmo_logic.gd - _on_spawn_enemy() - Spawning enemy: ", enemy_name, " at position: ", position, " from spawner: ", spawner_name)

    var enemy = null
    
    if enemy_spawner:
        # Use MultiplayerSpawner if available
        var spawn_data = {
            "enemy_type": enemy_name,
            "position": spawn_position,
            "spawner_name": spawner_name, 
            "spawner_name_with_id": spawner_name_with_id
        }
        enemy = enemy_spawner.spawn(spawn_data)
    
    if enemy:
        print("game_logic.gd - spawn_enemies() - Spawned %s at %s" % [enemy_name, spawn_position])
    else:
        print("game_logic.gd - spawn_enemies() - Failed to spawn %s" % enemy_name)


#endregion

#region SPAWN ITEM DROP SECTION =================================================================

# Function connected to the EventBus.spawn_item_drop signal
func on_spawn_item_drop(item_stack: ItemStack, spawn_position: Vector2) -> void:
    if not multiplayer.is_server() or not item_drop_spawner: # Only the server can spawn item drops
        return
    print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - on_spawn_item_drop() - Spawning item drop: ", item_stack.item.item_name, " at position: ", spawn_position)

    var item_drop_node = null
    var spawn_data = {
        "item_name": item_stack.item.item_name,
        "item_sprite_path": item_stack.item.sprite.get_path(),
        "count": item_stack.count,
        "spawn_position": spawn_position
    }
    item_drop_spawner.spawn.call_deferred(spawn_data)
    # if item_drop_node:
    #     print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - on_spawn_item_drop() - Spawned item drop: ", item_stack.item.item_name, " at position: ", spawn_position)
    # else:
    #     print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - on_spawn_item_drop() - Failed to spawn item drop: ", item_stack.item.item_name, " at position: ", spawn_position)

func _spawn_item_drop_callback(data: Dictionary) -> Node:
    var item_name = data.get("item_name", "")
    var item_sprite_path = data.get("item_sprite_path", null)
    var count = data.get("count", 0)
    var spawn_position = data.get("spawn_position", Vector2.ZERO)
    
    var item_sprite = load(item_sprite_path)
    if not item_sprite:
        print(multiplayer.get_unique_id(), " - level_mmo_logic.gd - _spawn_item_drop_callback() - Could not load item sprite: ", item_sprite_path)
        return null
    
    var item = Item.new()
    item.item_name = item_name
    item.sprite = item_sprite
    var item_stack = ItemStack.new(item, count)
    var item_drop = item_drop_scene.instantiate()
    item_drop.stack = item_stack
    item_drop.global_position = spawn_position
    return item_drop

#endregion
