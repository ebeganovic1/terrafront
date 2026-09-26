extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stock: Dictionary = game.world.players[1].stock
	var starting := stock.duplicate()
	await create_timer(5.5).timeout
	assert(stock == starting and game.world.tick == 0, "Exploring before first construction must not exhaust supplies")
	var home: Vector2i = game.world.settlements[0].cell
	for index in 3:
		var kind: String = ["well", "farm", "lumber"][index]
		var cell := home + Vector2i((index + 1) * 2, -2)
		for occupied in game.economy.footprint(cell):
			game.world.ownership[occupied] = 1
			game.world.tiles[game.world.index(occupied)] = {"biome": 5 if kind == "lumber" else 4, "resources": [5, 5, 0, 0, 0, 5]}
		game.world.tiles[game.world.index(cell)] = {"biome": 5 if kind == "lumber" else 4, "resources": [5, 5, 0, 0, 0, 5]}
		game.selected = cell
		game.select_action(kind)
		game.confirm_action()
	assert(game.world.buildings.size() == 3)
	game.economy.advance_construction(game.world, 24.0)
	var before := stock.duplicate()
	await create_timer(5.5).timeout
	assert(game.world.tick == 1, "Real engine frames must drive production")
	assert(stock.Wood == before.Wood + 8)
	assert(stock.Food == before.Food + 4)
	assert(game.hud.stock_labels.Wood.text == str(stock.Wood))
	assert(game.hud.stock_labels.Food.text == str(stock.Food))
	game.paused = true
	game.refresh_ui()
	assert("Pauzirano" in game.hud.cycle_label.text)
	var well: Dictionary = game.world.buildings.pop_front()
	stock.Food = 0
	stock.Water = 0
	game.economy.step(game.world)
	var farm: Dictionary = game.world.buildings[0]
	var lumber: Dictionary = game.world.buildings[1]
	assert(farm.missing.Water == 2 and farm.last_output == 0)
	assert(lumber.missing.Food == 1 and lumber.last_output == 0)
	game.inspect(farm.cell)
	assert("bunar" in game.hud.information.text)
	game.inspect(lumber.cell)
	assert("hranu" in game.hud.information.text)
	game.world.buildings.push_front(well)
	before = stock.duplicate()
	game.economy.step(game.world)
	assert(stock.Wood == before.Wood + 8 and stock.Food == before.Food + 7)
	assert(farm.missing.is_empty() and lumber.missing.is_empty())
	print("PASS real-time inventory growth, HUD values, pre-build protection, shortage diagnosis and production recovery")
	quit()
