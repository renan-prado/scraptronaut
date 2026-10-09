class_name Fonts
extends RefCounted
## The game's named text sizes and the `Label` factory that uses them.
## VT323 isn't clean at every size; sizes here were checked on screen, not computed.
## See docs/arquitetura/interface-e-camera.md.

## Floating world text and the tool panel's rows. Also `gui/theme/default_font_size`.
const SMALL: int = 20

## HUD plate readout — today just the day counter.
const MEDIUM: int = 25

## The pause menu, and only it.
const LARGE: int = 30


## A `Label` with color and size set. No outline — see docs/arquitetura/interface-e-camera.md.
static func label(color: String, size: int = SMALL) -> Label:
	var written := Label.new()
	written.add_theme_color_override(&"font_color", Color(color))
	written.add_theme_font_size_override(&"font_size", size)
	return written
