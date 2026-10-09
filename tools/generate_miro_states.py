# Generates the character's state sheets from assets/sprites/miro_8dir.png.
#
#   assets/sprites/miro_idle.png      4x8   breathing, one row per direction
#   assets/sprites/miro_working.png   4x8   pickaxe swinging, one per direction
#   assets/sprites/miro_sleeping.png  4x1   lying in bed, breathing
#
# WHY DERIVE INSTEAD OF REDRAWING
#
# The walk sheet came from hand-drawn art (docs/sprites-paste/), not a
# generator — redrawing the character in code would give a different
# character. Every pose here comes from frame 0 of each row (the idle pose)
# with small deformations and a drawn-on object. That's why breathing is
# 1-2px, not 6: what can be done without redrawing the body is compressing
# the silhouette, and heavy compression turns to rubber.
#
# WHY THE WORK SHEET'S CELL IS BIGGER
#
# The pickaxe reaches up to 30px from the hand, which would fall outside a
# 70x100 cell in side views. The work sheet uses 100x110, same ground line
# and horizontal center, so the Sprite2D offset changes with it — see
# scripts/player.gd, which keeps one offset per state.
import math

from PIL import Image, ImageDraw

SOURCE = "assets/sprites/miro_8dir.png"
IDLE_OUTPUT = "assets/sprites/miro_idle.png"
WORK_OUTPUT = "assets/sprites/miro_working.png"
SLEEP_OUTPUT = "assets/sprites/miro_sleeping.png"

COLUMNS: int = 4
ROWS: int = 8

## Source sheet row order. Same as DIRECTIONS in generate_miro_8dir.py and
## enum Facing in scripts/player.gd.
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

## Source frame: each row's idle pose.
BASE_FRAME: int = 0

# --- figure measurements -------------------------------------------------------

## Cut lines of the source cell (70x100), measured on the sheet, not assumed.
## Valid for all eight views since every figure shares the same grid with
## feet at the cell's base — height differences between them are 1-3px.
##
##   7..50   hair and face
##  50..64   shoulders and chest
##  64..80   hands, at the tips, torso between them
##  80..89   legs
##  89..100  boots
SHOULDER: int = 50
HIP: int = 80
GROUND: int = 100

# --- breathing --------------------------------------------------------------

## Rows where breathing splits the compression. Not joints — chosen by how
## they look on screen. The high cut falls mid-face, which is what spreads
## the compression over two bands instead of a visible step at the neck.
NECK: int = 34
WAIST: int = 56

## How much the figure sinks each frame of the cycle. The head sinks the
## full amount and the torso half that, splitting the compression instead
## of stepping at the neck.
##
## Two pixels on a 93px figure is 2%: reads as a chest rising and falling,
## not a shrinking character. Three already reads as a crouch — which is
## exactly why the hammer hit uses four.
BREATHING: list[int] = [0, 1, 2, 1]


def _sink(cell: Image.Image, amount: int) -> Image.Image:
	"""Drops the head `amount` px and the torso half that, feet still."""
	if amount <= 0:
		return cell.copy()
	width, height = cell.size
	head = cell.crop((0, 0, width, NECK))
	torso = cell.crop((0, NECK, width, WAIST))
	half = amount // 2
	out = cell.copy()
	# Erase waist-up before re-pasting: the crop keeps alpha, and pasting
	# over would leave the old outline peeking out above the new one.
	ImageDraw.Draw(out).rectangle((0, 0, width, WAIST - 1), fill=(0, 0, 0, 0))
	out.alpha_composite(torso, (0, NECK + half))
	out.alpha_composite(head, (0, amount))
	return out


## How much row `y` moved in a sink of `amount`. The same split as _sink,
## read backward — tells the pickaxe where the glove ended up (the hand
## sits below the waist, the band that doesn't move).
def _sink_at(y: int, amount: int) -> int:
	if amount <= 0:
		return 0
	if y < NECK:
		return amount
	if y < WAIST:
		return amount // 2
	return 0


# --- pickaxe ----------------------------------------------------------------

## Tool angles in the four frames, in screen degrees: 0 points right, growing
## downward. Order is raised, descending, hit, returning.
##
## The arc is short on purpose: no raised-arm pose exists on the sheet, so a
## 180-degree swing would have the pickaxe trace a circle the body can't
## follow. Short, it reads as someone chipping with the wrist — and now the
## torso and arm move with it, in _strike_body() below.
##
## Left-facing rows are the right-facing ones mirrored on the vertical axis
## (a -> 180 - a), written already mirrored.
ANGLES: dict = {
	"down": [-80.0, -20.0, 65.0, -30.0],
	"right": [-75.0, -30.0, 25.0, -25.0],
	"left": [-105.0, -150.0, 155.0, -155.0],
	"down_right": [-78.0, -25.0, 45.0, -28.0],
	"down_left": [-102.0, -155.0, 135.0, -152.0],
	# The three back-facing rows are the hard case: the target is on the far
	# side of the body, and an arc centered on it disappears behind the
	# back. Here the arc runs along the MARGIN, on the holding hand's side,
	# so only the part crossing the body is hidden — reads as a sideways hit,
	# the best a back silhouette supports without a redrawn arm.
	"up": [-140.0, -175.0, 150.0, 170.0],
	"up_right": [-40.0, -5.0, 30.0, 10.0],
	"up_left": [-140.0, -175.0, 150.0, 170.0],
}

## Hand holding the tool in each row: the red glove's centroid, measured on
## the sheet. The pickaxe is anchored to it, not the figure's center,
## because a floating tool over the chest looks held by nobody.
HAND: dict = {
	"down": (51, 70),
	"right": (49, 68),
	"left": (21, 67),
	"down_right": (52, 67),
	"down_left": (17, 66),
	# From behind, the chosen hand is the one the tool runs toward — measured
	# centroids, no nudging. The hand is later re-pasted over the handle, so
	# it has to land where the glove actually is.
	"up": (18, 70),
	"up_right": (51, 68),
	"up_left": (18, 67),
}

## Rows where the tool sits on the FAR side of the body: facing away, the
## character hits a point farther than themself, and the pickaxe passes behind.
BEHIND: set = {"up", "up_right", "up_left"}

# --- the body's swing --------------------------------------------------------
#
# The first version only moved the tool: the figure stood still and the
# pickaxe spun beside it. What was missing was the character hitting —
# so the gesture now has three parts, all per-row or per-block deformations,
# never rotation (rotating a 70x100 figure with resampling shreds the
# one-pixel outline the whole sheet relies on).

## How much the torso leans toward the swing, in pixels at the top of the
## head. Lean decays linearly to zero at the feet (GROUND), so the head
## moves the full 8px, the hand under a third of that, and the boots nothing
## — weight shifting forward and back, the only way to make the hit move the
## whole body without redrawing any pose.
LEAN: list[int] = [-6, -2, 8, -3]

## How much the figure sinks each frame, same mechanic as breathing. Four
## pixels would be a crouch in an idle pose; in a swing it's exactly the
## point — the body gives under the tool on impact.
CROUCH: list[int] = [0, 1, 4, 2]

## How much the holding hand rises each frame.
##
## Always UP, never below its origin: rising shortens the arm, what the
## elbow does when it bends, and the hand overlaps the forearm with no gap.
## Lowering would open a gap between wrist and sleeve — a detached arm.
## The impact frame is the scale's zero: the arm is extended there, the
## correct pose, and the other three pull it back.
HAND_HEIGHT: list[int] = [-7, -3, 0, -5]

def _lean(cell: Image.Image, amount: int) -> Image.Image:
	"""Leans the figure `amount` px at the top, decaying to zero at the feet.

	A per-ROW shear — each full pixel row shifts sideways, no resampling —
	so no outline shreds. A real rotation would give the same gesture and destroy the 1px trace.
	"""
	if amount == 0:
		return cell.copy()
	width, height = cell.size
	out = Image.new("RGBA", cell.size, (0, 0, 0, 0))
	for y in range(height):
		out.alpha_composite(
			cell.crop((0, y, width, y + 1)), (round(amount * _profile(y)), y)
		)
	return out


## How much of the lean reaches this row: 1 at the figure's top, 0 at the
## ground. Linear, not just above the hip on purpose — the legs follow by a
## pixel, which is the weight transfer. Locked, the torso would look hinged onto a statue.
def _profile(y: int) -> float:
	return max(0.0, (GROUND - y) / float(GROUND))


## Half-box the hand fill may walk within, in pixels. The measured hand fits
## in 14x16, so there's margin to spare, well short of the torso's center —
## a final guard against a runaway fill.
HAND_BOX: tuple = (14, 12)

## How far the mask grows to capture the hand's outline, in pixels.
##
## Two, not one: the drawing closes the glove with a dark outline PLUS a
## shadow, and one pixel left the shadow behind at the old spot — a hollow
## red ring beside the arm, the most visible thing on the whole sheet. Growth
## only accepts dark pixels, or the two pixels would take a chip of the blue suit along.
HAND_OUTLINE: int = 2
MAX_DARK: int = 170


def _hand_region(cell: Image.Image, center: tuple) -> list:
	"""Pixels of the holding hand: the ones that move, and the ones that get erased.

	Flood fill from the glove's centroid, walking only skin and glove red.
	The red band is narrow on purpose: the drawing's dark outline is a
	continuous line running from the glove to the boot, and accepting
	near-black red let the fill run along it and eat the thigh. The outline
	itself comes in later, via growth, which doesn't propagate.
	"""
	px = cell.load()
	width, height = cell.size

	def in_box(x: int, y: int) -> bool:
		return abs(x - center[0]) <= HAND_BOX[0] and abs(y - center[1]) <= HAND_BOX[1]

	def is_hand(x: int, y: int) -> bool:
		if not in_box(x, y):
			return False
		r, g, b, a = px[x, y]
		if a < 128:
			return False
		if r > 225 and 140 < g < 215 and 90 < b < 180:
			return True  # skin
		# Band runs from dark red to the glove's light highlight. A low
		# ceiling here left the highlight behind as a hollow red thread. Hair
		# falls in this same band and isn't a problem: the box never reaches it.
		return 40 < r < 215 and g < 80 and b < 90  # glove

	seed = None
	for radius in range(8):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				x, y = center[0] + dx, center[1] + dy
				if 0 <= x < width and 0 <= y < height and is_hand(x, y):
					seed = (x, y)
					break
			if seed:
				break
		if seed:
			break
	if seed is None:
		return [], []

	seen = {seed}
	stack = [seed]
	while stack:
		x, y = stack.pop()
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			n = (x + dx, y + dy)
			if n in seen or not (0 <= n[0] < width and 0 <= n[1] < height):
				continue
			if is_hand(n[0], n[1]):
				seen.add(n)
				stack.append(n)

	def grow(above: int, below: int, with_red: bool) -> set:
		out = set(seen)
		for x, y in seen:
			for dx in range(-below, below + 1):
				for dy in range(-above, below + 1):
					n = (x + dx, y + dy)
					if not (0 <= n[0] < width and 0 <= n[1] < height) or not in_box(*n):
						continue
					r, g, b, a = px[n[0], n[1]]
					if a <= 128:
						continue
					if r + g + b < MAX_DARK:
						out.add(n)
					elif with_red and r > g * 1.6 and r > b * 1.6:
						out.add(n)
		return out

	# The hand is PASTED with a tight margin and ERASED with a bigger one —
	# but the extra margin only applies BELOW. The hand rises, so the trail
	# is left underneath; erasing the same margin above ate into the forearm
	# and the glove rose leaving a gap to the sleeve. The gap was worse than the trail.
	#
	# Pasting takes only the dark outline; erasing also takes red, since what
	# was left behind below was the glove's light highlight. Red below the
	# hand is always glove: the suit there is blue, and the scarf sits well above.
	tight: int = HAND_OUTLINE
	return (
		sorted(grow(tight, tight, False)),
		sorted(grow(tight, tight + 3, True)),
	)


## Loose blob smaller than this, after the hand moves, counts as leftover
## from the old spot. The source figure is a single blob (generate_miro_8dir.py
## guarantees it), so any island here was left by this generator.
MAX_LEFTOVER: int = 14


def _hand_only(cell: Image.Image, paste: list, rise: int) -> Image.Image:
	"""An image the size of the cell with just the hand, already at its new height.

	Used to re-paste the hand AFTER the tool. The grip is wide enough to
	cover the wrist, and with the hand underneath the frame showed a red
	block where it sat — nobody holding anything. On top, the fingers sit in
	front of the handle, how a pickaxe is actually held.
	"""
	out = Image.new("RGBA", cell.size, (0, 0, 0, 0))
	if not paste:
		return out
	src = cell.load()
	dst = out.load()
	for x, y in paste:
		if y - rise >= 0:
			dst[x, y - rise] = src[x, y]
	return out


def _clean_leftovers(cell: Image.Image) -> Image.Image:
	"""Erases pixel islands left behind from the hand's old spot.

	The margin erased in _hand_region() handles almost all of it, but it
	only reaches the dark parts: a light glove-highlight pixel escapes every
	so often. A loose pixel beside an otherwise clean figure is the first
	thing the eye catches, so a sweep closes the gap without tuning any more color bands.
	"""
	width, height = cell.size
	px = cell.load()
	seen = [[False] * width for _ in range(height)]
	out = cell.copy()
	dst = out.load()
	for y0 in range(height):
		for x0 in range(width):
			if seen[y0][x0] or px[x0, y0][3] <= 128:
				continue
			stack = [(x0, y0)]
			seen[y0][x0] = True
			island = []
			while stack:
				x, y = stack.pop()
				island.append((x, y))
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = x + dx, y + dy
					if (
						0 <= nx < width
						and 0 <= ny < height
						and not seen[ny][nx]
						and px[nx, ny][3] > 128
					):
						seen[ny][nx] = True
						stack.append((nx, ny))
			if len(island) <= MAX_LEFTOVER:
				for x, y in island:
					dst[x, y] = (0, 0, 0, 0)
	return out


def _bend_arm(cell: Image.Image, hand: tuple, rise: int) -> Image.Image:
	"""Raises the hand `rise` px, leaving the rest of the arm where it is.

	The gap left below is the arm shortening — what the elbow does when it
	bends — not a hole: the hand sits at the silhouette's TIP, so what
	disappears is the tip. `rise` is never negative for this reason: lowering
	would open a gap between wrist and sleeve, reading as a detached arm.
	"""
	paste, erase = hand
	if rise <= 0 or not paste:
		return cell.copy()
	out = cell.copy()
	dst = out.load()
	src = cell.load()
	for x, y in erase:
		dst[x, y] = (0, 0, 0, 0)
	for x, y in paste:
		if y - rise >= 0:
			dst[x, y - rise] = src[x, y]
	return out


## Pickaxe measurements, in source-cell pixels. The shaft runs 9px past the
## hand so the grip shows on both sides of the wrist.
SHAFT: int = 30
TAIL: int = 9
PICK_HEAD: int = 9

SHAFT_COLOR = (92, 71, 52, 255)
SHAFT_LIGHT = (138, 108, 78, 255)
GRIP_COLOR = (134, 46, 44, 255)
IRON_COLOR = (126, 139, 155, 255)
IRON_LIGHT = (198, 212, 226, 255)
IRON_SHADOW = (48, 56, 70, 255)
SPARK_COLOR = (255, 226, 150, 255)

## Margin of the work cell around the source cell. 15 on each side fits the
## shaft's 30px in side views; 10 on top fits the raised tool without touching the border.
SIDE_MARGIN: int = 15
TOP_MARGIN: int = 10


def _draw_pickaxe(canvas: Image.Image, pivot: tuple, degrees: float, hitting: bool) -> None:
	rad = math.radians(degrees)
	dx, dy = math.cos(rad), math.sin(rad)
	nx, ny = -dy, dx
	px, py = pivot

	def point(along: float, aside: float = 0.0) -> tuple:
		return (px + dx * along + nx * aside, py + dy * along + ny * aside)

	draw = ImageDraw.Draw(canvas)
	# Shaft: dark outline, wood, and a highlight on the top edge.
	draw.line([point(-TAIL), point(SHAFT)], fill=IRON_SHADOW, width=5)
	draw.line([point(-TAIL), point(SHAFT)], fill=SHAFT_COLOR, width=3)
	draw.line([point(-TAIL + 2, -1), point(SHAFT - 3, -1)], fill=SHAFT_LIGHT, width=1)
	# Grip, in the glove's color: ties the tool to the hand. Short, since the
	# hand is re-pasted over it — a long grip showed on both sides of the
	# wrist as a loose red block.
	draw.line([point(-TAIL + 3), point(1)], fill=GRIP_COLOR, width=3)

	# Head: a hexagon tapering to two tips, a point and a blade.
	body = [
		point(SHAFT + 1, -PICK_HEAD),
		point(SHAFT + 4, -3),
		point(SHAFT + 4, 3),
		point(SHAFT + 1, PICK_HEAD),
		point(SHAFT - 3, 3),
		point(SHAFT - 3, -3),
	]
	draw.polygon(body, fill=IRON_COLOR, outline=IRON_SHADOW)
	draw.line([point(SHAFT + 2, -PICK_HEAD + 2), point(SHAFT + 3, -3)], fill=IRON_LIGHT, width=1)

	if hitting:
		# Sparks only on the impact frame, only at the tip that lands.
		for along, aside in ((SHAFT + 6, -11), (SHAFT + 8, -7), (SHAFT + 7, -14)):
			draw.point(point(along, aside), fill=SPARK_COLOR)


# --- sleeping ----------------------------------------------------------------

## The two eye boxes on the "down" row, measured on the sheet. The lying pose
## is the FRONT view: seen from above, lying face-up shows the face, head on
## the pillow and feet at the edge — exactly the front view's framing.
EYES: list = [(29, 36, 30, 42), (39, 36, 41, 42)]

## Face skin color, read beside the eyes on the sheet itself.
SKIN_COLOR = (252, 194, 148, 255)
LASH_COLOR = (92, 48, 36, 255)

## Blanket: starts at the chest, covers to the feet. Not decoration — it's
## what sells the pose. Lying face-up, the standing legs' drawing would still
## be there and read as someone standing seen from above; covered, it's gone.
BLANKET_TOP: int = 56
BLANKET_BOTTOM: int = 96
BLANKET_LEFT: int = 12
BLANKET_RIGHT: int = 58

BLANKET_COLOR = (44, 86, 102, 255)
BLANKET_LIGHT = (72, 128, 146, 255)
BLANKET_BODY = (50, 93, 110, 255)
BLANKET_SHADOW = (24, 52, 64, 255)


def _cover(cell: Image.Image, amount: int) -> None:
	"""Draws the blanket over the figure, rising and falling with the chest."""
	draw = ImageDraw.Draw(cell)
	top = BLANKET_TOP + amount
	draw.rounded_rectangle(
		(BLANKET_LEFT, top, BLANKET_RIGHT, BLANKET_BOTTOM),
		radius=7,
		fill=BLANKET_COLOR,
		outline=BLANKET_SHADOW,
	)
	# Top fold: the light band gives the cloth thickness; without it the
	# blanket reads as a lid resting on the chest.
	draw.rounded_rectangle(
		(BLANKET_LEFT + 1, top + 1, BLANKET_RIGHT - 1, top + 4),
		radius=2,
		fill=BLANKET_LIGHT,
	)
	# The body's shape underneath — what separates a blanket from a box: a
	# flat sheet edge to edge has nobody in it.
	draw.rounded_rectangle(
		(22, top + 7, 48, BLANKET_BOTTOM - 12), radius=8, fill=BLANKET_BODY
	)
	for x in (21, 39):
		draw.ellipse((x, BLANKET_BOTTOM - 14, x + 11, BLANKET_BOTTOM - 4), fill=BLANKET_BODY)
	# Short creases, running from the body shape to the edge — cloth falling
	# off the sides. Straight edge-to-edge strokes would read as crate slats.
	for x0, x1 in ((20, 15), (50, 55)):
		for offset in (10, 22):
			draw.line(
				(x0, top + 9 + offset, x1, top + 15 + offset), fill=BLANKET_SHADOW
			)


def _close_eyes(cell: Image.Image) -> None:
	draw = ImageDraw.Draw(cell)
	for x0, y0, x1, y1 in EYES:
		draw.rectangle((x0, y0, x1, y1), fill=SKIN_COLOR)
		# The closed eyelid is wider than the open eye, and just one line.
		draw.line((x0 - 1, (y0 + y1) // 2, x1 + 1, (y0 + y1) // 2), fill=LASH_COLOR)


# --- assembly ----------------------------------------------------------------


def generate() -> None:
	sheet = Image.open(SOURCE).convert("RGBA")
	cw, ch = sheet.width // COLUMNS, sheet.height // ROWS
	bases = [
		sheet.crop((BASE_FRAME * cw, r * ch, (BASE_FRAME + 1) * cw, (r + 1) * ch))
		for r in range(ROWS)
	]

	idle = Image.new("RGBA", (cw * COLUMNS, ch * ROWS), (0, 0, 0, 0))
	for row in range(ROWS):
		for column, amount in enumerate(BREATHING):
			idle.paste(_sink(bases[row], amount), (column * cw, row * ch))
	idle.save(IDLE_OUTPUT)

	tw, th = cw + SIDE_MARGIN * 2, ch + TOP_MARGIN
	work = Image.new("RGBA", (tw * COLUMNS, th * ROWS), (0, 0, 0, 0))
	for row in range(ROWS):
		direction = DIRECTIONS[row]
		hand = HAND[direction]
		behind = direction in BEHIND
		angles = ANGLES[direction]
		# Which way the body throws its weight: the same side the tool
		# points to on impact. Read from the angle itself, not a separate
		# table, so the lean never fights the swing.
		sign = 1 if math.cos(math.radians(angles[2])) >= 0.0 else -1
		# The hand is found on the base frame, before any deformation: every
		# deformation is per-block or per-row, so the same pixels stay the hand afterward.
		hand_pixels = _hand_region(bases[row], hand)
		for column, degrees in enumerate(angles):
			lean = LEAN[column] * sign
			rise = -HAND_HEIGHT[column]
			body = _bend_arm(bases[row], hand_pixels, rise)
			body = _clean_leftovers(body)
			body = _sink(body, CROUCH[column])
			body = _lean(body, lean)

			# The wrist follows the body: the hand rose, the torso leaned and
			# the figure sank, so the shaft has to start where the glove ended up.
			hand_height = hand[1] - rise + _sink_at(hand[1], CROUCH[column])
			pivot = (
				hand[0] + SIDE_MARGIN + lean * _profile(hand_height),
				hand_height + TOP_MARGIN,
			)

			cell = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
			if behind:
				_draw_pickaxe(cell, pivot, degrees, column == 2)
				cell.alpha_composite(body, (SIDE_MARGIN, TOP_MARGIN))
			else:
				cell.alpha_composite(body, (SIDE_MARGIN, TOP_MARGIN))
				_draw_pickaxe(cell, pivot, degrees, column == 2)
			# The hand goes back on top of the tool, with the same
			# deformations as the body — translation on paste, then shear.
			# Sinking doesn't apply: the hand sits below the waist, the band that never moves.
			hand_in_front = _lean(
				_hand_only(bases[row], hand_pixels[0], rise), lean
			)
			cell.alpha_composite(hand_in_front, (SIDE_MARGIN, TOP_MARGIN))
			work.paste(cell, (column * tw, row * th))
	work.save(WORK_OUTPUT)

	sleep = Image.new("RGBA", (cw * COLUMNS, ch), (0, 0, 0, 0))
	for column, amount in enumerate(BREATHING):
		cell = _sink(bases[DIRECTIONS.index("down")], amount)
		_close_eyes(cell)
		_cover(cell, amount)
		sleep.paste(cell, (column * cw, 0))
	sleep.save(SLEEP_OUTPUT)

	print("generated: %s (%dx%d, frames of %dx%d)" % (IDLE_OUTPUT, idle.width, idle.height, cw, ch))
	print("generated: %s (%dx%d, frames of %dx%d)" % (WORK_OUTPUT, work.width, work.height, tw, th))
	print("generated: %s (%dx%d, frames of %dx%d)" % (SLEEP_OUTPUT, sleep.width, sleep.height, cw, ch))
	print("Sprite2D offset idle/sleeping: Vector2(0, %.1f)" % -(ch / 2.0 - 4.0))
	print("Sprite2D offset working:       Vector2(0, %.1f)" % -(th / 2.0 - 4.0))


if __name__ == "__main__":
	generate()
