class_name DebugTools
extends Node

var instance_index: int = -1
var instance_socket: TCPServer 

# In the 'GAME' tab, the option should be de-embeded for the server window to be re-positioned.

func _init() -> void:
    if OS.is_debug_build():
        detect_instance_index()

func _ready() -> void:
    if OS.is_debug_build():
        update_window_name()
        update_instance_window_rect(get_window(), 4)
    
func update_window_name() -> void:
    var cmd_args = OS.get_cmdline_args()
    if "--server" in cmd_args:
        get_window().title = "Server"
    else:
        get_window().title = "Client " + str(instance_index + 1)
    

func detect_instance_index() -> void:
    var cmd_args = OS.get_cmdline_args()
    
    # Server always gets index 0
    if "--server" in cmd_args:
        instance_index = 0
        return
    
    # Clients use port detection starting from index 1
    instance_socket = TCPServer.new()
    for index: int in range(1, 21):  # Start from 1, ports 5001-5020
        if instance_socket.listen(5000 + index) == OK:
            instance_index = index
            break

func update_instance_window_rect(window: Window, max_instances_count: int, title_bar_height: int = 30) -> void:
    var screen_rect: Rect2 = Rect2(DisplayServer.screen_get_usable_rect())
    
    # Set window title based on instance type

    var cols: int = ceili(sqrt(max_instances_count))
    var rows: int = ceili(float(max_instances_count) / cols)
    
    var width: float = screen_rect.size.x / cols
    var height: float = screen_rect.size.y / rows
    
    # Special layout: Server (0) at row 0 col 0, Client 1 (1) at row 1 col 0, Client 2 (2) at row 1 col 1
    # Row 0, column 1 is kept empty
    var col: int
    var row: int
    if instance_index == 0:
        # Server at row 0, column 0
        row = 0
        col = 0
    elif instance_index == 1:
        # Client 1 at row 1, column 0
        row = 1
        col = 0
    elif instance_index == 2:
        # Client 2 at row 1, column 1
        row = 1
        col = 1
    else:
        # Fallback to standard grid layout for other instances
        col = instance_index % cols
        row = int(float(instance_index) / cols)
    
    var origin: Vector2 = screen_rect.position + Vector2(
        col * width,
        row * height
        )
    
    window.size = Vector2(width, height - title_bar_height)
    window.position = origin + Vector2.DOWN * title_bar_height
