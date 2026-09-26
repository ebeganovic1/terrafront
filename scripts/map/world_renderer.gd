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
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(ground)
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/terrain.gdshader")
		ground.material = material
	var colors := Image.create(World.WIDTH, World.HEIGHT, false, Image.FORMAT_RGB8)
	for row in World.HEIGHT:
		for column in World.WIDTH:
			var cell := Vector2i(column, row)
			var tile: Dictionary = world.tile(cell)
			var color: Color = World.COLORS[tile.biome]
			var relief := 0.0
			if column > 0 and row > 0 and tile.biome >= 3:
				relief = (float(world.tile(cell - Vector2i.ONE).elevation) - float(tile.elevation)) * 1.7
			if tile.biome == 0:
				color = color.darkened((0.32 - tile.elevation) * 0.55)
			colors.set_pixel(column, row, color.lightened(clampf(relief, -0.12, 0.12)))
	ground.texture = ImageTexture.create_from_image(colors)
	ground.scale = Vector2.ONE * World.TILE_SIZE
	queue_redraw()

func _draw() -> void:
	if world == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world.world_seed + 1103
	for row in World.HEIGHT:
		for column in World.WIDTH:
			var tile: Dictionary = world.tile(Vector2i(column, row))
			var origin := Vector2(column, row) * World.TILE_SIZE
			var center := origin + Vector2(24, 24)
			match tile.biome:
				5:
					for tree in 3:
						var point := origin + Vector2(rng.randf_range(9, 39), 9 + tree * 12)
						var radius := rng.randf_range(5.0, 8.0)
						draw_circle(point + Vector2(3, 4), radius + 1, Color(0.12, 0.24, 0.22, 0.18), true, -1, true)
						draw_line(point, point + Vector2(0, 8), Color("5b6e58"), 2, true)
						draw_circle(point, radius, Color("3e705b").lightened(rng.randf_range(0, 0.15)), true, -1, true)
						draw_circle(point + Vector2(-2, -2), radius * 0.6, Color("78a27c"), true, -1, true)
				6:
					if rng.randf() < 0.2:
						continue
					center += Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8))
					var span := rng.randf_range(13, 23)
					var peak := center + Vector2(rng.randf_range(-5, 5), -span)
					var left := center + Vector2(-span, 12)
					var right := center + Vector2(span, 12)
					draw_colored_polygon(PackedVector2Array([left, peak, right]), Color("adb6ac"))
					draw_colored_polygon(PackedVector2Array([peak, center + Vector2(1, 15), right]), Color("798b86"))
					draw_colored_polygon(PackedVector2Array([peak, peak.lerp(left, 0.32), peak + Vector2(1, 7), peak.lerp(right, 0.32)]), Color("e1e8df"))
				0, 1:
					if (column + row * 3) % 4 == 0:
						draw_polyline(PackedVector2Array([center + Vector2(-9, 1), center + Vector2(-3, 0), center + Vector2(3, 1), center + Vector2(9, 0)]), Color(0.65, 0.88, 0.93, 0.16), 1.2, true)
				7:
					if (column + row) % 3 == 0:
						draw_polyline(PackedVector2Array([center + Vector2(-14, 4), center + Vector2(-5, 0), center + Vector2(5, -1), center + Vector2(15, 2)]), Color(0.7, 0.54, 0.32, 0.23), 1.4, true)
				4, 8:
					if rng.randf() < 0.35:
						draw_line(center + Vector2(-3, 3), center + Vector2(-1, -2), Color(0.3, 0.46, 0.33, 0.25), 1, true)
						draw_line(center + Vector2(2, 3), center + Vector2(3, 0), Color(0.3, 0.46, 0.33, 0.25), 1, true)
	for settlement in world.settlements:
		var center: Vector2 = (Vector2(settlement.cell) + Vector2.ONE * 0.5) * World.TILE_SIZE
		draw_circle(center, 28, Color(0.1, 0.2, 0.24, 0.2), true, -1, true)
		draw_arc(center, 26, 0, TAU, 48, Color("effaf5"), 2, true)
		draw_rect(Rect2(center + Vector2(-12, -4), Vector2(24, 19)), Color("edf0e6"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(-16, -3), center + Vector2(0, -17), center + Vector2(16, -3)]), Color("456e7d"))
		draw_rect(Rect2(center + Vector2(-3, 5), Vector2(6, 10)), Color("477467"))
		draw_line(center + Vector2(17, -6), center + Vector2(17, -29), Color("effaf5"), 2, true)
		draw_colored_polygon(PackedVector2Array([center + Vector2(18, -29), center + Vector2(31, -25), center + Vector2(18, -20)]), Color("75dbbe"))
