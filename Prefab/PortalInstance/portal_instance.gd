extends Node2D
class_name PortalInstance

@export var world_scene_ressource: WorldSceneRessourceClass = null
# not used for now
@export var portal_scale: Vector2 = Vector2.ONE
@export var portal_visible: bool = true
@export var portal_enabled: bool = true
@export var portal_locked: bool = false
@export var portal_locked_by_player_id: int = 0

@onready var area_2d: Area2D = $Area2D
@onready var sprite_2d: Sprite2D = $Sprite2D

var world_scene_path: String = ""
var world_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
    if world_scene_ressource != null:
        # loading info from resource file to variables
        world_scene_path = world_scene_ressource.world_scene_path
        world_offset = world_scene_ressource.world_offset

    if portal_visible and portal_enabled and area_2d != null:
        area_2d.body_entered.connect(on_body_entered)

    if not portal_visible and not portal_enabled and sprite_2d != null:
        disable_portal()


func on_body_entered(body: Node2D) -> void:
    if body.is_in_group("Player"):
        print(multiplayer.get_unique_id(), " - PortalInstance.gd - on_body_entered - Player entered portal: ", body)
        player_travel_to_destination_world(body)

func player_travel_to_destination_world(player: Node2D) -> void:
    if player == null:
        return
    var player_id = player.peer_id
    EventBus.move_player_to_destination_world.emit(player_id, world_scene_path, world_offset)

func disable_portal() -> void:
    if area_2d != null:
        area_2d.set_deferred("disabled", true)
        if area_2d.body_entered.is_connected(on_body_entered):
            area_2d.body_entered.disconnect(on_body_entered)
    if sprite_2d != null:
        sprite_2d.set_deferred("visible", false)
    if portal_enabled:
        portal_enabled = false
    if portal_locked:
        portal_locked = false
    if portal_locked_by_player_id != 0:
        portal_locked_by_player_id = 0

func enable_portal() -> void:
    if area_2d != null:
        area_2d.set_deferred("disabled", false)
        if not area_2d.body_entered.is_connected(on_body_entered):
            area_2d.body_entered.connect(on_body_entered)
    if sprite_2d != null:
        sprite_2d.set_deferred("visible", true)
    if portal_enabled:
        portal_enabled = true
    if portal_locked:
        portal_locked = false
    if portal_locked_by_player_id != 0:
        portal_locked_by_player_id = 0