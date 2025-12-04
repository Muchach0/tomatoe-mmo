# Global class - Items registry
extends Node

var EMPTY : Item = Item.new()
const STICK : Item = preload("res://Resources/Items/Materials/stick.tres")
const ROCK : Item = preload("res://Resources/Items/Materials/rock.tres")

var all_items = [
	EMPTY,
	STICK,
	ROCK
]

var item_registry := {}


func _ready() -> void:
	_register_items()
	Items.EMPTY.item_name = "EMPTY"


func _register_items() -> void:
	for item in all_items:
		item_registry[item.item_name] = item


func get_item(item_name: String) -> Item:
	return item_registry.get(item_name)
