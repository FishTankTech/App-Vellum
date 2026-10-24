from PIL import Image, ImageDraw, ImageFont

def make(scale):
    w, h = 660 * scale, 400 * scale
    img = Image.new("RGB", (w, h), (244, 236, 216))
    d = ImageDraw.Draw(img)

    try:
        title = ImageFont.truetype("/System/Library/Fonts/Supplemental/Georgia.ttf", 26 * scale)
        small = ImageFont.truetype("/System/Library/Fonts/Supplemental/Georgia.ttf", 14 * scale)
    except OSError:
        title = small = ImageFont.load_default()

    ink = (60, 48, 36)
    d.text((w / 2, 56 * scale), "Vellum", font=title, fill=ink, anchor="mm")
    d.text((w / 2, 340 * scale), "Drag Vellum into Applications",
           font=small, fill=(120, 105, 88), anchor="mm")

    d.text((w / 2, 90 * scale), "Quick-note capture for macOS",
       font=small, fill=(120, 105, 88), anchor="mm")

    y = 190 * scale
    x1, x2 = 250 * scale, 410 * scale
    d.line([(x1, y), (x2, y)], fill=ink, width=2 * scale)
    d.polygon([(x2, y), (x2 - 12 * scale, y - 8 * scale),
               (x2 - 12 * scale, y + 8 * scale)], fill=ink)
    return img

make(1).save("dmg-background.png", dpi=(72, 72))
make(2).save("dmg-background@2x.png", dpi=(144, 144))
print("Done")