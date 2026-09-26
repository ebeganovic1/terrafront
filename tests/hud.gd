extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.paused = true
	scene.refresh_ui()
	var hud = scene.hud
	assert(not hud.build_panel.visible and not hud.market_panel.visible and not hud.menu_panel.visible)
	assert(not hud.selection_panel.visible and not hud.quote_panel.visible)
	var stock: Dictionary = scene.world.players[1].stock.duplicate()
	hud.build_button.pressed.emit()
	assert(hud.build_panel.visible)
	for kind in scene.Economy.DEFINITIONS:
		hud.action_buttons[kind].pressed.emit()
		assert(scene.selected_action == kind, "Every build button selects its own action")
		assert(not hud.build_panel.visible and not hud.quote_panel.visible)
		assert(scene.world.players[1].stock == stock, "Selection must never spend")
	if not hud.build_panel.visible:
		hud.build_button.pressed.emit()
	assert(hud.build_panel.visible)
	hud.market_button.pressed.emit()
	assert(hud.market_panel.visible and not hud.build_panel.visible)
	hud.trade_resource.select(1)
	hud.trade_resource.item_selected.emit(1)
	var old_wood: int = scene.world.players[1].stock.Wood
	var old_money: int = scene.world.players[1].stock.Money
	hud.buy_button.pressed.emit()
	assert(scene.world.players[1].stock.Wood == old_wood + 10)
	assert(scene.world.players[1].stock.Money == old_money - 50)
	hud.sell_button.pressed.emit()
	assert(scene.world.players[1].stock.Wood == old_wood)
	assert(scene.world.players[1].stock.Money == old_money - 20)
	hud.menu_button.pressed.emit()
	assert(hud.menu_panel.visible and not hud.market_panel.visible)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene._unhandled_input(escape)
	assert(scene.selected_action == "inspect")
	assert(not hud.menu_panel.visible and not hud.quote_panel.visible)
	hud.pause_button.pressed.emit()
	assert(not scene.paused)
	hud.pause_button.pressed.emit()
	assert(scene.paused)
	hud.speed_button.pressed.emit()
	assert(scene.speed == 2)
	hud.toast("Test")
	hud.advance(6.0)
	assert(not hud.feedback.visible)
	if "--visual" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/hud-clean.png")
		hud.build_button.pressed.emit()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/hud-build.png")
		root.size = Vector2i(1100, 850)
		await process_frame
		await process_frame
		assert(root.get_visible_rect().encloses(hud.build_panel.get_global_rect()), "Build menu must fit")
		assert(root.get_visible_rect().encloses(hud.stock_bar.get_global_rect()), "Stocks must fit")
		assert(root.get_visible_rect().encloses(hud.dock.get_global_rect()), "Dock must fit")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/hud-build-small.png")
		hud.market_button.pressed.emit()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/hud-market.png")
	print("PASS HUD menus, all action bindings, hidden panels, trades, escape, pause, speed, toast and layout")
	quit()
