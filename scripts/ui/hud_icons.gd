extends RefCounted

# Pixel-art ikone iz dizajn-paketa (assets/ikone). Izvorne su 16x16; crtaju se
# nearest-neighbor na cjelobrojnim visekratnicima da ostanu ostre.

const BASE := "res://assets/ikone/"

# Resursi i male ikone zgrada - jedna varijanta, pune boje.
const PUNE := {
	"Money": "resursi/zlato",
	"Food": "resursi/hrana",
	"Wood": "resursi/drvo",
	"Stone": "resursi/kamen",
	"Iron": "resursi/zeljezo",
	"Oil": "resursi/nafta",
	"Water": "resursi/voda",
	"well": "resursi/bunar",
	"farm": "resursi/farma",
	"lumber": "resursi/pilana",
	"quarry": "resursi/kamenolom",
	"mine": "resursi/rudnik",
	"house": "resursi/kuce",
	"oil": "resursi/naftna",
	"barracks": "resursi/kasarna",
	"fort": "resursi/utvrda",
	"capital": "resursi/vijecnica",
	"army": "jedinice/vojska",
	"workers": "jedinice/radnici",
	"people": "jedinice/radnici",
}

# Kontrole - monokromatske siluete, svijetla i tamna varijanta.
const KONTROLE := {
	"home": "dom",
	"inspect": "dom",
	"expand": "sirenje",
	"build": "cekic",
	"market": "trgovina",
	"pause": "pauza",
	"play": "play",
	"speed": "brze",
	"menu": "meni",
	"close": "zatvori",
	"center": "centar",
	"clock": "sat",
	"lock": "brava",
}

static var cache := {}

static func get_icon(key: String, dark: bool = false) -> Texture2D:
	var id := key + ("_t" if dark else "")
	if cache.has(id):
		return cache[id]
	var path := ""
	if KONTROLE.has(key):
		path = BASE + "kontrole/" + KONTROLE[key] + ("_tamna" if dark else "_svijetla") + ".png"
	elif PUNE.has(key):
		path = BASE + PUNE[key] + ".png"
	else:
		path = BASE + "kontrole/cekic_svijetla.png"
	var texture: Texture2D = load(path)
	cache[id] = texture
	return texture

# Cjelobrojno uvecanje nearest-neighbor. Pixel ikona nacrtana na 1.5x je mutna,
# pa se sve velicine u sucelju izvode kao 16 * cijeli broj.
static func scaled(key: String, factor: int, dark: bool = false) -> Texture2D:
	var id := "%s@%d%s" % [key, factor, "_t" if dark else ""]
	if cache.has(id):
		return cache[id]
	var source := get_icon(key, dark)
	if source == null or factor <= 1:
		cache[id] = source
		return source
	var image := source.get_image()
	image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	cache[id] = ImageTexture.create_from_image(image)
	return cache[id]

static func has_icon(key: String) -> bool:
	return KONTROLE.has(key) or PUNE.has(key)
