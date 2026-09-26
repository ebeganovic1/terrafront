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
	world.tiles.fill({"biome": 4, "resources": [5, 5, 5, 5, 5, 5], "elevation": 0.5, "moisture": 0.5})
	world.settlements.append({"id": 1, "owner_id": 1, "cell": Vector2i(100, 100)})
	economy.initialize(world)
	assert(war.setup(world))
	for owner in world.players:
		for resource in Economy.NAMES:
			world.players[owner].stock[resource] = 1000
	return world

func run() -> void:
	var world := fixture()
	var home := war.capital(world, 1)
	var enemy := war.capital(world, 2)
	assert(home != enemy and world.ownership[enemy] == 2)
	var site := home + Vector2i(3, 0)
	assert(economy.execute(world, 1, "barracks", site).ok)
	economy.advance_construction(world, 18.0)
	for cell in economy.footprint(site):
		assert(economy.building_at(world, cell).kind == "barracks")
		assert(not economy.quote(world, 1, "house", cell).ok)
	assert(not economy.quote(world, 1, "house", home + Vector2i.ONE).ok)
	var before: Dictionary = world.players[1].stock.duplicate()
	var troops: int = world.armies[1].troops
	war.step(world)
	assert(world.armies[1].troops == troops + 2)
	assert(world.players[1].stock.Money == before.Money - 5)
	assert(world.players[1].stock.Food == before.Food - 3)
	world.armies[1].training = false
	war.step(world)
	assert(world.armies[1].troops == troops + 2)
	var front := home + Vector2i(10, 0)
	before = world.players[1].stock.duplicate()
	assert(war.upgrade(world, 1))
	assert(world.armies[1].equipment == 1)
	assert(world.players[1].stock.Iron == before.Iron - 15)
	assert(world.players[1].stock.Money == before.Money - 80)
	assert(war.upgrade(world, 1))
	before = world.players[1].stock.duplicate()
	assert(not war.upgrade(world, 1))
	assert(world.players[1].stock == before)
	world.ownership[front] = 2
	world.ownership[front + Vector2i.LEFT] = 1
	assert(not war.attack(world, 1, enemy, 0.5))
	assert(not war.attack(world, 1, home, 0.5))
	world.armies[1].troops = 40
	assert(war.attack(world, 1, front, 0.5))
	assert(world.armies[1].troops == 20 and war.deployed(world, 1) == 20)
	assert(not war.attack(world, 1, front, 0.5))
	war.retreat(world, 1)
	assert(world.armies[1].troops == 40 and world.battles.is_empty())
	var plain_defense := war.defense(world, front)
	world.walls[front] = 2
	assert(war.defense(world, front) > plain_defense)
	world.tiles[world.index(front)] = {"biome": 6, "resources": [0, 0, 5, 5, 0, 0]}
	assert(war.defense(world, front) > (plain_defense + 8) * 1.6)
	world = fixture()
	enemy = war.capital(world, 2)
	world.ownership[enemy + Vector2i.LEFT] = 1
	world.armies[1].troops = 100
	world.armies[2].troops = 0
	assert(war.attack(world, 1, enemy, 0.75))
	for tick in 8:
		war.step(world)
		war.advance_front(world, 5.0)
		if world.winner != 0:
			break
	assert(world.winner == 1, "Taking the enemy capital wins")
	before = world.players[1].stock.duplicate()
	assert(not economy.execute(world, 1, "house", home + Vector2i(3, 0)).ok)
	assert(not economy.trade(world, 1, "Wood", true))
	economy.step(world)
	assert(world.players[1].stock == before)
	world = fixture()
	world.ownership[home + Vector2i.LEFT] = 2
	world.armies[2].troops = 100
	world.armies[1].troops = 0
	assert(war.attack(world, 2, home, 0.75))
	for tick in 8:
		war.step(world)
		war.advance_front(world, 5.0)
	assert(world.winner == 2, "Taking the human capital loses")
	print("PASS 2x2 occupancy, capitals, training costs, reserve, retreat, terrain/fort defense, win/loss and frozen ending")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	assert(game.world.armies.size() == 2)
	var own_site := war.build_site(game.world, 1, "farm")
	assert(own_site.x >= 0)
	game.inspect_position((Vector2(own_site) + Vector2.ONE * 0.5) * World.TILE_SIZE)
	assert(game.hud.build_panel.visible and not game.hud.context_button.visible)
	game.select_action("farm")
	game.cancel_selection()
	game.inspect_position((Vector2(war.capital(game.world, 2)) + Vector2.ONE * 0.5) * World.TILE_SIZE)
	assert(game.selected_action == "attack" and game.hud.confirm_button.disabled)
	assert(game.hud.quote_panel.visible and not game.hud.build_panel.visible)
	assert(game.hud.attack_fraction.visible)
	var target := Vector2i(-1, -1)
	for owned in game.world.ownership:
		if game.world.ownership[owned] != 1:
			continue
		for neighbor in game.world.neighbors(owned):
			if not game.world.ownership.has(neighbor) and economy.quote(game.world, 1, "expand", neighbor).ok:
				target = neighbor
				break
		if target.x >= 0:
			break
	assert(target.x >= 0)
	game.world.ownership[target] = 2
	game.inspect_position((Vector2(target) + Vector2.ONE * 0.5) * World.TILE_SIZE)
	game.hud.attack_fraction.selected = 2
	game.hud.attack_fraction.item_selected.emit(2)
	assert(game.attack_share == 0.75 and not game.hud.confirm_button.disabled)
	game.hud.confirm_button.pressed.emit()
	assert(game.world.armies[1].troops == 3 and war.deployed(game.world, 1) == 9)
	game.hud.retreat_button.pressed.emit()
	assert(game.world.armies[1].troops == 12 and game.world.battles.is_empty())
	game.hud.training_button.pressed.emit()
	assert(not game.world.armies[1].training)
	game.hud.home_requested.emit()
	assert(game.camera.position == (Vector2(war.capital(game.world, 1)) + Vector2.ONE * 0.5) * World.TILE_SIZE)
	game.camera.cancel_requested.emit()
	assert(game.selected_action == "inspect" and not game.hud.quote_panel.visible)
	game.regenerate(260926)
	game.set_process(false)
	assert(game.attack_share == 0.5 and game.hud.attack_fraction.selected == 1)
	print("PASS contextual construction/attack, troop selector, confirm, recall, training toggle, minimap navigation and reset")
	var initial_size: int = economy.territory_size(game.world, 2)
	var attacked := false
	for tick in 900:
		economy.advance_construction(game.world, 5.0)
		economy.step(game.world)
		war.step(game.world)
		war.advance_front(game.world, 5.0)
		economy.advance_expansion(game.world, 5.0)
		war.ai_step(game.world)
		for battle in game.world.battles:
			attacked = attacked or battle.owner == 2
		for owner in game.world.players:
			for resource in Economy.NAMES:
				assert(game.world.players[owner].stock[resource] >= 0)
		if game.world.winner != 0:
			break
	print("AI RESULT buildings=", game.world.buildings, " territory=", economy.territory_size(game.world, 2), " army=", game.world.armies[2], " stock=", game.world.players[2].stock, " attacked=", attacked)
	assert(economy.territory_size(game.world, 2) > initial_size)
	assert(war.count(game.world, 2, "barracks") > 0)
	assert(attacked, "AI must reach the player and attack with its own resources")
	game.refresh_ui()
	game.territory.queue_redraw()
	if "--visual" in OS.get_cmdline_user_args():
		game.show_overview()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://logs/war-front.png")
		game.regenerate(260926)
		game.set_process(false)
		for kind in ["well", "farm", "lumber", "barracks", "fort"]:
			for resource in Economy.NAMES:
				game.world.players[1].stock[resource] = 1000
			var cell := war.build_site(game.world, 1, kind)
			if cell.x >= 0:
				economy.execute(game.world, 1, kind, cell)
		economy.advance_construction(game.world, 30.0)
		game.territory.queue_redraw()
		game.camera.zoom = Vector2.ONE * 1.5
		game.refresh_ui()
		game.hud.build_panel.show()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://logs/war-buildings.png")
	print("PASS real-map AI economy, expansion and attack")
	quit()
