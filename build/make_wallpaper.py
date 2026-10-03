from PIL import Image, ImageDraw, ImageFont
import math

W, H = 1920, 1080
img = Image.new("RGB", (W, H))
px = img.load()

# Deep space diagonal gradient (dark blue/purple -> near black)
top = (14, 18, 46)
bot = (4, 4, 10)
for y in range(H):
    t = y / H
    r = int(top[0] * (1 - t) + bot[0] * t)
    g = int(top[1] * (1 - t) + bot[1] * t)
    b = int(top[2] * (1 - t) + bot[2] * t)
    for x in range(W):
        # subtle horizontal glow toward center
        gx = 1 - abs(x - W / 2) / (W / 2)
        px[x, y] = (min(255, r + int(gx * 10)),
                    min(255, g + int(gx * 12)),
                    min(255, b + int(gx * 22)))

draw = ImageDraw.Draw(img)

# starfield
import random
random.seed(7)
for _ in range(500):
    sx, sy = random.randint(0, W - 1), random.randint(0, H - 1)
    s = random.choice([1, 1, 1, 2])
    c = random.randint(120, 255)
    draw.ellipse([sx, sy, sx + s, sy + s], fill=(c, c, min(255, c + 20)))

# glowing infinity symbol (two circles)
cx, cy = W // 2, H // 2 - 40
R = 120
for width, col in [(44, (40, 70, 160)), (30, (80, 120, 230)), (16, (160, 190, 255))]:
    draw.ellipse([cx - R * 2 + 10, cy - R, cx + 10, cy + R], outline=col, width=width)
    draw.ellipse([cx - 10, cy - R, cx + R * 2 - 10, cy + R], outline=col, width=width)

def load_font(size, bold=True):
    names = ["arialbd.ttf" if bold else "arial.ttf", "segoeuib.ttf", "segoeui.ttf"]
    for n in names:
        try:
            return ImageFont.truetype(n, size)
        except Exception:
            continue
    return ImageFont.load_default()

title_font = load_font(150, True)
sub_font = load_font(44, False)

def centered(text, font, y, fill):
    bb = draw.textbbox((0, 0), text, font=font)
    w = bb[2] - bb[0]
    draw.text(((W - w) / 2, y), text, font=font, fill=fill)

centered("InfinityOS", title_font, cy + R + 40, (235, 240, 255))
centered("powered by GNOME  •  built by Yassin", sub_font, cy + R + 215, (150, 170, 220))

img.save(r"C:\Users\yassi\OneDrive\Desktop\infinityos\wallpaper.png")
print("Wallpaper saved.")
