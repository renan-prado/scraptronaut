extends SceneTree
## Opens the scene already in build mode, points the cursor at a chosen cell and
## saves a PNG. The only way to see the build UI without sitting at the keyboard:
## tools/capture.gd captures the scene at rest, and the mode only exists after F1.
##
## Uses the real mouse to position the cursor, so it needs a window.
##
## godot --path . -s tools/capture_build_mode.gd -- <output> <tool> <x> <y> <zoom> [rx ry rw rh]
##
## The four optional ones are a rectangle where the SAME tool is applied before
## capture — for setting up the scene you want to see: expand, raise a wall, or
## open a hole with tool 4 (Demolish). With tool >= 0 it goes through build mode,
## as if the player had dragged the mouse; negative, straight on the map, always
## as an expansion. The tenth argument freezes construction at a stage (0, 1 or
## 2); any other value delivers the floor.
##
## With only TWO optionals, the script fakes a drag in progress from them, the
## only way to see the selection rectangle drawn.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/station.tscn").instantiate()
	root.add_child(scene)
	for _i: int in 20:
		await process_frame

	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = arguments[0]
	var tool: int = arguments[1].to_int()
	var target := Vector2i(arguments[2].to_int(), arguments[3].to_int())
	var zoom: float = arguments[4].to_float()

	var map: StationMap = scene.get_node("Map")
	var has_rect: bool = arguments.size() > 8
	var area := Rect2i()
	if has_rect:
		area = Rect2i(
			arguments[5].to_int(), arguments[6].to_int(),
			arguments[7].to_int(), arguments[8].to_int()
		)

	# Optional construction stage: 0..2 freezes the site at that stage, any
	# other value delivers the finished floor.
	var freeze := func() -> void:
		if arguments.size() <= 9:
			return
		var stage: int = arguments[9].to_int()
		if stage >= 0 and stage <= 2:
			map.force_stage(stage as StationMap.Stage)
		else:
			map.finish_all_construction()

	# Negative tools skip build mode: -1 places the player on the requested cell
	# and captures the plain game (checking proximity doors this way); -2 does
	# the same and also opens the pause menu; -3 puts the pickaxe hitting the
	# nearest site; -4 lies down on the bed.
	if tool < 0:
		if has_rect:
			var cells: Array[Vector2i] = []
			for y: int in range(area.position.y, area.end.y):
				for x: int in range(area.position.x, area.end.x):
					cells.append(Vector2i(x, y))
			var from_player: Vector2i = map.cell_at(scene.get_node("Player").global_position)
			print("rect: ", area, " -> '", map.apply(
				StationMap.Action.EXPAND, cells, from_player), "'")
			freeze.call()
		var player: Node2D = scene.get_node("Player")
		player.global_position = map.center_of(target)
		var eye: Camera2D = player.get_node("Camera2D")
		eye.zoom = Vector2(zoom, zoom)
		if tool == -2:
			scene.get_node("PauseMenu").call("pause")
		# -3: pickaxe hitting the nearest site. The work node reads the F key
		# every frame, and a physical key can't be faked — so it's disabled and
		# the state is set by hand. Only way for the capture to see the work
		# animation and the work bar.
		if tool == -3:
			var site: Vector2i = map.nearby_site(player.global_position)
			var work: Node2D = scene.get_node("Work")
			work.set_process(false)
			work.set("_site", site)
			# _has_target lights the yellow frame; _hitting, the progress bar.
			work.set("_has_target", true)
			work.set("_hitting", true)
			work.queue_redraw()
			player.call("work_toward", map.center_of(site))
		# -4: sleeping on the bed, character already lying down.
		if tool == -4:
			var bed: Bed = scene.get_node("Bed")
			var work: Node2D = scene.get_node("Work")
			work.set_process(false)
			player.call("lie_down", bed.sleep_point())
		for _i: int in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output)
		print("saved: ", output)
		quit()
		return

	var build_mode: Node2D = scene.get_node("BuildMode")
	build_mode.toggle()
	build_mode.call("_choose", tool)

	# The rectangle goes in AFTER opening the mode, through the same function
	# the mouse uses: only then does the capture show the bar as the player would.
	if has_rect:
		# A fixed-size piece ignores the rectangle and sits under the cursor;
		# the rectangle's corner becomes the requested cell.
		if build_mode.call("_is_fixed_piece"):
			build_mode.set("_cell", area.position)
		build_mode.call("_apply", 1, area)
		freeze.call()

	var camera: Camera2D = build_mode.get_node("Camera2D")
	camera.zoom = Vector2(zoom, zoom)
	camera.global_position = map.center_of(target)
	for _i: int in 4:
		await process_frame
	Input.warp_mouse(Vector2(root.size) * 0.5)
	for _i: int in 20:
		await process_frame

	# Two extra arguments fake a drag in progress, anchored at the requested
	# cell — the only way to see the selection rectangle drawn. With a
	# fixed-piece tool there's no drag, so the first one becomes the piece's
	# rotation instead — what right-click does in the game.
	if arguments.size() == 7:
		if build_mode.call("_is_fixed_piece"):
			build_mode.set("_rotation", arguments[5].to_int())
		else:
			build_mode.set("_anchor", Vector2i(arguments[5].to_int(), arguments[6].to_int()))
			build_mode.set("_dragging", 1)
		build_mode.call("_evaluate")
		build_mode.call("_update_ui")
		build_mode.queue_redraw()
		for _i: int in 4:
			await process_frame
	await RenderingServer.frame_post_draw

	root.get_texture().get_image().save_png(output)
	print("saved: ", output)
	quit()
