class_name EnemySpawnerResourceClass
extends Resource

@export var name : String = ""
@export var max_enemies_to_spawn : int = 10
@export var spawn_time : float = 1.0 # Spawn timer in seconds - Wait for the timer to timeout before spawning an enemy
@export var enemy_scene_array_of_dictionnary : Array[Dictionary] = [
    {
        "name": "Dummy",
        "scene": preload("res://Prefab/Enemies/Dummy.tscn"),
        "spawn_rate": 0.5 # 90% chance to spawn  
    },
    {
        "name": "Dino",
        "scene": preload("res://Prefab/Enemies/Dino/Dino_Green.tscn"),
        "spawn_rate": 0.5 # 10% chance to spawn
    },
]

# Returns a random enemy dictionary based on spawn_rate weights
func get_random_enemy() -> Dictionary:
    if enemy_scene_array_of_dictionnary.is_empty():
        return {}
    
    # Calculate total weight (sum of all spawn_rate values)
    var total_weight: float = 0.0
    for enemy in enemy_scene_array_of_dictionnary:
        total_weight += enemy.get("spawn_rate", 0.0)
    
    # Generate random number between 0 and total_weight
    var random_value = randf() * total_weight
    
    # Find which enemy corresponds to this random value
    var accumulated_weight: float = 0.0
    for enemy in enemy_scene_array_of_dictionnary:
        accumulated_weight += enemy.get("spawn_rate", 0.0)
        if random_value <= accumulated_weight:
            return enemy
    
    # Fallback: return last enemy (shouldn't reach here, but safety check)
    return enemy_scene_array_of_dictionnary[-1]
