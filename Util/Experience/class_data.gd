extends Resource
class_name ClassData

enum PlayerClass {
    STRENGTH,
    AGILITY,
    INTELLIGENCE
}

@export var class_id : PlayerClass = PlayerClass.STRENGTH
@export var display_name: String = "Strength Class"

@export var primary_gain_per_level: float = 3.0
@export var strength_gain_per_level: float = 1.0
@export var agility_gain_per_level: float = 1.0
@export var intelligence_gain_per_level: float = 1.0
@export var wisdom_gain_per_level: float = 1.0
@export var charisma_gain_per_level: float = 1.0
@export var luck_gain_per_level: float = 1.0
@export var constitution_gain_per_level: float = 1.0

@export var flat_max_life_per_level: float = 5.0
@export var flat_max_mana_per_level: float = 5.0
@export var flat_max_energy_shield_per_level: float = 5.0
@export var flat_max_stamina_per_level: float = 5.0

@export var armor_per_strength: float = 0.5

@export var skill_points_per_level: int = 1


func _init() -> void:
    match class_id:
        PlayerClass.STRENGTH:
            strength_gain_per_level = primary_gain_per_level
        PlayerClass.AGILITY:
            agility_gain_per_level = primary_gain_per_level
        PlayerClass.INTELLIGENCE:
            intelligence_gain_per_level = primary_gain_per_level

func apply_level_up(attribute_data: AttributeData, levels: int = 1):
    if not attribute_data or not attribute_data is AttributeData:
        return {"success": false, "error": "Attribute data is not valid"}
    

    attribute_data.strength += strength_gain_per_level * levels
    attribute_data.agility += agility_gain_per_level * levels
    attribute_data.intelligence += intelligence_gain_per_level * levels
    attribute_data.wisdom += wisdom_gain_per_level * levels
    attribute_data.charisma += charisma_gain_per_level * levels
    attribute_data.luck += luck_gain_per_level * levels
    attribute_data.constitution += constitution_gain_per_level * levels

    attribute_data.max_life += flat_max_life_per_level * levels
    attribute_data.max_mana += flat_max_mana_per_level * levels
    attribute_data.max_energy_shield += flat_max_energy_shield_per_level * levels
    attribute_data.max_stamina += flat_max_stamina_per_level * levels

    return {
        "success": true,
        "skill_points_awarded": skill_points_per_level * levels,
        "level_applied": levels,
    }