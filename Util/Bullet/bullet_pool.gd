class_name BulletPool extends Node

# Object pool for efficient bullet management
const MULTIPLAYER_BULLET_SCENE = preload("res://Prefab/Bullet/MultiplayerBullet.tscn")
const POOL_SIZE = 30

var available_bullets: Array = []
var active_bullets: Array = []

func _ready():
    # Pre-instantiate bullets for the pool
    for i in POOL_SIZE:
        var bullet = MULTIPLAYER_BULLET_SCENE.instantiate()
        bullet.set_physics_process(false)
        bullet.visible = false
        available_bullets.append(bullet)
        add_child(bullet)

func get_bullet():
    """Get a bullet from the pool"""
    print_debug("BulletPool: Getting bullet from pool. Available: ", available_bullets.size())
    var bullet
    
    if available_bullets.size() > 0:
        # Reuse existing bullet
        bullet = available_bullets.pop_back()
    else:
        # Pool exhausted, create new bullet
        bullet = MULTIPLAYER_BULLET_SCENE.instantiate()
        add_child(bullet)
        print("BulletPool: Pool exhausted, creating new bullet. Active: ", active_bullets.size())
    
    # Reset bullet state
    bullet.current_pierce_count = 0
    bullet.start_time = Time.get_time_dict_from_system().unix
    bullet.visible = true
    bullet.set_physics_process(true)
    
    active_bullets.append(bullet)
    
    # Connect to destruction signal
    if not bullet.tree_exiting.is_connected(_on_bullet_destroyed):
        bullet.tree_exiting.connect(_on_bullet_destroyed.bind(bullet))
    
    return bullet

func return_bullet(bullet):
    """Return a bullet to the pool"""
    if bullet in active_bullets:
        active_bullets.erase(bullet)
    
    # Reset bullet state
    bullet.set_physics_process(false)
    bullet.visible = false
    bullet.global_position = Vector2.ZERO
    bullet.velocity = Vector2.ZERO
    bullet.rotation = 0
    
    # Disconnect signals
    if bullet.tree_exiting.is_connected(_on_bullet_destroyed):
        bullet.tree_exiting.disconnect(_on_bullet_destroyed)
    
    # Return to pool if space available
    if available_bullets.size() < POOL_SIZE:
        available_bullets.append(bullet)
    else:
        # Pool full, actually destroy the bullet
        bullet.queue_free()

func _on_bullet_destroyed(bullet):
    """Handle bullet destruction"""
    return_bullet(bullet)

func get_active_bullet_count() -> int:
    """Get number of active bullets"""
    return active_bullets.size()

func get_pool_stats() -> Dictionary:
    """Get pool statistics for debugging"""
    return {
        "available": available_bullets.size(),
        "active": active_bullets.size(),
        "total": available_bullets.size() + active_bullets.size()
    }
