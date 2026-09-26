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
	for resource in Economy.NAMES:
		world.players[1].stock[resource] = 1000
	return world

func run() -> void:
	var world := fixture()
	var radial := economy.claim_cells(world, 1, Vector2i(100, 100))
	assert(radial.size() == 40)
	var directions := [false, false, false, false]
	for cell in radial:
		directions[0] = directions[0] or cell.x < 100
		directions[1] = directions[1] or cell.x > 100
		directions[2] = directions[2] or cell.y < 100
		directions[3] = directions[3] or cell.y > 100
	assert(false not in directions, "Radial order must grow around all sides")
	world.players[1].expansion_budget = 80
	assert(economy.claim_cells(world, 1, Vector2i(111, 100)).size() == 80)
	assert(economy.execute(world, 1, "farm", Vector2i(102, 100)).ok)
	var stock: Dictionary = world.players[1].stock
	var food: int = stock.Food
	economy.step(world)
	assert(stock.Food == food - 2, "Construction must not produce")
	economy.advance_construction(world, 9.9)
	assert(world.buildings[0].status == "Building")
	economy.advance_construction(world, 0.1)
	assert(world.buildings[0].remaining == 0)
	food = stock.Food
	economy.step(world)
	assert(stock.Food == food + 6)
	assert(economy.execute(world, 1, "house", Vector2i(104, 100)).ok)
	assert(world.players[1].population == 12)
	economy.advance_construction(world, 12)
	assert(world.players[1].population == 16)
	economy.advance_construction(world, 20)
	assert(world.players[1].population == 16, "Completion applies once")
	world.armies[1] = {"troops": 30, "training": false}
	world.players[2] = world.players[1].duplicate(true)
	world.armies[2] = {"troops": 30, "training": false}
	var target := Vector2i(110, 100)
	world.ownership[target] = 2
	assert(war.attack(world, 1, target, 0.75))
	var attacker: int = world.battles[0].troops
	var defender: int = world.armies[2].troops
	war.step(world)
	assert(world.battles[0].troops < attacker and world.armies[2].troops < defender)
	assert(world.armies[1].losses > 0 and world.armies[2].losses > 0)
	assert(economy.execute(world, 1, "barracks", Vector2i(102, 103)).ok)
	assert(war.count(world, 1, "barracks") == 0)
	economy.advance_construction(world, 18.0)
	assert(war.count(world, 1, "barracks") == 1)
	var dots := preload("res://scripts/map/army_renderer.gd").new()
	root.add_child(dots)
	dots.world = world
	var soldiers_before: int = world.battles[0].troops
	dots.advance(1.0)
	assert(not dots.routes.is_empty())
	var path: Array = dots.routes[0].path
	for position in path:
		var cell := Vector2i((position / World.TILE_SIZE).floor())
		assert(world.ownership[cell] == 1, "Cosmetic troops stay inside connected friendly land")
	assert(world.battles[0].troops == soldiers_before, "Visual particles never create or remove model troops")
	dots.queue_free()
	print("PASS organic radial budgets, timed construction, delayed output/population and bilateral casualties")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.paused = true
	assert(game.hud.stock_bar == game.hud.dock)
	assert(game.hud.dock.get_global_rect().position.y > root.get_visible_rect().size.y * 0.8)
	assert(not game.hud.quote_panel.visible and not game.hud.selection_panel.visible)
	assert(game.hud.build_button.text.is_empty() and game.hud.market_button.text.is_empty())
	game.hud.build_button.pressed.emit()
	game.world.players[1].stock.Wood = 0
	game.refresh_ui()
	assert("fali 30" in game.hud.build_cost_labels.barracks.Wood.tooltip_text)
	game.world.players[1].stock.Wood = 80
	var site := war.build_site(game.world, 1, "well")
	assert(site.x >= 0)
	assert(economy.execute(game.world, 1, "well", site).ok)
	game._process(3.0)
	assert(game.world.buildings[0].remaining == 6.0, "Pause freezes construction")
	game.paused = false
	game._process(2.0)
	assert(game.world.buildings[0].remaining == 4.0)
	await create_timer(4.3).timeout
	assert(game.world.buildings[0].remaining == 0.0, "Engine frames complete real construction")
	game.paused = true
	game.world.players[1].stock.Wood = 0
	game.refresh_ui()
	if "--visual" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://logs/compact-hud.png")
		root.size = Vector2i(1100, 850)
		await process_frame
		await process_frame
		assert(root.get_visible_rect().encloses(game.hud.dock.get_global_rect()))
		assert(root.get_visible_rect().encloses(game.hud.build_panel.get_global_rect()))
		root.get_texture().get_image().save_png("res://logs/compact-small.png")
	print("PASS compact bottom HUD, round right controls and two-row resource cards")
	quit()
