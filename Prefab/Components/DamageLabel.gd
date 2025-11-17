extends Node2D

@export var gravity := Vector2(0, 980)
var _velocity := Vector2.ZERO


func _ready():
    _velocity = Vector2(randf_range(-200, 200), -300)

func _physics_process(delta):
    # position += gravity * delta
    _velocity += gravity * delta
    position += _velocity * delta


func set_damage(damage):
    $Label.text = "-" + str(damage)
    $AnimationPlayer.play("show")



func _on_animation_player_animation_finished(anim_name:StringName) -> void:
    if anim_name == "show":
        queue_free()
    pass # Replace with function body.
