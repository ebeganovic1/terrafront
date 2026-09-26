extends RefCounted

# Jedinstveni izvor boja, fontova i okvira za pixel-art sucelje.
# Paleta je preuzeta iz generatora dizajna (tools/generator), pa HUD i mapa
# koriste iste boje.

const OUTLINE := Color("1f1a17")
const PANEL_BG := Color("2b211a")
const PANEL_DEEP := Color("1f1a17")
const PANEL_BORDER := Color("6a4424")
const BUTTON_BG := Color("3a2e26")
const BUTTON_HOVER := Color("6a4424")
const BUTTON_DOWN := Color("8a5a30")
const CREAM := Color("efe6cf")
const CREAM_DIM := Color("a8926f")
const GOLD := Color("ecc84e")
const RED := Color("c4453a")
const BLUE := Color("3a89d8")
const GREEN := Color("6fab45")
const DISABLED := Color("6b5a47")

# Boje svijeta, iste kao u generatoru mape.
const TRAVA := [Color("5c9a3a"), Color("68a842"), Color("76b54a"), Color("86c255")]
const PUSTINJA := [Color("dab262"), Color("e4c274"), Color("ecd08a"), Color("f4dea0")]
const MORE := [Color("1f5fae"), Color("2c72c4"), Color("3a89d8"), Color("5aa6e4")]
const STIJENA := [Color("7d848c"), Color("aab0b7"), Color("d9dee4"), Color("f4f6f8")]
const CETINAR := [Color("23552f"), Color("2f6d3a"), Color("3f8a45"), Color("5aa653")]
const PUT := [Color("b89556"), Color("c9a462"), Color("d6b476")]
const ZITO := [Color("c89a2c"), Color("ecc84e"), Color("f6dc78")]
const MOCVARA := [Color("4a7a4e"), Color("57895a"), Color("649866"), Color("74a872")]
const SNIJEG := [Color("dfe5ec"), Color("eaeff4"), Color("f4f6f8"), Color("ffffff")]
const OBALA := [Color("e7c690"), Color("ecd8a0"), Color("f0e0b4"), Color("f4ead0")]

const FONT_BODY := "res://assets/fonts/PixelifySans.ttf"
const FONT_STAT := "res://assets/fonts/Silkscreen-Regular.ttf"
const FONT_STAT_BOLD := "res://assets/fonts/Silkscreen-Bold.ttf"

static var _fonts := {}

static func font(path: String) -> FontFile:
	if _fonts.has(path):
		return _fonts[path]
	var loaded := load(path)
	var result: FontFile = null
	if loaded is FontFile:
		result = (loaded as FontFile).duplicate()
		# Pixel fontovi moraju ostati ostri: bez zaglađivanja i bez podpiksela.
		result.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		result.hinting = TextServer.HINTING_NONE
		result.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		result.generate_mipmaps = false
	_fonts[path] = result
	return result

static func body() -> FontFile:
	return font(FONT_BODY)

static func stat() -> FontFile:
	return font(FONT_STAT)

static func stat_bold() -> FontFile:
	return font(FONT_STAT_BOLD)

static func box(bg: Color, border: Color, width: int = 2, margin: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(margin)
	return style
