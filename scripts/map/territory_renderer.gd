extends Node2D

const World = preload("res://scripts/world/world_data.gd")
const LABELS := {"farm": "F", "lumber": "L", "quarry": "Q", "mine": "I", "well": "W", "house": "H", "oil": "O"}
var world: RefCounted

func _draw() -> void:
	if world == null:
		return
	var size := float(World.TILE_SIZE)
	for cell in world.ownership:
		var origin := Vector2(cell) * size
		draw_rect(Rect2(origin, Vector2.ONE * size), Color(0.15, 0.65, 0.53, 0.14))
		var offsets := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		var corners := [Vector2.ZERO, Vector2(size, 0), Vector2(size, size), Vector2(0, size)]
		for edge in 4:
			if world.ownership.get(cell + offsets[edge], 0) != world.ownership[cell]:
				draw_line(origin + corners[edge], origin + corners[(edge + 1) % 4], Color("247969"), 2.5)
	for building in world.buildings:
		var center := (Vector2(building.cell) + Vector2.ONE * 0.5) * size
		draw_rect(Rect2(center - Vector2(8, 8), Vector2(16, 16)), Color("f3f7ee"))
		draw_rect(Rect2(center - Vector2(8, 8), Vector2(16, 16)), Color("285d59"), false, 1.5)
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 5), LABELS[building.kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("244e49"))
