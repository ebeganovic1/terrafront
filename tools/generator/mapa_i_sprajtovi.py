import random, math, os, json
from PIL import Image

random.seed(11)
D = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(D, "assets4"); os.makedirs(OUT, exist_ok=True)
W, H = 480, 300

def hx(h, a=255):
    h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

OL = hx('#33291f')

# ---------------- noise ----------------
def ngrid(gw, gh, seed):
    r = random.Random(seed)
    return [[r.random() for _ in range(gw + 3)] for _ in range(gh + 3)]
def smooth(g, x, y, cell):
    gx, gy = x / cell, y / cell
    x0, y0 = int(gx), int(gy); fx, fy = gx - x0, gy - y0
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    a = g[y0][x0] * (1 - fx) + g[y0][x0 + 1] * fx
    b = g[y0 + 1][x0] * (1 - fx) + g[y0 + 1][x0 + 1] * fx
    return a * (1 - fy) + b * fy
NA = ngrid(W // 24, H // 24, 1); NB = ngrid(W // 8, H // 8, 2); NC = ngrid(W // 40, H // 40, 3)
def n1(x, y): return smooth(NA, x, y, 24) * .7 + smooth(NB, x, y, 8) * .3

# ---------------- geometry helpers ----------------
def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)
def poly_dist(px, py, pts):
    return min(seg_dist(px, py, *pts[i], *pts[i + 1]) for i in range(len(pts) - 1))

def catmull(pts, n=8):
    out = []
    P = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)))
    out.append(pts[-1]); return out

# ---------------- layout (native px; display = x3) ----------------
RIVER = catmull([(292, 14), (286, 38), (298, 62), (306, 86), (296, 110), (300, 134), (312, 160), (304, 186), (296, 210), (300, 240)])
def coast_y(x):
    return 234 + 9 * math.sin(x / 31) + 5 * math.sin(x / 11 + 1) + (smooth(NB, x, 200, 8) - .5) * 8
def lake_d(x, y):  # <1 => sea
    return 1 - (y - coast_y(x)) / 8
def desert_edge(y):
    return 402 + 10 * math.sin(y / 17) + (smooth(NB, 300, y, 8) - .5) * 16
ROADS = [
    catmull([(40, 120), (75, 112), (120, 118), (160, 126), (205, 132), (250, 132), (290, 128), (320, 130), (350, 142), (395, 146), (440, 146)]),
    catmull([(205, 132), (208, 150), (215, 178), (238, 204), (250, 222)]),
    catmull([(160, 126), (156, 104), (150, 92)]),
    catmull([(205, 132), (212, 110), (214, 96)]),
    catmull([(350, 142), (352, 160), (354, 176)]),
]
BRIDGES = [(301, 129)]
RUNWAY = (320, 190, 100, 10)   # x, y, w, h
APRON = (330, 170, 80, 20)
PIER = (246, 226, 8, 26)
FIELDS = [(120, 140, 30, 20, 'wheat'), (120, 170, 30, 10, 'green'), (160, 170, 20, 20, 'wheat'), (190, 180, 20, 10, 'wheat')]
# building placements: (kind, x_center, y_base)
BUILD = [
    ('vijecnica', 205, 128),
    ('kuce', 168, 112), ('kuce_b', 244, 114), ('fabrika', 254, 158), ('kuce_b', 182, 152),
    ('kuce', 140, 108), ('kuce', 128, 128), ('kuce', 96, 124), ('kuce_b', 232, 174), ('kuce', 272, 190),
    ('bunar', 222, 142),
    ('utvrda', 268, 118),
    ('farma', 100, 150),
    ('pilana', 70, 104),
    ('kasarna', 344, 128),
    ('kuce_b', 378, 110), ('kuce', 322, 106),
    ('rudnik', 150, 90),
    ('kamenolom', 212, 80), ('kamenolom', 250, 70),
    ('kamp', 446, 176),
    ('hangar', 350, 190), ('kontrola', 405, 190),
    ('kran', 262, 228),
]
MOUNTAINS = [(108, 20, 40, 30), (146, 10, 50, 40), (192, 14, 46, 36), (236, 22, 40, 30), (170, 30, 32, 24), (272, 34, 28, 22)]
CELL = 10
def rock_d(x, y):
    return ((x - 188) / 108) ** 2 + ((y - 36) / 50) ** 2 - (smooth(NB, x, y, 8) - .5) * .35

# ---------------- ground ----------------
G = [hx('#5c9a3a'), hx('#68a842'), hx('#76b54a'), hx('#86c255')]
img = Image.new('RGBA', (W, H))
pix = img.load()
water_mask = [[0] * W for _ in range(H)]
road_mask = [[0] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        v = n1(x, y) + (random.random() - .5) * .12
        c = G[max(0, min(3, int(v * 4.2 - .4)))]
        pix[x, y] = c
# tufts & flowers
for _ in range(2600):
    x, y = random.randrange(1, W - 1), random.randrange(1, H - 2)
    base = pix[x, y]
    dk = tuple(max(0, int(ch * .82)) for ch in base[:3]) + (255,)
    lt = tuple(min(255, int(ch * 1.12)) for ch in base[:3]) + (255,)
    if random.random() < .5:
        pix[x, y] = dk; pix[x - 1, y - 1] = dk; pix[x + 1, y - 1] = dk
    else:
        pix[x, y] = lt
for _ in range(220):
    x, y = random.randrange(W), random.randrange(H)
    pix[x, y] = random.choice([hx('#f4f1e4'), hx('#f2d65a'), hx('#e98fb0')])

# roads
for y in range(H):
    for x in range(W):
        d = min(poly_dist(x, y, r) for r in ROADS) if any(abs(x - r[0][0]) < 400 for r in ROADS) else 99
        if d < 2.6:
            road_mask[y][x] = 1
            pix[x, y] = hx('#d6b476') if random.random() > .12 else hx('#c9a462')
        elif d < 3.4:
            pix[x, y] = hx('#b89556')

# desert
DS = [hx('#ecd08a'), hx('#e4c274'), hx('#dab262'), hx('#f4dea0')]
desert_mask = [[0] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        e = desert_edge(y)
        if x > e or (x > e - 5 and random.random() < (x - e + 5) / 5):
            desert_mask[y][x] = 1
            if road_mask[y][x]: continue
            v = smooth(NB, x, y, 8)
            c = DS[0] if v > .45 else DS[1]
            if (y + int(6 * math.sin(x / 9))) % 9 == 0: c = DS[2]
            if (y + int(6 * math.sin(x / 9))) % 9 == 1: c = DS[3]
            if random.random() < .03: c = DS[2]
            pix[x, y] = c
        elif x > e - 12 and random.random() < .5:
            pix[x, y] = hx('#9fb04a') if random.random() < .5 else hx('#b4b85a')
# rocky mountain ground (flat grey + white)
rock_mask = [[0] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        if rock_d(x, y) < 1 and y < 98 and not road_mask[y][x]:
            rock_mask[y][x] = 1
for y in range(H):
    for x in range(W):
        if not rock_mask[y][x]: continue
        edge = any(not (0 <= x + a < W and 0 <= y + b < H) or not rock_mask[y + b][x + a] for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        snow_line = 4 + 3 * math.sin(x / 9)
        if edge: c = hx('#7d848c')
        elif y < snow_line: c = hx('#f4f6f8')
        elif y < snow_line + 2: c = hx('#d9dee4')
        else: c = hx('#aab0b7')
        pix[x, y] = c
# runway + apron
rx, ry, rw_, rh_ = RUNWAY
for y in range(ry - 1, ry + rh_ + 1):
    for x in range(rx - 1, rx + rw_ + 1):
        c = hx('#5b5f66')
        if y in (ry - 1, ry + rh_) or x in (rx - 1, rx + rw_): c = hx('#3c3f45')
        elif y in (ry, ry + rh_ - 1): c = hx('#e9e6dc')
        elif y == ry + rh_ // 2 and (x - rx) % 8 < 4 and 6 < x - rx < rw_ - 6: c = hx('#f4f1e6')
        elif (x - rx) < 5 and (y - ry) % 2 == 1: c = hx('#e9e6dc')
        elif random.random() < .06: c = hx('#676b73')
        pix[x, y] = c; road_mask[y][x] = 1
ax, ay, aw, ah = APRON
for y in range(ay, ay + ah):
    for x in range(ax, ax + aw):
        c = hx('#8a8e95') if (x // 6 + y // 6) % 2 else hx('#7f838a')
        if y == ay or x in (ax, ax + aw - 1): c = hx('#5b5f66')
        pix[x, y] = c; road_mask[y][x] = 1

# fields
for fx, fy, fw, fh, kind in FIELDS:
    for y in range(fy, fy + fh):
        for x in range(fx, fx + fw):
            if kind == 'wheat':
                c = hx('#ecc84e') if (y - fy) % 3 else hx('#c89a2c')
                if (y - fy) % 3 == 1 and random.random() < .25: c = hx('#f6dc78')
            else:
                c = hx('#4f8a34') if (y - fy) % 3 == 0 else hx('#6fab45')
                if (y - fy) % 3 == 1 and (x % 3 == 0): c = hx('#8fcf5e')
            pix[x, y] = c
    # fence
    for x in range(fx - 1, fx + fw + 1):
        for yy in (fy - 1, fy + fh):
            pix[x, yy] = hx('#8a5a30') if x % 3 else hx('#5a3a1e')
    for y in range(fy - 1, fy + fh + 1):
        for xx in (fx - 1, fx + fw):
            pix[xx, y] = hx('#8a5a30') if y % 3 else hx('#5a3a1e')

# water
SEA = [hx('#1f5fae'), hx('#2c72c4'), hx('#3a89d8'), hx('#5aa6e4')]
for y in range(H):
    for x in range(W):
        rd = poly_dist(x, y, RIVER) if abs(x - 300) < 40 and y < 250 else 99
        rw = 5.6 + 1.4 * math.sin(y / 23)
        cy = coast_y(x)
        sea = y > cy
        if rd < rw or sea:
            water_mask[y][x] = 1
            if sea:
                d = y - cy
                c = SEA[3] if d < 3 else SEA[2] if d < 9 else SEA[1] if d < 30 else SEA[0]
            else:
                depth = (rw - rd) / rw
                c = SEA[1] if depth > .55 else SEA[2] if depth > .25 else SEA[3]
            pix[x, y] = c
        elif rd < rw + 1.6 or y > cy - 5:
            dry = desert_mask[y][x]
            pix[x, y] = hx('#ecd8a0') if (rd < rw + 1.0 or y > cy - 3.5) else hx('#d2bd80')
# ripples
for _ in range(420):
    x, y = random.randrange(W), random.randrange(H)
    if water_mask[y][x] and all(0 <= x + k < W and water_mask[y][x + k] for k in range(4)):
        for k in range(random.choice([2, 3, 4])): pix[x + k, y] = hx('#9ad2f4')
# bridges
for bx, by in BRIDGES:
    for y in range(by - 3, by + 4):
        for x in range(bx - 12, bx + 13):
            if abs(y - by) == 3: pix[x, y] = OL
            elif abs(y - by) == 2: pix[x, y] = hx('#6a4424')
            else: pix[x, y] = hx('#b07a45') if x % 3 else hx('#8a5a30')
    for x in range(bx - 12, bx + 13, 4):
        pix[x, by - 4] = hx('#6a4424'); pix[x, by + 3] = hx('#6a4424')

# pier
px_, py_, pw_, ph_ = PIER
for y in range(py_, py_ + ph_):
    for x in range(px_, px_ + pw_):
        c = hx('#b07a45') if y % 3 else hx('#8a5a30')
        if x in (px_, px_ + pw_ - 1): c = OL
        pix[x, y] = c
    if y % 6 == 0:
        pix[px_ - 1, y] = OL; pix[px_ + pw_, y] = OL
for y in range(py_ + 4, py_ + 12):
    for x in range(px_ + pw_, px_ + pw_ + 20):
        c = hx('#a8703f') if y % 3 else hx('#7a522c')
        if y in (py_ + 4, py_ + 11) or x == px_ + pw_ + 19: c = OL
        pix[x, y] = c
ground = img.copy()

# ---------------- sprites ----------------
def S(w, h): return Image.new('RGBA', (w, h), (0, 0, 0, 0))
def put(s, x, y, c):
    if 0 <= x < s.width and 0 <= y < s.height: s.putpixel((x, y), c if isinstance(c, tuple) else hx(c))
def rect(s, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w): put(s, xx, yy, c)

ROOFS = {'red': ('#e27a58', '#cf5337', '#b0402a', '#8a2f1f'),
         'blue': ('#7aa4de', '#4d7bc4', '#3a62a6', '#2a4880'),
         'slate': ('#8e98a6', '#6c7686', '#58616f', '#414956'),
         'brown': ('#c49060', '#a8703f', '#8a5a30', '#6a4424')}
WALL = ('#f4ead0', '#e2d2ac', '#c2ad82')
WOOD = ('#c08850', '#a0703e', '#7a522c')

def roof(s, x, y, w, rh, pal, gable=True):
    hl, mid, dk, dd = [hx(c) for c in ROOFS[pal]]
    for r in range(rh):
        ins = (rh - 1 - r) // 3 if gable else 0
        for c in range(ins, w - ins):
            col = mid
            if r % 3 == 2: col = dk
            if c == ins + 1 or r == 1: col = hl if r % 3 != 2 else mid
            if c == w - ins - 2: col = dk
            if r == 0 or c == ins or c == w - ins - 1 or r == rh - 1: col = OL
            put(s, x + c, y + r, col)

def wall(s, x, y, w, wh, pal=WALL, plank=False):
    lt, sh, base = [hx(c) for c in pal]
    for r in range(wh):
        for c in range(w):
            col = lt
            if c >= w - 3: col = sh
            if plank and c % 4 == 3: col = sh
            if r == 0: col = sh
            if r == wh - 1: col = base
            if c == 0 or c == w - 1 or r == wh - 1 and False: col = OL
            put(s, x + c, y + r, col)
    for c in range(w): put(s, x + c, y + wh - 1, OL)

def window(s, x, y):
    rect(s, x, y, 3, 3, OL); rect(s, x + 1, y + 1, 1, 1, '#a6dcf4'); put(s, x + 1, y + 1, '#d8f2ff')
def door(s, x, y, h=4):
    rect(s, x, y, 3, h, OL); rect(s, x + 1, y + 1, 1, h - 1, '#7a4c28')

def sp_house(pal='red', w=16):
    s = S(w + 2, 18)
    roof(s, 0, 2, w + 2, 9, pal)
    rect(s, w - 3, 0, 3, 5, OL); rect(s, w - 2, 1, 1, 3, '#b0a090')  # chimney
    wall(s, 1, 11, w, 7)
    window(s, 3, 12); window(s, w - 5, 12); door(s, w // 2, 13, 5)
    return s

def sp_hall():
    w = 30; s = S(w, 30)
    roof(s, 0, 10, w, 11, 'red')
    wall(s, 1, 21, w - 2, 9)
    for xx in (4, 9, 19, 24): window(s, xx, 23)
    rect(s, 13, 23, 4, 7, OL); rect(s, 14, 24, 2, 6, '#7a4c28')
    # tower
    rect(s, 11, 4, 8, 10, OL); wall(s, 12, 5, 6, 9); window(s, 13, 7)
    for r in range(5):
        for c in range(r, 10 - r): put(s, 10 + c, 4 - r, OL if c in (r, 9 - r) else hx(ROOFS['blue'][1] if c < 5 else ROOFS['blue'][2]))
    # banner
    rect(s, 25, 1, 1, 12, OL); rect(s, 26, 1, 4, 5, '#3f6fc4'); put(s, 27, 2, '#f4ead0'); put(s, 28, 3, '#f4ead0'); rect(s, 26, 6, 1, 1, '#3f6fc4'); put(s, 28, 6, '#3f6fc4')
    return s

def sp_tower():
    s = S(20, 30)
    st = [hx(c) for c in ('#d4d7db', '#b3b8bf', '#8d949d', '#666d76')]
    for r in range(6, 30):
        for c in range(1, 19):
            col = st[1]
            if c <= 3: col = st[0]
            if c >= 15: col = st[2]
            if (r % 4 == 0) or ((c + (r // 4) * 3) % 6 == 0): col = st[3] if c >= 15 else st[2]
            if c in (1, 18) or r == 29: col = OL
            put(s, c, r, col)
    for c in range(0, 20):
        for r in range(2, 7):
            merlon = (c // 3) % 2 == 0
            if r < 4 and not merlon: continue
            col = st[0] if c < 10 else st[1]
            if r in (2,) and merlon or c in (0, 19) or r == 6: col = OL
            if r < 4 and merlon and (c % 3 == 0 or c % 3 == 2): col = OL
            put(s, c, r, col)
    rect(s, 8, 22, 4, 8, OL); rect(s, 9, 23, 2, 7, '#3a2a1c')
    rect(s, 8, 12, 4, 5, OL); rect(s, 9, 13, 2, 3, '#23262b')
    # banner
    rect(s, 15, 0, 1, 3, OL); rect(s, 13, 7, 5, 9, '#3f6fc4'); rect(s, 13, 7, 5, 1, OL)
    put(s, 15, 10, '#f4ead0'); put(s, 14, 11, '#f4ead0'); put(s, 16, 11, '#f4ead0'); put(s, 13, 15, (0, 0, 0, 0)); put(s, 17, 15, (0, 0, 0, 0))
    return s

def sp_barracks():
    s = S(24, 22)
    roof(s, 0, 6, 24, 9, 'slate')
    wall(s, 1, 15, 22, 7, WOOD, plank=True)
    rect(s, 10, 16, 4, 6, OL); rect(s, 11, 17, 2, 5, '#3a2a1c')
    window(s, 3, 16); window(s, 18, 16)
    rect(s, 3, 0, 1, 9, OL); rect(s, 4, 0, 5, 4, '#3f6fc4'); put(s, 6, 1, '#f4ead0'); put(s, 6, 2, '#f4ead0')
    return s

def sp_sawmill():
    s = S(24, 18)
    roof(s, 0, 2, 18, 8, 'brown')
    wall(s, 1, 10, 16, 8, WOOD, plank=True)
    rect(s, 6, 12, 6, 6, OL); rect(s, 7, 13, 4, 5, '#4a3220')
    # saw blade
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx * dx + dy * dy <= 5: put(s, 9 + dx, 15 + dy, '#c9ccd0' if dx * dx + dy * dy < 4 else OL)
    # log pile
    for i, (lx, ly) in enumerate([(18, 15), (21, 15), (19, 12), (22, 12), (20, 9)]):
        rect(s, lx, ly, 3, 3, OL); put(s, lx + 1, ly + 1, '#e7c690')
    return s

def sp_well():
    s = S(12, 14)
    rect(s, 1, 0, 10, 4, OL); roof(s, 1, 0, 10, 4, 'red', gable=False)
    rect(s, 2, 4, 1, 4, OL); rect(s, 9, 4, 1, 4, OL); rect(s, 3, 5, 6, 1, '#6a4424')
    rect(s, 5, 6, 2, 2, '#7a522c')
    st = ('#d4d7db', '#b3b8bf', '#8d949d')
    for r in range(8, 14):
        for c in range(0, 12):
            if r == 8 and c in (0, 11): continue
            col = hx(st[0] if c < 4 else st[1] if c < 9 else st[2])
            if (r + c) % 4 == 0: col = hx(st[2])
            if r in (8, 13) or c in (0, 11): col = OL
            put(s, c, r, col)
    rect(s, 2, 9, 8, 1, '#2c72c4')
    return s

def sp_barn():
    s = S(20, 20)
    roof(s, 0, 2, 20, 10, 'red')
    wall(s, 1, 12, 18, 8, ('#b8513a', '#9a4230', '#7a3424'), plank=True)
    rect(s, 7, 13, 6, 7, OL)
    rect(s, 8, 14, 4, 6, '#f4ead0')
    for i in range(4): put(s, 8 + i, 14 + i + (1 if i > 1 else 0), '#b8513a'); put(s, 11 - i, 14 + i + (1 if i > 1 else 0), '#b8513a')
    # silo
    return s

def sp_mine():
    s = S(20, 14)
    # rocky mound face
    for r in range(14):
        for c in range(20):
            hw = 3 + r * 7 // 13 * 1 + r // 2
            if abs(c - 10) <= min(10, hw):
                col = hx('#9aa0a8') if c < 10 else hx('#7a8089')
                if (c * 7 + r * 3) % 11 == 0: col = hx('#5d636b')
                if abs(c - 10) == min(10, hw): col = OL
                put(s, c, r, col)
    rect(s, 5, 5, 10, 9, '#6a4424'); rect(s, 5, 5, 10, 1, OL)
    rect(s, 6, 6, 8, 8, '#1a1512'); rect(s, 6, 6, 1, 8, '#a8703f'); rect(s, 13, 6, 1, 8, '#a8703f'); rect(s, 6, 6, 8, 1, '#a8703f')
    return s

def sp_quarry():
    s = S(22, 12)
    st = [hx(c) for c in ('#d4d7db', '#b3b8bf', '#8d949d', '#666d76')]
    for r in range(12):
        for c in range(22):
            if ((c - 11) / 11) ** 2 + ((r - 6) / 6) ** 2 <= 1:
                step = (r // 3)
                col = st[min(3, step)] if (c + r) % 5 else st[3]
                if ((c - 11) / 11) ** 2 + ((r - 6) / 6) ** 2 > .8: col = hx('#b89556')
                put(s, c, r, col)
    for (bx, by) in [(4, 3), (15, 7), (9, 8)]:
        rect(s, bx, by, 3, 2, OL); put(s, bx + 1, by, '#e2e4e7')
    return s

def sp_derrick():
    s = S(16, 22)
    for r in range(20):
        hw = 1 + r * 6 // 20
        put(s, 8 - hw, r, OL); put(s, 8 + hw, r, OL)
        if r % 4 == 2:
            for c in range(8 - hw, 8 + hw + 1): put(s, c, r, '#8d949d')
    rect(s, 1, 20, 14, 2, OL); rect(s, 2, 20, 12, 1, '#3d3a4a')
    return s

def sp_camp():
    s = S(26, 20)
    for r in range(12):
        for c in range(-r, r + 1):
            col = hx('#c4453a') if c < 0 else hx('#9a3028')
            if abs(c) == r or r == 11: col = OL
            put(s, 7 + c, 8 + r, col)
    rect(s, 6, 15, 3, 5, OL)
    for r in range(10):
        for c in range(-r, r + 1):
            col = hx('#c4453a') if c < 0 else hx('#9a3028')
            if abs(c) == r or r == 9: col = OL
            put(s, 18 + c, 10 + r, col)
    rect(s, 12, 0, 1, 12, OL); rect(s, 13, 0, 6, 4, '#c4453a'); put(s, 15, 1, '#f4ead0')
    return s

def sp_conifer(v=0):
    h = 15 + v; s = S(11, h)
    cols = [hx('#23552f'), hx('#2f6d3a'), hx('#3f8a45'), hx('#5aa653')]
    tiers = [(0, 4), (4, 5), (8, 5)]
    for i, (ty, th) in enumerate(tiers):
        for r in range(th + 1):
            hw = (r + 1 + i) * 5 // (th + 1 + 2 - i) if False else min(5, 1 + (r + i * 1) * 4 // max(1, th))
            for c in range(-hw, hw + 1):
                col = cols[2] if c < 0 else cols[1]
                if c == -hw + 1 and r > 0: col = cols[3]
                if r == th: col = cols[0]
                if abs(c) == hw: col = cols[0]
                put(s, 5 + c, ty + r + v, col)
    rect(s, 4, h - 3, 3, 3, '#5a3a1e'); put(s, 4, h - 3, '#7a522c')
    put(s, 5, v, cols[0])
    return s

def sp_round():
    s = S(12, 13)
    for r in range(10):
        for c in range(12):
            d = ((c - 5.5) / 5.5) ** 2 + ((r - 4.5) / 4.8) ** 2
            if d <= 1:
                col = hx('#4f9a45')
                if c + r < 8: col = hx('#78c05a')
                if c + r > 13: col = hx('#347038')
                if d > .78: col = hx('#1f4d28')
                put(s, c, r, col)
    rect(s, 5, 10, 2, 3, '#5a3a1e')
    return s

def sp_rock(sz=0):
    w, h = (5, 4) if sz == 0 else (8, 6)
    s = S(w, h)
    for r in range(h):
        for c in range(w):
            if ((c - (w - 1) / 2) / (w / 2)) ** 2 + ((r - (h - 1) / 2) / (h / 2)) ** 2 <= 1.05:
                col = hx('#c9ccd0') if c + r < (w + h) / 2 - 1 else hx('#8d949d')
                put(s, c, r, col)
    for r in range(h):
        for c in range(w):
            p = s.getpixel((c, r))
            if p[3] and any(not (0 <= c + a < w and 0 <= r + b < h) or not s.getpixel((c + a, r + b))[3] for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                put(s, c, r, OL)
    return s

def sp_unit(col):
    s = S(3, 6)
    put(s, 1, 0, '#f0c8a0'); put(s, 0, 1, OL); put(s, 1, 1, '#f0c8a0'); put(s, 2, 1, OL)
    rect(s, 0, 2, 3, 2, col); put(s, 1, 2, tuple(min(255, int(v * 1.25)) for v in hx(col)[:3]) + (255,))
    put(s, 0, 4, OL); put(s, 2, 4, OL); put(s, 0, 5, OL); put(s, 2, 5, OL)
    return s

def sp_mountain(w, h):
    s = S(w, h)
    cx = w // 2
    for r in range(h):
        hw = (r + 1) * (w / 2) / h
        for c in range(w):
            dx = c - cx
            if abs(dx) <= hw:
                snow = h * .38 + (2 if (c // 3) % 2 else 0)
                if r < snow: col = hx('#ffffff') if dx <= 0 else hx('#dfe5ec')
                else: col = hx('#c3c8ce') if dx <= 0 else hx('#9ca3ab')
                if abs(dx) > hw - 1: col = hx('#5d636b')
                put(s, c, r, col)
    return s

def outline(s, col=None):
    col = col or OL
    w, h = s.size; src = s.copy()
    for r in range(h):
        for c in range(w):
            if src.getpixel((c, r))[3]:
                if any(not (0 <= c + a < w and 0 <= r + b < h) or not src.getpixel((c + a, r + b))[3] for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    put(s, c, r, col)
    return s

def sp_factory():
    s = S(26, 30)
    brick = ('#c0604a', '#a44e3a', '#7e3a2c')
    # chimneys
    for cx, top in ((4, 2), (10, 5)):
        rect(s, cx, top, 4, 16, OL); rect(s, cx + 1, top + 1, 2, 15, '#9a4a36'); put(s, cx + 1, top + 1, '#c86a52')
        rect(s, cx, top, 4, 2, '#3a2e26')
    # sawtooth roof
    for i in range(3):
        for r in range(6):
            for c in range(8):
                if c <= r + 1:
                    put(s, 1 + i * 8 + c, 12 + r, OL if c == r + 1 or r == 5 else hx(ROOFS['red'][1] if c < 4 else ROOFS['red'][2]))
        rect(s, 1 + i * 8 + 7, 12, 1, 6, '#a6dcf4')
    wall(s, 1, 18, 24, 12, brick, plank=False)
    for yy in (20, 24):
        for xx in (3, 8, 17, 21):
            window(s, xx, yy)
    rect(s, 11, 22, 5, 8, OL); rect(s, 12, 23, 3, 7, '#5a3e28')
    for i in range(3): rect(s, 12, 24 + i * 2, 3, 1, '#3a2a1c')
    return s

def sp_smoke():
    s = S(16, 18)
    for (cx, cy, r, col) in ((5, 14, 3, '#9ea3aa'), (7, 9, 4, '#b9bdc3'), (9, 4, 4, '#d3d6da')):
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                d = x * x + y * y
                if d <= r * r: put(s, cx + x, cy + y, hx('#7d828a') if d > (r - 1) * (r - 1) + 1 else hx(col) if (x + y) > -r else hx('#eef0f2'))
    return s

def sp_crane():
    s = S(24, 26)
    Y, y2 = '#e6a632', '#b87a1c'
    rect(s, 4, 6, 3, 18, OL); rect(s, 5, 7, 1, 17, Y)
    for r in range(8, 24, 3): put(s, 5, r, y2)
    rect(s, 2, 22, 7, 4, OL); rect(s, 3, 23, 5, 2, '#6c6f76')
    rect(s, 1, 4, 22, 3, OL); rect(s, 2, 5, 20, 1, Y)
    for c in range(3, 22, 3): put(s, c, 5, y2)
    rect(s, 2, 2, 5, 3, OL); rect(s, 3, 3, 3, 1, '#8fc6e0')
    rect(s, 19, 7, 1, 8, '#3a2e26'); rect(s, 17, 15, 5, 4, OL); rect(s, 18, 16, 3, 2, '#b07a45')
    return s

def sp_crates():
    s = S(12, 8)
    for (x, y) in ((0, 3), (5, 3), (2, 0)):
        rect(s, x, y, 5, 5, OL); rect(s, x + 1, y + 1, 3, 3, '#c89458'); put(s, x + 2, y + 2, '#8a5a30')
    return s

def sp_ship():
    s = S(48, 20)
    # hull
    for r in range(6):
        ins = r // 2
        for c in range(1 + ins, 47 - r * 2):
            col = hx('#5a616c') if r < 3 else hx('#474d57')
            if r == 4: col = hx('#b8402e')
            if r == 5: col = hx('#8a2f22')
            put(s, c, 12 + r, col)
    rect(s, 2, 11, 44, 1, '#8c939d')
    # superstructure
    rect(s, 14, 6, 16, 5, '#9aa2ac'); rect(s, 14, 6, 16, 1, '#c2c8cf'); rect(s, 16, 8, 12, 1, '#2e3440')
    rect(s, 18, 2, 8, 4, '#a9b0b9'); rect(s, 19, 3, 6, 1, '#2e3440')
    rect(s, 22, 0, 1, 3, '#3a3f47'); rect(s, 23, 0, 3, 2, '#c4453a')
    # turrets
    for tx in (5, 34):
        rect(s, tx, 8, 6, 3, '#7c8490'); rect(s, tx, 8, 6, 1, '#a9b0b9')
        rect(s, tx + (6 if tx > 20 else -4), 9, 4, 1, '#3a3f47')
    outline(s)
    return s

def sp_wake(w=18):
    s = S(w, 5)
    for x in range(w):
        for y in (0, 4):
            if random.random() < .55 * (1 - x / w): put(s, x, y + (1 if x % 4 < 2 else 0) * (1 if y else 0), hx('#e8f6ff', 230))
    return s

def sp_sailboat():
    s = S(14, 16)
    for r in range(10):
        for c in range(r * 7 // 10 + 1):
            put(s, 7 + c, r, '#f4f1e6' if c < r * 7 // 10 else '#c9c4b4')
    rect(s, 6, 0, 1, 12, '#5a3a1e')
    rect(s, 1, 11, 12, 3, '#9a6a3c'); rect(s, 2, 14, 10, 1, '#6a4424'); rect(s, 1, 11, 12, 1, '#c08850')
    outline(s)
    return s

def sp_tank(col='#6f7f3a', dk='#556330', lt='#8c9c4c'):
    s = S(26, 13)
    rect(s, 1, 8, 22, 5, '#3a3a33'); rect(s, 2, 9, 20, 3, '#55554c')
    for wx in range(3, 22, 4): rect(s, wx, 10, 2, 2, '#8a8a7c')
    rect(s, 2, 5, 21, 3, col); rect(s, 2, 5, 21, 1, lt); rect(s, 2, 7, 21, 1, dk)
    rect(s, 6, 1, 10, 4, col); rect(s, 6, 1, 10, 1, lt); rect(s, 9, 2, 2, 1, dk)
    rect(s, 16, 2, 10, 2, dk); rect(s, 16, 2, 10, 1, col)
    outline(s)
    return s

def sp_plane(col='#9aa4ae', dk='#6b7580', lt='#c3cad2'):
    s = S(24, 22)
    # fuselage (heading right)
    rect(s, 2, 9, 19, 4, col); rect(s, 2, 9, 19, 1, lt); rect(s, 2, 12, 19, 1, dk)
    rect(s, 21, 10, 2, 2, dk)
    rect(s, 13, 10, 3, 2, '#4d7bc4')
    # wings
    for r in range(9):
        rect(s, 10 - r // 3, 9 - r, 5, 1, col); rect(s, 10 - r // 3, 13 + r, 5, 1, col)
    rect(s, 7, 0, 5, 1, lt); rect(s, 7, 21, 5, 1, dk)
    # tail
    rect(s, 1, 6, 3, 3, col); rect(s, 1, 13, 3, 3, col)
    # roundels
    for yy in (4, 17):
        rect(s, 9, yy, 3, 2, '#3f6fc4'); put(s, 10, yy, '#f4f1e6')
    # prop
    rect(s, 23, 8, 1, 6, '#3a3f47')
    outline(s)
    return s

def shadow_of(sp):
    s = S(*sp.size)
    for r in range(sp.height):
        for c in range(sp.width):
            if sp.getpixel((c, r))[3]: put(s, c, r, (20, 40, 20, 70))
    return s

def sp_hangar():
    s = S(30, 18)
    for r in range(18):
        for c in range(30):
            if r >= 4 or ((c - 15) / 15) ** 2 + ((r - 6) / 6) ** 2 <= 1:
                col = hx('#b9bec5') if c < 12 else hx('#9aa0a8')
                if r < 5: col = hx('#d6dade') if c < 15 else hx('#b0b6bd')
                if c % 5 == 0: col = hx('#858b93')
                put(s, c, r, col)
    rect(s, 0, 17, 30, 1, OL)
    rect(s, 8, 8, 14, 10, OL); rect(s, 9, 9, 12, 9, '#3a3f47')
    for c in range(10, 21, 2): rect(s, c, 9, 1, 9, '#2c3038')
    outline(s)
    return s

def sp_ctower():
    s = S(12, 30)
    rect(s, 5, 0, 1, 7, '#c4453a'); put(s, 5, 2, '#f4f1e6'); put(s, 5, 4, '#f4f1e6')
    rect(s, 1, 7, 10, 2, '#e9e6dc'); rect(s, 2, 9, 8, 4, '#4d7bc4'); rect(s, 3, 10, 2, 2, '#9fd3ef')
    rect(s, 1, 13, 10, 1, '#b9bec5')
    rect(s, 3, 14, 6, 16, '#e9e6dc'); rect(s, 7, 14, 2, 16, '#c9c6bc')
    for yy in (17, 22): rect(s, 4, yy, 2, 2, '#4d7bc4')
    outline(s)
    return s

def sp_cactus():
    s = S(9, 12)
    G1, G2 = '#5aa04a', '#3f7e35'
    rect(s, 3, 0, 3, 12, G1); rect(s, 5, 0, 1, 12, G2)
    rect(s, 0, 3, 2, 4, G1); rect(s, 0, 6, 3, 2, G1)
    rect(s, 7, 2, 2, 4, G1); rect(s, 6, 5, 3, 2, G2)
    outline(s)
    return s


# ---------------- place objects ----------------
objs = []  # (base_y, x_left, y_top, sprite, shadow)
SP = {'vijecnica': sp_hall(), 'kuce': sp_house('red'), 'kuce_b': sp_house('blue'), 'bunar': sp_well(),
      'utvrda': sp_tower(), 'farma': sp_barn(), 'pilana': sp_sawmill(), 'kasarna': sp_barracks(),
      'rudnik': sp_mine(), 'kamenolom': sp_quarry(), 'kamp': sp_camp(),
      'fabrika': sp_factory(), 'hangar': sp_hangar(), 'kontrola': sp_ctower(), 'kran': sp_crane()}
occupied = []
positions = {}
FOOT = []
for kind, cx, by in BUILD:
    sp = SP[kind]
    wc = -(-sp.width // CELL)
    ix = round((cx - wc * CELL / 2) / CELL); iy = round(by / CELL)
    x0 = ix * CELL + (wc * CELL - sp.width) // 2; by = iy * CELL - 1; y0 = by + 1 - sp.height
    FOOT.append((kind, ix, iy - max(1, -(-min(sp.height, 20) // CELL)), wc, max(1, -(-min(sp.height, 20) // CELL))))
    flat = kind in ('kamenolom',)
    if kind == 'fabrika': objs.append((by + 1, x0 - 1, y0 - 15, sp_smoke(), False)); objs.append((by + 1, x0 + 5, y0 - 12, sp_smoke(), False))
    objs.append((by - (100 if flat else 0), x0, y0, sp, not flat))
    occupied.append((x0 - 3, y0 - 2, x0 + sp.width + 3, by + 4))
    positions.setdefault(kind, []).append((x0, y0, sp.width, sp.height))

for (cx, py, mw, mh) in MOUNTAINS:
    sp = sp_mountain(mw, mh)
    objs.append((py + mh - 50, cx - mw // 2, py, sp, False))
    occupied.append((cx - mw // 2, py, cx + mw // 2, py + mh))

def free(x, y, pad=2):
    if not (0 <= x < W and 0 <= y < H): return False
    for yy in range(max(0, y - pad), min(H, y + pad + 1)):
        for xx in range(max(0, x - pad), min(W, x + pad + 1)):
            if water_mask[yy][xx] or road_mask[yy][xx] or rock_mask[yy][xx]: return False
    for (a, b, c, d) in occupied:
        if a - pad <= x <= c + pad and b - pad <= y <= d + pad: return False
    for fx, fy, fw, fh, _ in FIELDS:
        if fx - 3 <= x <= fx + fw + 3 and fy - 3 <= y <= fy + fh + 3: return False
    return True

def forest_density(x, y):
    v = smooth(NC, x, y, 40) * .6 + smooth(NB, x, y, 8) * .4
    # force forests at edges / left
    v -= .22
    if x < 40: v += .35
    if x > 420 and y < 120: v += .25
    if y > 200 and x < 180: v += .2
    if y > 190 and 200 < x < 260: v += .1
    if 55 < x < 290 and 80 < y < 190: v -= .7  # village clearing
    if 315 < x < 400 and 95 < y < 200: v -= .6
    if y < 20: v += .2
    if x > desert_edge(y) - 8: v -= 2
    if 300 < x < 425 and 165 < y < 215: v -= 1
    if 225 < x < 290 and 180 < y < 235: v -= .8
    return v

trees = []
tries = 0
while tries < 26000:
    tries += 1
    x, y = random.randrange(-4, W + 4), random.randrange(4, H + 8)
    if random.random() > forest_density(x, y) - .12: continue
    if not free(min(W - 1, max(0, x)), min(H - 1, y), 1): continue
    if any(abs(x - tx) < 6 and abs(y - ty) < 5 for tx, ty in trees): continue
    trees.append((x, y))
for (x, y) in trees:
    sp = sp_conifer(random.choice([0, 0, 1, 2])) if random.random() < .72 else sp_round()
    objs.append((y, x - sp.width // 2, y - sp.height, sp, True))
# rocks
for _ in range(90):
    x, y = random.randrange(W), random.randrange(H)
    near_mtn = 0 < y < H and rock_d(x, y) < 1.25 and not rock_mask[min(H-1,y)][min(W-1,x)]
    if (near_mtn or random.random() < .2) and free(x, y, 1):
        sp = sp_rock(random.choice([0, 0, 1]))
        objs.append((y, x - sp.width // 2, y - sp.height, sp, False))

# units: blue (player) and red (enemy)
BLUE, RED, WORK = '#3a63b8', '#c23b30', '#8a6a3c'
groups = [((330, 136), BLUE, 6), ((200, 140), WORK, 2), ((160, 128), WORK, 1), ((236, 128), BLUE, 1), ((150, 92), WORK, 2),
          ((226, 100), WORK, 2), ((80, 116), WORK, 2), ((110, 170), WORK, 2), ((455, 186), RED, 6), ((426, 160), RED, 3), ((314, 118), BLUE, 2),
          ((240, 214), WORK, 2), ((262, 234), WORK, 1)]
for (gx, gy), col, n in groups:
    for i in range(n):
        ux = gx + (i % 3) * 5 + random.randint(-1, 1); uy = gy + (i // 3) * 7 + random.randint(-1, 1)
        sp = sp_unit(col)
        objs.append((uy + 6, ux, uy, sp, True))
for (tx, ty) in ((362, 148), (388, 156)):
    sp = sp_tank(); objs.append((ty + 13, tx, ty, sp, True))
sp = sp_tank('#b8503e', '#8a3a2c', '#d06a52'); objs.append((158 + 13, 418, 158, sp, True))
# parked plane on apron, flying plane with ground shadow
pl = sp_plane(); objs.append((194, 378, 169, pl, False))
fp = sp_plane()
objs.append((500, 322, 58, fp, False)); objs.append((-500, 336, 82, shadow_of(fp), False))
# ships
sh = sp_ship(); objs.append((600, 300, 256, sh, False)); objs.append((599, 345, 266, sp_wake(), False))
objs.append((600, 206, 262, sp_sailboat(), False))
objs.append((240, 266, 242, sp_crates(), False))
# cacti & desert rocks
for _ in range(400):
    x, y = random.randrange(400, W), random.randrange(22, 232)
    if x > desert_edge(y) + 4 and free(x, y, 3) and random.random() < .12:
        sp = sp_cactus() if random.random() < .7 else sp_rock(random.choice([0, 1]))
        objs.append((y, x - sp.width // 2, y - sp.height, sp, True))
        occupied.append((x - 4, y - 8, x + 4, y + 2))

# ---------------- compose (display res, grid + territory) ----------------
SC = 3
def river_x(y):
    best = min(RIVER, key=lambda p: abs(p[1] - y)); return best[0]
def compose(ground_img, objlist, terrs, scale=SC):
    g = ground_img.copy(); gp = g.load(); gw, gh = g.size
    for by, x0, y0, sp, sh in objlist:
        if not sh: continue
        for r in range(sp.height):
            for c in range(sp.width):
                if sp.getpixel((c, r))[3] and r > sp.height * .45:
                    X, Y = x0 + c + 2, y0 + r + 2
                    if 0 <= X < gw and 0 <= Y < gh:
                        q = gp[X, Y]; gp[X, Y] = (int(q[0] * .78), int(q[1] * .8), int(q[2] * .78), q[3])
    layer = Image.new('RGBA', (gw, gh), (0, 0, 0, 0))
    for by, x0, y0, sp, sh in sorted(objlist, key=lambda o: o[0]):
        layer.paste(sp, (x0, y0), sp) if (x0 < 0 or y0 < 0) else layer.alpha_composite(sp, (x0, y0))
    up = g.resize((gw * scale, gh * scale), Image.NEAREST)
    upx = up.load(); C = CELL * scale
    for t in terrs:
        col = hx(t['color']); cells = t['cells']
        for (i, j) in cells:
            for y in range(j * C, min(up.height, (j + 1) * C)):
                for x in range(i * C, min(up.width, (i + 1) * C)):
                    q = upx[x, y]
                    if q[3] == 0: continue
                    a = .16
                    if x == i * C or y == j * C: a = .30 if t.get('grid', True) else a
                    tgt = col if (x != i * C and y != j * C) else (40, 60, 40, 255)
                    if (x == i * C or y == j * C) and t.get('grid', True):
                        upx[x, y] = (int(q[0] * .8), int(q[1] * .83), int(q[2] * .8), 255)
                    else:
                        upx[x, y] = tuple(int(q[k] * (1 - a) + col[k] * a) for k in range(3)) + (255,)
    up.alpha_composite(layer.resize((gw * scale, gh * scale), Image.NEAREST))
    upx = up.load()
    for t in terrs:
        col = hx(t['color']); lite = tuple(min(255, int(v + (255 - v) * .55)) for v in col[:3]) + (255,)
        cells = t['cells']; dash = t.get('dash', False)
        def hline(x1, x2, y, c):
            for x in range(x1, x2):
                if 0 <= x < up.width and 0 <= y < up.height and (not dash or (x // 15) % 2 == 0): upx[x, y] = c
        def vline(x, y1, y2, c):
            for y in range(y1, y2):
                if 0 <= x < up.width and 0 <= y < up.height and (not dash or (y // 15) % 2 == 0): upx[x, y] = c
        for (i, j) in cells:
            x0, y0, x1, y1 = i * C, j * C, (i + 1) * C, (j + 1) * C
            if (i, j - 1) not in cells:
                for k in range(7): hline(x0, x1, y0 + k, col if k < 5 else lite)
            if (i, j + 1) not in cells:
                for k in range(7): hline(x0, x1, y1 - 1 - k, col if k < 5 else lite)
            if (i - 1, j) not in cells:
                for k in range(7): vline(x0 + k, y0, y1, col if k < 5 else lite)
            if (i + 1, j) not in cells:
                for k in range(7): vline(x1 - 1 - k, y0, y1, col if k < 5 else lite)
    return up

GW, GH = W // CELL, H // CELL
def cells_where(fn):
    out = set()
    for j in range(GH):
        for i in range(GW):
            cx, cy = i * CELL + 5, j * CELL + 5
            if water_mask[cy][cx] and not (abs(cx - river_x(cy)) < 12 and cy < 225): continue
            if fn(cx, cy): out.add((i, j))
    return out
def clean(cells):
    # keep largest component, fill holes
    comps = []; seen = set()
    for c in cells:
        if c in seen: continue
        st = [c]; comp = set(); seen.add(c)
        while st:
            a = st.pop(); comp.add(a)
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (a[0] + d[0], a[1] + d[1])
                if n in cells and n not in seen: seen.add(n); st.append(n)
        comps.append(comp)
    best = max(comps, key=len)
    for _ in range(2):
        for j in range(GH):
            for i in range(GW):
                if (i, j) not in best and sum((i + a, j + b) in best for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) >= 3: best.add((i, j))
        for c in list(best):
            if sum((c[0] + a, c[1] + b) in best for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) <= 1: best.discard(c)
    return best
GRAD = clean(cells_where(lambda x, y: ((x - 190) / 112) ** 2 + ((y - 124) / 90) ** 2 < 1 + (smooth(NB, x, y, 8) - .5) * .4 and x < river_x(y) - 2 and y > 34))
SELO = clean(cells_where(lambda x, y: ((x - 365) / 58) ** 2 + ((y - 150) / 52) ** 2 < 1 + (smooth(NB, x, y, 8) - .5) * .5 and x > river_x(y) + 6))
ENEMY = cells_where(lambda x, y: ((x - 452) / 34) ** 2 + ((y - 172) / 34) ** 2 < 1)
SELO -= ENEMY
TERRS = [{'cells': GRAD, 'color': '#2f62c0'}, {'cells': SELO, 'color': '#2f62c0', 'dash': True}, {'cells': ENEMY, 'color': '#c7372d', 'grid': False}]
final = compose(ground, objs, TERRS)
final.save(os.path.join(OUT, 'mapa4.png'))
final.save(os.path.join(D, 'map4prev.png'))
# free 2x2 spot in GRAD for placement ghost demo
def cell_free(i, j):
    for y in range(j * CELL, j * CELL + CELL):
        for x in range(i * CELL, i * CELL + CELL):
            if water_mask[y][x] or road_mask[y][x] or rock_mask[y][x]: return False
    for (_, fi, fj, fw, fh) in FOOT:
        if fi <= i < fi + fw and fj <= j < fj + fh: return False
    for fx, fy, fw_, fh_, _ in FIELDS:
        if fx <= i * CELL + 5 < fx + fw_ and fy <= j * CELL + 5 < fy + fh_: return False
    for by, x0, y0, sp, sh in objs:
        if sh and x0 < (i + 1) * CELL and x0 + sp.width > i * CELL and by - 4 < (j + 1) * CELL and by > j * CELL: return False
    return True
ghost = None
for (i, j) in sorted(GRAD, key=lambda c: abs(c[0] - 26) + abs(c[1] - 16)):
    if all((i + a, j + b) in GRAD and cell_free(i + a, j + b) for a in (0, 1) for b in (0, 1)):
        ghost = (i, j); break
bad = None
for (i, j) in sorted(GRAD, key=lambda c: abs(c[0] - ghost[0]) + abs(c[1] - ghost[1])):
    if not cell_free(i, j) and abs(i - ghost[0]) <= 3 and abs(j - ghost[1]) <= 2 and (i, j) not in [(ghost[0] + a, ghost[1] + b) for a in (0, 1) for b in (0, 1)]:
        bad = (i, j); break
json.dump({'ghost': ghost, 'bad': bad, 'grad_bbox': [min(c[0] for c in GRAD), min(c[1] for c in GRAD), max(c[0] for c in GRAD), max(c[1] for c in GRAD)],
           'selo_bbox': [min(c[0] for c in SELO), min(c[1] for c in SELO), max(c[0] for c in SELO), max(c[1] for c in SELO)],
           'enemy_bbox': [min(c[0] for c in ENEMY), min(c[1] for c in ENEMY), max(c[0] for c in ENEMY), max(c[1] for c in ENEMY)]}, open(os.path.join(D, 'ui4.json'), 'w'))

# ---------------- card sprites (24x24, bottom aligned) ----------------
cards = {'bunar': sp_well(), 'farma': sp_barn(), 'pilana': sp_sawmill(), 'kuce': sp_house('red'),
         'kasarna': sp_barracks(), 'utvrda': sp_tower(), 'kamenolom': sp_quarry(), 'rudnik': sp_mine(), 'nafta': sp_derrick(),
         'vijecnica': sp_hall(), 'fabrika': sp_factory(), 'aerodrom': sp_hangar(), 'luka': sp_crane()}
for n, sp in cards.items():
    size = 32
    c = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    c.alpha_composite(sp, ((size - sp.width) // 2, size - sp.height - 1))
    c.save(os.path.join(OUT, f'b_{n}.png'))
json.dump({k: [(x * 3, y * 3, w * 3, h * 3) for x, y, w, h in v] for k, v in positions.items()}, open(os.path.join(D, 'pos.json'), 'w'))
print(positions['kasarna'], len(trees), open(os.path.join(D, 'ui4.json')).read())


# ================= TILE SHEET =================
TO = os.path.join(OUT, 'tiles'); os.makedirs(TO, exist_ok=True)
rnd = random.Random(5)
def ground_tile(w, h, kind):
    t = S(w, h + 5)
    for y in range(h):
        for x in range(w):
            if kind == 'sand':
                c = hx('#ecd08a') if (y + int(3 * math.sin(x / 5))) % 6 else hx('#dab262')
                if (y + int(3 * math.sin(x / 5))) % 6 == 1: c = hx('#f4dea0')
            elif kind == 'sea':
                c = hx('#2c72c4') if rnd.random() > .02 else hx('#3a89d8')
            else:
                c = G[min(3, max(0, int(n1(x * 3 + 7, y * 3 + 11) * 4.2 - .4 + (rnd.random() - .5) * .6)))]
            put(t, x, y, c)
    if kind == 'grass':
        for _ in range(w * h // 18):
            x, y = rnd.randrange(1, w - 1), rnd.randrange(1, h - 1)
            put(t, x, y, hx('#4f8a32')); put(t, x - 1, y - 1, hx('#4f8a32')); put(t, x + 1, y - 1, hx('#4f8a32'))
    if kind == 'sea':
        for _ in range(w * h // 40):
            x, y = rnd.randrange(0, w - 4), rnd.randrange(0, h)
            for k in range(3): put(t, x + k, y, '#9ad2f4')
    side = ('#1f5fae', '#194d8e') if kind == 'sea' else ('#b8874c', '#8e6434')
    for y in range(h, h + 5):
        for x in range(w):
            put(t, x, y, side[0] if y < h + 3 else side[1])
            if kind != 'sea' and (x * 7 + y * 3) % 11 == 0: put(t, x, y, '#a0713c')
    for x in range(w): put(t, x, h, '#3a2e26' if kind != 'sea' else '#174582')
    return t
def place(t, sp, cx, by, sh=True):
    x0, y0 = cx - sp.width // 2, by - sp.height
    if sh:
        for r in range(sp.height):
            for c in range(sp.width):
                if sp.getpixel((c, r))[3] and r > sp.height * .45:
                    X, Y = x0 + c + 2, y0 + r + 2
                    if 0 <= X < t.width and 0 <= Y < t.height - 5 and t.getpixel((X, Y))[3]:
                        p = t.getpixel((X, Y)); t.putpixel((X, Y), (int(p[0] * .78), int(p[1] * .8), int(p[2] * .78), 255))
    t.alpha_composite(sp, (max(0, x0), max(0, y0))) if x0 >= 0 and y0 >= 0 else t.paste(sp, (x0, y0), sp)
def field(t, x0, y0, w, h, kind='wheat'):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            c = (hx('#ecc84e') if (y - y0) % 3 else hx('#c89a2c')) if kind == 'wheat' else (hx('#4f8a34') if (y - y0) % 3 == 0 else hx('#6fab45'))
            put(t, x, y, c)
    for x in range(x0 - 1, x0 + w + 1):
        put(t, x, y0 - 1, '#8a5a30'); put(t, x, y0 + h, '#8a5a30' if x % 3 else '#5a3a1e')
    for y in range(y0 - 1, y0 + h + 1):
        put(t, x0 - 1, y, '#8a5a30'); put(t, x0 + w, y, '#8a5a30')
def fence(t, x0, y0, w):
    for x in range(x0, x0 + w):
        put(t, x, y0, '#8a5a30'); put(t, x, y0 + 2, '#8a5a30')
        if x % 3 == 0: put(t, x, y0 - 1, '#5a3a1e'); put(t, x, y0 + 1, '#5a3a1e'); put(t, x, y0 + 3, '#5a3a1e')
def trees(t, pts):
    for (x, y, k) in sorted(pts, key=lambda p: p[1]):
        place(t, sp_conifer(k) if k >= 0 else sp_round(), x, y)
tiles = {}
# --- biomes 48x32
t = ground_tile(48, 32, 'grass'); place(t, sp_rock(1), 12, 22, False); place(t, sp_rock(0), 34, 12, False); place(t, sp_rock(0), 38, 26, False)
for (x, y, c) in ((20, 8, '#f4f1e4'), (8, 12, '#f2d65a'), (30, 22, '#e98fb0'), (42, 6, '#f2d65a')): put(t, x, y, c)
tiles['b_ravnice'] = t
t = ground_tile(48, 32, 'grass'); trees(t, [(8, 12, 0), (20, 10, 1), (34, 11, 0), (43, 14, -1), (13, 24, 2), (27, 24, 0), (40, 28, 1), (5, 30, -1)]); tiles['b_suma'] = t
t = ground_tile(48, 32, 'grass')
for y in range(3, 32):
    for x in range(48):
        if ((x - 24) / 24) ** 2 + ((y - 12) / 22) ** 2 < 1:
            put(t, x, y, '#aab0b7')
place(t, sp_mountain(30, 24), 16, 22, False); place(t, sp_mountain(26, 20), 33, 24, False); place(t, sp_quarry(), 26, 31, False); trees(t, [(4, 30, 0), (45, 30, 0)]); tiles['b_planine'] = t
t = ground_tile(48, 32, 'sand'); place(t, sp_cactus(), 32, 20); place(t, sp_cactus(), 10, 30); place(t, sp_rock(1), 20, 12, False); tiles['b_pustinja'] = t
t = ground_tile(48, 32, 'grass')
for y in range(32):
    for x in range(48):
        d = x - (18 + y * .5 + 3 * math.sin(y / 4))
        if d > 6: put(t, x, y, '#2c72c4' if d > 14 else '#3a89d8' if d > 9 else '#5aa6e4')
        elif d > 1: put(t, x, y, '#ecd8a0')
for y in range(32, 37):
    for x in range(48):
        d = x - (18 + 31 * .5)
        if d > 6: put(t, x, y, '#1f5fae' if y < 35 else '#194d8e')
trees(t, [(8, 10, 0), (5, 26, -1)]); tiles['b_obala'] = t
t = ground_tile(48, 32, 'grass')
for y in range(37):
    for x in range(48):
        cx = 24 + 7 * math.sin(y / 5)
        d = abs(x - cx)
        if d < 4: put(t, x, y, '#2c72c4' if d < 2 else '#3a89d8') if y < 32 else put(t, x, y, '#1f5fae')
        elif d < 5.5 and y < 32: put(t, x, y, '#ecd8a0')
trees(t, [(8, 14, 0), (40, 12, 1), (42, 28, -1)]); tiles['b_rijeka'] = t
tiles['b_more'] = ground_tile(48, 32, 'sea')
# --- settlement 64x40
t = ground_tile(64, 48, 'grass'); place(t, sp_house('red'), 32, 36); fence(t, 16, 40, 14); fence(t, 38, 40, 12); trees(t, [(12, 28, 0), (52, 30, -1)]); tiles['s_kuca'] = t
t = ground_tile(64, 48, 'grass'); trees(t, [(8, 22, 0), (56, 20, 1), (34, 20, -1)]); place(t, sp_house('red'), 18, 33); place(t, sp_house('red'), 46, 30); place(t, sp_house('blue'), 32, 46); fence(t, 4, 44, 10); fence(t, 50, 44, 12); tiles['s_selo'] = t
t = ground_tile(64, 48, 'grass'); trees(t, [(4, 26, 0), (60, 24, 0)]); place(t, sp_hall(), 32, 32); place(t, sp_house('red'), 12, 38); place(t, sp_house('blue'), 52, 38); place(t, sp_house('red'), 24, 48); place(t, sp_house('blue'), 44, 48); tiles['s_grad'] = t
# --- production 56x36
t = ground_tile(56, 40, 'grass'); field(t, 3, 18, 24, 18); place(t, sp_barn(), 42, 32); trees(t, [(34, 14, 0), (52, 14, -1)]); tiles['p_farma'] = t
t = ground_tile(56, 40, 'grass'); trees(t, [(6, 18, 0), (16, 14, 1), (50, 16, 0)]); place(t, sp_sawmill(), 32, 34)
for (lx, ly) in ((6, 34), (10, 34), (14, 34), (8, 31), (12, 31)):
    rect(t, lx, ly, 4, 3, OL); put(t, lx + 1, ly + 1, '#e7c690'); put(t, lx + 2, ly + 1, '#c49060')
tiles['p_pilana'] = t
t = ground_tile(56, 40, 'grass'); place(t, sp_mountain(40, 28), 28, 34, False); place(t, sp_mine(), 28, 38); trees(t, [(4, 26, 0), (52, 28, 0)])
for x in range(22, 34): put(t, x, 39 if x % 2 else 38, '#6a4424')
tiles['p_rudnik'] = t
t = ground_tile(56, 40, 'grass'); place(t, sp_factory(), 26, 37); place(t, sp_smoke(), 22, 18, False); place(t, sp_crates(), 47, 37); trees(t, [(50, 20, 0)]); tiles['p_fabrika'] = t
t = ground_tile(56, 40, 'sea')
for y in range(20, 30):
    for x in range(4, 48):
        c = hx('#a8703f') if y % 3 else hx('#7a522c')
        if y in (20, 29) or x in (4, 47): c = OL
        put(t, x, y, c)
for x in range(6, 50, 6):
    for y in range(30, 36): put(t, x, y, '#5a3a1e')
place(t, sp_crane(), 36, 28, False); place(t, sp_crates(), 14, 27, False); place(t, sp_sailboat(), 20, 39, False); tiles['p_luka'] = t
t = ground_tile(56, 40, 'grass')
for y in range(30, 38):
    for x in range(56):
        c = hx('#5b5f66')
        if y in (30, 37): c = hx('#e9e6dc')
        if y == 33 and x % 8 < 4: c = hx('#f4f1e6')
        put(t, x, y, c)
place(t, sp_hangar(), 20, 26); place(t, sp_ctower(), 46, 28); place(t, sp_plane(), 36, 40, False); tiles['p_aerodrom'] = t
# --- units
tiles['u_tenk'] = sp_tank()
tiles['u_avion'] = sp_plane()
sh = sp_ship(); t = S(60, 26)
for y in range(14, 26):
    for x in range(60):
        if ((x - 30) / 30) ** 2 + ((y - 20) / 6) ** 2 <= 1: put(t, x, y, '#3a89d8' if y > 17 else '#5aa6e4')
t.alpha_composite(sh, (6, 2)); tiles['u_brod'] = t

# --- territory / grid tiles (display res)
def tile_objs(lst):
    out = []
    for sp, cx, by in lst:
        out.append((by, cx - sp.width // 2, by - sp.height, sp, True))
    return out
def tcells(w, h, fn):
    return {(i, j) for j in range(h // CELL) for i in range(w // CELL) if fn(i, j)}
g = ground_tile(80, 50, 'grass')
ob = tile_objs([(sp_house('red'), 40, 29), (sp_conifer(0), 10, 18), (sp_conifer(1), 70, 22), (sp_round(), 64, 46), (sp_conifer(0), 14, 46)])
tiles['g_selo'] = compose(g, ob, [{'cells': tcells(80, 50, lambda i, j: abs(i - 3.5) + abs(j - 2) <= 2.5), 'color': '#2f62c0', 'dash': True}])
g = ground_tile(80, 50, 'grass')
ob = tile_objs([(sp_hall(), 40, 30), (sp_house('red'), 14, 29), (sp_house('blue'), 66, 29), (sp_house('red'), 26, 49), (sp_house('blue'), 54, 49), (sp_conifer(0), 5, 14), (sp_conifer(1), 75, 14)])
tiles['g_grad'] = compose(g, ob, [{'cells': tcells(80, 50, lambda i, j: 0 < i < 7 or (j > 0 and j < 4)), 'color': '#2f62c0'}])
g = ground_tile(80, 50, 'grass')
ob = tile_objs([(sp_conifer(0), 55, 38), (sp_rock(1), 66, 17), (sp_house('blue'), 15, 19)])
im = compose(g, ob, [{'cells': tcells(80, 50, lambda i, j: True), 'color': '#2f62c0'}])
ip = im.load(); C = CELL * SC
def cellfill(i, j, col, a):
    for y in range(j * C + 1, (j + 1) * C):
        for x in range(i * C + 1, (i + 1) * C):
            q = ip[x, y]; ip[x, y] = tuple(int(q[k] * (1 - a) + col[k] * a) for k in range(3)) + (255,)
    for k in range(C + 1):
        for (x, y) in ((i * C + k, j * C), (i * C + k, (j + 1) * C), (i * C, j * C + k), ((i + 1) * C, j * C + k)):
            if x < im.width and y < im.height: ip[x, y] = col
for (a, b) in ((0, 0), (1, 0), (0, 1), (1, 1)): cellfill(3 + a, 2 + b, hx('#3fbf5a'), .35)
cellfill(5, 3, hx('#e0463a'), .45)
gh_ = sp_house('red').resize((18 * SC, 18 * SC), Image.NEAREST)
ga = gh_.copy(); ga.putalpha(gh_.getchannel('A').point(lambda v: int(v * .6)))
im.alpha_composite(ga, (3 * C + (2 * C - ga.width) // 2, 4 * C - ga.height - 3))
tiles['g_grid'] = im
for n, im in tiles.items(): im.save(os.path.join(TO, n + '.png'))
print('tiles', len(tiles))
