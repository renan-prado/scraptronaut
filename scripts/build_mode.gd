extends Node2D
## Station build mode: cell cursor, tools and a free camera.
## See docs/arquitetura/construcao-e-obra.md.

## Cursor colors: refusal must read without the text.
const ALLOWED_COLOR: Color = Color(0.45, 0.95, 0.6, 0.28)
const REFUSED_COLOR: Color = Color(0.95, 0.35, 0.35, 0.26)
const OUTLINE_COLOR: Color = Color(0.95, 0.98, 1.0, 0.85)

## Refusal text color, matching the refused rectangle's.
const REFUSAL_COLOR: String = "ff9f9f"

## How long the refusal stays on screen. See docs/arquitetura/construcao-e-obra.md.
const REFUSAL_DURATION: float = 3.0

const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 1.5
const ZOOM_STEP: float = 1.12
const CAMERA_SPEED: float = 900.0

## Cap on cells per drag, so a careless wide drag can't apply thousands at once.
const MAX_PER_DRAG: int = 2500

enum Tool { EXPAND, WALL, DOOR, GATE, DEMOLISH }

## Each tool's name, in the order of keys 1-5 — same order as the ICONS cells.
const TOOL_NAMES: Array[String] = [
	"Expandir", "Parede", "Porta", "Portão de nave", "Demolir",
]

const ICONS: String = "res://assets/interface/tools.png"
const ICON_SIDE: int = 32

## The MODE icon's cell, after the five tools. Deliberately not any one tool's icon.
const MODE_ICON: int = 5

## The key that opens/closes the mode, and its name on the key-cap sheet.
const BUILD_KEY: Key = KEY_F1
const KEY_NAME: String = "F1"

## Gap between panels and the screen edge. Same as work.gd's — same top corner, two sides.
const SCREEN_MARGIN: float = 12.0

## Where the tool panel starts, measured from the top of the screen: the HUD
## plate's reserved height. See docs/arquitetura/construcao-e-obra.md — a
## tools/testar_estacao.gd check fails if the two panels start overlapping.
const BELOW_HUD: float = 71.0

## How far the key cap overhangs the shortcut icon's bottom-right corner.
const KEY_OVERHANG: float = 3.0

## Gap between a key cap and what it does, in the panel's rows.
const KEY_GAP: int = 5

## Gap between one row and the next, inside the panel.
const ROW_GAP: int = 2

## Chosen/hovered row colors. See docs/arquitetura/construcao-e-obra.md for why
## the chosen one is darker, not lighter, than the plate.
const CHOSEN_COLOR: Color = Color(0.10, 0.125, 0.172, 0.94)
const HOVER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.07)

## Panel row text color, and the disabled row's.
const ROW_COLOR: String = "dbe8f7"
const ROW_DISABLED_COLOR: Color = Color(0.55, 0.60, 0.68)

## Door atlas, used to draw the piece preview under the cursor.
const DOOR_ART: String = "res://assets/tiles/station/door.png"

## How visible the preview is.
const PREVIEW_ALPHA: float = 0.55

var active: bool = false

var _map: StationMap
var _player: Node2D
var _player_camera: Camera2D
var _camera: Camera2D

var _tool: Tool = Tool.EXPAND
var _cell: Vector2i = Vector2i.ZERO

## Why the cell under the cursor refuses the tool. Empty means accepted.
var _reason: String = ""

## Refusal of an actual attempt, shown on screen in a bubble anchored to the
## refused selection. See docs/arquitetura/construcao-e-obra.md.
var _message: String = ""

## Where the bubble's tail touches: the middle of the refused area's top edge, in world space.
var _refusal_point: Vector2 = Vector2.ZERO

## What's left of REFUSAL_DURATION.
var _refusal_time: float = 0.0

## Cell where the mouse button went down. While held, the area is the rectangle
## from here to the cursor; a plain click becomes a 1x1 rectangle.
var _anchor: Vector2i = Vector2i.ZERO
var _dragging: int = 0

## Which way the door's second cell points, as an index into StationMap.CARDINALS.
## Right-click rotates it 90 degrees at a time.
var _rotation: int = 1

## Map state when the mode opened; what Cancel restores to.
var _on_enter: Dictionary = {}
var _pending: int = 0

## Top-left shortcut, visible only with the mode CLOSED: mode icon with the key cap overhanging it.
var _shortcut: HudPanel

## The tool panel, top-right, visible only with the mode OPEN.
var _panel: HudPanel

var _bubble: SpeechBubble
var _confirm_button: Button
var _cancel_button: Button
var _door_art: Texture2D
var _buttons: Array[Button] = []


func _ready() -> void:
	_map = get_parent().get_node("Map") as StationMap
	_player = get_parent().get_node("Player") as Node2D
	_player_camera = _player.get_node("Camera2D") as Camera2D
	_camera = $Camera2D as Camera2D
	# Both cameras are born enabled, and the last one added wins make_current().
	_player_camera.make_current()
	_door_art = load(DOOR_ART)
	_build_ui()
	_update_ui()
	z_index = 100


func _process(delta: float) -> void:
	if not active:
		return
	_move_camera(delta)
	var target: Vector2i = _map.cell_at(get_global_mouse_position())
	if target != _cell:
		_cell = target
		_evaluate()
		_update_ui()
		queue_redraw()
	# After the camera: the bubble lives on a CanvasLayer and only its POSITION
	# comes from the world, so it needs repositioning whenever the view moves.
	if _message != "":
		_refusal_time -= delta
		if _refusal_time <= 0.0:
			_silence_refusal()
		else:
			_bubble.follow(_refusal_point)


## Esc is read in _input, before _unhandled_input: the pause menu is a later
## sibling and would otherwise get the event first.
func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).physical_keycode
		if key == BUILD_KEY:
			toggle()
			get_viewport().set_input_as_handled()
			return
		if not active and key == KEY_E:
			if _map.toggle_nearby_gate(_player.global_position):
				get_viewport().set_input_as_handled()
			return
		if active and (key == KEY_ENTER or key == KEY_KP_ENTER):
			confirm()
			get_viewport().set_input_as_handled()
			return
		if active and key >= KEY_1 and key <= KEY_5:
			_choose(key - KEY_1)
			get_viewport().set_input_as_handled()
		return

	if not active or not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_adjust_zoom(ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_zoom(1.0 / ZOOM_STEP)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
			var side: int = 1 if button.button_index == MOUSE_BUTTON_LEFT else -1
			# With a door in hand, right-click rotates instead of removing: a
			# fixed-size piece has no drag, so rotating is all that's left.
			if _is_fixed_piece():
				if side < 0 and button.pressed:
					_rotate_piece()
				elif side > 0 and not button.pressed:
					_apply(1, _area())
			elif button.pressed:
				_anchor = _cell
				_dragging = side
			elif _dragging == side:
				# Read BEFORE zeroing _dragging: _area() uses the anchor only
				# while a drag is in progress.
				_apply(side, _area())
				_dragging = 0
			queue_redraw()
		_:
			return
	get_viewport().set_input_as_handled()


func toggle() -> void:
	if active:
		confirm()
	else:
		_enter()


## Closes the mode, keeping the plan. No site moves by leaving here: construction
## only advances when the player hits it.
func confirm() -> void:
	if active:
		_exit()


## Closes the mode, undoing everything done since it opened.
func cancel() -> void:
	if not active:
		return
	if _pending > 0:
		_map.restore(_on_enter)
	_exit()


func _enter() -> void:
	active = true
	_dragging = 0
	_silence_refusal()
	_on_enter = _map.snapshot()
	_pending = 0
	_camera.global_position = _player.global_position
	_camera.zoom = _player_camera.zoom
	_camera.make_current()
	_cell = _map.cell_at(get_global_mouse_position())
	_anchor = _cell
	_evaluate()
	if _player.has_method(&"lock"):
		_player.call(&"lock", true)
	_update_ui()
	queue_redraw()


func _exit() -> void:
	active = false
	_dragging = 0
	_silence_refusal()
	_pending = 0
	_on_enter = {}
	_player_camera.make_current()
	if _player.has_method(&"lock"):
		_player.call(&"lock", false)
	_update_ui()
	queue_redraw()


# --- editing -----------------------------------------------------------------

func _choose(index: int) -> void:
	_tool = index as Tool
	_silence_refusal()
	_evaluate()
	_update_ui()
	queue_redraw()


## Fixed-piece tool: fixed size, no drag, no right-click removal. Today, just the door.
func _is_fixed_piece() -> bool:
	return _tool == Tool.DOOR


func _rotate_piece() -> void:
	_rotation = (_rotation + 1) % StationMap.CARDINALS.size()
	_silence_refusal()
	_evaluate()
	_update_ui()
	queue_redraw()


## The door's two cells, in order: anchor and the side it points to.
func _piece() -> Array[Vector2i]:
	return [_cell, _cell + StationMap.CARDINALS[_rotation]]


func _area() -> Rect2i:
	if _is_fixed_piece():
		var other: Vector2i = _cell + StationMap.CARDINALS[_rotation]
		var corner := Vector2i(mini(_cell.x, other.x), mini(_cell.y, other.y))
		return Rect2i(corner, (other - _cell).abs() + Vector2i.ONE)
	var anchor: Vector2i = _anchor if _dragging != 0 else _cell
	var start := Vector2i(mini(anchor.x, _cell.x), mini(anchor.y, _cell.y))
	var end := Vector2i(maxi(anchor.x, _cell.x), maxi(anchor.y, _cell.y))
	return Rect2i(start, end - start + Vector2i.ONE)


## Right-click always demolishes, whatever the active tool. The door is the
## exception — with it in hand, right-click rotates the piece.
func _apply(side: int, area: Rect2i) -> void:
	var tool: Tool = Tool.DEMOLISH if side < 0 else _tool
	if area.size.x * area.size.y > MAX_PER_DRAG:
		_announce("Área grande demais para uma vez só", area)
		return

	var cells: Array[Vector2i] = []
	if _is_fixed_piece():
		cells = _piece()
	else:
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				cells.append(Vector2i(x, y))

	var from_player: Vector2i = _map.cell_at(_player.global_position)
	_announce(_map.apply(_action(tool), cells, from_player), area)
	_pending = _map.differences(_on_enter)
	_evaluate()
	_update_ui()
	queue_redraw()


## Puts an attempt's refusal in the bubble, pointing at the area that caused it.
func _announce(reason: String, area: Rect2i) -> void:
	if reason == "":
		_silence_refusal()
		return
	var side: float = float(StationMap.CELL)
	_message = reason
	_refusal_point = Vector2(
		(float(area.position.x) + float(area.size.x) * 0.5) * side,
		float(area.position.y) * side
	)
	_refusal_time = REFUSAL_DURATION
	_bubble.say("", "", reason, REFUSAL_COLOR)
	_bubble.follow(_refusal_point)
	_update_ui()


func _silence_refusal() -> void:
	_message = ""
	_refusal_time = 0.0
	if _bubble != null:
		_bubble.silence()


func _action(tool: Tool) -> StationMap.Action:
	match tool:
		Tool.EXPAND:
			return StationMap.Action.EXPAND
		Tool.WALL:
			return StationMap.Action.WALL
		Tool.DOOR:
			return StationMap.Action.DOOR
		Tool.GATE:
			return StationMap.Action.GATE
		_:
			return StationMap.Action.DEMOLISH


## Cursor color: green when the area has at least one cell the tool accepts.
## See docs/arquitetura/construcao-e-obra.md.
func _evaluate() -> void:
	var tool: Tool = Tool.DEMOLISH if _dragging < 0 else _tool
	var from_player: Vector2i = _map.cell_at(_player.global_position)

	# The door is all-or-nothing: one refused half is enough to block it.
	if _is_fixed_piece():
		_reason = _map.can_door_at(_piece(), from_player)
		return

	var area: Rect2i = _area()
	if area.size.x * area.size.y > MAX_PER_DRAG:
		_reason = "Área grande demais para uma vez só"
		return

	var first: String = ""
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var refusal: String = _refusal(tool, Vector2i(x, y), from_player)
			if refusal == "":
				_reason = ""
				return
			if first == "":
				first = refusal
	_reason = first


func _refusal(tool: Tool, cell: Vector2i, from_player: Vector2i) -> String:
	match tool:
		Tool.EXPAND:
			return _map.can_expand(cell)
		Tool.WALL:
			return _map.can_wall(cell, from_player)
		Tool.DOOR:
			return _map.can_door(cell, from_player)
		Tool.GATE:
			return _map.can_gate(cell)
		_:
			return _map.can_demolish(cell, from_player)


# --- camera ------------------------------------------------------------------

func _move_camera(delta: float) -> void:
	var direction := Vector2(
		Input.get_axis(&"ui_left", &"ui_right"),
		Input.get_axis(&"ui_up", &"ui_down")
	)
	if Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direction.y += 1.0
	if direction == Vector2.ZERO:
		return
	# Dividing by zoom keeps the on-screen speed the same at any zoom level.
	_camera.global_position += direction.limit_length(1.0) * CAMERA_SPEED * delta / _camera.zoom.x


func _adjust_zoom(factor: float) -> void:
	var new_zoom: float = clampf(_camera.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	_camera.zoom = Vector2(new_zoom, new_zoom)


# --- cursor drawing ----------------------------------------------------------

func _draw() -> void:
	if not active:
		return
	var side: float = float(StationMap.CELL)
	var area: Rect2i = _area()
	var rect := Rect2(Vector2(area.position) * side, Vector2(area.size) * side)
	draw_rect(rect, ALLOWED_COLOR if _reason == "" else REFUSED_COLOR, true)
	draw_rect(rect, OUTLINE_COLOR, false, 2.0)
	if _is_fixed_piece():
		_draw_door_preview()


## Door preview: the tile's own art, half-transparent, on both cells.
func _draw_door_preview() -> void:
	var side: float = float(StationMap.CELL)
	var cells: Array[Vector2i] = _piece()
	var step: Vector2i = cells[1] - cells[0]
	var row: int = 0 if step.x != 0 else 1
	var toward_b := Vector2i(1, 0) if row == 0 else Vector2i(0, -1)
	for cell: Vector2i in cells:
		var other: Vector2i = cells[1] if cell == cells[0] else cells[0]
		var segment: int = 1 if cell + toward_b == other else 2
		var dest := Rect2(Vector2(cell) * side, Vector2(side, side))
		var clip := Rect2(segment * 2 * side, row * side, side, side)
		draw_texture_rect_region(_door_art, dest, clip,
			Color(1.0, 1.0, 1.0, PREVIEW_ALPHA))


# --- UI ----------------------------------------------------------------------
#
# TWO PANELS, NEVER BOTH AT ONCE. Closed: top-left shortcut (mode icon + F1 key
# cap). Open: top-right tool panel, in a column. Both are HudPanel, same steel
# plate as the HUD's. See docs/arquitetura/construcao-e-obra.md.

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	layer.layer = 50
	add_child(layer)
	_build_shortcut(layer)
	_build_panel(layer)
	_build_bubble(layer)


## The refusal bubble. Same box as the character's speech, same layer as the panels.
func _build_bubble(layer: CanvasLayer) -> void:
	_bubble = SpeechBubble.new()
	_bubble.name = "Refusal"
	_bubble.visible = false
	layer.add_child(_bubble)


## The shortcut to open the mode: icon and key cap, no words.
func _build_shortcut(layer: CanvasLayer) -> void:
	_shortcut = HudPanel.new()
	_shortcut.name = "Shortcut"
	_shortcut.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_shortcut.offset_left = SCREEN_MARGIN
	_shortcut.offset_top = SCREEN_MARGIN
	layer.add_child(_shortcut)

	# Icon and cap overlap, so they can't be container siblings.
	var frame := Control.new()
	frame.name = "Build"
	frame.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shortcut.content.add_child(frame)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = _crop_icon(load(ICONS), MODE_ICON)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)

	var cap := KeyCap.new()
	cap.name = "Key"
	# 1:1, not the panel rows' scale: here the cap overhangs an ICON_SIDE icon.
	cap.show_key(KEY_NAME, 1)
	frame.add_child(cap)
	var cap_size: Vector2 = cap.custom_minimum_size
	cap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	cap.offset_left = KEY_OVERHANG - cap_size.x
	cap.offset_top = KEY_OVERHANG - cap_size.y
	cap.offset_right = KEY_OVERHANG
	cap.offset_bottom = KEY_OVERHANG


## The tool panel: one row per key, top to bottom.
func _build_panel(layer: CanvasLayer) -> void:
	_panel = HudPanel.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_top = BELOW_HUD
	_panel.offset_right = -SCREEN_MARGIN
	# Grows LEFT and DOWN, like the HUD plate.
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	layer.add_child(_panel)
	_panel.content.add_theme_constant_override(
		&"separation", ROW_GAP
	)

	var sheet: Texture2D = load(ICONS)
	for i: int in TOOL_NAMES.size():
		var button := Button.new()
		button.name = TOOL_NAMES[i]
		button.text = TOOL_NAMES[i]
		button.icon = _crop_icon(sheet, i)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.toggle_mode = true
		button.add_theme_constant_override(&"h_separation", KEY_GAP)
		button.pressed.connect(_choose.bind(i))
		_style(button)
		_panel.content.add_child(_row(str(i + 1), button))
		_buttons.append(button)

	_confirm_button = _decision_button("Confirmar · Enter", confirm)
	_panel.content.add_child(_row("", _confirm_button))
	_cancel_button = _decision_button("Cancelar · Esc", cancel)
	_panel.content.add_child(_row("", _cancel_button))


## One panel row: the key cap and what it does, side by side.
func _row(key: String, right: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override(&"separation", KEY_GAP)
	if key == "":
		var gap := Control.new()
		gap.name = "Gap"
		gap.custom_minimum_size = Vector2(KeyCap.SIDE * KeyCap.SCALE, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
	else:
		var cap := KeyCap.new()
		cap.name = "Key"
		cap.show_key(key)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cap)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	return row


func _decision_button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = label.get_slice(" ", 0)
	button.text = label
	button.pressed.connect(action)
	_style(button)
	return button


## Strips Godot's default button theme and applies this plate's own.
func _style(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_color_override(&"font_color", Color(ROW_COLOR))
	button.add_theme_color_override(&"font_hover_color", Color(ROW_COLOR))
	button.add_theme_color_override(&"font_pressed_color", Color(ROW_COLOR))
	button.add_theme_color_override(&"font_focus_color", Color(ROW_COLOR))
	button.add_theme_color_override(&"font_disabled_color", ROW_DISABLED_COLOR)
	# All four states share the same plate; only the color changes.
	button.add_theme_stylebox_override(&"normal", _plate(Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override(&"focus", _plate(Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override(&"disabled", _plate(Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override(&"hover", _plate(HOVER_COLOR))
	button.add_theme_stylebox_override(&"pressed", _plate(CHOSEN_COLOR))


func _plate(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = ROW_GAP
	box.content_margin_right = ROW_GAP
	return box


func _crop_icon(sheet: Texture2D, index: int) -> AtlasTexture:
	var clip := AtlasTexture.new()
	clip.atlas = sheet
	clip.region = Rect2(index * ICON_SIDE, 0, ICON_SIDE, ICON_SIDE)
	return clip


func _update_ui() -> void:
	_shortcut.visible = not active
	_panel.visible = active
	if not active:
		return
	# Cancel only offers itself when there's something to undo.
	_cancel_button.disabled = _pending == 0
	for i: int in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == int(_tool))
