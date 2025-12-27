@tool
extends Area2D
# This should only be running on the server, as only the server can spawn enemies





var enemy_spawner_resource: EnemySpawnerResourceClass
var quest_resources_list: Array[QuestResource] = []  # Optional list of quests that start when player enters this spawner's area
@export var shape: Shape2D: # shape of the area to spawn the enemies - should be added on the worlds view node.
    set(value):
        shape = value
        if is_instance_valid($CollisionShape2D):
            $CollisionShape2D.shape = shape


@onready var timer: Timer = $SpawnTimer # A simple one second timer to check if we should spawn an enemy

const SPAWN_TIMER_TIME : float = 1.0 # Check every second if we should spawn an enemy

var spawner_name : String = "Spawner_Test_1" # name of the spawner - used to track enemy spawned, and that were killed
var spawner_name_with_id : String = "Spawner_Test_1_0" # name of the spawner with the unique id - used to track the spawner
var enemy_scene_array_of_dictionnary : Array[Dictionary] # array of dictionaries containing the name of the enemy, the scene to spawn and the spawn rate
var max_enemies_to_spawn : int # maximum number of enemies to spawn in the area
var spawn_time : float # spawn in seconds  - Wait for that time before spawning an enemy after the enemy is killed
var number_current_enemies : int = 0 # number of enemies spawned in the area

var array_of_time_to_spawn_enemies : Array[float] = [] # array of time to spawn enemies - used to track the time to spawn an enemy after the enemy is killed
var unique_id_spawner: int = 0 # unique id of the spawner - used to track the spawner

var world_name: String = "" # name of the world - used to track the world of the spawner to only spawn enemies in the correct world - set by the level_mmo_logic.gd @onready

func _ready() -> void:
    $CollisionShape2D.shape = shape
    
    # Connect Area2D signals for quest activation (works for both server and clients)
    if not Engine.is_editor_hint():
        body_entered.connect(_on_body_entered)
        body_exited.connect(_on_body_exited)
    


func activate_encounter() -> void:
    if not multiplayer.is_server():
        return
    # Reading the data from the resource
    enemy_scene_array_of_dictionnary = enemy_spawner_resource.enemy_scene_array_of_dictionnary
    unique_id_spawner = randi()
    spawner_name = enemy_spawner_resource.name
    spawner_name_with_id = spawner_name + "_" + str(unique_id_spawner)
    max_enemies_to_spawn = enemy_spawner_resource.max_enemies_to_spawn
    spawn_time = enemy_spawner_resource.spawn_time
    
    if multiplayer == null or not multiplayer.is_server() or Engine.is_editor_hint():
        return
    
    EventBus.one_enemy_die.connect(_on_one_enemy_die)

    timer.wait_time = SPAWN_TIMER_TIME
    timer.start() # Only start the timer if we are the server

    # Wait 1 second before spawning initial enemies to ensure systems are ready
    await get_tree().create_timer(1.0).timeout
    # Spawn all initial enemies at world creation
    for i in range(max_enemies_to_spawn):
        spawn_enemy_at_random_location()



func spawn_enemy_at_random_location() -> void:
    # Get a random location inside the shape of the area
    var collision_shape = $CollisionShape2D

    var random_position = collision_shape.global_position + Vector2(randf_range(-collision_shape.shape.radius, collision_shape.shape.radius), randf_range(-collision_shape.shape.radius, collision_shape.shape.radius))
    # Spawn an enemy

    # Get a random enemy from the enemy_scene_array_of_dictionnary based on the spawn_timer data
    var random_enemy = enemy_spawner_resource.get_random_enemy()
    print("mob_spawner.gd - spawn_enemy_at_random_location() - random enemy: ", random_enemy, " at position: ", random_position, " name: ", random_enemy["name"])

    var enemy_scene_path = random_enemy["scene"].resource_path
    print("mob_spawner.gd - spawn_enemy_at_random_location() - enemy scene path: ", enemy_scene_path)
    EventBus.spawn_enemy.emit(spawner_name, spawner_name_with_id, random_enemy["name"], random_position, world_name, enemy_scene_path)
    
    # enemy_spawner_resource.spawn_enemy(random_position)
    number_current_enemies += 1
    print("mob_spawner.gd - spawn_enemy_at_random_location() - number_current_enemies: ", number_current_enemies)


func _on_spawn_timer_timeout() -> void:
    if not multiplayer or not multiplayer.is_server():
        return
    # print("mob_spawner.gd - _on_spawn_timer_timeout() - timer timeout - number_current_enemies: ", number_current_enemies, " - max_enemies_to_spawn: ", max_enemies_to_spawn, " - array_of_time_to_spawn_enemies: ", array_of_time_to_spawn_enemies)
    if number_current_enemies >= max_enemies_to_spawn:
        # print_debug("mob_spawner.gd - _on_spawn_timer_timeout() - Max enemies reached, skipping spawn")
        return
    
    if array_of_time_to_spawn_enemies.size() < 1:
        return
    # Go through each timer to spawn an enemy backwards
    for i in range(array_of_time_to_spawn_enemies.size() - 1, -1, -1): # Going through each timer to spawn an enemy backwards
        array_of_time_to_spawn_enemies[i] += 1
        if array_of_time_to_spawn_enemies[i] >= spawn_time:
            spawn_enemy_at_random_location()
            array_of_time_to_spawn_enemies.remove_at(i)
            # print_debug("mob_spawner.gd - _on_spawn_timer_timeout() - Spawned enemy at time: ", array_of_time_to_spawn_enemies[i], " - Remaining timers: ", array_of_time_to_spawn_enemies.size())
            break
    

    


func _on_one_enemy_die(enemy_group_names: Array[StringName]) -> void: # To fix - should check which type of enemy died, and update the number_current_enemies accordingly.
    if not multiplayer or not multiplayer.is_server():
        return
    print("mob_spawner.gd - _on_one_enemy_die() - one enemy died - Spawner name: '", spawner_name, "',mob in groups: ", enemy_group_names)
    if spawner_name_with_id in enemy_group_names: # Checking if the name of the spawner is in the mob that die group names
        number_current_enemies -= 1
        array_of_time_to_spawn_enemies.append(0) # Add an entry in the array with a timer set at 0
        print("mob_spawner.gd - _on_one_enemy_die() - number_current_enemies: ", number_current_enemies,  " - Spawner name: ", spawner_name)

func _on_body_entered(body: Node2D) -> void:
    """Called when a body enters the MobSpawner's Area2D."""
    if Engine.is_editor_hint():
        return
    
    # Check if it's a player
    if "Player" not in body.get_groups():
        return
    
    # # Only activate quest on server
    # if multiplayer != null and not multiplayer.is_server():
    #     return
    
    # Check if the player is the authority
    if body.get_multiplayer_authority() != multiplayer.get_unique_id():
        return

    # If this spawner has quest resources, activate them
    if not quest_resources_list.is_empty():
        var quest_manager = _get_quest_manager()
        if quest_manager:
            var player = body as Player
            for quest_resource in quest_resources_list:
                if quest_resource != null:
                    quest_manager.activate_quest_from_spawner(quest_resource, self, player)
                    print("MobSpawner - Player entered area, activating quest: %s" % quest_resource.quest_name)

func _on_body_exited(body: Node2D) -> void:
    """Called when a body exits the MobSpawner's Area2D."""
    if Engine.is_editor_hint():
        return
    
    # Check if it's a player
    if "Player" not in body.get_groups():
        return
    
    # Optional: Handle quest deactivation or cleanup when player leaves
    # For now, we'll keep the quest active even if player leaves

func _get_quest_manager() -> QuestManager:
    """Find the QuestManager in the scene tree."""
    var quest_manager = get_tree().get_first_node_in_group("quest_manager")
    if quest_manager and quest_manager is QuestManager:
        return quest_manager
    
    # Fallback: search for QuestManager node
    var scene_root = get_tree().current_scene
    if scene_root:
        quest_manager = scene_root.find_child("QuestManager", true, false)
        if quest_manager and quest_manager is QuestManager:
            return quest_manager
    
    push_warning("MobSpawner - QuestManager not found. Make sure QuestManager is in the scene or in 'quest_manager' group.")
    return null

    

func get_spawner_name() -> String:
    return spawner_name

func set_world_name(world_name_to_set: String) -> void:
    world_name = world_name_to_set
