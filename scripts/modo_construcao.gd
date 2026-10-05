extends Node2D
## Modo de construcao da estacao: cursor em celula, ferramentas e camera livre.
##
## O no tambem carrega a interface de jogo que depende do mapa — a dica do
## portao do hangar. Ficou aqui, e nao num no proprio, porque e a mesma pergunta
## em dois modos: o que a celula debaixo do cursor ou do jogador aceita.

## Cores do cursor: a recusa precisa ser visivel sem ler o texto.
const COR_PERMITIDO: Color = Color(0.45, 0.95, 0.6, 0.28)
const COR_RECUSADO: Color = Color(0.95, 0.35, 0.35, 0.26)
const COR_CONTORNO: Color = Color(0.95, 0.98, 1.0, 0.85)

const ZOOM_MINIMO: float = 0.25
const ZOOM_MAXIMO: float = 1.5
const PASSO_ZOOM: float = 1.12
const VELOCIDADE_CAMERA: float = 900.0

## Teto de celulas por arrasto. Sem ele um arrasto distraido com a vista
## afastada aplicaria milhares de celulas de uma vez.
const MAXIMO_POR_ARRASTO: int = 2500

enum Ferramenta { EXPANDIR, PAREDE, PORTA, PORTAO, DEMOLIR }

const FERRAMENTAS: Array = [
	{"nome": "Expandir", "dica": "aumenta a área; o casco nasce ao redor"},
	{"nome": "Parede", "dica": "fecha uma célula de piso"},
	{"nome": "Porta", "dica": "peça de 2 células; botão direito gira"},
	{"nome": "Portão de nave", "dica": "em parede com piso dentro e espaço fora"},
	{"nome": "Demolir", "dica": "desce o mesmo degrau que subiu, e leva o mesmo tempo"},
]

const ICONES: String = "res://assets/interface/ferramentas.png"
const LADO_ICONE: int = 32

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

## Recusa de uma tentativa de verdade, essa sim escrita na barra. Fica ate a
## proxima acao dar certo ou o jogador trocar de ferramenta.
var _mensagem: String = ""

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

var _barra: Control
var _titulo: Label
var _aviso: Label
var _dica_portao: Label
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
	_dica_portao.visible = not ativo and _mapa.ha_portao_perto(_jogador.global_position)
	if not ativo:
		return
	_mover_camera(delta)
	var alvo: Vector2i = _mapa.celula_de(get_global_mouse_position())
	if alvo != _celula:
		_celula = alvo
		_avaliar()
		_atualizar_interface()
		queue_redraw()


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
		if tecla == KEY_TAB or tecla == KEY_B:
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
				# "so encostado na estacao".
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


## Fecha o modo e deixa a planta de pe. A obra so comeca a correr agora: o prazo
## conta do momento em que o jogador bate o martelo, nao de enquanto ele decide.
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
	_mensagem = ""
	_ao_entrar = _mapa.instantaneo()
	_pendentes = 0
	# O prazo da obra corre com o jogo, nao com a planta aberta.
	_mapa.correr_obras(false)
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
	_mensagem = ""
	_pendentes = 0
	_ao_entrar = {}
	_mapa.correr_obras(true)
	_camera_jogador.make_current()
	if _jogador.has_method(&"travar"):
		_jogador.call(&"travar", false)
	_atualizar_interface()
	queue_redraw()


# --- edicao ------------------------------------------------------------------

func _escolher(indice: int) -> void:
	_ferramenta = indice as Ferramenta
	_mensagem = ""
	_avaliar()
	_atualizar_interface()
	queue_redraw()


## Ferramenta de peca pronta: tamanho fixo, sem arrasto e sem remocao pelo botao
## direito. Hoje so a porta, que ocupa exatamente duas celulas.
func _peca_fixa() -> bool:
	return _ferramenta == Ferramenta.PORTA


func _girar() -> void:
	_rotacao = (_rotacao + 1) % MapaEstacao.CARDEAIS.size()
	_mensagem = ""
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
		_mensagem = "área grande demais"
		_atualizar_interface()
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
	_mensagem = _mapa.aplicar(_acao(ferramenta), celulas, do_jogador)
	_pendentes = _mapa.diferencas(_ao_entrar)
	_avaliar()
	_atualizar_interface()
	queue_redraw()


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
		_motivo = "área grande demais"
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

## Contorno preto no texto: a interface fica por cima do mapa, e sem isso o
## cinza do casco come as letras claras.
func _escrever(cor: String) -> Label:
	var rotulo := Label.new()
	rotulo.add_theme_color_override(&"font_color", Color(cor))
	rotulo.add_theme_color_override(&"font_outline_color", Color(0.03, 0.06, 0.12, 0.9))
	rotulo.add_theme_constant_override(&"outline_size", 6)
	return rotulo


func _montar_interface() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Interface"
	camada.layer = 50
	add_child(camada)

	_titulo = _escrever("dbe8f7")
	_titulo.name = "Titulo"
	_titulo.position = Vector2(16, 12)
	camada.add_child(_titulo)

	_dica_portao = _escrever("ffd98a")
	_dica_portao.name = "DicaPortao"
	_dica_portao.text = "E — abrir ou fechar o portão"
	_dica_portao.visible = false
	_dica_portao.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dica_portao.offset_left = -140.0
	_dica_portao.offset_top = -120.0
	camada.add_child(_dica_portao)

	_barra = VBoxContainer.new()
	_barra.name = "Barra"
	_barra.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_barra.offset_top = -164.0
	_barra.offset_left = 16.0
	_barra.offset_right = -16.0
	_barra.offset_bottom = -12.0
	_barra.set(&"theme_override_constants/separation", 6)
	camada.add_child(_barra)

	_aviso = _escrever("ff9f9f")
	_aviso.name = "Aviso"
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_barra.add_child(_aviso)

	var linha := HBoxContainer.new()
	linha.name = "Ferramentas"
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.set(&"theme_override_constants/separation", 8)
	_barra.add_child(linha)

	var decisao := HBoxContainer.new()
	decisao.name = "Decisao"
	decisao.alignment = BoxContainer.ALIGNMENT_CENTER
	decisao.set(&"theme_override_constants/separation", 12)
	_barra.add_child(decisao)

	_confirmar = Button.new()
	_confirmar.name = "Confirmar"
	_confirmar.text = "✔  Confirmar  (Enter)"
	_confirmar.focus_mode = Control.FOCUS_NONE
	_confirmar.custom_minimum_size = Vector2(230, 40)
	_confirmar.pressed.connect(confirmar)
	decisao.add_child(_confirmar)

	_cancelar = Button.new()
	_cancelar.name = "Cancelar"
	_cancelar.text = "✖  Cancelar  (Esc)"
	_cancelar.focus_mode = Control.FOCUS_NONE
	_cancelar.custom_minimum_size = Vector2(230, 40)
	_cancelar.pressed.connect(cancelar)
	decisao.add_child(_cancelar)

	var folha: Texture2D = load(ICONES)
	for i: int in FERRAMENTAS.size():
		var botao := Button.new()
		botao.text = "%d  %s" % [i + 1, FERRAMENTAS[i]["nome"]]
		botao.focus_mode = Control.FOCUS_NONE
		botao.toggle_mode = true
		botao.icon = _recortar_icone(folha, i)
		botao.custom_minimum_size = Vector2(0, 44)
		botao.add_theme_constant_override(&"h_separation", 8)
		botao.pressed.connect(_escolher.bind(i))
		linha.add_child(botao)
		_botoes.append(botao)


func _recortar_icone(folha: Texture2D, indice: int) -> AtlasTexture:
	var recorte := AtlasTexture.new()
	recorte.atlas = folha
	recorte.region = Rect2(indice * LADO_ICONE, 0, LADO_ICONE, LADO_ICONE)
	return recorte


func _atualizar_interface() -> void:
	_barra.visible = ativo
	if not ativo:
		_titulo.text = "TAB — modo construção"
		return
	var atual: Dictionary = FERRAMENTAS[int(_ferramenta)]
	var area: Rect2i = _area()
	var planta: String = "nada alterado ainda"
	if _pendentes == 1:
		planta = "1 célula alterada"
	elif _pendentes > 1:
		planta = "%d células alteradas" % _pendentes
	var manejo: String = "clique aplica 1 célula · arraste aplica o retângulo · direito demole"
	if _peca_fixa():
		manejo = "clique assenta a peça · direito gira 90°"
	_titulo.text = "CONSTRUÇÃO · %s — %s\n%s · roda aproxima · WASD move\n%d × %d em %d, %d · %s" % [
		atual["nome"], atual["dica"], manejo, area.size.x, area.size.y,
		area.position.x, area.position.y, planta,
	]
	_aviso.text = _mensagem
	# Cancelar so se oferece quando ha o que desfazer: um botao sempre aceso
	# sugere que sair por ali custa alguma coisa, e nao custa.
	_cancelar.disabled = _pendentes == 0
	for i: int in _botoes.size():
		_botoes[i].set_pressed_no_signal(i == int(_ferramenta))
		_botoes[i].modulate = Color(1, 1, 1) if i == int(_ferramenta) else Color(0.72, 0.77, 0.84)
