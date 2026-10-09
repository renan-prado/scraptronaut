#!/usr/bin/env -S godot -s
extends SceneTree
## Loads a scene, waits a few frames and saves a PNG of the viewport.
##
## Usage (arguments go after `--`):
##   godot --path <project> -s tools/capture.gd -- <scene> <output.png> [frames] [zoom]
##
## Needs a real window: under `--headless` the renderer is a dummy and the PNG comes out blank.

const DEFAULT_SCENE := "res://scenes/station.tscn"
const DEFAULT_FRAMES := 30

var _scene: String = DEFAULT_SCENE
var _output: String = "capture.png"
var _frames: int = DEFAULT_FRAMES

## Overrides the zoom of whatever camera the scene made current. Zero keeps it.
## Values below 1 pull back: 0.15 fits the whole station in the viewport, which
## is the only way to check a map edit without walking the place.
var _zoom: float = 0.0


func _init() -> void:
	_read_arguments()
	_capture.call_deferred()


func _read_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_scene = args[0]
	if args.size() > 1:
		_output = args[1]
	if args.size() > 2:
		_frames = maxi(1, args[2].to_int())
	if args.size() > 3:
		_zoom = maxf(0.0, args[3].to_float())


func _capture() -> void:
	if not ResourceLoader.exists(_scene):
		printerr("scene not found: ", _scene)
		quit(1)
		return

	var packed: PackedScene = load(_scene)
	if packed == null:
		printerr("failed to load scene: ", _scene)
		quit(1)
		return

	root.add_child(packed.instantiate())

	var folder: String = _output.get_base_dir()
	if folder != "" and not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)

	for _i: int in _frames:
		await process_frame

	if _zoom > 0.0:
		var camera: Camera2D = root.get_camera_2d()
		if camera != null:
			camera.zoom = Vector2(_zoom, _zoom)
			await process_frame
	await RenderingServer.frame_post_draw

	var image: Image = root.get_texture().get_image()
	var error: int = image.save_png(_output)
	if error != OK:
		printerr("failed to save PNG (error ", error, "): ", _output)
		quit(1)
		return

	print("screenshot saved: ", _output, " (", image.get_width(), "x", image.get_height(), ", ", _frames, " frames)")
	quit()
