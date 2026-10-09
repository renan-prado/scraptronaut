# Generates the game's bitmap text font. Unused since the VT323 switch — see
# project.godot and docs/arquitetura/interface-e-camera.md.
#
#   assets/interface/font.png   glyph atlas, white on transparent
#   assets/interface/font.fnt   BMFont metrics Godot imports
#
# Line metrics, in art pixels: LINE_HEIGHT total, BASE is the baseline, with
# an accent band above (rows 0-2, the gap at row 2 keeps a tilde from fusing
# with the letter below it), uppercase/ascenders in rows 3-8, lowercase in
# rows 5-8, descenders below the baseline at row 9.
#
# Accents are composed, not hand-drawn per letter: a small mark the generator
# stacks ABOVE the base glyph, so there's only one "a" drawing to maintain.
from PIL import Image

PNG_OUTPUT = "assets/interface/font.png"
FNT_OUTPUT = "assets/interface/font.fnt"

## The metrics, in art pixels. Changing these changes every text size in the game.
LINE_HEIGHT: int = 12
BASE: int = 9
TOP_TALL: int = 3
TOP_SHORT: int = 5

## Blank row between the accent mark and the letter. See header.
ACCENT_GAP: int = 1

## Gap between one letter and the next.
ADVANCE: int = 1

## Space width, in art pixels.
SPACE: int = 3

## Atlas cell size and columns per row. Deliberately loose: the whole sheet
## is a few kilobytes either way, and tight packing wouldn't save anything noticeable.
CELL_X: int = 8
CELL_Y: int = 12
COLUMNS: int = 16

WHITE = (255, 255, 255, 255)


# --- the glyphs ---------------------------------------------------------------
#
# Each drawing is a list of rows, "#" is ink. The top row of each drawing
# goes in the table alongside it, since that's what separates ascenders from
# descenders: "b" starts at TOP_TALL, "p" at TOP_SHORT.

TALL = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#"],
	"B": ["####.", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["####", "#...", "###.", "#...", "#...", "####"],
	"F": ["####", "#...", "###.", "#...", "#...", "#..."],
	"G": [".###.", "#...#", "#....", "#..##", "#...#", ".###."],
	"H": ["#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["###", ".#.", ".#.", ".#.", ".#.", "###"],
	"J": ["..##", "...#", "...#", "...#", "#..#", ".##."],
	"K": ["#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#...", "#...", "#...", "#...", "#...", "####"],
	"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#..#.", "#...#"],
	"S": [".####", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
	"X": ["#...#", ".#.#.", "..#..", "..#..", ".#.#.", "#...#"],
	"Y": ["#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".##.", "#..#", "#.##", "##.#", "#..#", ".##."],
	"1": [".#..", "##..", ".#..", ".#..", ".#..", "###."],
	"2": [".##.", "#..#", "...#", "..#.", ".#..", "####"],
	"3": ["####", "...#", "..#.", "...#", "#..#", ".##."],
	"4": ["..#.", ".##.", "#.#.", "####", "..#.", "..#."],
	"5": ["####", "#...", "###.", "...#", "#..#", ".##."],
	"6": [".##.", "#...", "###.", "#..#", "#..#", ".##."],
	"7": ["####", "...#", "..#.", "..#.", ".#..", ".#.."],
	"8": [".##.", "#..#", ".##.", "#..#", "#..#", ".##."],
	"9": [".##.", "#..#", "#..#", ".###", "...#", ".##."],
}

## Lowercase. Key is the letter; value is (top, drawing). Mixing ascenders,
## x-height and descenders is what makes a lowercase word read as a word,
## not a row of identical boxes.
SHORT = {
	"a": (TOP_SHORT, [".###", "#..#", "#..#", ".###"]),
	"b": (TOP_TALL, ["#...", "#...", "###.", "#..#", "#..#", "###."]),
	"c": (TOP_SHORT, [".###", "#...", "#...", ".###"]),
	"d": (TOP_TALL, ["...#", "...#", ".###", "#..#", "#..#", ".###"]),
	"e": (TOP_SHORT, [".##.", "####", "#...", ".###"]),
	"f": (TOP_TALL, [".##", "#..", "###", "#..", "#..", "#.."]),
	"g": (TOP_SHORT, [".##.", "#..#", "#..#", ".###", "...#", "###."]),
	"h": (TOP_TALL, ["#...", "#...", "###.", "#..#", "#..#", "#..#"]),
	"i": (TOP_TALL, ["#", ".", "#", "#", "#", "#"]),
	"j": (TOP_TALL, ["..#", "...", "..#", "..#", "..#", "..#", "..#", "##."]),
	"k": (TOP_TALL, ["#...", "#...", "#.#.", "##..", "#.#.", "#..#"]),
	"l": (TOP_TALL, ["#", "#", "#", "#", "#", "#"]),
	"m": (TOP_SHORT, ["#####", "#.#.#", "#.#.#", "#.#.#"]),
	"n": (TOP_SHORT, ["###.", "#..#", "#..#", "#..#"]),
	"o": (TOP_SHORT, [".##.", "#..#", "#..#", ".##."]),
	"p": (TOP_SHORT, ["###.", "#..#", "#..#", "###.", "#...", "#..."]),
	"q": (TOP_SHORT, [".##.", "#..#", "#..#", ".###", "...#", "...#"]),
	"r": (TOP_SHORT, ["#.#", "##.", "#..", "#.."]),
	"s": (TOP_SHORT, [".###", "##..", "..##", "###."]),
	"t": (TOP_TALL + 1, [".#.", "###", ".#.", ".#.", ".##"]),
	"u": (TOP_SHORT, ["#..#", "#..#", "#..#", ".###"]),
	"v": (TOP_SHORT, ["#...#", "#...#", ".#.#.", "..#.."]),
	"w": (TOP_SHORT, ["#...#", "#.#.#", "#.#.#", ".#.#."]),
	"x": (TOP_SHORT, ["#..#", ".##.", ".##.", "#..#"]),
	"y": (TOP_SHORT, ["#..#", "#..#", "#..#", ".###", "...#", "###."]),
	"z": (TOP_SHORT, ["####", "..#.", ".#..", "####"]),
}

## Punctuation and symbols. Same (top, drawing) shape as lowercase.
SIGNS = {
	".": (BASE - 1, ["#"]),
	",": (BASE - 1, [".#", "#."]),
	":": (TOP_SHORT + 1, ["#", ".", "#"]),
	";": (TOP_SHORT + 1, [".#", "..", ".#", "#."]),
	"!": (TOP_TALL, ["#", "#", "#", "#", ".", "#"]),
	"?": (TOP_TALL, [".##.", "#..#", "...#", "..#.", "....", "..#."]),
	"'": (TOP_TALL, ["#", "#"]),
	'"': (TOP_TALL, ["#.#", "#.#"]),
	"(": (TOP_TALL, [".#", "#.", "#.", "#.", "#.", "#.", ".#"]),
	")": (TOP_TALL, ["#.", ".#", ".#", ".#", ".#", ".#", "#."]),
	"-": (TOP_SHORT + 1, ["###"]),
	"—": (TOP_SHORT + 1, ["#####"]),
	"·": (TOP_SHORT + 1, ["#"]),
	"×": (TOP_SHORT - 1, ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]),
	"+": (TOP_SHORT - 1, ["..#..", "..#..", "#####", "..#..", "..#.."]),
	"=": (TOP_SHORT, ["####", "....", "####"]),
	"/": (TOP_TALL, ["...#", "...#", "..#.", ".#..", "#...", "#..."]),
	"\\": (TOP_TALL, ["#...", "#...", ".#..", "..#.", "...#", "...#"]),
	"%": (TOP_TALL, ["##..#", "##.#.", "..#..", ".#.##", "#..##", "....."]),
	"°": (TOP_TALL, ["##", "##"]),
	"[": (TOP_TALL, ["##", "#.", "#.", "#.", "#.", "#.", "##"]),
	"]": (TOP_TALL, ["##", ".#", ".#", ".#", ".#", ".#", "##"]),
	"<": (TOP_SHORT - 1, ["..#", ".#.", "#..", ".#.", "..#"]),
	">": (TOP_SHORT - 1, ["#..", ".#.", "..#", ".#.", "#.."]),
	"_": (BASE + 1, ["####"]),
	"*": (TOP_TALL, ["#.#", ".#.", "#.#"]),
	"#": (TOP_TALL, [".#.#.", "#####", ".#.#.", "#####", ".#.#."]),
	"@": (TOP_TALL, [".###.", "#...#", "#.###", "#.###", "#....", ".###."]),
	"&": (TOP_TALL, [".##..", "#..#.", ".##..", "#..#.", "#...#", ".####"]),
	"…": (BASE - 1, ["#.#.#"]),
}

## Accent marks, stacked ABOVE the letter. Each is as wide as it needs to be.
MARKS = {
	"agudo": [".#", "#."],
	"grave": ["#.", ".#"],
	"circunflexo": [".#.", "#.#"],
	# The tilde is a single step, not a wave: a wave needs up-down-up, and in
	# two rows that becomes a checkerboard that reads as noise, not a tilde.
	"til": [".###", "##.."],
	"trema": ["#.#"],
}

## Accented letter -> (base letter, mark). The cedilla is the only mark that
## drops below instead of stacking above, so it has its own table.
ACCENTED = {
	"á": ("a", "agudo"), "à": ("a", "grave"),
	"â": ("a", "circunflexo"), "ã": ("a", "til"),
	"é": ("e", "agudo"), "ê": ("e", "circunflexo"),
	"í": ("i", "agudo"),
	"ó": ("o", "agudo"), "ô": ("o", "circunflexo"),
	"õ": ("o", "til"),
	"ú": ("u", "agudo"), "ü": ("u", "trema"),
	"Á": ("A", "agudo"), "À": ("A", "grave"),
	"Â": ("A", "circunflexo"), "Ã": ("A", "til"),
	"É": ("E", "agudo"), "Ê": ("E", "circunflexo"),
	"Í": ("I", "agudo"),
	"Ó": ("O", "agudo"), "Ô": ("O", "circunflexo"),
	"Õ": ("O", "til"),
	"Ú": ("U", "agudo"), "Ü": ("U", "trema"),
}

## Accented "i" drops its dot: the accent takes its place.
NO_DOT = {"i": (["#", "#", "#", "#"], TOP_SHORT)}

## The cedilla: a hook off the base of the letter, curving left.
CEDILLA = ["..#", ".##"]
CEDILLAD = {"ç": "c", "Ç": "C"}


def _size(drawing: list) -> tuple:
	return max(len(row) for row in drawing), len(drawing)


def _compose(base: list, top: int, mark: list) -> tuple:
	"""Letter plus accent, on one grid. Returns (drawing, top)."""
	base_width, _ = _size(base)
	mark_width, mark_height = _size(mark)
	width = max(base_width, mark_width)
	base_indent = (width - base_width) // 2
	mark_indent = (width - mark_width) // 2
	rows = []
	for row in mark:
		rows.append(("." * mark_indent + row).ljust(width, "."))
	rows += ["." * width] * ACCENT_GAP
	for row in base:
		rows.append(("." * base_indent + row).ljust(width, "."))
	return rows, top - mark_height - ACCENT_GAP


def _add_cedilla(base: list, top: int) -> tuple:
	"""Letter plus cedilla. The mark drops below, so top doesn't change."""
	base_width, _ = _size(base)
	width = max(base_width, len(CEDILLA[0]))
	base_indent = (width - base_width) // 2
	mark_indent = (width - len(CEDILLA[0])) // 2
	rows = [("." * base_indent + row).ljust(width, ".") for row in base]
	for row in CEDILLA:
		rows.append(("." * mark_indent + row).ljust(width, "."))
	return rows, top


def glyphs() -> dict:
	"""All font glyphs: character -> (drawing, top)."""
	table = {}
	for letter, drawing in TALL.items():
		table[letter] = (drawing, TOP_TALL)
	for letter, (top, drawing) in SHORT.items():
		table[letter] = (drawing, top)
	for sign, (top, drawing) in SIGNS.items():
		table[sign] = (drawing, top)
	for letter, (base, mark) in ACCENTED.items():
		drawing, top = NO_DOT.get(base, table[base])
		table[letter] = _compose(drawing, top, MARKS[mark])
	for letter, base in CEDILLAD.items():
		drawing, top = table[base]
		table[letter] = _add_cedilla(drawing, top)
	return table


def generate() -> None:
	table = glyphs()
	order = sorted(table.keys(), key=ord)
	atlas_rows = (len(order) + COLUMNS - 1) // COLUMNS
	atlas = Image.new(
		"RGBA", (COLUMNS * CELL_X, atlas_rows * CELL_Y), (0, 0, 0, 0)
	)
	records = []
	for index, char in enumerate(order):
		drawing, top = table[char]
		width, height = _size(drawing)
		cx = (index % COLUMNS) * CELL_X
		cy = (index // COLUMNS) * CELL_Y
		for y, row in enumerate(drawing):
			for x, dot in enumerate(row):
				if dot == "#":
					atlas.putpixel((cx + x, cy + y), WHITE)
		records.append({
			"id": ord(char), "x": cx, "y": cy,
			"width": width, "height": height,
			"xoffset": 0, "yoffset": top, "xadvance": width + ADVANCE,
		})
	# Space has no drawing, just advance: a zero-width atlas cell.
	records.append({
		"id": 32, "x": 0, "y": 0, "width": 0, "height": 0,
		"xoffset": 0, "yoffset": 0, "xadvance": SPACE,
	})
	atlas.save(PNG_OUTPUT)

	png_name = PNG_OUTPUT.rsplit("/", 1)[-1]
	out = [
		'info face="Scraptronaut" size=%d bold=0 italic=0 charset="" unicode=1'
		' stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0'
		% LINE_HEIGHT,
		"common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0"
		% (LINE_HEIGHT, BASE, atlas.width, atlas.height),
		'page id=0 file="%s"' % png_name,
		"chars count=%d" % len(records),
	]
	for r in records:
		out.append(
			"char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d"
			" xadvance=%d page=0 chnl=15"
			% (r["id"], r["x"], r["y"], r["width"], r["height"],
				r["xoffset"], r["yoffset"], r["xadvance"])
		)
	out.append("kernings count=0")
	with open(FNT_OUTPUT, "w", encoding="utf-8", newline="\n") as file:
		file.write("\n".join(out) + "\n")

	print("generated: %s (%dx%d, %d glyphs)" % (
		PNG_OUTPUT, atlas.width, atlas.height, len(records)
	))
	print("generated: %s (line %d, base %d)" % (FNT_OUTPUT, LINE_HEIGHT, BASE))


if __name__ == "__main__":
	generate()
