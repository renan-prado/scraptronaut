# Font proof: renders game phrases with generate_font.py's metrics, saves an
# enlarged PNG to screenshots/, and checks that no game text needs a glyph
# the sheet doesn't have. Unused since the VT323 switch — see generate_font.py.
#
# Rendered proof exists because a font isn't checked by reading the glyph
# table: a wrong letter is invisible in a list of "#" and jumps out in a word.
#
# Scanning the scripts exists because a missing glyph doesn't complain: the
# engine draws nothing and moves on.
import glob
import re
import sys

from PIL import Image

import generate_font as font

OUTPUT = "screenshots/_fonte.png"

## Text between double quotes, not crossing a line break.
BETWEEN_QUOTES = re.compile(r'"([^"\n]*)"')

ZOOM = 5
MARGIN = 6
BACKGROUND = (26, 32, 44, 255)
INK = (219, 232, 247, 255)

PHRASES = [
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"abcdefghijklmnopqrstuvwxyz",
	"0123456789  .,:;!?()-—·×/%",
	"áàâã éê í óôõ úü ç ÁÂÃ ÉÊ Ç",
	"Não está muito cedo para dormir?",
	"Estou caindo de sono · Acabei por hoje",
	"CONSTRUÇÃO · Portão de nave · Demolir",
	"Dia 12 · 22 células alteradas · F1",
]


def _width(table: dict, phrase: str) -> int:
	total = 0
	for letter in phrase:
		if letter == " ":
			total += font.SPACE
			continue
		drawing, _ = table[letter]
		total += font._size(drawing)[0] + font.ADVANCE
	return total


def _write(art: Image.Image, table: dict, phrase: str, x: int, y: int) -> None:
	for letter in phrase:
		if letter == " ":
			x += font.SPACE
			continue
		drawing, top = table[letter]
		for dy, row in enumerate(drawing):
			for dx, dot in enumerate(row):
				if dot == "#":
					art.putpixel((x + dx, y + top + dy), INK)
		x += font._size(drawing)[0] + font.ADVANCE


def _check_scripts(table: dict) -> int:
	"""Scans quoted text in scripts/*.gd for a missing glyph.

	Over-scanning is intentional: resource paths, node names and signal
	names get swept in along with the text the player reads. They're all
	ASCII, so they raise no false alarm, and filtering them out would cost
	more than it saves.
	"""
	missing = {}
	for path in sorted(glob.glob("scripts/*.gd")):
		with open(path, encoding="utf-8") as file:
			for text in re.findall(BETWEEN_QUOTES, file.read()):
				for letter in text:
					if letter != " " and letter not in table:
						missing.setdefault(letter, path)
	for letter, path in sorted(missing.items()):
		print("no glyph: %r, used in %s" % (letter, path))
	return len(missing)


def generate() -> None:
	table = font.glyphs()
	missing = sorted({c for f in PHRASES for c in f if c != " " and c not in table})
	if missing:
		print("no glyph: %s" % " ".join(missing))
		sys.exit(1)
	width = max(_width(table, f) for f in PHRASES) + MARGIN * 2
	height = len(PHRASES) * font.LINE_HEIGHT + MARGIN * 2
	art = Image.new("RGBA", (width, height), BACKGROUND)
	for i, phrase in enumerate(PHRASES):
		_write(art, table, phrase, MARGIN, MARGIN + i * font.LINE_HEIGHT)
	art = art.resize((width * ZOOM, height * ZOOM), Image.NEAREST)
	art.save(OUTPUT)
	print("generated: %s (%dx%d, %dx)" % (OUTPUT, art.width, art.height, ZOOM))
	if _check_scripts(table):
		sys.exit(1)
	print("no script needs a glyph the sheet doesn't have")


if __name__ == "__main__":
	generate()
