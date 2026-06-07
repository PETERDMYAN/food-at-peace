import math
from PIL import Image, ImageDraw

SS = 4          # supersample factor
OUT = 1024
S = OUT * SS    # working size
C = S / 2

def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))

# --- background: diagonal-ish vertical gradient in the app's violet ---
top = (139, 92, 246)     # #8B5CF6
bot = (76, 29, 149)      # #4C1D95
img = Image.new("RGB", (S, S), bot)
px = img.load()
for y in range(S):
    t = y / (S - 1)
    # ease for a softer middle
    row = lerp(top, bot, t)
    for x in range(S):
        px[x, y] = row
draw = ImageDraw.Draw(img, "RGBA")

WHITE = (255, 255, 255, 255)

# --- progress ring (open ring with rounded caps) ---
R = int(S * 0.345)            # outer radius
T = int(S * 0.072)            # ring thickness
Rc = R - T // 2               # centerline radius
bbox = [C - R, C - R, C + R, C + R]
# Pillow angles: 0=3 o'clock, increasing clockwise. Gap centered at top (270deg).
gap = 44
start = 270 + gap / 2
end = 270 - gap / 2 + 360
draw.arc(bbox, start, end, fill=WHITE, width=T)
# rounded caps
for ang in (start, end):
    a = math.radians(ang)
    cx = C + Rc * math.cos(a)
    cy = C + Rc * math.sin(a)
    r = T / 2
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE)

# --- leaf in the center (white, with a background-violet midrib) ---
leaf_len = int(S * 0.40)
leaf_max_w = int(S * 0.115)
N = 160
upper, lower = [], []
for i in range(N + 1):
    x = leaf_len * i / N
    f = x / leaf_len
    w = leaf_max_w * math.sqrt(max(0.0, f)) * (1.0 - f) * 2.0  # pointed both ends
    upper.append((x, -w))
    lower.append((x, w))
pts = upper + lower[::-1]

# draw leaf on its own layer so we can rotate it
pad = leaf_max_w * 2
lw = leaf_len + pad * 2
lh = leaf_max_w * 4 + pad
layer = Image.new("RGBA", (int(lw), int(lh)), (0, 0, 0, 0))
ld = ImageDraw.Draw(layer)
ox, oy = pad, lh / 2
poly = [(ox + p[0], oy + p[1]) for p in pts]
ld.polygon(poly, fill=WHITE)
# midrib: a violet vein down the middle
mid = (109, 40, 217, 255)
ld.line([(ox + leaf_len * 0.05, oy), (ox + leaf_len * 0.95, oy)],
        fill=mid, width=int(S * 0.010))

def half_w(f):
    return leaf_max_w * math.sqrt(max(0.0, f)) * (1.0 - f) * 2.0

# clean herringbone side veins, angled toward the tip, kept inside the leaf
vein_w = int(S * 0.0065)
for fx in (0.30, 0.48, 0.66):
    bx = ox + leaf_len * fx
    fe = min(fx + 0.13, 0.95)
    ex = ox + leaf_len * fe
    ey = half_w(fe) * 0.80
    ld.line([(bx, oy), (ex, oy - ey)], fill=mid, width=vein_w)
    ld.line([(bx, oy), (ex, oy + ey)], fill=mid, width=vein_w)

# rotate leaf to sit diagonally and center it in the ring
layer = layer.rotate(38, expand=True, resample=Image.BICUBIC)
lx = int(C - layer.width / 2)
ly = int(C - layer.height / 2)
img.paste(layer, (lx, ly), layer)

# --- downscale with high-quality filter ---
icon = img.resize((OUT, OUT), Image.LANCZOS).convert("RGB")
icon.save("/tmp/appicon_1024.png")
print("wrote /tmp/appicon_1024.png", icon.size)
