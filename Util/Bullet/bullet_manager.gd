class_name BulletManager extends Node

# Singleton for managing bullets across the multiplayer game

const MULTIPLAYER_BULLET_SCENE = preload("res://Prefab/Bullet/MultiplayerBullet.tscn")
const MAX_BULLETS_PER_PLAYER = 50

var bullet_count_per_player: Dictionary = {}

@onready var bullet_spawner: MultiplayerSpawner = $BulletSpawner
@onready var bullet_pool = $BulletPool

func _ready():
    # Configure bullet spawner
    # bullet_spawner.spawnable_scenes = [MULTIPLAYER_BULLET_SCENE.resource_path]
    bullet_spawner.spawn_function = _spawn_bullet_callback
    
    # Connect to multiplayer events
    if multiplayer.has_multiplayer_peer():
        multiplayer.peer_disconnected.connect(_on_player_disconnected)

func _spawn_bullet_callback(data: Dictionary) -> Node:
    """Called by MultiplayerSpawner when creating bullets"""
    var bullet = MULTIPLAYER_BULLET_SCENE.instantiate()
    
    # Extract visual data from bullet_data if it exists
    var visual_data = data.get("bullet_data", {})
    
    # Initialize bullet with visual customizations
    bullet.initialize_bullet(data.position, data.direction, data.shooter_id, visual_data)
    
    bullet.damage = data.get("damage", 5.0)
    bullet.speed = data.get("speed", 300.0)
    bullet.max_pierce = data.get("max_pierce", 1)
    
    # Set explosion properties if provided
    bullet.explosion_radius = data.get("explosion_radius", 0.0)
    bullet.explosion_damage = data.get("explosion_damage", 0.0)
    
    bullet.current_world = data.get("current_world", "")
    # bullet.force_visibility_update()
    
    return bullet

@rpc("any_peer", "call_local", "reliable")
func request_bullet_spawn(position: Vector2, direction: Vector2, bullet_data: Dictionary, current_world: String):
    """Client requests bullet spawn - server validates and spawns"""
    if not multiplayer.is_server():
        return
    
    var shooter_id = multiplayer.get_remote_sender_id()
    
    # Validate bullet spawn request
    if not _can_player_shoot(shooter_id):
        print("BulletManager: Player ", shooter_id, " exceeded bullet limit")
        return
    
    # Prepare spawn data (include full bullet_data for visual customizations)
    var spawn_data = {
        "position": position,
        "direction": direction,
        "shooter_id": shooter_id,
        "damage": bullet_data.get("damage", 5.0),
        "speed": bullet_data.get("speed", 300.0),
        "max_pierce": bullet_data.get("max_pierce", 1),
        "explosion_radius": bullet_data.get("explosion_radius", 0.0),
        "explosion_damage": bullet_data.get("explosion_damage", 0.0),
        "bullet_data": bullet_data,  # Pass full bullet_data for visual customizations
        "current_world": current_world
    }
    
    # Spawn bullet using MultiplayerSpawner
    var bullet = bullet_spawner.spawn(spawn_data)
    
    if bullet:
        # Track bullet count
        if not bullet_count_per_player.has(shooter_id):
            bullet_count_per_player[shooter_id] = 0
        bullet_count_per_player[shooter_id] += 1
        
        # Connect to bullet destruction to update count
        bullet.tree_exiting.connect(_on_bullet_destroyed.bind(shooter_id))

func _can_player_shoot(player_id: int) -> bool:
    """Check if player can spawn another bullet"""
    var current_count = bullet_count_per_player.get(player_id, 0)
    return current_count < MAX_BULLETS_PER_PLAYER

func _on_bullet_destroyed(shooter_id: int):
    """Update bullet count when bullet is destroyed"""
    if bullet_count_per_player.has(shooter_id):
        bullet_count_per_player[shooter_id] = max(0, bullet_count_per_player[shooter_id] - 1)

func _on_player_disconnected(player_id: int):
    """Clean up when player disconnects"""
    bullet_count_per_player.erase(player_id)

# Client-side prediction for responsive shooting
func spawn_prediction_bullet(position: Vector2, direction: Vector2, bullet_data: Dictionary):
    """Spawn local prediction bullet for immediate feedback"""
    if multiplayer.is_server():
        return # Server doesn't need prediction
        
    var prediction_bullet = MULTIPLAYER_BULLET_SCENE.instantiate()
    get_tree().current_scene.add_child(prediction_bullet)
    
    prediction_bullet.initialize_bullet(position, direction, multiplayer.get_unique_id())
    prediction_bullet.damage = bullet_data.get("damage", 5.0)
    prediction_bullet.speed = bullet_data.get("speed", 300.0)
    prediction_bullet.max_pierce = bullet_data.get("max_pierce", 1)
    
    # Make prediction bullet slightly transparent
    prediction_bullet.modulate.a = 0.7
    
    # Destroy prediction bullet after short time (server bullet should replace it)
    prediction_bullet.lifetime = 0.5
