extends Node2D
## The work day: energy, pickaxe and bed.
## Building and demolishing are the same thing here — work hit into a cell — and
## work costs energy, which only comes back by sleeping. See docs/arquitetura/trabalho-energia-e-dia.md.

## The player script, only to read MAX_ENERGY below. The actual node comes from the tree in _ready.
const Player: GDScript = preload("res://scripts/player.gd")

## How many hammer hits close one floor square. See docs/arquitetura/trabalho-energia-e-dia.md.
const HAMMER_HITS_PER_SQUARE: float = 12.0

## Energy the pickaxe burns per second, derived from the square above so animation
## cadence and work cost never drift apart. See docs/arquitetura/trabalho-energia-e-dia.md.
const ENERGY_PER_SECOND: float = (
	StationMap.WORK_PER_CELL[StationMap.Type.FLOOR]
	/ (HAMMER_HITS_PER_SQUARE * Player.WORK_CYCLE)
)

## How long a full bar lasts, in seconds of continuous hammering. For reading/tests only.
const SECONDS_PER_DAY: float = Player.MAX_ENERGY / ENERGY_PER_SECOND

const WORK_KEY: Key = KEY_F
const SLEEP_KEY: Key = KEY_E

## Where the speech bubble's tail touches, relative to the player: top of the head.
const SPEECH_HEIGHT: Vector2 = Vector2(0, -104)

## Above this fraction of full energy, lying down is a choice, not a need. See
## docs/arquitetura/trabalho-energia-e-dia.md — the bed never refuses.
const DAY_AHEAD_FRACTION: float = 0.6

## What he says at the bed, by how much he still has left today.
const LINE_TOO_EARLY: String = "Não está muito cedo para dormir?"
const LINE_SLEEPY: String = "Dormir parece uma boa ideia"
const LINE_EXHAUSTED: String = "Estou caindo de sono"
const LINE_DONE: String = "Acabei por hoje"

## At a site, with no energy left.
const LINE_NO_ENERGY: String = "Estou muito cansado pra isso"

## Duration of the three sleep phases, in seconds: fade out, night, fade in.
const FADE_OUT: float = 0.9
const NIGHT: float = 0.6
const FADE_IN: float = 0.9

## Work bar, drawn OUTSIDE the site's cell. See docs/arquitetura/trabalho-energia-e-dia.md.
const WORK_BAR: Vector2 = Vector2(52, 9)

## Gap between the bar and the cell's edge.
const BAR_GAP: float = 5.0

## Dead zone, as a fraction of a cell, before the bar flips to the other side.
const ABOVE_SITE_FRACTION: float = 0.25

const BAR_BACKGROUND_COLOR: Color = Color(0.06, 0.08, 0.13, 0.85)
const BAR_FILL_COLOR: Color = Color(1.0, 0.76, 0.33)

## Yellow target frame on the aimed site — the only way to know which cell F will hit.
## See docs/arquitetura/trabalho-energia-e-dia.md for why it's thin and unfilled.
const TARGET_COLOR: Color = Color(1.0, 0.95, 0.62, 0.55)

## Frame thickness, in world pixels.
const TARGET_THICKNESS: float = 3.0

## Gap between the panel and the screen's corner.
const SCREEN_MARGIN: float = 12.0

## Gap between the day counter and the bar, inside the panel's row.
const PANEL_GAP: int = 4

## Day counter's text size inside the panel — one step above the rest of the UI.
## See docs/arquitetura/interface-e-camera.md.
const DAY_SIZE: int = Fonts.MEDIUM

## Gap for the day's inset — smaller than the outer panel's, since it has no rivet.
const DAY_GAP: int = 4

var day: int = 1

var _map: StationMap
var _player: Node2D
var _build_mode: Node2D
var _bed: Bed

## Cell the pickaxe is hitting this frame; empty unless a site is in progress.
var _site: Vector2i = Vector2i.ZERO

## A site is aimed at this frame. Separate from _hitting: the frame shows up BEFORE
## the player presses F, since it's what tells them where F will land.
var _has_target: bool = false
var _hitting: bool = false

var _sleeping: bool = false

var _bubble: SpeechBubble
var _counter: Label
var _panel: HudPanel
var _energy_bar: EnergyBar
var _dark: ColorRect


func _ready() -> void:
	_map = get_parent().get_node("Map") as StationMap
	_player = get_parent().get_node("Player") as Node2D
	_build_mode = get_parent().get_node("BuildMode") as Node2D
	_bed = get_parent().get_node_or_null("Bed") as Bed
	_build_ui()
	if _player.has_signal(&"energy_changed"):
		_player.connect(&"energy_changed", _show_energy)
		# Also synced right away: the player's _ready runs BEFORE this one (an
		# earlier sibling), so its first emission is missed otherwise.
		_show_energy(
			_player.get(&"energy"),
			_player.get_script().get_script_constant_map()["MAX_ENERGY"]
		)
	# Below the build cursor (100), above the map: the work bar can't cover the selection rectangle.
	z_index = 90


func _process(delta: float) -> void:
	if _sleeping or _build_mode.get(&"active"):
		_has_target = false
		_hitting = false
		_bubble.silence()
		queue_redraw()
		return

	# The site comes from the character's FACING, not distance: with one site to
	# the south and another east, it's which way he's turned that decides.
	_site = _map.nearby_site(_player.global_position, _player.call(&"heading"))
	_has_target = _map.type_at(_site) == StationMap.Type.CONSTRUCTION
	var energy: float = _player.get(&"energy")
	var wants_to: bool = Input.is_physical_key_pressed(WORK_KEY)

	_hitting = _has_target and wants_to and energy > 0.0
	if _hitting:
		_hit(delta, energy)
	else:
		_player.call(&"stop_working")
	_speak(_has_target, energy)
	queue_redraw()


## Converts energy into work, in this order: the map only gets what the player can
## pay, and the player only pays what the site accepted.
func _hit(delta: float, energy: float) -> void:
	var requested: float = minf(ENERGY_PER_SECOND * delta, energy)
	var used: float = _map.work(_site, requested)
	if used > 0.0:
		_player.call(&"spend_energy", used)
	_player.call(&"work_toward", _map.center_of(_site))


func _unhandled_input(event: InputEvent) -> void:
	if _sleeping or _build_mode.get(&"active"):
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# E also opens the hangar gate, in build mode. This node is a later sibling,
	# so it sees the event first — and only consumes it near the bed.
	if (event as InputEventKey).physical_keycode != SLEEP_KEY:
		return
	if _bed == null or not _bed.is_near(_player.global_position):
		return
	_lie_down()
	get_viewport().set_input_as_handled()


# --- sleep ---------------------------------------------------------------

func _lie_down() -> void:
	_sleeping = true
	_hitting = false
	_bubble.silence()
	_player.call(&"lie_down", _bed.sleep_point())
	# Energy comes back mid-night, screen faded out: seeing the bar fill with the
	# character still lying down would spoil the day-turning beat.
	var night: Tween = create_tween()
	night.tween_property(_dark, ^"color:a", 1.0, FADE_OUT)
	night.tween_interval(NIGHT)
	night.tween_callback(_dawn)
	night.tween_property(_dark, ^"color:a", 0.0, FADE_IN)
	night.tween_interval(0.4)
	night.tween_callback(_stand_up)


func _dawn() -> void:
	day += 1
	_player.call(&"rest")
	_update_counter()


func _stand_up() -> void:
	_player.call(&"stand_up", _bed.wake_point())
	_sleeping = false


# --- drawing -----------------------------------------------------------------

## Target frame and progress bar, both drawn in world space over the site.
func _draw() -> void:
	if not _has_target:
		return
	var side: float = float(StationMap.CELL)
	var box := Rect2(Vector2(_site) * side, Vector2(side, side))
	draw_rect(box.grow(-TARGET_THICKNESS * 0.5), TARGET_COLOR, false, TARGET_THICKNESS)
	if not _hitting:
		return
	var corner: Vector2 = _bar_corner(box)
	draw_rect(Rect2(corner - Vector2.ONE, WORK_BAR + Vector2(2, 2)), BAR_BACKGROUND_COLOR, true)
	var done: float = _map.progress_at(_site)
	draw_rect(Rect2(corner, Vector2(WORK_BAR.x * done, WORK_BAR.y)), BAR_FILL_COLOR, true)


## Progress bar corner, against the OUTSIDE of the site's cell, on the side
## opposite the player. See docs/arquitetura/trabalho-energia-e-dia.md.
func _bar_corner(box: Rect2) -> Vector2:
	var center: Vector2 = box.position + box.size * 0.5
	var threshold: float = center.y - box.size.y * ABOVE_SITE_FRACTION
	var above: bool = _player.global_position.y < threshold
	var y: float = box.end.y + BAR_GAP if above else box.position.y - BAR_GAP - WORK_BAR.y
	return Vector2(center.x - WORK_BAR.x * 0.5, y)


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	layer.layer = 40
	add_child(layer)

	# The night curtain shares this layer, on top of everything else here.
	_dark = ColorRect.new()
	_dark.name = "Night"
	_dark.color = Color(0.02, 0.03, 0.06, 0.0)
	_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_dark)

	# Top right corner: the left one belongs to build mode's shortcut icon.
	_panel = HudPanel.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_top = SCREEN_MARGIN
	_panel.offset_right = -SCREEN_MARGIN
	# The plate grows LEFT and DOWN from the corner as max energy adds segments.
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	layer.add_child(_panel)

	# One row per topic inside the plate.
	var row := HBoxContainer.new()
	row.name = "DayAndEnergy"
	row.add_theme_constant_override(&"separation", PANEL_GAP)
	_panel.content.add_child(row)

	# The counter sits in an inset carved into the plate itself.
	var inset := HudPanel.new(HudPanel.Plate.RECESSED)
	inset.name = "Day"
	inset.tighten(DAY_GAP)
	row.add_child(inset)

	_counter = Fonts.label("dbe8f7", DAY_SIZE)
	_counter.name = "Counter"
	inset.content.add_child(_counter)

	_energy_bar = EnergyBar.new()
	_energy_bar.name = "Energy"
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_energy_bar)

	# The bubble comes after the panel: both share this layer.
	_bubble = SpeechBubble.new()
	_bubble.name = "Bubble"
	_bubble.visible = false
	layer.add_child(_bubble)

	_update_counter()


func _update_counter() -> void:
	_counter.text = "Dia %d" % day


func _show_energy(energy: float, max_energy: float) -> void:
	_energy_bar.show_bar(energy, max_energy)


## What the character says this frame, by precedence: bed, gate, site. See
## docs/arquitetura/trabalho-energia-e-dia.md.
func _speak(has_site: bool, energy: float) -> void:
	if _bed != null and _bed.is_near(_player.global_position):
		_bubble.say(_sleep_line(energy), "E", "Dormir")
	elif _map.has_nearby_gate(_player.global_position):
		_bubble.say("", "E", "Abrir ou fechar o portão")
	elif _hitting or not has_site:
		# While the pickaxe is swinging, the bubble gets out of the way.
		_bubble.silence()
		return
	elif energy <= 0.0:
		_bubble.say(LINE_NO_ENERGY, "", "Dorma para recuperar as energias")
	else:
		_bubble.say("", "F", "Trabalhar na obra")
	_bubble.follow(_player.global_position + SPEECH_HEIGHT)


## The bed's line comes from energy, and the middle step matches the bar turning red.
func _sleep_line(energy: float) -> String:
	if energy <= 0.0:
		return LINE_DONE
	if _player.call(&"is_low_energy"):
		return LINE_EXHAUSTED
	if energy > Player.MAX_ENERGY * DAY_AHEAD_FRACTION:
		return LINE_TOO_EARLY
	return LINE_SLEEPY
