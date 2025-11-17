extends Node2D
# This demo is an example of controling a high number of 2D objects with logic
# and collision without using nodes in the scene. This technique is a lot more
# efficient than using instancing and nodes, but requires more programming and
# is less visual. Bullets are managed together in the `bullets.gd` script.

const BULLET_COUNT = 200
const SPEED_MIN = 20
const SPEED_MAX = 80

# Test drawing circle by hand
const BASE_LINE_WIDTH: float = 3.0
const DRAW_COLOR = Color.WHITE * Color(1, 0, 0, 0.5)

# const bullet_image := preload("res://assets/bullet2.png")

var bullets := []
var shape := RID()

var bullets_rand_data := []


class Bullet:
    var position := Vector2()
    var speed := 1.0
    # The body is stored as a RID, which is an "opaque" way to access resources.
    # With large amounts of objects (thousands or more), it can be significantly
    # faster to use RIDs compared to a high-level approach.
    var body := RID()

func _ready() -> void:
    EventBus.connect("bullets_init_and_start", server_init_and_start)
    # init_game()

func server_init_and_start(current_level, nb_bullets) -> void:
    if !multiplayer.is_server():
        return   # Only the server should initialize and start the bullets.
    print("bullets.gd - server_init_and_start () : creating %d bullets" % nb_bullets)
    bullets_rand_data = []
    
    for bullet in nb_bullets:
        bullets_rand_data.append({
            "position": Vector2(randf_range(0, get_viewport_rect().size.x), randf_range(0, get_viewport_rect().size.y)),
            "speed": randf_range(SPEED_MIN, SPEED_MAX)
        })
    
    init_game.rpc(current_level, nb_bullets, bullets_rand_data) # The server send the data to the clients to initialize the game (with same start value). 
    # Note that  there is no syncinc of bullet position and speed after the game has started.
    # This is because the bullets are not supposed to be controlled by the player, so there is no need to synchronize their state after initialization.
    # This might an issue if the game is paused and resumed, as the bullets will not be synchronized with the server state.
    # This is a trade-off between performance and synchronization.


@rpc("any_peer", "reliable")
func init_game(current_level, nb_bullets, data_rand) -> void:
    print("bullets.gd - initiating the game level %d with %d bullets" % [current_level, nb_bullets])
    EventBus.emit_signal("start_level", current_level, nb_bullets) # Emit a signal to notify the UI to update the number of bullets (locally)
    shape = PhysicsServer2D.circle_shape_create()
    # Set the collision shape's radius for each bullet in pixels.
    PhysicsServer2D.shape_set_data(shape, 8)
    bullets = []
    for _i in len(data_rand):
        var bullet := Bullet.new()
        # Give each bullet its own random speed.
        bullet.speed = data_rand[_i]["speed"]
        bullet.body = PhysicsServer2D.body_create()

        PhysicsServer2D.body_set_space(bullet.body, get_world_2d().get_space())
        PhysicsServer2D.body_add_shape(bullet.body, shape)
        # Don't make bullets check collision with other bullets to improve performance.
        PhysicsServer2D.body_set_collision_mask(bullet.body, 0)

        # Place bullets randomly on the viewport and move bullets outside the
        # play area so that they fade in nicely.
        bullet.position = data_rand[_i]["position"]
        var transform2d := Transform2D()
        transform2d.origin = bullet.position
        PhysicsServer2D.body_set_state(bullet.body, PhysicsServer2D.BODY_STATE_TRANSFORM, transform2d)

        bullets.push_back(bullet)




func _process(_delta: float) -> void:
    # Order the CanvasItem to update every frame.
    queue_redraw()


func _physics_process(delta: float) -> void:
    var transform2d := Transform2D()
    var offset := - 16
    for bullet: Bullet in bullets:
        bullet.position.y += bullet.speed * delta

        if bullet.position.y >  get_viewport_rect().size.y:
            # Move the bullet back to the right when it left the screen.
            bullet.position.y = offset

        transform2d.origin = bullet.position
        PhysicsServer2D.body_set_state(bullet.body, PhysicsServer2D.BODY_STATE_TRANSFORM, transform2d)


# Instead of drawing each bullet individually in a script attached to each bullet,
# we are drawing *all* the bullets at once here.
func _draw() -> void:
    # var offset := -bullet_image.get_size() * 0.5
    var offset := Vector2(BASE_LINE_WIDTH * 0.5, BASE_LINE_WIDTH * 0.5)

    for bullet: Bullet in bullets:
        # draw_texture(bullet_image, bullet.position + offset)
        draw_circle(bullet.position + offset, BASE_LINE_WIDTH * 2.0, DRAW_COLOR)


# Perform cleanup operations (required to exit without error messages in the console).
func _exit_tree() -> void:
    for bullet: Bullet in bullets:
        PhysicsServer2D.free_rid(bullet.body)

    # PhysicsServer2D.free_rid(shape)
    bullets.clear()
