extends StaticBody2D
## Hangar's outer gate: five cells, toggles open/closed with E.
## Unused since the gate became a tile in station_map.gd — see docs/decisoes/abertas.md.

signal state_changed(is_open: bool)

const CLOSED_REGION: Rect2 = Rect2(0, 0, 64, 320)
const OPEN_REGION: Rect2 = Rect2(64, 0, 64, 320)

@export var open: bool = false

var _nearby_bodies: int = 0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $Collision
@onready var _notice: Label = $Notice


func _ready() -> void:
	$Range.body_entered.connect(_on_entered)
	$Range.body_exited.connect(_on_exited)
	_apply_state()


func _unhandled_input(event: InputEvent) -> void:
	if _nearby_bodies <= 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_E:
			toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	open = not open
	_apply_state()
	state_changed.emit(open)


func _apply_state() -> void:
	_sprite.region_rect = OPEN_REGION if open else CLOSED_REGION
	_collision.set_deferred(&"disabled", open)
	_update_notice()


func _update_notice() -> void:
	_notice.visible = _nearby_bodies > 0
	_notice.text = "E — fechar portão" if open else "E — abrir portão"


func _on_entered(_body: Node2D) -> void:
	_nearby_bodies += 1
	_update_notice()


func _on_exited(_body: Node2D) -> void:
	_nearby_bodies = maxi(0, _nearby_bodies - 1)
	_update_notice()
