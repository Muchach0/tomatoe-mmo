extends State
class_name BossRolling

var enemy: Enemy
var player: Node2D
var roll_direction: Vector2
var roll_speed: float = 400.0
var roll_duration: float = 8.0
var roll_timer: float = 0.0
# var damage_on_contact: float = 5.0

var state_animation_name: String = "rolling"

func Enter():
	print_debug("BossRolling.gd - Enter - Entering rolling state")
	enemy = get_parent().get_parent()
	player = enemy.player
	
	if not player or not is_instance_valid(player):
		emit_signal("transitioned", self, "EnemyIdle")
		return
	
	# Calculate direction towards player
	roll_direction = (player.global_position - enemy.global_position).normalized()
	roll_timer = 0.0
	
	# # Enable collision damage during roll
	# if enemy.hurtbox:
	# 	enemy.hurtbox.damage = damage_on_contact
	
	# Play rolling animation
	if enemy.animation_player and enemy.animation_player.has_animation("rolling"):
		enemy.animation_player.play("rolling")

func Update(delta: float):
	if not enemy or not is_instance_valid(enemy):
		emit_signal("transitioned", self, "EnemyIdle")
		return
	
	roll_timer += delta
	
	# Check if roll duration is complete
	if roll_timer >= roll_duration:
		emit_signal("transitioned", self, "BossConeSeedAttack")
		return

func Physics_Update(_delta: float):
	if not enemy or not is_instance_valid(enemy):
		return
	
	# Move in roll direction
	enemy.velocity = roll_direction * roll_speed
	enemy.move_and_slide()
	
	# Handle wall collisions - bounce off walls
	if enemy.is_on_wall():
		var wall_normal = enemy.get_wall_normal()
		roll_direction = roll_direction.bounce(wall_normal)

func Exit():
	# Reset collision damage
	if enemy and enemy.hurtbox:
		enemy.hurtbox.damage = 0.0
	
	print_debug("BossRolling.gd - Exit - Exiting rolling state")
