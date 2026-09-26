extends Camera2D

signal tile_clicked(world_position: Vector2)

const World = preload("res://scripts/world/world_data.gd")
const DRAG_THRESHOLD := 6.0
var drag_button := 0
var press_position := Vector2.ZERO
var last_position := Vector2.ZERO
var dragging := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_drag()

func cancel_drag() -> void:
	drag_button = 0
	dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _input(event: InputEvent) -> void:
	if drag_button == 0:
		return
	if event is InputEventMouseMotion:
		if not dragging and event.position.distance_to(press_position) >= DRAG_THRESHOLD:
			dragging = true
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		if dragging:
			position -= (event.position - last_position) / zoom
			constrain()
		last_position = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == drag_button and not event.pressed:
		var inspect_click: bool = drag_button == MOUSE_BUTTON_LEFT and not dragging and event.position.distance_to(press_position) < DRAG_THRESHOLD
		cancel_drag()
		if inspect_click:
			force_update_scroll()
			tile_clicked.emit(get_canvas_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		drag_button = event.button_index
		press_position = event.position
		last_position = event.position
		dragging = false
		get_viewport().set_input_as_handled()
		return
	var multiplier := 1.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		multiplier = 1.15
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		multiplier = 1.0 / 1.15
	if multiplier != 1.0:
		var before := get_global_mouse_position()
		zoom = Vector2.ONE * clampf(zoom.x * multiplier, 0.12, 2.5)
		force_update_scroll()
		position += before - get_global_mouse_position()
		constrain()
		get_viewport().set_input_as_handled()

func constrain() -> void:
	position = position.clamp(Vector2.ZERO, Vector2(World.WIDTH, World.HEIGHT) * World.TILE_SIZE)
