extends Node2D
## O dia de trabalho: energia, picareta e cama.
##
## Nenhum canteiro anda sozinho. Construir e demolir sao a mesma coisa daqui —
## trabalho batido numa celula — e trabalho sai de energia, que so volta
## dormindo. E isso que fecha o laco: planejar no modo de construcao, ir ate a
## obra, bater ate a energia acabar, dormir, continuar no dia seguinte.
##
## O no junta as tres pontas (energia, obra e cama) porque elas sao uma coisa
## so: separa-las daria tres nos que precisariam perguntar o estado um do outro
## a cada quadro.

## O script do jogador, so para ler ENERGIA_MAXIMA aqui em cima. O no em si vem
## da arvore, em _ready: isto e a constante, nao o personagem.
const Jogador: GDScript = preload("res://scripts/jogador.gd")

## Quantas marteladas fecham um quadrado de chao.
##
## **E o botao do ritmo**, e esta em marteladas porque e assim que o golpe se
## conta na mao: quem joga nao mede segundos, mede quantas vezes a picareta sobe
## e desce ate a celula fechar. Vinte e quatro, que foi onde a primeira versao
## caiu, e repeticao demais do mesmo ciclo de quatro quadros.
##
## Tudo o mais sai daqui. Mexer neste numero estica ou encurta o dia inteiro sem
## tocar no equilibrio: os custos de obra estao em energia, e a energia nao
## muda — continuam sendo oito quadrados por barra, vinte paredes, oito portas.
const MARTELADAS_POR_QUADRADO: float = 12.0

## Quanta energia a picareta queima por segundo.
##
## Sai da conta acima: um quadrado custa TRABALHO_POR_CELULA[PISO] de energia e
## leva MARTELADAS_POR_QUADRADO ciclos da folha de trabalho, cada um de
## Jogador.CICLO_TRABALHO segundos. Derivar — em vez de escrever a taxa — e o
## que mantem a martelada visivel casada com o custo: mudar a cadencia da
## animacao sem mexer aqui faria a conta de marteladas mentir em silencio.
const ENERGIA_POR_SEGUNDO: float = (
	MapaEstacao.TRABALHO_POR_CELULA[MapaEstacao.Tipo.PISO]
	/ (MARTELADAS_POR_QUADRADO * Jogador.CICLO_TRABALHO)
)

## Quanto dura uma barra cheia, em segundos de martelada continua. So para
## leitura e teste: quem manda sao os dois numeros acima.
const SEGUNDOS_DE_UM_DIA: float = Jogador.ENERGIA_MAXIMA / ENERGIA_POR_SEGUNDO

const TECLA_TRABALHAR: Key = KEY_F
const TECLA_DORMIR: Key = KEY_E

## Tempo das tres fases do dormir, em segundos: apagar, noite, clarear.
const APAGAR: float = 0.9
const NOITE: float = 0.6
const CLAREAR: float = 0.9

## Barra de obra, desenhada DENTRO da celula do canteiro.
##
## Dentro, e nao flutuando acima: quem bate fica sempre na celula vizinha, e uma
## barra acima do canteiro cai justamente em cima de quem esta martelando —
## foi o que apareceu na primeira captura, com a barra nos pes do personagem.
const BARRA_OBRA: Vector2 = Vector2(52, 9)

const COR_BARRA_FUNDO: Color = Color(0.06, 0.08, 0.13, 0.85)
const COR_BARRA_OBRA: Color = Color(1.0, 0.76, 0.33)

## Folga a esquerda da barra, para o contador de dias caber na mesma caixa.
const MARGEM_DA_BARRA: float = 24.0

var dia: int = 1

var _mapa: MapaEstacao
var _jogador: Node2D
var _construcao: Node2D
var _cama: Cama

## Celula em que a picareta esta batendo neste quadro. Fora dela nao ha obra em
## curso, e e o que a barra de progresso desenha.
var _canteiro: Vector2i = Vector2i.ZERO
var _batendo: bool = false

var _dormindo: bool = false

var _dica: Label
var _contador: Label
var _canto: VBoxContainer
var _barra_energia: BarraEnergia
var _escuro: ColorRect


func _ready() -> void:
	_mapa = get_parent().get_node("Mapa") as MapaEstacao
	_jogador = get_parent().get_node("Jogador") as Node2D
	_construcao = get_parent().get_node("Construcao") as Node2D
	_cama = get_parent().get_node_or_null("Cama") as Cama
	_montar_interface()
	if _jogador.has_signal(&"energia_alterada"):
		_jogador.connect(&"energia_alterada", _mostrar_energia)
		# E sincroniza na hora: o jogador emite o valor inicial no _ready dele,
		# que roda ANTES deste — por ser um irmao anterior na arvore — entao a
		# primeira emissao se perde e a barra nasceria com a energia maxima
		# zerada, numa divisao so.
		_mostrar_energia(
			_jogador.get(&"energia"),
			_jogador.get_script().get_script_constant_map()["ENERGIA_MAXIMA"]
		)
	# Abaixo do cursor de construcao (100), acima do mapa: a barra de obra nao
	# pode cobrir o retangulo de selecao.
	z_index = 90


func _process(delta: float) -> void:
	if _dormindo or _construcao.get(&"ativo"):
		_batendo = false
		_dica.visible = false
		queue_redraw()
		return

	_canteiro = _mapa.canteiro_perto(_jogador.global_position)
	var ha_obra: bool = _mapa.tipo_em(_canteiro) == MapaEstacao.Tipo.OBRA
	var energia: float = _jogador.get(&"energia")
	var quer: bool = Input.is_physical_key_pressed(TECLA_TRABALHAR)

	_batendo = ha_obra and quer and energia > 0.0
	if _batendo:
		_bater(delta, energia)
	else:
		_jogador.call(&"parar_de_trabalhar")
	_atualizar_dica(ha_obra, energia)
	queue_redraw()


## Converte energia em trabalho, nessa ordem: o mapa so recebe o que o jogador
## pode pagar, e o jogador so paga o que o canteiro aceitou. Pagar primeiro
## cobraria a sobra da ultima martelada, quando o canteiro ja fechou.
func _bater(delta: float, energia: float) -> void:
	var pedido: float = minf(ENERGIA_POR_SEGUNDO * delta, energia)
	var usado: float = _mapa.trabalhar(_canteiro, pedido)
	if usado > 0.0:
		_jogador.call(&"gastar_energia", usado)
	_jogador.call(&"trabalhar_em", _mapa.centro_da(_canteiro))


func _unhandled_input(evento: InputEvent) -> void:
	if _dormindo or _construcao.get(&"ativo"):
		return
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	# O E tambem abre o portao do hangar, em modo_construcao. Este no e irmao
	# posterior na arvore, entao recebe o evento primeiro — e por isso so o
	# consome perto da cama, deixando o resto passar.
	if (evento as InputEventKey).physical_keycode != TECLA_DORMIR:
		return
	if _cama == null or not _cama.perto(_jogador.global_position):
		return
	_deitar()
	get_viewport().set_input_as_handled()


# --- dormir ------------------------------------------------------------------

func _deitar() -> void:
	_dormindo = true
	_batendo = false
	_dica.visible = false
	_jogador.call(&"deitar", _cama.ponto_de_dormir())
	# A energia volta no meio da noite, com a tela apagada: ver a barra encher
	# com o personagem ainda deitado estraga a leitura de que o dia virou.
	var noite: Tween = create_tween()
	noite.tween_property(_escuro, ^"color:a", 1.0, APAGAR)
	noite.tween_interval(NOITE)
	noite.tween_callback(_amanhecer)
	noite.tween_property(_escuro, ^"color:a", 0.0, CLAREAR)
	noite.tween_interval(0.4)
	noite.tween_callback(_levantar)


func _amanhecer() -> void:
	dia += 1
	_jogador.call(&"descansar")
	_atualizar_contador()


func _levantar() -> void:
	_jogador.call(&"levantar", _cama.ponto_de_levantar())
	_dormindo = false


# --- desenho -----------------------------------------------------------------

## Barra de progresso em cima do canteiro. Fica no mundo, e nao na interface,
## porque o que ela mede e aquela celula: numa obra de vinte celulas, uma barra
## no canto da tela nao diria qual delas esta andando.
func _draw() -> void:
	if not _batendo:
		return
	var lado: float = float(MapaEstacao.CELULA)
	var canto := Vector2(_canteiro) * lado + (Vector2(lado, lado) - BARRA_OBRA) * 0.5
	draw_rect(Rect2(canto - Vector2.ONE, BARRA_OBRA + Vector2(2, 2)), COR_BARRA_FUNDO, true)
	var feito: float = _mapa.progresso_em(_canteiro)
	draw_rect(Rect2(canto, Vector2(BARRA_OBRA.x * feito, BARRA_OBRA.y)), COR_BARRA_OBRA, true)


# --- interface ---------------------------------------------------------------

func _montar_interface() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Interface"
	camada.layer = 40
	add_child(camada)

	# A cortina da noite entra na mesma camada, por cima de tudo que esta aqui.
	_escuro = ColorRect.new()
	_escuro.name = "Noite"
	_escuro.color = Color(0.02, 0.03, 0.06, 0.0)
	_escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_escuro)

	# No canto direito: o esquerdo e do titulo do modo de construcao.
	_canto = VBoxContainer.new()
	_canto.name = "Dia"
	_canto.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_canto.offset_top = 12.0
	_canto.offset_right = -16.0
	_canto.alignment = BoxContainer.ALIGNMENT_END
	camada.add_child(_canto)

	_contador = _escrever("dbe8f7")
	_contador.name = "Contador"
	_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_canto.add_child(_contador)

	# A barra se dimensiona sozinha a partir da energia maxima, entao a caixa
	# que a contem nao fixa largura nenhuma: so a alinha a direita.
	var fila := HBoxContainer.new()
	fila.name = "Energia"
	fila.alignment = BoxContainer.ALIGNMENT_END
	_canto.add_child(fila)

	_barra_energia = BarraEnergia.new()
	_barra_energia.name = "Carga"
	fila.add_child(_barra_energia)

	_dica = _escrever("ffd98a")
	_dica.name = "Dica"
	_dica.visible = false
	_dica.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dica.offset_left = -160.0
	_dica.offset_top = -92.0
	camada.add_child(_dica)

	_atualizar_contador()


## Contorno preto no texto: a interface fica por cima do mapa, e sem isso o
## cinza do casco come as letras claras.
func _escrever(cor: String) -> Label:
	var rotulo := Label.new()
	rotulo.add_theme_color_override(&"font_color", Color(cor))
	rotulo.add_theme_color_override(&"font_outline_color", Color(0.03, 0.06, 0.12, 0.9))
	rotulo.add_theme_constant_override(&"outline_size", 6)
	return rotulo


func _atualizar_contador() -> void:
	_contador.text = "Dia %d" % dia


func _mostrar_energia(energia: float, maxima: float) -> void:
	_barra_energia.mostrar(energia, maxima)
	# A caixa acompanha a largura da barra, que muda com o numero de divisoes:
	# com borda esquerda fixa, uma energia maxima maior empurraria a barra para
	# fora da tela — e e justamente crescer que a barra existe para poder fazer.
	_canto.offset_left = -_barra_energia.custom_minimum_size.x - MARGEM_DA_BARRA


func _atualizar_dica(ha_obra: bool, energia: float) -> void:
	if _cama != null and _cama.perto(_jogador.global_position):
		_dica.text = "E — dormir e começar o dia %d" % (dia + 1)
		_dica.visible = true
		return
	if not ha_obra:
		_dica.visible = false
		return
	if energia <= 0.0:
		_dica.text = "sem energia — durma para continuar a obra"
	elif _batendo:
		_dica.text = "trabalhando…"
	else:
		_dica.text = "F — trabalhar na obra"
	_dica.visible = true
