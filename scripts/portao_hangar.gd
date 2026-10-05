extends StaticBody2D
## Portao externo do hangar: cinco celulas, alterna entre fechado e aberto com E.

signal estado_alterado(esta_aberto: bool)

const REGIAO_FECHADO: Rect2 = Rect2(0, 0, 64, 320)
const REGIAO_ABERTO: Rect2 = Rect2(64, 0, 64, 320)

@export var aberto: bool = false

var _corpos_proximos: int = 0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _colisao: CollisionShape2D = $Colisao
@onready var _aviso: Label = $Aviso


func _ready() -> void:
	$Alcance.body_entered.connect(_ao_entrar)
	$Alcance.body_exited.connect(_ao_sair)
	_aplicar_estado()


func _unhandled_input(evento: InputEvent) -> void:
	if _corpos_proximos <= 0:
		return
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if (evento as InputEventKey).physical_keycode == KEY_E:
			alternar()
			get_viewport().set_input_as_handled()


func alternar() -> void:
	aberto = not aberto
	_aplicar_estado()
	estado_alterado.emit(aberto)


func _aplicar_estado() -> void:
	_sprite.region_rect = REGIAO_ABERTO if aberto else REGIAO_FECHADO
	_colisao.set_deferred(&"disabled", aberto)
	_atualizar_aviso()


func _atualizar_aviso() -> void:
	_aviso.visible = _corpos_proximos > 0
	_aviso.text = "E — fechar portão" if aberto else "E — abrir portão"


func _ao_entrar(_corpo: Node2D) -> void:
	_corpos_proximos += 1
	_atualizar_aviso()


func _ao_sair(_corpo: Node2D) -> void:
	_corpos_proximos = maxi(0, _corpos_proximos - 1)
	_atualizar_aviso()
