extends CanvasLayer
## Menu de pausa: Esc interrompe o jogo e oferece voltar ou fechar.
##
## O no processa SEMPRE, nao so pausado. Com PROCESS_MODE_WHEN_PAUSED o
## _unhandled_input ficava desligado enquanto o jogo rodava, e o Esc que deveria
## abrir o menu nunca chegava aqui — o menu existia e era inalcancavel.

## A interface e montada em codigo, nao numa cena propria: o menu nasce de um
## unico no da estacao, e cenas .tscn escritas a mao quebram com facilidade.
const MARGEM_PAINEL: int = 24
const ESPACO_BOTOES: int = 12
const LARGURA_BOTAO: int = 220

var _fundo: ColorRect
var _continuar: Button
var _sair: Button


func _ready() -> void:
	layer = 100
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed(&"ui_cancel"):
		alternar()
		get_viewport().set_input_as_handled()


func alternar() -> void:
	if visible:
		retomar()
	else:
		pausar()


func pausar() -> void:
	visible = true
	get_tree().paused = true
	_continuar.grab_focus()


func retomar() -> void:
	visible = false
	get_tree().paused = false


func sair() -> void:
	get_tree().quit()


# --- Montagem da interface ---------------------------------------------------

func _montar() -> void:
	_fundo = ColorRect.new()
	_fundo.name = "Fundo"
	_fundo.color = Color(0, 0, 0, 0.6)
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	var painel := PanelContainer.new()
	painel.name = "Painel"
	centro.add_child(painel)

	var margem := MarginContainer.new()
	margem.name = "Margem"
	for lado: StringName in [
		&"theme_override_constants/margin_left",
		&"theme_override_constants/margin_top",
		&"theme_override_constants/margin_right",
		&"theme_override_constants/margin_bottom",
	]:
		margem.set(lado, MARGEM_PAINEL)
	painel.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.name = "Coluna"
	coluna.set(&"theme_override_constants/separation", ESPACO_BOTOES)
	margem.add_child(coluna)

	_continuar = _montar_botao("Voltar ao jogo", retomar)
	coluna.add_child(_continuar)

	_sair = _montar_botao("Sair do jogo", sair)
	coluna.add_child(_sair)


func _montar_botao(rotulo: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = rotulo
	botao.custom_minimum_size = Vector2(LARGURA_BOTAO, 0)
	botao.pressed.connect(acao)
	return botao
