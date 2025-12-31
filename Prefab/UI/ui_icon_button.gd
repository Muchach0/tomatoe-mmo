extends TextureButton
class_name UiIconButton


enum MenuToShow {
    # SKILLS,
    INVENTORY
    # QUESTS,
}

@export var menu_to_show: MenuToShow
@export var icon_texture : AtlasTexture


@onready var icon_sprite_button: Sprite2D = $IconSprite

func _ready() -> void:
    icon_sprite_button.texture = icon_texture
    toggled.connect(on_toggled)

func on_toggled(is_toggled: bool) -> void:
    match menu_to_show:
        # MenuToShow.SKILLS:
        #     EventBus.emit_signal("attach_skills_to_ui", Player.skills)
        MenuToShow.INVENTORY:
            EventBus.show_inventory_ui.emit(is_toggled)
        # MenuToShow.QUESTS:
        #     EventBus.emit_signal("attach_quests_to_ui", Player.quests)
