extends RefCounted

const World = preload("res://scripts/world/world_data.gd")
const Resources = preload("res://scripts/systems/resource_system.gd")
const Drainage = preload("res://scripts/world/drainage.gd")

func noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var field := FastNoiseLite.new()
	field.seed = seed_value
	field.frequency = frequency
	field.fractal_octaves = 4
	return field

func generate(seed_value: int) -> RefCounted:
	var world := World.new()
	world.world_seed = seed_value
	var elevation := noise(seed_value, 0.027)
	var moisture := noise(seed_value + 101, 0.039)
	var temperature := noise(seed_value + 203, 0.021)
	for row in World.HEIGHT:
		for column in World.WIDTH:
			var latitude := absf(float(row) / (World.HEIGHT - 1) * 2.0 - 1.0)
			var position := Vector2(float(column) / (World.WIDTH - 1) * 2.0 - 1.0, float(row) / (World.HEIGHT - 1) * 2.0 - 1.0)
			var height := clampf(0.83 - position.length_squared() * 0.55 + elevation.get_noise_2d(column, row) * 0.43, 0.0, 1.0)
			var wetness := clampf(0.5 + moisture.get_noise_2d(column, row) * 0.85, 0.0, 1.0)
			var warmth := clampf(1.0 - latitude * 0.95 - height * 0.18 + temperature.get_noise_2d(column, row) * 0.3, 0.0, 1.0)
			var biome := 4
			if height < 0.32:
				biome = 1
			elif height > 0.76:
				biome = 6
			elif warmth < 0.27:
				biome = 9
			elif height < 0.36:
				biome = 3
			elif wetness > 0.65 and height < 0.48:
				biome = 8
			elif wetness < 0.43 and warmth > 0.58:
				biome = 7
			elif wetness > 0.51:
				biome = 5
			world.tiles.append({"biome": biome, "elevation": height, "moisture": wetness, "temperature": warmth, "terrain_type": "", "resources": []})
	classify_ocean(world)
	add_lakes(world, seed_value)
	add_rivers(world, seed_value)
	Resources.populate(world)
	place_settlement(world)
	return world

func classify_ocean(world: RefCounted) -> void:
	var queue: Array[Vector2i] = []
	for row in World.HEIGHT:
		for column in World.WIDTH:
			if row == 0 or column == 0 or row == World.HEIGHT - 1 or column == World.WIDTH - 1:
				var cell := Vector2i(column, row)
				if world.tile(cell).biome == 1:
					world.tile(cell).biome = 0
					queue.append(cell)
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for next in world.neighbors(cell):
			if world.tile(next).biome == 1:
				world.tile(next).biome = 0
				queue.append(next)

func add_lakes(world: RefCounted, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 401
	var centers: Array[Vector2i] = []
	for attempt in 500:
		if centers.size() >= 5:
			break
		var center := Vector2i(rng.randi_range(25, World.WIDTH - 26), rng.randi_range(20, World.HEIGHT - 21))
		if not world.walkable(center):
			continue
		var valid := true
		for previous in centers:
			if Vector2(center - previous).length() < 15:
				valid = false
		for vertical in range(-5, 6):
			for horizontal in range(-5, 6):
				if world.tile(center + Vector2i(horizontal, vertical)).biome in [0, 1, 6]:
					valid = false
		if not valid:
			continue
		centers.append(center)
		var surface: float = world.tile(center).elevation - 0.03
		for vertical in range(-3, 4):
			for horizontal in range(-4, 5):
				if pow(float(horizontal) / 4.0, 2) + pow(float(vertical) / 3.0, 2) < rng.randf_range(0.7, 1.1):
					var lake: Dictionary = world.tile(center + Vector2i(horizontal, vertical))
					lake.biome = 1
					lake.elevation = surface

func add_rivers(world: RefCounted, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 607
	var downstream := Drainage.new().build(world)
	for attempt in 1500:
		if world.river_paths.size() >= 9:
			break
		var cell := Vector2i(rng.randi_range(10, World.WIDTH - 11), rng.randi_range(10, World.HEIGHT - 11))
		if world.tile(cell).elevation < 0.69 or world.tile(cell).biome in [0, 1, 2]:
			continue
		var near_source := false
		for existing in world.river_paths:
			if Vector2(cell - existing[0]).length() < 12:
				near_source = true
		if near_source:
			continue
		var path: Array[Vector2i] = []
		var new_land := 0
		for step in world.tiles.size():
			path.append(cell)
			if world.tile(cell).biome == 0:
				break
			if world.tile(cell).biome >= 3:
				new_land += 1
			var next_index: int = downstream[world.index(cell)]
			assert(next_index >= 0, "Land must have an ocean drainage route")
			cell = Vector2i(next_index % World.WIDTH, int(next_index / World.WIDTH))
		if new_land < 12 or world.tile(path.back()).biome != 0:
			continue
		for river_cell in path:
			if world.tile(river_cell).biome >= 3:
				world.tile(river_cell).biome = 2
		world.river_paths.append(path)

func place_settlement(world: RefCounted) -> void:
	var best := Vector2i(-1, -1)
	var best_score := -1.0
	for row in range(4, World.HEIGHT - 4):
		for column in range(4, World.WIDTH - 4):
			var cell := Vector2i(column, row)
			if world.tile(cell).biome != 4:
				continue
			var types := {}
			for vertical in range(-3, 4):
				for horizontal in range(-3, 4):
					types[world.tile(cell + Vector2i(horizontal, vertical)).biome] = true
			var score := float(types.size()) - Vector2(cell - Vector2i(80, 56)).length() * 0.005
			if score > best_score:
				best_score = score
				best = cell
	if best.x < 0:
		for row in World.HEIGHT:
			for column in World.WIDTH:
				var cell := Vector2i(column, row)
				if best.x < 0 and world.walkable(cell):
					best = cell
	assert(world.walkable(best), "World has no valid settlement position")
	world.settlements.append({"id": 1, "owner_id": 1, "cell": best})
