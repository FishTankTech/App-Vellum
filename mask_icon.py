from PIL import Image, ImageDraw

size = 1024
radius = int(size * 0.2237)  # Apple's approximate squircle corner ratio

img = Image.open("icon-source.png").convert("RGBA").resize((size, size))

mask = Image.new("L", (size, size), 0)
draw = ImageDraw.Draw(mask)
draw.rounded_rectangle([(0, 0), (size, size)], radius=radius, fill=255)

output = Image.new("RGBA", (size, size), (0, 0, 0, 0))
output.paste(img, (0, 0), mask)
output.save("icon-source-rounded.png")

print("Done — saved as icon-source-rounded.png")
