class_name HudPanel
extends MarginContainer
## HUD steel plate: nine-piece frame with content inside. See docs/arquitetura/interface-e-camera.md.
## Same sheet, two rows: RAISED (the plate) and RECESSED (a dent carved into it) —
## the day counter is a RECESSED HudPanel inside a RAISED one.

const ART: Texture2D = preload("res://assets/interface/panel.png")

## Must match tools/gerar_interface.py: corner/edge/center split is a shared decision.
const SIDE: int = 9
const BORDER: int = 4

## Integer scale, like the rest of the project's upscaled pixel art.
const SCALE: int = 2

enum Plate { RAISED, RECESSED }

var plate: Plate = Plate.RAISED

## Gap between frame and content, in screen pixels. tighten() can reduce it.
var _gap: int = BORDER * SCALE

## Where the panel's content goes: one row per topic, top to bottom.
var content: VBoxContainer


func _init(which: Plate = Plate.RAISED) -> void:
	plate = which
	content = VBoxContainer.new()
	content.name = "Content"
	add_child(content)


## Brings content closer to the frame. Only safe for the rivet-less plate.
func tighten(gap: int) -> void:
	_gap = maxi(gap, 2 * SCALE)
	if is_node_ready():
		_apply_gap()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_gap()


func _apply_gap() -> void:
	add_theme_constant_override(&"margin_left", _gap)
	add_theme_constant_override(&"margin_right", _gap)
	add_theme_constant_override(&"margin_top", _gap)
	add_theme_constant_override(&"margin_bottom", _gap)


func _draw() -> void:
	var border: float = float(BORDER * SCALE)
	var width: float = maxf(size.x - border * 2.0, 0.0)
	var height: float = maxf(size.y - border * 2.0, 0.0)
	var top: int = int(plate) * SIDE
	var end: int = SIDE - BORDER

	# Corners: fixed size, never stretched — the rivet lives here.
	_piece(Rect2(0, top, BORDER, BORDER), Rect2(0, 0, border, border))
	_piece(Rect2(end, top, BORDER, BORDER), Rect2(size.x - border, 0, border, border))
	_piece(Rect2(0, top + end, BORDER, BORDER), Rect2(0, size.y - border, border, border))
	_piece(
		Rect2(end, top + end, BORDER, BORDER),
		Rect2(size.x - border, size.y - border, border, border)
	)

	# Edges: one-pixel slice stretched along the side.
	_piece(Rect2(BORDER, top, 1, BORDER), Rect2(border, 0, width, border))
	_piece(Rect2(BORDER, top + end, 1, BORDER), Rect2(border, size.y - border, width, border))
	_piece(Rect2(0, top + BORDER, BORDER, 1), Rect2(0, border, border, height))
	_piece(Rect2(end, top + BORDER, BORDER, 1), Rect2(size.x - border, border, border, height))

	# Center: one pixel stretched both ways.
	_piece(Rect2(BORDER, top + BORDER, 1, 1), Rect2(border, border, width, height))


func _piece(clip: Rect2, dest: Rect2) -> void:
	if dest.size.x <= 0.0 or dest.size.y <= 0.0:
		return
	draw_texture_rect_region(ART, dest, clip)
