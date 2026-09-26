import random, math, os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "assets")
os.makedirs(OUT, exist_ok=True)

def hx(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + (255,)

K = '#1f1a17'
ICONS = {}

def icon(name, pal, rows, pad_top=0):
    rows = ['.' * 16] * pad_top + rows
    rows = rows + ['.' * 16] * (16 - len(rows))
    for i, r in enumerate(rows):
        assert len(r) == 16, (name, i, r, len(r))
    ICONS[name] = (pal, rows)

base = {'k': K}
icon('zlato', {**base, 'Y': '#f4c95a', 'y': '#c98a1f', 'o': '#8a5a12'}, [
"................",
".....kkkkkk.....",
"...kkYYYYYYkk...",
"..kYYyyyyyyYok..",
"..kYyYYYYYYyok..",
".kYyYYYyyYYYyok.",
".kYyYYyYYYYYyok.",
".kYyYYyyyYYYyok.",
".kYyYYYYYyYYyok.",
".kYyYYYYYyYYyok.",
".kYyYYyyyYYYyok.",
"..kYyYYYYYYyok..",
"..kYYyyyyyyyok..",
"...kkooooookk...",
".....kkkkkk.....",
])
icon('hrana', {**base, 'W': '#f0d27a', 'w': '#c9a23a', 'g': '#6f9a3a'}, [
"................",
".......k........",
"......kWk.......",
".....kWwWk......",
".....kWwWk..k...",
".....kWwWk.kWk..",
"..k...kWkkWwWk..",
".kWk..kgk.kWwk..",
".kwWk.kgkkWwk...",
"..kwWkkgkWwk....",
"...kwWkgkwk.....",
"....kkkgkk......",
"......kgk.......",
"......kgk.......",
"......kgk.......",
".......k........",
])
icon('drvo', {**base, 'B': '#b87f48', 'b': '#7a4f2a', 'r': '#e7c690', 'R': '#b88a50'}, [
"..kkkkkkkkkkkk..",
".kBBBBBBBBBkrrk.",
".kbBBbbBBBkrRRrk",
".kBBBBBBbbkrRrRk",
".kbbBBBBBBkrRRrk",
".kBBBbbBBBkrrrrk",
"..kkkkkkkkkkkk..",
], pad_top=5)
icon('kamen', {**base, 'S': '#c6c8ca', 's': '#8d9197', 'd': '#5c6168'}, [
"......kkkkk.....",
"....kkSSSSSkk...",
"...kSSSSSSssdk..",
"..kSSSsSSSSsdk..",
"..kSSSSSSSssddk.",
".kSSsSSSSsssddk.",
".kSSSSSSSssdddk.",
".ksSSSSsssssddk.",
"..kssssssddddk..",
"...kkkkkkkkkk...",
], pad_top=3)
icon('zeljezo', {**base, 'I': '#c3d2dc', 'i': '#7b91a2', 'j': '#4d5e6b'}, [
"....kkkkkkkk....",
"...kIIIIIIIIk...",
"..kIIIIIIIIIIk..",
"..kiiiiiiiiiik..",
".kiiiiiiiiiiiik.",
".kjjjjjjjjjjjjk.",
".kkkkkkkkkkkkkk.",
], pad_top=5)
icon('nafta', {**base, 'O': '#3d3a4a', 'P': '#6c6882', 'm': '#9a95ad'}, [
"....kkkkkkkk....",
"...kPPPPPPPPk...",
"...kOOOOOOOOk...",
"...kmmmmmmmmk...",
"...kOPOOOOOOk...",
"...kOPOOOOOOk...",
"...kOPOOOOOOk...",
"...kmmmmmmmmk...",
"...kOPOOOOOOk...",
"...kOPOOOOOOk...",
"...kOOOOOOOOk...",
"....kkkkkkkk....",
], pad_top=2)
drop = [
".......kk.......",
"......kOOk......",
"......kOOk......",
".....kOOOOk.....",
".....kOOOOk.....",
"....kOPOOOOk....",
"...kOPOOOOOOk...",
"...kOPOOOOOOk...",
"...kOPOOOOOQk...",
"...kOOOOOOOQk...",
"....kOOOOOQk....",
".....kkkkkk.....",
]
icon('voda', {**base, 'O': '#6fb6e6', 'P': '#e0f4ff', 'Q': '#3b7fb5'}, drop, pad_top=2)
icon('vojska', {**base, 'M': '#b3bcc6', 'm': '#6d7883', 'R': '#d0583f'}, [
".......kk.......",
"......kRRk......",
"......kRRk......",
"....kkkkkkkk....",
"...kMMMMMMmmk...",
"..kMMMMMMMMmmk..",
"..kMMMMMMMMmmk..",
"..kMkkkkkkkkmk..",
"..kMMMMkkMMMmk..",
"..kMMMMkkMMMmk..",
"...kkMMkkMMkk...",
".....kkkkkk.....",
], pad_top=2)
icon('radnici', {**base, 'H': '#b3bcc6', 'B': '#c08850'}, [
"....kkkkkk......",
"..kkHHHHHHkk....",
".kHHkkkkkkHHk...",
".kHk.....kBkHk..",
".kk.....kBk.kHk.",
".......kBk...kk.",
"......kBk.......",
".....kBk........",
"....kBk.........",
"...kBk..........",
"..kBk...........",
".kBk............",
".kk.............",
], pad_top=1)
# buildings
icon('bunar', {**base, 'R': '#b8513a', 'B': '#9a6a3c', 'S': '#bfc1c3', 's': '#878b91'}, [
"....kkkkkkkk....",
"...kRRRRRRRRk...",
"..kRRRRRRRRRRk..",
"..kkkkkkkkkkkk..",
"....kBk..kBk....",
"....kBk..kBk....",
"....kBk..kBk....",
"..kkkkkkkkkkkk..",
"..kSSsSSSsSSSk..",
"..kSsSSSsSSSsk..",
"..kSSSsSSSSsSk..",
"..kssssssssssk..",
"..kkkkkkkkkkkk..",
], pad_top=1)
house_rows = [
".......kk.......",
"......kRRk......",
".....kRRRrk.....",
"....kRRRRrrk....",
"...kRRRRRRrrk...",
"..kRRRRRRRRrrk..",
".kkkkkkkkkkkkkk.",
"..kWWWWWWWWWWk..",
"..kWAAWkkWAAWk..",
"..kWAAWDDWAAwk..",
"..kWWWWDDWWWwk..",
"..kwwwwDDwwwwk..",
"..kkkkkkkkkkkk..",
]
icon('kuce', {**base, 'R': '#c0563d', 'r': '#8a3a2a', 'W': '#ecdcb6', 'w': '#c2ae86', 'A': '#8fc6e0', 'D': '#6b4a2e'}, house_rows, pad_top=2)
icon('vijecnica', {**base, 'R': '#4aa396', 'r': '#2c6b64', 'W': '#f0e6cc', 'w': '#c8b78e', 'A': '#8fc6e0', 'D': '#5a3e28'}, house_rows, pad_top=2)
icon('farma', {**base, 'R': '#b8513a', 'W': '#f3ead2', 'G': '#8cb455', 'g': '#5e8a30', 'w': '#e2c25a'}, [
"......kkkk......",
".....kRRRRk.....",
"....kRRRRRRk....",
"...kRRRRRRRRk...",
"..kkkkkkkkkkkk..",
"..kRRRRWWRRRRk..",
"..kRRRRWWRRRRk..",
"..kRRRkkkkRRRk..",
"..kRRRkWWkRRRk..",
"..kRRRkWWkRRRk..",
"..kkkkkkkkkkkk..",
"GgGgGgGgGgGgGgGg",
"wGwGwGwGwGwGwGwG",
], pad_top=2)
icon('pilana', {**base, 'S': '#c6c8ca', 's': '#8d9197', 'd': '#4d5258', 'B': '#b87f48', 'b': '#7a4f2a', 'r': '#e7c690', 'R': '#b88a50'}, [
".....k..k.......",
"....kSkkSk......",
"...kSSSSSSk.....",
"..kSSSssSSSk....",
"...kSsddsSk.....",
"..kSSsddsSSk....",
"...kSSssSSk.....",
"..kSSSSSSSSk....",
"....kSkkSk......",
".kkkkkkkkkkkkk..",
"kBBBBBBBBBBBkrk.",
"kbBBbbBBBBBkrRrk",
"kBBBBBbbBBBkrrrk",
".kkkkkkkkkkkkk..",
], pad_top=1)
icon('kasarna', {**base, 'R': '#c4453a', 'W': '#dccb9c', 'w': '#a8925e', 'D': '#5a3e28'}, [
"........kRRR....",
"........kRRRR...",
"........kRR.....",
"........k.......",
".......kkk......",
"......kWWWk.....",
".....kWWwWWk....",
"....kWWWwWWWk...",
"...kWWWWwWWWWk..",
"..kWWWWkwkWWWWk.",
".kWWWWkDDDkWWWWk",
"kWWWWWkDDDkWWWWk",
"kkkkkkkkkkkkkkkk",
], pad_top=2)
icon('utvrda', {**base, 'S': '#c6c8ca', 's': '#8d9197'}, [
"..kkk.kkkk.kkk..",
"..kSk.kSSk.kSk..",
"..kSkkkSSkkkSk..",
"..kSSSSSSSSSsk..",
"..kkkkkkkkkkkk..",
"...kSSsSSSSsk...",
"...kSSSSkSSsk...",
"...kSsSSkSSsk...",
"...kSSSSSSssk...",
"...kSSSkkSSsk...",
"...kSsSkkSssk...",
"...kSSSkkSSsk...",
"..kkkkkkkkkkkk..",
], pad_top=2)
icon('kamenolom', {**base, 'S': '#c6c8ca', 's': '#8d9197'}, [
".........kkkkk..",
"........kSSSSsk.",
"........kSSSssk.",
".....kkkkkkkkkk.",
"....kSSSSSSSSsk.",
"....kSsSSSSSssk.",
"..kkkkkkkkkkkkk.",
".kSSSSSSSSSSSsk.",
".kSSsSSSSsSSssk.",
".kssssssssssssk.",
".kkkkkkkkkkkkkk.",
], pad_top=3)
icon('rudnik', {**base, 'S': '#a89878', 's': '#776850', 'B': '#b87f48'}, [
".....kkkkkk.....",
"...kkSSSSSSkk...",
"..kSSSSSSSSSsk..",
".kSSSSSSSSSSssk.",
".kSSkkkkkkkkSsk.",
".kSSkBBBBBBkSsk.",
"kSSSkBkkkkBkSssk",
"kSSSkBkkkkBkSssk",
"kSsSkBkkkkBkssSk",
"kssskBkkkkBksssk",
"kkkkkkkkkkkkkkkk",
], pad_top=3)
icon('naftna', {**base, 'M': '#a9b2ba', 'O': '#3d3a4a'}, [
".......kk.......",
"......kMMk......",
"......kMMk......",
".....kMkkMk.....",
".....kMkkMk.....",
"....kMkMMkMk....",
"....kMMkkMMk....",
"...kMkkMMkkMk...",
"...kMMkkkkMMk...",
"..kMkkMMMMkkMk..",
"..kMMkkkkkkMMk..",
".kkkkkkkkkkkkkk.",
".kOOOOOOOOOOOOk.",
".kkkkkkkkkkkkkk.",
], pad_top=1)
# controls (L = line color)
ctrl = {}
ctrl['cekic'] = ({'L': 'L', 'B': '#c8925a', 'b': '#8a5a30', 'k': K}, [
"..kkkkkkkkkkk...",
".kLLLLLLLLLLLk..",
".kLLLLLLLLLLLk..",
"..kkkkkBBkkkk...",
"......kBBk......",
"......kBBk......",
"......kBBk......",
"......kBBk......",
"......kBBk......",
"......kBBk......",
"......kbbk......",
".......kk.......",
], 2)
ctrl['trgovina'] = ({'L': 'L'}, [
"..........L.....",
"..........LL....",
"..LLLLLLLLLLL...",
"..........LL....",
"..........L.....",
"................",
".....L..........",
"....LL..........",
"...LLLLLLLLLLL..",
"....LL..........",
".....L..........",
], 3)
ctrl['dom'] = ({'L': 'L'}, [
".......LL.......",
"......LLLL......",
".....LL..LL.....",
"....LL....LL....",
"...LL......LL...",
"..LLLLLLLLLLLL..",
"...L........L...",
"...L........L...",
"...L...LL...L...",
"...L...LL...L...",
"...L...LL...L...",
"...LLLLLLLLLL...",
], 2)
ctrl['centar'] = ({'L': 'L'}, [
"..LLL......LLL..",
"..L..........L..",
"..L..........L..",
"................",
".......LL.......",
".....LLLLLL.....",
".....LLLLLL.....",
".......LL.......",
"................",
"..L..........L..",
"..L..........L..",
"..LLL......LLL..",
], 2)
ctrl['pauza'] = ({'L': 'L'}, ["....LLL..LLL...."] * 10, 3)
ctrl['play'] = ({'L': 'L'}, [
"......L.........",
"......LL........",
"......LLL.......",
"......LLLL......",
"......LLLLL.....",
"......LLLLL.....",
"......LLLL......",
"......LLL.......",
"......LL........",
"......L.........",
], 3)
ctrl['brze'] = ({'L': 'L'}, [
"...L.....L......",
"...LL....LL.....",
"...LLL...LLL....",
"...LLLL..LLLL...",
"...LLLL..LLLL...",
"...LLL...LLL....",
"...LL....LL.....",
"...L.....L......",
], 4)
ctrl['meni'] = ({'L': 'L'}, [
"..LLLLLLLLLLLL..",
"..LLLLLLLLLLLL..",
"................",
"................",
"..LLLLLLLLLLLL..",
"..LLLLLLLLLLLL..",
"................",
"................",
"..LLLLLLLLLLLL..",
"..LLLLLLLLLLLL..",
], 3)
ctrl['zatvori'] = ({'L': 'L'}, [
"..LL........LL..",
"...LL......LL...",
"....LL....LL....",
".....LL..LL.....",
"......LLLL......",
"......LLLL......",
".....LL..LL.....",
"....LL....LL....",
"...LL......LL...",
"..LL........LL..",
], 3)
ctrl['sat'] = ({'L': 'L'}, [
".....LLLLLL.....",
"....L......L....",
"...L...LL...L...",
"..L....LL....L..",
"..L....LL....L..",
"..L....LLLL..L..",
"..L....LLLL..L..",
"..L..........L..",
"...L........L...",
"....L......L....",
".....LLLLLL.....",
], 2)
ctrl['brava'] = ({'L': 'L'}, [
".....LLLLLL.....",
"....LL....LL....",
"....L......L....",
"....L......L....",
"..LLLLLLLLLLLL..",
"..LLLLLLLLLLLL..",
"..LLLLL..LLLLL..",
"..LLLLL..LLLLL..",
"..LLLLLL.LLLLL..".replace("LLLLLL.LLLLL", "LLLLLL.LLLLL"),
"..LLLLLLLLLLLL..",
"..LLLLLLLLLLLL..",
], 2)

def render(pal, rows, scale=1):
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != '.':
                im.putpixel((x, y), hx(pal[c]))
    return im

for n, (pal, rows) in ICONS.items():
    render(pal, rows).save(f"{OUT}/i_{n}.png")
for n, (pal, rows, pt) in ctrl.items():
    rows = ['.' * 16] * pt + rows
    rows += ['.' * 16] * (16 - len(rows))
    for i, r in enumerate(rows):
        assert len(r) == 16, (n, i, r)
    for suf, col in (('l', '#efe6cf'), ('d', '#3a2a1c')):
        p = dict(pal); p['L'] = col
        render(p, rows).save(f"{OUT}/c_{n}_{suf}.png")

# ---------- map ----------
random.seed(7)
W, H = 144, 90
def noise_grid(gw, gh):
    return [[random.random() for _ in range(gw + 2)] for _ in range(gh + 2)]
def smooth(g, x, y, cell):
    gx, gy = x / cell, y / cell
    x0, y0 = int(gx), int(gy); fx, fy = gx - x0, gy - y0
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    a = g[y0][x0] * (1 - fx) + g[y0][x0 + 1] * fx
    b = g[y0 + 1][x0] * (1 - fx) + g[y0 + 1][x0 + 1] * fx
    return a * (1 - fy) + b * fy
g1 = noise_grid(W // 18 + 2, H // 18 + 2); g2 = noise_grid(W // 8 + 2, H // 8 + 2); g3 = noise_grid(W // 4 + 2, H // 4 + 2)
g4 = noise_grid(W // 12 + 2, H // 12 + 2)
def height(x, y):
    return smooth(g1, x, y, 18) * .6 + smooth(g2, x, y, 8) * .3 + smooth(g3, x, y, 4) * .1
def moist(x, y):
    return smooth(g4, x, y, 12)
cols = {
    'snow': '#e4e7e1', 'rock': '#a7a9a4', 'rock2': '#b4b5ae',
    'g1': '#8ea57e', 'g2': '#9bb08a', 'g3': '#a8bb95', 'g4': '#b7c8a4', 'g5': '#c3d1b0',
    'sand': '#d8d0ae', 'sand2': '#dccba0', 'forest': '#7f9872', 'forest2': '#738b67',
    'water': '#7d9fbe', 'water2': '#6b8fb0',
}
im = Image.new('RGBA', (W, H))
for y in range(H):
    for x in range(W):
        h = height(x, y); m = moist(x, y)
        if h > .74: c = 'snow'
        elif h > .66: c = 'rock' if (x + y) % 5 else 'rock2'
        elif h < .28: c = 'sand' if m > .45 else 'sand2'
        elif m > .62: c = 'forest' if random.random() > .18 else 'forest2'
        else:
            c = ['g1', 'g2', 'g3', 'g4', 'g5'][min(4, int((h - .28) / .38 * 5))]
        im.putpixel((x, y), hx(cols[c]))
# rivers (random walks)
def river(x, y, steps, dx, dy):
    for _ in range(steps):
        for ox in (0,):
            if 0 <= x < W and 0 <= y < H:
                im.putpixel((x, y), hx(cols['water']))
        if random.random() < .6: x += dx
        else: y += dy
river(60, 0, 120, 1, 1)
river(20, 89, 90, 1, -1)
river(143, 30, 70, -1, 1)
# lake
for y in range(4, 10):
    for x in range(40, 47):
        if (x - 43) ** 2 + (y - 7) ** 2 < 11:
            im.putpixel((x, y), hx(cols['water2']))
# territory around (70, 46)
cx, cy, R = 66, 46, 13
inside = lambda x, y: abs(x - cx) * .9 + abs(y - cy) * 1.15 + smooth(g3, x, y, 4) * 5 <= R
for y in range(H):
    for x in range(W):
        if inside(x, y):
            r, g, b, a = im.getpixel((x, y))
            im.putpixel((x, y), (int(r * .82 + 62 * .18), int(g * .82 + 150 * .18), int(b * .82 + 132 * .18), 255))
for y in range(H):
    for x in range(W):
        if inside(x, y) and not all(inside(x + a, y + b) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            im.putpixel((x, y), hx('#2f6f66'))
im.save(f"{OUT}/mapa.png")
print(sorted(os.listdir(OUT)))
