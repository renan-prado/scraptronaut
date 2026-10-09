class_name SpeechBubble
extends MarginContainer
## Character speech bubble: what they say and the key that does it.
## Lives on a CanvasLayer, UI-sized; only its position comes from the world, via follow().
## See docs/arquitetura/interface-e-camera.md.

const ART: Texture2D = preload("res://assets/interface/speech_bubble.png")

## Must match tools/gerar_interface.py: corner/edge/center split is a shared decision.
const SIDE: int = 9
const BORDER: int = 4
const TAIL_Y: int = 9
const TAIL_WIDTH: int = 11
const TAIL_HEIGHT: int = 7

## How many rows of the tail overlap the bubble's bottom border, to open the mouth.
const TAIL_OVERLAP: int = 2

## Integer scale, like the rest of the project's upscaled pixel art.
const SCALE: int = 2

## Speech and action text size — see docs/arquitetura/interface-e-camera.md for why they're equal.
const SPEECH_SIZE: int = Fonts.SMALL
const ACTION_SIZE: int = Fonts.SMALL

## Speech is neutral; action is amber, this game's "press this" color.
const SPEECH_COLOR: String = "dbe8f7"
const ACTION_COLOR: String = "ffd98a"

## Gap between the key and what it does.
const GAP: int = 5

## Padding between the drawn border and the text, beyond the border itself.
const PADDING_X: int = 8
const PADDING_Y: int = 5

var _speech: Label
var _action: Label
var _key: KeyCap
var _row: HBoxContainer


func _init() -> void:
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override(&"separation", 2)
	add_child(content)

	_speech = Fonts.label(SPEECH_COLOR, SPEECH_SIZE)
	_speech.name = "Speech"
	content.add_child(_speech)

	_row = HBoxContainer.new()
	_row.name = "Action"
	_row.add_theme_constant_override(&"separation", GAP)
	content.add_child(_row)

	_key = KeyCap.new()
	_key.name = "Key"
	_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_key)

	_action = Fonts.label(ACTION_COLOR, ACTION_SIZE)
	_action.name = "Text"
	_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_action)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin: int = BORDER * SCALE
	add_theme_constant_override(&"margin_left", margin + PADDING_X)
	add_theme_constant_override(&"margin_right", margin + PADDING_X)
	add_theme_constant_override(&"margin_top", margin + PADDING_Y)
	add_theme_constant_override(&"margin_bottom", margin + PADDING_Y)
	# Never narrower than the tail itself.
	custom_minimum_size = Vector2((TAIL_WIDTH + BORDER) * SCALE, 0)


## What the character says. Empty `speech` shows only the key and action; empty `key_name`
## shows the action with no cap — the "energy ran out" case. See docs/arquitetura/interface-e-camera.md
## for why build mode's refusal text overrides `color`.
func say(speech: String, key_name: String, action: String, color: String = ACTION_COLOR) -> void:
	_speech.text = speech
	_speech.visible = speech != ""
	_action.text = action
	_action.add_theme_color_override(&"font_color", Color(color))
	_row.visible = action != ""
	_key.visible = key_name != ""
	if key_name != "":
		_key.show_key(key_name)
	visible = true


func silence() -> void:
	visible = false


## Puts the tail tip at the requested WORLD point. Call every frame.
func follow(global_target: Vector2) -> void:
	size = get_combined_minimum_size()
	var on_screen: Vector2 = get_viewport().get_canvas_transform() * global_target
	var top: float = size.y + float((TAIL_HEIGHT - TAIL_OVERLAP) * SCALE)
	position = (on_screen - Vector2(size.x * 0.5, top)).round()


## Nine-piece frame plus the tail — same split as the HUD plate.
func _draw() -> void:
	var border: float = float(BORDER * SCALE)
	var width: float = maxf(size.x - border * 2.0, 0.0)
	var height: float = maxf(size.y - border * 2.0, 0.0)
	var end: int = SIDE - BORDER

	_piece(Rect2(0, 0, BORDER, BORDER), Rect2(0, 0, border, border))
	_piece(Rect2(end, 0, BORDER, BORDER), Rect2(size.x - border, 0, border, border))
	_piece(Rect2(0, end, BORDER, BORDER), Rect2(0, size.y - border, border, border))
	_piece(
		Rect2(end, end, BORDER, BORDER),
		Rect2(size.x - border, size.y - border, border, border)
	)

	_piece(Rect2(BORDER, 0, 1, BORDER), Rect2(border, 0, width, border))
	_piece(Rect2(BORDER, end, 1, BORDER), Rect2(border, size.y - border, width, border))
	_piece(Rect2(0, BORDER, BORDER, 1), Rect2(0, border, border, height))
	_piece(Rect2(end, BORDER, BORDER, 1), Rect2(size.x - border, border, border, height))

	_piece(Rect2(BORDER, BORDER, 1, 1), Rect2(border, border, width, height))

	# Tail last: its first two rows erase the bubble's bottom border, opening the mouth.
	var tail := Vector2(TAIL_WIDTH, TAIL_HEIGHT) * SCALE
	var corner := Vector2(
		roundf((size.x - tail.x) * 0.5),
		size.y - float(TAIL_OVERLAP * SCALE)
	)
	_piece(Rect2(0, TAIL_Y, TAIL_WIDTH, TAIL_HEIGHT), Rect2(corner, tail))


func _piece(clip: Rect2, dest: Rect2) -> void:
	if dest.size.x <= 0.0 or dest.size.y <= 0.0:
		return
	draw_texture_rect_region(ART, dest, clip)
