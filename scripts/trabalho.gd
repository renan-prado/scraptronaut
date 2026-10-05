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

## Moldura amarela do canteiro na mira. Nao e enfeite: e o unico jeito de saber
## em qual celula o F vai bater ANTES de apertar o F.
##
## Fina e transparente de proposito, e **sem tinta por dentro**. A primeira
## versao era opaca, grossa e com o quadro todo pintado, e tapava justamente o
## que o jogador foi olhar: a celula em que vai bater. A moldura diz QUAL
## celula; ela nao pode substituir o que esta desenhado nela.
##
## O amarelo e quase branco, e nao o ambar da obra. Toda marca de canteiro deste
## jogo e ambar — fita, baliza, trilho —, entao uma moldura ambar some dentro do
## que ela deveria estar apontando. Clara, ela le por cima da fita.
const COR_ALVO: Color = Color(1.0, 0.95, 0.62, 0.55)

## Grossura da moldura, em pixels de mundo. A camera do jogo anda perto de 0,4
## de zoom, entao isto sai com pouco mais de um pixel na tela — e e por isso que
## nao da para medir a grossura pelo numero daqui.
const GROSSURA_ALVO: float = 3.0

## Folga entre o painel e o canto da tela.
const MARGEM_DA_TELA: float = 12.0

## Separacao entre o contador do dia e a barra, dentro da linha do painel.
const SEPARACAO_NO_PAINEL: int = 4

## Corpo da letra do contador de dias, dentro do painel.
const TAMANHO_DO_DIA: int = 11

## Folga do rebaixo do dia, menor que a folga da placa que o guarda.
##
## Pode ser menor porque o rebaixo nao tem rebite: o desenho da moldura dele
## ocupa dois pixels de arte, e o resto da borda de nove pedacos e so chapa. Na
## placa de fora a folga TEM de passar do rebite, senao a barra sobe nele.
const FOLGA_DO_DIA: int = 4

var dia: int = 1

var _mapa: MapaEstacao
var _jogador: Node2D
var _construcao: Node2D
var _cama: Cama

## Celula em que a picareta esta batendo neste quadro. Fora dela nao ha obra em
## curso, e e o que a barra de progresso desenha.
var _canteiro: Vector2i = Vector2i.ZERO

## Ha canteiro na mira neste quadro. Separado de _batendo porque a moldura
## aparece ANTES de o jogador apertar o F: e ela que diz onde o F vai cair.
var _ha_alvo: bool = false
var _batendo: bool = false

var _dormindo: bool = false

var _dica: Label
var _contador: Label
var _painel: PainelHud
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
		_ha_alvo = false
		_batendo = false
		_dica.visible = false
		queue_redraw()
		return

	# O canteiro sai da VISTA do personagem, nao da distancia: com um canteiro
	# ao sul e outro a leste, quem decide e para onde ele esta virado.
	_canteiro = _mapa.canteiro_perto(_jogador.global_position, _jogador.call(&"rumo"))
	_ha_alvo = _mapa.tipo_em(_canteiro) == MapaEstacao.Tipo.OBRA
	var energia: float = _jogador.get(&"energia")
	var quer: bool = Input.is_physical_key_pressed(TECLA_TRABALHAR)

	_batendo = _ha_alvo and quer and energia > 0.0
	if _batendo:
		_bater(delta, energia)
	else:
		_jogador.call(&"parar_de_trabalhar")
	_atualizar_dica(_ha_alvo, energia)
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

## Moldura do alvo e barra de progresso, as duas em cima do canteiro. Ficam no
## mundo, e nao na interface, porque o que elas dizem e QUAL celula: numa obra
## de vinte celulas, uma marca no canto da tela nao apontaria nenhuma.
func _draw() -> void:
	if not _ha_alvo:
		return
	var lado: float = float(MapaEstacao.CELULA)
	var quadro := Rect2(Vector2(_canteiro) * lado, Vector2(lado, lado))
	draw_rect(quadro.grow(-GROSSURA_ALVO * 0.5), COR_ALVO, false, GROSSURA_ALVO)
	if not _batendo:
		return
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
	_painel = PainelHud.new()
	_painel.name = "Painel"
	_painel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_painel.offset_top = MARGEM_DA_TELA
	_painel.offset_right = -MARGEM_DA_TELA
	# A placa cresce para a ESQUERDA e para BAIXO a partir do canto. E o que
	# substitui a conta de largura que havia aqui: uma energia maxima maior da
	# mais divisoes a barra, e a placa inteira se alarga pelo lado de dentro da
	# tela em vez de empurrar a borda direita para fora dela.
	_painel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_painel.grow_vertical = Control.GROW_DIRECTION_END
	camada.add_child(_painel)

	# Uma linha por assunto, dentro da placa. Hoje ha uma; a proxima leitura do
	# HUD e um filho novo de _painel.conteudo, e nada aqui precisa mudar.
	var linha := HBoxContainer.new()
	linha.name = "DiaEEnergia"
	linha.add_theme_constant_override(&"separation", SEPARACAO_NO_PAINEL)
	_painel.conteudo.add_child(linha)

	# O contador mora num rebaixo cavado na propria placa: e a mesma arte com a
	# luz invertida, e e o que o faz ler como parte do instrumento em vez de
	# texto pousado em cima dele.
	var encaixe := PainelHud.new(PainelHud.Chapa.ENCAIXE)
	encaixe.name = "Dia"
	encaixe.apertar(FOLGA_DO_DIA)
	linha.add_child(encaixe)

	_contador = _escrever("dbe8f7")
	_contador.name = "Contador"
	# Sem contorno: aqui ha chapa atras do texto, e o contorno que o salva sobre
	# o casco so engorda a letra dentro do rebaixo.
	_contador.add_theme_constant_override(&"outline_size", 0)
	# Menor que o corpo do jogo: o painel e instrumento de canto de tela, e a
	# letra do tamanho padrao obrigava um rebaixo mais largo que a propria barra.
	_contador.add_theme_font_size_override(&"font_size", TAMANHO_DO_DIA)
	encaixe.conteudo.add_child(_contador)

	# A barra se dimensiona sozinha a partir da energia maxima; na linha ela so
	# precisa ficar centrada na altura, para nao esticar junto com o rebaixo.
	_barra_energia = BarraEnergia.new()
	_barra_energia.name = "Carga"
	_barra_energia.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(_barra_energia)

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
