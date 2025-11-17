extends Node2D

@onready var player = get_owner()
@onready var bullet_manager

# Deprecated - kept for compatibility with old bullet system
var bullet_scene : PackedScene = preload("res://Prefab/Bullet/Bullet.tscn")

# Shooting cooldown to prevent spam
var last_shot_time: float = 0.0
var shot_cooldown: float = 0.1  # 100ms between shots

# Continuous firing state
var is_mouse_pressed: bool = false
var last_touch_position: Vector2 = Vector2.ZERO


func _ready():
    # Find bullet manager in scene
    bullet_manager = get_tree().get_first_node_in_group("bullet_manager")
    if not bullet_manager:
        push_error("BulletManager not found! Make sure it's added to the scene and in 'bullet_manager' group.")

# Convert screen coordinates to world coordinates
func screen_to_world(screen_pos: Vector2) -> Vector2:
    var viewport = get_viewport()
    var canvas_transform = viewport.get_canvas_transform().affine_inverse()
    return canvas_transform * screen_pos

func _process(_delta):
    # Continuous firing while mouse/touch is held down
    if is_mouse_pressed and not player.is_hidden:
        # Only handle input if we are the authority (or single player)
        if multiplayer == null or is_multiplayer_authority():
            # Use current touch position for mobile, current mouse position for PC
            if last_touch_position != Vector2.ZERO:
                shoot_primary(last_touch_position)
            else:
                shoot_primary()

# Handles input from mouse (PC) and touch (Mobile)
func _unhandled_input(event: InputEvent) -> void:
    # Only handle input if we are the authority (or single player)
    if not (multiplayer == null or is_multiplayer_authority()):
        return
    if player.is_hidden:
        return
    
    # PC: left mouse button press/release
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            is_mouse_pressed = true
            shoot_primary()  # Shoot immediately on press
        else:
            is_mouse_pressed = false
    
    # Mobile: screen touch press/release
    elif event is InputEventScreenTouch:
        if event.pressed:
            is_mouse_pressed = true
            # Convert screen coordinates to world coordinates
            last_touch_position = screen_to_world(event.position)
            shoot_primary(last_touch_position)  # Shoot immediately on touch
        else:
            is_mouse_pressed = false
            last_touch_position = Vector2.ZERO  # Reset touch position
    
    # Mobile: screen drag to update touch position during continuous firing
    elif event is InputEventScreenDrag and is_mouse_pressed:
        # Convert screen coordinates to world coordinates
        last_touch_position = screen_to_world(event.position)

func shoot_primary(mobile_touch_position: Vector2 = Vector2.ZERO):
    # Check cooldown
    var current_time = Time.get_unix_time_from_system()
    if current_time - last_shot_time < shot_cooldown:
        return
    
    last_shot_time = current_time
    
    var mouse_direction : Vector2 = Vector2.ZERO # Init - Direction of the mouse or touch position

    if mobile_touch_position != Vector2.ZERO:
        mouse_direction = (mobile_touch_position - player.global_position).normalized()
    else:
        print("player_weapond.gd - shoot_primary() - Mouse position: ", get_global_mouse_position())
        var mouse_position := get_global_mouse_position()
        mouse_direction = (mouse_position - player.global_position).normalized()
        
    # Prepare bullet data with upgrade effects
    var bullet_data = {
        "damage": 5.0,
        "speed": 300.0,
        "max_pierce": 1
    }
    
    # Apply strategy upgrades to bullet data
    if player.bullet_strategies and player.bullet_strategies.size() > 0:
        for strategy in player.bullet_strategies:
            if strategy and strategy.has_method("modify_bullet_data"):
                bullet_data = strategy.modify_bullet_data(bullet_data)
    
    # # Client-side prediction for responsive feedback
    # if bullet_manager and not multiplayer.is_server():
    #     bullet_manager.spawn_prediction_bullet(player.global_position, mouse_direction, bullet_data)
    
    # Request authoritative bullet spawn from server
    if bullet_manager:
        bullet_manager.request_bullet_spawn.rpc(player.global_position, mouse_direction, bullet_data)
#     else:
#         # Fallback to old system if bullet manager not available
#         _fallback_shoot_primary(mouse_direction)

# func _fallback_shoot_primary(mouse_direction: Vector2):
#     """Fallback to old bullet system if BulletManager not available"""
#     var spawned_bullet = bullet_scene.instantiate()
#     get_tree().root.add_child(spawned_bullet)
    
#     spawned_bullet.global_position = player.global_position
#     spawned_bullet.rotation = mouse_direction.angle()
#     spawned_bullet.shooter_id = player.peer_id  # Set shooter ID to prevent self-damage

#     # Apply strategy upgrades
#     if player.bullet_strategies and player.bullet_strategies.size() > 0:
#         for strategy in player.bullet_strategies:
#             if strategy and strategy.has_method("apply_upgrade"):
#                 strategy.apply_upgrade(spawned_bullet)
