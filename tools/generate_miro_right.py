# Generates assets/sprites/miro_right.png from entrada/referencias/sprites/miro-right-2.png.
# Unused legacy sheet.
#
# Reading order isn't animation order; it was deduced by measuring foot
# spread (distance between back and front foot) and confirmed by which arm
# swings forward in the two contact frames — see git history for the full
# measurement notes if this sheet is ever revisited.
#
# Anchor: head center horizontally, ground at the cell's base. A torso-
# centroid anchor was tried first and made the walk crooked (the torso band
# includes the arms, which swing opposite in the two contact frames); the
# head is rigid (97-99% correlation between frames) and sits above the shoulders.
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import miro_sheet

SOURCE = "entrada/referencias/sprites/miro-right-2.png"
OUTPUT = "assets/sprites/miro_right.png"

## Animation order, as indices into the sheet's reading order.
ORDER: list[int] = [0, 2, 1, 3, 4, 5]

## Gap on each side of the cell, in source pixels.
MARGIN: int = 24


def _stride(figure: Image.Image) -> int:
	"""Horizontal distance between the back foot and the front one."""
	alpha = figure.getchannel("A").load()
	width, height = figure.size
	band = range(int(height * 0.88), height)
	columns = [x for x in range(width) if any(alpha[x, y] > 128 for y in band)]
	return columns[-1] - columns[0] if columns else 0


def generate() -> None:
	figures = miro_sheet.figures(SOURCE)
	assert len(figures) == len(ORDER), f"expected {len(ORDER)} drawings, found {len(figures)}"

	# Checks the order's premise: figures 3 apart are the same step instant.
	half = len(ORDER) // 2
	for i in range(half):
		a, b = _stride(figures[ORDER[i]]), _stride(figures[ORDER[i + half]])
		assert abs(a - b) <= max(16, a * 0.08), (
			f"frames {ORDER[i]} and {ORDER[i + half]} should be the same step "
			f"instant, but differ by {a} and {b}"
		)

	centers = [miro_sheet.head_center(f) for f in figures]
	scale = miro_sheet.scale(figures)

	reach = max(
		max(centers),
		max(f.width - c for f, c in zip(figures, centers)),
	)
	half_width = reach + MARGIN
	width = int(half_width * 2)
	height = round(miro_sheet.FINAL_HEIGHT / scale)
	assert height >= max(f.height for f in figures), "figure taller than the cell"

	cells: list[Image.Image] = []
	for i in ORDER:
		cell = Image.new("RGBA", (width, height), (0, 0, 0, 0))
		cell.paste(figures[i], (int(half_width - centers[i]), height - figures[i].height))
		cells.append(cell)

	fw = round(width * scale)
	fh = miro_sheet.FINAL_HEIGHT
	sheet = Image.new("RGBA", (fw * len(cells), fh), (0, 0, 0, 0))
	for i, cell in enumerate(cells):
		sheet.paste(cell.resize((fw, fh), Image.BOX), (i * fw, 0))
	sheet.save(OUTPUT)

	strides = [_stride(figures[i]) * scale for i in (ORDER[half - 1], ORDER[-1])]
	cycle = sum(strides)
	print(f"generated: {OUTPUT} ({sheet.width}x{sheet.height}, {len(cells)} frames of {fw}x{fh})")
	print(f"animation order: {ORDER}")
	print(f"average stride: {cycle / 2:.1f} px   full cycle (two strides): {cycle:.1f} px")


generate()
