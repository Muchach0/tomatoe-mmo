extends Control

const levels_description_dict = {
    "1" = {
        "name": "Level 1",
        "description": "Level 1, tomatoe king boss (easy)"
    },
    "2" = {
        "name": "Level 2",
        "description": "Level 2, orc boss (medium)"
    }
}


@onready var start_button: Button = $MarginContainer/StartButton

var current_level_number_selected: String = "1"



func _ready() -> void:
    EventBus.level_selected.connect(on_level_selected)
    EventBus.level_started.connect(on_level_started)
    start_button.pressed.connect(on_level_started)

func on_level_selected(level_number: String) -> void:
    # print("level_selection_game_logic.gd - on_level_selected() - level_number: %s" % level_number)
    current_level_number_selected = level_number
    # TODO: Start the level

func on_level_started() -> void:
    pass
    # print("level_selection_game_logic.gd - on_level_started() - current_level_number_selected: %s" % current_level_number_selected)
    # TODO: Start the level
