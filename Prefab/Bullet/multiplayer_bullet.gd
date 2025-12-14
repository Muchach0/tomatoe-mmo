class_name MultiplayerBullet extends Area2D

@export var speed := 300.0
@export var damage := 5.0
@export var max_pierce := 1
@export var lifetime := 3.0

# Explosion properties
@export var explosion_radius: float = 0.0  # If > 0, bullet explodes on impact
@export var explosion_damage: float = 0.0  # Damage dealt by explosion

var current_pierce_count := 0
var shooter_id: int = -1
var direction: Vector2
var start_time: float
var already_hit: Dictionary = {}

# Network synchronization
@onready var sync = $MultiplayerSynchronizer
@onready var sprite: Sprite2D = $Sprite2D
@onready var trail_particles: GPUParticles2D = get_node_or_null("TrailParticles")
@onready var explosion_particles_scene: PackedScene = null  # Can be set for custom explosion particles


# Visual properties
var custom_sprite_texture: Texture2D = null
var sprite_scale: Vector2 = Vector2(0.5, 0.5)
var texture_2d: Texture2D = null

func _ready():
    # Set up multiplayer authority
    if multiplayer.has_multiplayer_peer():
        # Only the server should handle physics and lifetime
        set_physics_process(multiplayer.is_server())
    
    start_time = Time.get_unix_time_from_system()
    
    # Initialize particles (if they exist)
    if trail_particles:
        trail_particles.emitting = true

    if sprite and texture_2d:
        sprite.texture = texture_2d
        sprite.scale = sprite_scale

func initialize_bullet(pos: Vector2, dir: Vector2, owner_id: int, bullet_data: Dictionary = {}):
    """Initialize bullet with position, direction and owner"""
    global_position = pos
    direction = dir.normalized()
    rotation = direction.angle()
    shooter_id = owner_id
    
    # Set authority to server for authoritative movement
    if multiplayer != null:
        set_multiplayer_authority(1) # Server ID is always 1
    
    # Apply visual customizations from bullet_data
    apply_visual_customizations(bullet_data)

func apply_visual_customizations(bullet_data: Dictionary):
    """Apply sprite and particle customizations from bullet_data"""
    # Set custom sprite texture if provided (load from path for RPC compatibility)
    if bullet_data.has("sprite_texture_path") and bullet_data["sprite_texture_path"] != "":
        var texture_path = bullet_data["sprite_texture_path"]
        var loaded_texture = load(texture_path) as Texture2D
        if loaded_texture:
            texture_2d = loaded_texture
    
    # Set sprite scale if provided
    if bullet_data.has("sprite_scale"):
        sprite_scale = bullet_data["sprite_scale"]
        if sprite:
            sprite.scale = sprite_scale
    
    # Configure trail particles if provided
    if bullet_data.has("enable_trail_particles") and bullet_data["enable_trail_particles"]:
        if trail_particles:
            trail_particles.emitting = true
            # Configure particle properties if provided
            if bullet_data.has("trail_particle_color"):
                var color = bullet_data["trail_particle_color"]
                if trail_particles.process_material:
                    trail_particles.process_material.color = color
    elif trail_particles:
        trail_particles.emitting = false
    
    # Store explosion particle scene if provided (load from path for RPC compatibility)
    if bullet_data.has("explosion_particles_scene_path") and bullet_data["explosion_particles_scene_path"] != "":
        var scene_path = bullet_data["explosion_particles_scene_path"]
        var loaded_scene = load(scene_path) as PackedScene
        if loaded_scene:
            explosion_particles_scene = loaded_scene

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
        
        # If bullet has explosion, trigger it on first hit (even if hitting a wall)
        if explosion_radius > 0.0 and current_pierce_count == 1:
            trigger_explosion()
            destroy_bullet()
            return
        
        if current_pierce_count >= max_pierce:
            destroy_bullet()

func trigger_explosion():
    """Trigger explosion at bullet position, damaging all entities within radius"""
    if not multiplayer.is_server():
        return
    
    if explosion_radius <= 0.0:
        return
    
    var explosion_position = global_position
    var space_state = get_world_2d().direct_space_state
    
    # Use a shape query to find all entities in radius
    var shape = CircleShape2D.new()
    shape.radius = explosion_radius
    
    var shape_query = PhysicsShapeQueryParameters2D.new()
    shape_query.shape = shape
    shape_query.transform.origin = explosion_position
    shape_query.collision_mask = 0xFFFFFFFF
    shape_query.collide_with_areas = true
    shape_query.collide_with_bodies = true
    
    var results = space_state.intersect_shape(shape_query)
    var already_damaged: Dictionary = {}
    
    # Damage all entities in explosion radius
    for result in results:
        var collider = result.get("collider")
        if collider == null:
            continue
        
        var id = collider.get_instance_id()
        if already_damaged.has(id):
            continue
        already_damaged[id] = true
        
        # Don't damage the shooter
        if collider.has_method("get") and collider.get("peer_id") != null:
            if collider.peer_id == shooter_id:
                continue
        
        # Apply explosion damage
        if collider.has_method("take_damage"):
            collider.take_damage(explosion_damage, shooter_id)
    
    # Sync explosion effect to all clients (for visual/audio effects)
    sync_explosion_effect.rpc(explosion_position, explosion_radius)

@rpc("authority", "call_local", "reliable")
func sync_explosion_effect(position: Vector2, radius: float):
    """Sync explosion visual/audio effects to all clients"""
    # Spawn explosion particles
    spawn_explosion_particles(position, radius)

func spawn_explosion_particles(position: Vector2, radius: float):
    """Spawn explosion particle effects at the given position"""
    # Use custom explosion particles if provided, otherwise create default
    var particles: GPUParticles2D = null
    
    if explosion_particles_scene:
        var particles_node = explosion_particles_scene.instantiate()
        if particles_node is GPUParticles2D:
            particles = particles_node
    else:
        # Create default explosion particles
        particles = create_default_explosion_particles(radius)
    
    if particles:
        particles.global_position = position
        particles.emitting = true
        # Add to scene tree
        get_tree().current_scene.add_child(particles)
        # Auto-remove after particles finish (use a timer since GPUParticles2D doesn't have finished signal)
        var timer = Timer.new()
        timer.wait_time = particles.lifetime + 0.1  # Slight buffer
        timer.one_shot = true
        timer.timeout.connect(func(): 
            if is_instance_valid(particles):
                particles.queue_free()
            timer.queue_free()
        )
        get_tree().current_scene.add_child(timer)
        timer.start()

func create_default_explosion_particles(radius: float) -> GPUParticles2D:
    """Create default explosion particle effect"""
    var particles = GPUParticles2D.new()
    var material = ParticleProcessMaterial.new()
    
    # Configure explosion particle material
    material.direction = Vector3(0, -1, 0)
    material.initial_velocity_min = 50.0
    material.initial_velocity_max = 150.0
    material.gravity = Vector3(0, 98, 0)
    material.scale_min = 2.0
    material.scale_max = 5.0
    material.color = Color.ORANGE
    
    particles.process_material = material
    particles.amount = max(20, int(radius / 5.0))  # More particles for larger explosions, minimum 20
    particles.lifetime = 0.5
    particles.explosiveness = 1.0  # All particles at once
    particles.one_shot = true
    particles.emitting = false  # Will be set to true when spawned
    
    return particles

@rpc("authority", "call_local", "reliable")
func destroy_bullet():
    """Destroy bullet across all clients"""
    queue_free()
