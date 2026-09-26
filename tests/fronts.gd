extends SceneTree

const World = preload("res://scripts/world/world_data.gd")
const Economy = preload("res://scripts/systems/economy.gd")
const War = preload("res://scripts/systems/war.gd")
var economy := Economy.new()
var war := War.new()

func _initialize() -> void:
	run.call_deferred()

func fixture() -> RefCounted:
	var world := World.new()
	world.tiles.resize(World.WIDTH * World.HEIGHT)
	world.tiles.fill({"biome": 4, "resources": [5, 5, 5, 5, 5, 5]})
	world.settlements.append({"id": 1, "owner_id": 1, "cell": Vector2i(100, 100)})
	economy.initialize(world)
	return world

func run() -> void:
	var world := fixture()
	var border := Vector2i(111, 100)
	var size_before: int = world.ownership.size()
	var offer := economy.execute(world, 1, "expand", border)
	assert(offer.ok and world.ownership.size() == size_before)
	var stock: Dictionary = world.players[1].stock.duplicate()
	assert(not economy.execute(world, 1, "expand", border).ok)
	assert(world.players[1].stock == stock)
	economy.advance_expansion(world, 0.14)
	assert(world.ownership.size() == size_before)
	economy.advance_expansion(world, 0.02)
	assert(world.ownership.size() == size_before + 1)
	economy.advance_expansion(world, 10.0)
	assert(world.ownership.size() == size_before + offer.cells.size())
	assert(world.expansions.is_empty())
	world = fixture()
	offer = economy.execute(world, 1, "fort", Vector2i(110, 100))
	assert(offer.ok and world.walls.is_empty())
	economy.advance_construction(world, 15.0)
	assert(world.walls.size() == 5)
	for cell in world.walls:
		assert(economy.boundary(world, 1, cell))
	assert(not economy.execute(world, 1, "fort", Vector2i(110, 100)).ok)
	world = fixture()
	world.players[2] = world.players[1].duplicate(true)
	world.armies = {1: {"troops": 100, "training": false, "equipment": 0}, 2: {"troops": 0, "training": false, "equipment": 0}}
	world.ownership.clear()
	for row in range(90, 111):
		for column in range(90, 120):
			world.ownership[Vector2i(column, row)] = 1 if column < 105 else 2
	assert(war.attack(world, 1, Vector2i(105, 100), 0.75))
	war.step(world)
	var troops: int = world.battles[0].troops
	war.advance_front(world, 0.2)
	assert(world.ownership[Vector2i(105, 100)] == 1)
	war.advance_front(world, 0.2)
	war.advance_front(world, 0.2)
	assert(world.ownership[Vector2i(105, 99)] == 1)
	war.advance_front(world, 0.2)
	assert(world.ownership[Vector2i(105, 101)] == 1)
	assert(world.ownership[Vector2i(107, 100)] == 2, "The wave must widen instead of drawing a tunnel")
	assert(world.battles[0].troops == troops, "Animation does not duplicate combat charges")
	world.winner = 2
	var owners: Dictionary = world.ownership.duplicate()
	war.advance_front(world, 5.0)
	assert(world.ownership == owners)
	print("PASS asynchronous paid expansion, duplicate rejection, 5-cell contour wall, broad front and end-state freeze")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.paused = true
	assert(game.world.enemy_route.size() >= 96)
	assert(Vector2(war.capital(game.world, 1)).distance_to(Vector2(war.capital(game.world, 2))) >= 70)
	game.world.players[1].stock.Wood = 0
	game.refresh_ui()
	assert("fali 30" in game.hud.build_cost_labels.barracks.Wood.tooltip_text)
	game.hud.build_panel.show()
	await process_frame
	assert(game.hud.build_panel.get_global_rect().position.x > root.get_visible_rect().size.x * 0.5)
	game.world.players[1].stock.Wood = 80
	var target := Vector2i(-1, -1)
	for owned in game.world.ownership:
		if game.world.ownership[owned] == 1:
			for neighbor in game.world.neighbors(owned):
				if not game.world.ownership.has(neighbor) and economy.quote(game.world, 1, "expand", neighbor).ok:
					target = neighbor
					break
		if target.x >= 0:
			break
	assert(target.x >= 0)
	assert(economy.execute(game.world, 1, "expand", target).ok)
	var before_pause: int = game.world.ownership.size()
	game._process(1.0)
	assert(game.world.ownership.size() == before_pause, "Pause freezes expansion")
	game.paused = false
	game._process(0.16)
	assert(game.world.ownership.size() == before_pause + 1)
	game.paused = true
	game.world.players[1].stock.Wood = 0
	game.refresh_ui()
	if "--visual" in OS.get_cmdline_user_args():
		await process_frame
		root.get_texture().get_image().save_png("res://logs/front-sidebar.png")
	print("PASS distant rival, right construction sidebar and exact resource deficits")
	quit()
