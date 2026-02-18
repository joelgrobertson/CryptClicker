# camera_controller.gd
# Smooth zoom/pan camera. Attached to a Camera2D node.
extends Camera2D

@export var zoom_speed: float = 80.0
@export var min_zoom: float = 0.4
@export var max_zoom: float = 2.0
@export var pan_speed: float = 800.0

var zoom_target: Vector2
var is_dragging: bool = false
var drag_start_mouse: Vector2
var drag_start_camera: Vector2

func _ready():
	zoom_target = zoom
	# Start zoomed out to see the full play area (spawn radius ~600px)
	var play_area = 1200.0 # Diameter of the play field
	var viewport_size = get_viewport_rect().size
	var needed_zoom = min(viewport_size.x / (play_area * 1.2), viewport_size.y / (play_area * 1.2))
	zoom_target = Vector2(needed_zoom, needed_zoom).clamp(Vector2.ONE * min_zoom, Vector2.ONE * max_zoom)
	zoom = zoom_target

func _process(delta):
	_handle_zoom(delta)
	_handle_pan(delta)
	_handle_drag()

func _handle_zoom(delta):
	# Zoom is handled via Ctrl+scroll (bare scroll = tool switching)
	zoom = zoom.slerp(zoom_target, zoom_speed * delta)

func _input(event):
	# Ctrl+scroll for zoom
	if event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = (zoom * 1.15).clamp(Vector2.ONE * min_zoom, Vector2.ONE * max_zoom)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = (zoom * 0.85).clamp(Vector2.ONE * min_zoom, Vector2.ONE * max_zoom)
			get_viewport().set_input_as_handled()

func _handle_pan(delta):
	var input = Input.get_vector("camera_move_left", "camera_move_right", "camera_move_up", "camera_move_down")
	if input != Vector2.ZERO:
		position += input.normalized() * pan_speed * delta * (1.0 / zoom.x)

func _handle_drag():
	# Middle mouse drag
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		if not is_dragging:
			is_dragging = true
			drag_start_mouse = get_viewport().get_mouse_position()
			drag_start_camera = position
		else:
			var move = get_viewport().get_mouse_position() - drag_start_mouse
			position = drag_start_camera - move * (1.0 / zoom.x)
	else:
		is_dragging = false
