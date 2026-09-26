extends RefCounted

const BASE := [[2,0,0,0,0,0], [3,0,0,0,0,5], [3,0,1,0,0,5], [2,1,2,0,0,1], [5,1,1,0,0,1], [2,5,1,0,0,2], [0,0,5,4,0,0], [0,0,2,0,4,0], [2,2,0,0,1,4], [1,1,2,1,0,2]]

static func populate(world: RefCounted) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.world_seed + 809
	for tile in world.tiles:
		tile.terrain_type = "water" if tile.biome < 3 else ("impassable" if tile.biome == 6 else "land")
		tile.resources = BASE[tile.biome].duplicate()
		for resource in tile.resources.size():
			if tile.resources[resource] > 0:
				tile.resources[resource] = clampi(tile.resources[resource] + rng.randi_range(-1, 1), 0, 5)
		if tile.biome == 7 and rng.randf() > 0.25:
			tile.resources[4] = 0
