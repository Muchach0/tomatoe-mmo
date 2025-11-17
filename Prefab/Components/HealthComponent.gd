extends Node2D
class_name HealthComponent

const DAMAGE_LABEL_SCENE: PackedScene = preload("res://Prefab/Components/DamageLabel.tscn")

@onready var life_ui_bar = $LifeUIBar
@onready var damage_spawning_point = $DamageSpawningPoint

func init_life_bar(health):
    life_ui_bar.max_value = health
    life_ui_bar.value = health

func update_life_bar(health, damage_taken):
    life_ui_bar.value = health
    # Create a DamageLabel
    var damage_label = DAMAGE_LABEL_SCENE.instantiate()
    damage_label.position = damage_spawning_point.position
    add_child(damage_label)
    damage_label.set_damage(damage_taken)
