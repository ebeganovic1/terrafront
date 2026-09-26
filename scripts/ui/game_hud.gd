extends CanvasLayer

signal action_selected(action: String)
signal confirmed
signal trade_requested(buying: bool, resource: String)
signal pause_requested
signal speed_requested
signal home_requested
signal overview_requested
signal new_world_requested(seed_value: int)

const World = preload("res://scripts/world/world_data.gd")
const Economy = preload("res://scripts/systems/economy.gd")
const Icons = preload("res://scripts/ui/hud_icons.gd")
const NAMES := {"Money": "Novac", "Food": "Hrana", "Wood": "Drvo", "Stone": "Kamen", "Iron": "Željezo", "Oil": "Nafta", "Water": "Voda"}
const ACTIONS := {"inspect": "Pregled", "expand": "Širenje", "farm": "Farma", "lumber": "Pilana", "quarry": "Kamenolom", "mine": "Rudnik", "well": "Bunar", "house": "Kuće", "oil": "Nafta"}
const BIOMES := ["More", "Jezero", "Rijeka", "Obala", "Ravnica", "Šuma", "Planine", "Pustinja", "Močvara", "Snijeg"]
var stock_labels := {}
var delta_labels := {}
var action_buttons := {}
var information: Label
var stats: Label
var status: Label
var feedback: Label
var quote_label: Label
var confirm_button: Button
var pause_button: Button
var speed_button: Button
var seed_input: LineEdit
var trade_resource: OptionButton
var buy_button: Button
var sell_button: Button
var selection_panel: PanelContainer
var build_panel: PanelContainer
var market_panel: PanelContainer
var menu_panel: PanelContainer
var quote_panel: PanelContainer
var reset_dialog: ConfirmationDialog
var build_button: Button
var market_button: Button
var menu_button: Button
var stock_bar: PanelContainer
var dock: PanelContainer
var toast_time := 0.0

func _ready() -> void:
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = make_theme()
	stock_bar = panel(root, Vector4(16, 16, -190, 84), Vector4(0, 0, 1, 0))
	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 14)
	stock_bar.add_child(resources)
	for resource in Economy.NAMES:
		var group := VBoxContainer.new()
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resources.add_child(group)
		var title := HBoxContainer.new()
		group.add_child(title)
		var icon := TextureRect.new()
		icon.texture = Icons.get_icon(resource)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(15, 15)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title.add_child(icon)
		label(title, NAMES[resource], 12).modulate = Color("adc0ce")
		var amounts := HBoxContainer.new()
		group.add_child(amounts)
		stock_labels[resource] = label(amounts, "0", 20)
		delta_labels[resource] = label(amounts, "", 11)
		group.tooltip_text = NAMES[resource] + ": zaliha i promjena tokom posljednjih 5 sekundi."
	var controls := panel(root, Vector4(-178, 16, -16, 84), Vector4(1, 0, 1, 0))
	var control_row := HBoxContainer.new()
	controls.add_child(control_row)
	pause_button = button(control_row, "II", func(): pause_requested.emit())
	pause_button.tooltip_text = "Pauza / nastavak"
	speed_button = button(control_row, "1×", func(): speed_requested.emit())
	speed_button.tooltip_text = "Brzina simulacije"
	menu_button = button(control_row, "…", func(): toggle_popup(menu_panel))
	menu_button.tooltip_text = "Mapa, naselje, nova partija i pomoć"
	var player_panel := panel(root, Vector4(16, -126, 236, -16), Vector4(0, 1, 0, 1))
	var player_column := VBoxContainer.new()
	player_panel.add_child(player_column)
	label(player_column, "TERRAFRONT", 16)
	stats = label(player_column, "", 13)
	selection_panel = panel(root, Vector4(16, -300, 236, -138), Vector4(0, 1, 0, 1))
	var selection_column := VBoxContainer.new()
	selection_panel.add_child(selection_column)
	var selected_header := HBoxContainer.new()
	selection_column.add_child(selected_header)
	label(selected_header, "ODABRANO", 11).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(selected_header, "×", func(): selection_panel.hide())
	information = label(selection_column, "", 14)
	information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_panel.hide()
	dock = panel(root, Vector4(252, -98, -16, -16), Vector4(0, 1, 1, 1))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	dock.add_child(actions)
	for action in ["inspect", "expand"]:
		var action_button := button(actions, ACTIONS[action], func(): action_selected.emit(action))
		action_button.icon = Icons.get_icon(action)
		action_button.toggle_mode = true
		action_buttons[action] = action_button
		action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_button = button(actions, "Gradnja", func(): toggle_popup(build_panel))
	build_button.icon = Icons.get_icon("build")
	build_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_button = button(actions, "Trgovina", func(): toggle_popup(market_panel))
	market_button.icon = Icons.get_icon("market")
	market_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quote_panel = panel(root, Vector4(252, -186, -16, -110), Vector4(0, 1, 1, 1))
	var quote_row := HBoxContainer.new()
	quote_panel.add_child(quote_row)
	quote_label = label(quote_row, "", 14)
	quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button = button(quote_row, "Potvrdi", func(): confirmed.emit())
	confirm_button.custom_minimum_size.x = 160
	button(quote_row, "×", func(): action_selected.emit("inspect")).tooltip_text = "Otkaži akciju"
	quote_panel.hide()
	build_panel = panel(root, Vector4(252, -278, -16, -110), Vector4(0, 1, 1, 1))
	var build_column := VBoxContainer.new()
	build_panel.add_child(build_column)
	var build_header := HBoxContainer.new()
	build_column.add_child(build_header)
	label(build_header, "Šta želiš izgraditi?", 16).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(build_header, "×", func(): build_panel.hide(); refresh_popups())
	var buildings := HBoxContainer.new()
	build_column.add_child(buildings)
	for action in Economy.DEFINITIONS:
		var definition: Dictionary = Economy.DEFINITIONS[action]
		var action_button := button(buildings, "%s\n$%d" % [ACTIONS[action], definition.cost.Money], func():
			build_panel.hide()
			action_selected.emit(action))
		action_button.icon = Icons.get_icon(definition.resource if definition.resource != "" else "house")
		action_button.add_theme_constant_override("icon_max_width", 18)
		action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_button.toggle_mode = true
		action_buttons[action] = action_button
		var terrain := PackedStringArray()
		for biome in definition.biomes:
			terrain.append(BIOMES[biome])
		action_button.tooltip_text = "Cijena: %s\nTeren: %s\nOdržavanje / 5s: %s" % [cost_text(definition.cost), ", ".join(terrain), cost_text(definition.inputs)]
	label(build_column, "Odaberi objekat, zatim mjesto na svojoj teritoriji.", 12).modulate = Color("adc0ce")
	build_panel.hide()
	market_panel = panel(root, Vector4(-300, 96, -16, 290), Vector4(1, 0, 1, 0))
	var market_column := VBoxContainer.new()
	market_panel.add_child(market_column)
	var market_header := HBoxContainer.new()
	market_column.add_child(market_header)
	label(market_header, "Trgovina", 18).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(market_header, "×", func(): market_panel.hide())
	trade_resource = OptionButton.new()
	for resource in World.RESOURCE_NAMES:
		trade_resource.add_item(NAMES[resource])
	trade_resource.item_selected.connect(func(_index: int): action_selected.emit(current_action))
	market_column.add_child(trade_resource)
	label(market_column, "Količina: 10", 12)
	var trade_row := HBoxContainer.new()
	market_column.add_child(trade_row)
	buy_button = button(trade_row, "Kupi", func(): trade_requested.emit(true, World.RESOURCE_NAMES[trade_resource.selected]))
	sell_button = button(trade_row, "Prodaj", func(): trade_requested.emit(false, World.RESOURCE_NAMES[trade_resource.selected]))
	menu_panel = panel(root, Vector4(-300, 96, -16, 390), Vector4(1, 0, 1, 0))
	var menu_column := VBoxContainer.new()
	menu_panel.add_child(menu_column)
	button(menu_column, "Cijela mapa", func(): menu_panel.hide(); overview_requested.emit())
	button(menu_column, "Moje naselje", func(): menu_panel.hide(); home_requested.emit())
	button(menu_column, "Kako igrati", show_help)
	status = label(menu_column, "", 12)
	seed_input = LineEdit.new()
	seed_input.text = "260926"
	seed_input.tooltip_text = "Seed za novu mapu"
	menu_column.add_child(seed_input)
	button(menu_column, "Nova partija", func():
		if seed_input.text.is_valid_int():
			reset_dialog.popup_centered()
		else:
			toast("Seed mora biti cijeli broj."))
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.ok_button_text = "Nova partija"
	reset_dialog.cancel_button_text = "Odustani"
	reset_dialog.dialog_text = "Nova partija briše trenutnu teritoriju, građevine i zalihe. Nastaviti?"
	reset_dialog.confirmed.connect(func(): menu_panel.hide(); new_world_requested.emit(int(seed_input.text)))
	root.add_child(reset_dialog)
	market_panel.hide()
	menu_panel.hide()
	feedback = label(root, "", 14)
	feedback.anchor_left = 0.5
	feedback.anchor_right = 0.5
	feedback.offset_left = -300
	feedback.offset_right = 300
	feedback.offset_top = 98
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_color_override("font_color", Color("f3faf8"))
	feedback.add_theme_color_override("font_shadow_color", Color("15232d"))
	feedback.add_theme_constant_override("shadow_offset_x", 1)
	feedback.add_theme_constant_override("shadow_offset_y", 1)
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE

var current_action := "inspect"

func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	for type in ["Label", "Button", "LineEdit", "OptionButton"]:
		theme.set_color("font_color", type, Color("e0eaf0"))
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Color.WHITE)
		theme.set_color("font_disabled_color", type, Color("75838f"))
		if type == "Label":
			continue
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("293d4b") if state in ["normal", "disabled"] else Color("356d66")
			style.set_corner_radius_all(6)
			style.set_content_margin_all(9)
			if state == "focus":
				style.bg_color = Color.TRANSPARENT
				style.border_color = Color("75bbae")
				style.set_border_width_all(1)
			theme.set_stylebox(state, type, style)
	return theme

func panel(parent: Control, offsets: Vector4, anchors: Vector4) -> PanelContainer:
	var result := PanelContainer.new()
	parent.add_child(result)
	result.anchor_left = anchors.x
	result.anchor_top = anchors.y
	result.anchor_right = anchors.z
	result.anchor_bottom = anchors.w
	result.offset_left = offsets.x
	result.offset_top = offsets.y
	result.offset_right = offsets.z
	result.offset_bottom = offsets.w
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.12, 0.16, 0.96)
	style.border_color = Color("344954")
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	result.add_theme_stylebox_override("panel", style)
	return result

func label(parent: Node, value: String, size: int = 14) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size)
	parent.add_child(result)
	return result

func button(parent: Node, value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func toggle_popup(target: Control) -> void:
	var opening := not target.visible
	for popup in [build_panel, market_panel, menu_panel]:
		popup.hide()
	target.visible = opening
	refresh_popups()

func refresh_popups() -> void:
	quote_panel.visible = current_action != "inspect" and not build_panel.visible

func toast(message: String) -> void:
	feedback.text = message
	toast_time = 5.0
	feedback.show()

func advance(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	feedback.visible = toast_time > 0

func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for resource in cost:
		parts.append("$%d" % cost[resource] if resource == "Money" else "%d %s" % [cost[resource], NAMES[resource]])
	return " · ".join(parts) if not parts.is_empty() else "—"

func brief_reason(quote: Dictionary) -> String:
	var reason: String = quote.reason
	if reason.begins_with("Choose unclaimed"):
		return "Odaberi zemlju uz svoju granicu."
	if reason.begins_with("Build only"):
		return "Odaberi polje unutar svoje teritorije."
	if reason.begins_with("This tile"):
		return "Polje je zauzeto."
	if reason.begins_with("Wrong terrain"):
		var hints := {"farm": "Farma treba ravnicu.", "lumber": "Pilana treba šumu.", "quarry": "Kamenolom treba planine.", "mine": "Rudnik treba planine.", "oil": "Nafta traži nalazište u pustinji.", "well": "Bunar gradi na kopnu.", "house": "Kuće gradi na prohodnom kopnu."}
		return hints.get(current_action, "Odaberi odgovarajući teren.")
	if reason.begins_with("Not enough workers"):
		return "Nema radnika. Izgradi kuće."
	if reason.begins_with("Not enough resources"):
		return "Nedovoljno resursa."
	if reason.begins_with("No "):
		return "Ovdje nema potrebnog resursa."
	return "Odaberi polje na mapi."

func refresh(world: RefCounted, economy: RefCounted, cell: Vector2i, action: String, quote: Dictionary, paused: bool, speed: int) -> void:
	current_action = action
	var player: Dictionary = world.players[1]
	for resource in Economy.NAMES:
		stock_labels[resource].text = str(player.stock[resource])
		var change: int = player.delta.get(resource, 0)
		delta_labels[resource].text = "%+d" % change if change != 0 else ""
		delta_labels[resource].add_theme_color_override("font_color", Color("f3a593") if change < 0 else Color("83d2b2"))
		stock_labels[resource].add_theme_color_override("font_color", Color("f0bd77") if resource in ["Food", "Water"] and player.stock[resource] < 10 else Color("e0eaf0"))
	stats.text = "Radnici  %d / %d\nTeritorija  %d polja" % [player.workers, player.population, economy.territory_size(world, 1)]
	stats.tooltip_text = "Stanovništvo: %d\nPorez: $%d / 5s\nPotrošnja: %d hrane + %d vode / 5s\n%s" % [player.population, 15 + int((player.population - 12) / 4) * 3, ceili(player.population / 6.0), ceili(player.population / 6.0), "Nestašica: porez je smanjen na $4." if not player.warning.is_empty() else ""]
	if not player.warning.is_empty():
		stats.text += "\n! Nedostaje hrana ili voda"
	status.text = "Seed %d · Ciklus %d" % [world.world_seed, world.tick]
	pause_button.text = "▶" if paused else "II"
	speed_button.text = "%d×" % speed
	var resource: String = World.RESOURCE_NAMES[trade_resource.selected]
	var price: int = Economy.SELL_PRICE[resource] * 10
	buy_button.text = "Kupi 10 · $%d" % (price + 20)
	sell_button.text = "Prodaj 10 · $%d" % price
	buy_button.disabled = player.stock.Money < price + 20
	sell_button.disabled = player.stock[resource] < 10
	var tile: Dictionary = world.tile(cell)
	var building: Dictionary = economy.building_at(world, cell)
	information.text = BIOMES[tile.biome] + (" · Tvoje" if world.ownership.get(cell, 0) == 1 else " · Slobodno")
	if not building.is_empty():
		information.text = ACTIONS[building.kind] + (" · Radi" if building.status == "Active" else " · Spremno" if building.status == "Ready" else " · Zastoj")
		var definition: Dictionary = Economy.DEFINITIONS[building.kind]
		information.text += "\n+%d %s / 5s" % [building.output, NAMES[definition.resource]] if definition.resource != "" else "\n+4 stanovnika"
		information.tooltip_text = "Održavanje / 5s: " + cost_text(definition.inputs)
	else:
		var potentials := PackedStringArray()
		for index in World.RESOURCE_NAMES.size():
			if tile.resources[index] >= 3:
				potentials.append("%s %d/5" % [NAMES[World.RESOURCE_NAMES[index]], tile.resources[index]])
		information.text += "\n" + " · ".join(potentials.slice(0, 2))
		information.tooltip_text = "Polje %d:%d · Potencijal, ne zaliha\n" % [cell.x, cell.y]
		for index in World.RESOURCE_NAMES.size():
			information.tooltip_text += "%s: %d/5\n" % [NAMES[World.RESOURCE_NAMES[index]], tile.resources[index]]
	for key in action_buttons:
		action_buttons[key].set_pressed_no_signal(key == action)
	build_button.text = ACTIONS[action] if Economy.DEFINITIONS.has(action) else "Gradnja"
	confirm_button.disabled = not quote.ok
	confirm_button.text = "Proširi" if action == "expand" else "Izgradi"
	quote_label.text = cost_text(quote.cost) + "\n"
	if quote.ok:
		quote_label.text += "+%d polja" % quote.cells.size() if action == "expand" else "+4 stanovnika" if action == "house" else "+%d %s / 5s" % [quote.output, NAMES[Economy.DEFINITIONS[action].resource]]
	else:
		quote_label.text += brief_reason(quote)
	quote_label.tooltip_text = ""
	if Economy.DEFINITIONS.has(action):
		var definition: Dictionary = Economy.DEFINITIONS[action]
		var terrain := PackedStringArray()
		for biome in definition.biomes:
			terrain.append(BIOMES[biome])
		quote_label.tooltip_text = "Teren: %s\nOdržavanje / 5s: %s\nRadnici: %d" % [", ".join(terrain), cost_text(definition.inputs), definition.workers]
	refresh_popups()

func show_help() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Kako igrati"
	dialog.ok_button_text = "U redu"
	dialog.dialog_text = "Povuci mišem za kretanje, točkić za zoom.\n\nŠirenje → klik uz granicu → Proširi.\nGradnja → objekat → vlastito polje → Izgradi.\nTrgovina → resurs → Kupi / Prodaj.\n\nPočni s bunarom i farmom.\nZadrži miš iznad dugmeta za cijenu i detalje.\nEscape otkazuje akciju. Partija se još ne sprema."
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
