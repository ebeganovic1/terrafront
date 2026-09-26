extends RefCounted

# Sprajtovi zgrada 32x32 iz dizajn-paketa (assets/zgrade). Jedna zgrada zauzima
# 2x2 polja, a polje je 16 jedinica, pa se sprajt crta u odnosu 1:1 bez zamucenja.

const BASE := "res://assets/zgrade/"
const SPRAJTOVI := {
	"well": "bunar",
	"farm": "farma",
	"lumber": "pilana",
	"quarry": "kamenolom",
	"mine": "rudnik",
	"house": "kuce",
	"oil": "nafta",
	"barracks": "kasarna",
	"fort": "utvrda",
	"capital": "vijecnica",
	"factory": "fabrika",
	"port": "luka",
	"airport": "aerodrom",
}

static var cache := {}

static func icon(kind: String) -> Texture2D:
	if cache.has(kind):
		return cache[kind]
	var name: String = SPRAJTOVI.get(kind, SPRAJTOVI.house)
	cache[kind] = load(BASE + name + ".png")
	return cache[kind]

# Uvecani sprajt za popis gradnje; nearest-neighbor da rubovi ostanu ostri.
static func scaled(kind: String, factor: int) -> Texture2D:
	var id := "%s@%d" % [kind, factor]
	if cache.has(id):
		return cache[id]
	var source := icon(kind)
	if source == null or factor <= 1:
		cache[id] = source
		return source
	var image := source.get_image()
	image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	cache[id] = ImageTexture.create_from_image(image)
	return cache[id]
