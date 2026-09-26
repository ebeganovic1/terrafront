extends RefCounted

const World = preload("res://scripts/world/world_data.gd")
const TICK_SECONDS := 5.0
const NAMES := ["Money", "Food", "Wood", "Stone", "Iron", "Oil", "Water"]
const DEFINITIONS := {
	"farm": {"name": "Farm", "cost": {"Money": 60, "Wood": 20, "Stone": 10}, "inputs": {"Money": 2, "Water": 2}, "resource": "Food", "base": 3, "workers": 2, "biomes": [4], "potential": 0},
	"lumber": {"name": "Lumber camp", "cost": {"Money": 50, "Wood": 10}, "inputs": {"Money": 2, "Food": 1}, "resource": "Wood", "base": 3, "workers": 2, "biomes": [5], "potential": 1},
	"quarry": {"name": "Quarry", "cost": {"Money": 65, "Wood": 20}, "inputs": {"Money": 3, "Food": 1}, "resource": "Stone", "base": 3, "workers": 2, "biomes": [6], "potential": 2},
	"mine": {"name": "Iron mine", "cost": {"Money": 100, "Wood": 30, "Stone": 25}, "inputs": {"Money": 4, "Food": 1, "Water": 1}, "resource": "Iron", "base": 2, "workers": 3, "biomes": [6], "potential": 3},
	"well": {"name": "Well", "cost": {"Money": 40, "Wood": 15, "Stone": 10}, "inputs": {"Money": 1}, "resource": "Water", "base": 6, "workers": 1, "biomes": [3, 4, 5, 7, 8, 9], "potential": 5},
	"house": {"name": "Housing", "cost": {"Money": 80, "Wood": 25, "Stone": 20}, "inputs": {}, "resource": "", "base": 0, "workers": 0, "biomes": [3, 4, 5, 7, 8, 9], "potential": -1},
	"oil": {"name": "Oil pump", "cost": {"Money": 150, "Wood": 30, "Stone": 40, "Iron": 20}, "inputs": {"Money": 5, "Water": 2}, "resource": "Oil", "base": 2, "workers": 3, "biomes": [7], "potential": 4}
}
const SELL_PRICE := {"Food": 2, "Wood": 3, "Stone": 3, "Iron": 6, "Oil": 8, "Water": 1}
const ORDER := ["well", "farm", "lumber", "quarry", "mine", "oil", "house"]

func initialize(world: RefCounted, player_id: int = 1) -> void:
	world.players[player_id] = {"stock": {"Money": 350, "Food": 60, "Wood": 80, "Stone": 60, "Iron": 0, "Oil": 0, "Water": 50}, "population": 12, "workers": 0, "delta": {}, "warning": ""}
	var center: Vector2i = world.settlements[0].cell
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
		if building.cell == cell:
			return building
	return {}

func affordable(stock: Dictionary, cost: Dictionary) -> bool:
	for resource in cost:
		if stock.get(resource, 0) < cost[resource]:
			return false
	return true

func transfer(stock: Dictionary, amounts: Dictionary, sign_value: int) -> void:
	for resource in amounts:
		stock[resource] += amounts[resource] * sign_value

func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for resource in cost:
		parts.append("%d %s" % [cost[resource], resource])
	return ", ".join(parts) if not parts.is_empty() else "none"

func claim_cells(world: RefCounted, player_id: int, target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not world.contains(target) or world.tile(target).biome < 3 or world.ownership.has(target):
		return result
	var adjacent := false
	for neighbor in world.neighbors(target):
		if world.ownership.get(neighbor, 0) == player_id:
			adjacent = true
	if not adjacent:
		return result
	result.append(target)
	var visited := {target: true}
	var cursor := 0
	while cursor < result.size():
		var cell := result[cursor]
		cursor += 1
		for neighbor in world.neighbors(cell):
			if visited.has(neighbor) or world.ownership.has(neighbor) or world.tile(neighbor).biome < 3:
				continue
			if absi(neighbor.x - target.x) + absi(neighbor.y - target.y) > 4:
				continue
			visited[neighbor] = true
			result.append(neighbor)
	return result

func quote(world: RefCounted, player_id: int, action: String, cell: Vector2i) -> Dictionary:
	var result := {"ok": false, "reason": "Select an action and a tile.", "cost": {}, "cells": [], "output": 0, "detail": ""}
	if not world.players.has(player_id) or not world.contains(cell):
		return result
	var player: Dictionary = world.players[player_id]
	if action == "expand":
		var cells := claim_cells(world, player_id, cell)
		if cells.is_empty():
			result.reason = "Choose unclaimed land touching your border. Water cannot be claimed."
			return result
		result.cells = cells
		result.cost = {"Money": 12 + cells.size() + int(territory_size(world, player_id) / 150), "Wood": ceili(cells.size() / 12.0), "Food": ceili(cells.size() / 10.0)}
		result.detail = "Claim %d connected tiles. No territory upkeep." % cells.size()
	elif DEFINITIONS.has(action):
		var definition: Dictionary = DEFINITIONS[action]
		result.cost = definition.cost.duplicate()
		if world.ownership.get(cell, 0) != player_id:
			result.reason = "Build only inside your territory. Expand first."
			return result
		if not building_at(world, cell).is_empty() or cell == world.settlements[0].cell:
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
		if player.workers + definition.workers > player.population:
			result.reason = "Not enough workers. Build housing (+4 population)."
			return result
		result.detail = "+4 population / workers, +3 tax; more food and water needed." if action == "house" else "+%d %s / 5s | Upkeep: %s | Workers: %d" % [result.output, definition.resource, cost_text(definition.inputs), definition.workers]
	else:
		return result
	if not affordable(player.stock, result.cost):
		result.reason = "Not enough resources. Need: " + cost_text(result.cost)
		return result
	result.ok = true
	result.reason = result.detail
	return result

func execute(world: RefCounted, player_id: int, action: String, cell: Vector2i) -> Dictionary:
	var result := quote(world, player_id, action, cell)
	if not result.ok:
		return result
	var player: Dictionary = world.players[player_id]
	transfer(player.stock, result.cost, -1)
	if action == "expand":
		for claimed in result.cells:
			world.ownership[claimed] = player_id
	else:
		var definition: Dictionary = DEFINITIONS[action]
		world.buildings.append({"id": world.next_entity_id, "owner_id": player_id, "cell": cell, "kind": action, "output": result.output, "status": "Ready"})
		world.next_entity_id += 1
		player.workers += definition.workers
		if action == "house":
			player.population += 4
	return result

func trade(world: RefCounted, player_id: int, resource: String, buying: bool) -> bool:
	if not world.players.has(player_id) or not SELL_PRICE.has(resource):
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
				if not affordable(stock, definition.inputs):
					building.status = "Stopped: needs " + cost_text(definition.inputs)
					continue
				transfer(stock, definition.inputs, -1)
				if not definition.resource.is_empty():
					stock[definition.resource] += building.output
				building.status = "Active"
		for resource in NAMES:
			player.delta[resource] = stock[resource] - before[resource]
