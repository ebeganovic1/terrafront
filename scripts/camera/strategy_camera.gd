extends Camera2D

const World = preload("res://scripts/world/world_data.gd")

func _ready() -> void:
	var bindings := {"camera_left": KEY_A, "camera_right": KEY_D, "camera_up": KEY_W, "camera_down": KEY_S}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = bindings[action]
			InputMap.action_add_event(action, key)

func _process(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	position += direction.normalized() * 650.0 * delta / zoom.x
	constrain()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var multiplier := 1.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			multiplier = 1.15
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			multiplier = 1.0 / 1.15
		if multiplier != 1.0:
			var before := get_global_mouse_position()
			zoom = Vector2.ONE * clampf(zoom.x * multiplier, 0.4, 4.0)
			force_update_scroll()
			position += before - get_global_mouse_position()
			constrain()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		position -= event.relative / zoom
		constrain()

func constrain() -> void:
	position = position.clamp(Vector2.ZERO, Vector2(World.WIDTH, World.HEIGHT) * World.TILE_SIZE)
