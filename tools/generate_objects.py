# Generates the station's standalone objects — neither tile nor character.
#
#   assets/objects/bed.png   72x136   Lastro's metal bunk
#
# WHY NOT A TILE
#
# Everything on the map is indexed by neighbor mask and fits a 64px cell. The
# bed occupies TWO cells standing up, has a headboard that only makes sense
# on one side, and doesn't connect to any neighbor — indexing it by
# neighborhood would spend 256 variants to draw the same thing every time.
# It's its own node (scripts/bed.gd), with its own collision.
#
# THE ART IS BIGGER THAN THE BED
#
# 72x136 for a 60x128 bed: the 6px gap on the right and bottom is where the
# contact shadow goes, offset like the hull's. With the bed filling the whole
# image, the shadow would get clipped, or the bed would be off-center and the
# lying character wouldn't land in the middle of the mattress.
#
# HEIGHTS MATCH THE LYING CHARACTER
#
# The sleep pose is the character's FRONT view (see generate_miro_states.py)
# placed over the mattress. With scripts/bed.gd's offset, the sprite's `y`
# row lands at `y + 18` of the art: hair at 25, face at 54, blanket at 74,
# boots at 117. Pillow, sheet fold and bed foot follow those numbers —
# changing one means checking the other.
from PIL import Image, ImageDraw

BED_OUTPUT = "assets/objects/bed.png"

WIDTH: int = 72
HEIGHT: int = 136

## The bed's box within the image; the rest is the shadow.
LEFT: int = 6
RIGHT: int = 65
TOP: int = 4
BOTTOM: int = 131

OUTLINE = (28, 34, 43, 255)
STEEL = (126, 139, 155, 255)
LIGHT_STEEL = (182, 194, 207, 255)
DARK_STEEL = (74, 84, 98, 255)
PANEL = (56, 66, 80, 255)
CYAN = (104, 224, 236, 255)
DIM_CYAN = (48, 118, 132, 255)
AMBER = (255, 186, 84, 255)
MATTRESS = (66, 78, 92, 255)
MATTRESS_LIGHT = (88, 102, 118, 255)
SHEET = (178, 190, 204, 255)
PILLOW = (214, 224, 234, 255)
SHADOW = (0, 0, 0, 90)

## Bed rows, with which part of the lying character lands on each.
HEADBOARD_BASE: int = 26
MATTRESS_TOP: int = 24
PILLOW_BASE: int = 60  # head spans 25 to 68
SHEET_TOP: int = 63  # chest, just above the blanket, which starts at 74
SHEET_BASE: int = 71
MATTRESS_BASE: int = 124  # boots end at 117
FOOT_TOP: int = 120


def _bed() -> Image.Image:
	art = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
	draw = ImageDraw.Draw(art)

	# Contact shadow, offset down and right like the hull's.
	draw.rounded_rectangle((LEFT + 4, TOP + 4, RIGHT + 4, BOTTOM + 4), radius=8, fill=SHADOW)

	# Headboard: dark panel with a reading light and a power indicator.
	draw.rounded_rectangle(
		(LEFT, TOP, RIGHT, HEADBOARD_BASE), radius=6, fill=PANEL, outline=OUTLINE
	)
	draw.rectangle((17, 10, 54, 16), fill=DIM_CYAN)
	draw.rectangle((18, 11, 53, 14), fill=CYAN)
	draw.ellipse((57, 9, 61, 13), fill=AMBER)
	for x, y in ((10, 8), (10, 21), (61, 21)):
		draw.point((x, y), fill=LIGHT_STEEL)

	# Frame: the plate holding the mattress, under everything else.
	draw.rounded_rectangle(
		(LEFT, HEADBOARD_BASE - 6, RIGHT, BOTTOM - 3), radius=6, fill=DARK_STEEL, outline=OUTLINE
	)

	# Side rails, with a highlight on the top edge — same metal language as the hull's pipes.
	for x0 in (LEFT + 1, RIGHT - 5):
		draw.rectangle((x0, MATTRESS_TOP, x0 + 4, MATTRESS_BASE), fill=STEEL)
		draw.line((x0 + 1, MATTRESS_TOP + 1, x0 + 1, MATTRESS_BASE - 1), fill=LIGHT_STEEL)
		for y in (40, 72, 104):
			draw.point((x0 + 2, y), fill=DARK_STEEL)

	# Mattress. Quilting lines are light and spaced out — dark ones would read as a bare frame.
	draw.rounded_rectangle(
		(11, MATTRESS_TOP, 60, MATTRESS_BASE), radius=4, fill=MATTRESS, outline=DARK_STEEL
	)
	for y in range(MATTRESS_TOP + 16, MATTRESS_BASE - 6, 16):
		draw.line((13, y, 58, y), fill=MATTRESS_LIGHT)

	# Pillow and sheet fold: the two pieces that say "bed", not "stretcher".
	draw.rounded_rectangle(
		(14, MATTRESS_TOP + 1, 57, PILLOW_BASE), radius=5, fill=PILLOW, outline=DARK_STEEL
	)
	draw.line((35, MATTRESS_TOP + 6, 35, PILLOW_BASE - 5), fill=STEEL)
	draw.rounded_rectangle((14, SHEET_TOP, 57, SHEET_BASE), radius=2, fill=SHEET)
	draw.line((14, SHEET_BASE + 1, 57, SHEET_BASE + 1), fill=DARK_STEEL)

	# Foot of the bed, matching the headboard's language.
	draw.rounded_rectangle((LEFT, FOOT_TOP, RIGHT, BOTTOM), radius=5, fill=PANEL, outline=OUTLINE)
	for x in (10, 61):
		draw.point((x, FOOT_TOP + 5), fill=LIGHT_STEEL)

	return art


def generate() -> None:
	art = _bed()
	art.save(BED_OUTPUT)
	print("generated: %s (%dx%d)" % (BED_OUTPUT, art.width, art.height))


if __name__ == "__main__":
	generate()
