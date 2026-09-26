extends Node2D

const World = preload("res://scripts/world/world_data.gd")
const Art = preload("res://scripts/ui/building_art.gd")
const Design = preload("res://scripts/ui/design.gd")
var world: RefCounted

func _draw() -> void:
	if world == null:
		return
	var size := float(World.TILE_SIZE)
	for cell in world.ownership:
		var origin := Vector2(cell) * size
		var color := Design.BLUE if world.ownership[cell] == 1 else Design.RED
		draw_rect(Rect2(origin, Vector2.ONE * size), Color(color, 0.10))
		var offsets := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		var corners := [Vector2.ZERO, Vector2(size, 0), Vector2(size, size), Vector2(0, size)]
		for edge in 4:
			if world.ownership.get(cell + offsets[edge], 0) != world.ownership[cell]:
				draw_line(origin + corners[edge], origin + corners[(edge + 1) % 4], color, 3.0)
	for building in world.buildings:
		var bounds := Rect2(Vector2(building.cell) * size, Vector2.ONE * size * 2)
		var remaining: float = building.get("remaining", 0.0)
		draw_texture_rect(Art.icon(building.kind), bounds, false, Color(1, 1, 1, 0.45) if remaining > 0 else Color.WHITE)
		if remaining > 0:
			draw_rect(Rect2(bounds.position + Vector2(0, 30), Vector2(32, 3)), Design.OUTLINE)
			draw_rect(Rect2(bounds.position + Vector2(0, 30), Vector2(32 * (1.0 - remaining / building.duration), 3)), Design.GOLD)
			draw_string(Design.stat(), bounds.position + Vector2(3, -3), "%ds" % ceili(remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Design.CREAM)
		if building.status.begins_with("Stopped"):
			draw_circle(bounds.position + Vector2(28, 3), 3, Design.GOLD)
	for cell in world.walls:
		var owner: int = world.walls[cell]
		var origin := Vector2(cell) * size
		var offsets := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		var corners := [Vector2.ZERO, Vector2(size, 0), Vector2(size, size), Vector2(0, size)]
		for edge in 4:
			if offsets[edge] in world.wall_edges.get(cell, offsets):
				draw_line(origin + corners[edge], origin + corners[(edge + 1) % 4], Design.OUTLINE, 6)
				draw_line(origin + corners[edge], origin + corners[(edge + 1) % 4], Design.STIJENA[2] if owner == 1 else Design.RED, 3)
				draw_circle(origin + corners[edge], 3, Design.STIJENA[3])
		if world.ownership.get(cell, 0) == owner:
			draw_circle(origin + Vector2.ONE * size * 0.5, 2, Design.STIJENA[2])
	for job in world.wall_jobs:
		for cell in job.cells:
			draw_rect(Rect2(Vector2(cell) * size, Vector2.ONE * size), Color(0.9, 0.8, 0.5, 0.35))
		draw_string(Design.stat(), Vector2(job.cells[0]) * size, "%ds" % ceili(job.remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Design.CREAM)
	for job in world.expansions:
		if not job.cells.is_empty():
			draw_rect(Rect2(Vector2(job.cells[0]) * size, Vector2.ONE * size), Design.GOLD, false, 2)
	for settlement in world.settlements:
		var bounds := Rect2(Vector2(settlement.cell) * size, Vector2.ONE * size * 2)
		draw_texture_rect(Art.icon("capital"), bounds, false)
		draw_line(bounds.position, bounds.position + Vector2(32, 0), Design.BLUE if settlement.owner_id == 1 else Design.RED, 3)
	for battle in world.battles:
		for cell in battle.get("front", []):
			draw_rect(Rect2(Vector2(cell) * size, Vector2.ONE * size), Color(0.95, 0.65, 0.3, 0.35))
		var center := (Vector2(battle.target) + Vector2.ONE * 0.5) * size
		draw_arc(center, 15, 0, TAU, 32, Design.GOLD, 3, true)
		draw_string(Design.stat(), center + Vector2(18, 4), str(battle.troops), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Design.CREAM)
