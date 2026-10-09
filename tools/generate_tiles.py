# Converts the reference tilesets in inbox/reference/sprites/ into 64x64px-per-cell atlases,
# saved to assets/tiles/. Unused legacy tiles — see docs/decisoes/abertas.md.
from PIL import Image

CELL = 64
OUTPUT = "assets/tiles"


def _shrink(img: Image.Image, columns: int, rows: int) -> Image.Image:
	return img.resize((columns * CELL, rows * CELL), Image.BOX)


def floor() -> None:
	im = Image.open("inbox/reference/sprites/tileset-piso-2x2.png").convert("RGBA")
	_shrink(im, 2, 2).save(f"{OUTPUT}/floor.png")


def wall() -> None:
	im = Image.open("inbox/reference/sprites/tileset-parede-2x2.png").convert("RGBA")
	_shrink(im, 2, 2).save(f"{OUTPUT}/wall.png")


def door() -> None:
	# The art has 4 horizontal cells, vertically centered with padding.
	im = Image.open("inbox/reference/sprites/tileset-porta-1x4.png").convert("RGBA").crop((0, 221, 1774, 666))
	horizontal = _shrink(im, 4, 1)
	horizontal.save(f"{OUTPUT}/door.png")
	horizontal.transpose(Image.ROTATE_90).save(f"{OUTPUT}/door_vertical.png")


def hangar_gate() -> None:
	# 5 cells wide x 2 rows: row 0 closed, row 1 open.
	im = _shrink(Image.open("inbox/reference/sprites/tileset-portao-hangar-2x5.png").convert("RGBA"), 5, 2)
	closed = im.crop((0, 0, 5 * CELL, CELL)).transpose(Image.ROTATE_90)
	open_ = im.crop((0, CELL, 5 * CELL, 2 * CELL)).transpose(Image.ROTATE_90)
	sheet = Image.new("RGBA", (2 * CELL, 5 * CELL), (0, 0, 0, 0))
	sheet.paste(closed, (0, 0))
	sheet.paste(open_, (CELL, 0))
	sheet.save(f"{OUTPUT}/hangar_gate.png")


floor()
wall()
door()
hangar_gate()
print("tiles generated in", OUTPUT)


def player_placeholder() -> None:
	# Crops "Lira without a helmet" from the reference sheet and removes the beige background.
	im = Image.open("inbox/reference/sprites/prototipo-lira-e-miro.png").convert("RGBA")
	background = im.getpixel((5, 5))[:3]
	data = []
	for r, g, b, a in im.getdata():
		close = abs(r - background[0]) + abs(g - background[1]) + abs(b - background[2]) < 40
		data.append((r, g, b, 0) if close else (r, g, b, a))
	im.putdata(data)
	figure = im.crop((150, 150, 500, 720))
	box = figure.getbbox()
	figure = figure.crop(box)
	height = 96
	width = max(1, round(figure.width * height / figure.height))
	figure.resize((width, height), Image.BOX).save("assets/sprites/lira.png")


player_placeholder()
