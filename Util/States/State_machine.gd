class_name StateMachine
extends Node

@export var initial_state : String = "EnemyIdle"

var current_state : State
var states : Dictionary = {}

func _ready():
    for child in get_children():
        if child is State:
            states[child.name.to_lower()] = child
            child.connect("transitioned", on_child_transitioned)
    if initial_state:
        var initial = states.get(initial_state.to_lower())
        if initial:
            initial.Enter()
            current_state = initial

func _process(delta):
    if current_state:
        current_state.Update(delta)

func _physics_process(delta):
    if current_state:
        current_state.Physics_Update(delta)

func on_child_transitioned(state, new_state_name):
    if state != current_state:
        return
    var new_state = states.get(new_state_name.to_lower())
    if !new_state:
        return
    if current_state:
        current_state.Exit() # TODO: CHECK HERE
    new_state.Enter() # TODO: CHECK HERE
    current_state = new_state
