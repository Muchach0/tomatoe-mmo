extends Node2D

@onready var player = get_owner()
@onready var bullet_manager

# Deprecated - kept for compatibility with old bullet system
var bullet_scene : PackedScene = preload("res://Prefab/Bullet/Bullet.tscn")

# Continuous firing state
var is_mouse_pressed: bool = false
var last_touch_position: Vector2 = Vector2.ZERO

# Double tap detection for mobile
var last_touch_time: float = 0.0
var last_touch_pos: Vector2 = Vector2.ZERO
const DOUBLE_TAP_TIME_THRESHOLD: float = 0.3  # Time in seconds between taps
const DOUBLE_TAP_DISTANCE_THRESHOLD: float = 50.0  # Maximum distance in pixels between taps


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
                execute_skill(0, last_touch_position)  # Skill 0 = SimpleShootSkill
            else:
                execute_skill(0)  # Skill 0 = SimpleShootSkill

# Handles input from mouse (PC) and touch (Mobile)
func _unhandled_input(event: InputEvent) -> void:
    # Only handle input if we are the authority (or single player)
    if not (multiplayer == null or is_multiplayer_authority()):
        return
    if player.is_hidden:
        return
    
    # PC: left mouse button press/release (SimpleShootSkill)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            is_mouse_pressed = true
            execute_skill(0)  # Skill 0 = SimpleShootSkill
        else:
            is_mouse_pressed = false
    
    # PC: right mouse button (AOEShootSkill)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        if event.pressed:
            execute_skill(1)  # Skill 1 = AOEShootSkill
    
    # Mobile: screen touch press/release
    elif event is InputEventScreenTouch:
        if event.pressed:
            var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
            var current_pos = event.position
            var world_pos = screen_to_world(current_pos)
            
            # Check if this is a double tap
            var time_since_last_touch = current_time - last_touch_time
            var distance_from_last_touch = current_pos.distance_to(last_touch_pos)
            
            if time_since_last_touch < DOUBLE_TAP_TIME_THRESHOLD and distance_from_last_touch < DOUBLE_TAP_DISTANCE_THRESHOLD:
                # Double tap detected - execute skill 1 (AOEShootSkill)
                execute_skill(1, world_pos)
                # Reset double tap tracking to prevent triple tap from triggering again
                last_touch_time = 0.0
                last_touch_pos = Vector2.ZERO
            else:
                # Single tap - execute skill 0 (SimpleShootSkill)
                is_mouse_pressed = true
                last_touch_position = world_pos
                execute_skill(0, last_touch_position)
                # Update double tap tracking
                last_touch_time = current_time
                last_touch_pos = current_pos
        else:
            is_mouse_pressed = false
            last_touch_position = Vector2.ZERO  # Reset touch position
    
    # Mobile: screen drag to update touch position during continuous firing
    elif event is InputEventScreenDrag and is_mouse_pressed:
        # Convert screen coordinates to world coordinates
        last_touch_position = screen_to_world(event.position)

## Execute a skill by index
## @param skill_index: Index of the skill in player.skills array (0 = SimpleShootSkill, 1 = AOEShootSkill)
## @param mobile_touch_position: Optional touch position for mobile devices
func execute_skill(skill_index: int, mobile_touch_position: Vector2 = Vector2.ZERO):
    if not player or player.is_hidden:
        return
    
    # Check if skill index is valid
    if skill_index < 0 or skill_index >= player.skills.size():
        push_error("player_weapon.gd - execute_skill() - Invalid skill index: " + str(skill_index))
        return
    
    var skill = player.skills[skill_index]
    if not skill:
        push_error("player_weapon.gd - execute_skill() - Skill at index " + str(skill_index) + " is null")
        return
    
    # Get target position
    var target_position: Vector2 = Vector2.ZERO
    if mobile_touch_position != Vector2.ZERO:
        target_position = mobile_touch_position
    else:
        target_position = get_global_mouse_position()
    
    # Execute the skill
    skill.execute(player, target_position, bullet_manager)
