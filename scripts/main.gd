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
	add_child(renderer)
	camera = StrategyCamera.new()
	add_child(camera)
	build_ui()
	regenerate(260926)

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(284, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14252a")
	style.border_color = Color("45635d")
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "T E R R A F R O N T"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("eace88"))
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
	column.add_child(HSeparator.new())
	information = Label.new()
	information.add_theme_font_size_override("font_size", 15)
	column.add_child(information)
	column.add_child(HSeparator.new())
	var controls := Label.new()
	controls.text = "WASD   Move camera\nWheel   Zoom at cursor\nMiddle drag   Pan\nLeft click   Inspect tile\n\nResources: 0 none / 5 abundant\nMountain and water: inaccessible"
	controls.add_theme_font_size_override("font_size", 13)
	column.add_child(controls)

func regenerate(seed_value: int) -> void:
	world = Generator.new().generate(seed_value)
	renderer.world = world
	renderer.queue_redraw()
	status.text = "SEED %d  /  160 x 112 TILES" % seed_value
	camera.zoom = Vector2.ONE * 0.85
	focus_settlement()
	inspect(world.settlements[0].cell)

func focus_settlement() -> void:
	if world != null:
		camera.position = Vector2(world.settlements[0].cell) * World.TILE_SIZE + Vector2(8, 8)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := get_global_mouse_position() / World.TILE_SIZE
		var cell := Vector2i(floori(mouse.x), floori(mouse.y))
		if world.contains(cell):
			inspect(cell)
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
		draw_rect(Rect2(Vector2(selected) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color("fff1bd"), false, 2.0)
