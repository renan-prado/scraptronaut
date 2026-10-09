class_name KeyCap
extends TextureRect
## Drawn keyboard cap, one or two letters. Own node because tools/gerar_interface.py's
## cell order is a contract shared with build mode's shortcut icon. See docs/arquitetura/interface-e-camera.md.

const ART_SIMPLE: Texture2D = preload("res://assets/interface/keys.png")
const ART_DUAL: Texture2D = preload("res://assets/interface/dual_keys.png")

## Must match tools/gerar_interface.py: letter -> index -> cell, on both sides.
const ORDER_SIMPLE: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const ORDER_DUAL: Array[String] = [
	"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9"
]

const SIDE: int = 11
const COLUMNS_SIMPLE: int = 6

## Dual-cap width: two 5px letters, one px gap, same 3px side margin as the simple cap.
const DUAL_WIDTH: int = 17

## Drawn at 2x, like the rest of the project's upscaled pixel art. See docs/arquitetura/interface-e-camera.md.
const SCALE: int = 2


func _init() -> void:
	var clip := AtlasTexture.new()
	clip.atlas = ART_SIMPLE
	texture = clip
	stretch_mode = TextureRect.STRETCH_SCALE


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Which key the cap shows: a letter/digit ("E", "7") or a function key ("F1").
## `icon_scale` differs by context: text-line usage measures by the letter beside it (SCALE);
## the build-mode shortcut icon measures itself, so it asks for 1:1. See docs/arquitetura/interface-e-camera.md.
func show_key(key_name: String, icon_scale: int = SCALE) -> void:
	var clip := texture as AtlasTexture
	var dual_index: int = ORDER_DUAL.find(key_name.to_upper())
	if dual_index >= 0:
		clip.atlas = ART_DUAL
		clip.region = Rect2(dual_index * DUAL_WIDTH, 0, DUAL_WIDTH, SIDE)
	else:
		var index: int = ORDER_SIMPLE.find(key_name.to_upper())
		if index < 0:
			push_error("key has no art in the sheet: %s" % key_name)
			index = 0
		clip.atlas = ART_SIMPLE
		clip.region = Rect2(
			float((index % COLUMNS_SIMPLE) * SIDE),
			float((index / COLUMNS_SIMPLE) * SIDE),
			float(SIDE), float(SIDE)
		)
	custom_minimum_size = clip.region.size * icon_scale
	size = custom_minimum_size
