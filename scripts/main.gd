extends Node2D

const World = preload("res://scripts/world/world_data.gd")
const Generator = preload("res://scripts/world/world_generator.gd")
const Renderer = preload("res://scripts/map/world_renderer.gd")
const Territory = preload("res://scripts/map/territory_renderer.gd")
const StrategyCamera = preload("res://scripts/camera/strategy_camera.gd")
const Economy = preload("res://scripts/systems/economy.gd")
const PLAYER_ID := 1
var world: RefCounted
var economy := Economy.new()
var renderer: Node2D
var territory: Node2D
var camera: Camera2D
var information: Label
var seed_input: LineEdit
var selected := Vector2i(-1, -1)
var status: Label
var stock_labels := {}
var delta_labels := {}
var stats: Label
var feedback: Label
var quote_label: Label
var confirm_button: Button
var pause_button: Button
var speed_button: Button
var trade_resource: OptionButton
var buy_button: Button
var sell_button: Button
var action_buttons := {}
var selected_action := "inspect"
var current_quote: Dictionary = {}
var elapsed := 0.0
var paused := false
var speed := 1
var reset_dialog: ConfirmationDialog

func _ready() -> void:
	renderer = Renderer.new()
	renderer.z_index = -1
	add_child(renderer)
	territory = Territory.new()
	add_child(territory)
	camera = StrategyCamera.new()
	add_child(camera)
	camera.tile_clicked.connect(inspect_position)
	build_ui()
	regenerate(260926)

func _process(delta: float) -> void:
	if world == null or paused:
		return
	elapsed += delta * speed
	if elapsed >= Economy.TICK_SECONDS:
		while elapsed >= Economy.TICK_SECONDS:
			elapsed -= Economy.TICK_SECONDS
			economy.step(world)
		refresh_ui()

func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	for type in ["Label", "Button", "LineEdit", "OptionButton"]:
		result.set_color("font_color", type, Color("29454d"))
		result.set_color("font_hover_color", type, Color("163e40"))
		result.set_color("font_pressed_color", type, Color("163e40"))
		result.set_color("font_disabled_color", type, Color("81948c"))
		if type == "Label":
			continue
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("dce8e2") if state in ["normal", "disabled"] else Color("b2d4c7")
			style.set_corner_radius_all(7)
			style.set_content_margin_all(8)
			if state == "focus":
				style.bg_color = Color.TRANSPARENT
				style.border_color = Color("499784")
				style.set_border_width_all(2)
			result.set_stylebox(state, type, style)
	return result

func panel(parent: Control) -> PanelContainer:
	var result := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f1f5f2")
	style.border_color = Color("d4e0db")
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	result.add_theme_stylebox_override("panel", style)
	parent.add_child(result)
	return result

func label(parent: Node, value: String, font_size: int = 14) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	parent.add_child(result)
	return result

func button(parent: Node, value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = make_theme()
	var sidebar := panel(root)
	sidebar.anchor_bottom = 1
	sidebar.offset_left = 16
	sidebar.offset_top = 16
	sidebar.offset_right = 316
	sidebar.offset_bottom = -204
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	label(column, "Terrafront", 28)
	label(column, "TREASURY & STORES", 12)
	var stocks := GridContainer.new()
	stocks.columns = 3
	stocks.add_theme_constant_override("h_separation", 16)
	column.add_child(stocks)
	for resource in Economy.NAMES:
		var name_label := label(stocks, resource, 15)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stock_labels[resource] = label(stocks, "0", 16)
		delta_labels[resource] = label(stocks, "+0", 13)
	label(column, "Right column: net change last 5s tick", 11)
	stats = label(column, "", 13)
	column.add_child(HSeparator.new())
	label(column, "MARKET  /  batches of 10", 12)
	trade_resource = OptionButton.new()
	for resource in World.RESOURCE_NAMES:
		trade_resource.add_item(resource)
	trade_resource.item_selected.connect(func(_index: int): refresh_ui())
	column.add_child(trade_resource)
	var trade_row := HBoxContainer.new()
	column.add_child(trade_row)
	buy_button = button(trade_row, "Buy", func(): trade(true))
	sell_button = button(trade_row, "Sell", func(): trade(false))
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(HSeparator.new())
	information = label(column, "", 13)
	information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(HSeparator.new())
	feedback = label(column, "", 13)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var header := panel(root)
	header.anchor_right = 1
	header.offset_left = 332
	header.offset_top = 16
	header.offset_right = -16
	header.offset_bottom = 86
	var header_row := HBoxContainer.new()
	header.add_child(header_row)
	status = label(header_row, "", 12)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button = button(header_row, "Pause", func():
		paused = not paused
		pause_button.text = "Resume" if paused else "Pause")
	speed_button = button(header_row, "1x", func():
		speed = 2 if speed == 1 else 1
		speed_button.text = "%dx" % speed)
	button(header_row, "Home", focus_settlement)
	button(header_row, "Map", show_overview)
	seed_input = LineEdit.new()
	seed_input.custom_minimum_size.x = 80
	seed_input.text = "260926"
	header_row.add_child(seed_input)
	button(header_row, "New", func():
		if seed_input.text.is_valid_int():
			paused = true
			pause_button.text = "Resume"
			reset_dialog.popup_centered()
		else:
			feedback.text = "Enter an integer world seed.")
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.dialog_text = "Start a new world? Territory, buildings and stocks will reset."
	reset_dialog.confirmed.connect(func(): regenerate(int(seed_input.text)))
	root.add_child(reset_dialog)
	var toolbar := panel(root)
	toolbar.anchor_top = 1
	toolbar.anchor_bottom = 1
	toolbar.anchor_right = 1
	toolbar.offset_left = 16
	toolbar.offset_right = -16
	toolbar.offset_top = -188
	toolbar.offset_bottom = -16
	var tools_column := VBoxContainer.new()
	tools_column.add_theme_constant_override("separation", 6)
	toolbar.add_child(tools_column)
	var actions := GridContainer.new()
	actions.columns = 5
	tools_column.add_child(actions)
	for action in ["inspect", "expand", "farm", "lumber", "quarry", "mine", "well", "house", "oil"]:
		var title: String = Economy.DEFINITIONS[action].name if Economy.DEFINITIONS.has(action) else action.capitalize()
		var action_button := button(actions, title, select_action.bind(action))
		action_button.toggle_mode = true
		action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_buttons[action] = action_button
		if Economy.DEFINITIONS.has(action):
			var definition: Dictionary = Economy.DEFINITIONS[action]
			var biomes := PackedStringArray()
			for biome in definition.biomes:
				biomes.append(World.BIOMES[biome])
			action_button.tooltip_text = "Cost: %s\nTerrain: %s\nUpkeep / 5s: %s" % [economy.cost_text(definition.cost), ", ".join(biomes), economy.cost_text(definition.inputs)]
	button(actions, "Help / costs", show_help).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quote_row := HBoxContainer.new()
	tools_column.add_child(quote_row)
	quote_label = label(quote_row, "", 13)
	quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quote_label.custom_minimum_size.y = 56
	confirm_button = button(quote_row, "Confirm", confirm_action)
	confirm_button.custom_minimum_size.x = 150

func show_help() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Terrafront / economy guide"
	dialog.dialog_text = "1. Drag the mouse to move. Click a tile to inspect.\n2. Choose Expand, then unclaimed land touching your border.\n3. Preview the highlighted claim and its cost, then Confirm.\n4. Build on owned tiles: Farm / plains, Lumber / forest, mines / mountains.\n5. Wells need water potential or an adjacent river/lake.\n6. A tick is 5 seconds. Taxes fund upkeep; population eats food and drinks water.\n7. Buildings stop if upkeep is missing. The market can resolve shortages.\n8. Housing adds 4 people/workers and 3 tax, but increases consumption.\n\nHover building buttons for prices and terrain requirements.\nNo automatic spending: all claims and buildings require Confirm.\nNew resets the current world after confirmation. There is no save/load yet."
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(780, 400))

func regenerate(seed_value: int) -> void:
	world = Generator.new().generate(seed_value)
	economy.initialize(world, PLAYER_ID)
	camera.cancel_drag()
	renderer.set_world(world)
	territory.world = world
	territory.queue_redraw()
	elapsed = 0
	paused = false
	speed = 1
	pause_button.text = "Pause"
	speed_button.text = "1x"
	selected_action = "inspect"
	camera.zoom = Vector2.ONE * 0.85
	focus_settlement()
	feedback.text = "Start with a well and farm. Claim towards forests and mountains."
	inspect(world.settlements[0].cell)

func focus_settlement() -> void:
	if world != null:
		camera.position = (Vector2(world.settlements[0].cell) + Vector2.ONE * 0.5) * World.TILE_SIZE - Vector2(140, -40) / camera.zoom

func show_overview() -> void:
	var available := get_viewport_rect().size - Vector2(370, 310)
	var dimensions := Vector2(World.WIDTH, World.HEIGHT) * World.TILE_SIZE
	camera.zoom = Vector2.ONE * clampf(minf(available.x / dimensions.x, available.y / dimensions.y), 0.08, 2.5)
	camera.position = dimensions * 0.5 - Vector2(150, -45) / camera.zoom

func inspect_position(world_position: Vector2) -> void:
	var cell := Vector2i((world_position / World.TILE_SIZE).floor())
	if world.contains(cell):
		inspect(cell)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_HOME:
			focus_settlement()
		elif event.keycode == KEY_ESCAPE:
			select_action("inspect")

func inspect(cell: Vector2i) -> void:
	selected = cell
	refresh_ui()

func select_action(action: String) -> void:
	selected_action = action
	refresh_ui()

func confirm_action() -> void:
	var result := economy.execute(world, PLAYER_ID, selected_action, selected)
	feedback.text = "Completed: " + selected_action + ". " + result.detail if result.ok else result.reason
	territory.queue_redraw()
	refresh_ui()

func trade(buying: bool) -> void:
	var resource: String = trade_resource.get_item_text(trade_resource.selected)
	var completed := economy.trade(world, PLAYER_ID, resource, buying)
	feedback.text = ("Bought " if buying else "Sold ") + "10 " + resource if completed else "Not enough money or stock for that trade."
	refresh_ui()

func refresh_ui() -> void:
	if world == null:
		return
	var player: Dictionary = world.players[PLAYER_ID]
	for resource in Economy.NAMES:
		stock_labels[resource].text = str(player.stock[resource])
		var change: int = player.delta.get(resource, 0)
		delta_labels[resource].text = "%+d" % change
		delta_labels[resource].add_theme_color_override("font_color", Color("aa5750") if change < 0 else Color("397d65"))
	var consumption := ceili(player.population / 6.0)
	stats.text = "Population %d | Workers %d / %d\nTerritory %d tiles | Buildings %d\nPeople use %d Food + %d Water / 5s" % [player.population, player.workers, player.population, economy.territory_size(world, PLAYER_ID), world.buildings.size(), consumption, consumption]
	stats.text += "\nTax $%d / 5s ($4 during shortage)" % (15 + int((player.population - 12) / 4) * 3)
	status.text = "FRONTIER  /  TICK %d\nSEED %d" % [world.tick, world.world_seed]
	var resource: String = trade_resource.get_item_text(trade_resource.selected)
	var sell_price: int = Economy.SELL_PRICE[resource] * 10
	buy_button.text = "Buy 10 / $%d" % (sell_price + 20)
	sell_button.text = "Sell 10 / $%d" % sell_price
	buy_button.disabled = player.stock.Money < sell_price + 20
	sell_button.disabled = player.stock[resource] < 10
	var tile: Dictionary = world.tile(selected)
	var owner := "Yours" if world.ownership.get(selected, 0) == PLAYER_ID else "Unclaimed"
	information.text = "SELECTED  %d : %d  /  %s\nBiome: %s\n" % [selected.x, selected.y, owner, World.BIOMES[tile.biome]]
	var building := economy.building_at(world, selected)
	if not building.is_empty():
		information.text += "%s / %s\n" % [Economy.DEFINITIONS[building.kind].name, building.status]
		var definition: Dictionary = Economy.DEFINITIONS[building.kind]
		if not definition.resource.is_empty():
			information.text += "+%d %s / 5s\nUpkeep: %s\n" % [building.output, definition.resource, economy.cost_text(definition.inputs)]
	information.text += "Potential (not stored resources):\nFood %d  Wood %d  Stone %d\nIron %d  Oil %d  Water %d" % tile.resources
	if not player.warning.is_empty():
		information.text += "\n" + player.warning
	for action in action_buttons:
		action_buttons[action].set_pressed_no_signal(action == selected_action)
	current_quote = economy.quote(world, PLAYER_ID, selected_action, selected)
	confirm_button.disabled = not current_quote.ok
	quote_label.text = "Drag to move / Click to select. Choose an action below, then select its location." if selected_action == "inspect" else "Cost: %s\n%s" % [economy.cost_text(current_quote.cost), current_quote.reason]
	queue_redraw()

func _draw() -> void:
	if selected.x < 0:
		return
	for cell in current_quote.get("cells", []):
		draw_rect(Rect2(Vector2(cell) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color(0.94, 0.78, 0.25, 0.35))
	draw_rect(Rect2(Vector2(selected) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color("fff4bd"), false, 2.0)
