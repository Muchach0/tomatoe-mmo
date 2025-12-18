extends Node

@onready var player_spawner: MultiplayerSpawner = get_node_or_null("PlayerSpawner")
@onready var enemy_spawner: MultiplayerSpawner = get_node_or_null("EnemySpawner")
@onready var item_drop_spawner: MultiplayerSpawner = get_node_or_null("ItemDropSpawner")



const player_scene = preload("res://Prefab/Player/player_ship.tscn") # The player scene to instantiate when a new player connects.

var item_drop_scene = preload("res://Util/Items/item_drop.tscn")

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



func _ready() -> void:
    EventBus.spawn_player_on_global_spawner.connect(spawn_player_on_global_spawner)
    EventBus.spawn_enemy_on_global_spawner.connect(spawn_enemy_on_global_spawner)
    EventBus.spawn_item_drop_on_global_spawner.connect(spawn_item_drop_on_global_spawner)


    player_spawner.spawn_function = _spawn_player_callback
    enemy_spawner.spawn_function = _spawn_enemy_callback
    item_drop_spawner.spawn_function = _spawn_item_drop_callback


#region 1. CALLBACKS =================================================================

func _spawn_player_callback(data: Dictionary): # called at .spawn()
    print("level_mmo_logic.gd - _spawn_player()  Spawning player with dict: " + str(data))
    var player := player_scene.instantiate()
    var player_world = data["current_world_name"]
    # # Rather than changing the authority of the player itself,
    # # change the body and its children (recursively)
    # # to allow the player's position to be synchronized
    # # but not the visibility
    # # More information about visibility here: https://gist.github.com/Meshiest/1274c6e2e68960a409698cf75326d4f6
    # player.get_node("CharacterBody3D").set_multiplayer_authority(id)
    player.set_multiplayer_authority(data["id"])
    player.global_position = data["position"]
    # player.info = data["info"] - not used for now
    player.peer_id = data["id"] # I like to also store this on players
    player.current_world = player_world
    player.add_to_group(player_world)
    return player

func _spawn_enemy_callback(data: Dictionary) -> Node:
    var enemy_world = data["current_world_name"]

    var enemy_type = data.get("enemy_type", "Dummy")
    var enemy_scene_path = enemy_scenes.get(enemy_type, "res://Prefab/Enemies/Dummy.tscn")
    
    # Load and instantiate enemy
    var enemy_scene = load(enemy_scene_path)
    if not enemy_scene:
        print("game_logic.gd - _spawn_enemy_callback() - Could not load enemy scene: %s" % enemy_scene_path)
        return null
    
    var enemy = enemy_scene.instantiate()
    enemy.global_position = data.position
    enemy.current_world = enemy_world
    print(multiplayer.get_unique_id(), " - game_logic.gd - _spawn_enemy_callback() - Adding enemy to group: ", data)
    enemy.add_to_group(data.spawner_name)  # Add to group for easy tracking (quests)
    enemy.add_to_group(data.spawner_name_with_id) # Add to group for easy tracking (mob_spawner)
    enemy.add_to_group(enemy_world)
    
    # enemy.set_visibility_on_spawn()

    # # Connect enemy death signal if available
    # if enemy.has_signal("enemy_died"):
    #     enemy.enemy_died.connect(_on_enemy_died)
    
    print("game_logic.gd - _spawn_enemy_callback() - Spawned %s at %s" % [enemy_type, data.position])
    return enemy    


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

#region 2. FUNCTIONS spawning players, enemies and item drops ==================================================================

func spawn_player_on_global_spawner(data: Dictionary):
    var new_player_node = player_spawner.spawn(data) # Spawning players with a small offset to avoid overlap
    # new_player_node.sync.set_visibility_for(data["id"], true)
    return new_player_node

func spawn_enemy_on_global_spawner(data: Dictionary):
    var enemy = enemy_spawner.spawn(data) # Spawning enemies with a small offset to avoid overlap
    return enemy

func spawn_item_drop_on_global_spawner(data: Dictionary):
    # var item_drop = item_drop_spawner.spawn(data) # Spawning item drops with a small offset to avoid overlap
    item_drop_spawner.spawn.call_deferred(data)
    # return item_drop

#endregion

#region 3. Setting visibility for spawned nodes ==================================================================



#endregion
