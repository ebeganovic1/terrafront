extends RefCounted

const Economy = preload("res://scripts/systems/economy.gd")
const Art = preload("res://scripts/ui/building_art.gd")
const Icons = preload("res://scripts/ui/hud_icons.gd")
const Design = preload("res://scripts/ui/design.gd")

# Izvorne ikone su 16x16. Crtaju se samo na 16, 32, 48 ... jer svaki drugi
# faktor daje mutne rubove.
static func icon(parent: Node, key: String, factor: int = 1) -> void:
	var image := TextureRect.new()
	image.texture = Icons.scaled(key, factor)
	image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	image.custom_minimum_size = Vector2.ONE * 16 * factor
	parent.add_child(image)

static func round_button(hud: CanvasLayer, root: Control, key: String, top: float, callback: Callable) -> Button:
	var result: Button = hud.button(root, "", callback)
	result.anchor_left = 1
	result.anchor_right = 1
	result.anchor_top = 0.5
	result.anchor_bottom = 0.5
	result.offset_left = -72
	result.offset_right = -16
	result.offset_top = top
	result.offset_bottom = top + 56
	result.icon = Icons.scaled(key, 2)
	result.tooltip_text = "Gradnja" if key == "build" else "Trgovina"
	var states := {
		"normal": [Design.BUTTON_BG, Design.PANEL_BORDER],
		"hover": [Design.BUTTON_HOVER, Design.CREAM_DIM],
		"pressed": [Design.BUTTON_DOWN, Design.CREAM],
		"focus": [Color.TRANSPARENT, Design.CREAM],
	}
	for state in states:
		result.add_theme_stylebox_override(state, Design.box(states[state][0], states[state][1], 2, 10))
	return result

static func build(hud: CanvasLayer) -> void:
	var root := Control.new()
	hud.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = hud.make_theme()
	var drop_surface := preload("res://scripts/ui/building_drop.gd").new()
	root.add_child(drop_surface)
	drop_surface.placement_requested.connect(func(action: String, position: Vector2): hud.building_dropped.emit(action, position))
	drop_surface.placement_hovered.connect(func(action: String, position: Vector2): hud.building_hovered.emit(action, position))
	drop_surface.placement_ended.connect(func(): hud.building_drag_ended.emit())
	hud.dock = hud.panel(root, Vector4(12, -96, -12, -12), Vector4(0, 1, 1, 1))
	var dock_style := hud.dock.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	dock_style.set_content_margin_all(8)
	dock_style.bg_color = Color(Design.PANEL_BG, 0.94)
	hud.dock.add_theme_stylebox_override("panel", dock_style)
	hud.stock_bar = hud.dock
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	hud.dock.add_child(content)
	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 14)
	content.add_child(resources)
	for resource in Economy.NAMES:
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 4)
		group.tooltip_text = hud.NAMES[resource]
		resources.add_child(group)
		icon(group, resource)
		hud.stock_labels[resource] = hud.label(group, "0", 16)
		hud.delta_labels[resource] = hud.label(group, "", 12)
		hud.delta_labels[resource].hide()
	# Gura brojace i kontrole na desni kraj trake.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources.add_child(spacer)
	hud.army_label = hud.label(resources, "", 16)
	hud.stats = hud.label(resources, "", 16)
	var controls := HBoxContainer.new()
	resources.add_child(controls)
	for action in ["inspect", "expand"]:
		var control: Button = hud.button(controls, "", func():
			if action == "inspect": hud.home_requested.emit()
			else: hud.radial_requested.emit())
		control.icon = Icons.get_icon("house" if action == "inspect" else "expand")
		control.tooltip_text = "Moje naselje" if action == "inspect" else "Širenje u svim smjerovima"
		control.toggle_mode = true
		hud.action_buttons[action] = control
	hud.pause_button = hud.button(controls, "Ⅱ", func(): hud.pause_requested.emit())
	hud.pause_button.tooltip_text = "Pauza / nastavak"
	hud.menu_button = hud.button(controls, "", func(): hud.toggle_popup(hud.menu_panel))
	hud.menu_button.icon = Icons.get_icon("menu")
	hud.menu_button.tooltip_text = "Vojska, pregled mape i postavke"
	var lower := HBoxContainer.new()
	content.add_child(lower)
	hud.feedback = hud.label(lower, "", 11)
	hud.feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud.feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.quote_panel = PanelContainer.new()
	hud.quote_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	lower.add_child(hud.quote_panel)
	var order := HBoxContainer.new()
	hud.quote_panel.add_child(order)
	hud.quote_label = hud.label(order, "", 12)
	hud.quote_label.hide()
	hud.attack_fraction = OptionButton.new()
	for percent in [25, 50, 75]:
		hud.attack_fraction.add_item("%d%%" % percent)
	hud.attack_fraction.selected = 1
	hud.attack_fraction.item_selected.connect(func(index: int): hud.attack_fraction_changed.emit([0.25, 0.5, 0.75][index]))
	order.add_child(hud.attack_fraction)
	hud.confirm_button = hud.button(order, "Potvrdi", func(): hud.confirmed.emit())
	hud.button(order, "", func(): hud.action_selected.emit("inspect")).icon = Icons.get_icon("close")
	for control in order.get_children():
		if control is BaseButton:
			for state in ["normal", "hover", "pressed", "focus", "disabled"]:
				var style := control.get_theme_stylebox(state).duplicate() as StyleBoxFlat
				style.set_content_margin_all(4)
				control.add_theme_stylebox_override(state, style)
	hud.quote_panel.hide()
	hud.build_button = round_button(hud, root, "build", -54, func(): hud.toggle_popup(hud.build_panel))
	hud.market_button = round_button(hud, root, "market", 4, func(): hud.toggle_popup(hud.market_panel))
	hud.build_panel = hud.panel(root, Vector4(-418, 120, -78, -94), Vector4(1, 0, 1, 1))
	var build_column := VBoxContainer.new()
	hud.build_panel.add_child(build_column)
	var header := HBoxContainer.new()
	build_column.add_child(header)
	hud.label(header, "GRADNJA", 14).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.button(header, "", func(): hud.build_panel.hide()).icon = Icons.get_icon("close")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_column.add_child(scroll)
	var buildings := VBoxContainer.new()
	buildings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(buildings)
	for kind in ["well", "farm", "lumber", "house", "barracks", "fort", "quarry", "mine", "oil"]:
		var definition: Dictionary = Economy.DEFINITIONS[kind]
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		buildings.add_child(card)
		var control: Button = hud.button(card, "%s  ·  %ds" % [hud.ACTIONS[kind], Economy.BUILD_SECONDS[kind]], func(): hud.action_selected.emit(kind))
		control.icon = Art.icon(kind)
		control.alignment = HORIZONTAL_ALIGNMENT_LEFT
		control.add_theme_constant_override("h_separation", 10)
		control.custom_minimum_size.y = 40
		control.toggle_mode = true
		hud.action_buttons[kind] = control
		var costs := HBoxContainer.new()
		card.add_child(costs)
		hud.build_cost_labels[kind] = {}
		for resource in definition.cost:
			icon(costs, resource)
			hud.build_cost_labels[kind][resource] = hud.label(costs, "", 11)
		control.tooltip_text = "Imaš / treba. Crveno: resurs nedostaje.\nCijena: " + hud.cost_text(definition.cost)
		control.set_drag_forwarding(func(_position: Vector2):
			var preview := TextureRect.new()
			preview.texture = Art.icon(kind)
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.custom_minimum_size = Vector2(32, 32)
			control.set_drag_preview(preview)
			hud.building_drag_started.emit()
			return {"type": "building", "action": kind}, Callable(), Callable())
	hud.build_panel.hide()
	hud.market_panel = hud.panel(root, Vector4(-418, -110, -78, 110), Vector4(1, 0.5, 1, 0.5))
	var market := VBoxContainer.new()
	hud.market_panel.add_child(market)
	hud.label(market, "TRGOVINA · 10 komada", 14)
	hud.trade_resource = OptionButton.new()
	for resource in hud.World.RESOURCE_NAMES:
		hud.trade_resource.add_item(hud.NAMES[resource])
	hud.trade_resource.item_selected.connect(func(_index: int): hud.action_selected.emit(hud.current_action))
	market.add_child(hud.trade_resource)
	hud.buy_button = hud.button(market, "Kupi", func(): hud.trade_requested.emit(true, hud.World.RESOURCE_NAMES[hud.trade_resource.selected]))
	hud.sell_button = hud.button(market, "Prodaj", func(): hud.trade_requested.emit(false, hud.World.RESOURCE_NAMES[hud.trade_resource.selected]))
	hud.button(market, "", func(): hud.market_panel.hide()).icon = Icons.get_icon("close")
	hud.market_panel.hide()
	hud.menu_panel = hud.panel(root, Vector4(-380, -610, -16, -94), Vector4(1, 1, 1, 1))
	var menu_scroll := ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.menu_panel.add_child(menu_scroll)
	var menu := VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.add_child(menu)
	hud.label(menu, "VOJSKA I POSTAVKE", 14)
	hud.training_button = hud.button(menu, "Obuka: DA", func(): hud.training_requested.emit())
	hud.retreat_button = hud.button(menu, "Povuci napad", func(): hud.retreat_requested.emit())
	hud.context_button = hud.button(menu, "Oprema", func(): hud.equipment_requested.emit())
	hud.button(menu, "Pregled fronta", func(): hud.menu_panel.hide(); hud.overview_requested.emit())
	hud.button(menu, "Protivničko naselje", func(): hud.menu_panel.hide(); hud.enemy_requested.emit())
	var budget := OptionButton.new()
	for amount in [20, 40, 80]:
		budget.add_item("Širenje: %d polja" % amount)
	budget.selected = 1
	budget.item_selected.connect(func(index: int): hud.expansion_size_changed.emit([20, 40, 80][index]))
	menu.add_child(budget)
	hud.speed_button = hud.button(menu, "1×", func(): hud.speed_requested.emit())
	hud.status = hud.label(menu, "", 11)
	hud.cycle_label = hud.label(menu, "", 11)
	hud.information = hud.label(menu, "", 11)
	hud.information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.seed_input = LineEdit.new()
	hud.seed_input.text = "260926"
	menu.add_child(hud.seed_input)
	hud.button(menu, "Nova partija", func():
		if hud.seed_input.text.is_valid_int(): hud.reset_dialog.popup_centered())
	hud.button(menu, "Pomoć", hud.show_help)
	hud.menu_panel.hide()
	hud.selection_panel = PanelContainer.new()
	root.add_child(hud.selection_panel)
	hud.selection_panel.hide()
	hud.objective_label = hud.label(menu, "", 11)
	hud.objective_label.hide()
	hud.cycle_bar = ProgressBar.new()
	hud.cycle_bar.max_value = Economy.TICK_SECONDS
	hud.cycle_bar.hide()
	root.add_child(hud.cycle_bar)
	hud.reset_dialog = ConfirmationDialog.new()
	hud.reset_dialog.dialog_text = "Nova partija briše trenutni napredak. Nastaviti?"
	hud.reset_dialog.confirmed.connect(func(): hud.menu_panel.hide(); hud.new_world_requested.emit(int(hud.seed_input.text)))
	root.add_child(hud.reset_dialog)
	hud.result_dialog = AcceptDialog.new()
	hud.result_dialog.title = "Kraj partije"
	root.add_child(hud.result_dialog)
