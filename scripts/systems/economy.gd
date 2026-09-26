extends RefCounted

const World = preload("res://scripts/world/world_data.gd")
const TICK_SECONDS := 5.0
const BUILD_SECONDS := {"well": 6.0, "farm": 10.0, "lumber": 10.0, "house": 12.0, "barracks": 18.0, "fort": 15.0, "quarry": 14.0, "mine": 20.0, "oil": 24.0}
const NAMES := ["Money", "Food", "Wood", "Stone", "Iron", "Oil", "Water"]
const DEFINITIONS := {
	"barracks": {"name": "Barracks", "cost": {"Money": 100, "Wood": 30, "Stone": 15}, "inputs": {}, "resource": "", "base": 0, "workers": 2, "biomes": [3, 4, 5, 7, 8, 9], "potential": -1},
	"fort": {"name": "Fort", "cost": {"Money": 90, "Wood": 15, "Stone": 35}, "inputs": {}, "resource": "", "base": 0, "workers": 0, "biomes": [3, 4, 5, 6, 7, 8, 9], "potential": -1},
	"farm": {"name": "Farm", "cost": {"Money": 60, "Wood": 20, "Stone": 10}, "inputs": {"Money": 2, "Water": 2}, "resource": "Food", "base": 3, "workers": 2, "biomes": [4], "potential": 0},
	"lumber": {"name": "Lumber camp", "cost": {"Money": 50, "Wood": 10}, "inputs": {"Money": 2, "Food": 1}, "resource": "Wood", "base": 3, "workers": 2, "biomes": [5], "potential": 1},
	"quarry": {"name": "Quarry", "cost": {"Money": 65, "Wood": 20}, "inputs": {"Money": 3, "Food": 1}, "resource": "Stone", "base": 3, "workers": 2, "biomes": [6], "potential": 2},
	"mine": {"name": "Iron mine", "cost": {"Money": 100, "Wood": 30, "Stone": 25}, "inputs": {"Money": 4, "Food": 1, "Water": 1}, "resource": "Iron", "base": 2, "workers": 3, "biomes": [6], "potential": 3},
	"well": {"name": "Well", "cost": {"Money": 40, "Wood": 15, "Stone": 10}, "inputs": {"Money": 1}, "resource": "Water", "base": 6, "workers": 1, "biomes": [3, 4, 5, 7, 8, 9], "potential": 5},
	"house": {"name": "Housing", "cost": {"Money": 80, "Wood": 25, "Stone": 20}, "inputs": {}, "resource": "", "base": 0, "workers": 0, "biomes": [3, 4, 5, 7, 8, 9], "potential": -1},
	"oil": {"name": "Oil pump", "cost": {"Money": 150, "Wood": 30, "Stone": 40, "Iron": 20}, "inputs": {"Money": 5, "Water": 2}, "resource": "Oil", "base": 2, "workers": 3, "biomes": [7], "potential": 4}
}
const SELL_PRICE := {"Food": 2, "Wood": 3, "Stone": 3, "Iron": 6, "Oil": 8, "Water": 1}
const ORDER := ["well", "farm", "lumber", "quarry", "mine", "oil", "house", "barracks", "fort"]

func initialize(world: RefCounted, player_id: int = 1) -> void:
	world.players[player_id] = {"stock": {"Money": 350, "Food": 60, "Wood": 80, "Stone": 60, "Iron": 0, "Oil": 0, "Water": 50}, "population": 12, "workers": 0, "delta": {}, "warning": ""}
	var center := Vector2i.ZERO
	for settlement in world.settlements:
		if settlement.owner_id == player_id:
			center = settlement.cell
			break
	var queue: Array[Vector2i] = [center]
	world.ownership[center] = player_id
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for neighbor in world.neighbors(cell):
			if world.tile(neighbor).biome < 3 or world.ownership.has(neighbor):
				continue
			if absi(neighbor.x - center.x) + absi(neighbor.y - center.y) > 10:
				continue
			world.ownership[neighbor] = player_id
			queue.append(neighbor)

func territory_size(world: RefCounted, player_id: int) -> int:
	var count := 0
	for owner in world.ownership.values():
		if owner == player_id:
			count += 1
	return count

func building_at(world: RefCounted, cell: Vector2i) -> Dictionary:
	for building in world.buildings:
		if cell in footprint(building.cell):
			return building
	return {}

func footprint(cell: Vector2i) -> Array[Vector2i]:
	return [cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.ONE]

func capital_at(world: RefCounted, cell: Vector2i) -> int:
	for settlement in world.settlements:
		if cell in footprint(settlement.cell):
			return settlement.owner_id
	return 0

func boundary(world: RefCounted, owner: int, cell: Vector2i) -> bool:
	if world.ownership.get(cell, 0) != owner:
		return false
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if world.ownership.get(cell + offset, 0) != owner:
			return true
	return false

func wall_cells(world: RefCounted, owner: int, cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var queue: Array[Vector2i] = [cell]
	var visited := {cell: true}
	while not queue.is_empty() and result.size() < 5:
		var next: Vector2i = queue.pop_front()
		if not boundary(world, owner, next) or wall_reserved(world, next) or not building_at(world, next).is_empty() or capital_at(world, next) != 0:
			continue
		result.append(next)
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			if not visited.has(next + offset):
				visited[next + offset] = true
				queue.append(next + offset)
	return result

func wall_reserved(world: RefCounted, cell: Vector2i) -> bool:
	if world.walls.has(cell):
		return true
	for job in world.wall_jobs:
		if cell in job.cells:
			return true
	return false

func advance_construction(world: RefCounted, delta: float) -> bool:
	if world.winner != 0:
		return false
	var changed := false
	for building in world.buildings:
		if building.get("remaining", 0.0) <= 0:
			continue
		building.remaining = maxf(0, building.remaining - delta)
		changed = true
		if building.remaining == 0:
			building.status = "Ready"
			if building.kind == "house":
				world.players[building.owner_id].population += 4
	for index in range(world.wall_jobs.size() - 1, -1, -1):
		var job: Dictionary = world.wall_jobs[index]
		job.remaining = maxf(0, job.remaining - delta)
		changed = true
		var valid := true
		for cell in job.cells:
			valid = valid and world.ownership.get(cell, 0) == job.owner
		if not valid:
			world.wall_jobs.remove_at(index)
		elif job.remaining == 0:
			for cell in job.cells:
				world.walls[cell] = job.owner
				world.wall_edges[cell] = job.edges[cell]
			world.wall_jobs.remove_at(index)
	return changed

func advance_expansion(world: RefCounted, delta: float) -> bool:
	if world.winner != 0:
		return false
	var changed := false
	for index in range(world.expansions.size() - 1, -1, -1):
		var job: Dictionary = world.expansions[index]
		job.elapsed += delta
		while job.elapsed >= 0.15 and not job.cells.is_empty():
			job.elapsed -= 0.15
			var cell: Vector2i = job.cells.pop_front()
			var connected := false
			for neighbor in world.neighbors(cell):
				connected = connected or world.ownership.get(neighbor, 0) == job.owner
			if connected and not world.ownership.has(cell) and world.tile(cell).biome >= 3:
				world.ownership[cell] = job.owner
				job.claimed += 1
				changed = true
		if job.cells.is_empty():
			for resource in job.cost:
				world.players[job.owner].stock[resource] += floori(job.cost[resource] * float(job.total - job.claimed) / job.total)
			world.expansions.remove_at(index)
			changed = true
	return changed

func affordable(stock: Dictionary, cost: Dictionary) -> bool:
	for resource in cost:
		if stock.get(resource, 0) < cost[resource]:
			return false
	return true

func transfer(stock: Dictionary, amounts: Dictionary, sign_value: int) -> void:
	for resource in amounts:
		stock[resource] += amounts[resource] * sign_value

func missing_inputs(stock: Dictionary, inputs: Dictionary) -> Dictionary:
	var missing := {}
	for resource in inputs:
		var shortage: int = inputs[resource] - stock.get(resource, 0)
		if shortage > 0:
			missing[resource] = shortage
	return missing

func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for resource in cost:
		parts.append("%d %s" % [cost[resource], resource])
	return ", ".join(parts) if not parts.is_empty() else "none"

func claim_cells(world: RefCounted, player_id: int, target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not world.contains(target) or world.tile(target).biome < 3:
		return result
	var radial: bool = world.ownership.get(target, 0) == player_id
	if world.ownership.has(target) and not radial:
		return result
	var frontier := {}
	if radial:
		for owned in world.ownership:
			if world.ownership[owned] == player_id:
				for neighbor in world.neighbors(owned):
					if not world.ownership.has(neighbor) and world.tile(neighbor).biome >= 3:
						frontier[neighbor] = growth_cost(world, neighbor)
	else:
		for neighbor in world.neighbors(target):
			if world.ownership.get(neighbor, 0) == player_id:
				frontier[target] = 0.0
				break
	var visited := {}
	var budget: int = clampi(world.players[player_id].get("expansion_budget", 40), 20, 80)
	while not frontier.is_empty() and result.size() < budget:
		var chosen := Vector2i(-1, -1)
		var lowest := INF
		for candidate in frontier:
			if frontier[candidate] < lowest:
				lowest = frontier[candidate]
				chosen = candidate
		frontier.erase(chosen)
		visited[chosen] = true
		result.append(chosen)
		for neighbor in world.neighbors(chosen):
			if visited.has(neighbor) or world.ownership.has(neighbor) or world.tile(neighbor).biome < 3:
				continue
			var cost := lowest + growth_cost(world, neighbor)
			if cost < frontier.get(neighbor, INF):
				frontier[neighbor] = cost
	return result

func growth_cost(world: RefCounted, cell: Vector2i) -> float:
	var terrain: int = world.tile(cell).biome
	var noise := sin(cell.x * 0.47 + cell.y * 0.21 + world.world_seed * 0.001) + cos(cell.y * 0.39 - cell.x * 0.17)
	return 1.2 + noise * 0.28 + (0.8 if terrain == 6 else 0.35 if terrain in [5, 8] else 0.0)

func construction_cost(world: RefCounted, player_id: int, kind: String) -> Dictionary:
	var counts: Dictionary = world.players[player_id].get("construction_counts", {})
	var built: int = counts.get(kind, 0)
	var cost: Dictionary = DEFINITIONS[kind].cost.duplicate()
	for resource in cost:
		cost[resource] = ceili(cost[resource] * (1.0 + built * 0.1))
	return cost

func quote(world: RefCounted, player_id: int, action: String, cell: Vector2i) -> Dictionary:
	var result := {"ok": false, "reason": "Select an action and a tile.", "cost": {}, "cells": [], "output": 0, "detail": ""}
	if not world.players.has(player_id) or not world.contains(cell):
		return result
	if world.winner != 0:
		result.reason = "Partija je završena."
		return result
	var player: Dictionary = world.players[player_id]
	if action == "expand":
		for job in world.expansions:
			if job.owner == player_id:
				result.reason = "Širenje traje · sačekaj završetak."
				return result
		var cells := claim_cells(world, player_id, cell)
		if cells.is_empty():
			result.reason = "Choose unclaimed land touching your border. Water cannot be claimed."
			return result
		result.cells = cells
		result.cost = {"Money": 12 + cells.size() + int(territory_size(world, player_id) / 150), "Wood": ceili(cells.size() / 12.0), "Food": ceili(cells.size() / 10.0)}
		result.detail = "Claim %d connected tiles. No territory upkeep." % cells.size()
	elif action == "fort":
		result.cost = construction_cost(world, player_id, action)
		result.cells = wall_cells(world, player_id, cell)
		if result.cells.size() != 5:
			result.reason = "Odaberi svoju granicu: treba 5 povezanih slobodnih rubnih polja."
			return result
		result.detail = "Zid prati 5 rubnih polja · odbrana +8 na tim poljima."
	elif DEFINITIONS.has(action):
		var definition: Dictionary = DEFINITIONS[action]
		result.cost = construction_cost(world, player_id, action)
		if player.population - player.workers < definition.workers:
			result.reason = "Not enough workers. Izgradi kuće za dodatne radnike."
			return result
		if world.ownership.get(cell, 0) != player_id:
			result.reason = "Build only inside your territory. Expand first."
			return result
		for occupied in footprint(cell):
			if not world.contains(occupied) or world.ownership.get(occupied, 0) != player_id or world.tile(occupied).biome < 3:
				result.reason = "Treba slobodan prostor 2×2 na vlastitom kopnu."
				return result
			if not building_at(world, occupied).is_empty() or capital_at(world, occupied) != 0 or wall_reserved(world, occupied):
				result.reason = "This tile is already occupied."
				return result
		var tile: Dictionary = world.tile(cell)
		if tile.biome not in definition.biomes:
			result.reason = "Wrong terrain for %s." % definition.name
			return result
		if definition.potential >= 0:
			var potential: int = tile.resources[definition.potential]
			if action == "well":
				for neighbor in world.neighbors(cell):
					if world.tile(neighbor).biome in [1, 2]:
						potential = maxi(potential, 4)
			if potential <= 0:
				result.reason = "No %s deposit here. Choose a richer tile." % definition.resource
				return result
			result.output = definition.base + potential
		result.detail = "+4 population, +3 tax; more food and water needed." if action == "house" else "+%d %s / 5s | Upkeep: %s" % [result.output, definition.resource, cost_text(definition.inputs)]
	else:
		return result
	if not affordable(player.stock, result.cost):
		result.missing = missing_inputs(player.stock, result.cost)
		result.reason = "Not enough resources. Need: " + cost_text(result.cost)
		return result
	result.ok = true
	result.reason = result.detail
	return result

func execute(world: RefCounted, player_id: int, action: String, cell: Vector2i) -> Dictionary:
	var result := quote(world, player_id, action, cell)
	if not result.ok:
		return result
	world.war_started = true
	var player: Dictionary = world.players[player_id]
	transfer(player.stock, result.cost, -1)
	if DEFINITIONS.has(action):
		if not player.has("construction_counts"):
			player.construction_counts = {}
		player.construction_counts[action] = player.construction_counts.get(action, 0) + 1
	if action == "expand":
		world.expansions.append({"owner": player_id, "cells": result.cells.duplicate(), "cost": result.cost.duplicate(), "total": result.cells.size(), "claimed": 0, "elapsed": 0.0})
	elif action == "fort":
		var edges := {}
		for cell_on_border in result.cells:
			edges[cell_on_border] = []
			for offset in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				if world.ownership.get(cell_on_border + offset, 0) != player_id:
					edges[cell_on_border].append(offset)
		world.wall_jobs.append({"owner": player_id, "cells": result.cells.duplicate(), "edges": edges, "remaining": BUILD_SECONDS.fort})
	else:
		world.buildings.append({"id": world.next_entity_id, "owner_id": player_id, "cell": cell, "kind": action, "output": result.output, "status": "Building", "remaining": BUILD_SECONDS[action], "duration": BUILD_SECONDS[action]})
		world.next_entity_id += 1
		world.buildings.back().construction_workers = DEFINITIONS[action].workers
		player.workers += DEFINITIONS[action].workers
	return result

func trade(world: RefCounted, player_id: int, resource: String, buying: bool) -> bool:
	if world.winner != 0 or not world.players.has(player_id) or not SELL_PRICE.has(resource):
		return false
	var stock: Dictionary = world.players[player_id].stock
	var price: int = SELL_PRICE[resource] + (2 if buying else 0)
	var cost := {"Money": price * 10} if buying else {resource: 10}
	if not affordable(stock, cost):
		return false
	transfer(stock, cost, -1)
	transfer(stock, {resource: 10} if buying else {"Money": price * 10}, 1)
	return true

func step(world: RefCounted) -> void:
	if world.winner != 0:
		return
	world.tick += 1
	for player_id in world.players:
		var player: Dictionary = world.players[player_id]
		var stock: Dictionary = player.stock
		var before: Dictionary = stock.duplicate()
		var consumption := ceili(player.population / 6.0)
		var supplied: bool = stock.Food >= consumption and stock.Water >= consumption
		player.warning = "" if supplied else "Shortage: tax reduced. Supply food and water."
		stock.Money += 15 + int((player.population - 12) / 4) * 3 if supplied else 4
		stock.Food = maxi(0, stock.Food - consumption)
		stock.Water = maxi(0, stock.Water - consumption)
		for kind in ORDER:
			var definition: Dictionary = DEFINITIONS[kind]
			for building in world.buildings:
				if building.owner_id != player_id or building.kind != kind:
					continue
				if building.get("remaining", 0.0) > 0:
					continue
				building.last_output = 0
				building.missing = missing_inputs(stock, definition.inputs)
				if not affordable(stock, definition.inputs):
					building.status = "Stopped: needs " + cost_text(definition.inputs)
					continue
				transfer(stock, definition.inputs, -1)
				if not definition.resource.is_empty():
					stock[definition.resource] += building.output
					building.last_output = building.output
				building.status = "Active"
		for resource in NAMES:
			player.delta[resource] = stock[resource] - before[resource]
