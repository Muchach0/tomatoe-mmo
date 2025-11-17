extends Button 
class_name ButtonLevel

enum LevelNumber {
    LEVEL_1 = 1, # Level 1, tomatoe king boss (easy)
    LEVEL_2 = 2 # Level 2, orc boss (medium)
}

@export var level_number: LevelNumber



func _ready() -> void:
    pressed.connect(on_pressed) # Connect the pressed signal to the on_pressed function

func on_pressed() -> void:
    EventBus.emit_signal("level_selected", str(level_number))
