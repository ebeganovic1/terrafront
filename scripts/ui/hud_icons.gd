extends RefCounted

const PATHS := {
	"Money": '<circle cx="12" cy="12" r="8"/><path d="M15 8h-4a2 2 0 0 0 0 4h2a2 2 0 0 1 0 4H9m3-10v12"/>',
	"Food": '<path d="M12 21V4m0 6C5 10 5 4 5 4c7 0 7 6 7 6Zm0 5c7 0 7-6 7-6-7 0-7 6-7 6Zm0 4c-7 0-7-6-7-6 7 0 7 6 7 6Z"/>',
	"Wood": '<path d="m4 8 12-4 4 4-12 4Zm0 0v9l4 4 12-4V8M8 12v9"/>',
	"Stone": '<path d="m3 17 3-9 8-4 6 5 1 8-9 4Zm3-9 7 4 7-3m-7 3-1 9"/>',
	"Iron": '<path d="m3 16 4-8h10l4 8-9 4Zm0 0h18M7 8l5 5 5-5m-5 5v7"/>',
	"Oil": '<path d="M12 3C10 7 5 11 5 15a7 7 0 0 0 14 0c0-4-5-8-7-12Z"/><path d="M8 15a4 4 0 0 0 4 4"/>',
	"Water": '<path d="M12 3C10 7 5 11 5 15a7 7 0 0 0 14 0c0-4-5-8-7-12ZM5 15c3-4 10 4 14 0"/>',
	"inspect": '<circle cx="10" cy="10" r="6"/><path d="m15 15 6 6"/>',
	"expand": '<path d="M4 10V4h6m4 0h6v6m0 4v6h-6m-4 0H4v-6m4-2h8m-4-4v8"/>',
	"build": '<path d="m4 21 9-9m-5-6 4-4 9 9-4 4Zm5-3 5 5"/>',
	"market": '<path d="M4 8h16l-4-4m4 12H4l4 4"/>',
	"house": '<path d="m3 11 9-8 9 8M6 9v12h12V9m-9 12v-8h6v8"/>',
	"well": '<path d="M4 20h16M6 20V10h12v10M4 10l8-7 8 7m-8 0v7m-3-4h6"/>',
	"people": '<circle cx="9" cy="7" r="3"/><path d="M3 21v-4a6 6 0 0 1 12 0v4m1-16a3 3 0 0 1 0 6m3 10v-4a5 5 0 0 0-2-4"/>'
}
static var cache := {}

static func get_icon(key: String) -> Texture2D:
	if cache.has(key):
		return cache[key]
	var source: String = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#dce9ee" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' + PATHS.get(key, PATHS.build) + '</g></svg>'
	var image := Image.new()
	image.load_svg_from_string(source)
	var texture := ImageTexture.create_from_image(image)
	cache[key] = texture
	return texture
