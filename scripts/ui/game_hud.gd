extends CanvasLayer

signal action_selected(action: String)
signal confirmed
signal trade_requested(buying: bool, resource: String)
signal pause_requested
signal speed_requested
signal home_requested
signal overview_requested
signal new_world_requested(seed_value: int)
signal building_dropped(action: String, screen_position: Vector2)
signal building_hovered(action: String, screen_position: Vector2)
signal building_drag_started
signal building_drag_ended
signal enemy_requested
signal attack_fraction_changed(value: float)
signal retreat_requested
signal training_requested
signal radial_requested
signal expansion_size_changed(value: int)
signal equipment_requested

const World = preload("res://scripts/world/world_data.gd")
const Economy = preload("res://scripts/systems/economy.gd")
const Icons = preload("res://scripts/ui/hud_icons.gd")
const Art = preload("res://scripts/ui/building_art.gd")
const Design = preload("res://scripts/ui/design.gd")
const NAMES := {"Money": "Novac", "Food": "Hrana", "Wood": "Drvo", "Stone": "Kamen", "Iron": "Željezo", "Oil": "Nafta", "Water": "Voda"}
const ACTIONS := {"inspect": "Naselje", "expand": "Front", "attack": "Napad", "barracks": "Kasarna", "fort": "Utvrda", "farm": "Farma", "lumber": "Pilana", "quarry": "Kamenolom", "mine": "Rudnik", "well": "Bunar", "house": "Kuće", "oil": "Nafta"}
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
var cycle_bar: ProgressBar
var cycle_label: Label
var army_label: Label
var objective_label: Label
var training_button: Button
var retreat_button: Button
var context_button: Button
var attack_fraction: OptionButton
var result_dialog: AcceptDialog
var upgrade_context := false
var build_cost_labels := {}

func _ready() -> void:
	preload("res://scripts/ui/compact_layout.gd").build(self)

var current_action := "inspect"

func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = Design.body()
	theme.default_font_size = 16
	for type in ["Label", "Button", "LineEdit", "OptionButton"]:
		theme.set_color("font_color", type, Design.CREAM)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Color.WHITE)
		theme.set_color("font_disabled_color", type, Design.DISABLED)
		if type == "Label":
			continue
		theme.set_stylebox("normal", type, Design.box(Design.BUTTON_BG, Design.PANEL_BORDER))
		theme.set_stylebox("hover", type, Design.box(Design.BUTTON_HOVER, Design.CREAM_DIM))
		theme.set_stylebox("pressed", type, Design.box(Design.BUTTON_DOWN, Design.CREAM))
		theme.set_stylebox("disabled", type, Design.box(Design.PANEL_DEEP, Design.PANEL_BORDER))
		theme.set_stylebox("focus", type, Design.box(Color.TRANSPARENT, Design.CREAM))
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
	result.add_theme_stylebox_override("panel", Design.box(Color(Design.PANEL_BG, 0.97), Design.PANEL_BORDER, 2, 12))
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
	quote_panel.visible = current_action in ["expand", "attack"]

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
		return "Nema slobodnih radnika. Izgradi kuće (+4 radnika)."
	if reason.begins_with("Not enough resources"):
		return "Nedostaje: " + cost_text(quote.get("missing", {}))
	if reason.begins_with("No "):
		return "Ovdje nema potrebnog resursa."
	if not reason.begins_with("Select an action"):
		return reason
	return "Odaberi polje na mapi."

func refresh(world: RefCounted, economy: RefCounted, cell: Vector2i, action: String, quote: Dictionary, paused: bool, speed: int) -> void:
	current_action = action
	var player: Dictionary = world.players[1]
	for kind in build_cost_labels:
		action_buttons[kind].tooltip_text = "Klikni za postavljanje · desni klik odustaje\nCijena: " + cost_text(economy.construction_cost(world, 1, kind)) + "\nDodijeljeni radnici: %d" % Economy.DEFINITIONS[kind].workers
		for resource in build_cost_labels[kind]:
			var needed: int = economy.construction_cost(world, 1, kind)[resource]
			var owned: int = player.stock[resource]
			var missing := maxi(0, needed - owned)
			var cost_label: Label = build_cost_labels[kind][resource]
			cost_label.text = "%d/%d" % [owned, needed]
			cost_label.tooltip_text = "%s: imaš %d, treba %d; fali %d" % [NAMES[resource], owned, needed, missing]
			cost_label.modulate = Color("f3a593") if missing > 0 else Color("83d2b2")
	for resource in Economy.NAMES:
		stock_labels[resource].text = str(player.stock[resource])
		var change: int = player.delta.get(resource, 0)
		stock_labels[resource].tooltip_text = "%s: %d · Neto promjena prošlog ciklusa: %+d / 5s (nakon potrošnje)" % [NAMES[resource], player.stock[resource], change]
		delta_labels[resource].text = "%+d" % change if change != 0 else ""
		delta_labels[resource].add_theme_color_override("font_color", Color("f3a593") if change < 0 else Color("83d2b2"))
		stock_labels[resource].add_theme_color_override("font_color", Color("f0bd77") if resource in ["Food", "Water"] and player.stock[resource] < 10 else Color("e0eaf0"))
	stats.text = "Radnici %d/%d" % [maxi(0, player.population - player.workers), player.population]
	stats.tooltip_text = "Stanovništvo: %d\nPorez: $%d / 5s\nPotrošnja: %d hrane + %d vode / 5s\n%s" % [player.population, 15 + int((player.population - 12) / 4) * 3, ceili(player.population / 6.0), ceili(player.population / 6.0), "Nestašica: porez je smanjen na $4." if not player.warning.is_empty() else ""]
	if not player.warning.is_empty():
		stats.modulate = Color("efbd7b")
	else:
		stats.modulate = Color.WHITE
	status.text = "Seed %d · Ciklus %d" % [world.world_seed, world.tick]
	pause_button.text = ""
	pause_button.icon = Icons.scaled("play" if paused else "pause", 1)
	if paused:
		cycle_label.text = "Pauzirano · pritisni ▶ za proizvodnju"
	speed_button.text = "%d×" % speed
	var resource: String = World.RESOURCE_NAMES[trade_resource.selected]
	var price: int = Economy.SELL_PRICE[resource] * 10
	buy_button.text = "Kupi 10 · $%d" % (price + 20)
	sell_button.text = "Prodaj 10 · $%d" % price
	buy_button.disabled = player.stock.Money < price + 20
	sell_button.disabled = player.stock[resource] < 10
	var tile: Dictionary = world.tile(cell)
	var building: Dictionary = economy.building_at(world, cell)
	var owner: int = world.ownership.get(cell, 0)
	upgrade_context = owner == 1 and building.get("kind", "") == "barracks"
	context_button.visible = upgrade_context
	context_button.text = "Oprema +20%"
	information.text = BIOMES[tile.biome] + (" · Tvoje" if owner == 1 else " · Protivnik" if owner != 0 else " · Slobodno")
	if not building.is_empty():
		information.text = ACTIONS[building.kind] + (" · Radi" if building.status == "Active" else " · Spremno" if building.status == "Ready" else " · Zastoj")
		var definition: Dictionary = Economy.DEFINITIONS[building.kind]
		information.text += "\n+%d %s / 5s" % [building.output, NAMES[definition.resource]] if definition.resource != "" else "\n" + special_output(building.kind)
		if owner != 1:
			information.text = "Protivnik · " + information.text
		if building.status.begins_with("Stopped"):
			information.text = ACTIONS[building.kind] + " · Zastoj\nNedostaje: " + cost_text(building.get("missing", {}))
			var missing: Dictionary = building.get("missing", {})
			information.text += "\nIzgradi bunar ili kupi vodu." if missing.has("Water") else "\nIzgradi farmu ili kupi hranu." if missing.has("Food") else "\nSačekaj porez ili prodaj resurse."
		elif definition.resource != "" and building.status == "Active":
			information.text += "\nDodano u zalihe: +%d" % building.get("last_output", 0)
		information.tooltip_text = "Održavanje / 5s: " + cost_text(definition.inputs)
		if building.get("remaining", 0.0) > 0:
			information.text = ACTIONS[building.kind] + " · Gradnja %ds" % ceili(building.remaining)
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
	build_button.tooltip_text = "Gradnja"
	confirm_button.disabled = not quote.ok
	attack_fraction.visible = action == "attack"
	confirm_button.text = "Napadni" if action == "attack" else "+%d polja" % quote.cells.size() if action == "expand" else "Gradi"
	confirm_button.tooltip_text = cost_text(quote.cost) + "\n" + (quote.reason if action == "attack" else brief_reason(quote) if not quote.ok else "")
	quote_label.text = cost_text(quote.cost) + "\n"
	var missing: Dictionary = economy.missing_inputs(player.stock, quote.cost)
	quote.missing = missing
	if action == "attack":
		quote_label.text = quote.reason
	elif quote.ok:
		quote_label.text += "+%d polja" % quote.cells.size() if action == "expand" else special_output(action) if Economy.DEFINITIONS[action].resource == "" else "+%d %s / 5s" % [quote.output, NAMES[Economy.DEFINITIONS[action].resource]]
	else:
		quote_label.text += brief_reason(quote)
	quote_label.tooltip_text = ""
	if Economy.DEFINITIONS.has(action):
		var definition: Dictionary = Economy.DEFINITIONS[action]
		var terrain := PackedStringArray()
		for biome in definition.biomes:
			terrain.append(BIOMES[biome])
		quote_label.tooltip_text = "Teren: %s\nOdržavanje / 5s: %s\nTrajno dodijeljeni radnici: %d" % [", ".join(terrain), cost_text(definition.inputs), definition.workers]
	refresh_popups()

func special_output(kind: String) -> String:
	return {"house": "+4 stanovnika", "barracks": "+2 vojnika / 5s · $4 + 2 hrane", "fort": "Zid: 5 rubnih polja · odbrana +8"}.get(kind, "")

func refresh_war(world: RefCounted, war: RefCounted) -> void:
	if not world.armies.has(1):
		army_label.text = "Protivnik nije dostupan na ovoj mapi"
		return
	var army: Dictionary = world.armies[1]
	var away: int = war.deployed(world, 1)
	army_label.text = "Vojska %d/%d" % [army.troops, war.capacity(world, 1)]
	army_label.tooltip_text = army.warning + "\nHrana: 1 na 12 vojnika / 5s. Novac: $1 na 15 vojnika / 5s.\nRezerva automatski brani granice. Utvrde pojačavaju okolnu odbranu."
	army_label.tooltip_text += "\nU napadu: %d · Poginuli: %d\nOprema: nivo %d / 2." % [away, army.get("losses", 0), army.get("equipment", 0)]
	if upgrade_context:
		var level: int = army.get("equipment", 0)
		context_button.text = "Oprema %d → %d" % [level, level + 1] if level < 2 else "Oprema: maksimum"
		context_button.tooltip_text = "Napad i odbrana +20% po nivou.\n" + cost_text(war.upgrade_cost(world, 1))
		context_button.disabled = level >= 2 or not Economy.new().affordable(world.players[1].stock, war.upgrade_cost(world, 1)) or world.winner != 0
	else:
		context_button.disabled = false
	training_button.text = "Obuka: DA" if army.training else "Obuka: NE"
	retreat_button.disabled = away == 0 or world.winner != 0
	if world.winner != 0:
		cycle_label.text = "Partija završena · nova partija u meniju …"
		objective_label.text = "POBJEDA · Osvojio si glavni grad!" if world.winner == 1 else "PORAZ · Tvoj glavni grad je osvojen."
	elif not army.warning.is_empty():
		objective_label.text = army.warning + " Fali: " + cost_text(army.get("missing", {}))
	else:
		objective_label.text = "NAPAD: klik crvene granice → udio vojske → Napadni. ODBRANA: rezerva + zid."

func show_help() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Kako igrati"
	dialog.ok_button_text = "U redu"
	dialog.dialog_text = "CILJ: osvoji crveni glavni grad, sačuvaj svoj.\n\nPovuci mapu za kretanje, točkić za zoom.\nIkonica kuće vraća kameru; pregled fronta je u meniju ⋯.\nDesni klik / Escape zatvara trenutnu akciju.\n\nKlik na svoje kopno otvara gradnju. Objekti zauzimaju 2×2 polja.\nPrevuci objekat na kopno: zelen okvir dozvoljava gradnju.\nDvoklik plaća širenje: jedno polje svakih 0,15 sekundi.\nIkonica širenja širi u svim smjerovima; meni bira 20/40/80 polja.\nGradnja desno: imaš / treba; pređi mišem za tačan manjak.\nGrađevine rade tek kad završi tajmer.\n\nPočni: bunar → farma → pilana → kasarna.\nKasarna obučava vojsku; hrana i novac održavaju vojsku.\nOdaberi kasarnu pa meni ⋯ za opremu (+20% po nivou).\nUtvrda gradi zid na 5 rubnih polja i prati granicu.\nRezerva vojske automatski brani; zid jača svoja polja.\n\nKlik na crvenu granicu → 25/50/75% vojske → Napadni.\nOstatak automatski brani teritoriju. Povuci napad vraća preživjele.\nNapad gura širi front; obje strane gube vojnike.\nTačkice iz kasarne prikazuju kretanje prema frontu.\n\nPrva gradnja ili širenje pokreće oba igrača.\nPauza zaustavlja i protivnika. Partija se još ne sprema."
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
