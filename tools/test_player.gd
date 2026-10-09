extends SceneTree
## Checks the player's row and frame switching on the 8-direction sheet.
##
## Usage: godot --headless --path . --script tools/test_player.gd

var _failures: int = 0


func _check(name: String, actual: Variant, expected: Variant) -> void:
	var ok: bool = actual == expected
	if not ok:
		_failures += 1
	print("[%s] %s -> %s expected=%s" % ["OK" if ok else "FAIL", name, actual, expected])


func _walk(actions: Array[StringName], frames: int) -> void:
	for action in actions:
		Input.action_press(action)
	for i in frames:
		await physics_frame
		await process_frame
	for action in actions:
		Input.action_release(action)


func _initialize() -> void:
	var scene: Node = load("res://scenes/station.tscn").instantiate()
	root.add_child(scene)
	await physics_frame

	var player: CharacterBody2D = scene.get_node("Player")
	var sprite: Sprite2D = player.get_node("Sprite2D")

	_check("texture", sprite.texture.resource_path, "res://assets/sprites/miro_8dir.png")
	_check("hframes", sprite.hframes, 4)
	_check("vframes", sprite.vframes, 8)
	_check("not mirrored", sprite.flip_h, false)
	_check("idle: faces down", sprite.frame_coords, Vector2i(0, 0))

	# One row per direction, in the order of enum Facing in scripts/player.gd.
	var rows: Array = [
		[[&"ui_right"], 1, "right"],
		[[&"ui_right", &"ui_down"], 4, "down-right"],
		[[&"ui_down"], 0, "down"],
		[[&"ui_left", &"ui_down"], 5, "down-left"],
		[[&"ui_left"], 3, "left"],
		[[&"ui_left", &"ui_up"], 7, "up-left"],
		[[&"ui_up"], 2, "up"],
		[[&"ui_right", &"ui_up"], 6, "up-right"],
	]
	for case in rows:
		var actions: Array[StringName] = []
		actions.assign(case[0])
		await _walk(actions, 12)
		_check("walking %s: sheet row" % case[2], sprite.frame_coords.y, case[1])

	# The loop above walks all eight directions, so final position proves nothing.
	# This part measures an isolated displacement.
	var before: Vector2 = player.position
	await _walk([&"ui_left"], 12)
	_check("walked left", player.position.x < before.x, true)
	before = player.position
	await _walk([&"ui_up"], 12)
	_check("walked up", player.position.y < before.y, true)

	var seen: Dictionary = {}
	Input.action_press(&"ui_right")
	for i in 40:
		await physics_frame
		await process_frame
		seen[sprite.frame_coords.x] = true
	Input.action_release(&"ui_right")
	_check("walking: cycles through all four frames", seen.size(), 4)

	for i in 60:
		await physics_frame
		await process_frame
	_check("stopped: returns to idle frame", sprite.frame_coords, Vector2i(0, 1))

	print("failures: ", _failures)
	quit(1 if _failures > 0 else 0)
