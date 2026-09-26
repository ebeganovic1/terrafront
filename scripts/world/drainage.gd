extends RefCounted

const World = preload("res://scripts/world/world_data.gd")
var frontier: Array[Vector2] = []

func build(world: RefCounted) -> PackedInt32Array:
	frontier.clear()
	var downstream := PackedInt32Array()
	downstream.resize(world.tiles.size())
	downstream.fill(-2)
	for index in world.tiles.size():
		if world.tiles[index].biome == 0:
			downstream[index] = -1
			push(Vector2(world.tiles[index].elevation, index))
	while not frontier.is_empty():
		var current := pop()
		var index := int(current.y)
		var cell := Vector2i(index % World.WIDTH, int(index / World.WIDTH))
		for neighbor in world.neighbors(cell):
			var neighbor_index: int = world.index(neighbor)
			if downstream[neighbor_index] != -2:
				continue
			downstream[neighbor_index] = index
			var spill_height := maxf(world.tiles[neighbor_index].elevation, current.x + 0.00001)
			push(Vector2(spill_height, neighbor_index))
	return downstream

func push(entry: Vector2) -> void:
	frontier.append(entry)
	var index := frontier.size() - 1
	while index > 0:
		var parent := int((index - 1) / 2)
		if frontier[parent].x <= entry.x:
			break
		frontier[index] = frontier[parent]
		index = parent
	frontier[index] = entry

func pop() -> Vector2:
	var result := frontier[0]
	var tail: Vector2 = frontier.pop_back()
	if frontier.is_empty():
		return result
	var index := 0
	while index * 2 + 1 < frontier.size():
		var child := index * 2 + 1
		if child + 1 < frontier.size() and frontier[child + 1].x < frontier[child].x:
			child += 1
		if tail.x <= frontier[child].x:
			break
		frontier[index] = frontier[child]
		index = child
	frontier[index] = tail
	return result
