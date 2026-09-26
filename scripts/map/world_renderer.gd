extends Node2D

# Teren se crta u paleti iz dizajna (tools/generator). Svako polje dobije mali
# 4x4 uzorak umjesto jedne pune boje, pa trava, dine, valovi i stijena imaju
# teksturu kao na predlosku. Uzorci su unaprijed pripremljeni, a slika se slaze
# jednim blit-om po polju, pa cijela mapa nastaje za oko 50 ms.

const World = preload("res://scripts/world/world_data.gd")
const Design = preload("res://scripts/ui/design.gd")

const SUB := 4

var world: RefCounted
var ground: Sprite2D

static var patch_cache := {}

# Cetiri nijanse po biomu, istim redoslijedom kao World.BIOMES.
static func palette(biome: int) -> Array:
	match biome:
		0: return Design.MORE
		1, 2: return [Design.MORE[1], Design.MORE[2], Design.MORE[3], Design.MORE[2]]
		3: return Design.OBALA
		4: return Design.TRAVA
		5: return Design.CETINAR
		6: return Design.STIJENA
		7: return Design.PUSTINJA
		8: return Design.MOCVARA
		9: return Design.SNIJEG
	return Design.TRAVA

# Cetiri varijante po biomu da susjedna polja ne ponavljaju isti uzorak.
static func build_patches(biome: int) -> Array:
	var colors := palette(biome)
	var variants: Array = []
	for variant in 4:
		var image := Image.create(SUB, SUB, false, Image.FORMAT_RGB8)
		for y in SUB:
			for x in SUB:
				var shade := 1
				match biome:
					0, 1, 2:
						# Voda: kratke vodoravne crtice kao valovi.
						shade = 0 if variant < 2 else 1
						if y == (variant + 1) % SUB and x < 2:
							shade = 3
					3:
						shade = 2 if (x * 2 + y + variant) % 3 else 1
					4, 8:
						# Trava i mocvara: busenovi svjetlije i tamnije.
						shade = 1 + ((x + y + variant) % 2)
						if (x * 3 + y * 5 + variant * 7) % 11 == 0:
							shade = 3
						elif (x * 5 + y * 3 + variant * 2) % 13 == 0:
							shade = 0
					5:
						# Suma: gusta krosnja s tamnim obrisima.
						shade = 2 if (x + y + variant) % 3 else 1
						if (x * 2 + y + variant) % 5 == 0:
							shade = 0
						elif (x + y * 2 + variant) % 7 == 0:
							shade = 3
					6:
						# Stijena: mrlje i poneki svijetli greben.
						shade = 1 if (x + y * 2 + variant) % 4 else 0
						if (x * 3 + y + variant) % 9 == 0:
							shade = 2
					7:
						# Pustinja: kose dine.
						shade = 2 if ((x + y + variant * 2) % SUB) < 2 else 1
						if (y + variant) % SUB == 0:
							shade = 3
					9:
						shade = 2 if (x + y + variant) % 3 else 3
				image.set_pixel(x, y, colors[clampi(shade, 0, colors.size() - 1)])
		variants.append(image)
	return variants

static func patches(biome: int) -> Array:
	if not patch_cache.has(biome):
		patch_cache[biome] = build_patches(biome)
	return patch_cache[biome]

func set_world(value: RefCounted) -> void:
	world = value
	if ground == null:
		ground = Sprite2D.new()
		ground.centered = false
		ground.z_index = -1
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(ground)
	var canvas := Image.create(World.WIDTH * SUB, World.HEIGHT * SUB, false, Image.FORMAT_RGB8)
	var source := Rect2i(0, 0, SUB, SUB)
	var by_biome := []
	for biome in World.BIOMES.size():
		by_biome.append(patches(biome))
	for row in World.HEIGHT:
		for column in World.WIDTH:
			var tile: Dictionary = world.tiles[row * World.WIDTH + column]
			var variants: Array = by_biome[tile.biome]
			var pick := (column * 7 + row * 11 + int(tile.elevation * 97.0)) % variants.size()
			canvas.blit_rect(variants[pick], source, Vector2i(column * SUB, row * SUB))
	ground.texture = ImageTexture.create_from_image(canvas)
	ground.scale = Vector2.ONE * (float(World.TILE_SIZE) / float(SUB))
	queue_redraw()
