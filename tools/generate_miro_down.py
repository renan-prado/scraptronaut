# Generates assets/sprites/miro_down.png from inbox/reference/sprites/image.png. Unused legacy sheet.
#
# The sheet has six front-facing drawings in a 3x2 grid, but only four form a
# cycle: measuring which foot is forward (lower in the drawing), four have
# the right foot forward and only two the left — so figures 3 and 5 (no
# mirror match) are dropped, or the walk would favor one leg.
#
# SCALE: this sheet is NOT normalized by head width like the others — a
# front-facing head is 4% narrower than a profile one (hair adds width from
# the side). Instead, scale matches this figure's HEIGHT to the side-walk
# sheet's, so the character doesn't change size when turning.
#
# Anchor: head center horizontally, ground at the cell's base, same as idle and side.
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import miro_sheet

SOURCE = "inbox/reference/sprites/image.png"
OUTPUT = "assets/sprites/miro_down.png"

## Animation order, as indices into the sheet's reading order.
ORDER: list[int] = [0, 1, 2, 4]

## Figure height, in final-sprite pixels, matching the side-walk sheet's
## height after scaling (92, vs 96 for the idle sheet).
FIGURE_HEIGHT: int = 92

## Gap on each side of the cell, in source pixels.
MARGIN: int = 24


def _front_foot(figure: Image.Image) -> int:
	"""How much lower one foot is than the other. Negative = left forward, positive = right."""
	alpha = figure.getchannel("A").load()
	width, height = figure.size
	center = int(miro_sheet.head_center(figure))

	def base(x0: int, x1: int) -> int:
		for y in range(height - 1, int(height * 0.80), -1):
			if any(alpha[x, y] > 128 for x in range(x0, x1)):
				return height - 1 - y
		return 0

	return base(0, center) - base(center, width)


def generate() -> None:
	figures = miro_sheet.figures(SOURCE)
	assert len(figures) == 6, f"expected 6 drawings, found {len(figures)}"

	# Checks the order's premise: frames half a cycle apart are the same
	# pose with legs swapped. Warns instead of silently generating a limp
	# if the sheet ever changes.
	half = len(ORDER) // 2
	for i in range(half):
		a = _front_foot(figures[ORDER[i]])
		b = _front_foot(figures[ORDER[i + half]])
		assert a * b < 0, (
			f"frames {ORDER[i]} and {ORDER[i + half]} should have opposite feet "
			f"forward, got {a} and {b}"
		)
		assert abs(abs(a) - abs(b)) <= 8, (
			f"frames {ORDER[i]} and {ORDER[i + half]} should be mirrored poses, "
			f"but differ by {abs(a)} and {abs(b)}"
		)

	centers = [miro_sheet.head_center(f) for f in figures]
	scale = FIGURE_HEIGHT / max(f.height for f in figures)

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

	print(f"generated: {OUTPUT} ({sheet.width}x{sheet.height}, {len(cells)} frames of {fw}x{fh})")
	print(f"animation order: {ORDER}   dropped: "
	      f"{[i for i in range(6) if i not in ORDER]} (no mirror match)")


generate()
