extends Node

# Singleton for managing the global timer across the multiplayer game
# The global timer will count the 2 minutes round of the game and be synchronized across all clients
# The timer should start when a player joins the game and stop when the timer finishes. 

@export var duration: float = 120.0

@onready var tick: Timer = $UiTickTimer # Timer to update the label once per second
@onready var countdown: Timer = $CountdownTimer # Timer to count down the duration

func _ready() -> void:
    # Connect the signals of the timers to the functions
    tick.timeout.connect(_on_UiTickTimer_timeout)
    countdown.timeout.connect(_on_CountdownTimer_timeout)
    EventBus.connect("add_player", server_start_countdown)

func server_start_countdown(player_id, _player_info) -> void:
    if !multiplayer.is_server():
        return
    # Only start the timer if no timer is already running
    if countdown.time_left == null or countdown.time_left == 0.0:
        start_countdown(duration)
    server_send_remaining_time_to_connected_client.rpc_id(player_id, countdown.time_left)

@rpc("any_peer", "call_local", "reliable")
func server_send_remaining_time_to_connected_client(remaining_time: float) -> void:
    start_countdown(remaining_time)

@rpc("any_peer", "call_local", "reliable")
func server_send_stage_finished_to_connected_client() -> void:
    EventBus.stage_finished.emit()

# Function to restart the timer from scratch (called when all players die in dungeon)
func restart_timer_from_scratch() -> void:
    if !multiplayer.is_server():
        return
    print(multiplayer.get_unique_id(), " - global_timer_manager.gd - restart_timer_from_scratch() - Restarting timer from scratch")
    start_countdown(duration)
    # Broadcast the restart to all clients
    server_restart_timer_from_scratch.rpc()

@rpc("any_peer", "call_local", "reliable")
func server_restart_timer_from_scratch() -> void:
    print(multiplayer.get_unique_id(), " - global_timer_manager.gd - server_restart_timer_from_scratch() - Restarting timer from scratch on all clients")
    start_countdown(duration)

func start_countdown(remaining_time: float) -> void:
    countdown.stop()
    tick.stop()

    countdown.wait_time = remaining_time
    countdown.one_shot = true
    countdown.start()

    _update_label()      # show 02:00 immediately
    tick.start()         # then update once per second

func _on_UiTickTimer_timeout() -> void:
    _update_label()
    if countdown.time_left <= 0.0:
        tick.stop()

func _on_CountdownTimer_timeout() -> void:
    tick.stop()
    # countdown finished logic here
    if multiplayer.is_server():
        server_send_stage_finished_to_connected_client.rpc()

func _update_label() -> void:
    EventBus.update_global_timer_label.emit(format_time(countdown.time_left))

func format_time(seconds: float) -> String:
    var total := int(ceil(seconds))   # keeps 02:00 at the start
    return "%02d:%02d" % [total / 60, total % 60]