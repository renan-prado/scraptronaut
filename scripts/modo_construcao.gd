extends Node2D
## Modo de construcao da estacao: cursor em celula, ferramentas e camera livre.
##
## A dica de `E` do portao do hangar morava aqui e saiu em 2026-10-05: ela so
## aparecia com o modo FECHADO, entao nunca foi interface de construcao. Hoje e
## uma fala do personagem, em scripts/trabalho.gd.

## Cores do cursor: a recusa precisa ser visivel sem ler o texto.
const COR_PERMITIDO: Color = Color(0.45, 0.95, 0.6, 0.28)
const COR_RECUSADO: Color = Color(0.95, 0.35, 0.35, 0.26)
const COR_CONTORNO: Color = Color(0.95, 0.98, 1.0, 0.85)

## A cor da recusa escrita, igual a do retangulo recusado: o balao e a selecao
## dizem a mesma coisa, entao nao podem sair de cores diferentes.
const COR_DA_RECUSA: String = "ff9f9f"

## Quanto a recusa fica na tela, em segundos. Ela TEM prazo porque mudou de
## lugar: dentro da placa uma linha parada era so uma linha parada, mas o balao
## mora em cima do mapa, preso na celula recusada, e ali o que ninguem apagou
## vira obstaculo — o jogador ja corrigiu a selecao e continua com o aviso
## cobrindo o casco atras dela.
const DURACAO_DA_RECUSA: float = 3.0

const ZOOM_MINIMO: float = 0.25
const ZOOM_MAXIMO: float = 1.5
const PASSO_ZOOM: float = 1.12
const VELOCIDADE_CAMERA: float = 900.0

## Teto de celulas por arrasto. Sem ele um arrasto distraido com a vista
## afastada aplicaria milhares de celulas de uma vez.
const MAXIMO_POR_ARRASTO: int = 2500

enum Ferramenta { EXPANDIR, PAREDE, PORTA, PORTAO, DEMOLIR }

## O nome de cada ferramenta, na ordem das teclas 1 a 5 — e a mesma ordem das
## celulas de ICONES.
##
## A DICA DE CADA UMA SAIU em 2026-10-05, com o resto do texto solto do modo.
## Ela morava num bloco de tres linhas no alto da tela ("aumenta a área; o casco
## nasce ao redor"), que o jogador pediu para tirar: era paragrafo de manual
## impresso por cima do cenario, e o modo todo se descobre clicando.
const FERRAMENTAS: Array[String] = [
	"Expandir", "Parede", "Porta", "Portão de nave", "Demolir",
]

const ICONES: String = "res://assets/interface/ferramentas.png"
const LADO_ICONE: int = 32

## A celula do icone do MODO, depois das cinco ferramentas. Nao e o icone de
## nenhuma delas de proposito: o atalho abre a construcao inteira, e usar o
## desenho do "expandir" faria o atalho ler como a ferramenta de expandir.
const ICONE_DO_MODO: int = 5

## A tecla que abre e fecha o modo, e o nome dela na folha de tampas.
##
## **Era TAB (e B), e virou F1 em 2026-10-05, a pedido.** Os dois nomes andam
## juntos porque sao a mesma decisao: a tampa desenhada no canto da tela tem de
## dizer a tecla que o _unhandled_input de fato escuta.
const TECLA_CONSTRUIR: Key = KEY_F1
const NOME_DA_TECLA: String = "F1"

## Folga entre os paineis e a beira da tela. A mesma de trabalho.gd, porque os
## dois cantos de cima sao o mesmo canto visto de dois lados.
const MARGEM_DA_TELA: float = 12.0

## Onde comeca o painel das ferramentas, medido do alto da tela.
##
## **E a altura reservada para a placa do HUD**, que mora no mesmo canto de cima
## a direita. Os dois paineis nao se conhecem — um e de scripts/trabalho.gd e o
## outro daqui —, entao o unico acordo entre eles e este numero, e ha uma
## verificacao em tools/testar_estacao.gd que falha se eles passarem a se cobrir.
##
## 71 = MARGEM_DA_TELA (12) + a altura medida da placa (49) + 10 de respiro.
## **Era 58, e subiu em 2026-10-06 com a troca da fonte**: texto maior engordou
## a placa de 36 para 49 e o painel passou a cobrir o contador do dia. Quem
## mexer no corpo da fonte ou no conteudo da placa mexe aqui — e a verificacao
## e que avisa, porque na tela o estrago aparece so quando o modo esta aberto.
const ABAIXO_DO_HUD: float = 71.0

## Quanto a tampa da tecla avanca para fora do icone do atalho, no canto de
## baixo a direita dele. Encavalada, e nao ao lado: a tampa diz o que apertar
## para aquele icone, e peca ao lado leria como um segundo item do menu.
const SALIENCIA_DA_TECLA: float = 3.0

## Folga entre a tampa da tecla e o que ela faz, nas linhas do painel.
const SEPARACAO_DA_TECLA: int = 5

## Folga entre uma linha e a seguinte, dentro do painel.
const SEPARACAO_DAS_LINHAS: int = 2

## A cor da linha da ferramenta escolhida, e a do passar do mouse.
##
## **A escolhida fica mais ESCURA que a placa, nao mais clara.** O tema padrao
## do Godot acende o botao apertado, e dentro desta chapa isso virava uma caixa
## branca maior que a placa. Escura, a linha le como rebaixo cavado — e a mesma
## leitura do contador do dia, que e um encaixe na mesma chapa.
const COR_ESCOLHIDA: Color = Color(0.10, 0.125, 0.172, 0.94)
const COR_SOBRE: Color = Color(1.0, 1.0, 1.0, 0.07)

## Cor da letra das linhas do painel, e a da linha desligada.
const COR_LINHA: String = "dbe8f7"
const COR_LINHA_APAGADA: Color = Color(0.55, 0.60, 0.68)

## Atlas da porta, usado para desenhar a previa da peca debaixo do cursor.
const ARTE_PORTA: String = "res://assets/tiles/estacao/porta.png"

## Quanto da previa aparece. Baixo demais some sobre o casco claro; alto demais
## deixa de parecer previa e vira porta ja posta.
const ALFA_PREVIA: float = 0.55

var ativo: bool = false

var _mapa: MapaEstacao
var _jogador: Node2D
var _camera_jogador: Camera2D
var _camera: Camera2D

var _ferramenta: Ferramenta = Ferramenta.EXPANDIR
var _celula: Vector2i = Vector2i.ZERO

## Por que a celula sob o cursor nao aceita a ferramenta. Vazio quer dizer que
## aceita. So pinta o cursor: escrever isso na tela a cada quadro encheria a
## barra de "ja e piso" a estacao inteira.
var _motivo: String = ""

## Recusa de uma tentativa de verdade, essa sim escrita na tela — num balao
## ancorado na selecao recusada, e nao no painel das ferramentas.
##
## **Saiu do rodape da placa em 2026-10-06, a pedido.** La ela estava longe do
## que reclamava: o jogador clica numa celula do outro lado da tela, a recusa
## acende num canto, e nada liga uma coisa a outra. O balao tem rabo, aponta, e
## responde "qual quadrado esta errado" sem precisar dizer.
var _mensagem: String = ""

## Onde o rabo do balao encosta: o meio da borda de cima da area recusada, em
## coordenada de mundo. Guardado e nao recalculado porque a recusa e de uma
## tentativa que ja passou — o cursor anda depois dela, e o balao tem de ficar
## apontando para o lugar onde o clique foi dado.
var _ponto_da_recusa: Vector2 = Vector2.ZERO

## O que falta do prazo de DURACAO_DA_RECUSA.
var _tempo_da_recusa: float = 0.0

## Celula onde o botao do mouse desceu. Enquanto o botao esta em baixo, a area
## e o retangulo dela ate o cursor; um clique seco vira um retangulo de 1x1.
var _ancora: Vector2i = Vector2i.ZERO
var _arrastando: int = 0

## Para que lado a segunda celula da porta aponta, em indice de
## MapaEstacao.CARDEAIS. O botao direito gira de 90 em 90.
var _rotacao: int = 1

## Mapa como estava quando o modo abriu. E o que Cancelar devolve: a planta so
## vira obra depois de confirmar, entao o jogador pode desenhar a estacao
## inteira, olhar, e desistir dela sem deixar rastro.
var _ao_entrar: Dictionary = {}
var _pendentes: int = 0

## O atalho no canto de cima a esquerda, visivel so com o modo FECHADO: o icone
## do modo com a tampa da tecla encavalada nele.
var _atalho: PainelHud

## O painel das ferramentas, no canto de cima a direita, visivel so com o modo
## ABERTO.
var _painel: PainelHud

var _balao: Balao
var _confirmar: Button
var _cancelar: Button
var _arte_porta: Texture2D
var _botoes: Array[Button] = []


func _ready() -> void:
	_mapa = get_parent().get_node("Mapa") as MapaEstacao
	_jogador = get_parent().get_node("Jogador") as Node2D
	_camera_jogador = _jogador.get_node("Camera2D") as Camera2D
	_camera = $Camera2D as Camera2D
	# As duas cameras nascem habilitadas — Camera2D desabilitada recusa
	# make_current() — e a ultima a entrar na arvore ganha. Como este no vem
	# depois do jogador, sem esta linha o jogo abriria na camera parada.
	_camera_jogador.make_current()
	_arte_porta = load(ARTE_PORTA)
	_montar_interface()
	_atualizar_interface()
	z_index = 100


func _process(delta: float) -> void:
	if not ativo:
		return
	_mover_camera(delta)
	var alvo: Vector2i = _mapa.celula_de(get_global_mouse_position())
	if alvo != _celula:
		_celula = alvo
		_avaliar()
		_atualizar_interface()
		queue_redraw()
	# Depois da camera: o balao mora numa CanvasLayer e so a POSICAO dele vem do
	# mundo, entao ele precisa ser recolocado toda vez que a vista anda.
	if _mensagem != "":
		_tempo_da_recusa -= delta
		if _tempo_da_recusa <= 0.0:
			_calar_recusa()
		else:
			_balao.seguir(_ponto_da_recusa)


## Esc e lido em _input, antes do _unhandled_input: o menu de pausa e um irmao
## posterior na arvore e ganharia o evento primeiro, abrindo o menu em vez de
## sair do modo.
func _input(evento: InputEvent) -> void:
	if not ativo:
		return
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if (evento as InputEventKey).physical_keycode == KEY_ESCAPE:
			cancelar()
			get_viewport().set_input_as_handled()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		var tecla: int = (evento as InputEventKey).physical_keycode
		if tecla == TECLA_CONSTRUIR:
			alternar()
			get_viewport().set_input_as_handled()
			return
		if not ativo and tecla == KEY_E:
			if _mapa.alternar_portao_perto(_jogador.global_position):
				get_viewport().set_input_as_handled()
			return
		if ativo and (tecla == KEY_ENTER or tecla == KEY_KP_ENTER):
			confirmar()
			get_viewport().set_input_as_handled()
			return
		if ativo and tecla >= KEY_1 and tecla <= KEY_5:
			_escolher(tecla - KEY_1)
			get_viewport().set_input_as_handled()
		return

	if not ativo or not (evento is InputEventMouseButton):
		return
	var botao := evento as InputEventMouseButton
	match botao.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_ajustar_zoom(PASSO_ZOOM)
		MOUSE_BUTTON_WHEEL_DOWN:
			_ajustar_zoom(1.0 / PASSO_ZOOM)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
			var lado: int = 1 if botao.button_index == MOUSE_BUTTON_LEFT else -1
			# Com a porta na mao o botao direito gira a peca em vez de remover:
			# peca de tamanho fixo nao tem arrasto, e girar e a unica escolha
			# que sobra para o jogador.
			if _peca_fixa():
				if lado < 0 and botao.pressed:
					_girar()
				elif lado > 0 and not botao.pressed:
					_aplicar(1, _area())
			elif botao.pressed:
				_ancora = _celula
				_arrastando = lado
			elif _arrastando == lado:
				# A area e lida ANTES de zerar _arrastando: _area() usa a ancora
				# so enquanto o arrasto esta em curso, e zerar antes encolhia
				# todo arrasto para a unica celula sob o cursor na hora de
				# soltar — que quase sempre e vacuo solto, e a recusa saia como
				# a recusa de quem tenta estender piso solto no vacuo.
				_aplicar(lado, _area())
				_arrastando = 0
			queue_redraw()
		_:
			return
	get_viewport().set_input_as_handled()


func alternar() -> void:
	if ativo:
		confirmar()
	else:
		_entrar()


## Fecha o modo e deixa a planta de pe. Nenhum canteiro anda por sair daqui: a
## obra so avanca com o jogador batendo nela, e a planta confirmada e so a lista
## do que ha para fazer.
func confirmar() -> void:
	if ativo:
		_sair()


## Fecha o modo desfazendo tudo que foi feito desde que ele abriu. Existe porque
## o jogador precisa poder experimentar uma planta inteira antes de aceita-la —
## sem isso o unico jeito de voltar atras seria remover celula por celula, e a
## expansao nem tem volta exata, ja que remover piso abre vacuo.
func cancelar() -> void:
	if not ativo:
		return
	if _pendentes > 0:
		_mapa.restaurar(_ao_entrar)
	_sair()


func _entrar() -> void:
	ativo = true
	_arrastando = 0
	_calar_recusa()
	_ao_entrar = _mapa.instantaneo()
	_pendentes = 0
	_camera.global_position = _jogador.global_position
	_camera.zoom = _camera_jogador.zoom
	_camera.make_current()
	_celula = _mapa.celula_de(get_global_mouse_position())
	_ancora = _celula
	_avaliar()
	if _jogador.has_method(&"travar"):
		_jogador.call(&"travar", true)
	_atualizar_interface()
	queue_redraw()


func _sair() -> void:
	ativo = false
	_arrastando = 0
	_calar_recusa()
	_pendentes = 0
	_ao_entrar = {}
	_camera_jogador.make_current()
	if _jogador.has_method(&"travar"):
		_jogador.call(&"travar", false)
	_atualizar_interface()
	queue_redraw()


# --- edicao ------------------------------------------------------------------

func _escolher(indice: int) -> void:
	_ferramenta = indice as Ferramenta
	_calar_recusa()
	_avaliar()
	_atualizar_interface()
	queue_redraw()


## Ferramenta de peca pronta: tamanho fixo, sem arrasto e sem remocao pelo botao
## direito. Hoje so a porta, que ocupa exatamente duas celulas.
func _peca_fixa() -> bool:
	return _ferramenta == Ferramenta.PORTA


func _girar() -> void:
	_rotacao = (_rotacao + 1) % MapaEstacao.CARDEAIS.size()
	_calar_recusa()
	_avaliar()
	_atualizar_interface()
	queue_redraw()


## As duas celulas da porta, na ordem: ancora e o lado para onde ela aponta.
func _peca() -> Array[Vector2i]:
	return [_celula, _celula + MapaEstacao.CARDEAIS[_rotacao]]


func _area() -> Rect2i:
	if _peca_fixa():
		var outra: Vector2i = _celula + MapaEstacao.CARDEAIS[_rotacao]
		var canto := Vector2i(mini(_celula.x, outra.x), mini(_celula.y, outra.y))
		return Rect2i(canto, (outra - _celula).abs() + Vector2i.ONE)
	var ancora: Vector2i = _ancora if _arrastando != 0 else _celula
	var inicio := Vector2i(mini(ancora.x, _celula.x), mini(ancora.y, _celula.y))
	var fim := Vector2i(maxi(ancora.x, _celula.x), maxi(ancora.y, _celula.y))
	return Rect2i(inicio, fim - inicio + Vector2i.ONE)


## O botao direito sempre demole, qualquer que seja a ferramenta: e o atalho que
## faz o modo render sem obrigar a trocar de ferramenta a cada correcao. A porta
## e a excecao — com ela na mao o direito gira a peca.
func _aplicar(lado: int, area: Rect2i) -> void:
	var ferramenta: Ferramenta = Ferramenta.DEMOLIR if lado < 0 else _ferramenta
	if area.size.x * area.size.y > MAXIMO_POR_ARRASTO:
		_anunciar("Área grande demais para uma vez só", area)
		return

	# A peca vai na ordem que o jogador escolheu; o retangulo, varrido em linhas.
	var celulas: Array[Vector2i] = []
	if _peca_fixa():
		celulas = _peca()
	else:
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				celulas.append(Vector2i(x, y))

	var do_jogador: Vector2i = _mapa.celula_de(_jogador.global_position)
	_anunciar(_mapa.aplicar(_acao(ferramenta), celulas, do_jogador), area)
	_pendentes = _mapa.diferencas(_ao_entrar)
	_avaliar()
	_atualizar_interface()
	queue_redraw()


## Poe a recusa de uma tentativa no balao, apontando para a area que a levou.
## `motivo` vazio e o caso em que deu certo, e ali o balao se cala: a selecao
## seguinte ja e outra, e um aviso sobrevivente mentiria sobre ela.
##
## O rabo encosta no MEIO DA BORDA DE CIMA da area, e nao no centro dela: o
## balao sobe a partir do ponto, entao daqui ele fica logo acima do retangulo
## vermelho em vez de deitar por cima do que o jogador acabou de selecionar.
func _anunciar(motivo: String, area: Rect2i) -> void:
	if motivo == "":
		_calar_recusa()
		return
	var lado: float = float(MapaEstacao.CELULA)
	_mensagem = motivo
	_ponto_da_recusa = Vector2(
		(float(area.position.x) + float(area.size.x) * 0.5) * lado,
		float(area.position.y) * lado
	)
	_tempo_da_recusa = DURACAO_DA_RECUSA
	_balao.dizer("", "", motivo, COR_DA_RECUSA)
	_balao.seguir(_ponto_da_recusa)
	_atualizar_interface()


func _calar_recusa() -> void:
	_mensagem = ""
	_tempo_da_recusa = 0.0
	if _balao != null:
		_balao.calar()


func _acao(ferramenta: Ferramenta) -> MapaEstacao.Acao:
	match ferramenta:
		Ferramenta.EXPANDIR:
			return MapaEstacao.Acao.EXPANDIR
		Ferramenta.PAREDE:
			return MapaEstacao.Acao.PAREDE
		Ferramenta.PORTA:
			return MapaEstacao.Acao.PORTA
		Ferramenta.PORTAO:
			return MapaEstacao.Acao.PORTAO
		_:
			return MapaEstacao.Acao.DEMOLIR


## Cor do cursor: verde quando a area tem ao menos uma celula que aceita a
## ferramenta, porque e isso que aplicar() vai fazer. Julgar so a ancora
## pintaria de vermelho um retangulo que comeca no vazio e termina encostando
## na estacao — e esse e justamente o arrasto mais comum.
func _avaliar() -> void:
	var ferramenta: Ferramenta = Ferramenta.DEMOLIR if _arrastando < 0 else _ferramenta
	var do_jogador: Vector2i = _mapa.celula_de(_jogador.global_position)

	# A peca e tudo ou nada: basta uma metade recusada para a porta nao entrar,
	# entao o cursor so fica verde com as duas aceitas. A regra do retangulo e a
	# oposta de proposito — ver abaixo.
	if _peca_fixa():
		_motivo = _mapa.pode_porta_em(_peca(), do_jogador)
		return

	var area: Rect2i = _area()
	if area.size.x * area.size.y > MAXIMO_POR_ARRASTO:
		_motivo = "Área grande demais para uma vez só"
		return

	var primeiro: String = ""
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var recusa: String = _recusa(ferramenta, Vector2i(x, y), do_jogador)
			if recusa == "":
				_motivo = ""
				return
			if primeiro == "":
				primeiro = recusa
	_motivo = primeiro


func _recusa(ferramenta: Ferramenta, celula: Vector2i, do_jogador: Vector2i) -> String:
	match ferramenta:
		Ferramenta.EXPANDIR:
			return _mapa.pode_expandir(celula)
		Ferramenta.PAREDE:
			return _mapa.pode_muro(celula, do_jogador)
		Ferramenta.PORTA:
			return _mapa.pode_porta(celula, do_jogador)
		Ferramenta.PORTAO:
			return _mapa.pode_portao(celula)
		_:
			return _mapa.pode_demolir(celula, do_jogador)


# --- camera ------------------------------------------------------------------

func _mover_camera(delta: float) -> void:
	var direcao := Vector2(
		Input.get_axis(&"ui_left", &"ui_right"),
		Input.get_axis(&"ui_up", &"ui_down")
	)
	if Input.is_physical_key_pressed(KEY_A):
		direcao.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direcao.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		direcao.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direcao.y += 1.0
	if direcao == Vector2.ZERO:
		return
	# Dividir pelo zoom mantem a mesma velocidade na tela com a vista afastada.
	_camera.global_position += direcao.limit_length(1.0) * VELOCIDADE_CAMERA * delta / _camera.zoom.x


func _ajustar_zoom(fator: float) -> void:
	var novo: float = clampf(_camera.zoom.x * fator, ZOOM_MINIMO, ZOOM_MAXIMO)
	_camera.zoom = Vector2(novo, novo)


# --- desenho do cursor -------------------------------------------------------

func _draw() -> void:
	if not ativo:
		return
	var lado: float = float(MapaEstacao.CELULA)
	var area: Rect2i = _area()
	var retangulo := Rect2(Vector2(area.position) * lado, Vector2(area.size) * lado)
	draw_rect(retangulo, COR_PERMITIDO if _motivo == "" else COR_RECUSADO, true)
	draw_rect(retangulo, COR_CONTORNO, false, 2.0)
	if _peca_fixa():
		_desenhar_previa_da_porta()


## Previa da porta: a propria arte do tile, meio transparente, nas duas celulas.
##
## E a arte e nao um retangulo porque a peca tem orientacao, e o jogador precisa
## ver para onde ela aponta antes de clicar — o retangulo de duas celulas sozinho
## nao diz se a folha corre deitada ou em pe.
func _desenhar_previa_da_porta() -> void:
	var lado: float = float(MapaEstacao.CELULA)
	var celulas: Array[Vector2i] = _peca()
	var passo: Vector2i = celulas[1] - celulas[0]
	# Linha 0 e a porta deitada; a 1 sai de um giro do atlas. Na deitada a
	# metade B fica a leste, e na em pe, ao norte.
	var linha: int = 0 if passo.x != 0 else 1
	var para_b := Vector2i(1, 0) if linha == 0 else Vector2i(0, -1)
	for celula: Vector2i in celulas:
		var outra: Vector2i = celulas[1] if celula == celulas[0] else celulas[0]
		var segmento: int = 1 if celula + para_b == outra else 2
		var destino := Rect2(Vector2(celula) * lado, Vector2(lado, lado))
		var recorte := Rect2(segmento * 2 * lado, linha * lado, lado, lado)
		draw_texture_rect_region(_arte_porta, destino, recorte,
			Color(1.0, 1.0, 1.0, ALFA_PREVIA))


# --- interface ---------------------------------------------------------------
#
# SAO DOIS PAINEIS, E NUNCA OS DOIS AO MESMO TEMPO.
#
# Com o modo FECHADO, o canto de cima a esquerda mostra so o ATALHO: o icone do
# modo com a tampa de F1 encavalada nele. Era uma linha de texto solta na tela
# ("TAB — modo construção"), que o jogador pediu para virar menu de pixel:
# frase escrita por cima do cenario le como legenda de depuracao, e um icone com
# a tecla desenhada em cima diz a mesma coisa sem nenhuma palavra.
#
# Com o modo ABERTO, o canto de cima a direita mostra o PAINEL das ferramentas.
# Ele veio do rodape da tela em 2026-10-05, a pedido, e virou COLUNA no caminho:
# em fila, as cinco ferramentas com nome mediam mais de meia tela e nao havia
# "canto de cima a direita" que as coubesse — atravessariam o alto inteiro e
# esbarrariam na placa do HUD. Em coluna o painel fica estreito, e e o unico
# arranjo em que a posicao pedida e um canto de verdade.
#
# As duas placas sao PainelHud, a mesma chapa de aco da barra de energia: o modo
# de construcao e instrumento da estacao como o HUD e, e dar a ele uma caixa
# propria faria o jogador ler duas interfaces onde ha uma.

func _montar_interface() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Interface"
	camada.layer = 50
	add_child(camada)
	_montar_atalho(camada)
	_montar_painel(camada)
	_montar_balao(camada)


## O balao da recusa. Mesma caixa da fala do personagem, e na mesma camada dos
## paineis: o modo tem uma interface so, e uma segunda moldura para uma frase
## de tres palavras seria caixa nova dizendo o que esta nao sabe dizer.
##
## Entra DEPOIS do painel para passar por cima dele: a selecao pode estar
## debaixo das ferramentas, e balao cortado pela placa leria como erro de
## desenho em vez de aviso.
func _montar_balao(camada: CanvasLayer) -> void:
	_balao = Balao.new()
	_balao.name = "Recusa"
	_balao.visible = false
	camada.add_child(_balao)


## O atalho de abrir o modo: icone e tampa de tecla, sem uma palavra.
func _montar_atalho(camada: CanvasLayer) -> void:
	_atalho = PainelHud.new()
	_atalho.name = "Atalho"
	_atalho.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_atalho.offset_left = MARGEM_DA_TELA
	_atalho.offset_top = MARGEM_DA_TELA
	camada.add_child(_atalho)

	# O icone e a tampa se sobrepoem, entao nao podem ser irmaos num container:
	# container poe um ao lado do outro. Esta moldura e do tamanho do icone, e a
	# tampa se ancora no canto de baixo a direita DELA.
	var moldura := Control.new()
	moldura.name = "Construir"
	moldura.custom_minimum_size = Vector2(LADO_ICONE, LADO_ICONE)
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atalho.conteudo.add_child(moldura)

	var icone := TextureRect.new()
	icone.name = "Icone"
	icone.texture = _recortar_icone(load(ICONES), ICONE_DO_MODO)
	icone.set_anchors_preset(Control.PRESET_FULL_RECT)
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(icone)

	var tampa := Tecla.new()
	tampa.name = "Tecla"
	# 1:1, e nao a escala das linhas do painel: aqui a tampa esta encavalada num
	# icone de LADO_ICONE, e na escala da letra ela cobriria o proprio icone.
	tampa.mostrar(NOME_DA_TECLA, 1)
	moldura.add_child(tampa)
	var lado: Vector2 = tampa.custom_minimum_size
	tampa.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	tampa.offset_left = SALIENCIA_DA_TECLA - lado.x
	tampa.offset_top = SALIENCIA_DA_TECLA - lado.y
	tampa.offset_right = SALIENCIA_DA_TECLA
	tampa.offset_bottom = SALIENCIA_DA_TECLA


## O painel das ferramentas: uma linha por tecla, de cima para baixo.
func _montar_painel(camada: CanvasLayer) -> void:
	_painel = PainelHud.new()
	_painel.name = "Painel"
	_painel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_painel.offset_top = ABAIXO_DO_HUD
	_painel.offset_right = -MARGEM_DA_TELA
	# Cresce para a ESQUERDA e para BAIXO, como a placa do HUD: um nome de
	# ferramenta mais comprido alarga o painel pelo lado de dentro da tela em vez
	# de empurrar a borda direita para fora dela.
	_painel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_painel.grow_vertical = Control.GROW_DIRECTION_END
	camada.add_child(_painel)
	_painel.conteudo.add_theme_constant_override(
		&"separation", SEPARACAO_DAS_LINHAS
	)

	var folha: Texture2D = load(ICONES)
	for i: int in FERRAMENTAS.size():
		var botao := Button.new()
		botao.name = FERRAMENTAS[i]
		botao.text = FERRAMENTAS[i]
		botao.icon = _recortar_icone(folha, i)
		botao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		botao.toggle_mode = true
		botao.add_theme_constant_override(&"h_separation", SEPARACAO_DA_TECLA)
		botao.pressed.connect(_escolher.bind(i))
		_vestir(botao)
		_painel.conteudo.add_child(_linha(str(i + 1), botao))
		_botoes.append(botao)

	_confirmar = _decisao("Confirmar · Enter", confirmar)
	_painel.conteudo.add_child(_linha("", _confirmar))
	_cancelar = _decisao("Cancelar · Esc", cancelar)
	_painel.conteudo.add_child(_linha("", _cancelar))


## Uma linha do painel: a tampa da tecla e o que ela faz, lado a lado.
##
## Com `tecla` vazia entra um VAO da largura da tampa, e nao uma tampa
## escondida: container do Godot pula filho invisivel em vez de guardar o lugar
## dele, e as duas linhas sem tecla saiam encostadas na borda enquanto as cinco
## de cima comecavam recuadas.
func _linha(tecla: String, direita: Control) -> HBoxContainer:
	var linha := HBoxContainer.new()
	linha.name = "Linha"
	linha.add_theme_constant_override(&"separation", SEPARACAO_DA_TECLA)
	if tecla == "":
		var vao := Control.new()
		vao.name = "Vao"
		vao.custom_minimum_size = Vector2(Tecla.LADO * Tecla.ESCALA, 0)
		vao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_child(vao)
	else:
		var tampa := Tecla.new()
		tampa.name = "Tecla"
		tampa.mostrar(tecla)
		tampa.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		linha.add_child(tampa)
	direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(direita)
	return linha


func _decisao(rotulo: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.name = rotulo.get_slice(" ", 0)
	botao.text = rotulo
	botao.pressed.connect(acao)
	_vestir(botao)
	return botao


## Tira do botao o tema padrao do Godot inteiro e poe o desta placa no lugar.
##
## A placa ja e a caixa: botao com moldura propria dentro dela daria duas
## molduras encaixadas uma na outra. E `flat = true` nao resolve sozinho — ele
## apaga so o estado parado, e deixa o apertado acender uma caixa clara maior
## que a chapa que o guarda.
func _vestir(botao: Button) -> void:
	botao.focus_mode = Control.FOCUS_NONE
	botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
	botao.add_theme_color_override(&"font_color", Color(COR_LINHA))
	botao.add_theme_color_override(&"font_hover_color", Color(COR_LINHA))
	botao.add_theme_color_override(&"font_pressed_color", Color(COR_LINHA))
	botao.add_theme_color_override(&"font_focus_color", Color(COR_LINHA))
	botao.add_theme_color_override(&"font_disabled_color", COR_LINHA_APAGADA)
	# Os quatro estados usam a MESMA chapa, e so a cor muda — inclusive o parado,
	# que e transparente. Parado com StyleBoxEmpty media menos que os outros, e a
	# largura minima do botao sai do estado parado: a linha escolhida ganhava
	# quatro pixels de folga que ninguem tinha reservado, e comia a ultima letra
	# de "Portão de nave".
	botao.add_theme_stylebox_override(&"normal", _chapa(Color(0, 0, 0, 0)))
	botao.add_theme_stylebox_override(&"focus", _chapa(Color(0, 0, 0, 0)))
	botao.add_theme_stylebox_override(&"disabled", _chapa(Color(0, 0, 0, 0)))
	botao.add_theme_stylebox_override(&"hover", _chapa(COR_SOBRE))
	botao.add_theme_stylebox_override(&"pressed", _chapa(COR_ESCOLHIDA))


func _chapa(cor: Color) -> StyleBoxFlat:
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = cor
	# Sem canto arredondado e sem borda: a chapa de aco deste jogo e toda de
	# quina viva, e canto redondo aqui denunciaria o tema padrao do Godot.
	fundo.content_margin_left = SEPARACAO_DAS_LINHAS
	fundo.content_margin_right = SEPARACAO_DAS_LINHAS
	return fundo


func _recortar_icone(folha: Texture2D, indice: int) -> AtlasTexture:
	var recorte := AtlasTexture.new()
	recorte.atlas = folha
	recorte.region = Rect2(indice * LADO_ICONE, 0, LADO_ICONE, LADO_ICONE)
	return recorte


func _atualizar_interface() -> void:
	_atalho.visible = not ativo
	_painel.visible = ativo
	if not ativo:
		return
	# Cancelar so se oferece quando ha o que desfazer: um botao sempre aceso
	# sugere que sair por ali custa alguma coisa, e nao custa.
	_cancelar.disabled = _pendentes == 0
	for i: int in _botoes.size():
		_botoes[i].set_pressed_no_signal(i == int(_ferramenta))
		_botoes[i].modulate = Color(1, 1, 1) if i == int(_ferramenta) else Color(0.72, 0.77, 0.84)
