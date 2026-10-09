# Builds screenshots/miro_4dir_conferencia.png: the 16 cells of
# assets/sprites/miro_4dir.png enlarged and labeled. Unused: see generate_miro_4dir.py.
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
import generate_miro_4dir as g

SHEET = "assets/sprites/miro_4dir.png"
OUTPUT = "screenshots/miro_4dir_conferencia.png"

ZOOM: int = 4
BACKGROUND = (38, 38, 46, 255)


def check() -> None:
	sheet = Image.open(SHEET).convert("RGBA")
	fw = sheet.width // g.COLUMNS
	fh = sheet.height // g.ROWS

	cw, ch = fw * ZOOM + 20, fh * ZOOM + 46
	canvas = Image.new("RGBA", (cw * g.COLUMNS + 70, ch * g.ROWS + 10), BACKGROUND)
	brush = ImageDraw.Draw(canvas)
	for row in range(g.ROWS):
		brush.text((6, 10 + row * ch + ch // 2), g.DIRECTIONS[row][:4], fill=(255, 210, 120, 255))
		for column in range(g.COLUMNS):
			cell = sheet.crop((column * fw, row * fh, (column + 1) * fw, (row + 1) * fh))
			cell = cell.resize((fw * ZOOM, fh * ZOOM), Image.NEAREST)
			x0, y0 = 70 + column * cw, 10 + row * ch
			brush.rectangle(
				[x0, y0, x0 + fw * ZOOM + 19, y0 + fh * ZOOM + 40],
				outline=(120, 120, 140, 255),
			)
			canvas.alpha_composite(cell, (x0 + 10, y0 + 32))
			brush.text(
				(x0 + 10, y0 + 10),
				f"{g.DIRECTIONS[row]} q{column}   (sheet row {row} col {g.ORDER[column]})",
				fill=(200, 220, 255, 255),
			)
	Path(OUTPUT).parent.mkdir(exist_ok=True)
	canvas.save(OUTPUT)
	print(f"generated: {OUTPUT} ({canvas.width}x{canvas.height})")


check()
