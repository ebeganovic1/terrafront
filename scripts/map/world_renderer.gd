extends Node2D

const World = preload("res://scripts/world/world_data.gd")
var world: RefCounted

func _draw() -> void:
	if world == null:
		return
	for row in World.HEIGHT:
		for column in World.WIDTH:
			var tile: Dictionary = world.tile(Vector2i(column, row))
			var origin := Vector2(column, row) * World.TILE_SIZE
			var variation := float((column * 13 + row * 7) % 7 - 3) * 0.009
			var color: Color = World.COLORS[tile.biome]
			draw_rect(Rect2(origin, Vector2.ONE * World.TILE_SIZE), color.lightened(variation))
			match tile.biome:
				5:
					draw_rect(Rect2(origin + Vector2(7, 9), Vector2(2, 5)), Color("454d37"))
					draw_rect(Rect2(origin + Vector2(4, 4), Vector2(8, 7)), Color("244b3d"))
					draw_rect(Rect2(origin + Vector2(6, 2), Vector2(4, 4)), Color("477854"))
				6:
					draw_colored_polygon(PackedVector2Array([origin + Vector2(2, 13), origin + Vector2(8, 2), origin + Vector2(14, 13)]), Color("a0a5a0"))
					draw_line(origin + Vector2(8, 4), origin + Vector2(12, 12), Color("535f65"), 2)
				0, 1:
					if (column + row * 3) % 5 == 0:
						draw_rect(Rect2(origin + Vector2(4, 8), Vector2(6, 1)), color.lightened(0.08))
				7:
					if (column + row) % 3 == 0:
						draw_rect(Rect2(origin + Vector2(3, 9), Vector2(9, 1)), color.darkened(0.1))
	for settlement in world.settlements:
		var center: Vector2 = Vector2(settlement.cell) * World.TILE_SIZE + Vector2(8, 8)
		draw_rect(Rect2(center - Vector2(12, 12), Vector2(24, 24)), Color("eace88"), false, 2)
		draw_rect(Rect2(center - Vector2(5, 3), Vector2(10, 9)), Color("eee7c8"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(-7, -3), center + Vector2(0, -10), center + Vector2(7, -3)]), Color("b65d4f"))
