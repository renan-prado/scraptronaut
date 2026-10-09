class_name Bed
extends Node2D
## Metal bunk in the storage room: the only place in Lastro where the day ends.
## Not indexed in the map grid — own node, art and collision. See docs/arquitetura/trabalho-energia-e-dia.md.

const ART: Texture2D = preload("res://assets/objects/bed.png")

## The piece occupies the node's cell and the one below it.
const CELLS_TALL: int = 2

## Where the player node ends up when lying down; see tools/gerar_objetos.py for the offset math.
const LYING_OFFSET: Vector2 = Vector2(0, 46)

## Where the player stands back up: the cell right at the foot of the bed.
const STANDING_OFFSET: Vector2 = Vector2(0, 96)

## Interact distance, in cells.
const RANGE: float = 2.2

## Collision box, slightly smaller than the art so the corridor stays passable.
const COLLISION: Vector2 = Vector2(56, 120)

const SCENERY_LAYER: int = 1


func _ready() -> void:
	var sprite := get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = ART
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func sleep_point() -> Vector2:
	return global_position + LYING_OFFSET


func wake_point() -> Vector2:
	return global_position + STANDING_OFFSET


func is_near(global_pos: Vector2) -> bool:
	return global_pos.distance_to(global_position) < RANGE * StationMap.CELL
