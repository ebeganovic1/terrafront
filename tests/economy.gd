extends SceneTree

const World = preload("res://scripts/world/world_data.gd")
const Economy = preload("res://scripts/systems/economy.gd")
var economy := Economy.new()
const HOME := Vector2i(240, 168)

func _initialize() -> void:
	run.call_deferred()

func fixture() -> RefCounted:
	var world := World.new()
	world.tiles.resize(World.WIDTH * World.HEIGHT)
	world.tiles.fill({"biome": 4, "elevation": 0.5, "moisture": 0.5, "temperature": 0.5, "terrain_type": "land", "resources": [5, 0, 0, 0, 0, 2]})
	world.settlements.append({"id": 1, "owner_id": 1, "cell": HOME})
	economy.initialize(world)
	return world

func run() -> void:
	var world := fixture()
	var player: Dictionary = world.players[1]
	assert(world.ownership.size() == 221)
	var border := HOME + Vector2i(11, 0)
	var quote := economy.quote(world, 1, "expand", border)
	assert(quote.ok)
	var stock: Dictionary = player.stock.duplicate()
	assert(not economy.execute(world, 1, "expand", HOME + Vector2i(50, 0)).ok)
	assert(player.stock == stock)
	assert(economy.execute(world, 1, "expand", border).ok)
	for resource in quote.cost:
		assert(player.stock[resource] == stock[resource] - quote.cost[resource])
	assert(world.ownership.size() == 221 + quote.cells.size())
	stock = player.stock.duplicate()
	assert(not economy.execute(world, 1, "expand", border).ok)
	assert(player.stock == stock)
	assert(not economy.execute(world, 2, "farm", HOME + Vector2i(1, 0)).ok)
	world.tiles[world.index(HOME + Vector2i(0, 11))] = {"biome": 0}
	assert(not economy.quote(world, 1, "expand", HOME + Vector2i(0, 11)).ok)
	player.stock.Money = 0
	assert(not economy.execute(world, 1, "farm", HOME + Vector2i(1, 0)).ok)
	assert(world.buildings.is_empty())
	world = fixture()
	player = world.players[1]
	assert(economy.execute(world, 1, "well", HOME + Vector2i(1, 0)).ok)
	assert(economy.execute(world, 1, "farm", HOME + Vector2i(2, 0)).ok)
	assert(player.stock.Money == 250)
	assert(player.workers == 3)
	assert(not economy.execute(world, 1, "farm", HOME + Vector2i(2, 0)).ok)
	assert(not economy.execute(world, 1, "lumber", HOME + Vector2i(3, 0)).ok)
	assert(not economy.execute(world, 1, "farm", HOME).ok)
	economy.step(world)
	assert(player.stock.Money == 262)
	assert(player.stock.Food == 66)
	assert(player.stock.Water == 54)
	assert(player.delta.Money == 12)
	assert(economy.execute(world, 1, "house", HOME + Vector2i(3, 0)).ok)
	assert(player.population == 16)
	var money: int = player.stock.Money
	var food: int = player.stock.Food
	assert(economy.trade(world, 1, "Food", true))
	assert(player.stock.Money == money - 40 and player.stock.Food == food + 10)
	assert(economy.trade(world, 1, "Food", false))
	assert(player.stock.Money == money - 20 and player.stock.Food == food)
	assert(not economy.trade(world, 1, "Oil", false))
	assert(not economy.trade(world, 1, "Unknown", true))
	player.workers = player.population
	assert(not economy.quote(world, 1, "farm", HOME + Vector2i(4, 0)).ok)
	world = fixture()
	player = world.players[1]
	economy.execute(world, 1, "farm", HOME + Vector2i(1, 0))
	player.stock.Water = 0
	economy.step(world)
	assert(world.buildings[0].status.begins_with("Stopped"))
	assert(player.stock.Food == 58)
	player.stock.Water = 10
	economy.step(world)
	assert(world.buildings[0].status == "Active")
	for tick in 100:
		economy.step(world)
		for resource in Economy.NAMES:
			assert(player.stock[resource] >= 0)
	print("PASS claims, exact charges, invalid purchases, workforce, production, upkeep, recovery and market")
	for kind in Economy.DEFINITIONS:
		world = fixture()
		player = world.players[1]
		for resource in Economy.NAMES:
			player.stock[resource] = 1000
		var definition: Dictionary = Economy.DEFINITIONS[kind]
		var cell := HOME + Vector2i(1, 0)
		world.tiles[world.index(cell)] = {"biome": definition.biomes[0], "resources": [5, 5, 5, 5, 5, 5]}
		assert(economy.execute(world, 1, kind, cell).ok)
		var balances: Dictionary = player.stock.duplicate()
		economy.step(world)
		var people_use := ceili(player.population / 6.0)
		for resource in Economy.NAMES:
			var expected: int = balances[resource] - definition.inputs.get(resource, 0)
			if resource == "Money":
				expected += 18 if kind == "house" else 15
			if resource in ["Food", "Water"]:
				expected -= people_use
			if resource == definition.resource:
				expected += definition.base + 5
			assert(player.stock[resource] == expected, "Wrong balance: " + kind + "/" + resource)
	print("PASS exact tick balances for all seven building types")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.paused = true
	var farm := find_build_site(scene, "farm")
	var old_money: int = scene.world.players[1].stock.Money
	scene.select_action("farm")
	scene.inspect(farm)
	assert(not scene.confirm_button.disabled)
	assert(scene.world.players[1].stock.Money == old_money)
	scene.confirm_action()
	assert(scene.world.players[1].stock.Money == old_money - 60)
	assert(scene.confirm_button.disabled)
	scene.select_action("well")
	scene.inspect(find_build_site(scene, "well"))
	scene.confirm_action()
	assert(scene.world.buildings.size() == 2)
	var before_tick: int = scene.world.tick
	scene._process(10.0)
	assert(scene.world.tick == before_tick)
	scene.paused = false
	scene.elapsed = 0
	scene.speed = 2
	scene._process(2.5)
	assert(scene.world.tick == before_tick + 1)
	scene.paused = true
	scene.pause_button.text = "Resume"
	var target := Vector2i(-1, -1)
	for cell in scene.world.ownership:
		for neighbor in scene.world.neighbors(cell):
			if scene.economy.quote(scene.world, 1, "expand", neighbor).ok:
				target = neighbor
				break
		if target.x >= 0:
			break
	assert(target.x >= 0)
	scene.select_action("expand")
	scene.inspect(target)
	var old_size: int = scene.world.ownership.size()
	scene.confirm_action()
	assert(scene.world.ownership.size() > old_size)
	scene.select_action("inspect")
	scene.inspect(farm)
	if "--visual" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/gameplay.png")
		scene.select_action("farm")
		scene.inspect(find_build_site(scene, "farm"))
		root.size = Vector2i(1100, 850)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/gameplay-small.png")
	print("PASS UI previews, confirmed purchases, duplicate prevention, pause, speed and territory")
	quit()

func find_build_site(scene: Node, kind: String) -> Vector2i:
	for cell in scene.world.ownership:
		if scene.economy.quote(scene.world, 1, kind, cell).ok:
			return cell
	assert(false, "No starting build site for " + kind)
	return Vector2i(-1, -1)
