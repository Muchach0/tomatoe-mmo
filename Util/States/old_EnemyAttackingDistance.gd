extends State
class_name EnemyAttackingDistance

var enemy : Area2D
var player: Area2D
var direction_player: Vector2
var state_animation_name: String = "attacking_distance"
signal attack_send

func Enter():
	print("EnemyAttackingDistance.gd - Enter - Entering EnemyAttackingDistance state: ", String(get_name())) 
	enemy = get_parent().get_parent() # Getting the grand-parent of the script, i.e. the KinematicBody2D node to move it
	player = enemy.player
	# Check if we are already connected to the signal: 
	if not EventBus.is_connected("player_died", player_died):
		EventBus.connect("player_died", player_died)
# func Update(delta: float):

func flip_sprite_if_necessary():
	if not enemy.should_flip_sprite: # do nothing if the enemy should not flip the sprite
		return
	if direction_player.x < 0:
		enemy.flip_sprite(true)
		enemy.get_node("Sprite").flip_h = true
	else:
		enemy.flip_sprite(false)
		enemy.get_node("Sprite").flip_h = false

func Update(_delta: float):
	if not enemy.is_attack_on_cooldown:
		if not EventBus.is_in_network_mode():
			attack()
		elif is_multiplayer_authority():
			rpc("attack")
		return

func Physics_Update(_delta: float):
	if not enemy or not player or not is_instance_valid(enemy) or not is_instance_valid(player):
		return
	direction_player = (player.global_position - enemy.global_position).normalized()
	
	flip_sprite_if_necessary()

		# enemy.look_at(enemy.position + move_direction)
		# enemy.play("walk")

func attack():
	print_debug("EnemyAttackingDistance.gd - attack - attacking")
	# var bomb = preload("res://weapons/Arrow.tscn").instance()
	# bomb.direction = direction_player
	# # No need to set network master to bomb, will be owned by server by default
	# get_node("../..").add_child(bomb)
	emit_signal("attack_send", direction_player, player.global_position)
		# attack_landed()

func player_died(player_id):
	if player_id == player.player_id: # if the player we are attacking dies, goes to Idle State
		emit_signal("transitioned", self, "EnemyIdle")
