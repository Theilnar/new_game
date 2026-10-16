from PIL import Image, ImageDraw

src = r"C:\Users\Admin\Documents\box_push\train_station_near_lit_layer_continuation.png"
dst = r"C:\Users\Admin\Documents\box_push\train_station_near_lit_layer_carriage.png"

image = Image.open(src).convert("RGBA")
draw = ImageDraw.Draw(image)

# A dark pixel-art passenger carriage placed on the existing track/platform.
body = (410, 325, 1650, 515)
draw.rectangle(body, fill=(8, 18, 38, 255), outline=(2, 7, 20, 255), width=10)
draw.rectangle((420, 340, 1640, 505), fill=(15, 31, 57, 255), outline=(28, 53, 80, 255), width=4)
draw.rectangle((420, 475, 1640, 505), fill=(5, 13, 28, 255))
draw.rectangle((420, 337, 1640, 348), fill=(30, 54, 76, 255))

# Windows with warm interior light.
for x in range(470, 1540, 175):
    draw.rectangle((x, 365, x + 112, 425), fill=(40, 44, 56, 255), outline=(3, 10, 25, 255), width=5)
    draw.rectangle((x + 10, 374, x + 102, 416), fill=(132, 99, 52, 255))
    draw.rectangle((x + 18, 382, x + 94, 410), fill=(196, 151, 73, 235))
    draw.line((x + 56, 374, x + 56, 416), fill=(47, 43, 43, 255), width=4)

# Sliding door and carriage seams.
draw.rectangle((1310, 351, 1450, 505), fill=(10, 23, 44, 255), outline=(38, 61, 83, 255), width=5)
draw.rectangle((1330, 368, 1430, 437), fill=(111, 87, 51, 255), outline=(3, 10, 24, 255), width=4)
draw.rectangle((1341, 378, 1419, 428), fill=(178, 135, 67, 220))
draw.line((1380, 368, 1380, 437), fill=(46, 44, 44, 255), width=3)
for x in (700, 1000, 1570):
    draw.line((x, 348, x, 505), fill=(7, 17, 34, 255), width=5)

# Undercarriage, wheels, and couplers.
draw.rectangle((500, 505, 1550, 548), fill=(3, 8, 18, 255), outline=(20, 31, 46, 255), width=4)
for x in (600, 910, 1230, 1500):
    draw.ellipse((x - 35, 515, x + 35, 585), fill=(3, 7, 15, 255), outline=(35, 50, 63, 255), width=7)
    draw.rectangle((x - 8, 535, x + 8, 565), fill=(94, 78, 48, 220))
draw.rectangle((350, 505, 420, 535), fill=(5, 10, 20, 255))
draw.rectangle((1640, 505, 1720, 535), fill=(5, 10, 20, 255))

# Small red marker lights at the ends.
draw.rectangle((424, 455, 439, 475), fill=(132, 22, 26, 255))
draw.rectangle((1620, 455, 1635, 475), fill=(132, 22, 26, 255))

image.save(dst)
