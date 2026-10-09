# Shared utilities for the Miro reference sheets in entrada/referencias/sprites/.
#
# Sheets are a grid of loose drawings on transparent background, not an exact
# grid — some drawings spill into the neighboring cell. Separation is done by
# fully empty bands, not arithmetic division.
from PIL import Image

## Final head width, in game pixels: 193px of head in a 401px figure that
## became a 96px sprite. Each reference sheet is drawn at a slightly
## different scale; the head is the one stable point between poses, so it's
## what fixes the scale of every sheet.
FINAL_HEIGHT: int = 96
FINAL_HEAD_WIDTH: float = 193.0 * FINAL_HEIGHT / 401.0


def _bands(size: int, occupied) -> list[tuple[int, int]]:
	bands: list[tuple[int, int]] = []
	start = -1
	for i in range(size):
		if occupied(i):
			if start < 0:
				start = i
		elif start >= 0:
			bands.append((start, i))
			start = -1
	if start >= 0:
		bands.append((start, size))
	return bands


def figures(path: str) -> list[Image.Image]:
	"""Crops each drawing from the sheet, in reading order."""
	sheet = Image.open(path).convert("RGBA")
	data = sheet.getchannel("A").load()
	width, height = sheet.size
	crops: list[Image.Image] = []
	for y0, y1 in _bands(height, lambda y: any(data[x, y] > 128 for x in range(width))):
		columns = _bands(width, lambda x: any(data[x, y] > 128 for y in range(y0, y1)))
		for x0, x1 in columns:
			cell = sheet.crop((x0, y0, x1, y1))
			crops.append(cell.crop(cell.getbbox()))
	return crops


def head_center(figure: Image.Image) -> float:
	"""Horizontal center of the head — the anchor for every sheet.

	The figure's bounding box doesn't work: it grows and shrinks with the
	limbs. The torso's center of mass doesn't either — a swinging arm drags
	it sideways each step. The head is the only rigid part (97-99% match
	frame to frame), measured in a band above the shoulders where no limb enters.
	"""
	alpha = figure.getchannel("A").load()
	width, height = figure.size
	columns = [
		x
		for x in range(width)
		for y in range(int(height * 0.04), int(height * 0.26))
		if alpha[x, y] > 128
	]
	return (min(columns) + max(columns)) / 2.0


def head_width(figure: Image.Image) -> int:
	"""Widest span of the figure within the head band."""
	alpha = figure.getchannel("A").load()
	width, height = figure.size
	widest = 0
	for y in range(int(height * 0.05), int(height * 0.30)):
		row = [x for x in range(width) if alpha[x, y] > 128]
		if row:
			widest = max(widest, row[-1] - row[0] + 1)
	return widest


def scale(figures: list[Image.Image]) -> float:
	"""Scale that puts this sheet's head at the idle sprite's size."""
	heads = sorted(head_width(f) for f in figures)
	mid = len(heads) // 2
	median = (heads[mid] + heads[~mid]) / 2.0
	return FINAL_HEAD_WIDTH / median
