class_name Skill extends Resource
## Base class for all player skills
## Skills are resources that can be applied to the player and triggered by input

## The name of the skill
@export var skill_name: String = "Unnamed Skill"

## Cooldown time in seconds before the skill can be used again
@export var cooldown: float = 0.1

@export var icon : Texture2D = AtlasTexture.new()

@export var level : int = 1 # The current level of the skill

## Last time the skill was used (Unix timestamp)
var last_used_time: float = 0.0

## Whether the skill is currently on cooldown
func is_on_cooldown() -> bool:
	var current_time = Time.get_unix_time_from_system()
	return (current_time - last_used_time) < cooldown

## Execute the skill. Override this in derived classes.
## @param player: The player node executing the skill
## @param target_position: The target position (e.g., mouse position) in world coordinates
## @param bullet_manager: The bullet manager for spawning bullets
func execute(player: Player, target_position: Vector2, bullet_manager: BulletManager) -> void:
	push_error("Skill.execute() called on base class - override this method!")
	pass

## Get the direction from player to target position
func get_direction_to_target(player: Player, target_position: Vector2) -> Vector2:
	if target_position == Vector2.ZERO:
		# Fallback to mouse position if target is zero
		# Get mouse position from the viewport
		var viewport = player.get_viewport()
		if viewport:
			var mouse_position = viewport.get_global_mouse_position()
			return (mouse_position - player.global_position).normalized()
		return Vector2.ZERO
	return (target_position - player.global_position).normalized()

## Apply bullet strategies to bullet data
func apply_bullet_strategies(player: Player, bullet_data: Dictionary) -> Dictionary:
	if player.bullet_strategies and player.bullet_strategies.size() > 0:
		for strategy in player.bullet_strategies:
			if strategy and strategy.has_method("modify_bullet_data"):
				bullet_data = strategy.modify_bullet_data(bullet_data)
	return bullet_data

## Add sprite customization to bullet data
## @param bullet_data: The bullet data dictionary to modify
## @param texture: The texture to use for the bullet sprite (can be null for default)
## @param scale: The scale of the sprite (default: Vector2(0.5, 0.5))
func add_sprite_customization(bullet_data: Dictionary, texture: Texture2D = null, scale: Vector2 = Vector2(0.5, 0.5)) -> Dictionary:
	if texture != null:
		# Store resource path instead of the resource itself (for RPC compatibility)
		bullet_data["sprite_texture_path"] = texture.resource_path
	bullet_data["sprite_scale"] = scale
	return bullet_data

## Add trail particle customization to bullet data
## @param bullet_data: The bullet data dictionary to modify
## @param enable: Whether to enable trail particles
## @param color: The color of the trail particles (optional)
func add_trail_particles(bullet_data: Dictionary, enable: bool = true, color: Color = Color.WHITE) -> Dictionary:
	bullet_data["enable_trail_particles"] = enable
	if enable:
		bullet_data["trail_particle_color"] = color
	return bullet_data

## Add explosion particle scene to bullet data
## @param bullet_data: The bullet data dictionary to modify
## @param particles_scene: PackedScene containing GPUParticles2D for explosion effect
func add_explosion_particles(bullet_data: Dictionary, particles_scene: PackedScene) -> Dictionary:
	if particles_scene != null:
		# Store resource path instead of the resource itself (for RPC compatibility)
		bullet_data["explosion_particles_scene_path"] = particles_scene.resource_path
	return bullet_data

