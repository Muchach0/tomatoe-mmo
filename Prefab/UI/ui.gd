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

# Quest Tree
@onready var tree: Tree = $ControlQuests/Control/VBoxContainer/Tree

# Global timer related labels
@onready var global_timer_label: Label = $GlobalTimerLabel
@onready var timer_finished_go_boss_room_screen: Control = $TimerFinishedGoBossRoom
@onready var go_boss_room_button: Button = $TimerFinishedGoBossRoom/Control2/Button

# Return to forest related UI
@onready var return_to_forest_screen: Control = $ReturnToMainWorldScreen
@onready var return_to_forest_button: Button = $ReturnToMainWorldScreen/Control2/Button

@onready var control_inventory: Control = $ControlInventory

# Experience related UI
@onready var experience_bar: ProgressBar = $ExperienceBar/ProgressBar
@onready var experience_label: Label = $ExperienceBar/ProgressBar/Label

var number_of_players: int = 0
const THEME: Theme = preload("res://Art/Font/my_theme.tres")
const ITEM_ICON_SIZE: int = 16
const ITEM_GOLD_ICON: Texture2D = preload("res://Art/Sprites/icon/gold.png")
const ITEM_EXPERIENCE_ICON: Texture2D = preload("res://Art/Sprites/icon/experience.png")

# Quest tree item storage: quest_id -> {quest_item: TreeItem, progress_item: TreeItem, rewards_item: TreeItem}
var quest_tree_items: Dictionary = {}
var tree_root: TreeItem = null


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
    EventBus.update_level_number.connect(on_update_level_number)

    restart_button.pressed.connect(on_restart_button_pressed)

    
    EventBus.connect("quest_activated", on_quest_activated)
    EventBus.connect("quest_progress_updated", on_quest_progress_updated)
    EventBus.connect("quest_completed", on_quest_completed)

    # Setup Tree view for quests
    tree.columns = 1                 # One column
    tree.hide_root = false           # Hide the root item
    tree.focus_mode = Control.FOCUS_NONE # Disable focus mode to prevent keyboard navigation
    # Create root
    tree_root = tree.create_item()
    tree_root.set_text(0, "Quests")
    tree.item_mouse_selected.connect(_on_tree_item_mouse_selected) # Be able to click to toggle the collapse of the tree item

    # Global timer related signals
    EventBus.connect("update_global_timer_label", on_update_global_timer_label)
    EventBus.stage_finished.connect(on_stage_finished)
    go_boss_room_button.pressed.connect(on_go_boss_room_button_pressed)
    EventBus.hide_go_boss_room_button.connect(on_hide_go_boss_room_button)
    # Return to forest related signals
    return_to_forest_button.pressed.connect(on_return_to_forest_button_pressed)
    EventBus.show_return_to_forest_button.connect(on_show_return_to_forest_button)
    EventBus.hide_return_to_forest_button.connect(on_hide_return_to_forest_button)

    # Inventory related signals
    EventBus.show_inventory_ui.connect(on_show_inventory_ui)

    # Experience related signals
    EventBus.leveled_up.connect(on_leveled_up)
    EventBus.xp_changed.connect(on_xp_changed)


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

func on_update_level_number(level_number: int) -> void:
    level_label.text = " Level: %d" % level_number

func on_update_wave_ui(level_number: int, wave_number: int, TOTAL_WAVES: int, enemy_killed: int, enemy_total: int) -> void:
    level_label.text = " Level: %d" % level_number
    wave_label.text = "Wave: %d / %d - Enemy killed: %d / %d" % [wave_number, TOTAL_WAVES, enemy_killed, enemy_total]
    if wave_completed_label.visible:
        wave_completed_label.hide()


func on_wave_cleared(wave_number: int, TOTAL_WAVES: int) -> void:
    wave_completed_label.show()
    if wave_number >= TOTAL_WAVES - 1:
        wave_completed_label.text = "Boss incoming!!"
    else:
        wave_completed_label.text = "Wave %d completed!" % [wave_number]



func on_restart_button_pressed() -> void:
    print("ui.gd - on_restart_button_pressed() - Restart button pressed by player %d" % multiplayer.get_unique_id())
    EventBus.restart_button_pressed.emit()




#region: Quest Tree

func _create_quest_rewards_tree_items(rewards_item: TreeItem, quest_resource: QuestResource) -> void:
    """Create reward items under the rewards container."""
    # Clear existing reward children if any (defensive cleanup)
    var child = rewards_item.get_first_child()
    while child:
        var next = child.get_next()
        child.free()
        child = next
    
    # Add gold reward
    if quest_resource.reward_gold > 0:
        var gold_reward = tree.create_item(rewards_item)
        gold_reward.set_text(0, "x%d" % quest_resource.reward_gold)
        gold_reward.set_icon(0, ITEM_GOLD_ICON)
        gold_reward.collapsed = false
    
    # Add experience reward
    if quest_resource.reward_experience > 0:
        var exp_reward = tree.create_item(rewards_item)
        exp_reward.set_text(0, "x%d" % quest_resource.reward_experience)
        exp_reward.set_icon(0, ITEM_EXPERIENCE_ICON)
        exp_reward.collapsed = false
    
    # Add guaranteed items
    for item_dict in quest_resource.reward_items:
        if item_dict.has("item") and item_dict.has("count"):
            var item: Item = item_dict["item"]
            var count: int = item_dict["count"]
            if item and count > 0:
                var item_reward = tree.create_item(rewards_item)
                item_reward.set_text(0, "x%d" % count)
                if item.sprite:
                    item_reward.set_icon(0, item.sprite)
                item_reward.collapsed = false
    
    # Add choice items
    for item_dict in quest_resource.reward_choice_items:
        if item_dict.has("item") and item_dict.has("count"):
            var item: Item = item_dict["item"]
            var count: int = item_dict["count"]
            if item and count > 0:
                var item_reward = tree.create_item(rewards_item)
                item_reward.set_text(0, "x%d (Choose)" % count)
                if item.sprite:
                    item_reward.set_icon(0, item.sprite)
                item_reward.collapsed = false

# Quest related signals
func on_quest_activated(quest_id: String, quest_name: String, quest_resource: QuestResource) -> void:
    print("ui.gd - on_quest_activated() - Quest activated: %s" % quest_name)
    
    # Ensure tree root exists
    if not tree_root:
        tree_root = tree.create_item()
        tree_root.set_text(0, "Quests")
    
    # Create quest tree item
    # var quest_tree_item := tree.create_item(tree_root)
    # quest_tree_item.set_text(0, quest_name)
    # quest_tree_item.collapsed = false
    
    # Create progress item
    var progress_item := tree.create_item(tree_root)
    progress_item.set_text(0, "%s: 0/%d" % [quest_resource.quest_description, quest_resource.target_count])
    progress_item.collapsed = false
    
    # Create rewards container
    var rewards_item := tree.create_item(progress_item)
    rewards_item.set_text(0, "Rewards")
    rewards_item.collapsed = true
    
    # Create reward items
    _create_quest_rewards_tree_items(rewards_item, quest_resource)
    
    # Store tree items for later updates
    quest_tree_items[quest_id] = {
        # "quest_item": quest_tree_item,
        "progress_item": progress_item,
        "rewards_item": rewards_item
    }

    # # Add a button element to test in the tree view
    # var test_item := tree.create_item(quest_tree_item)
    # var icon: Texture2D = preload("res://Art/Sprites/icon/reward_icon.png")
    # # Change the size of the icon
    # test_item.add_button(0, icon, 0, false)

func on_quest_progress_updated(quest_id: String, quest_name: String, quest_resource: QuestResource, current_progress: int, target_progress: int) -> void:
    print("ui.gd - on_quest_progress_updated() - Quest progress updated: %s" % quest_id)
    
    if quest_id not in quest_tree_items:
        print("ui.gd - on_quest_progress_updated() - Quest tree items not found: %s" % quest_id)
        return
    
    var quest_data = quest_tree_items[quest_id]
    var progress_item = quest_data["progress_item"]
    
    if progress_item:
        progress_item.set_text(0, "%s: %d/%d" % [quest_resource.quest_description, current_progress, target_progress])

func on_quest_completed(quest_id: String, quest_name: String, quest_resource: QuestResource) -> void:
    print("ui.gd - on_quest_completed() - Quest completed: %s" % quest_name)
    
    if quest_id not in quest_tree_items:
        print("ui.gd - on_quest_completed() - Quest tree items not found: %s" % quest_id)
        return
    
    var quest_data = quest_tree_items[quest_id]
    var quest_item = quest_data["progress_item"]
    
    if quest_item:
        # Remove the quest item from its parent (tree_root)
        tree_root.remove_child(quest_item)
        # Free the tree item (TreeItem uses free(), not queue_free())
        quest_item.free()
        quest_tree_items.erase(quest_id)
    else:
        print("ui.gd - on_quest_completed() - Quest tree item not found: %s" % quest_id)

func _on_tree_item_mouse_selected(position: Vector2, mouse_button_index: int) -> void:
    # Check if the click was with the left mouse button (index 1)
    if mouse_button_index == MOUSE_BUTTON_LEFT:
        # Get the currently selected TreeItem
        var item: TreeItem = tree.get_selected()
        
        if item != null:
            # Check if the item has children (i.e., is foldable)
            if item.get_child(0) != null:
                # Toggle the 'collapsed' property
                item.collapsed = not item.collapsed

#endregion: Quest Tree


#region Global Timer related functions

func on_update_global_timer_label(time_left: String) -> void:
    global_timer_label.text = time_left
    global_timer_label.visible = true

func on_stage_finished() -> void:
    print("ui.gd - on_stage_finished() - Stage finished")
    global_timer_label.text = "Stage finished"
    timer_finished_go_boss_room_screen.visible = true
    global_timer_label.visible = false

func on_go_boss_room_button_pressed() -> void:
    print("ui.gd - on_go_boss_room_button_pressed() - Go to the boss room button pressed")
    EventBus.go_to_boss_room_button_pressed.emit()

func on_hide_go_boss_room_button() -> void:
    timer_finished_go_boss_room_screen.visible = false
    global_timer_label.visible = false

func on_return_to_forest_button_pressed() -> void:
    print("ui.gd - on_return_to_forest_button_pressed() - Return to forest button pressed")
    EventBus.return_to_forest_button_pressed.emit()

func on_show_return_to_forest_button() -> void:
    print("ui.gd - on_show_return_to_forest_button() - Showing return to forest button")
    return_to_forest_screen.visible = true

func on_hide_return_to_forest_button() -> void:
    print("ui.gd - on_hide_return_to_forest_button() - Hiding return to forest button")
    return_to_forest_screen.visible = false

#endregion: Global Timer related functions


#region Inventory related functions

func on_show_inventory_ui(is_toggled: bool) -> void:
    control_inventory.visible = is_toggled

#endregion


#region Experience related functions

func on_leveled_up(level: int, _levels_gained: int, _skill_points: int) -> void:
    print("ui.gd - on_leveled_up() - Leveled up: %d" % level)
    experience_label.text = "Lv. %d" % level

func on_xp_changed(current_xp: int, xp_to_next: int) -> void:
    print("ui.gd - on_xp_changed() - XP changed: %d" % current_xp)
    experience_bar.max_value = xp_to_next
    experience_bar.value = current_xp

#endregion: Experience related functions
