extends RefCounted

const WIDTH := 160
const HEIGHT := 112
const TILE_SIZE := 48
const BIOMES := ["Sea", "Lake", "River", "Coast", "Plains", "Forest", "Mountain", "Desert", "Swamp", "Snow"]
const COLORS := [Color("7296ad"), Color("82a9b9"), Color("82a9b9"), Color("d4d5b8"), Color("b7c8a6"), Color("98b18d"), Color("a9b0a8"), Color("d6caaa"), Color("a2b9a1"), Color("e2e7de")]
const RESOURCE_NAMES := ["Food", "Wood", "Stone", "Iron", "Oil", "Water"]
var world_seed: int
var tiles: Array[Dictionary] = []
var settlements: Array[Dictionary] = []

func index(cell: Vector2i) -> int:
	return cell.y * WIDTH + cell.x

func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < HEIGHT

func tile(cell: Vector2i) -> Dictionary:
	return tiles[index(cell)]

func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next: Vector2i = cell + offset
		if contains(next):
			result.append(next)
	return result

func walkable(cell: Vector2i) -> bool:
	return contains(cell) and tile(cell).biome in [3, 4, 5, 7, 8, 9]
