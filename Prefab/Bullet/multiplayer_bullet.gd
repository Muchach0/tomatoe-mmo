class_name MultiplayerBullet extends Area2D

@export var speed := 300.0
@export var damage := 5.0
@export var max_pierce := 1
@export var lifetime := 3.0

var current_pierce_count := 0
var shooter_id: int = -1
var direction: Vector2
var start_time: float
var already_hit: Dictionary = {}

# Network synchronization
@onready var sync = $MultiplayerSynchronizer

func _ready():
    # Set up multiplayer authority
    if multiplayer.has_multiplayer_peer():
        # Only the server should handle physics and lifetime
        set_physics_process(multiplayer.is_server())
    
    start_time = Time.get_unix_time_from_system()


func initialize_bullet(pos: Vector2, dir: Vector2, owner_id: int):
    """Initialize bullet with position, direction and owner"""
    global_position = pos
    direction = dir.normalized()
    rotation = direction.angle()
    shooter_id = owner_id
    
    # Set authority to server for authoritative movement
    if multiplayer != null:
        set_multiplayer_authority(1) # Server ID is always 1

func _physics_process(delta: float) -> void:
    # Only server processes physics
    if not multiplayer.is_server():
        return
    
    # Check lifetime
    var current_time = Time.get_unix_time_from_system()
    if current_time - start_time > lifetime:
        destroy_bullet()
        return
    
    # Move bullet manually (Area2D doesn't push bodies)
    global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
    if not multiplayer.is_server():
        return
    _handle_hit(body)

func _on_area_entered(area: Area2D) -> void:
    if not multiplayer.is_server():
        return
    _handle_hit(area)

func _handle_hit(collider: Node) -> void:
    """Handle bullet hit using Area2D overlaps (server authoritative)."""
    if collider == null:
        return
    
    var id := collider.get_instance_id()
    if already_hit.has(id):
        return
    already_hit[id] = true
    
    # Ignore the shooter (if collider has peer_id)
    if collider.has_method("get") and collider.get("peer_id") != null:
        if collider.peer_id == shooter_id:
            return
    
    var did_hit := false
    
    # Apply damage if target can take damage
    if collider.has_method("take_damage"):
        collider.take_damage(damage, shooter_id)
        did_hit = true
    elif collider is PhysicsBody2D:
        # Hitting walls/obstacles should also count as a hit for piercing
        did_hit = true
    
    if did_hit:
        current_pierce_count += 1
        if current_pierce_count >= max_pierce:
            destroy_bullet()

@rpc("authority", "call_local", "reliable")
func destroy_bullet():
    """Destroy bullet across all clients"""
    queue_free()

# Called when bullet hits screen edge (from Area2D signal)
func _on_screen_exited():
    if multiplayer.is_server():
        destroy_bullet()
