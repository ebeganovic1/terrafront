extends Control

signal navigated(world_position: Vector2)
const World = preload("res://scripts/world/world_data.gd")
var world: RefCounted
var terrain: Texture2D
var camera_rect := Rect2()
var region := Rect2()

func setup(value: RefCounted, texture: Texture2D) -> void:
	world = value
	terrain = texture
	var home: Vector2 = world.settlements[0].cell
	region = Rect2(home - Vector2(20, 20), Vector2(40, 40))
	for settlement in world.settlements:
		region = region.expand(Vector2(settlement.cell) - Vector2(20, 20))
		region = region.expand(Vector2(settlement.cell) + Vector2(20, 20))
	region = region.intersection(Rect2(0, 0, World.WIDTH, World.HEIGHT))
	queue_redraw()

func point(cell: Vector2) -> Vector2:
	return (cell - region.position) / region.size * size

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		navigated.emit((region.position + event.position / size * region.size) * World.TILE_SIZE)
		accept_event()

func _draw() -> void:
	if world == null or terrain == null:
		return
	draw_texture_rect_region(terrain, Rect2(Vector2.ZERO, size), region)
	for cell in world.ownership:
		if region.has_point(Vector2(cell)):
			draw_rect(Rect2(point(Vector2(cell)), size / region.size + Vector2.ONE), Color(0.15, 0.7, 0.65, 0.45) if world.ownership[cell] == 1 else Color(0.8, 0.25, 0.21, 0.5))
	for settlement in world.settlements:
		draw_circle(point(settlement.cell), 4, Color("e9e6cc") if settlement.owner_id == 1 else Color("b73737"))
	draw_rect(Rect2(point(camera_rect.position / World.TILE_SIZE), camera_rect.size / World.TILE_SIZE / region.size * size).intersection(Rect2(Vector2.ZERO, size)), Color("fff3bc"), false, 1)
