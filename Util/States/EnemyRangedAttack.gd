extends State
class_name EnemyRangedAttack

var enemy: Enemy
var player: Node2D
var direction_to_player: Vector2

@export var attack_range: float = 300.0
@export var attack_cooldown: float = 2.0
@export var projectile_speed: float = 200.0

var last_attack_time: float = 0.0
var bullet_scene: PackedScene = preload("res://Prefab/Bullet/EnemyBullet.tscn")

var state_animation_name: String = "ranged_attack"

func Enter():
    print_debug("EnemyRangedAttack.gd - Enter - Entering ranged attack state")
    enemy = get_parent().get_parent() # Getting the enemy node
    player = enemy.player
    # Get initial direction to player
    direction_to_player = (player.global_position - enemy.global_position).normalized()
    
    # Connect to player death signal
    if not EventBus.is_connected("player_died", player_died):
        EventBus.connect("player_died", player_died)

func Update(_delta: float):
    if not enemy or not player or not is_instance_valid(enemy) or not is_instance_valid(player):
        emit_signal("transitioned", self, "EnemyIdle")
        return
    
    # var distance_to_player = enemy.global_position.distance_to(player.global_position)
    
    # # If player is too close, switch to melee attack if available, otherwise keep attacking
    # if distance_to_player < 50.0:
    # 	if enemy.has_method("can_melee_attack") and enemy.can_melee_attack():
    # 		emit_signal("transitioned", self, "EnemyAttackingDistance")
    # 		return
    
    # # If player is too far, follow them
    # if distance_to_player > attack_range:
    # 	emit_signal("transitioned", self, "EnemyFollowing")
    # 	return
    
    # Check if we can attack
    var current_time = Time.get_unix_time_from_system()
    if current_time - last_attack_time >= attack_cooldown:
        perform_ranged_attack()
        last_attack_time = current_time

func Physics_Update(_delta: float):
    if not enemy or not player or not is_instance_valid(enemy) or not is_instance_valid(player):
        return
    
    direction_to_player = (player.global_position - enemy.global_position).normalized()
    
    # Flip sprite to face player
    flip_sprite_if_necessary()
    
    # Stop movement while attacking (optional - you can modify this behavior)
    enemy.velocity = Vector2.ZERO

func flip_sprite_if_necessary():
    if not enemy.should_flip_sprite:
        return
    
    if direction_to_player.x < 0:
        enemy.flip_sprite(true)
    else:
        enemy.flip_sprite(false)

func perform_ranged_attack():
    print_debug("%d - EnemyRangedAttack.gd - perform_ranged_attack - Shooting at player" % multiplayer.get_unique_id())
    
    # Play attack animation if available
    if enemy.animation_player != null and enemy.animation_player.has_animation("ranged_attack"):
        enemy.animation_player.play("ranged_attack")
    elif enemy.animation_player != null and enemy.animation_player.has_animation("attack"):
        enemy.animation_player.play("attack")
    
    # Create and shoot bullet
    if enemy.has_method("shoot_bullet"):
        enemy.shoot_bullet(direction_to_player)
    # else:
    # 	# Fallback - create bullet directly
    # 	var bullet = bullet_scene.instantiate()
    # 	var spawn_position = enemy.global_position + direction_to_player * 20  # Offset from enemy center
        
    # 	# Add bullet to scene
    # 	enemy.get_parent().add_child(bullet)
    # 	bullet.initialize_bullet(spawn_position, direction_to_player, enemy)

func player_died(player_id):
    if player != null and player.has_method("get") and player.get("player_id") != null:
        if player_id == player.player_id:
            emit_signal("transitioned", self, "EnemyIdle")
    else:
        # Single player mode - just transition to idle
        emit_signal("transitioned", self, "EnemyIdle")
