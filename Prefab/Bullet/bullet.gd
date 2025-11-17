class_name BulletPlayer extends CharacterBody2D

# @export var hurtbox : Hurtbox

@export var speed := 300.0
@export var damage := 5.0
@export var max_pierce := 1

var current_pierce_count := 0
var shooter_id: int = -1  # ID of the player who shot this bullet

func _physics_process(delta: float) -> void:
	var direction = Vector2.RIGHT.rotated(rotation)
	
	velocity = direction*speed
	
	var collision := move_and_collide(velocity*delta)
	
	if collision:
		var collider = collision.get_collider()
		
		# Don't hit the shooter - check if collider has peer_id property
		if collider.has_method("get") and collider.get("peer_id") != null:
			if collider.peer_id == shooter_id:
				return  # Don't destroy bullet, just pass through shooter
		
		queue_free()
