extends Node2D

const World = preload("res://scripts/world/world_data.gd")
var world: RefCounted
var ground: Sprite2D

func set_world(value: RefCounted) -> void:
	world = value
	if ground == null:
		ground = Sprite2D.new()
		ground.centered = false
		ground.z_index = -1
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(ground)
	var colors := Image.create(World.WIDTH, World.HEIGHT, false, Image.FORMAT_RGB8)
	for row in World.HEIGHT:
		for column in World.WIDTH:
			var cell := Vector2i(column, row)
			var tile: Dictionary = world.tile(cell)
			var color: Color = World.COLORS[tile.biome]
			var relief := 0.0
			if column > 0 and row > 0 and tile.biome >= 3:
				relief = (float(world.tile(cell - Vector2i.ONE).elevation) - float(tile.elevation)) * 0.45
			if tile.biome == 6:
				color = color.darkened(clampf((tile.elevation - 0.76) * 0.22, 0.0, 0.055))
			elif tile.biome == 5:
				color = color.darkened(clampf((tile.moisture - 0.51) * 0.08, 0.0, 0.03))
			elif tile.biome == 0:
				color = color.darkened((0.32 - tile.elevation) * 0.16)
			colors.set_pixel(column, row, color.lightened(clampf(relief, -0.025, 0.025)))
	ground.texture = ImageTexture.create_from_image(colors)
	ground.scale = Vector2.ONE * World.TILE_SIZE
	queue_redraw()
