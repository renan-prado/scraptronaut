extends Node2D
## Universe background: deep-space color and stars with light flicker.

const COUNT: int = 280
const SEED: int = 20261002
const SPACE_COLOR: Color = Color("0b1024")
const STAR_COLORS: Array[Color] = [
	Color("ffffff"),
	Color("cfe4ff"),
	Color("9fc0ff"),
	Color("ffe9a8"),
	Color("d7c4ff"),
]

var _stars: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	_generate()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var area: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, area), SPACE_COLOR)
	for star: Dictionary in _stars:
		var brightness: float = star["brightness"] + 0.12 * sin(_time * star["rhythm"] + star["phase"])
		var color: Color = star["color"]
		color.a = clampf(brightness, 0.0, 1.0)
		var size: float = star["size"]
		var corner: Vector2 = Vector2(star["position"]) * area
		draw_rect(Rect2(corner.floor(), Vector2(size, size)), color)


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_stars.clear()
	for i: int in COUNT:
		_stars.append({
			"position": Vector2(rng.randf(), rng.randf()),
			"size": 1.0 if rng.randf() < 0.72 else 2.0,
			"color": STAR_COLORS[rng.randi_range(0, STAR_COLORS.size() - 1)],
			"brightness": rng.randf_range(0.25, 0.8),
			"rhythm": rng.randf_range(0.35, 1.1),
			"phase": rng.randf_range(0.0, TAU),
		})
