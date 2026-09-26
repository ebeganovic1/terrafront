extends RefCounted

const Economy = preload("res://scripts/systems/economy.gd")
var economy := Economy.new()

func capital(world: RefCounted, owner: int) -> Vector2i:
	for settlement in world.settlements:
		if settlement.owner_id == owner:
			return settlement.cell
	return Vector2i(-1, -1)

func setup(world: RefCounted) -> bool:
	var start := capital(world, 1)
	var queue: Array[Vector2i] = [start]
	var parent := {start: start}
	var distance := {start: 0}
	var cursor := 0
	var candidate := Vector2i(-1, -1)
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		if distance[cell] >= 95 and Vector2(cell).distance_to(Vector2(start)) >= 70 and world.tile(cell).biome in [4, 5]:
			var clear := true
			for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
				clear = clear and world.contains(cell + offset) and world.tile(cell + offset).biome >= 3
			if clear:
				candidate = cell
				break
		if distance[cell] >= 180:
			continue
		for neighbor in world.neighbors(cell):
			if world.tile(neighbor).biome >= 3 and not parent.has(neighbor):
				parent[neighbor] = cell
				distance[neighbor] = distance[cell] + 1
				queue.append(neighbor)
	if candidate.x < 0:
		return false
	world.settlements.append({"id": world.next_entity_id, "owner_id": 2, "cell": candidate})
	world.next_entity_id += 1
	economy.initialize(world, 2)
	var route_cell := candidate
	while route_cell != start:
		world.enemy_route.append(route_cell)
		route_cell = parent[route_cell]
	world.enemy_route.append(start)
	for owner in [1, 2]:
		world.armies[owner] = {"troops": 12, "training": true, "warning": "", "equipment": 0}
	return true

func count(world: RefCounted, owner: int, kind: String, include_pending: bool = false) -> int:
	if kind == "fort":
		var sections := 0
		for wall_owner in world.walls.values():
			if wall_owner == owner:
				sections += 1
		if include_pending:
			for job in world.wall_jobs:
				if job.owner == owner:
					sections += job.cells.size()
		return ceili(sections / 5.0)
	var total := 0
	for building in world.buildings:
		if building.owner_id == owner and building.kind == kind and (include_pending or building.get("remaining", 0.0) <= 0):
			total += 1
	return total

func deployed(world: RefCounted, owner: int) -> int:
	var total := 0
	for battle in world.battles:
		if battle.owner == owner:
			total += battle.troops
	return total

func capacity(world: RefCounted, owner: int) -> int:
	return world.players[owner].population * 2 + count(world, owner, "barracks") * 12

func upgrade_cost(world: RefCounted, owner: int) -> Dictionary:
	var level: int = world.armies[owner].get("equipment", 0)
	return {"Money": 80 * (level + 1), "Iron": 15 * (level + 1)}

func upgrade(world: RefCounted, owner: int) -> bool:
	if world.winner != 0 or not world.armies.has(owner) or count(world, owner, "barracks") == 0:
		return false
	var army: Dictionary = world.armies[owner]
	var cost := upgrade_cost(world, owner)
	if army.get("equipment", 0) >= 2 or not economy.affordable(world.players[owner].stock, cost):
		return false
	economy.transfer(world.players[owner].stock, cost, -1)
	army.equipment = army.get("equipment", 0) + 1
	return true

func adjacent(world: RefCounted, owner: int, cell: Vector2i) -> bool:
	for neighbor in world.neighbors(cell):
		if world.ownership.get(neighbor, 0) == owner:
			return true
	return false

func defense(world: RefCounted, cell: Vector2i) -> float:
	var owner: int = world.ownership.get(cell, 0)
	if not world.armies.has(owner):
		return 0
	var strength: float = 3.0 + world.armies[owner].troops * 0.25
	if economy.capital_at(world, cell) == owner:
		strength += 14
	if world.walls.get(cell, 0) == owner:
		strength += 8
	var biome: int = world.tile(cell).biome
	return strength * (1.7 if biome == 6 else 1.25 if biome == 5 else 1.0) * (1.0 + 0.2 * world.armies[owner].get("equipment", 0))

func quote(world: RefCounted, owner: int, target: Vector2i, fraction: float) -> Dictionary:
	var result := {"ok": false, "reason": "Odaberi protivničku granicu.", "troops": 0, "defense": 0.0, "forecast": ""}
	if world.winner != 0 or not world.armies.has(owner) or not world.contains(target):
		return result
	var defender: int = world.ownership.get(target, 0)
	if defender == 0 or defender == owner or not adjacent(world, owner, target):
		return result
	for battle in world.battles:
		if battle.owner == owner:
			result.reason = "Napad već traje. Povuci ga prije novog napada."
			return result
	result.troops = floori(world.armies[owner].troops * clampf(fraction, 0.25, 0.75))
	result.defense = defense(world, target)
	if result.troops < 4:
		result.reason = "Treba poslati barem 4 vojnika. Izgradi kasarnu."
		return result
	result.ok = true
	result.cells = front_cells(world, {"owner": owner, "defender": defender, "origin": target, "target": target}).slice(0, 12)
	var strength: float = result.troops * (1.0 + 0.2 * world.armies[owner].get("equipment", 0))
	result.forecast = "Povoljno" if strength > result.defense * 1.7 else "Rizično" if strength >= result.defense else "Nepovoljno"
	result.reason = "%s · napad %d · kod kuće ostaje %d\nRezerva automatski brani. Zid štiti svoja polja. Odbrana cilja ≈ %d." % [result.forecast, result.troops, world.armies[owner].troops - result.troops, ceili(result.defense)]
	return result

func attack(world: RefCounted, owner: int, target: Vector2i, fraction: float) -> bool:
	var offer := quote(world, owner, target, fraction)
	if not offer.ok:
		return false
	world.armies[owner].troops -= offer.troops
	world.battles.append({"owner": owner, "defender": world.ownership[target], "origin": target, "target": target, "troops": offer.troops, "progress": 0.0, "elapsed": 0.0})
	world.war_started = true
	return true

func retreat(world: RefCounted, owner: int) -> void:
	for index in range(world.battles.size() - 1, -1, -1):
		var battle: Dictionary = world.battles[index]
		if battle.owner == owner:
			world.armies[owner].troops += battle.troops
			world.battles.remove_at(index)

func capture(world: RefCounted, owner: int, cell: Vector2i) -> void:
	var defender: int = world.ownership.get(cell, 0)
	world.ownership[cell] = owner
	world.walls.erase(cell)
	world.wall_edges.erase(cell)
	var building := economy.building_at(world, cell)
	if not building.is_empty():
		world.players[defender].workers = maxi(0, world.players[defender].workers - int(building.get("construction_workers", Economy.DEFINITIONS[building.kind].workers)))
		if building.kind == "house" and building.get("remaining", 0.0) <= 0:
			world.players[defender].population -= 4
		world.buildings.erase(building)
	if economy.capital_at(world, cell) == defender:
		world.winner = owner

func step(world: RefCounted) -> void:
	if world.winner != 0:
		return
	for owner in world.armies:
		var army: Dictionary = world.armies[owner]
		var stock: Dictionary = world.players[owner].stock
		var total: int = army.troops + deployed(world, owner)
		var upkeep := {"Food": ceili(total / 12.0), "Money": ceili(total / 15.0)}
		army.warning = ""
		army.missing = economy.missing_inputs(stock, upkeep)
		if economy.affordable(stock, upkeep):
			economy.transfer(stock, upkeep, -1)
		elif total > 0:
			army.warning = "Vojska nema hranu/novac; dezertira."
			if army.troops > 0:
				army.troops -= 1
			else:
				for battle in world.battles:
					if battle.owner == owner and battle.troops > 0:
						battle.troops -= 1
						break
		var recruits: int = mini(2 * count(world, owner, "barracks"), maxi(0, capacity(world, owner) - total))
		var cost := {"Money": recruits * 2, "Food": recruits}
		if army.training and recruits > 0 and economy.affordable(stock, cost):
			economy.transfer(stock, cost, -1)
			army.troops += recruits
		elif army.training and recruits > 0 and army.warning.is_empty():
			army.warning = "Obuka čeka hranu i novac."
			army.missing = economy.missing_inputs(stock, cost)
	for index in range(world.battles.size() - 1, -1, -1):
		var battle: Dictionary = world.battles[index]
		if battle.troops < 2:
			world.armies[battle.owner].troops += battle.troops
			world.battles.remove_at(index)
			continue
		var front := front_cells(world, battle)
		if front.is_empty():
			world.armies[battle.owner].troops += battle.troops
			world.battles.remove_at(index)
			continue
		battle.target = front[0]
		var strength := defense(world, battle.target)
		var losses := mini(battle.troops, maxi(1, ceili(strength / 8.0)))
		var defender_losses := maxi(1, floori(battle.troops / 10.0))
		inflict_losses(world, battle.defender, defender_losses)
		battle.troops -= losses
		world.armies[battle.owner].losses = world.armies[battle.owner].get("losses", 0) + losses
		battle.rate = battle.troops * 1.8 * (1.0 + 0.2 * world.armies[battle.owner].get("equipment", 0)) / Economy.TICK_SECONDS
		if battle.troops < 2:
			world.armies[battle.owner].troops += battle.troops
			world.battles.remove_at(index)
			continue

func inflict_losses(world: RefCounted, owner: int, amount: int) -> void:
	var army: Dictionary = world.armies[owner]
	var reserve_losses := mini(army.troops, amount)
	army.troops -= reserve_losses
	var remaining := amount - reserve_losses
	for force in world.battles:
		if force.owner == owner and remaining > 0:
			var deployed_losses := mini(force.troops, remaining)
			force.troops -= deployed_losses
			remaining -= deployed_losses
	army.losses = army.get("losses", 0) + amount - remaining

func front_cells(world: RefCounted, battle: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in world.ownership:
		if world.ownership[cell] == battle.defender and adjacent(world, battle.owner, cell):
			cells.append(cell)
	var origin: Vector2i = battle.get("origin", battle.target)
	cells.sort_custom(func(first: Vector2i, second: Vector2i):
		var first_distance := Vector2(first).distance_squared_to(Vector2(origin))
		var second_distance := Vector2(second).distance_squared_to(Vector2(origin))
		if first_distance == second_distance:
			return first.y < second.y if first.y != second.y else first.x < second.x
		return first_distance < second_distance)
	return cells

func advance_front(world: RefCounted, delta: float) -> bool:
	if world.winner != 0:
		return false
	var changed := false
	for battle in world.battles:
		battle.progress += delta * battle.get("rate", 0.0)
		battle.elapsed += delta
		while battle.elapsed >= 0.2:
			battle.elapsed -= 0.2
			var cells := front_cells(world, battle)
			battle.front = cells.slice(0, 12)
			if cells.is_empty() or battle.troops < 2:
				break
			battle.target = cells[0]
			var price := defense(world, battle.target) * 1.5
			if battle.progress < price:
				break
			battle.progress -= price
			capture(world, battle.owner, battle.target)
			changed = true
			if world.winner != 0:
				return true
	return changed

func build_site(world: RefCounted, owner: int, kind: String) -> Vector2i:
	for cell in world.ownership:
		if world.ownership[cell] == owner and economy.quote(world, owner, kind, cell).ok:
			return cell
	return Vector2i(-1, -1)

func ai_step(world: RefCounted) -> void:
	if not world.armies.has(2) or world.winner != 0:
		return
	var stock: Dictionary = world.players[2].stock
	for resource in ["Wood", "Food", "Water", "Stone"]:
		if stock[resource] > 70 and stock.Money < 100:
			economy.trade(world, 2, resource, false)
	for resource in ["Water", "Food", "Wood"]:
		if stock[resource] < 8 and stock.Money > 60:
			economy.trade(world, 2, resource, true)
	var priorities: Array[String] = ["well", "farm", "lumber", "barracks", "farm", "fort"]
	var desired := {}
	for kind in priorities:
		desired[kind] = desired.get(kind, 0) + 1
		if count(world, 2, kind, true) < desired[kind]:
			var build_cost: Dictionary = economy.construction_cost(world, 2, kind)
			for resource in build_cost:
				if resource != "Money" and stock[resource] < build_cost[resource]:
					var price: int = (Economy.SELL_PRICE[resource] + 2) * 10
					if stock.Money >= build_cost.Money + price:
						economy.trade(world, 2, resource, true)
			var site := build_site(world, 2, kind)
			if site.x >= 0:
				economy.execute(world, 2, kind, site)
				break
			if not economy.affordable(stock, build_cost):
				break
	if world.tick % 6 == 0:
		for cell in world.enemy_route:
			if not world.ownership.has(cell) and economy.quote(world, 2, "expand", cell).ok:
				economy.execute(world, 2, "expand", cell)
				break
	var active := false
	for battle in world.battles:
		if battle.owner == 2:
			active = true
			if battle.troops < 5:
				retreat(world, 2)
			break
	if active or world.armies[2].troops < 20:
		return
	var target := Vector2i(-1, -1)
	var weakest := INF
	for cell in world.ownership:
		if world.ownership[cell] == 1 and adjacent(world, 2, cell):
			var strength := defense(world, cell)
			if strength < weakest:
				weakest = strength
				target = cell
	if target.x >= 0:
		attack(world, 2, target, 0.75)
