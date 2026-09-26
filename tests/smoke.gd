extends SceneTree

const Generator = preload("res://scripts/world/world_generator.gd")
const World = preload("res://scripts/world/world_data.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for seed_value in [260926, 1, 42, 100, -17, 9999]:
		var world := Generator.new().generate(seed_value)
		assert(world.tiles.size() == World.WIDTH * World.HEIGHT)
		assert(world.walkable(world.settlements[0].cell))
		var counts := {}
		for tile in world.tiles:
			counts[tile.biome] = counts.get(tile.biome, 0) + 1
			assert(tile.elevation >= 0 and tile.elevation <= 1)
			assert(tile.resources.size() == 6)
			for value in tile.resources:
				assert(value >= 0 and value <= 5)
		for biome in [0, 1, 2, 4, 5, 6, 7]:
			assert(counts.get(biome, 0) > 0, "Missing required biome %d seed %d" % [biome, seed_value])
		var repeat := Generator.new().generate(seed_value)
		assert(world.tiles == repeat.tiles)
		assert(world.settlements == repeat.settlements)
		print("PASS seed ", seed_value, " biome counts ", counts)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.inspect(Vector2i(0, 0))
	assert(scene.information.text.contains("Biome: Sea"))
	scene.regenerate(42)
	assert(scene.world.world_seed == 42)
	assert(scene.selected == scene.world.settlements[0].cell)
	var zoom_event := InputEventMouseButton.new()
	zoom_event.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_event.pressed = true
	var old_zoom: float = scene.camera.zoom.x
	scene.camera._unhandled_input(zoom_event)
	assert(scene.camera.zoom.x > old_zoom)
	var focus := root.gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	Input.action_press("camera_right")
	var old_position: Vector2 = scene.camera.position
	scene.camera._process(0.1)
	assert(scene.camera.position.x > old_position.x)
	Input.action_release("camera_right")
	scene.regenerate(260926)
	if "--visual" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/preview.png")
	print("PASS scene, inspection, regeneration, zoom and movement")
	quit()
