class_name EnergyBar
extends Control
## Energy bar as ">" segments, built from pieces. Segment count isn't fixed: each is
## worth ENERGY_PER_SEGMENT of the character's max energy. See docs/arquitetura/trabalho-energia-e-dia.md.

const ART: Texture2D = preload("res://assets/interface/energy.png")

## Must match tools/gerar_interface.py: sheet layout and segment step are shared decisions.
const PIECE_WIDTH: int = 8
const PIECE_HEIGHT: int = 11
const STEP: int = 6
const RAIL_WIDTH: int = 1
const CAP_WIDTH: int = 2

enum Piece { FULL, EMPTY, ARROW, GEM, RAIL, CAP }

## What one segment is worth: the cost of one floor-tile square.
const ENERGY_PER_SEGMENT: float = StationMap.WORK_PER_CELL[StationMap.Type.FLOOR]

## Drawn at a large pixel scale; always an integer factor to avoid blurring.
const SCALE: int = 2

## Gap between the gem and the frame, in art pixels.
const GEM_GAP: int = 1

## Segment and gem color. See docs/arquitetura/trabalho-energia-e-dia.md.
const ENERGY_COLOR: Color = Color(0.42, 0.84, 0.48)

## Below this fraction the bar warns in red.
const LOW_FRACTION: float = 0.25
const LOW_COLOR: Color = Color(0.88, 0.26, 0.22)

var _energy: float = 0.0
var _max: float = 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _size()


func show_bar(energy: float, max_energy: float) -> void:
	_energy = energy
	_max = maxf(max_energy, 1.0)
	custom_minimum_size = _size()
	queue_redraw()


## How many segments the bar has. Rounds up: leftover energy still needs a place to show.
func segments() -> int:
	return maxi(1, ceili(_max / ENERGY_PER_SEGMENT))


func _size() -> Vector2:
	var usable: int = PIECE_WIDTH + GEM_GAP + _frame_width() + PIECE_WIDTH
	return Vector2(usable, PIECE_HEIGHT) * SCALE


## Width of the straight frame, no arrow: cap plus segments.
func _frame_width() -> int:
	return CAP_WIDTH + segments() * STEP


func _draw() -> void:
	var total: int = segments()
	var full: float = _energy / ENERGY_PER_SEGMENT
	var color: Color = LOW_COLOR if _energy <= _max * LOW_FRACTION else ENERGY_COLOR

	_piece(Piece.GEM, 0, PIECE_WIDTH, color)

	var frame: int = PIECE_WIDTH + GEM_GAP
	_piece(Piece.CAP, frame, CAP_WIDTH)
	_stretch(Piece.RAIL, frame + CAP_WIDTH, total * STEP)
	_piece(Piece.ARROW, frame + _frame_width(), PIECE_WIDTH)

	# Empty segments first, then full ones on top (segments overlap at the tip).
	var x: int = frame + CAP_WIDTH
	for i: int in total:
		_piece(Piece.EMPTY, x + i * STEP, PIECE_WIDTH)
	for i: int in total:
		var part: float = clampf(full - float(i), 0.0, 1.0)
		if part <= 0.0:
			continue
		# The current segment is cut vertically, for mid-segment feedback.
		_piece(Piece.FULL, x + i * STEP, ceili(PIECE_WIDTH * part), color)


func _piece(piece: Piece, x: int, width: int, color: Color = Color.WHITE) -> void:
	if width <= 0:
		return
	var clip := Rect2(int(piece) * PIECE_WIDTH, 0, width, PIECE_HEIGHT)
	var dest := Rect2(x * SCALE, 0, width * SCALE, PIECE_HEIGHT * SCALE)
	draw_texture_rect_region(ART, dest, clip, color)


func _stretch(piece: Piece, x: int, width: int) -> void:
	if width <= 0:
		return
	var clip := Rect2(int(piece) * PIECE_WIDTH, 0, RAIL_WIDTH, PIECE_HEIGHT)
	var dest := Rect2(x * SCALE, 0, width * SCALE, PIECE_HEIGHT * SCALE)
	draw_texture_rect_region(ART, dest, clip)
