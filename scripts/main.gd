extends Node2D

const World = preload("res://scripts/world/world_data.gd")
const Generator = preload("res://scripts/world/world_generator.gd")
const Renderer = preload("res://scripts/map/world_renderer.gd")
const Territory = preload("res://scripts/map/territory_renderer.gd")
const StrategyCamera = preload("res://scripts/camera/strategy_camera.gd")
const Economy = preload("res://scripts/systems/economy.gd")
const HUD = preload("res://scripts/ui/game_hud.gd")
const War = preload("res://scripts/systems/war.gd")
const Art = preload("res://scripts/ui/building_art.gd")
const PLAYER_ID := 1
var world: RefCounted
var economy := Economy.new()
var renderer: Node2D
var territory: Node2D
var camera: Camera2D
var hud: CanvasLayer
var selected := Vector2i(-1, -1)
var selected_action := "inspect"
var current_quote: Dictionary = {}
var elapsed := 0.0
var paused := false
var speed := 1
var placement_dragging := false
var war := War.new()
var attack_share := 0.5
var result_shown := false
var ui_elapsed := 0.0
var information: Label:
	get:
		return hud.information
var confirm_button: Button:
	get:
		return hud.confirm_button
var pause_button: Button:
	get:
		return hud.pause_button

func _ready() -> void:
	renderer = Renderer.new()
	renderer.z_index = -1
	add_child(renderer)
	territory = Territory.new()
	add_child(territory)
	camera = StrategyCamera.new()
	add_child(camera)
	camera.tile_clicked.connect(inspect_position)
	camera.tile_double_clicked.connect(expand_position)
	camera.cancel_requested.connect(cancel_selection)
	hud = HUD.new()
	add_child(hud)
	hud.action_selected.connect(select_action)
	hud.confirmed.connect(confirm_action)
	hud.trade_requested.connect(trade)
	hud.pause_requested.connect(func(): paused = not paused; refresh_ui())
	hud.speed_requested.connect(func(): speed = 2 if speed == 1 else 1; refresh_ui())
	hud.home_requested.connect(focus_settlement)
	hud.overview_requested.connect(show_overview)
	hud.new_world_requested.connect(regenerate)
	hud.building_drag_started.connect(func(): camera.cancel_drag(); placement_dragging = true)
	hud.building_hovered.connect(preview_building)
	hud.building_dropped.connect(drop_building)
	hud.building_drag_ended.connect(func(): placement_dragging = false; select_action("inspect"))
	hud.enemy_requested.connect(func(): camera.position = (Vector2(war.capital(world, 2)) + Vector2.ONE) * World.TILE_SIZE)
	hud.radial_requested.connect(func(): selected = war.capital(world, PLAYER_ID); select_action("expand"))
	hud.expansion_size_changed.connect(func(value: int): world.players[PLAYER_ID].expansion_budget = value; refresh_ui())
	hud.attack_fraction_changed.connect(func(value: float): attack_share = value; refresh_ui())
	hud.retreat_requested.connect(func(): war.retreat(world, PLAYER_ID); refresh_ui(); territory.queue_redraw())
	hud.training_requested.connect(func():
		if world.armies.has(1) and world.winner == 0:
			world.armies[1].training = not world.armies[1].training
			refresh_ui())
	hud.equipment_requested.connect(func():
		hud.toast("Oprema unaprijeđena · jači napad i odbrana." if war.upgrade(world, PLAYER_ID) else "Treba kasarna, novac i željezo.")
		refresh_ui())
	if OS.has_feature("web"):
		# WebAssembly generates the 480x336 world noticeably slower than native and
		# blocks the canvas while it runs. Paint a splash first so the first frame
		# is never an empty canvas. Desktop and headless keep the synchronous path
		# the test suite relies on.
		var boot := build_boot_overlay()
		add_child(boot)
		await get_tree().process_frame
		await get_tree().process_frame
		regenerate(260926)
		boot.queue_free()
	else:
		regenerate(260926)

func build_boot_overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 128
	var background := ColorRect.new()
	background.color = Color(0.025, 0.045, 0.065, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var label := Label.new()
	label.text = "TERRAFRONT\n\nGeneriranje svijeta…"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_child(label)
	return layer

func _process(delta: float) -> void:
	if hud != null:
		hud.advance(delta)
		hud.cycle_bar.value = elapsed
	if world == null or paused or hud.reset_dialog.visible or world.winner != 0:
		return
	if not world.war_started:
		hud.cycle_label.text = "Gradnja ili širenje pokreće partiju"
		return
	var changed := economy.advance_expansion(world, delta * speed)
	changed = economy.advance_construction(world, delta * speed) or changed
	changed = war.advance_front(world, delta * speed) or changed
	ui_elapsed += delta
	if changed:
		territory.queue_redraw()
		if ui_elapsed >= 0.15 or world.winner != 0:
			ui_elapsed = 0
			refresh_ui()
	if world.winner != 0:
		show_result()
		return
	elapsed += delta * speed
	hud.cycle_label.text = "Proizvodnja za %.1f s" % (maxf(0, Economy.TICK_SECONDS - elapsed) / speed)
	if elapsed >= Economy.TICK_SECONDS:
		while elapsed >= Economy.TICK_SECONDS:
			elapsed -= Economy.TICK_SECONDS
			var stocks := {}
			for owner in world.players:
				stocks[owner] = world.players[owner].stock.duplicate()
			economy.step(world)
			war.step(world)
			war.ai_step(world)
			for owner in world.players:
				for resource in Economy.NAMES:
					world.players[owner].delta[resource] = world.players[owner].stock[resource] - stocks[owner][resource]
			if world.winner != 0:
				break
		var stopped := 0
		for building in world.buildings:
			if building.owner_id == 1 and building.status.begins_with("Stopped"):
				stopped += 1
		if stopped > 0:
			hud.toast("%d objekata ne proizvodi · klikni objekat za uzrok" % stopped)
		territory.queue_redraw()
		refresh_ui()
		for battle in world.battles:
			if battle.defender == 1:
				hud.objective_label.text = "NAPADNUT SI · klikni Front ili crveni krug na mapi"
		if world.winner != 0:
			show_result()

func show_result() -> void:
	if not result_shown:
		result_shown = true
		hud.result_dialog.dialog_text = "Pobjeda! Protivnički glavni grad je osvojen." if world.winner == 1 else "Poraz. Tvoj glavni grad je osvojen."
		hud.result_dialog.popup_centered()

func preview_building(action: String, screen_position: Vector2) -> void:
	var cell := Vector2i((get_canvas_transform().affine_inverse() * screen_position / World.TILE_SIZE).floor())
	if not world.contains(cell):
		return
	selected = cell
	selected_action = action
	refresh_ui()
	if placement_dragging:
		hud.toast("Pusti za gradnju · " + hud.cost_text(current_quote.cost) if current_quote.ok else hud.brief_reason(current_quote))

func drop_building(action: String, screen_position: Vector2) -> void:
	var cell := Vector2i((get_canvas_transform().affine_inverse() * screen_position / World.TILE_SIZE).floor())
	if not world.contains(cell):
		hud.toast("Spusti objekat na svoje kopno.")
		return
	preview_building(action, screen_position)
	confirm_action()

func expand_position(world_position: Vector2) -> void:
	if Economy.DEFINITIONS.has(selected_action):
		return
	var cell := Vector2i((world_position / World.TILE_SIZE).floor())
	if not world.contains(cell):
		return
	selected = cell
	select_action("expand")
	confirm_action()

func regenerate(seed_value: int) -> void:
	world = Generator.new().generate(seed_value)
	economy.initialize(world, PLAYER_ID)
	war.setup(world)
	result_shown = false
	attack_share = 0.5
	hud.attack_fraction.selected = 1
	hud.result_dialog.hide()
	camera.cancel_drag()
	renderer.set_world(world)
	territory.world = world
	territory.queue_redraw()
	elapsed = 0
	paused = false
	speed = 1
	selected_action = "inspect"
	camera.zoom = Vector2.ONE * 0.85
	focus_settlement()
	inspect(world.settlements[0].cell)
	for popup in [hud.build_panel, hud.market_panel, hud.menu_panel, hud.selection_panel]:
		popup.hide()
	hud.toast_time = 0
	hud.feedback.hide()

func focus_settlement() -> void:
	if world != null:
		camera.position = (Vector2(world.settlements[0].cell) + Vector2.ONE * 0.5) * World.TILE_SIZE

func show_overview() -> void:
	if world.settlements.size() > 1:
		var home := Vector2(war.capital(world, 1)) * World.TILE_SIZE
		var enemy := Vector2(war.capital(world, 2)) * World.TILE_SIZE
		var bounds := Rect2(home, Vector2.ZERO).expand(enemy).grow(280)
		var available := get_viewport_rect().size - Vector2(300, 380)
		camera.zoom = Vector2.ONE * clampf(minf(available.x / bounds.size.x, available.y / bounds.size.y), 0.08, 1.1)
		camera.position = bounds.get_center()
		return
	var available := get_viewport_rect().size - Vector2(80, 120)
	var dimensions := Vector2(World.WIDTH, World.HEIGHT) * World.TILE_SIZE
	camera.zoom = Vector2.ONE * clampf(minf(available.x / dimensions.x, available.y / dimensions.y), 0.08, 2.5)
	camera.position = dimensions * 0.5 - Vector2(115, -10) / camera.zoom

func inspect_position(world_position: Vector2) -> void:
	var cell := Vector2i((world_position / World.TILE_SIZE).floor())
	if Economy.DEFINITIONS.has(selected_action):
		if world.contains(cell):
			selected = cell
			confirm_action()
		return
	if world.contains(cell):
		var owner: int = world.ownership.get(cell, 0)
		if owner != PLAYER_ID or not Economy.DEFINITIONS.has(selected_action) or not economy.building_at(world, cell).is_empty() or economy.capital_at(world, cell) != 0:
			selected_action = "attack" if owner != 0 and owner != PLAYER_ID else "expand" if owner == 0 and not economy.claim_cells(world, PLAYER_ID, cell).is_empty() else "inspect"
			if owner != PLAYER_ID or not economy.building_at(world, cell).is_empty():
				hud.build_panel.hide()
		inspect(cell)
		if selected_action == "inspect" and world.ownership.get(cell, 0) == 1 and economy.building_at(world, cell).is_empty() and economy.capital_at(world, cell) == 0:
			hud.build_panel.show()
			hud.refresh_popups()

func cancel_selection() -> void:
	for popup in [hud.build_panel, hud.market_panel, hud.menu_panel, hud.selection_panel]:
		popup.hide()
	select_action("inspect")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Economy.DEFINITIONS.has(selected_action) and not placement_dragging:
		preview_building(selected_action, event.position)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_HOME:
			focus_settlement()
		elif event.keycode == KEY_ESCAPE:
			cancel_selection()

func inspect(cell: Vector2i) -> void:
	selected = cell
	refresh_ui()
	if not economy.building_at(world, cell).is_empty():
		hud.toast(("Pauzirano · " if paused else "") + hud.information.text.replace("\n", " · "))

func select_action(action: String) -> void:
	selected_action = action
	if action == "inspect" or action == "expand" or Economy.DEFINITIONS.has(action):
		hud.build_panel.hide()
	refresh_ui()

func confirm_action() -> void:
	if world.winner != 0:
		return
	if selected_action == "attack":
		hud.toast("Napad pokrenut. Dio vojske ostaje u odbrani." if war.attack(world, PLAYER_ID, selected, attack_share) else war.quote(world, PLAYER_ID, selected, attack_share).reason)
		refresh_ui()
		territory.queue_redraw()
		return
	var result := economy.execute(world, PLAYER_ID, selected_action, selected)
	if result.ok:
		hud.toast("Širenje · %d polja" % result.cells.size() if selected_action == "expand" else "Gradnja: %s · %ds" % [HUD.ACTIONS[selected_action], Economy.BUILD_SECONDS[selected_action]])
		if selected_action == "expand":
			selected_action = "inspect"
	else:
		hud.toast(hud.brief_reason(result))
	territory.queue_redraw()
	refresh_ui()

func trade(buying: bool, resource: String) -> void:
	if world.winner != 0:
		return
	var completed := economy.trade(world, PLAYER_ID, resource, buying)
	hud.toast(("Kupljeno: " if buying else "Prodano: ") + "10 " + HUD.NAMES[resource] if completed else "Nedovoljno novca ili resursa.")
	refresh_ui()

func refresh_ui() -> void:
	if world == null:
		return
	current_quote = economy.quote(world, PLAYER_ID, selected_action, selected)
	if selected_action == "attack":
		current_quote = war.quote(world, PLAYER_ID, selected, attack_share)
		current_quote.merge({"cost": {}, "cells": [], "output": 0})
	hud.refresh(world, economy, selected, selected_action, current_quote, paused, speed)
	hud.refresh_war(world, war)
	queue_redraw()

func _draw() -> void:
	if selected.x < 0:
		return
	for cell in current_quote.get("cells", []):
		draw_rect(Rect2(Vector2(cell) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color(0.94, 0.78, 0.25, 0.35))
	draw_rect(Rect2(Vector2(selected) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color("fff4bd"), false, 2.0)
	if Economy.DEFINITIONS.has(selected_action) and selected_action != "fort":
		var tint := Color("83d2b2") if current_quote.get("ok", false) else Color("f3a593")
		var bounds := Rect2(Vector2(selected) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE * 2)
		draw_rect(bounds, Color(tint, 0.2))
		draw_rect(bounds, tint, false, 2)
		draw_texture_rect(Art.icon(selected_action), bounds, false)
