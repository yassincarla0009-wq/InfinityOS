import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 760, 420
# transparent canvas
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

# --- build the infinity (lemniscate of Bernoulli) path ---
cx, cy = W // 2, H // 2 - 30
a = 150
pts = []
N = 600
for i in range(N + 1):
    t = -math.pi + (2 * math.pi) * i / N
    denom = 1 + math.sin(t) ** 2
    x = a * math.cos(t) / denom
    y = a * math.sin(t) * math.cos(t) / denom
    pts.append((cx + x, cy + y * 1.9))  # stretch vertically a touch

def draw_stroke(canvas, pts, color, width):
    d = ImageDraw.Draw(canvas)
    d.line(pts, fill=color, width=width, joint="curve")

NEON = (0, 229, 255, 255)       # cyan
NEON2 = (120, 90, 255, 255)     # violet edge

# glow layers (wide, blurred, low alpha) -> tight bright core
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
draw_stroke(glow, pts, (0, 229, 255, 90), 40)
glow = glow.filter(ImageFilter.GaussianBlur(18))
img = Image.alpha_composite(img, glow)

glow2 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
draw_stroke(glow2, pts, (120, 90, 255, 120), 24)
glow2 = glow2.filter(ImageFilter.GaussianBlur(9))
img = Image.alpha_composite(img, glow2)

core = Image.new("RGBA", (W, H), (0, 0, 0, 0))
draw_stroke(core, pts, NEON, 12)
draw_stroke(core, pts, (220, 250, 255, 255), 4)   # bright white-ish center line
img = Image.alpha_composite(img, core)

# --- neon text "INFINITY OS" ---
def load_font(size):
    for n in ("arialbd.ttf", "segoeuib.ttf", "segoeui.ttf"):
        try:
            return ImageFont.truetype(n, size)
        except Exception:
            continue
    return ImageFont.load_default()

font = load_font(66)
text = "INFINITY OS"
tmp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dt = ImageDraw.Draw(tmp)
bb = dt.textbbox((0, 0), text, font=font)
tw = bb[2] - bb[0]
tx, ty = (W - tw) / 2, cy + 120
dt.text((tx, ty), text, font=font, fill=(0, 229, 255, 255))
tglow = tmp.filter(ImageFilter.GaussianBlur(10))
img = Image.alpha_composite(img, tglow)
img = Image.alpha_composite(img, tmp)
d2 = ImageDraw.Draw(img)
d2.text((tx, ty), text, font=font, fill=(235, 250, 255, 255))

img.save(r"C:\Users\yassi\OneDrive\Desktop\infinityos\boot_logo.png")

# --- GRUB background: logo centered on deep-space ---
bg = Image.new("RGBA", (1920, 1080), (6, 8, 20, 255))
import random
random.seed(11)
bd = ImageDraw.Draw(bg)
for _ in range(400):
    sx, sy = random.randint(0, 1919), random.randint(0, 1079)
    c = random.randint(110, 230)
    bd.ellipse([sx, sy, sx + 1, sy + 1], fill=(c, c, min(255, c + 25), 255))
logo_big = img.resize((950, 525))
bg.alpha_composite(logo_big, ((1920 - 950) // 2, (1080 - 525) // 2 - 40))
bg.convert("RGB").save(r"C:\Users\yassi\OneDrive\Desktop\infinityos\grub_bg.png")

print("Logo + GRUB background saved.")
