# Generates assets/sprites/miro.png from docs/sprite-miro-maior.png. Unused legacy sheet.
#
# The reference sheet's 8 drawings are independent redraws (not animation
# frames), so blinking is done by pasting only the closed-eyes BAND over the
# base drawing — not swapping the whole figure, which would make the body shimmer.
#
# Output: 2-frame horizontal sheet — 0 = open eyes, 1 = blinking.
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import miro_sheet

SOURCE = "docs/sprite-miro-maior.png"
OUTPUT = "assets/sprites/miro.png"

## Figure indices on the sheet, in reading order (row, then column).
BASE = 2
BLINK = 3

## Eye band in the cropped BASE figure's coordinates, covering eyebrows and eyes.
BAND = (78, 83, 166, 134)


def generate() -> None:
	figures = miro_sheet.figures(SOURCE)
	open_eyes = figures[BASE]
	closed_eyes = figures[BLINK]

	blinking = open_eyes.copy()
	blinking.paste(closed_eyes.crop(BAND), (BAND[0], BAND[1]))

	scale = miro_sheet.scale(figures)
	width = round(open_eyes.width * scale)
	height = round(open_eyes.height * scale)
	frames = [f.resize((width, height), Image.BOX) for f in (open_eyes, blinking)]

	sheet = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
	for i, frame in enumerate(frames):
		sheet.paste(frame, (i * width, 0))
	sheet.save(OUTPUT)
	print(f"generated: {OUTPUT} ({sheet.width}x{sheet.height}, {len(frames)} frames)")


generate()
