@tool
extends Area2D

var _bullet_strategy: BulletStrategy

@export var bullet_strategy: BulletStrategy:
    get: return _bullet_strategy
    set(v):
        # Keep the value, don’t write back to the exported name again.
        _bullet_strategy = v
        # Make per-instance safe in the editor
        if Engine.is_editor_hint() and v and !v.resource_local_to_scene:
            v.resource_local_to_scene = true
        # Apply safely (both editor & game)
        if is_inside_tree():
            _apply_strategy()

func _ready() -> void:
    _apply_strategy()
    # body_entered.connect(on_body_entered)


func _apply_strategy() -> void:
    if !_bullet_strategy: return
    var sprite := $Sprite2D if has_node("Sprite2D") else null
    var label  := $Label if has_node("Label") else null
    if sprite: sprite.texture = _bullet_strategy.texture
    if label:  label.text    = _bullet_strategy.upgrade_text

# # Used when editing to denote that the sprite has changed and needs updating
# @export var needs_update := false

# @export var bullet_strategy : BulletStrategy:
#     set(val):
#         bullet_strategy = val
#         needs_update = true


# func _ready() -> void:
#     body_entered.connect(on_body_entered)
#     # _on_resource_set()

# func _on_resource_set():
#     print("My resource was set!")
#     if bullet_strategy:
#         # Check if nodes are available (either in editor or at runtime)
#         if sprite:
#             sprite.texture = bullet_strategy.texture
#         if upgrade_label:
#             upgrade_label.text = bullet_strategy.upgrade_text

# func _process(delta: float) -> void:
#     if Engine.is_editor_hint():
#         if needs_update:
#             sprite.texture = bullet_strategy.texture
#             upgrade_label.text = bullet_strategy.upgrade_text
#             needs_update = false

# func on_body_entered(body: PhysicsBody2D):
#     # if body is Player:
#         ######################################
#         # Strategy Relevant Code:
#         # This adds the upgrade to our player,
#         # which the player uses when firing.
#         ######################################
#     body.upgrades.append(bullet_strategy)
    
#     queue_free()
