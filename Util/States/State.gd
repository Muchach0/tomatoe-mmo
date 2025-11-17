extends Node
class_name State

signal transitioned

@rpc("authority", "call_local", "reliable")
func server_transition_state(new_state_name: String) -> void:
    emit_signal("transitioned", self, new_state_name)

func transition_state(new_state_name: String) -> void:
    if multiplayer != null and multiplayer.is_server():
        server_transition_state.rpc(new_state_name)
    else:
        emit_signal("transitioned", self, new_state_name)

func Enter():
    pass

func Exit():
    pass

func Update(_delta: float):
    pass

func Physics_Update(_delta: float):
    pass