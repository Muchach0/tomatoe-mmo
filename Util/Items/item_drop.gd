class_name ItemDrop
extends Node2D


@onready var item_sprite: Sprite2D = $ItemSprite
@onready var hitbox: Area2D = $Area2D
@onready var count_label: Label = $CountLabel

var stack : ItemStack
var velocity : Vector2

var velocity_tween : Tween


func _ready():
    hitbox.body_entered.connect(on_body_entered)
    item_sprite.texture = stack.item.sprite
    count_label.text = str(stack.count)
    
    var speed = randf_range(75, 100)
    velocity = Vector2.RIGHT.rotated(deg_to_rad(randf_range(0.0, 360.0))) * speed
    
    velocity_tween = create_tween()
    
    velocity_tween.tween_property(self, "velocity", Vector2.ZERO, 0.75)
    velocity_tween.set_trans(Tween.TRANS_BOUNCE)
    velocity_tween.set_ease(Tween.EASE_OUT)


func update_display():
    item_sprite.texture = stack.item.sprite
    count_label.text = str(stack.count)


func on_body_entered(body: Node2D) -> void:
    if "Player" not in body.get_groups():
        return
    print(multiplayer.get_unique_id(), " - item_drop.gd - on_body_entered() - Player entered item drop")
    # TODO: TO FIX LATER - this is not the best way to do it.
    # queue_free() # Probably not the best to queue free on local player with no sync, but it works for now.
    # and it feels better
    # TODO: Queue free send to server and sync to all clients.

    var player = body as Player
    if player.is_multiplayer_authority(): # Only the authority should add the item to the inventory
        var original_count = stack.count
        var item_type = stack.item  # Store item reference before consumption
        stack = player.inventory.add_item(stack)
        var picked_up_count = original_count - stack.count
        
        # Emit signal for quest tracking (only on server)
        if picked_up_count > 0 and item_type:
            EventBus.item_picked_up.emit(item_type, picked_up_count)
        
    # queue_free()
    if stack.is_empty():
        destroy_item_drop()
    else:
        update_display()


func _physics_process(delta: float) -> void:
    global_position += velocity * delta


func destroy_item_drop():
    if multiplayer.is_server():
        queue_free()
    else:
        # Hide the item drop on all clients
        visible = false