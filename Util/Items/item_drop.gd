class_name ItemDrop
extends Node2D


@onready var item_sprite: Sprite2D = $ItemSprite
@onready var hitbox: Area2D = $Area2D
@onready var count_label: Label = $CountLabel
@onready var multiplayerSynchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

var current_world: String = ""
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

    force_visibility_update()

func update_display():
    item_sprite.texture = stack.item.sprite
    count_label.text = str(stack.count)


func on_body_entered(body: Node2D) -> void:
    if "Player" not in body.get_groups():
        return
    
    var player = body as Player
    if player.is_multiplayer_authority(): # Only the authority should request item pickup
        # Request server to handle item pickup
        request_item_pickup.rpc(get_path(), player.peer_id)


func _physics_process(delta: float) -> void:
    global_position += velocity * delta


func destroy_item_drop():
    if multiplayer.is_server():
        queue_free()
    else:
        # Hide the item drop on all clients
        visible = false

func get_players_id_in_current_world() -> Array:
    var players_id_in_current_world: Array = []
    for player_id in EventBus.players:
        if EventBus.players[player_id]["current_world"] == current_world:
            players_id_in_current_world.append(player_id)
    return players_id_in_current_world


func force_visibility_update() -> void:
    if multiplayerSynchronizer == null or not multiplayer or not multiplayer.is_server():
        return
    print(multiplayer.get_unique_id(), " - item_drop.gd - force_visibility_update() - Force visibility update for item drop in world: ", current_world)
    for players_id in EventBus.players:
        if players_id in get_players_id_in_current_world():
            multiplayerSynchronizer.set_visibility_for(players_id, true)
        else:
            multiplayerSynchronizer.set_visibility_for(players_id, false)
    # sync.update_visibility()


# ================ MULTIPLAYER ITEM PICKUP SECTION ================

@rpc("any_peer", "call_local", "reliable")
func request_item_pickup(item_drop_path: NodePath, player_peer_id: int) -> void:
    # Only the server should handle the item pickup
    if not multiplayer.is_server():
        return
    
    var requesting_peer_id = multiplayer.get_remote_sender_id()
    # Validate that the requesting peer matches the player peer ID
    if requesting_peer_id != player_peer_id:
        print("item_drop.gd - request_item_pickup() - Peer ID mismatch. Requesting: ", requesting_peer_id, " Player: ", player_peer_id)
        return
    
    var item_drop = get_node_or_null(item_drop_path)
    if not item_drop or not item_drop is ItemDrop:
        print("item_drop.gd - request_item_pickup() - Item drop not found at path: ", item_drop_path)
        return
    
    var item_drop_node = item_drop as ItemDrop
    
    # Validate the item drop is not empty
    if item_drop_node.stack.is_empty():
        print(multiplayer.get_unique_id(), " - item_drop.gd - request_item_pickup() - Item drop is empty")
        return
    
    # Store item info before processing
    var original_count = item_drop_node.stack.count
    var item_type = item_drop_node.stack.item
    var item_name = item_type.item_name if item_type else ""
    
    # Calculate how much can be picked up (simulate on server to determine remaining)
    # We'll let the client's inventory handle the actual addition, but we need to know
    # how much was actually picked up. For now, we'll assume all items are picked up
    # and let the client's inventory.add_item() handle stacking/limits
    
    # Tell the client to add the item to their inventory
    print(multiplayer.get_unique_id(), " - item_drop.gd - request_item_pickup() - Telling client to add item to inventory: ", item_name, " - count: ", original_count)
    add_item_to_player_inventory.rpc_id(player_peer_id, item_name, original_count)
    
    # Emit signal for quest tracking (only on server)
    if original_count > 0 and item_type:
        EventBus.item_picked_up.emit(item_type, original_count)
    
    # For now, assume all items are picked up. The client will tell us if there's a remainder
    # We'll update this after the client responds, but for immediate feedback, remove all
    item_drop_node.stack.count = 0
    item_drop_node.stack.item = Items.EMPTY
    print(multiplayer.get_unique_id(), " - item_drop.gd - request_item_pickup() - Item drop is now empty")
    # Broadcast the result to all clients (item drop is now empty)
    # sync_item_pickup_result.rpc(item_drop_path, item_name, 0, original_count)


@rpc("any_peer", "call_local", "reliable")
func add_item_to_player_inventory(item_name: String, count: int) -> void:
    # This runs on the client that picked up the item to add it to their inventory
    var player = _get_local_player()
    if not player:
        return
    
    var original_count = stack.count
    var item_type = stack.item  # Store item reference before consumption
    stack = player.inventory.add_item(stack)
    var picked_up_count = original_count - stack.count
        

    if picked_up_count > 0 and item_type:
        EventBus.item_picked_up.emit(item_type, picked_up_count) # For questing system

    if stack.is_empty():
         sync_item_pickup_result.rpc(get_path(), item_name, 0, picked_up_count)

    if not stack.is_empty():
        print("item_drop.gd - add_item_to_player_inventory() - Inventory full, could not pick up all items. Remaining: ", stack.count)
        sync_item_pickup_result.rpc(get_path(), item_name, stack.count, picked_up_count)


@rpc("any_peer", "call_local", "reliable")
func sync_item_pickup_result(item_drop_path: NodePath, item_name: String, remaining_count: int, _picked_up_count: int) -> void:
    # This runs on all clients to sync the item pickup result
    var item_drop = get_node_or_null(item_drop_path)
    if not item_drop or not item_drop is ItemDrop:
        return
    
    var item_drop_node = item_drop as ItemDrop
    
    # Update the stack count
    item_drop_node.stack.count = remaining_count
    
    # If the count is 0, set item to EMPTY
    if remaining_count <= 0:
        item_drop_node.stack.item = Items.EMPTY
        item_drop_node.destroy_item_drop()
    else:
        # Ensure the item is still set correctly (in case it was changed)
        if item_drop_node.stack.item.item_name != item_name:
            var item = Items.get_item(item_name)
            if item:
                item_drop_node.stack.item = item
        item_drop_node.update_display()


func _get_local_player() -> Player:
    # Find the local player (the one with multiplayer authority)
    var players = get_tree().get_nodes_in_group("Player")
    for player_node in players:
        if player_node is Player:
            var player = player_node as Player
            if player.is_multiplayer_authority():
                return player
    return null
