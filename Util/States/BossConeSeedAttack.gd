extends State
class_name BossConeSeedAttack

var enemy: Enemy
var player: Node2D
var attack_timer: float = 0.0
var attack_duration: float = 3.0
var seed_spawn_interval: float = 0.15
var last_seed_time: float = 0.0

# Cone attack parameters
var cone_angle: float = 60.0  # Total cone angle in degrees
var num_projectiles: int = 8  # Number of projectiles in cone
var projectile_speed: float = 300.0
var seed_damage: float = 1.0

var seed_scene: PackedScene = preload("res://Prefab/Bullet/EnemyBullet.tscn")
var state_animation_name: String = "attack"

func Enter():
	print_debug("BossConeSeedAttack.gd - Enter - Entering cone seed attack state")
	enemy = get_parent().get_parent()
	player = enemy.player
	
	if not player or not is_instance_valid(player):
		emit_signal("transitioned", self, "EnemyIdle")
		return
	
	attack_timer = 0.0
	last_seed_time = 0.0
	
	# Stop movement during attack
	if enemy:
		enemy.velocity = Vector2.ZERO
	
	# Play attack animation
	if enemy.animation_player and enemy.animation_player.has_animation("attack"):
		enemy.animation_player.play("attack")

func Update(delta: float):
	if not enemy or not player or not is_instance_valid(enemy) or not is_instance_valid(player):
		emit_signal("transitioned", self, "EnemyIdle")
		return
	
	attack_timer += delta
	
	# Spawn seeds at intervals
	if attack_timer - last_seed_time >= seed_spawn_interval:
		spawn_cone_seeds()
		last_seed_time = attack_timer
	
	# Check if attack duration is complete
	if attack_timer >= attack_duration:
		# Decide next state based on distance to player
		# var distance_to_player = enemy.global_position.distance_to(player.global_position)
		
		# if distance_to_player > 150.0:
		# 	emit_signal("transitioned", self, "EnemyFollowing")
		# else:
		emit_signal("transitioned", self, "BossRolling")

func Physics_Update(_delta: float):
	if not enemy or not player or not is_instance_valid(enemy) or not is_instance_valid(player):
		return
	
	# Face the player during attack
	var direction_to_player = (player.global_position - enemy.global_position).normalized()
	flip_sprite_if_necessary(direction_to_player)
	
	# Keep velocity zero during attack
	enemy.velocity = Vector2.ZERO

func spawn_cone_seeds():
	"""Spawn seeds in a cone pattern towards the player"""
	if not enemy or not player:
		return
	
	var direction_to_player = (player.global_position - enemy.global_position).normalized()
	var base_angle = direction_to_player.angle()
	
	# Calculate angle step between projectiles
	var angle_step = deg_to_rad(cone_angle) / (num_projectiles - 1)
	var start_angle = base_angle - deg_to_rad(cone_angle) / 2.0
	
	# Spawn seeds in cone pattern
	for i in range(num_projectiles):
		var projectile_angle = start_angle + (i * angle_step)
		var projectile_direction = Vector2.from_angle(projectile_angle)
		
		spawn_seed(projectile_direction)

func spawn_seed(direction: Vector2):
	"""Spawn a single seed projectile"""
	if not seed_scene:
		print_debug("BossConeSeedAttack.gd - spawn_seed - No seed scene loaded")
		return
	
	var projectile = seed_scene.instantiate()
	var spawn_position = enemy.global_position + direction.normalized() * 30  # Offset from boss center
	
	# Add seed to the same parent as the enemy
	enemy.get_parent().add_child(projectile)
	
	# Initialize seed with custom properties
	projectile.initialize_bullet(spawn_position, direction, enemy)
	projectile.damage = seed_damage
	projectile.speed = projectile_speed
	
	print_debug("BossConeSeedAttack.gd - spawn_seed - Seed spawned in direction: ", direction)

func flip_sprite_if_necessary(direction: Vector2):
	if not enemy.should_flip_sprite:
		return
	
	if direction.x < 0:
		enemy.flip_sprite(true)
	else:
		enemy.flip_sprite(false)

func Exit():
	print_debug("BossConeSeedAttack.gd - Exit - Exiting cone seed attack state")
