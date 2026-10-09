# Generates assets/sprites/miro_8dir.png from inbox/reference/sprites/sprite-miro-walking.png.
#
# Source sheet: 792x2880, an EXACT 4x8 grid, 198x360 cells. Rows 0-3 repeat
# the previous sheet (inbox/reference/sprites/miro-sprite.png) pixel for pixel; rows 4-7 are the
# new diagonals.
#
# Cropping is arithmetic, not by empty-band detection (what miro_sheet.figures()
# does): this sheet has drawings only 1px from a cut line, so band detection
# would fuse neighboring figures. Since the grid here is exact, _check_bleed()
# instead asserts no drawing crosses a cut line, so a bleeding sheet fails
# loudly instead of producing a dirty sprite.
#
# Row order was measured (skin-pixel centroid position, mirror-matching
# between pairs), not assumed, for rows 0-3 and the 4 cardinal/diagonal pairs.
# ANIMATION ORDER is only measured for rows 0-3 (contact/pass columns differ
# in height there); for the diagonal rows 4-7 the four frames sit at the same
# height and the same [0, 2, 1, 3] order is ASSUMED by symmetry with rows 0-3.
# If diagonal walking looks off, this assumption is the place to check.
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import miro_sheet

SOURCE = "inbox/reference/sprites/sprite-miro-walking.png"
OUTPUT = "assets/sprites/miro_8dir.png"

COLUMNS: int = 4
ROWS: int = 8

## Row names, in sheet order. Becomes the enum order in scripts/player.gd.
DIRECTIONS: list[str] = [
	"down",
	"right",
	"up",
	"left",
	"down_right",
	"down_left",
	"up_right",
	"up_left",
]

## Animation order within each row, as indices into reading order.
ORDER: list[int] = [0, 2, 1, 3]

## Gap on each side of the final cell, in source pixels.
MARGIN: int = 20

## Gap above the head, in source pixels. Without it the tallest rows (left,
## up-left) touch the cell's top with zero margin and resizing eats a hair pixel.
TOP_MARGIN: int = 12

## Loose blobs smaller than this are discarded as drawing noise (the sheet has exactly one).
MAX_NOISE: int = 8


def _cells() -> list[Image.Image]:
	"""Cuts the 32 cells on the arithmetic grid, no heuristics."""
	sheet = Image.open(SOURCE).convert("RGBA")
	width, height = sheet.size
	assert width % COLUMNS == 0 and height % ROWS == 0, (
		f"sheet {width}x{height} doesn't divide into {COLUMNS}x{ROWS}"
	)
	cw, ch = width // COLUMNS, height // ROWS
	return [
		sheet.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
		for r in range(ROWS)
		for c in range(COLUMNS)
	]


def _check_bleed() -> None:
	"""Fails if any drawing crosses a grid cut line."""
	sheet = Image.open(SOURCE).convert("RGBA")
	alpha = sheet.getchannel("A").load()
	width, height = sheet.size
	cw, ch = width // COLUMNS, height // ROWS

	for c in range(1, COLUMNS):
		x = c * cw
		crossing = [y for y in range(height) if alpha[x - 1, y] > 0 and alpha[x, y] > 0]
		assert not crossing, f"drawing crosses vertical cut x={x} on {len(crossing)} rows"
	for r in range(1, ROWS):
		y = r * ch
		crossing = [x for x in range(width) if alpha[x, y - 1] > 0 and alpha[x, y] > 0]
		assert not crossing, f"drawing crosses horizontal cut y={y} on {len(crossing)} columns"


def _clean(cell: Image.Image) -> tuple[Image.Image, int]:
	"""Keeps only the largest connected blob. Returns the cell and the noise removed."""
	alpha = cell.getchannel("A")
	pixels = alpha.load()
	width, height = cell.size
	seen = [[False] * width for _ in range(height)]
	blobs: list[list[tuple[int, int]]] = []
	for y0 in range(height):
		for x0 in range(width):
			if pixels[x0, y0] <= 128 or seen[y0][x0]:
				continue
			stack = [(x0, y0)]
			seen[y0][x0] = True
			blob: list[tuple[int, int]] = []
			while stack:
				x, y = stack.pop()
				blob.append((x, y))
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = x + dx, y + dy
					if (
						0 <= nx < width
						and 0 <= ny < height
						and pixels[nx, ny] > 128
						and not seen[ny][nx]
					):
						seen[ny][nx] = True
						stack.append((nx, ny))
			blobs.append(blob)
	blobs.sort(key=len, reverse=True)
	noise = sum(len(b) for b in blobs[1:])
	assert all(len(b) <= MAX_NOISE for b in blobs[1:]), (
		f"cell has a second blob of {len(blobs[1])} px — too big to be noise, "
		f"looks like a piece of another drawing"
	)
	if len(blobs) > 1:
		clean = cell.copy()
		drawing = clean.load()
		for blob in blobs[1:]:
			for x, y in blob:
				drawing[x, y] = (0, 0, 0, 0)
		return clean, noise
	return cell, 0


def generate() -> None:
	_check_bleed()

	cells = _cells()
	total_noise = 0
	clean_cells: list[Image.Image] = []
	for cell in cells:
		clean, noise = _clean(cell)
		total_noise += noise
		clean_cells.append(clean)

	# Crop to the bbox, but keep each one's gap to its ROW's ground line, so
	# a raised-foot figure (shorter box) doesn't bob the head up and down.
	figures: list[Image.Image] = []
	gaps: list[int] = []
	for row in range(ROWS):
		bases: list[int] = []
		crops: list[Image.Image] = []
		for column in range(COLUMNS):
			cell = clean_cells[row * COLUMNS + column]
			box = cell.getbbox()
			bases.append(box[3])
			crops.append(cell.crop(box))
		ground = max(bases)
		figures.extend(crops)
		gaps.extend(ground - b for b in bases)

	centers = [miro_sheet.head_center(f) for f in figures]
	scale = miro_sheet.scale(figures)

	reach = max(
		max(centers),
		max(f.width - c for f, c in zip(figures, centers)),
	)
	half = reach + MARGIN
	width = int(half * 2)
	height = max(f.height + g for f, g in zip(figures, gaps)) + TOP_MARGIN

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

	print(f"generated: {OUTPUT} ({sheet.width}x{sheet.height}, {COLUMNS}x{ROWS} frames of {fw}x{fh})")
	print(f"rows: {DIRECTIONS}")
	print(f"animation order within each row: {ORDER}")
	print(f"noise removed: {total_noise} px")
	# Sprite2D offset depends on cell height: feet at the base, origin 4px above them.
	print(f"Sprite2D offset for scripts/player.gd: Vector2(0, {-(fh / 2.0 - 4.0):.1f})")


if __name__ == "__main__":
	generate()
