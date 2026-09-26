extends Node2D

const World = preload("res://scripts/world/world_data.gd")
var world: RefCounted
var elapsed := 0.0
var refresh_time := 0.0
var routes: Array[Dictionary] = []

func advance(delta: float) -> void:
	elapsed += delta
	refresh_time -= delta
	if refresh_time <= 0:
		refresh_time = 0.8
		routes.clear()
		for battle in world.battles:
			for owner in [battle.owner, battle.defender]:
				var target: Vector2i = battle.target
				if world.ownership.get(target, 0) != owner:
					for neighbor in world.neighbors(target):
						if world.ownership.get(neighbor, 0) == owner:
							target = neighbor
							break
				var path := route(owner, target)
				var soldiers: int = battle.troops if owner == battle.owner else world.armies[owner].troops
				if path.size() >= 2 and soldiers > 0:
					routes.append({"owner": owner, "path": path, "count": mini(soldiers, 24)})
	queue_redraw()

func route(owner: int, target: Vector2i) -> Array[Vector2]:
	var start := Vector2i(-1, -1)
	for building in world.buildings:
		if building.owner_id == owner and building.kind == "barracks" and building.get("remaining", 0.0) <= 0:
			start = building.cell
			break
	if start.x < 0:
		return []
	var queue: Array[Vector2i] = [start]
	var parents := {start: start}
	var cursor := 0
	while cursor < queue.size() and not parents.has(target):
		var cell := queue[cursor]
		cursor += 1
		for neighbor in world.neighbors(cell):
			if world.ownership.get(neighbor, 0) == owner and not parents.has(neighbor):
				parents[neighbor] = cell
				queue.append(neighbor)
	var result: Array[Vector2] = []
	if not parents.has(target):
		return result
	var cell := target
	while cell != start:
		result.append((Vector2(cell) + Vector2.ONE * 0.5) * World.TILE_SIZE)
		cell = parents[cell]
	result.append((Vector2(start) + Vector2.ONE * 0.5) * World.TILE_SIZE)
	result.reverse()
	return result

func _draw() -> void:
	for trail in routes:
		var path: Array = trail.path
		var length: float = (path.size() - 1) * World.TILE_SIZE
		for index in trail.count:
			var distance := fposmod(elapsed * 36.0 + index * length / trail.count, length)
			var segment := mini(floori(distance / World.TILE_SIZE), path.size() - 2)
			var position: Vector2 = path[segment].lerp(path[segment + 1], fmod(distance, World.TILE_SIZE) / World.TILE_SIZE)
			draw_circle(position + Vector2(1, 2), 2.8, Color(0.05, 0.1, 0.12, 0.55))
			draw_circle(position, 2.0, Color("e5efca") if trail.owner == 1 else Color("dc7a65"))
