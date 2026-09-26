extends Node2D

const World = preload("res://scripts/world/world_data.gd")
const Generator = preload("res://scripts/world/world_generator.gd")
const Renderer = preload("res://scripts/map/world_renderer.gd")
const StrategyCamera = preload("res://scripts/camera/strategy_camera.gd")
var world: RefCounted
var renderer: Node2D
var camera: Camera2D
var information: Label
var seed_input: LineEdit
var selected := Vector2i(-1, -1)
var status: Label

func _ready() -> void:
	renderer = Renderer.new()
	renderer.z_index = -1
	add_child(renderer)
	camera = StrategyCamera.new()
	add_child(camera)
	camera.tile_clicked.connect(inspect_position)
	build_ui()
	regenerate(260926)

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(284, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f1f5f2")
	style.border_color = Color("d4e0db")
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.06, 0.16, 0.19, 0.16)
	style.shadow_size = 12
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 15
	ui_theme.set_color("font_color", "Label", Color("29454d"))
	ui_theme.set_color("font_color", "Button", Color("29454d"))
	ui_theme.set_color("font_hover_color", "Button", Color("163e40"))
	ui_theme.set_color("font_pressed_color", "Button", Color("163e40"))
	ui_theme.set_color("font_color", "LineEdit", Color("29454d"))
	ui_theme.set_color("caret_color", "LineEdit", Color("29454d"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("dce8e2") if state == "normal" else Color("c4ded3")
		button_style.set_corner_radius_all(8)
		button_style.set_content_margin_all(10)
		if state == "focus":
			button_style.bg_color = Color.TRANSPARENT
			button_style.border_color = Color("499784")
			button_style.set_border_width_all(2)
		ui_theme.set_stylebox(state, "Button", button_style)
		ui_theme.set_stylebox(state, "LineEdit", button_style)
	panel.theme = ui_theme
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Terrafront"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("245f59"))
	column.add_child(title)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 12)
	column.add_child(status)
	column.add_child(HSeparator.new())
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "World seed (integer)"
	seed_input.text = "260926"
	column.add_child(seed_input)
	var generate_button := Button.new()
	generate_button.text = "Generate continent"
	generate_button.pressed.connect(func():
		if seed_input.text.is_valid_int():
			regenerate(int(seed_input.text))
		else:
			status.text = "Enter a valid integer seed."
		seed_input.release_focus())
	column.add_child(generate_button)
	var home := Button.new()
	home.text = "Return to settlement [Home]"
	home.pressed.connect(focus_settlement)
	column.add_child(home)
	var overview := Button.new()
	overview.text = "View entire continent"
	overview.pressed.connect(show_overview)
	column.add_child(overview)
	column.add_child(HSeparator.new())
	information = Label.new()
	information.add_theme_font_size_override("font_size", 15)
	column.add_child(information)
	column.add_child(HSeparator.new())
	var controls := Label.new()
	controls.text = "Hold + drag mouse to explore\nScroll to zoom / Click to inspect\nHome to return to settlement\n\nResource potential: 0 - 5"
	controls.add_theme_font_size_override("font_size", 13)
	column.add_child(controls)

func regenerate(seed_value: int) -> void:
	world = Generator.new().generate(seed_value)
	camera.cancel_drag()
	renderer.set_world(world)
	status.text = "SEED %d  /  %d x %d TILES" % [seed_value, World.WIDTH, World.HEIGHT]
	camera.zoom = Vector2.ONE * 0.55
	focus_settlement()
	inspect(world.settlements[0].cell)

func focus_settlement() -> void:
	if world != null:
		camera.position = (Vector2(world.settlements[0].cell) + Vector2.ONE * 0.5) * World.TILE_SIZE

func show_overview() -> void:
	var available := get_viewport_rect().size - Vector2(360, 60)
	var dimensions := Vector2(World.WIDTH, World.HEIGHT) * World.TILE_SIZE
	camera.zoom = Vector2.ONE * clampf(minf(available.x / dimensions.x, available.y / dimensions.y), 0.12, 2.5)
	camera.position = dimensions * 0.5 - Vector2(155, 0) / camera.zoom

func inspect_position(world_position: Vector2) -> void:
	var cell := Vector2i((world_position / World.TILE_SIZE).floor())
	if world.contains(cell):
		inspect(cell)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		focus_settlement()

func inspect(cell: Vector2i) -> void:
	selected = cell
	var tile: Dictionary = world.tile(cell)
	information.text = "TILE  %d : %d\n\nBiome: %s\nTerrain: %s\nElevation: %.2f\nMoisture: %.2f\nTemperature: %.2f\n\nRESOURCE POTENTIAL\n" % [cell.x, cell.y, World.BIOMES[tile.biome], tile.terrain_type, tile.elevation, tile.moisture, tile.temperature]
	for resource in World.RESOURCE_NAMES.size():
		information.text += "\n%s: %d / 5" % [World.RESOURCE_NAMES[resource], tile.resources[resource]]
	queue_redraw()

func _draw() -> void:
	if selected.x >= 0:
		draw_rect(Rect2(Vector2(selected) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color(0.9, 1, 0.97, 0.14))
		draw_rect(Rect2(Vector2(selected) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color("e5fff4"), false, 2.0)
