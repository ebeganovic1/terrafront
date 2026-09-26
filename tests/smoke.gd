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
		validate_rivers(world)
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
		assert(world.river_paths == repeat.river_paths)
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
	var old_position: Vector2 = scene.camera.position
	var original_selection: Vector2i = scene.selected
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(700, 450)
	scene.camera._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(780, 480)
	scene.camera._input(motion)
	assert(scene.camera.position.x < old_position.x)
	assert(scene.camera.dragging)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	scene.camera._input(release)
	assert(scene.camera.drag_button == 0)
	assert(scene.selected == original_selection, "Dragging must not select a tile")
	scene.camera._unhandled_input(press)
	release.position = press.position
	scene.camera.force_update_scroll()
	var clicked_world: Vector2 = scene.camera.get_canvas_transform().affine_inverse() * release.position
	var expected_cell := Vector2i((clicked_world / World.TILE_SIZE).floor())
	scene.camera._input(release)
	assert(scene.selected == expected_cell, "Short click must inspect the target tile")
	for button in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		press.button_index = button
		scene.camera._unhandled_input(press)
		scene.camera._input(motion)
		release.button_index = button
		release.position = Vector2(50, 100)
		scene.camera._input(release)
		assert(scene.camera.drag_button == 0, "Release over UI must end dragging")
	press.button_index = MOUSE_BUTTON_LEFT
	scene.camera._unhandled_input(press)
	scene.camera._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(scene.camera.drag_button == 0)
	scene.show_overview()
	assert(scene.camera.zoom.x >= 0.12)
	scene.regenerate(260926)
	if "--visual" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/preview.png")
		scene.show_overview()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/overview.png")
	print("PASS scene, click/drag separation, all mouse buttons, focus loss, zoom and overview")
	quit()

func validate_rivers(world: RefCounted) -> void:
	assert(not world.river_paths.is_empty(), "Expected rivers")
	var covered := {}
	for path in world.river_paths:
		assert(world.tile(path[0]).elevation >= 0.69)
		assert(world.tile(path.back()).biome == 0, "Every river must reach the sea")
		var visited := {}
		for index in path.size():
			var cell: Vector2i = path[index]
			assert(not visited.has(cell), "River must not loop")
			visited[cell] = true
			covered[cell] = true
			assert(world.tile(cell).biome in [0, 1, 2], "River must be unbroken water")
			if index > 0:
				var offset: Vector2i = cell - path[index - 1]
				assert(absi(offset.x) + absi(offset.y) == 1, "River must be cardinally connected")
	for row in World.HEIGHT:
		for column in World.WIDTH:
			var cell := Vector2i(column, row)
			if world.tile(cell).biome == 2:
				assert(covered.has(cell), "No isolated river tiles")
