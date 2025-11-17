class_name EnemyBullet extends CharacterBody2D

@export var speed := 200.0
@export var damage := 2.0
@export var lifetime := 4.0

var direction: Vector2
var start_time: float
var shooter_enemy: Node = null

func _ready():
	start_time = Time.get_unix_time_from_system()

func initialize_bullet(pos: Vector2, dir: Vector2, shooter: Node):
	"""Initialize bullet with position, direction and shooter reference"""
	global_position = pos
	direction = dir.normalized()
	rotation = direction.angle()
	shooter_enemy = shooter

func _physics_process(delta: float) -> void:
	# Check lifetime
	var current_time = Time.get_unix_time_from_system()
	if current_time - start_time > lifetime:
		queue_free()
		return
	
	# Move bullet
	velocity = direction * speed
	var collision := move_and_collide(velocity * delta)
	
	if collision:
		var collider = collision.get_collider()
		_handle_hit(collider)

func _handle_hit(collider: Node) -> void:
	"""Handle bullet collision"""
	if collider == null:
		queue_free()
		return
	
	# Don't hit the shooter enemy
	if collider == shooter_enemy:
		return
	
	# Don't hit other enemies
	if collider is Enemy:
		return
	
	# Check if it's a player and deal damage
	if collider.has_method("take_damage"):
		# For multiplayer, we need to handle damage properly
		if collider.has_method("get") and collider.get("peer_id") != null:
			# This is a player with multiplayer support
			var _player_id = collider.peer_id
			collider.take_damage(damage, -1) # -1 indicates enemy damage
		else:
			# Single player or non-multiplayer entity
			collider.take_damage(damage, -1)
	
	# Destroy bullet on any collision (except shooter)
	queue_free()
