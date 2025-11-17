extends State
class_name EnemyDying

var enemy : Enemy

var state_animation_name: String = "die"

func Enter():
    print_debug("Entering EnemyDying state")
    enemy = get_parent().get_parent() # Getting the grand-parent of the script, i.e. the KinematicBody2D node to move it
    # enemy.play("die")


func Update(_delta: float):
    pass
