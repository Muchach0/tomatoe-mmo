extends Node2D
class_name PortalInstance

@export var portal_ressource: PortalInstanceRessourceClass = null

@onready var area_2d: Area2D = $Area2D
@onready var sprite_2d: Sprite2D = $Sprite2D

var portal_scene_path: String = ""
var world_offset: Vector2 = Vector2.ZERO
# not used for now
var portal_scale: Vector2 = Vector2.ONE
var portal_visible: bool = true
var portal_enabled: bool = true
var portal_locked: bool = false
var portal_locked_by_player_id: int = 0

func _ready() -> void:
    if portal_ressource != null:
        # loading info from resource file to variables
        portal_scene_path = portal_ressource.portal_scene_path
        world_offset = portal_ressource.world_offset

        # not used for now
        portal_scale = portal_ressource.portal_scale
        portal_visible = portal_ressource.portal_visible
        portal_enabled = portal_ressource.portal_enabled
        portal_locked = portal_ressource.portal_locked
        portal_locked_by_player_id = portal_ressource.portal_locked_by_player_id


    if area_2d != null:
        area_2d.body_entered.connect(on_body_entered)


func on_body_entered(body: Node2D) -> void:
    if body.is_in_group("Player"):
        print(multiplayer.get_unique_id(), " - PortalInstance.gd - on_body_entered - Player entered portal: ", body)
        player_travel_to_destination_world(body)

func player_travel_to_destination_world(player: Node2D) -> void:
    if player == null:
        return
    var player_id = player.peer_id
    EventBus.move_player_to_destination_world.emit(player_id, portal_scene_path, world_offset)
