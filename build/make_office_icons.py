import os
from PIL import Image, ImageDraw, ImageFont

OUT = r"C:\Users\yassi\OneDrive\Desktop\infinityos\office_icons"
os.makedirs(OUT, exist_ok=True)

def font(sz):
    for n in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(n, sz)
        except Exception:
            continue
    return ImageFont.load_default()

def tile(letter, color, name):
    S = 256
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # rounded square
    r = 44
    d.rounded_rectangle([12, 12, S - 12, S - 12], radius=r, fill=color)
    # lighter left spine like office icons
    d.rounded_rectangle([12, 12, 96, S - 12], radius=r, fill=tuple(min(255, c + 30) for c in color[:3]) + (255,))
    f = font(150)
    bb = d.textbbox((0, 0), letter, font=f)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    d.text(((S - w) / 2 - bb[0], (S - h) / 2 - bb[1]), letter, font=f, fill=(255, 255, 255, 255))
    img.save(os.path.join(OUT, name))

tile("W", (41, 103, 196, 255), "word.png")         # blue
tile("X", (33, 115, 70, 255), "excel.png")          # green
tile("P", (198, 84, 40, 255), "powerpoint.png")     # orange
tile("O", (0, 120, 212, 255), "outlook.png")        # outlook blue

# Office home: multicolor squares
S = 256
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle([12, 12, S - 12, S - 12], radius=44, fill=(32, 32, 40, 255))
cols = [(41, 103, 196), (33, 115, 70), (198, 84, 40), (0, 120, 212)]
pos = [(44, 44), (140, 44), (44, 140), (140, 140)]
for c, (x, y) in zip(cols, pos):
    d.rounded_rectangle([x, y, x + 72, y + 72], radius=14, fill=c + (255,))
img.save(os.path.join(OUT, "office.png"))

print("Office icons saved to", OUT)
