class_name AOEShootSkill extends Skill
## Area of Effect shooting skill - fires multiple bullets in a circular pattern

## Base damage for each bullet
@export var damage: float = 5.0

## Speed of each bullet
@export var speed: float = 300.0

## Maximum number of enemies each bullet can pierce through
@export var max_pierce: int = 1

## Number of bullets to spawn in the AOE pattern
@export var bullet_count: int = 8

## Spread angle in degrees (total angle covered by all bullets)
@export var spread_angle: float = 360.0

## Visual customization
@export var bullet_sprite_texture: Texture2D = null  # Custom sprite texture (null = default)
@export var bullet_sprite_scale: Vector2 = Vector2(0.5, 0.5)
@export var enable_trail_particles: bool = true
@export var trail_particle_color: Color = Color.CYAN

func _init():
	skill_name = "AOE Shoot"
	cooldown = 0.5  # Longer cooldown for AOE skill

func execute(player: Player, target_position: Vector2, bullet_manager: BulletManager) -> void:
	if is_on_cooldown():
		return
	
	if not bullet_manager:
		push_error("AOEShootSkill: BulletManager not found!")
		return
	
	# Update last used time
	last_used_time = Time.get_unix_time_from_system()
	
	# Get base direction to target
	var base_direction = get_direction_to_target(player, target_position)
	var base_angle = base_direction.angle()
	
	# Calculate angle step between bullets
	var angle_step = deg_to_rad(spread_angle) / bullet_count
	
	# Calculate starting angle (centered on base direction)
	var start_angle = base_angle - (deg_to_rad(spread_angle) / 2.0) + (angle_step / 2.0)
	
	# Prepare base bullet data
	var base_bullet_data = {
		"damage": damage,
		"speed": speed,
		"max_pierce": max_pierce
	}
	
	# Add visual customizations
	base_bullet_data = add_sprite_customization(base_bullet_data, bullet_sprite_texture, bullet_sprite_scale)
	base_bullet_data = add_trail_particles(base_bullet_data, enable_trail_particles, trail_particle_color)
	
	# Apply bullet strategies once (they'll apply to all bullets)
	base_bullet_data = apply_bullet_strategies(player, base_bullet_data)
	
	# Spawn bullets in circular pattern
	for i in range(bullet_count):
		var angle = start_angle + (angle_step * i)
		var direction = Vector2(cos(angle), sin(angle))
		
		# Request bullet spawn for each bullet
		bullet_manager.request_bullet_spawn.rpc(player.global_position, direction, base_bullet_data)


