# Audits assets/sprites/miro_8dir.png and builds a review sheet.
#
# The generator already audits the SOURCE (no drawing crosses the grid).
# This audits the RESULT, where an anchor or scale bug would show up:
#
#   1. each final cell is a single connected blob — leftover from a
#      neighbor would show up as a second blob
#   2. no cell touches its own border except the bottom (the ground line is
#      meant to touch; anywhere else means the figure got clipped)
#   3. the head lands at the same spot across every frame of a row — this
#      is what makes the character slide sideways each step otherwise
#
# Also writes screenshots/miro_8dir_conferencia.png, the 32 cells enlarged
# and labeled, to point at a wrong frame by name instead of describing the pose.
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
import generate_miro_8dir as g

SHEET = "assets/sprites/miro_8dir.png"
OUTPUT = "screenshots/miro_8dir_conferencia.png"

ZOOM: int = 3
BACKGROUND = (38, 38, 46, 255)

## How much the head may vary within a row, in final-sprite pixels.
ANCHOR_TOLERANCE: float = 1.5


def _blobs(cell: Image.Image) -> list[int]:
	alpha = cell.getchannel("A").load()
	width, height = cell.size
	seen = [[False] * width for _ in range(height)]
	sizes: list[int] = []
	for y0 in range(height):
		for x0 in range(width):
			if alpha[x0, y0] <= 128 or seen[y0][x0]:
				continue
			queue = deque([(x0, y0)])
			seen[y0][x0] = True
			n = 0
			while queue:
				x, y = queue.popleft()
				n += 1
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = x + dx, y + dy
					if (
						0 <= nx < width
						and 0 <= ny < height
						and alpha[nx, ny] > 128
						and not seen[ny][nx]
					):
						seen[ny][nx] = True
						queue.append((nx, ny))
			sizes.append(n)
	sizes.sort(reverse=True)
	return sizes


def audit(sheet: Image.Image, fw: int, fh: int) -> int:
	failures = 0
	for row in range(g.ROWS):
		anchors: list[float] = []
		for column in range(g.COLUMNS):
			name = f"{g.DIRECTIONS[row]} q{column}"
			cell = sheet.crop((column * fw, row * fh, (column + 1) * fw, (row + 1) * fh))

			sizes = _blobs(cell)
			if len(sizes) != 1:
				failures += 1
				print(f"[FAIL] {name}: {len(sizes)} blobs {sizes} (expected 1)")

			box = cell.getbbox()
			# The bottom touches on purpose: the ground is the cell's base.
			if box[0] == 0 or box[2] == fw or box[1] == 0:
				failures += 1
				print(f"[FAIL] {name}: figure touches the cell border, box={box}")

			anchors.append(sheet_anchor(cell))

		spread = max(anchors) - min(anchors)
		mark = "OK" if spread <= ANCHOR_TOLERANCE else "FAIL"
		if mark == "FAIL":
			failures += 1
		print(
			f"[{mark}] {g.DIRECTIONS[row]}: head varies {spread:.2f} px across the row "
			f"(limit {ANCHOR_TOLERANCE}) — {[round(a, 1) for a in anchors]}"
		)
	return failures


def sheet_anchor(cell: Image.Image) -> float:
	"""Horizontal head center, in the same band the generator uses."""
	alpha = cell.getchannel("A").load()
	width, height = cell.size
	box = cell.getbbox()
	tall = box[3] - box[1]
	columns = [
		x
		for x in range(width)
		for y in range(box[1] + int(tall * 0.04), box[1] + int(tall * 0.26))
		if alpha[x, y] > 128
	]
	return (min(columns) + max(columns)) / 2.0


def check() -> None:
	sheet = Image.open(SHEET).convert("RGBA")
	fw = sheet.width // g.COLUMNS
	fh = sheet.height // g.ROWS
	print(f"{SHEET}: {sheet.width}x{sheet.height}, cells of {fw}x{fh}\n")

	failures = audit(sheet, fw, fh)

	cw, ch = fw * ZOOM + 16, fh * ZOOM + 40
	canvas = Image.new("RGBA", (cw * g.COLUMNS + 10, ch * g.ROWS + 10), BACKGROUND)
	brush = ImageDraw.Draw(canvas)
	for row in range(g.ROWS):
		for column in range(g.COLUMNS):
			cell = sheet.crop((column * fw, row * fh, (column + 1) * fw, (row + 1) * fh))
			cell = cell.resize((fw * ZOOM, fh * ZOOM), Image.NEAREST)
			x0, y0 = 5 + column * cw, 5 + row * ch
			brush.rectangle(
				[x0, y0, x0 + fw * ZOOM + 15, y0 + fh * ZOOM + 35],
				outline=(120, 120, 140, 255),
			)
			canvas.alpha_composite(cell, (x0 + 8, y0 + 28))
			brush.text(
				(x0 + 8, y0 + 8),
				f"{g.DIRECTIONS[row]} q{column}  (sheet column {g.ORDER[column]})",
				fill=(200, 220, 255, 255),
			)
	Path(OUTPUT).parent.mkdir(exist_ok=True)
	canvas.save(OUTPUT)
	print(f"\ngenerated: {OUTPUT} ({canvas.width}x{canvas.height})")
	print(f"failures: {failures}")
	sys.exit(1 if failures else 0)


if __name__ == "__main__":
	check()
