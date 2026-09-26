extends RefCounted

const WIDTH := 160
const HEIGHT := 112
const TILE_SIZE := 16
const BIOMES := ["Sea", "Lake", "River", "Coast", "Plains", "Forest", "Mountain", "Desert", "Swamp", "Snow"]
const COLORS := [Color("183d59"), Color("327f9e"), Color("52afbf"), Color("c4b784"), Color("80935c"), Color("355f4a"), Color("7c8182"), Color("d0ac6b"), Color("546f62"), Color("c4d6d5")]
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
