extends SceneTree
## Checks the initial plan, build mode's rules and the work day.
##
## Usage: godot --headless --path . --script tools/test_station.gd
## Exits with the failure count, so it plugs straight into automated checks.

const C: int = 64

var _failures: int = 0


func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * C + C / 2.0, cell.y * C + C / 2.0)


func _check(name: String, actual: Variant, expected: Variant) -> void:
	var ok: bool = actual == expected
	if not ok:
		_failures += 1
	print("[%s] %s -> %s (expected %s)" % ["OK" if ok else "FAIL", name, actual, expected])


func _refused(name: String, reason: String, should_refuse: bool) -> void:
	var refused: bool = reason != ""
	var ok: bool = refused == should_refuse
	if not ok:
		_failures += 1
	var text: String = reason if refused else "allowed"
	print("[%s] %s -> %s" % ["OK" if ok else "FAIL", name, text])


func _initialize() -> void:
	var scene: Node = load("res://scenes/station.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame

	var map: StationMap = scene.get_node("Map")
	var player: CharacterBody2D = scene.get_node("Player")
	var build_mode: Node2D = scene.get_node("BuildMode")
	var work: Node2D = scene.get_node("Work")
	var bed: Bed = scene.get_node("Bed")
	var space := player.get_world_2d().direct_space_state

	var solid := func(cell: Vector2i) -> bool:
		var query := PhysicsPointQueryParameters2D.new()
		query.position = _point(cell)
		query.collision_mask = 1
		return not space.intersect_point(query).is_empty()

	print("--- initial plan collision")
	_check("courtyard center (15,9) clear", solid.call(Vector2i(15, 9)), false)
	_check("courtyard north hull (12,4) solid", solid.call(Vector2i(12, 4)), true)
	_check("storage room door (10,9) clear", solid.call(Vector2i(10, 9)), false)
	_check("corridor divider (10,11) solid", solid.call(Vector2i(10, 11)), true)
	_check("closed gate (31,7) solid", solid.call(Vector2i(31, 7)), true)
	_check("outside the station (60,40) clear", solid.call(Vector2i(60, 40)), false)
	_check("the bed occupies the headboard (3,2)", solid.call(Vector2i(3, 2)), true)
	_check("and the foot (3,3)", solid.call(Vector2i(3, 3)), true)
	_check("but it's reachable via (3,4)", solid.call(Vector2i(3, 4)), false)

	print("--- the player crosses the door and stops at the divider")
	# The storage room's corridor runs west to east; the wall line is column
	# 10, with a door on rows 9 and 10 and a divider on row 11.
	player.position = _point(Vector2i(8, 10))
	await physics_frame
	_check("crosses the door (8,10)->(12,10)", player.move_and_collide(Vector2(4 * C, 0)) == null, true)
	player.position = _point(Vector2i(8, 11))
	await physics_frame
	_check("divider blocks (8,11)->east", player.move_and_collide(Vector2(4 * C, 0)) != null, true)

	print("--- the door opens by proximity")
	player.position = map.center_of(Vector2i(15, 9))
	await process_frame
	_check("far: closed", map.is_open(Vector2i(10, 10)), false)
	player.position = map.center_of(Vector2i(9, 10))
	await process_frame
	_check("near: open", map.is_open(Vector2i(10, 10)), true)

	print("--- build rules")
	var from_player: Vector2i = Vector2i(15, 9)
	player.position = _point(from_player)
	await physics_frame

	_refused("expand touching the station (19,10)", map.can_expand(Vector2i(19, 10)), false)
	_refused("expand loose in the void (60,40)", map.can_expand(Vector2i(60, 40)), true)
	_refused("expand over floor (15,10)", map.can_expand(Vector2i(15, 10)), true)
	_refused("divider on floor (15,10)", map.can_wall(Vector2i(15, 10), from_player), false)
	_refused("divider on the hull (12,4)", map.can_wall(Vector2i(12, 4), from_player), true)
	_refused("door on the outer wall (12,4)", map.can_door(Vector2i(12, 4), from_player), true)
	_refused("door on the divider (14,15)", map.can_door(Vector2i(14, 15), from_player), false)
	_refused("door where the player stands", map.can_door(from_player, from_player), true)
	_refused("door outside the station (60,40)", map.can_door(Vector2i(60, 40), from_player), true)
	_refused("gate on the outer wall (12,4)", map.can_gate(Vector2i(12, 4)), false)
	_refused("gate on an interior divider (14,15)", map.can_gate(Vector2i(14, 15)), true)
	_refused("demolish the player's own cell", map.can_demolish(from_player, from_player), true)
	_refused("demolish the void (60,40)", map.can_demolish(Vector2i(60, 40), from_player), true)
	_refused("demolish the automatic hull (12,4)", map.can_demolish(Vector2i(12, 4), from_player), true)

	print("--- expanding a rectangle opens a construction site")
	# x 16..22 / y 17..22 is the press room; east of it is just void.
	var area: Array[Vector2i] = []
	for y: int in range(18, 21):
		for x: int in range(23, 28):
			area.append(Vector2i(x, y))
	_refused("rectangle touching the press room", map.apply(StationMap.Action.EXPAND, area, from_player), false)
	await physics_frame
	await physics_frame
	_check("the row against the press room became a site (23,19)", map.type_at(Vector2i(23, 19)), StationMap.Type.CONSTRUCTION)
	# The back row only touches the station after the front row becomes a
	# site: if the rectangle weren't applied in rounds, it would be left out.
	_check("so does the back row (27,19)", map.type_at(Vector2i(27, 19)), StationMap.Type.CONSTRUCTION)
	_check("construction starts marked", map.stage_at(Vector2i(27, 19)), StationMap.Stage.MARKED)
	_check("construction blocks passage", solid.call(Vector2i(27, 19)), true)
	_check("hull appeared next to it (28,19)", map.is_auto_hull(Vector2i(28, 19)), true)
	_check("the new hull collides", solid.call(Vector2i(28, 19)), true)

	var loose: Array[Vector2i] = [Vector2i(60, 40), Vector2i(61, 40)]
	_refused("rectangle loose in the void", map.apply(StationMap.Action.EXPAND, loose, from_player), true)
	_check("and nothing was written", map.type_at(Vector2i(60, 40)), -1)

	print("--- selecting an already-built area isn't an error")
	# Column 11 is empty on these rows; from 12 on it's already courtyard floor.
	var half_and_half: Array[Vector2i] = []
	for y: int in range(5, 9):
		for x: int in range(11, 15):
			half_and_half.append(Vector2i(x, y))
	_refused("half built, half empty", map.apply(
		StationMap.Action.EXPAND, half_and_half, from_player), false)
	_check("the existing floor stayed intact", map.type_at(Vector2i(13, 6)), StationMap.Type.FLOOR)
	_check("only the empty part became a site", map.type_at(Vector2i(11, 6)), StationMap.Type.CONSTRUCTION)

	print("--- construction only advances when someone hits it")
	var site := Vector2i(27, 19)
	var per_stage: float = map.work_per_stage(StationMap.Type.FLOOR)
	_check("nobody hit it: still marked",
		map.stage_at(site), StationMap.Stage.MARKED)
	var half: float = map.work(site, per_stage * 0.5)
	await physics_frame
	_check("half a hit is charged in full", is_equal_approx(half, per_stage * 0.5), true)
	_check("counts toward progress", map.progress_at(site) > 0.0, true)
	_check("but doesn't close the stage", map.stage_at(site), StationMap.Stage.MARKED)
	map.work(site, per_stage * 0.5)
	await physics_frame
	_check("first stage closed: structure", map.stage_at(site), StationMap.Stage.STRUCTURE)
	map.work(site, per_stage)
	await physics_frame
	_check("second stage closed: finish", map.stage_at(site), StationMap.Stage.FINISH)
	# The leftover isn't charged: at the last stage the site no longer exists.
	var last: float = map.work(site, per_stage * 10.0)
	await physics_frame
	await physics_frame
	_check("the last hit only charges what was left", last < per_stage * 10.0, true)
	_check("and the cell became floor", map.type_at(site), StationMap.Type.FLOOR)
	_check("and it's walkable", solid.call(site), false)
	_check("hitting outside a site charges nothing", map.work(site, 50.0), 0.0)
	map.finish_all_construction()
	await physics_frame
	await physics_frame

	print("--- the pickaxe hits the site the character faces")
	# Two sites one cell from the same point: one south, one east. By the old
	# nearest-wins rule they'd tie; the ask is that facing decides.
	var aim := Vector2i(15, 9)
	var east := Vector2i(16, 9)
	var south := Vector2i(15, 10)
	_refused("raise a wall to the east", map.apply(
		StationMap.Action.WALL, [east] as Array[Vector2i], from_player), false)
	_refused("and another to the south", map.apply(
		StationMap.Action.WALL, [south] as Array[Vector2i], from_player), false)
	await physics_frame
	_check("facing east, picks the east one",
		map.nearby_site(_point(aim), Vector2(1, 0)), east)
	_check("facing south, picks the south one",
		map.nearby_site(_point(aim), Vector2(0, 1)), south)
	# Facing away from both: nearby_site returns the cell itself, which the
	# caller reads as "nothing aimed at".
	_check("facing north, picks neither",
		map.nearby_site(_point(aim), Vector2(0, -1)), aim)
	_check("no heading, falls back to nearest",
		map.type_at(map.nearby_site(_point(aim))), StationMap.Type.CONSTRUCTION)
	map.apply(StationMap.Action.DEMOLISH, [east, south] as Array[Vector2i], from_player)
	await physics_frame

	print("--- expanding over the hull doesn't open a hole to the void")
	var on_hull := Vector2i(12, 4)
	_check("the chosen cell is hull", map.is_auto_hull(on_hull), true)
	_refused("expanding there is accepted", map.apply(
		StationMap.Action.EXPAND, [on_hull] as Array[Vector2i], from_player), false)
	await physics_frame
	_check("became a site", map.type_at(on_hull), StationMap.Type.CONSTRUCTION)
	var hull_layer: TileMapLayer = map.get_node("Hull")
	_check("and the wall is still drawn",
		hull_layer.get_cell_source_id(on_hull), StationMap.SOURCE_HULL)
	_check("so there's no missing floor there", map.is_missing_floor(on_hull), false)
	_check("and the neighboring floor gets no cone",
		map.get_node("Details").get_cell_source_id(Vector2i(12, 5)), -1)
	map.apply(StationMap.Action.DEMOLISH, [on_hull] as Array[Vector2i], from_player)
	await physics_frame

	print("--- expanding over an interior divider tears the wall down")
	# Was refused until 2026-10-06. Today expanding over a wall IS its
	# demolition — it costs the same hits Demolish would charge.
	var divider := Vector2i(10, 11)
	_check("the chosen cell is a divider", map.type_at(divider),
		StationMap.Type.WALL)
	_refused("the cursor accepts it", map.can_expand(divider), false)
	_refused("so does the expansion", map.apply(
		StationMap.Action.EXPAND, [divider] as Array[Vector2i], from_player), false)
	await physics_frame
	_check("became a site", map.type_at(divider), StationMap.Type.CONSTRUCTION)
	_check("demolishing", map.is_demolishing(divider), true)
	_check("targeting a wall", map.target_at(divider), StationMap.Type.WALL)
	_check("and the wall still blocks while it comes down", solid.call(divider), true)
	map.finish_all_construction()
	await physics_frame
	await physics_frame
	_check("site finished, became floor", map.type_at(divider),
		StationMap.Type.FLOOR)
	_check("and it's walkable", solid.call(divider), false)
	map.set_type(divider, StationMap.Type.WALL)
	await physics_frame

	print("--- construction cost, in cells per energy bar")
	# The table is written as work per cell, but was requested in cells per
	# full bar. The checks below are the translation, to make a mismatch
	# fail loudly instead of drifting unnoticed.
	var day_of_energy: float = player.get_script().get_script_constant_map()["MAX_ENERGY"]
	var cost: Dictionary = StationMap.WORK_PER_CELL
	_check("a full bar expands eight squares",
		is_equal_approx(cost[StationMap.Type.FLOOR] * 8.0, day_of_energy), true)
	_check("or raises twenty walls",
		is_equal_approx(cost[StationMap.Type.WALL] * 20.0, day_of_energy), true)
	_check("or installs eight doors, two cells each",
		is_equal_approx(cost[StationMap.Type.DOOR] * 2.0 * 8.0, day_of_energy), true)
	_check("and a whole door costs the same as one floor square",
		is_equal_approx(cost[StationMap.Type.DOOR] * 2.0, cost[StationMap.Type.FLOOR]), true)

	print("--- the pickaxe's cadence, in hammer hits")
	var cycle: float = player.get_script().get_script_constant_map()["WORK_CYCLE"]
	var day_constants: Dictionary = work.get_script().get_script_constant_map()
	var seconds_per_square: float = (
		cost[StationMap.Type.FLOOR] / float(day_constants["ENERGY_PER_SECOND"])
	)
	_check("one square takes the requested hit count",
		is_equal_approx(seconds_per_square / cycle,
			float(day_constants["HAMMER_HITS_PER_SQUARE"])), true)
	_check("and a full bar takes eight times that",
		is_equal_approx(float(day_constants["SECONDS_PER_DAY"]),
			seconds_per_square * 8.0), true)

	print("--- the energy bar counts squares")
	var panel: HudPanel = work.get_node("Interface/Panel")
	var bar: EnergyBar = panel.get_node("Content/DayAndEnergy/Energy")
	_check("the day counter lives on the same plate",
		panel.get_node_or_null("Content/DayAndEnergy/Day/Content/Counter") != null, true)
	_check("one segment is worth one floor square",
		is_equal_approx(EnergyBar.ENERGY_PER_SEGMENT, cost[StationMap.Type.FLOOR]), true)
	bar.show_bar(day_of_energy, day_of_energy)
	await process_frame
	_check("with today's energy, eight segments", bar.segments(), 8)
	var width_of_eight: float = bar.custom_minimum_size.x
	var right_edge: float = panel.position.x + panel.size.x
	# Doubling max energy has to double the row with no new art.
	bar.show_bar(day_of_energy * 2.0, day_of_energy * 2.0)
	await process_frame
	_check("double the energy gives double the segments", bar.segments(), 16)
	_check("and the bar grows with it", bar.custom_minimum_size.x > width_of_eight, true)
	_check("the plate grows with it", panel.size.x > width_of_eight, true)
	# The plate grows LEFT: without that a bigger bar would run off the right of the screen.
	_check("and the right edge stays put",
		is_equal_approx(panel.position.x + panel.size.x, right_edge), true)
	bar.show_bar(day_of_energy, day_of_energy)
	await process_frame

	print("--- the mouse wheel adjusts the game's zoom")
	var eye: Camera2D = player.get_node("Camera2D")
	var initial_zoom: float = eye.zoom.x
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	player.call("_unhandled_input", wheel)
	_check("wheel up zooms in", eye.zoom.x > initial_zoom, true)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for _i: int in 20:
		player.call("_unhandled_input", wheel)
	var min_zoom: float = player.get_script().get_script_constant_map()["MIN_ZOOM"]
	_check("and doesn't pass the zoom-out limit",
		is_equal_approx(eye.zoom.x, min_zoom), true)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for _i: int in 40:
		player.call("_unhandled_input", wheel)
	var max_zoom: float = player.get_script().get_script_constant_map()["MAX_ZOOM"]
	_check("nor the zoom-in one", is_equal_approx(eye.zoom.x, max_zoom), true)
	# Locked, the wheel isn't his: in build mode the build camera is in charge.
	player.call("lock", true)
	player.call("_unhandled_input", wheel)
	_check("and in build mode the wheel doesn't move this camera",
		is_equal_approx(eye.zoom.x, max_zoom), true)
	player.call("lock", false)
	eye.zoom = Vector2(initial_zoom, initial_zoom)

	print("--- the rectangle sweeps a divider, but not a door")
	# The divider is the ONLY placed piece the rectangle tears down. Doors and
	# gates are passage: sweeping them in a wide drag would split the station unasked.
	var over_door: Array[Vector2i] = [Vector2i(10, 9), Vector2i(10, 10), Vector2i(10, 11)]
	map.apply(StationMap.Action.EXPAND, over_door, from_player)
	await physics_frame
	_check("the door survived", map.type_at(Vector2i(10, 9)), StationMap.Type.DOOR)
	_check("but the divider became a site", map.type_at(Vector2i(10, 11)),
		StationMap.Type.CONSTRUCTION)
	_check("demolishing", map.is_demolishing(Vector2i(10, 11)), true)
	# Restore the whole wall: the next block demolishes it with the tool,
	# which needs to start from a finished wall.
	map.apply(StationMap.Action.DEMOLISH, [Vector2i(10, 11)] as Array[Vector2i], from_player)
	await physics_frame
	_check("and demolishing the site restores the wall",
		map.type_at(Vector2i(10, 11)), StationMap.Type.WALL)

	print("--- demolishing goes down the same ladder construction climbed")
	var wall: Array[Vector2i] = [Vector2i(10, 11)]
	_refused("wall opens a demolition site", map.apply(
		StationMap.Action.DEMOLISH, wall, from_player), false)
	await physics_frame
	await physics_frame
	_check("it's a site running backward", map.is_demolishing(Vector2i(10, 11)), true)
	_check("starting from the last stage", map.stage_at(Vector2i(10, 11)),
		StationMap.Stage.STRUCTURE)
	_check("the wall still blocks while it comes down", solid.call(Vector2i(10, 11)), true)

	print("--- demolishing a site cancels the work")
	_refused("demolishing its own demolition", map.apply(
		StationMap.Action.DEMOLISH, wall, from_player), false)
	_check("the wall comes back whole", map.type_at(Vector2i(10, 11)), StationMap.Type.WALL)

	map.apply(StationMap.Action.DEMOLISH, wall, from_player)
	map.finish_all_construction()
	await physics_frame
	await physics_frame
	_check("it really became floor", map.type_at(Vector2i(10, 11)), StationMap.Type.FLOOR)
	_refused("and the floor becomes vacuum", map.apply(
		StationMap.Action.DEMOLISH, wall, from_player), false)
	_check("the floor only leaves at the end", map.type_at(Vector2i(10, 11)), StationMap.Type.CONSTRUCTION)
	_check("and starts from finish", map.stage_at(Vector2i(10, 11)),
		StationMap.Stage.FINISH)
	map.finish_all_construction()
	await physics_frame
	await physics_frame
	_check("left the map", map.type_at(Vector2i(10, 11)), -1)
	_refused("nothing happens on the automatic hull", map.apply(
		StationMap.Action.DEMOLISH, [Vector2i(31, 3)] as Array[Vector2i], from_player), true)
	map.set_type(Vector2i(10, 11), StationMap.Type.WALL)

	print("--- demolishing floor in the middle of a room opens a walled gap")
	var middle := Vector2i(15, 7)
	_refused("the floor leaves", map.apply(
		StationMap.Action.DEMOLISH, [middle] as Array[Vector2i], from_player), false)
	map.finish_all_construction()
	await physics_frame
	await physics_frame
	_check("became a hole", map.is_hole(middle), true)
	_check("and NOT solid hull", map.is_auto_hull(middle), false)
	_check("but blocks the player", solid.call(middle), true)
	map.set_type(middle, StationMap.Type.FLOOR)
	await physics_frame
	await physics_frame
	_check("restoring the floor closes the hole", map.is_hole(middle), false)

	print("--- a door is a two-cell piece")
	# What breaks the deadlock: before, you couldn't raise the wall that would
	# close the corner (it would isolate the station), nor place the door that
	# would fix it (there was no wall there yet).
	var pair: Array[Vector2i] = [Vector2i(14, 8), Vector2i(15, 8)]
	var half_pair: Array[Vector2i] = [Vector2i(14, 8)]
	var apart: Array[Vector2i] = [Vector2i(14, 8), Vector2i(17, 8)]
	_refused("a single cell isn't a door", map.can_door_at(half_pair, from_player), true)
	_refused("neither are two separate ones", map.can_door_at(apart, from_player), true)
	_refused("an adjacent pair passes", map.can_door_at(pair, from_player), false)
	var over_player: Array[Vector2i] = [from_player, from_player + Vector2i(1, 0)]
	_refused("and it doesn't go over the player",
		map.can_door_at(over_player, from_player), true)
	_refused("applying the pair", map.apply(StationMap.Action.DOOR, pair, from_player), false)
	await physics_frame
	_check("became a door site", map.target_at(pair[0]), StationMap.Type.DOOR)
	_check("under construction, the door already lets you through", solid.call(pair[0]), false)
	_check("and needs no cone", map.is_missing_floor(pair[0]), false)
	_check("the lying door uses row 0", map.door_row(pair[0]), 0)

	print("--- door and wall take two stages")
	map.advance_one_stage()
	await physics_frame
	_check("after one stage: structure", map.stage_at(pair[0]),
		StationMap.Stage.STRUCTURE)
	_check("but still not a door", map.type_at(pair[0]), StationMap.Type.CONSTRUCTION)
	map.advance_one_stage()
	await physics_frame
	await physics_frame
	_check("after two: door done", map.type_at(pair[0]), StationMap.Type.DOOR)
	_check("and still walkable through", solid.call(pair[0]), false)
	map.set_type(pair[0], StationMap.Type.FLOOR)
	map.set_type(pair[1], StationMap.Type.FLOOR)

	var on_wall := Vector2i(16, 11)
	_refused("wall opens a site", map.apply(
		StationMap.Action.WALL, [on_wall] as Array[Vector2i], from_player), false)
	await physics_frame
	await physics_frame
	_check("targeting a wall", map.target_at(on_wall), StationMap.Type.WALL)
	_check("and already blocks passage", solid.call(on_wall), true)
	map.advance_one_stage()
	map.advance_one_stage()
	await physics_frame
	await physics_frame
	_check("two stages and it's a wall", map.type_at(on_wall), StationMap.Type.WALL)

	print("--- canceling a wall site returns floor, not vacuum")
	var abandoned := Vector2i(17, 11)
	map.apply(StationMap.Action.WALL, [abandoned] as Array[Vector2i], from_player)
	_refused("removing the site", map.apply(
		StationMap.Action.DEMOLISH, [abandoned] as Array[Vector2i], from_player), false)
	_check("the floor is still there", map.type_at(abandoned), StationMap.Type.FLOOR)
	map.apply(StationMap.Action.DEMOLISH, [on_wall] as Array[Vector2i], from_player)
	map.finish_all_construction()
	await physics_frame
	await physics_frame

	print("--- nobody seals the station around themselves")
	# With door (10,9) turned into a divider, (10,10) is the storage room's
	# only passage. Removing it once turns it into floor and the path stays
	# open; it's the second removal, which would open vacuum, that must be refused.
	map.set_type(Vector2i(10, 9), StationMap.Type.WALL)
	var last_one: Array[Vector2i] = [Vector2i(10, 10)]
	_refused("door becomes floor", map.apply(StationMap.Action.DEMOLISH, last_one, from_player), false)
	map.finish_all_construction()
	await physics_frame
	_refused("but opening vacuum on the only passage", map.apply(
		StationMap.Action.DEMOLISH, last_one, from_player), true)
	_check("the floor is still there", map.type_at(Vector2i(10, 10)), StationMap.Type.FLOOR)
	map.set_type(Vector2i(10, 9), StationMap.Type.DOOR)
	map.set_type(Vector2i(10, 10), StationMap.Type.DOOR)

	print("--- hangar gate")
	player.position = map.center_of(Vector2i(30, 7))
	await physics_frame
	_check("a gate is nearby", map.has_nearby_gate(player.global_position), true)
	_check("E toggles the gate", map.toggle_nearby_gate(player.global_position), true)
	await physics_frame
	await physics_frame
	_check("open gate clears (31,7)", solid.call(Vector2i(31, 7)), false)
	_check("opened the whole group (31,9)", solid.call(Vector2i(31, 9)), false)
	map.toggle_nearby_gate(player.global_position)
	await physics_frame
	await physics_frame
	_check("closed gate blocks again", solid.call(Vector2i(31, 7)), true)

	print("--- the bed closes the day")
	player.position = bed.wake_point()
	await physics_frame
	_check("standing at the bed's foot, it's in range",
		bed.is_near(player.global_position), true)
	player.position = map.center_of(from_player)
	await physics_frame
	_check("from the courtyard, it isn't", bed.is_near(player.global_position), false)

	var spent: float = player.call("spend_energy", 60.0)
	_check("spending energy charges the request", is_equal_approx(spent, 60.0), true)
	_check("and the bar goes down", is_equal_approx(player.get("energy"), day_of_energy - 60.0), true)
	_check("can't spend what you don't have",
		is_equal_approx(player.call("spend_energy", 999.0), day_of_energy - 60.0), true)
	_check("energy stops at zero", player.get("energy"), 0.0)

	player.call("lie_down", bed.sleep_point())
	await process_frame
	_check("lay down", player.call("is_sleeping"), true)
	_check("on top of the mattress",
		player.global_position.distance_to(bed.global_position) < 64.0, true)
	var day_before: int = work.get("day")
	work.call("_dawn")
	_check("night restores energy", player.get("energy"), day_of_energy)
	_check("and turns the day", work.get("day"), day_before + 1)
	player.call("stand_up", bed.wake_point())
	await process_frame
	_check("stood up", player.call("is_sleeping"), false)

	print("--- build mode")
	build_mode.toggle()
	await process_frame
	_check("mode active", build_mode.active, true)
	_check("the build camera took over", build_mode.get_node("Camera2D").is_current(), true)
	build_mode.toggle()
	await process_frame
	_check("mode off", build_mode.active, false)
	_check("the player's camera is back", player.get_node("Camera2D").is_current(), true)

	print("--- build mode's two panels")
	var shortcut: HudPanel = build_mode.get_node("Interface/Shortcut")
	var tools: HudPanel = build_mode.get_node("Interface/Panel")
	_check("mode closed: only the shortcut shows",
		[shortcut.visible, tools.visible], [true, false])
	build_mode.toggle()
	await process_frame
	_check("and open, only the panel",
		[shortcut.visible, tools.visible], [false, true])
	# The HUD plate lives in the same top-right corner, and the two nodes
	# don't know about each other: the only agreement is BuildMode.BELOW_HUD.
	var hud_plate: HudPanel = work.get_node("Interface/Panel")
	_check("the panel starts below the HUD plate",
		tools.position.y >= hud_plate.position.y + hud_plate.size.y, true)
	_check("and both touch the same right edge",
		is_equal_approx(
			tools.position.x + tools.size.x,
			hud_plate.position.x + hud_plate.size.x
		), true)
	# The shortcut is on the other side: the left corner is its alone.
	_check("the shortcut stays in the left corner",
		shortcut.position.x < hud_plate.position.x, true)
	build_mode.toggle()
	await process_frame

	print("--- the pixel font")
	var typeface: FontFile = ThemeDB.get_default_theme().default_font as FontFile
	_check("is the project's default font", typeface != null, true)
	_check("no antialiasing", typeface.antialiasing, TextServer.FONT_ANTIALIASING_NONE)
	_check("and no subpixel positioning",
		typeface.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED)
	# The three sizes are the ones checked on screen; 16, the engine default, isn't one of them.
	var clean: Array[int] = [20, 24, 25, 28, 30, 40, 50]
	_check("the three sizes are checked ones",
		[clean.has(Fonts.SMALL), clean.has(Fonts.MEDIUM), clean.has(Fonts.LARGE)],
		[true, true, true])
	_check("and they climb in that order",
		Fonts.SMALL < Fonts.MEDIUM and Fonts.MEDIUM < Fonts.LARGE, true)
	_check("whoever asks for no size falls back to small, not the engine's 16",
		ProjectSettings.get_setting("gui/theme/default_font_size"), Fonts.SMALL)
	_check("and the small size's line height is the size itself",
		typeface.get_height(Fonts.SMALL), float(Fonts.SMALL))
	_check("and it has the ç and ã the game writes",
		[typeface.has_char("ç".unicode_at(0)), typeface.has_char("ã".unicode_at(0))],
		[true, true])

	print("--- the key cap knows both widths")
	var cap := KeyCap.new()
	cap.show_key("E")
	_check("a letter comes out on the square cap",
		cap.custom_minimum_size, Vector2(KeyCap.SIDE, KeyCap.SIDE) * KeyCap.SCALE)
	cap.show_key("F1")
	_check("and a function key, on the wide one",
		cap.custom_minimum_size, Vector2(KeyCap.DUAL_WIDTH, KeyCap.SIDE) * KeyCap.SCALE)
	cap.free()

	print("--- confirming and canceling the plan")
	player.position = _point(from_player)
	await physics_frame
	var before_draft: int = map.type_at(Vector2i(11, 15))
	build_mode.toggle()
	await process_frame
	# (11,15) is empty against the corridor's west wall, courtyard -> workshop.
	var draft: Array[Vector2i] = [Vector2i(11, 15), Vector2i(11, 16)]
	_refused("expanding with the mode open", map.apply(
		StationMap.Action.EXPAND, draft, from_player), false)
	build_mode.set("_pending", map.differences(build_mode.get("_on_enter")))
	_check("the bar counts the new cells", build_mode.get("_pending"), 2)
	build_mode.call("cancel")
	await process_frame
	_check("cancel closes the mode", build_mode.active, false)
	_check("and undoes the expansion", map.type_at(Vector2i(11, 15)), before_draft)
	_check("including the second cell", map.type_at(Vector2i(11, 16)), before_draft)

	build_mode.toggle()
	await process_frame
	map.apply(StationMap.Action.EXPAND, draft, from_player)
	build_mode.set("_pending", map.differences(build_mode.get("_on_enter")))
	build_mode.call("confirm")
	await process_frame
	_check("confirm closes the mode", build_mode.active, false)
	_check("and the site stays up", map.type_at(Vector2i(11, 15)), StationMap.Type.CONSTRUCTION)
	map.finish_all_construction()
	await physics_frame
	await physics_frame

	print("--- cones: the floor warns where ground runs out")
	_check("finished floor needs no cone", map.is_missing_floor(Vector2i(11, 16)), false)
	var hole_cells: Array[Vector2i] = [Vector2i(14, 12)]
	map.apply(StationMap.Action.DEMOLISH, hole_cells, from_player)
	await physics_frame
	_check("a floor site needs a cone", map.is_missing_floor(Vector2i(14, 12)), true)
	var details: TileMapLayer = map.get_node("Details")
	_check("the floor to the north got a cone", details.get_cell_source_id(Vector2i(14, 11)),
		StationMap.SOURCE_CONE)
	# Bit 2 of CARDINALS is south: the void is below the cell carrying the mark.
	_check("facing the right way", details.get_cell_atlas_coords(Vector2i(14, 11)),
		Vector2i(1 << 2, 0))
	_check("floor far from the hole stays clean",
		details.get_cell_source_id(Vector2i(14, 9)), -1)
	# Going down: the cone follows the demolition to the last stage.
	map.force_stage(StationMap.Stage.MARKED)
	await physics_frame
	_check("at the last stage the cone is still there",
		details.get_cell_source_id(Vector2i(14, 11)), StationMap.SOURCE_CONE)
	map.finish_all_construction()
	await physics_frame
	await physics_frame
	# The cone disappears with the site, not the gap: the hole's border wall
	# sits between the floor and the void, and the warning has nothing left to warn about.
	_check("demolition finished, the cone is gone",
		details.get_cell_source_id(Vector2i(14, 11)), -1)
	_check("and the gap ended up walled", map.is_hole(Vector2i(14, 12)), true)

	# Going up: the cone stays until the floor is delivered, not until the plate appears.
	map.apply(StationMap.Action.EXPAND, hole_cells, from_player)
	map.force_stage(StationMap.Stage.FINISH)
	await physics_frame
	_check("at finish the cone is still there",
		details.get_cell_source_id(Vector2i(14, 11)), StationMap.SOURCE_CONE)
	map.finish_all_construction()
	await physics_frame
	await physics_frame
	_check("only delivered floor removes the cone",
		details.get_cell_source_id(Vector2i(14, 11)), -1)

	print("--- ESC: exits build mode before opening the menu")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true

	build_mode.toggle()
	await process_frame
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_check("first ESC closes build mode", build_mode.active, false)
	_check("and doesn't pause the game", paused, false)

	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_check("the next ESC opens the menu", paused, true)
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_check("and the next closes the menu", paused, false)

	print("--- pause menu")
	var menu: CanvasLayer = scene.get_node("PauseMenu")
	# With PROCESS_MODE_WHEN_PAUSED the menu wouldn't get Esc while the game
	# runs, and would be unreachable: this check exists so that exact case never comes back.
	_check("always processes", menu.process_mode, Node.PROCESS_MODE_ALWAYS)
	menu.pause()
	await process_frame
	_check("pausing stops the game", paused, true)
	_check("and shows the menu", menu.visible, true)
	menu.resume()
	await process_frame
	_check("resuming unpauses", paused, false)

	print("failures: ", _failures)
	quit(_failures)
