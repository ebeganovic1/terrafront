extends RefCounted

static var cache := {}
const SHAPES := {
	"farm": '<rect x="7" y="31" width="49" height="25" rx="3" fill="#887449"/><path d="M12 36h39M12 43h39M12 50h39" stroke="#d9c579" stroke-width="3"/><path d="M11 29V17h23v15" fill="#efe1be"/><path d="m7 18 15-12 17 12z" fill="#ac634e"/><rect x="19" y="21" width="8" height="12" fill="#584c42"/>',
	"lumber": '<rect x="10" y="23" width="34" height="23" rx="2" fill="#ceb98f"/><path d="m5 25 21-17 24 17z" fill="#607c75"/><path d="M17 27v16m11-16v16m10-16v16" stroke="#9a815f" stroke-width="3"/><path d="M14 49h34m-30 7h29" stroke="#785a40" stroke-width="7" stroke-linecap="round"/><circle cx="49" cy="49" r="4" fill="#debd82"/><circle cx="48" cy="55" r="3" fill="#debd82"/>',
	"well": '<ellipse cx="32" cy="45" rx="18" ry="10" fill="#728c91"/><ellipse cx="32" cy="41" rx="18" ry="10" fill="#d1d4c5"/><ellipse cx="32" cy="41" rx="12" ry="6" fill="#5c9fbd"/><path d="M17 40V20m30 20V20" stroke="#897256" stroke-width="5"/><path d="m9 22 22-14 24 14z" fill="#5b8584"/><path d="M32 23v15" stroke="#e8d6af" stroke-width="2"/>',
	"house": '<path d="M12 28h24v27H12z" fill="#dfcda7"/><path d="m7 29 17-17 18 17z" fill="#b97960"/><path d="M33 35h20v20H33z" fill="#ecdcb7"/><path d="m28 36 15-14 15 14z" fill="#647f84"/><path d="M21 55V40h8v15m12-9h6" stroke="#695e50" stroke-width="4"/>',
	"quarry": '<path d="m7 49 7-26 21-9 20 18-5 21z" fill="#87918f"/><path d="m14 23 21 10 20-1M35 33l-6 20" fill="none" stroke="#cbd2c5" stroke-width="3"/><path d="m7 51 13-9 10 13m7-3 6-13 15 10" fill="#bac2b6"/><path d="m18 15 22 20" stroke="#be9864" stroke-width="4"/><path d="m27 12-12 13" stroke="#e0e5d8" stroke-width="5"/>',
	"mine": '<path d="m4 54 14-34 22-12 21 46z" fill="#89938c"/><path d="M19 55V38a13 13 0 0 1 26 0v17" fill="#293a3e" stroke="#c3b18b" stroke-width="5"/><path d="m25 50-7 10m20-10 7 10m-23-6h20" stroke="#a0afb0" stroke-width="2"/><rect x="25" y="43" width="14" height="10" rx="2" fill="#687f86"/>',
	"oil": '<path d="M8 53h49M19 51l11-29 10 29M11 20l36-9 8 8-40 11z" fill="#5b7079" stroke="#d0d6c9" stroke-width="2"/><path d="m45 17 3 32" stroke="#384c53" stroke-width="3"/><rect x="44" y="45" width="11" height="10" rx="2" fill="#967353"/>',
	"barracks": '<rect x="9" y="25" width="44" height="28" rx="2" fill="#d1c5a4"/><path d="m5 27 26-15 27 15z" fill="#9e5f59"/><path d="M18 35h7m14 0h7" stroke="#52646a" stroke-width="5"/><rect x="27" y="38" width="10" height="15" fill="#665c50"/><path d="M45 22V5" stroke="#ddd7bb" stroke-width="2"/><path d="M46 5h12l-4 5H46z" fill="#c88468"/>',
	"fort": '<path d="M11 24h42v30H11z" fill="#8e9d9e"/><path d="M8 14h10v8h8v-8h11v8h8v-8h11v20H8z" fill="#c6cfbf"/><path d="M25 54V43a7 7 0 0 1 14 0v11" fill="#465b61"/><path d="M12 35h10m20 0h10M15 44h6m21 0h6" stroke="#bac6be" stroke-width="3"/>',
	"capital": '<path d="M10 27h44v28H10z" fill="#d8d1b3"/><path d="m5 29 27-20 27 20z" fill="#477d79"/><path d="M19 34v15m26-15v15" stroke="#839b92" stroke-width="5"/><path d="M27 55V39h10v16" fill="#52636a"/><path d="M32 12V2" stroke="#f0e6bf" stroke-width="2"/><path d="M33 2h14l-5 6h-9z" fill="#dfb762"/>'
}

static func icon(kind: String) -> Texture2D:
	if cache.has(kind):
		return cache[kind]
	var source: String = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><ellipse cx="33" cy="55" rx="27" ry="6" fill="#233c3a" opacity=".25"/>' + SHAPES.get(kind, SHAPES.house) + '</svg>'
	var image := Image.new()
	image.load_svg_from_string(source)
	cache[kind] = ImageTexture.create_from_image(image)
	return cache[kind]
