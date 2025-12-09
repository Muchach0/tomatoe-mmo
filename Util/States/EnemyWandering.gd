extends State
class_name EnemyWandering

var enemy : Enemy
@export var move_speed := 10.0

var rng = RandomNumberGenerator.new() # useful for randomize functions
var move_direction : Vector2
var wander_time : float

var state_animation_name: String = "wandering"

func randomize_wander():
    move_direction = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
    wander_time = rng.randf_range(1, 3)

func Enter():
    enemy = get_parent().get_parent() # Getting the grand-parent of the script, i.e. the KinematicBody2D node to move it
    rng.randomize()
    randomize_wander()

func Update(delta: float):
    if wander_time > 0:
        wander_time -= delta
    else:
        randomize_wander()

func Physics_Update(_delta: float):
    if enemy:
        enemy.velocity = move_direction * move_speed
        enemy.move_and_slide()
        # enemy.look_at(enemy.position + move_direction)
        # enemy.play("walk")
