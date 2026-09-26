extends Node2D

const World = preload("res://scripts/world/world_data.gd")
const Generator = preload("res://scripts/world/world_generator.gd")
const Renderer = preload("res://scripts/map/world_renderer.gd")
const Territory = preload("res://scripts/map/territory_renderer.gd")
const StrategyCamera = preload("res://scripts/camera/strategy_camera.gd")
const Economy = preload("res://scripts/systems/economy.gd")
const HUD = preload("res://scripts/ui/game_hud.gd")
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
	regenerate(260926)

func _process(delta: float) -> void:
	if hud != null:
		hud.advance(delta)
	if world == null or paused or hud.reset_dialog.visible:
		return
	elapsed += delta * speed
	if elapsed >= Economy.TICK_SECONDS:
		while elapsed >= Economy.TICK_SECONDS:
			elapsed -= Economy.TICK_SECONDS
			economy.step(world)
		refresh_ui()

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
	selected_action = "inspect"
	camera.zoom = Vector2.ONE * 0.85
	focus_settlement()
	inspect(world.settlements[0].cell)
	for popup in [hud.build_panel, hud.market_panel, hud.menu_panel, hud.selection_panel]:
		popup.hide()
	hud.toast("Počni s bunarom i farmom. Otvori Gradnja.")

func focus_settlement() -> void:
	if world != null:
		camera.position = (Vector2(world.settlements[0].cell) + Vector2.ONE * 0.5) * World.TILE_SIZE

func show_overview() -> void:
	var available := get_viewport_rect().size - Vector2(290, 220)
	var dimensions := Vector2(World.WIDTH, World.HEIGHT) * World.TILE_SIZE
	camera.zoom = Vector2.ONE * clampf(minf(available.x / dimensions.x, available.y / dimensions.y), 0.08, 2.5)
	camera.position = dimensions * 0.5 - Vector2(115, -10) / camera.zoom

func inspect_position(world_position: Vector2) -> void:
	var cell := Vector2i((world_position / World.TILE_SIZE).floor())
	if world.contains(cell):
		inspect(cell)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_HOME:
			focus_settlement()
		elif event.keycode == KEY_ESCAPE:
			for popup in [hud.build_panel, hud.market_panel, hud.menu_panel, hud.selection_panel]:
				popup.hide()
			select_action("inspect")

func inspect(cell: Vector2i) -> void:
	selected = cell
	hud.selection_panel.show()
	refresh_ui()

func select_action(action: String) -> void:
	selected_action = action
	if action == "inspect" or action == "expand":
		hud.build_panel.hide()
	refresh_ui()

func confirm_action() -> void:
	var result := economy.execute(world, PLAYER_ID, selected_action, selected)
	if result.ok:
		hud.toast("Teritorija +%d polja" % result.cells.size() if selected_action == "expand" else "Izgrađeno: " + HUD.ACTIONS[selected_action])
	else:
		hud.toast(hud.brief_reason(result))
	territory.queue_redraw()
	refresh_ui()

func trade(buying: bool, resource: String) -> void:
	var completed := economy.trade(world, PLAYER_ID, resource, buying)
	hud.toast(("Kupljeno: " if buying else "Prodano: ") + "10 " + HUD.NAMES[resource] if completed else "Nedovoljno novca ili resursa.")
	refresh_ui()

func refresh_ui() -> void:
	if world == null:
		return
	current_quote = economy.quote(world, PLAYER_ID, selected_action, selected)
	hud.refresh(world, economy, selected, selected_action, current_quote, paused, speed)
	queue_redraw()

func _draw() -> void:
	if selected.x < 0:
		return
	for cell in current_quote.get("cells", []):
		draw_rect(Rect2(Vector2(cell) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color(0.94, 0.78, 0.25, 0.35))
	draw_rect(Rect2(Vector2(selected) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color("fff4bd"), false, 2.0)
