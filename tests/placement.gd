extends SceneTree

const World = preload("res://scripts/world/world_data.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game := preload("res://scripts/main.gd").new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.armies.clear()
	var home: Vector2i = game.world.settlements[0].cell
	var cell := home + Vector2i(2, 0)
	for occupied in game.economy.footprint(cell):
		game.world.ownership[occupied] = 1
		game.world.tiles[game.world.index(occupied)] = {"biome": 5, "resources": [2, 5, 0, 0, 0, 2]}
	game.world.tiles[game.world.index(cell)] = {"biome": 5, "resources": [2, 5, 0, 0, 0, 2]}
	game.camera.force_update_scroll()
	var position: Vector2 = game.get_canvas_transform() * ((Vector2(cell) + Vector2.ONE * 0.5) * World.TILE_SIZE)
	var stock: Dictionary = game.world.players[1].stock
	var before := stock.duplicate()
	game.preview_building("lumber", position)
	assert(stock == before and game.current_quote.ok)
	game.drop_building("lumber", position)
	assert(game.world.buildings.size() == 1)
	assert(stock.Wood == before.Wood - 10 and stock.Money == before.Money - 50)
	before = stock.duplicate()
	game.drop_building("lumber", position)
	game.drop_building("lumber", Vector2(-100000, -100000))
	assert(stock == before and game.world.buildings.size() == 1)
	game.economy.advance_construction(game.world, 10.0)
	game._process(5.0)
	assert(stock.Wood == before.Wood + 8)
	assert(game.hud.stock_labels.Wood.text == str(stock.Wood))
	assert(game.world.buildings[0].status == "Active")
	var target := Vector2i(-1, -1)
	for owned in game.world.ownership:
		for neighbor in game.world.neighbors(owned):
			if not game.world.ownership.has(neighbor) and game.economy.quote(game.world, 1, "expand", neighbor).ok:
				target = neighbor
				break
		if target.x >= 0:
			break
	assert(target.x >= 0)
	var territory_size: int = game.world.ownership.size()
	var world_position := (Vector2(target) + Vector2.ONE * 0.5) * World.TILE_SIZE
	game.expand_position(world_position)
	game.economy.advance_expansion(game.world, 10.0)
	assert(game.world.ownership.size() > territory_size)
	before = stock.duplicate()
	game.expand_position(Vector2(-1000, -1000))
	assert(stock == before)
	var double_clicks := [0]
	game.camera.tile_double_clicked.connect(func(_position: Vector2): double_clicks[0] += 1)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.double_click = true
	press.position = Vector2(500, 300)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	game.camera._unhandled_input(press)
	game.camera._input(release)
	assert(double_clicks[0] == 1)
	game.camera._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(540, 300)
	game.camera._input(motion)
	game.camera._input(release)
	assert(double_clicks[0] == 1)
	game.camera.cancel_drag()
	if DisplayServer.get_name() == "headless":
		print("PASS placement costs, duplicate/outside rejection, lumber inventory, expansion and double-click vs drag; native GUI drag requires visual run")
		quit()
		return
	game.focus_settlement()
	game.camera.force_update_scroll()
	game.hud.build_panel.show()
	await process_frame
	await process_frame
	var farm_cell := home + Vector2i(4, 0)
	for occupied in game.economy.footprint(farm_cell):
		game.world.ownership[occupied] = 1
		game.world.tiles[game.world.index(occupied)] = {"biome": 4, "resources": [5, 0, 0, 0, 0, 2]}
	game.world.tiles[game.world.index(farm_cell)] = {"biome": 4, "resources": [5, 0, 0, 0, 0, 2]}
	var button_position: Vector2 = game.hud.action_buttons.farm.get_global_rect().get_center()
	var destination: Vector2 = game.get_canvas_transform() * ((Vector2(farm_cell) + Vector2.ONE * 0.5) * World.TILE_SIZE)
	root.warp_mouse(button_position)
	await process_frame
	var move := InputEventMouseMotion.new()
	move.position = button_position
	root.push_input(move, true)
	var button_press := InputEventMouseButton.new()
	button_press.button_index = MOUSE_BUTTON_LEFT
	button_press.pressed = true
	button_press.position = button_position
	root.push_input(button_press, true)
	await process_frame
	move = InputEventMouseMotion.new()
	move.position = button_position + Vector2(0, -30)
	move.relative = Vector2(0, -30)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move, true)
	await process_frame
	assert(root.gui_is_dragging(), "Native drag starts from build button")
	root.warp_mouse(destination)
	await process_frame
	move = InputEventMouseMotion.new()
	move.position = destination
	move.relative = destination - button_position
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move, true)
	await process_frame
	var button_release := InputEventMouseButton.new()
	button_release.button_index = MOUSE_BUTTON_LEFT
	button_release.position = destination
	root.push_input(button_release, true)
	await process_frame
	assert(not root.gui_is_dragging())
	assert(game.world.buildings.size() == 2, "Native map drop builds once")
	assert(game.economy.building_at(game.world, farm_cell).kind == "farm")
	assert(game.camera.drag_button == 0)
	var wood_before: int = stock.Wood
	game.set_process(true)
	await create_timer(5.5).timeout
	game.set_process(false)
	assert(stock.Wood == wood_before + 8)
	assert(game.hud.stock_labels.Wood.text == str(stock.Wood))
	print("LIVE VISIBLE WOOD: ", wood_before, " -> ", stock.Wood, " after 5 seconds")
	if "--visual" in OS.get_cmdline_user_args():
		game.focus_settlement()
		game.hud.build_panel.show()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://logs/placement.png")
	print("PASS placement costs, duplicate/outside rejection, real lumber inventory production, expansion and double-click vs drag")
	quit()
