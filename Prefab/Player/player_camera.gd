extends Camera2D

var player: CharacterBody2D

func _ready() -> void:
    EventBus.set_player_camera.connect(on_set_player_camera)


func on_set_player_camera(player_to_follow: CharacterBody2D) -> void:
    player = player_to_follow
    enabled = true
    make_current()


func _physics_process(_delta: float) -> void:
    if player == null or not is_current():
        return
    position = player.global_position

