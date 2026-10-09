extends SceneTree
## Generates resources/tileset_station.tres and scenes/station.tscn.
##
## The plan itself isn't written here: since build mode shipped, the map is
## drawn at runtime by scripts/station_map.gd. What's left for this generator
## is what can't be assembled at play time — the TileSet with its 256 hull
## variations and each one's collision polygons — and the scene's node skeleton.
##
## Usage: godot --headless --path . --script tools/build_station.gd

const CELL: int = 64

## Must match RECUO in tools/gerar_tiles_estacao.py: how much the hull art
## recesses on the side facing space; collision follows the art.
const RECESS: int = 20

## Camera zoom: smaller values pull the view back.
const CAMERA_ZOOM: float = 0.4

## Physics layers: 1 = solid scenery, 2 = player.
const SCENERY_LAYER: int = 1
const PLAYER_LAYER: int = 2

const TILESET_PATH: String = "res://resources/tileset_station.tres"
const SCENE_PATH: String = "res://scenes/station.tscn"

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

## Alt used while a piece is still under construction: same art, dimmed and
## translucent. Must match ALT_UNDER_CONSTRUCTION in scripts/station_map.gd.
const ALT_UNDER_CONSTRUCTION: int = 1
const UNDER_CONSTRUCTION_COLOR: Color = Color(0.60, 0.66, 0.78, 0.62)

## No-collision tape alt. A wall's tape blocks passage — it's already a site —
## but a door's doesn't: a door never collides, built or not, and blocking the
## gap during construction would remove the exact exit a standalone door exists to give.
const ALT_TAPE_NO_COLLISION: int = 1

## Same alt drawn over a piece under construction, so it's translucent: the
## tape is a wide band on all four sides of the cell, and opaque it would eat
## the whole square.
const TAPE_OVER_PIECE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)

## Hull mask bits, in the order of DIRECTIONS in station_map.gd.
const BIT_NORTH: int = 1 << 0
const BIT_EAST: int = 1 << 2
const BIT_SOUTH: int = 1 << 4
const BIT_WEST: int = 1 << 6


func _initialize() -> void:
	var tileset: TileSet = _build_tileset()
	var error: int = ResourceSaver.save(tileset, TILESET_PATH)
	assert(error == OK, "failed to save the tileset")

	var root: Node2D = _build_scene(load(TILESET_PATH))
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK, "failed to pack the scene")
	error = ResourceSaver.save(packed, SCENE_PATH)
	assert(error == OK, "failed to save the scene")

	print("generated: ", TILESET_PATH)
	print("generated: ", SCENE_PATH)
	quit()


# --- Tileset -----------------------------------------------------------------

func _build_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(CELL, CELL)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, SCENERY_LAYER)

	_add(tileset, SOURCE_FLOOR, "res://assets/tiles/station/floor.png", 4, 4)
	_add(tileset, SOURCE_BORDER, "res://assets/tiles/station/border.png", 16, 16)

	var hull: TileSetAtlasSource = _add(
		tileset, SOURCE_HULL, "res://assets/tiles/station/hull.png", 16, 16
	)
	for mask: int in 256:
		var coord := Vector2i(mask % 16, mask / 16)
		var area: Rect2 = _hull_body(mask)
		_collide(hull, coord, area)
		# Wall not built yet. An alt, not its own atlas, since the art is the
		# same — only whether the player can see stars through it changes.
		var alt: int = hull.create_alternative_tile(coord, ALT_UNDER_CONSTRUCTION)
		assert(alt == ALT_UNDER_CONSTRUCTION, "unexpected alt id")
		hull.get_tile_data(coord, ALT_UNDER_CONSTRUCTION).modulate = UNDER_CONSTRUCTION_COLOR
		_collide(hull, coord, area, ALT_UNDER_CONSTRUCTION)

	# Eight columns: four gap segments, each closed and open.
	var door: TileSetAtlasSource = _add(
		tileset, SOURCE_DOOR, "res://assets/tiles/station/door.png", 8, 2
	)
	# The door also has an under-construction version: the frame already in
	# place, dimmed, before the leaf exists. Neither collides.
	for row: int in 2:
		for column: int in 8:
			var gap := Vector2i(column, row)
			door.create_alternative_tile(gap, ALT_UNDER_CONSTRUCTION)
			door.get_tile_data(gap, ALT_UNDER_CONSTRUCTION).modulate = UNDER_CONSTRUCTION_COLOR

	var gate: TileSetAtlasSource = _add(
		tileset, SOURCE_GATE, "res://assets/tiles/station/gate.png", 4, 2
	)
	# Only row 0 collides: row 1 is the open gate, which has to let the ship and the player through.
	for column: int in 4:
		_collide(gate, Vector2i(column, 0), _gate_body(column))

	# Pipes, boxes and lights are decoration: they sit in the hull's recess, outside collision.
	_add(tileset, SOURCE_DETAIL, "res://assets/tiles/station/details.png", 8, 4)

	# Construction site, structure and finish. The first stage isn't here: the
	# marker depends on neighborhood and has its own atlas.
	var construction: TileSetAtlasSource = _add(
		tileset, SOURCE_CONSTRUCTION, "res://assets/tiles/station/construction.png", 4, 2
	)
	for row: int in 2:
		for column: int in 4:
			_collide(construction, Vector2i(column, row), _whole_cell())

	# Site marker: 256 neighbor-mask variants, like the hull. Collides the same as other stages.
	var marking: TileSetAtlasSource = _add(
		tileset, SOURCE_MARKING, "res://assets/tiles/station/marking.png", 16, 16
	)
	for mask: int in 256:
		_collide(marking, Vector2i(mask % 16, mask / 16), _whole_cell())

	# Gap open to space, walled around. Collides whole: the border wall is too thin for its own polygon.
	var hole: TileSetAtlasSource = _add(
		tileset, SOURCE_HOLE, "res://assets/tiles/station/hole.png", 16, 1
	)
	for mask: int in 16:
		_collide(hole, Vector2i(mask, 0), _whole_cell())

	# Construction tape on the floor: wall and door's first stage. The base
	# collides, the alt doesn't — see ALT_TAPE_NO_COLLISION.
	var tape: TileSetAtlasSource = _add(
		tileset, SOURCE_TAPE, "res://assets/tiles/station/tape.png", 16, 2
	)
	for row: int in 2:
		for mask: int in 16:
			var strip := Vector2i(mask, row)
			_collide(tape, strip, _whole_cell())
			var no_collision: int = tape.create_alternative_tile(strip, ALT_TAPE_NO_COLLISION)
			assert(no_collision == ALT_TAPE_NO_COLLISION, "unexpected alt id")
			tape.get_tile_data(strip, ALT_TAPE_NO_COLLISION).modulate = TAPE_OVER_PIECE_COLOR

	# Cone and caution stripe: no collision on purpose.
	_add(tileset, SOURCE_CONE, "res://assets/tiles/station/cones.png", 16, 1)

	return tileset


func _whole_cell() -> Rect2:
	return Rect2(Vector2(-CELL / 2.0, -CELL / 2.0), Vector2(CELL, CELL))


func _add(
	tileset: TileSet, id: int, path: String, columns: int, rows: int
) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(path)
	assert(source.texture != null, "missing texture: " + path)
	source.texture_region_size = Vector2i(CELL, CELL)
	for y: int in rows:
		for x: int in columns:
			source.create_tile(Vector2i(x, y))
	tileset.add_source(source, id)
	return source


func _collide(
	source: TileSetAtlasSource, coord: Vector2i, area: Rect2, alt: int = 0
) -> void:
	var data: TileData = source.get_tile_data(coord, alt)
	data.set_collision_polygons_count(0, 1)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		area.position,
		Vector2(area.end.x, area.position.y),
		area.end,
		Vector2(area.position.x, area.end.y),
	]))


## Solid rectangle for a hull cell, in tile coordinates (center at origin).
func _hull_body(mask: int) -> Rect2:
	var left: float = -CELL / 2.0 + (RECESS if mask & BIT_WEST else 0)
	var right: float = CELL / 2.0 - (RECESS if mask & BIT_EAST else 0)
	var top: float = -CELL / 2.0 + (RECESS if mask & BIT_NORTH else 0)
	var bottom: float = CELL / 2.0 - (RECESS if mask & BIT_SOUTH else 0)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


## The gate atlas column says which side of the cell faces space: north, east, south, west.
func _gate_body(column: int) -> Rect2:
	var mask: int = [BIT_NORTH, BIT_EAST, BIT_SOUTH, BIT_WEST][column]
	return _hull_body(mask)


# --- Scene -------------------------------------------------------------------

func _build_scene(tileset: TileSet) -> Node2D:
	var root := Node2D.new()
	root.name = "Station"

	var background := CanvasLayer.new()
	background.name = "Background"
	background.layer = -10
	root.add_child(background)
	background.owner = root

	var stars := Node2D.new()
	stars.name = "Starfield"
	stars.set_script(load("res://scripts/starfield.gd"))
	background.add_child(stars)
	stars.owner = root

	var map := Node2D.new()
	map.name = "Map"
	map.set_script(load("res://scripts/station_map.gd"))
	root.add_child(map)
	map.owner = root

	# Draw order: floor, contact border, construction, hull, its decorations, openings on top.
	var with_collision: Array[String] = ["Construction", "Hull", "Openings"]
	for layer_name: String in ["Floor", "Border", "Construction", "Hull", "Details", "Openings"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tileset
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.collision_enabled = with_collision.has(layer_name)
		map.add_child(layer)
		layer.owner = root

	var bed: Node2D = _build_bed()
	root.add_child(bed)
	_adopt(bed, root)

	var player: CharacterBody2D = _build_player()
	root.add_child(player)
	_adopt(player, root)

	var build_mode := Node2D.new()
	build_mode.name = "BuildMode"
	build_mode.set_script(load("res://scripts/build_mode.gd"))
	var build_mode_camera := Camera2D.new()
	build_mode_camera.name = "Camera2D"
	build_mode.add_child(build_mode_camera)
	root.add_child(build_mode)
	_adopt(build_mode, root)

	# After build mode on purpose: _unhandled_input runs tree-reversed, and E
	# needs to reach here first — near the bed it sleeps, otherwise it passes
	# through to open the hangar gate.
	var work := Node2D.new()
	work.name = "Work"
	work.set_script(load("res://scripts/work.gd"))
	root.add_child(work)
	_adopt(work, root)

	var menu := CanvasLayer.new()
	menu.name = "PauseMenu"
	menu.layer = 100
	menu.visible = false
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.set_script(load("res://scripts/pause_menu.gd"))
	root.add_child(menu)
	menu.owner = root

	return root


func _adopt(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child: Node in node.get_children():
		_adopt(child, owner_node)


## The bed sits at the map's chosen cell, with the node landing on the DIVIDE
## between the two cells it occupies — the center of the art.
func _build_bed() -> Node2D:
	var map_script: GDScript = load("res://scripts/station_map.gd")
	var cell: Vector2i = map_script.get_script_constant_map()["BED_CELL"]
	var bed_script: GDScript = load("res://scripts/bed.gd")
	var constants: Dictionary = bed_script.get_script_constant_map()
	var height: int = constants["CELLS_TALL"]

	var bed := Node2D.new()
	bed.name = "Bed"
	bed.position = (
		Vector2(cell) * CELL + Vector2(CELL, CELL * height) * 0.5
	)
	bed.set_script(bed_script)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/objects/bed.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bed.add_child(sprite)

	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = SCENERY_LAYER
	bed.add_child(body)

	var shape := RectangleShape2D.new()
	shape.size = constants["COLLISION"]
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)

	return bed


func _build_player() -> CharacterBody2D:
	var map_script: GDScript = load("res://scripts/station_map.gd")
	var cell: Vector2i = map_script.get_script_constant_map()["INITIAL_PLAYER_CELL"]

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5
	player.collision_layer = PLAYER_LAYER
	player.collision_mask = SCENERY_LAYER
	player.set_script(load("res://scripts/player.gd"))
	# The map finds the player by group to open doors by proximity.
	player.add_to_group(&"player", true)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/sprites/miro_idle.png")
	sprite.hframes = 4
	sprite.vframes = 8
	sprite.frame = 0
	sprite.offset = Vector2(0, -46)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.add_child(sprite)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(34, 26)
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.position = Vector2(0, -13)
	player.add_child(collision)

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	player.add_child(camera)

	return player
