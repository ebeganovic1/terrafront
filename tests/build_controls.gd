extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var player: Dictionary = game.world.players[1]
	assert(player.population == 12)
	player.workers = 0
	for resource in player.stock:
		player.stock[resource] = 10000
	var first := game.war.build_site(game.world, 1, "well") as Vector2i
	assert(first.x >= 0)
	game.select_action("well")
	assert(not game.hud.build_panel.visible and not game.hud.quote_panel.visible)
	game.inspect_position((Vector2(first) + Vector2.ONE * 0.5) * game.World.TILE_SIZE)
	assert(game.world.buildings.size() == 1)
	assert(player.stock.Money == 9960 and player.workers == 1)
	assert(game.selected_action == "well")
	assert(game.economy.construction_cost(game.world, 1, "well") == {"Money": 44, "Wood": 17, "Stone": 11})
	assert(game.economy.construction_cost(game.world, 1, "farm").Money == 60)
	assert(game.economy.construction_cost(game.world, 2, "well").Money == 40)
	game.inspect_position((Vector2(first) + Vector2.ONE * 0.5) * game.World.TILE_SIZE)
	assert(game.world.buildings.size() == 1 and player.stock.Money == 9960)
	var second := game.war.build_site(game.world, 1, "well") as Vector2i
	game.inspect_position((Vector2(second) + Vector2.ONE * 0.5) * game.World.TILE_SIZE)
	assert(game.world.buildings.size() == 2 and player.stock.Money == 9916)
	assert(game.hud.build_cost_labels.well.Money.text == "9916/48")
	game.economy.advance_construction(game.world, 6.0)
	assert(player.workers == 2, "Workers remain assigned after completion")
	player.population = 2
	var blocked := game.war.build_site(game.world, 1, "well") as Vector2i
	assert(blocked.x < 0, "New construction requires available builders")
	var water: int = player.stock.Water
	game.economy.step(game.world)
	assert(player.stock.Water > water, "Production works without free workers")
	assert(player.workers == 2, "Production never consumes additional workers")
	game.cancel_selection()
	assert(game.selected_action == "inspect")
	print("PASS permanent assigned workers, production without free workers, progressive costs and click placement")
	quit()
