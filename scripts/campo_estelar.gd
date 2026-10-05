extends Node2D
## Fundo de universo: cor de espaco profundo e estrelas com cintilacao leve.

const QUANTIDADE: int = 280
const SEMENTE: int = 20261002
const COR_ESPACO: Color = Color("0b1024")
const CORES_ESTRELA: Array[Color] = [
	Color("ffffff"),
	Color("cfe4ff"),
	Color("9fc0ff"),
	Color("ffe9a8"),
	Color("d7c4ff"),
]

var _estrelas: Array[Dictionary] = []
var _tempo: float = 0.0


func _ready() -> void:
	_gerar()


func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()


func _draw() -> void:
	var area: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, area), COR_ESPACO)
	for estrela: Dictionary in _estrelas:
		var brilho: float = estrela["brilho"] + 0.12 * sin(_tempo * estrela["ritmo"] + estrela["fase"])
		var cor: Color = estrela["cor"]
		cor.a = clampf(brilho, 0.0, 1.0)
		var tamanho: float = estrela["tamanho"]
		var canto: Vector2 = Vector2(estrela["posicao"]) * area
		draw_rect(Rect2(canto.floor(), Vector2(tamanho, tamanho)), cor)


func _gerar() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE
	_estrelas.clear()
	for i: int in QUANTIDADE:
		_estrelas.append({
			"posicao": Vector2(rng.randf(), rng.randf()),
			"tamanho": 1.0 if rng.randf() < 0.72 else 2.0,
			"cor": CORES_ESTRELA[rng.randi_range(0, CORES_ESTRELA.size() - 1)],
			"brilho": rng.randf_range(0.25, 0.8),
			"ritmo": rng.randf_range(0.35, 1.1),
			"fase": rng.randf_range(0.0, TAU),
		})
