class_name StationMap
extends Node2D
## Station map in free-form cells, no fixed-size modules.
## Only placed pieces are stored; the hull is derived every rebuild. See docs/arquitetura/mapa-da-estacao.md.

signal map_changed

enum Type { FLOOR, WALL, DOOR, GATE, CONSTRUCTION }

## Construction stages, in order.
enum Stage { MARKED, STRUCTURE, FINISH }

## How many stages each piece goes through before it's done.
const STAGES_TO: Dictionary = {
	Type.FLOOR: 3,
	Type.WALL: 2,
	Type.DOOR: 2,
	Type.GATE: 2,
}

## Work cost per cell, in the same unit as the player's energy (see docs/arquitetura/mapa-da-estacao.md for the dB-like math).
const WORK_PER_CELL: Dictionary = {
	Type.FLOOR: 12.5,
	Type.WALL: 5.0,
	Type.DOOR: 6.25,
	Type.GATE: 6.25,
}

## Distance, in cells, from which a work site can be hit.
const WORK_RANGE: float = 1.9

## Cosine of the half-angle of the pickaxe's aim cone (60 degrees each side).
const RANGE_COSINE: float = 0.5

const CELL: int = 64

## Neighbor-mask bit order. Must match DIRECTIONS in tools/gerar_tiles_estacao.py.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const CARDINALS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]

## TileSet source indices, in the order tools/construir_estacao.gd adds them.
const SOURCE_FLOOR: int = 0
const SOURCE_BORDER: int = 1
const SOURCE_HULL: int = 2
const SOURCE_DOOR: int = 3
const SOURCE_GATE: int = 4
const SOURCE_DETAIL: int = 5
const SOURCE_CONSTRUCTION: int = 6
const SOURCE_HOLE: int = 7
const SOURCE_MARKING: int = 8
const SOURCE_CONE: int = 9
const SOURCE_TAPE: int = 10

## Alt tile drawn while a piece isn't finished yet: same art, dimmed/translucent.
const ALT_UNDER_CONSTRUCTION: int = 1

## Alt tile for the door's caution tape without collision.
const ALT_TAPE_NO_COLLISION: int = 1

const CONSTRUCTION_VARIANTS: int = 4

const FLOOR_VARIANTS: int = 4

## Door atlas segments, two per segment: closed and open.
enum DoorSegment { WHOLE, HALF_A, HALF_B, MIDDLE }

## Detail atlas columns; row is orientation, in CARDINALS order.
enum Detail {
	PIPE, PIPE_FLANGE, PIPE_AMBER, PIPE_BAND, PIPE_END_A, PIPE_END_B, BOX, LIGHT
}

## Pipe-run filler pieces, randomized between the two ends.
const PIPE_MIDDLE: Array[Detail] = [
	Detail.PIPE, Detail.PIPE, Detail.PIPE_FLANGE, Detail.PIPE_BAND,
]

## Direction a wall run is walked, by orientation (clockwise around the station).
const RUN_DIRECTION: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
]

## How much of the outer wall gets decorated.
const PIPE_CHANCE: float = 0.8
const BOX_CHANCE: float = 0.55
const LIGHT_CHANCE: float = 0.22

## Distance, in cells, that auto-opens a door.
const DOOR_RANGE: float = 1.8

## Distance, in cells, for a gate to accept E.
const GATE_RANGE: float = 3.0

## Lastro's initial floor plan. Rectangles overlap on purpose — see docs/arquitetura/mapa-da-estacao.md.
const INITIAL_ROOMS: Array[Rect2i] = [
	Rect2i(2, 2, 6, 7),     # Storage room
	Rect2i(3, 9, 5, 3),     # Storage room, step to the southeast
	Rect2i(8, 9, 4, 3),     # Corridor: storage -> courtyard
	Rect2i(12, 5, 7, 9),    # Courtyard
	Rect2i(14, 3, 4, 2),    # Courtyard, north bulge
	Rect2i(19, 7, 3, 3),    # Corridor: courtyard -> hangar
	Rect2i(22, 3, 9, 8),    # Hangar
	Rect2i(24, 11, 6, 2),   # Hangar, south step
	Rect2i(12, 14, 3, 3),   # Corridor: courtyard -> workshop
	Rect2i(7, 17, 8, 6),    # Teardown workshop
	Rect2i(16, 14, 3, 3),   # Corridor: courtyard -> press room
	Rect2i(16, 17, 7, 6),   # Press room
]

## Dividers closing off each corridor mouth, leaving only the door gap.
const INITIAL_WALLS: Array[Vector2i] = [
	Vector2i(10, 11),
	Vector2i(20, 9),
	Vector2i(14, 15),
	Vector2i(18, 15),
]

## Two-cell doors, per docs/Estacao-Lastro-grid-e-modulos.
const INITIAL_DOORS: Array[Vector2i] = [
	Vector2i(10, 9), Vector2i(10, 10),
	Vector2i(20, 7), Vector2i(20, 8),
	Vector2i(12, 15), Vector2i(13, 15),
	Vector2i(16, 15), Vector2i(17, 15),
]

## Hangar gate: five cells on the east wall, per the approved plan.
const INITIAL_GATE: Array[Vector2i] = [
	Vector2i(31, 5), Vector2i(31, 6), Vector2i(31, 7), Vector2i(31, 8), Vector2i(31, 9),
]

const INITIAL_PLAYER_CELL: Vector2i = Vector2i(15, 9)

## Headboard cell of the bed, against the storage room's north wall.
const BED_CELL: Vector2i = Vector2i(3, 2)

@onready var _floor: TileMapLayer = $Floor
@onready var _border: TileMapLayer = $Border
@onready var _construction: TileMapLayer = $Construction
@onready var _hull: TileMapLayer = $Hull
@onready var _details: TileMapLayer = $Details
@onready var _openings: TileMapLayer = $Openings

## Cell -> Type. Only what was placed; the hull is left out.
var _cells: Dictionary = {}

## Cell -> bool, for doors and gates.
var _open: Dictionary = {}

## Cell -> Stage, only for Type.CONSTRUCTION cells.
var _stages: Dictionary = {}

## Cell -> the piece a site is about: FLOOR, WALL, DOOR or GATE.
var _targets: Dictionary = {}

## Sites running backward (demolition instead of construction).
var _demolishing: Dictionary = {}

## Sites opened where a wall already stood — see docs/arquitetura/construcao-e-obra.md.
var _was_wall: Dictionary = {}

## Work already hit at the current stage of each site.
var _work: Dictionary = {}

var _auto_hull: Dictionary = {}

## Empty cells enclosed by the station: open gaps to space, walled around.
var _holes: Dictionary = {}
var _doors: Array[Vector2i] = []

## Adjacent door cells forming a single gap, opening together.
var _gaps: Array = []
var _player: Node2D


func _ready() -> void:
	if _cells.is_empty():
		load_initial_plan()
	rebuild()


func _process(_delta: float) -> void:
	_update_doors()


# --- query ---------------------------------------------------------------

func type_at(cell: Vector2i) -> int:
	return _cells.get(cell, -1)


## Station's usable area, for hull and contact-shadow purposes.
func is_interior(cell: Vector2i) -> bool:
	var type: int = type_at(cell)
	return type == Type.FLOOR or type == Type.DOOR or type == Type.CONSTRUCTION


## Where it's possible to walk. Floor/wall sites stay collidable until done.
func is_walkable(cell: Vector2i) -> bool:
	var type: int = type_at(cell)
	if type == Type.FLOOR or type == Type.DOOR:
		return true
	return type == Type.CONSTRUCTION and _targets.get(cell, Type.FLOOR) == Type.DOOR


## Belongs to the station: includes the derived hull, which isn't in _cells.
func belongs(cell: Vector2i) -> bool:
	return _cells.has(cell) or _auto_hull.has(cell)


func is_auto_hull(cell: Vector2i) -> bool:
	return _auto_hull.has(cell)


func is_hole(cell: Vector2i) -> bool:
	return _holes.has(cell)


## Cell with no floor yet: a floor site, rising or falling. See docs/arquitetura/mapa-da-estacao.md.
func is_missing_floor(cell: Vector2i) -> bool:
	if _was_wall.has(cell):
		return false
	return type_at(cell) == Type.CONSTRUCTION and _targets.get(cell, Type.FLOOR) == Type.FLOOR


## The piece this cell's site is about. -1 outside construction.
func target_at(cell: Vector2i) -> int:
	return _targets.get(cell, -1) if type_at(cell) == Type.CONSTRUCTION else -1


## This cell's site is being undone instead of built.
func is_demolishing(cell: Vector2i) -> bool:
	return _demolishing.has(cell)


## Already a door, or about to be.
func _will_be_door(cell: Vector2i) -> bool:
	if type_at(cell) == Type.DOOR:
		return true
	return type_at(cell) == Type.CONSTRUCTION and _targets.get(cell, Type.FLOOR) == Type.DOOR


func stage_at(cell: Vector2i) -> int:
	return _stages.get(cell, -1)


## Works for both doors and gates: same open-state dictionary.
func is_open(cell: Vector2i) -> bool:
	return _open.get(cell, false)


func cell_at(global_pos: Vector2) -> Vector2i:
	return _floor.local_to_map(_floor.to_local(global_pos))


func center_of(cell: Vector2i) -> Vector2:
	return to_global(Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5)


func initial_player_position() -> Vector2:
	return center_of(INITIAL_PLAYER_CELL)


# --- plan ------------------------------------------------------------------

func load_initial_plan() -> void:
	_cells.clear()
	_open.clear()
	for room: Rect2i in INITIAL_ROOMS:
		for y: int in range(room.position.y, room.end.y):
			for x: int in range(room.position.x, room.end.x):
				_cells[Vector2i(x, y)] = Type.FLOOR
	for cell: Vector2i in INITIAL_WALLS:
		_cells[cell] = Type.WALL
	for cell: Vector2i in INITIAL_DOORS:
		_cells[cell] = Type.DOOR
	for cell: Vector2i in INITIAL_GATE:
		_cells[cell] = Type.GATE
		_open[cell] = false


# --- editing ---------------------------------------------------------------

func set_type(cell: Vector2i, type: Type) -> void:
	_cells[cell] = type
	if type == Type.GATE:
		_open[cell] = _open.get(cell, false)
	rebuild()


func erase(cell: Vector2i) -> void:
	_cells.erase(cell)
	_open.erase(cell)
	rebuild()


## Empty string means allowed; anything else is the refusal reason shown on screen.
## These are single-cell checks for the cursor; apply() is what actually commits, in batch.
func can_expand(cell: Vector2i) -> String:
	# Interior dividers are accepted and become floor via the same demolition site Demolish would open.
	if type_at(cell) == Type.WALL:
		return ""
	if _cells.has(cell):
		return "Piso já construído"
	if not _has_interior_neighbor(cell):
		return "Só é possível estender o piso a partir da estação"
	return ""


## Interior wall only on floor; the outer hull is already a wall.
func can_wall(cell: Vector2i, player_cell: Vector2i) -> String:
	if cell == player_cell:
		return "Você está parado neste quadrado"
	if type_at(cell) != Type.FLOOR:
		return "Parede só pode ser erguida sobre piso"
	return ""


## A door can go on a wall, or directly on floor (the cell becomes the frame).
## With an explicit axis the passage is the one the piece picked, not the one the map suggests.
func can_door(cell: Vector2i, player_cell: Vector2i, axis := Vector2i.ZERO) -> String:
	var type: int = type_at(cell)
	if cell == player_cell:
		return "Você está parado neste quadrado"
	if type == Type.DOOR:
		return "Porta já construída"
	if type == Type.GATE:
		return "Remova o portão de nave antes"
	if type == Type.CONSTRUCTION:
		return "Espere a obra terminar"
	if type == -1 and not is_auto_hull(cell):
		return "Porta só dentro da estação"
	if axis == Vector2i.ZERO:
		axis = _door_axis(cell)
		if axis == Vector2i.ZERO:
			return "A porta precisa de piso dos dois lados"
		return ""
	if not is_interior(cell + axis) or not is_interior(cell - axis):
		return "A porta precisa de piso dos dois lados"
	return ""


func can_gate(cell: Vector2i) -> String:
	if type_at(cell) == Type.GATE:
		return "Portão já construído"
	if type_at(cell) == Type.CONSTRUCTION:
		return "Espere a obra terminar"
	if not is_auto_hull(cell) and type_at(cell) != Type.WALL:
		return "Coloque sobre uma parede externa"
	if _outer_side(cell) == Vector2i.ZERO:
		return "O portão precisa de piso dentro e espaço aberto fora"
	return ""


## Whole-piece refusal, without applying anything.
func can_door_at(cells: Array[Vector2i], from_player: Vector2i) -> String:
	if cells.size() != 2:
		return "A porta ocupa dois quadrados"
	var step: Vector2i = cells[1] - cells[0]
	if not CARDINALS.has(step):
		return "Os dois quadrados da porta precisam estar juntos"
	var axis := Vector2i(0, 1) if step.x != 0 else Vector2i(1, 0)
	for cell: Vector2i in cells:
		var refusal: String = can_door(cell, from_player, axis)
		if refusal != "":
			return refusal
	return ""


## Demolish undoes one stage at a time: wall/door/gate go back to floor, floor opens vacuum.
func can_demolish(cell: Vector2i, player_cell: Vector2i) -> String:
	var type: int = type_at(cell)
	if type == -1:
		return "Não tem nada para demolir aqui"
	if (type == Type.FLOOR or type == Type.CONSTRUCTION) and cell == player_cell:
		return "Você está parado neste quadrado"
	return ""


# --- batch editing -----------------------------------------------------------

enum Action { EXPAND, WALL, DOOR, GATE, DEMOLISH }


## Applies an action to a set of cells at once, all-or-nothing. See docs/arquitetura/construcao-e-obra.md.
func apply(action: Action, cells: Array[Vector2i], from_player: Vector2i) -> String:
	var before: Dictionary = _cells.duplicate()
	var stages_before: Dictionary = _stages.duplicate()
	var targets_before: Dictionary = _targets.duplicate()
	var work_before: Dictionary = _work.duplicate()
	var demolishing_before: Dictionary = _demolishing.duplicate()
	var was_wall_before: Dictionary = _was_wall.duplicate()
	var reason: String = _execute(action, cells, from_player)
	if reason == "":
		reason = _validate_connectivity(from_player)
	if reason != "":
		_cells = before
		_stages = stages_before
		_work = work_before
		_targets = targets_before
		_demolishing = demolishing_before
		_was_wall = was_wall_before
		return reason
	rebuild()
	return ""


func _execute(action: Action, cells: Array[Vector2i], from_player: Vector2i) -> String:
	match action:
		Action.EXPAND:
			return _expand(cells)
		Action.WALL:
			return _build_wall(cells, from_player)
		Action.DOOR:
			return _order_door(cells, from_player)
		Action.GATE:
			return _open_gate(cells)
		Action.DEMOLISH:
			return _demolish(cells, from_player)
	return ""


## Opens a site on vacuum or hull, and TEARS DOWN any interior divider in the way.
## Floor/door/gate survive the rectangle; a divider is the only placed piece the rectangle tears down (see docs/arquitetura/construcao-e-obra.md).
func _expand(cells: Array[Vector2i]) -> String:
	var pending: Array[Vector2i] = []
	var walls: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if not _cells.has(cell):
			pending.append(cell)
		elif type_at(cell) == Type.WALL:
			walls.append(cell)
	if pending.is_empty() and walls.is_empty():
		return "Piso já construído"

	# Walls go through the same demolition site the Demolish tool would open.
	for cell: Vector2i in walls:
		_open_site(cell, Type.WALL, true)

	var opened: int = walls.size()
	while not pending.is_empty():
		var remaining: Array[Vector2i] = []
		var round: int = 0
		for cell: Vector2i in pending:
			if not _has_interior_neighbor(cell):
				remaining.append(cell)
				continue
			_open_site(cell, Type.FLOOR)
			round += 1
		opened += round
		if round == 0:
			break
		pending = remaining

	if opened == 0:
		return "Só é possível estender o piso a partir da estação"
	return ""


## Opens a site on a cell, saying what piece it's about and which way it runs.
func _open_site(cell: Vector2i, target: Type, demolishing: bool = false) -> void:
	if is_auto_hull(cell):
		_was_wall[cell] = true
	else:
		_was_wall.erase(cell)
	_cells[cell] = Type.CONSTRUCTION
	_targets[cell] = target
	_stages[cell] = (int(STAGES_TO[target]) - 1) if demolishing else int(Stage.MARKED)
	_work[cell] = 0.0
	if demolishing:
		_demolishing[cell] = true
	else:
		_demolishing.erase(cell)


## Closes a site, delivering the result.
func _finish_site(cell: Vector2i) -> void:
	var target: int = _targets.get(cell, Type.FLOOR)
	if not _demolishing.has(cell):
		_cells[cell] = target
	elif target == Type.FLOOR:
		_cells.erase(cell)
		_open.erase(cell)
	else:
		_cells[cell] = Type.FLOOR
		_open.erase(cell)
	_forget_site(cell)


## Interrupts a site and returns the cell to its state before it.
func _cancel_site(cell: Vector2i) -> void:
	var target: int = _targets.get(cell, Type.FLOOR)
	if _demolishing.has(cell):
		_cells[cell] = target
	elif target == Type.FLOOR:
		_cells.erase(cell)
		_open.erase(cell)
	else:
		_cells[cell] = Type.FLOOR
		_open.erase(cell)
	_forget_site(cell)


func _forget_site(cell: Vector2i) -> void:
	_targets.erase(cell)
	_stages.erase(cell)
	_work.erase(cell)
	_demolishing.erase(cell)
	_was_wall.erase(cell)


func _build_wall(cells: Array[Vector2i], from_player: Vector2i) -> String:
	var done: int = 0
	for cell: Vector2i in cells:
		if cell == from_player or type_at(cell) != Type.FLOOR:
			continue
		_open_site(cell, Type.WALL)
		done += 1
	if done == 0:
		return "Parede só pode ser erguida sobre piso"
	return ""


## A door is a two-cell piece, not a brush.
func _order_door(cells: Array[Vector2i], from_player: Vector2i) -> String:
	var refusal: String = can_door_at(cells, from_player)
	if refusal != "":
		return refusal
	for cell: Vector2i in cells:
		_open_site(cell, Type.DOOR)
	return ""


func _open_gate(cells: Array[Vector2i]) -> String:
	var done: int = 0
	var reason: String = ""
	for cell: Vector2i in cells:
		var refusal: String = can_gate(cell)
		if refusal != "":
			if reason == "":
				reason = refusal
			continue
		_cells[cell] = Type.GATE
		_open[cell] = _open.get(cell, false)
		done += 1
	if done == 0:
		return reason if reason != "" else "nada aqui aceita isso"
	return ""


## Demolish is construction in reverse: a piece goes down the same ladder it climbed.
## On a site, demolish CANCELS the work instead of opening another one.
func _demolish(cells: Array[Vector2i], from_player: Vector2i) -> String:
	var done: int = 0
	for cell: Vector2i in cells:
		var type: int = type_at(cell)
		if type == -1:
			continue
		if (type == Type.FLOOR or type == Type.CONSTRUCTION) and cell == from_player:
			continue
		if type == Type.CONSTRUCTION:
			_cancel_site(cell)
		else:
			_open_site(cell, type as Type, true)
		done += 1
	if done == 0:
		if cells.has(from_player):
			return "Você está parado neste quadrado"
		return "Não tem nada para demolir aqui"
	return ""


## After any edit, every walkable cell must stay reachable on foot from the player.
func _validate_connectivity(from_player: Vector2i) -> String:
	if not is_walkable(from_player):
		return "Você ficaria para fora da estação"

	var target: int = 0
	for cell: Vector2i in _cells:
		if is_walkable(cell):
			target += 1

	var seen: Dictionary = {from_player: true}
	var queue: Array[Vector2i] = [from_player]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for direction: Vector2i in CARDINALS:
			var neighbor: Vector2i = current + direction
			if seen.has(neighbor) or not is_walkable(neighbor):
				continue
			seen[neighbor] = true
			queue.append(neighbor)
	if seen.size() != target:
		return "Isso isolaria uma parte da estação"
	return ""


# --- undo ----------------------------------------------------------------

## Copy of everything the player can edit, for the cancel-plan flow.
func snapshot() -> Dictionary:
	return {
		"cells": _cells.duplicate(),
		"open": _open.duplicate(),
		"stages": _stages.duplicate(),
		"work": _work.duplicate(),
		"targets": _targets.duplicate(),
		"demolishing": _demolishing.duplicate(),
		"was_wall": _was_wall.duplicate(),
	}


func restore(state: Dictionary) -> void:
	_cells = (state["cells"] as Dictionary).duplicate()
	_open = (state["open"] as Dictionary).duplicate()
	_stages = (state["stages"] as Dictionary).duplicate()
	_work = (state["work"] as Dictionary).duplicate()
	_targets = (state["targets"] as Dictionary).duplicate()
	_demolishing = (state["demolishing"] as Dictionary).duplicate()
	_was_wall = (state["was_wall"] as Dictionary).duplicate()
	rebuild()


## How many cells changed since the snapshot, for the cancel-plan counter.
func differences(state: Dictionary) -> int:
	var before: Dictionary = state["cells"]
	var total: int = 0
	for cell: Vector2i in _cells:
		if before.get(cell, -1) != _cells[cell]:
			total += 1
	for cell: Vector2i in before:
		if not _cells.has(cell):
			total += 1
	return total


# --- construction ----------------------------------------------------------

## Work cost of one stage of this piece. All stages of a piece cost the same.
func work_per_stage(target: int) -> float:
	var steps: int = int(STAGES_TO.get(target, 1))
	return float(WORK_PER_CELL.get(target, 0.0)) / maxf(float(steps), 1.0)


## Hits `amount` of work into this cell's site and returns how much was actually consumed.
func work(cell: Vector2i, amount: float) -> float:
	if amount <= 0.0 or type_at(cell) != Type.CONSTRUCTION:
		return 0.0
	var per_stage: float = work_per_stage(_targets.get(cell, Type.FLOOR))
	if per_stage <= 0.0:
		return 0.0

	var leftover: float = amount
	var changed: bool = false
	while leftover > 0.0 and type_at(cell) == Type.CONSTRUCTION:
		var missing: float = per_stage - float(_work.get(cell, 0.0))
		if leftover < missing:
			_work[cell] = float(_work.get(cell, 0.0)) + leftover
			leftover = 0.0
			break
		leftover -= missing
		changed = true
		_close_stage(cell)
	if changed:
		rebuild()
	return amount - leftover


## Closes one step of the ladder. Construction climbs, demolition descends.
func _close_stage(cell: Vector2i) -> void:
	var target: int = _targets.get(cell, Type.FLOOR)
	var step: int = -1 if _demolishing.has(cell) else 1
	var stage: int = _stages.get(cell, Stage.MARKED) + step
	var done: bool = stage < 0 if step < 0 else stage >= int(STAGES_TO[target])
	if done:
		_finish_site(cell)
		return
	_stages[cell] = stage
	_work[cell] = 0.0


## How much of the site is done, 0 to 1, counting closed stages plus the current one's progress.
func progress_at(cell: Vector2i) -> float:
	if type_at(cell) != Type.CONSTRUCTION:
		return 0.0
	var target: int = _targets.get(cell, Type.FLOOR)
	var steps: int = int(STAGES_TO[target])
	var stage: int = _stages.get(cell, Stage.MARKED)
	var closed: float = float(steps - 1 - stage) if _demolishing.has(cell) else float(stage)
	var within: float = float(_work.get(cell, 0.0)) / work_per_stage(target)
	return clampf((closed + within) / float(steps), 0.0, 1.0)


## Site the pickaxe hits: the one underfoot, or the best aligned with `heading` within arm's reach.
## Returns the cell under the point when there's none — caller checks with type_at(), as the work node does.
## `heading` zeroed falls back to nearest, which is what the screenshot tool uses (no facing to go by).
func nearby_site(global_pos: Vector2, heading: Vector2 = Vector2.ZERO) -> Vector2i:
	var here: Vector2i = cell_at(global_pos)
	if type_at(here) == Type.CONSTRUCTION:
		return here

	var aiming: bool = heading != Vector2.ZERO
	var found: Vector2i = here
	var best: float = -2.0
	var closest: float = WORK_RANGE * CELL
	for cell: Vector2i in _cells:
		if _cells[cell] != Type.CONSTRUCTION:
			continue
		var toward: Vector2 = center_of(cell) - global_pos
		var distance: float = toward.length()
		if distance >= WORK_RANGE * CELL:
			continue
		var alignment: float = heading.dot(toward / distance) if aiming else 0.0
		if aiming and alignment < RANGE_COSINE:
			continue
		if alignment < best or (alignment == best and distance >= closest):
			continue
		best = alignment
		closest = distance
		found = cell
	return found


## Freezes all pending construction at one stage; used by tests and screenshots.
func force_stage(stage: Stage) -> void:
	for cell: Vector2i in _work:
		var last: int = int(STAGES_TO[_targets.get(cell, Type.FLOOR)]) - 1
		_stages[cell] = mini(int(stage), last) as Stage
		_work[cell] = 0.0
	rebuild()


## Closes one step of all pending construction; used by tests.
func advance_one_stage() -> void:
	for cell: Vector2i in _work.keys():
		_close_stage(cell)
	rebuild()


## Finishes all pending construction instantly; used by tests and screenshots.
func finish_all_construction() -> void:
	for cell: Vector2i in _work.keys():
		_finish_site(cell)
	rebuild()


func toggle_nearby_gate(global_pos: Vector2) -> bool:
	var origin: Vector2 = global_pos
	var best: Vector2i = Vector2i.ZERO
	var closest: float = GATE_RANGE * CELL
	var found: bool = false
	for cell: Vector2i in _cells:
		if _cells[cell] != Type.GATE:
			continue
		var distance: float = origin.distance_to(center_of(cell))
		if distance < closest:
			closest = distance
			best = cell
			found = true
	if not found:
		return false
	var group: Array[Vector2i] = _contiguous_group(best, Type.GATE)
	var new_state: bool = not _open.get(best, false)
	for cell: Vector2i in group:
		_open[cell] = new_state
	rebuild()
	Sound.door(new_state)
	return true


func has_nearby_gate(global_pos: Vector2) -> bool:
	for cell: Vector2i in _cells:
		if _cells[cell] != Type.GATE:
			continue
		if global_pos.distance_to(center_of(cell)) < GATE_RANGE * CELL:
			return true
	return false


# --- drawing -----------------------------------------------------------------

func rebuild() -> void:
	_recompute_hull()
	_floor.clear()
	_border.clear()
	_construction.clear()
	_hull.clear()
	_details.clear()
	_openings.clear()
	_doors.clear()
	_gaps.clear()

	for cell: Vector2i in _cells:
		match _cells[cell] as Type:
			Type.FLOOR:
				_paint_floor(cell)
			Type.DOOR:
				_paint_floor(cell)
				_doors.append(cell)
				_paint_door(cell)
			Type.GATE:
				_paint_gate(cell)
			Type.WALL:
				_paint_hull(cell)
			Type.CONSTRUCTION:
				_paint_construction(cell)

	for cell: Vector2i in _auto_hull:
		_paint_hull(cell)

	for cell: Vector2i in _holes:
		_paint_hole(cell)

	for cell: Vector2i in _cells:
		if is_interior(cell):
			_paint_border(cell)

	_group_gaps()
	_paint_cones()
	_paint_details()
	map_changed.emit()


func _group_gaps() -> void:
	var seen: Dictionary = {}
	for cell: Vector2i in _doors:
		if seen.has(cell):
			continue
		var group: Array[Vector2i] = _contiguous_group(cell, Type.DOOR)
		for member: Vector2i in group:
			seen[member] = true
		_gaps.append(group)


## Hull and holes come from the same pass: every empty cell touching the interior is a wall
## candidate; the ones reaching open space become solid hull, the enclosed ones become holes.
## A flood-fill from outside-in decides which is which. See docs/arquitetura/mapa-da-estacao.md.
func _recompute_hull() -> void:
	_auto_hull.clear()
	_holes.clear()

	var candidates: Dictionary = {}
	for cell: Vector2i in _cells:
		if not is_interior(cell):
			continue
		for direction: Vector2i in DIRECTIONS:
			var target: Vector2i = cell + direction
			if not _cells.has(target):
				candidates[target] = true
	if candidates.is_empty():
		return

	for cell: Vector2i in _reached_from_outside(candidates):
		_auto_hull[cell] = true
	for cell: Vector2i in candidates:
		if not _auto_hull.has(cell):
			_holes[cell] = true


## Flood-fill from a corner outside everything, walking only non-station cells.
func _reached_from_outside(candidates: Dictionary) -> Array[Vector2i]:
	var box: Rect2i = Rect2i(_cells.keys()[0], Vector2i.ONE)
	for cell: Vector2i in _cells:
		box = box.expand(cell).expand(cell + Vector2i.ONE)
	for cell: Vector2i in candidates:
		box = box.expand(cell).expand(cell + Vector2i.ONE)
	box = box.grow(1)

	var start: Vector2i = box.position
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var found: Array[Vector2i] = []
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		if candidates.has(current):
			found.append(current)
		for direction: Vector2i in CARDINALS:
			var neighbor: Vector2i = current + direction
			if seen.has(neighbor) or not box.has_point(neighbor):
				continue
			if _cells.has(neighbor):
				continue
			seen[neighbor] = true
			queue.append(neighbor)
	return found


func _paint_floor(cell: Vector2i) -> void:
	# Variant from a coordinate hash: stable, so rebuilding mid-construction doesn't flicker.
	var index: int = posmod(cell.x * 7 + cell.y * 13, FLOOR_VARIANTS * FLOOR_VARIANTS)
	_floor.set_cell(cell, SOURCE_FLOOR, Vector2i(index % FLOOR_VARIANTS, index / FLOOR_VARIANTS))


func _paint_border(cell: Vector2i) -> void:
	var mask: int = 255 ^ _mask(cell, func(c: Vector2i) -> bool: return is_interior(c))
	if mask == 0:
		return
	_border.set_cell(cell, SOURCE_BORDER, Vector2i(mask % 16, mask / 16))


func _paint_hull(cell: Vector2i, under_construction: bool = false) -> void:
	var mask: int = 255 ^ _mask(cell, func(c: Vector2i) -> bool: return belongs(c))
	var alt: int = ALT_UNDER_CONSTRUCTION if under_construction or _born_from_construction(cell) else 0
	_hull.set_cell(cell, SOURCE_HULL, Vector2i(mask % 16, mask / 16), alt)


## A wall that only exists because a floor site is still open next to it. See docs/arquitetura/mapa-da-estacao.md.
func _born_from_construction(cell: Vector2i) -> bool:
	var has_construction: bool = false
	for direction: Vector2i in DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		match type_at(neighbor):
			Type.CONSTRUCTION:
				if _targets.get(neighbor, Type.FLOOR) == Type.FLOOR:
					has_construction = true
			Type.FLOOR, Type.DOOR:
				return false
	return has_construction


## A hole is indexed only by its four sides: wall grows where the gap touches the station.
func _paint_hole(cell: Vector2i) -> void:
	var mask: int = 0
	for i: int in CARDINALS.size():
		if belongs(cell + CARDINALS[i]):
			mask |= 1 << i
	_hull.set_cell(cell, SOURCE_HOLE, Vector2i(mask, 0))


func _paint_construction(cell: Vector2i) -> void:
	if _targets.get(cell, Type.FLOOR) == Type.FLOOR:
		_paint_site(cell)
		return
	_paint_piece_under_construction(cell)


## New floor site, open to space.
func _paint_site(cell: Vector2i) -> void:
	var stage: int = _stages.get(cell, Stage.MARKED)
	if _was_wall.has(cell):
		_paint_site_on_hull(cell, stage)
		return
	if stage == Stage.MARKED:
		var neighborhood: Callable = func(c: Vector2i) -> bool: return is_interior(c)
		var mask: int = 255 ^ _mask(cell, neighborhood)
		_construction.set_cell(cell, SOURCE_MARKING, Vector2i(mask % 16, mask / 16))
		return
	var variant: int = posmod(cell.x * 5 + cell.y * 11, CONSTRUCTION_VARIANTS)
	_construction.set_cell(cell, SOURCE_CONSTRUCTION, Vector2i(variant, stage - 1))


## Site opened over the hull: the station grows THROUGH the wall, which stays up until
## the new floor is delivered. See docs/arquitetura/mapa-da-estacao.md for the stage table.
func _paint_site_on_hull(cell: Vector2i, stage: int) -> void:
	if stage > int(Stage.MARKED):
		var variant: int = posmod(cell.x * 5 + cell.y * 11, CONSTRUCTION_VARIANTS)
		_construction.set_cell(cell, SOURCE_CONSTRUCTION, Vector2i(variant, int(Stage.FINISH) - 1))
	if stage < int(Stage.FINISH):
		_paint_hull(cell, stage == int(Stage.STRUCTURE))
	# Tape goes in Details, on top, with no collision — the wall or finish plate blocks here.
	_details.set_cell(cell, SOURCE_TAPE,
		Vector2i(_construction_on_hull_mask(cell), 1), ALT_TAPE_NO_COLLISION)


## Sides where the tape closes around the site on the hull. A neighbor that's the SAME
## site doesn't count, so a six-cell expansion gets one tape border, not one per cell.
func _construction_on_hull_mask(cell: Vector2i) -> int:
	var mask: int = 0
	for i: int in CARDINALS.size():
		if not _was_wall.has(cell + CARDINALS[i]):
			mask |= 1 << i
	return mask


## Wall or door under construction. Both rise over floor that already exists.
func _paint_piece_under_construction(cell: Vector2i) -> void:
	_paint_floor(cell)
	var target: int = _targets.get(cell, Type.WALL)
	var mask: int = _tape_mask(cell)
	if _stages.get(cell, Stage.MARKED) == Stage.MARKED:
		# Only the wall tape collides; the door one uses the no-collision alt.
		var no_collision: int = ALT_TAPE_NO_COLLISION if target == Type.DOOR else 0
		_construction.set_cell(cell, SOURCE_MARKING, Vector2i(mask, 0), no_collision)
		return
	if target == Type.DOOR:
		_paint_door(cell, true)
	else:
		# Half-built wall uses the same scaffolding grid as a floor site.
		var variant: int = posmod(cell.x * 5 + cell.y * 11, CONSTRUCTION_VARIANTS)
		_construction.set_cell(cell, SOURCE_CONSTRUCTION, Vector2i(variant, 0))
	_details.set_cell(cell, SOURCE_MARKING, Vector2i(mask, 1), ALT_TAPE_NO_COLLISION)


## Sides of the cell that don't belong to the same site marking.
func _tape_mask(cell: Vector2i) -> int:
	var mask: int = 0
	for i: int in CARDINALS.size():
		var target: int = target_at(cell + CARDINALS[i])
		if target == -1 or target == Type.FLOOR:
			mask |= 1 << i
	return mask


## Cone/caution stripe on floor touching the void. Collision already blocks it; this warns.
func _paint_cones() -> void:
	for cell: Vector2i in _cells:
		if _cells[cell] != Type.FLOOR:
			continue
		var mask: int = 0
		for i: int in CARDINALS.size():
			if is_missing_floor(cell + CARDINALS[i]):
				mask |= 1 << i
		if mask != 0:
			_details.set_cell(cell, SOURCE_CONE, Vector2i(mask, 0))


func _paint_door(cell: Vector2i, under_construction: bool = false) -> void:
	var row: int = door_row(cell)
	var toward_b: Vector2i = Vector2i(1, 0) if row == 0 else Vector2i(0, -1)
	var has_b: bool = _will_be_door(cell + toward_b)
	var has_a: bool = _will_be_door(cell - toward_b)

	var segment: int = DoorSegment.WHOLE
	if has_a and has_b:
		segment = DoorSegment.MIDDLE
	elif has_b:
		segment = DoorSegment.HALF_A
	elif has_a:
		segment = DoorSegment.HALF_B

	var column: int = segment * 2 + (1 if _open.get(cell, false) else 0)
	var alt: int = ALT_UNDER_CONSTRUCTION if under_construction else 0
	_openings.set_cell(cell, SOURCE_DOOR, Vector2i(column, row), alt)


## Door atlas row: 0 lying (leaf runs east-west, passage north-south), 1 standing.
## The neighboring half decides first; the map axis is only a fallback. See docs/arquitetura/mapa-da-estacao.md.
func door_row(cell: Vector2i) -> int:
	if _will_be_door(cell + Vector2i(1, 0)) or _will_be_door(cell + Vector2i(-1, 0)):
		return 0
	if _will_be_door(cell + Vector2i(0, 1)) or _will_be_door(cell + Vector2i(0, -1)):
		return 1
	return 0 if _door_axis(cell) == Vector2i(0, 1) else 1


func _paint_gate(cell: Vector2i) -> void:
	var outward: Vector2i = _outer_side(cell)
	if outward == Vector2i.ZERO:
		outward = Vector2i(0, -1)
	var column: int = CARDINALS.find(outward)
	var row: int = 1 if _open.get(cell, false) else 0
	_openings.set_cell(cell, SOURCE_GATE, Vector2i(column, row))


# --- hull decoration -------------------------------------------------------

## Wall cells with exactly one side facing space, mapped to that side. Corners are
## skipped on purpose: piping there would need a curve it doesn't have.
func _straight_faces() -> Dictionary:
	var faces: Dictionary = {}
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in _auto_hull:
		candidates.append(cell)
	for cell: Vector2i in _cells:
		if _cells[cell] == Type.WALL:
			candidates.append(cell)

	for cell: Vector2i in candidates:
		# A wall still born from construction gets no pipe, as a reminder it's still a site.
		if _born_from_construction(cell):
			continue
		var outward: int = -1
		var count: int = 0
		for i: int in CARDINALS.size():
			if not belongs(cell + CARDINALS[i]):
				count += 1
				outward = i
		if count == 1:
			faces[cell] = outward
	return faces


func _paint_details() -> void:
	var faces: Dictionary = _straight_faces()
	var visited: Dictionary = {}
	for cell: Vector2i in faces:
		if visited.has(cell):
			continue
		var orientation: int = faces[cell]
		var step: Vector2i = RUN_DIRECTION[orientation]

		var start: Vector2i = cell
		while faces.get(start - step, -1) == orientation:
			start -= step

		var run: Array[Vector2i] = []
		var current: Vector2i = start
		while faces.get(current, -1) == orientation:
			visited[current] = true
			run.append(current)
			current += step
		_decorate(run, orientation)


## Stable seed per run: the same wall always gets the same pipe layout.
func _seed(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)


func _decorate(run: Array[Vector2i], orientation: int) -> void:
	var total: int = run.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed(run[0])
	var occupied: Dictionary = {}

	if total >= 4 and rng.randf() < PIPE_CHANCE:
		var length: int = rng.randi_range(3, mini(total, 7))
		var start: int = rng.randi_range(0, total - length)
		var amber: int = rng.randi_range(1, length - 2) if length >= 4 else -1
		for i: int in length:
			var variant: int = Detail.PIPE
			if i == 0:
				variant = Detail.PIPE_END_A
			elif i == length - 1:
				variant = Detail.PIPE_END_B
			elif i == amber:
				variant = Detail.PIPE_AMBER
			else:
				variant = PIPE_MIDDLE[rng.randi_range(0, PIPE_MIDDLE.size() - 1)]
			occupied[start + i] = true
			_details.set_cell(run[start + i], SOURCE_DETAIL, Vector2i(variant, orientation))

	if total >= 3 and rng.randf() < BOX_CHANCE:
		for _attempt: int in 6:
			var position: int = rng.randi_range(0, total - 1)
			if occupied.has(position):
				continue
			occupied[position] = true
			_details.set_cell(run[position], SOURCE_DETAIL, Vector2i(Detail.BOX, orientation))
			break

	# The light sits on the inner face, so it only fits where the other side is real floor.
	var inward: Vector2i = -CARDINALS[orientation]
	for position: int in total:
		if occupied.has(position) or rng.randf() > LIGHT_CHANCE:
			continue
		if not is_interior(run[position] + inward):
			continue
		_details.set_cell(run[position], SOURCE_DETAIL, Vector2i(Detail.LIGHT, orientation))


func _mask(cell: Vector2i, has: Callable) -> int:
	var mask: int = 0
	for i: int in DIRECTIONS.size():
		if has.call(cell + DIRECTIONS[i]):
			mask |= 1 << i
	return mask


# --- automatic doors ---------------------------------------------------------

func _update_doors() -> void:
	if _gaps.is_empty():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player == null:
			return
	var reach: float = DOOR_RANGE * CELL
	var origin: Vector2 = _player.global_position
	for gap: Array in _gaps:
		var open_flag: bool = false
		for cell: Vector2i in gap:
			if origin.distance_to(center_of(cell)) < reach:
				open_flag = true
				break
		# The sound belongs to the GAP, not the cell — see docs/arquitetura/som.md.
		var changed: bool = false
		for cell: Vector2i in gap:
			if _open.get(cell, false) == open_flag:
				continue
			_open[cell] = open_flag
			_paint_door(cell)
			changed = true
		if changed:
			Sound.door(open_flag)


# --- rules -------------------------------------------------------------------

func _has_interior_neighbor(cell: Vector2i) -> bool:
	for direction: Vector2i in CARDINALS:
		if is_interior(cell + direction):
			return true
	return false


## Door passage axis: the pair of opposite sides that have floor. Zero when there's no pair.
func _door_axis(cell: Vector2i) -> Vector2i:
	for axis: Vector2i in [Vector2i(0, 1), Vector2i(1, 0)]:
		if is_interior(cell + axis) and is_interior(cell - axis):
			return axis
	return Vector2i.ZERO


## Side of the gate facing space. Requires floor on the opposite side.
func _outer_side(cell: Vector2i) -> Vector2i:
	for direction: Vector2i in CARDINALS:
		if belongs(cell + direction):
			continue
		if is_interior(cell - direction):
			return direction
	return Vector2i.ZERO


## Neighboring cells of the same type; used for door gaps and gates, which open as one piece.
func _contiguous_group(start: Vector2i, type: Type) -> Array[Vector2i]:
	var group: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for direction: Vector2i in CARDINALS:
			var neighbor: Vector2i = current + direction
			if seen.has(neighbor) or type_at(neighbor) != type:
				continue
			seen[neighbor] = true
			group.append(neighbor)
			queue.append(neighbor)
	return group
