extends CanvasLayer

@onready var network_label: Label = $NetworkLabel
@onready var level_label: Label = $LevelLabel
@onready var wave_label: Label = $WaveLabel
@onready var wave_completed_label: Label = $WaveCompletedLabel
@onready var is_a_game_running_label: Label = $IsAGameRunningLabel
@onready var bonus_label: Label = $BonusLabel

# Audio part
@onready var audio_bonus_picked_up: AudioStreamPlayer = $"AudioManager/BonusPickUpAudioStreamPlayer"
@onready var audio_bonus_used: AudioStreamPlayer = $"AudioManager/BonusUsedAudioStreamPlayer"
@onready var audio_explosion: AudioStreamPlayer = $AudioManager/ExplosionAudioStreamPlayer
@onready var audio_win: AudioStreamPlayer = $AudioManager/WinAudioStreamPlayer


@onready var ai_response_label: Label = $AiResponseLabel
@onready var ai_request_failed_label: Label = $AiRequestFailedLabel

@onready var server_label: Control = $IsServerLabel

# Game Over related labels
@onready var game_over_screen: Control = $GameOverScreen
@onready var game_over_screen_label: Label = $GameOverScreen/Control/Label
@onready var restart_button: Button = $GameOverScreen/Control2/Button

# Quest related labels
@onready var QuestVBox: VBoxContainer = $ControlQuests/Control/VBoxContainer

var number_of_players: int = 0

func _ready() -> void:
    EventBus.connect("add_player", on_player_added)
    EventBus.connect("remove_player", on_remove_player)
    # EventBus.connect("start_level", on_start_level)
    EventBus.connect("is_server_running_a_busy_round", on_joining_server_running_a_busy_round)
    EventBus.connect("sync_bonus_count", on_sync_bonus_count)
    EventBus.connect("bonus_used", on_bonus_used)

    # AI Test
    EventBus.connect("ai_response_received", on_ai_response_received)
    EventBus.connect("ai_request_failed", on_ai_request_failed)

    # UI related signals
    EventBus.connect("is_server_label_visible", on_is_server_label_visible)
    EventBus.connect("game_over_screen_text_and_visibility", on_game_over_screen_text_and_visibility)

    # Wave related signals
    EventBus.connect("update_wave_ui", on_update_wave_ui)
    EventBus.connect("wave_cleared", on_wave_cleared)

    restart_button.pressed.connect(on_restart_button_pressed)

    
    EventBus.connect("quest_activated", on_quest_activated)
    EventBus.connect("quest_progress_updated", on_quest_progress_updated)



func on_player_added(_player_id, _player_info) -> void:
    number_of_players += 1
    network_label.text = "Player connected: %d " % number_of_players

func on_remove_player(_player_id) -> void:
    number_of_players -= 1
    network_label.text = "Player connected: %d " % number_of_players


func on_joining_server_running_a_busy_round(should_display_label: bool) -> void:
    # If the game is currently running, we display the label.
    if should_display_label:
        is_a_game_running_label.show()
    else:
        is_a_game_running_label.hide()

func on_sync_bonus_count(bonus_number: int, is_bonus_picked_up: bool = false) -> void:
    bonus_label.text = " Shield: %d" % bonus_number
    if is_bonus_picked_up:
        audio_bonus_picked_up.play()  # Play the bonus picked up sound
    # Update the UI with the current bonus count.

func on_bonus_used() -> void:
    audio_bonus_used.play()  # Play the bonus used sound

func on_ai_response_received(response: String) -> void:
    ai_response_label.text = response
    print("ui.gd - on_ai_response_received() - AI response received: %s" % response)

func on_ai_request_failed(message: String) -> void:
    ai_request_failed_label.text = message
    print("ui.gd - on_ai_request_failed() - AI request failed: %s" % message)


func _on_ai_button_test_pressed() -> void:
    EventBus.ai_test_button_pressed.emit()


# Labels
func on_is_server_label_visible(should_display_server_label: bool) -> void:
    if should_display_server_label:
        server_label.visible = true
    else:
        server_label.visible = false

func on_game_over_screen_text_and_visibility(label_text: String, button_text: String, is_visible: bool) -> void:
    if not is_visible:
        game_over_screen.visible = false
    game_over_screen_label.text = label_text
    restart_button.text = button_text
    game_over_screen.visible = is_visible


# Audio related signals
func on_audio_explosion_play() -> void:
    audio_explosion.play()

func on_audio_win_play() -> void:
    audio_win.play()


# func on_start_level(level_number, wave_number, enemy_killed, enemy_total) -> void:
#     # Update the UI with the current level and number of bullets.
#     level_label.text = "Level: %d" % level_number
#     wave_label.text = "Wave: %d - Enemy killed: %d / %d" % [wave_number, enemy_killed, enemy_total]


func on_update_wave_ui(level_number: int, wave_number: int, TOTAL_WAVES: int, enemy_killed: int, enemy_total: int) -> void:
    level_label.text = " Level: %d" % level_number
    wave_label.text = "Wave: %d / %d - Enemy killed: %d / %d" % [wave_number, TOTAL_WAVES, enemy_killed, enemy_total]
    if wave_completed_label.visible:
        wave_completed_label.hide()


func on_wave_cleared(wave_number: int, TOTAL_WAVES: int) -> void:
    wave_completed_label.show()
    if wave_number >= TOTAL_WAVES:
        wave_completed_label.text = "Boss incoming!!"
    else:
        wave_completed_label.text = "Wave %d completed!" % [wave_number]



func on_restart_button_pressed() -> void:
    print("ui.gd - on_restart_button_pressed() - Restart button pressed by player %d" % multiplayer.get_unique_id())
    EventBus.restart_button_pressed.emit()



# Quest related signals
func on_quest_activated(quest_id: String, quest_name: String, quest_resource: QuestResource) -> void:
    print("ui.gd - on_quest_activated() - Quest activated: %s" % quest_name)
    # Create a Label for the quest and add it to the QuestVBox
    var quest_label = Label.new()
    quest_label.name = quest_name
    var progress_count = 0
    var target_count = quest_resource.target_count
    quest_label.text = "'" + quest_name + "'" + " - " + quest_resource.quest_description + "\nProgress: %d/%d" % [progress_count, target_count]
    QuestVBox.add_child(quest_label)


func on_quest_progress_updated(quest_id: String, quest_name: String, quest_resource: QuestResource, current_progress: int, target_progress: int) -> void:
    print("ui.gd - on_quest_progress_updated() - Quest progress updated: %s" % quest_id)
    var quest_label = QuestVBox.get_node_or_null(quest_name)
    if quest_label:
        quest_label.text = "'" + quest_name + "'" + " - " + quest_resource.quest_description + "\nProgress: %d/%d" % [current_progress, target_progress]
    else:
        print("ui.gd - on_quest_progress_updated() - Quest label not found: %s" % quest_id)
