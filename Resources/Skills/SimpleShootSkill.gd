class_name SimpleShootSkill extends Skill
## Simple shooting skill - fires a single bullet in the direction of the target

## Base damage for the bullet
@export var damage: float = 5.0

## Speed of the bullet
@export var speed: float = 300.0

## Maximum number of enemies the bullet can pierce through
@export var max_pierce: int = 1

## Visual customization
@export var bullet_sprite_texture: Texture2D = null  # Custom sprite texture (null = default)
@export var bullet_sprite_scale: Vector2 = Vector2(0.5, 0.5)
@export var enable_trail_particles: bool = false
@export var trail_particle_color: Color = Color.WHITE

func _init():
	skill_name = "Simple Shoot"
	cooldown = 0.1

func execute(player: Player, target_position: Vector2, bullet_manager: BulletManager) -> void:
	if is_on_cooldown():
		return
	
	if not bullet_manager:
		push_error("SimpleShootSkill: BulletManager not found!")
		return
	
	# Update last used time
	last_used_time = Time.get_unix_time_from_system()
	
	# Get direction to target
	var direction = get_direction_to_target(player, target_position)
	
	# Prepare bullet data
	var bullet_data = {
		"damage": damage,
		"speed": speed,
		"max_pierce": max_pierce
	}
	
	# Add visual customizations
	bullet_data = add_sprite_customization(bullet_data, bullet_sprite_texture, bullet_sprite_scale)
	bullet_data = add_trail_particles(bullet_data, enable_trail_particles, trail_particle_color)
	
	# Apply bullet strategies
	bullet_data = apply_bullet_strategies(player, bullet_data)
	
	# Request bullet spawn
	bullet_manager.request_bullet_spawn.rpc(player.global_position, direction, bullet_data)


