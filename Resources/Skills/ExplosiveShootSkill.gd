class_name ExplosiveShootSkill extends Skill
## Explosive shooting skill - fires a bullet that explodes on impact, damaging all entities in radius

## Base damage for the bullet (direct hit damage)
@export var damage: float = 4.0

## Speed of the bullet
@export var speed: float = 300.0

## Maximum number of enemies the bullet can pierce through (usually 1 for explosive)
@export var max_pierce: int = 1

## Explosion radius in pixels
@export var explosion_radius: float = 100.0

## Damage dealt by the explosion to all entities within radius
@export var explosion_damage: float = 9.0

## Visual customization
@export var bullet_sprite_texture: Texture2D = null  # Custom sprite texture (null = default)
@export var bullet_sprite_scale: Vector2 = Vector2(0.5, 0.5)
@export var enable_trail_particles: bool = true
@export var trail_particle_color: Color = Color.ORANGE
@export var explosion_particles_scene: PackedScene = null  # Custom explosion particles scene

func _init():
	skill_name = "Explosive Shoot"
	cooldown = 0.8  # Longer cooldown for explosive skill

func execute(player: Player, target_position: Vector2, bullet_manager: BulletManager) -> void:
	if is_on_cooldown():
		return
	
	if not bullet_manager:
		push_error("ExplosiveShootSkill: BulletManager not found!")
		return
	
	# Update last used time
	last_used_time = Time.get_unix_time_from_system()
	
	# Get direction to target
	var direction = get_direction_to_target(player, target_position)
	
	# Prepare bullet data with explosion properties
	var bullet_data = {
		"damage": damage + level,
		"speed": speed,
		"max_pierce": max_pierce,
		"explosion_radius": explosion_radius,
		"explosion_damage": explosion_damage + level
	}
	
	# Add visual customizations
	bullet_data = add_sprite_customization(bullet_data, bullet_sprite_texture, bullet_sprite_scale)
	bullet_data = add_trail_particles(bullet_data, enable_trail_particles, trail_particle_color)
	if explosion_particles_scene:
		bullet_data = add_explosion_particles(bullet_data, explosion_particles_scene)
	
	# Apply bullet strategies
	bullet_data = apply_bullet_strategies(player, bullet_data)
	
	# Request bullet spawn
	bullet_manager.request_bullet_spawn.rpc(player.global_position, direction, bullet_data, player.current_world)

