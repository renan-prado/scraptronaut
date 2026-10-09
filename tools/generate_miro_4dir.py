# Generates assets/sprites/miro_4dir.png from docs/miro-sprite.png.
#
# Unused: superseded by generate_miro_8dir.py. See docs/padroes/arquitetura.md.
#
# Source sheet is a 4x4 grid on transparent background:
#   row 0  front (down)     row 1  right
#   row 2  back (up)        row 3  left
#
# Reading order within a row isn't animation order: columns 0/1 are the two
# feet-together poses (passing), columns 2/3 are the two contacts with legs
# swapped — hence the cycle [0, 2, 1, 3].
#
# Anchor: head center horizontally, ground at the cell's base — same as the
# older sheets. All 16 figures share ONE cell, so any frame uses the same
# Sprite2D offset.
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import miro_sheet

SOURCE = "docs/miro-sprite.png"
OUTPUT = "assets/sprites/miro_4dir.png"

ROWS: int = 4
COLUMNS: int = 4

## Row names, in sheet order. Becomes the enum order in player.gd.
DIRECTIONS: list[str] = ["down", "right", "up", "left"]

## Animation order within each row, as indices into reading order.
ORDER: list[int] = [0, 2, 1, 3]

## Gap on each side of the cell, in source pixels. Keeps the widest frame off the border.
MARGIN: int = 24


def _figures_and_gap() -> tuple[list[Image.Image], list[int]]:
	"""Crops the 16 figures and measures each one's gap to its row's ground line.

	miro_sheet.figures() crops each drawing to its own box, which loses the
	ground line: two figures in the same row can end at different heights just
	because one has a raised foot. Aligning boxes by their row's lowest pixel
	instead keeps the head from bobbing — a bob that isn't in the art.
	"""
	sheet = Image.open(SOURCE).convert("RGBA")
	alpha = sheet.getchannel("A").load()
	width, height = sheet.size
	figures: list[Image.Image] = []
	gaps: list[int] = []
	bands = miro_sheet._bands(height, lambda y: any(alpha[x, y] > 128 for x in range(width)))
	for y0, y1 in bands:
		columns = miro_sheet._bands(width, lambda x: any(alpha[x, y] > 128 for y in range(y0, y1)))
		bases: list[int] = []
		cells: list[Image.Image] = []
		for x0, x1 in columns:
			ys = [y for y in range(y0, y1) if any(alpha[x, y] > 128 for x in range(x0, x1))]
			bases.append(ys[-1])
			cell = sheet.crop((x0, y0, x1, y1))
			cells.append(cell.crop(cell.getbbox()))
		ground = max(bases)
		figures.extend(cells)
		gaps.extend(ground - b for b in bases)
	return figures, gaps


def _stride(figure: Image.Image) -> int:
	"""Horizontal distance between the back foot and the front one."""
	alpha = figure.getchannel("A").load()
	width, height = figure.size
	band = range(int(height * 0.90), height)
	columns = [x for x in range(width) if any(alpha[x, y] > 128 for y in band)]
	return columns[-1] - columns[0] if columns else 0


def generate() -> None:
	figures, gaps = _figures_and_gap()
	assert len(figures) == ROWS * COLUMNS, (
		f"expected {ROWS * COLUMNS} drawings, found {len(figures)}"
	)

	centers = [miro_sheet.head_center(f) for f in figures]
	scale = miro_sheet.scale(figures)

	# One shared cell for all 16 figures, symmetric around the head.
	reach = max(
		max(centers),
		max(f.width - c for f, c in zip(figures, centers)),
	)
	half = reach + MARGIN
	width = int(half * 2)
	# Cell height comes from the tallest figure, not a fixed constant.
	height = max(f.height + g for f, g in zip(figures, gaps))

	fw = round(width * scale)
	fh = round(height * scale)
	sheet = Image.new("RGBA", (fw * COLUMNS, fh * ROWS), (0, 0, 0, 0))
	for row in range(ROWS):
		for column, src in enumerate(ORDER):
			i = row * COLUMNS + src
			cell = Image.new("RGBA", (width, height), (0, 0, 0, 0))
			cell.paste(
				figures[i],
				(int(half - centers[i]), height - figures[i].height - gaps[i]),
			)
			sheet.paste(cell.resize((fw, fh), Image.BOX), (column * fw, row * fh))
	sheet.save(OUTPUT)

	# The cycle has two contacts; each is one step. player.gd uses this to
	# match animation cadence with actual movement.
	side = DIRECTIONS.index("right")
	strides = [
		_stride(figures[side * COLUMNS + ORDER[1]]) * scale,
		_stride(figures[side * COLUMNS + ORDER[3]]) * scale,
	]
	cycle = sum(strides)
	print(f"generated: {OUTPUT} ({sheet.width}x{sheet.height}, {COLUMNS}x{ROWS} frames of {fw}x{fh})")
	print(f"rows: {DIRECTIONS}")
	print(f"animation order within each row: {ORDER}")
	print(f"average stride: {cycle / 2:.1f} px   full cycle (two strides): {cycle:.1f} px")


if __name__ == "__main__":
	generate()
