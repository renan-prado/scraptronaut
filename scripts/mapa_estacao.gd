class_name MapaEstacao
extends Node2D
## Mapa da estacao em celulas livres, sem modulo de tamanho fixo.
##
## O modelo guarda so o que foi colocado de proposito: obra, piso, divisoria,
## porta e portao. O casco externo nao e guardado — e derivado a cada
## reconstrucao como o anel de celulas vazias que encostam no interior E
## alcancam o espaco aberto. E isso que deixa a planta livre: quem pinta piso
## ganha parede de graca, e quem apaga piso perde a parede junto.

signal mapa_alterado

enum Tipo { PISO, MURO, PORTA, PORTAO, OBRA }

## Estagios da obra, na ordem. Cada um avanca quando o jogador bate trabalho
## suficiente na celula; o ultimo entrega a peca.
enum Estagio { DEMARCADO, ESTRUTURA, ACABAMENTO }

## Quantos estagios cada peca percorre antes de ficar pronta. Piso nasce do nada
## e precisa de chao: tres. Parede e porta sobem sobre piso que ja existe, entao
## param no ESTRUTURA — demarcar o lugar e erguer a estrutura bastam.
const ESTAGIOS_ATE: Dictionary = {
	Tipo.PISO: 3,
	Tipo.MURO: 2,
	Tipo.PORTA: 2,
	Tipo.PORTAO: 2,
}

## Quanto trabalho cada celula de canteiro custa. A unidade e a MESMA energia
## que o jogador gasta na picareta, e um dia de trabalho e a barra cheia
## (Jogador.ENERGIA_MAXIMA, 100): assim o custo se le direto em quantas celulas
## cabem num dia.
##
## | Alvo    | Por celula | Numa barra cheia              |
## |---------|-----------:|-------------------------------|
## | `PISO`  |       12,5 | **8 quadrados**               |
## | `MURO`  |        5,0 | 20 paredes                    |
## | `PORTA` |       6,25 | 8 portas (a peca tem 2 celulas) |
##
## Os oito quadrados por barra sao o pedido de 2026-10-05, e substituem a
## calibragem anterior, de tres dias para quatro celulas de piso. A diferenca e
## de escala, nao de proporcao: expandir continua sendo a obra cara, parede a
## barata, e uma porta inteira custa o mesmo que um quadrado de chao.
##
## A obra nao corre sozinha. Antes havia relogio, e o prazo passava enquanto o
## jogador fazia outra coisa; agora nada anda sem alguem bater nele.
const TRABALHO_POR_CELULA: Dictionary = {
	Tipo.PISO: 12.5,
	Tipo.MURO: 5.0,
	Tipo.PORTA: 6.25,
	Tipo.PORTAO: 6.25,
}

## Distancia, em celulas, de onde da para bater num canteiro. Pouco menos de
## duas: alcanca os oito vizinhos e a propria celula, e nao alcanca a de tras
## deles — trabalhar a tres celulas de distancia nao parece trabalho.
const ALCANCE_TRABALHO: float = 1.9

## Cosseno do meio-angulo do cone em que a picareta enxerga canteiro: 0,5 e
## sessenta graus para cada lado da vista.
##
## Sessenta, e nao quarenta e cinco, por causa da diagonal: as vistas da folha
## estao a quarenta e cinco graus uma da outra, e com o cone justo um canteiro
## exatamente na diagonal cairia na divisa entre duas vistas e piscaria. Com
## sessenta, quem olha para a direita alcanca o canteiro a nordeste e a sudeste
## — e segue SEM alcancar o que esta ao sul, que e o ponto do pedido.
const COSSENO_DO_ALCANCE: float = 0.5

const CELULA: int = 64

## Ordem dos bits da mascara de vizinhanca. Precisa bater com DIRECOES em
## tools/gerar_tiles_estacao.py: trocar de um lado so embaralha o atlas inteiro
## em silencio, e o resultado ainda parece plausivel na tela.
const DIRECOES: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const CARDEAIS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]

## Indices das fontes do TileSet, na ordem em que tools/construir_estacao.gd
## as adiciona.
const FONTE_PISO: int = 0
const FONTE_BORDA: int = 1
const FONTE_CASCO: int = 2
const FONTE_PORTA: int = 3
const FONTE_PORTAO: int = 4
const FONTE_DETALHE: int = 5
const FONTE_OBRA: int = 6
const FONTE_BURACO: int = 7
const FONTE_DEMARCACAO: int = 8
const FONTE_CONE: int = 9
const FONTE_MARCACAO: int = 10

## Alternativa desenhada enquanto a peca nao fica pronta: mesma arte, apagada e
## translucida. Precisa bater com tools/construir_estacao.gd.
const ALT_EM_OBRA: int = 1

## Alternativa da fita de obra sem colisao, para a porta.
const ALT_MARCACAO_LIVRE: int = 1

const VARIACOES_OBRA: int = 4

const VARIACOES_PISO: int = 4

## Segmentos do atlas de porta, dois por segmento: fechada e aberta. Um vao de
## duas celulas e METADE_A + METADE_B, e so assim a emenda ambar cai na divisa
## entre as duas em vez de aparecer uma em cada celula.
enum SegmentoPorta { INTEIRA, METADE_A, METADE_B, MEIO }

## Colunas do atlas de detalhes. A linha e a orientacao, na ordem de CARDEAIS.
enum Detalhe {
	CANO, CANO_FLANGE, CANO_AMBAR, CANO_CINTA, CANO_PONTA_A, CANO_PONTA_B, CAIXA, LUZ
}

## Peças de miolo de corrida de cano, sorteadas entre as duas pontas.
const MIOLO_DO_CANO: Array[Detalhe] = [
	Detalhe.CANO, Detalhe.CANO, Detalhe.CANO_FLANGE, Detalhe.CANO_CINTA,
]

## Sentido em que uma corrida de parede e percorrida, por orientacao. E a volta
## no sentido horario em torno da estacao, e precisa ser essa: o atlas desenha
## a ponta A do cano a oeste e as outras tres orientacoes saem de rotacoes, o
## que gira junto o lado em que a ponta cai.
const SENTIDO_CORRIDA: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
]

## Quanto da parede externa ganha enfeite. Valores altos poluem: o casco vira
## um emaranhado de cano e a silhueta da estacao se perde.
const CHANCE_CANO: float = 0.8
const CHANCE_CAIXA: float = 0.55
const CHANCE_LUZ: float = 0.22

## Distancia, em celulas, que abre uma porta automatica.
const ALCANCE_PORTA: float = 1.8

## Distancia, em celulas, para o portao aceitar o E.
const ALCANCE_PORTAO: float = 3.0

## Planta inicial da Lastro. Cada retangulo e area util; o casco nasce ao redor
## da uniao de todos. Os retangulos se sobrepoem de proposito — e a sobreposicao
## que produz as salas recortadas da referencia em vez de caixas iguais.
##
## Encolhida em 2026-10-05, a pedido. A topologia e a mesma de antes — seis
## salas ligadas por corredores com porta, portao do hangar a leste — mas a
## caixa util caiu de 44x30 celulas para 30x21, menos da metade da area.
const SALAS_INICIAIS: Array[Rect2i] = [
	Rect2i(2, 2, 6, 7),     # Armazem
	Rect2i(3, 9, 5, 3),     # Armazem, degrau para sudeste
	Rect2i(8, 9, 4, 3),     # Corredor armazem -> patio
	Rect2i(12, 5, 7, 9),    # Patio
	Rect2i(14, 3, 4, 2),    # Patio, saliencia norte
	Rect2i(19, 7, 3, 3),    # Corredor patio -> hangar
	Rect2i(22, 3, 9, 8),    # Hangar
	Rect2i(24, 11, 6, 2),   # Hangar, degrau sul
	Rect2i(12, 14, 3, 3),   # Corredor patio -> oficina
	Rect2i(7, 17, 8, 6),    # Oficina de desmontagem
	Rect2i(16, 14, 3, 3),   # Corredor patio -> prensa
	Rect2i(16, 17, 7, 6),   # Prensa
]

## Divisorias que fecham a boca de cada corredor, deixando so o vao da porta.
const MUROS_INICIAIS: Array[Vector2i] = [
	Vector2i(10, 11),
	Vector2i(20, 9),
	Vector2i(14, 15),
	Vector2i(18, 15),
]

## Portas comuns de duas celulas, como manda docs/Estacao-Lastro-grid-e-modulos.
const PORTAS_INICIAIS: Array[Vector2i] = [
	Vector2i(10, 9), Vector2i(10, 10),
	Vector2i(20, 7), Vector2i(20, 8),
	Vector2i(12, 15), Vector2i(13, 15),
	Vector2i(16, 15), Vector2i(17, 15),
]

## Portao do hangar: cinco celulas na parede leste, como na planta aprovada.
const PORTAO_INICIAL: Array[Vector2i] = [
	Vector2i(31, 5), Vector2i(31, 6), Vector2i(31, 7), Vector2i(31, 8), Vector2i(31, 9),
]

const CELULA_INICIAL_JOGADOR: Vector2i = Vector2i(15, 9)

## Celula da cabeceira da cama. A peca ocupa esta e a de baixo, encostada na
## parede norte do armazem, e e tudo que ha de habitacao na Lastro por enquanto.
## Quem le isto e tools/construir_estacao.gd, que posiciona o no na cena.
const CELULA_DA_CAMA: Vector2i = Vector2i(3, 2)

@onready var _piso: TileMapLayer = $Piso
@onready var _borda: TileMapLayer = $Borda
@onready var _obra: TileMapLayer = $Obra
@onready var _casco: TileMapLayer = $Casco
@onready var _detalhes: TileMapLayer = $Detalhes
@onready var _aberturas: TileMapLayer = $Aberturas

## Celula -> Tipo. So o que foi colocado; o casco fica fora.
var _celulas: Dictionary = {}

## Celula -> bool, para porta e portao. Portas sao reabertas por proximidade a
## cada quadro; portoes guardam o estado ate alguem apertar E de novo.
var _abertos: Dictionary = {}

## Celula -> Estagio, so para as celulas em Tipo.OBRA.
var _estagios: Dictionary = {}

## Celula -> a peca de que o canteiro trata: PISO, MURO, PORTA ou PORTAO. E o
## que define prazo, desenho e colisao. Numa construcao e o que vai ser
## entregue; numa demolicao, o que esta sendo desmontado.
var _alvos: Dictionary = {}

## Canteiros que correm ao contrario. Demolir nao e apagar: a peca desce a mesma
## escada que subiu, degrau por degrau, ate sumir.
var _demolindo: Dictionary = {}

## Canteiros abertos ONDE JA HAVIA PAREDE — o casco que a estacao atravessa ao
## crescer. A parede fica de pe enquanto a obra corre, em vez de a celula sair
## do casco no instante do clique e a baliza aparecer sobre o campo estelar:
## pedir chao onde havia parede abria um buraco para o vacuo, e era so o que
## nao se estava pedindo.
##
## Precisa ser guardado, e nao deduzido depois: o que separa o casco de um vao
## fechado e o preenchimento de fora para dentro de _recalcular_casco, e ele ja
## correu quando chega a hora de desenhar.
var _era_parede: Dictionary = {}

## Trabalho ja batido no estagio atual de cada obra. Nada aqui anda sozinho: so
## sobe quando alguem chama trabalhar(), e e isso que torna o canteiro um lugar
## onde se vai, e nao um prazo que passa.
var _trabalho: Dictionary = {}

var _casco_auto: Dictionary = {}

## Celulas vazias cercadas pela estacao: vaos abertos para o espaco, com parede
## em volta. Nao sao casco macico — e a diferenca entre "a estacao se fechou" e
## "a estacao se fechou EM VOLTA de um vao", que e o que o jogador pediu.
var _buracos: Dictionary = {}
var _portas: Array[Vector2i] = []

## Celulas de porta encostadas formam um vao so, e abrem juntas: uma porta de
## duas celulas abrindo meia folha de cada vez le como defeito.
var _vaos: Array = []
var _jogador: Node2D


func _ready() -> void:
	if _celulas.is_empty():
		carregar_planta_inicial()
	reconstruir()


func _process(_delta: float) -> void:
	_atualizar_portas()


# --- consulta ----------------------------------------------------------------

func tipo_em(celula: Vector2i) -> int:
	return _celulas.get(celula, -1)


## Area util da estacao, para efeito de casco e de sombra de contato. A obra
## entra: o casco nasce junto com o canteiro, para o jogador ver desde o
## primeiro segundo o contorno do que mandou construir.
func eh_interior(celula: Vector2i) -> bool:
	var tipo: int = tipo_em(celula)
	return tipo == Tipo.PISO or tipo == Tipo.PORTA or tipo == Tipo.OBRA


## Onde da para andar. Canteiro de piso e de parede nao entram — tem colisao ate
## o fim — e e por isso que a validacao de ligacao usa esta, e nao eh_interior.
##
## Obra de PORTA entra: porta nao colide nem pronta nem em obra. Se entrasse, pôr
## uma porta num vao de duas celulas fecharia a passagem por vinte segundos e a
## validacao recusaria a propria porta que destrava o canto.
func eh_andavel(celula: Vector2i) -> bool:
	var tipo: int = tipo_em(celula)
	if tipo == Tipo.PISO or tipo == Tipo.PORTA:
		return true
	return tipo == Tipo.OBRA and _alvos.get(celula, Tipo.PISO) == Tipo.PORTA


## Pertence a estacao: inclui o casco derivado, que nao esta em _celulas.
func pertence(celula: Vector2i) -> bool:
	return _celulas.has(celula) or _casco_auto.has(celula)


func eh_casco_automatico(celula: Vector2i) -> bool:
	return _casco_auto.has(celula)


func eh_buraco(celula: Vector2i) -> bool:
	return _buracos.has(celula)


## Celula onde ainda nao ha chao: canteiro de piso, subindo ou descendo. E a
## pergunta que decide onde entram os cones — nao basta "nao e andavel", porque
## parede tambem nao e andavel e nao tem vazio atras.
##
## Vale ate o ACABAMENTO inclusive. A chapa ja esta assentada ali, mas ninguem
## pisa nela enquanto a obra nao entrega: a marca sai quando a celula vira piso.
##
## Canteiro de parede ou de porta nao entra: sobe sobre chao que ja existe, nao
## ha vazio atras dele, e cercar de cone a propria parede nova nao avisa nada.
## Canteiro aberto sobre o casco tambem nao: ali a parede continua de pe, e cone
## apontando para uma parede inteira nao avisa de nada.
func falta_chao(celula: Vector2i) -> bool:
	if _era_parede.has(celula):
		return false
	return tipo_em(celula) == Tipo.OBRA and _alvos.get(celula, Tipo.PISO) == Tipo.PISO


## A peca de que o canteiro desta celula trata. Fora de obra, devolve -1.
func alvo_em(celula: Vector2i) -> int:
	return _alvos.get(celula, -1) if tipo_em(celula) == Tipo.OBRA else -1


## O canteiro desta celula esta desfazendo em vez de erguendo.
func esta_demolindo(celula: Vector2i) -> bool:
	return _demolindo.has(celula)


## Ja e porta ou vai ser. Quem desenha o vao precisa das duas: as duas metades de
## uma porta em obra tem de se reconhecer, senao saem duas portinhas.
func _sera_porta(celula: Vector2i) -> bool:
	if tipo_em(celula) == Tipo.PORTA:
		return true
	return tipo_em(celula) == Tipo.OBRA and _alvos.get(celula, Tipo.PISO) == Tipo.PORTA


func estagio_em(celula: Vector2i) -> int:
	return _estagios.get(celula, -1)


## Vale para porta e para portao: o estado de abertura e o mesmo dicionario.
func esta_aberto(celula: Vector2i) -> bool:
	return _abertos.get(celula, false)


func celula_de(posicao_global: Vector2) -> Vector2i:
	return _piso.local_to_map(_piso.to_local(posicao_global))


func centro_da(celula: Vector2i) -> Vector2:
	return to_global(Vector2(celula) * CELULA + Vector2(CELULA, CELULA) * 0.5)


func posicao_inicial_do_jogador() -> Vector2:
	return centro_da(CELULA_INICIAL_JOGADOR)


# --- planta ------------------------------------------------------------------

func carregar_planta_inicial() -> void:
	_celulas.clear()
	_abertos.clear()
	for sala: Rect2i in SALAS_INICIAIS:
		for y: int in range(sala.position.y, sala.end.y):
			for x: int in range(sala.position.x, sala.end.x):
				_celulas[Vector2i(x, y)] = Tipo.PISO
	for celula: Vector2i in MUROS_INICIAIS:
		_celulas[celula] = Tipo.MURO
	for celula: Vector2i in PORTAS_INICIAIS:
		_celulas[celula] = Tipo.PORTA
	for celula: Vector2i in PORTAO_INICIAL:
		_celulas[celula] = Tipo.PORTAO
		_abertos[celula] = false


# --- edicao ------------------------------------------------------------------

func definir(celula: Vector2i, tipo: Tipo) -> void:
	_celulas[celula] = tipo
	if tipo == Tipo.PORTAO:
		_abertos[celula] = _abertos.get(celula, false)
	reconstruir()


func apagar(celula: Vector2i) -> void:
	_celulas.erase(celula)
	_abertos.erase(celula)
	reconstruir()


## Vazio quer dizer permitido; qualquer outro texto e o motivo da recusa, que o
## modo de construcao mostra na tela.
##
## Estes sao os testes de UMA celula, usados para colorir o cursor. Quem aplica
## de verdade e aplicar(), que trabalha em lote e desfaz tudo se o resultado
## nao servir.
func pode_expandir(celula: Vector2i) -> String:
	# A divisoria e peca posta, e expandir nao varre peca posta. Quem quer chao
	# onde ha parede interna demole a parede: e a Demolir que a devolve em piso.
	if tipo_em(celula) == Tipo.MURO:
		return "parede: demola para virar piso"
	if _celulas.has(celula):
		return "aqui já é estação"
	if not _tem_interior_vizinho(celula):
		return "só encostado na estação"
	return ""


## Parede interna so em piso. Casco externo ja e parede, e marca-lo nao adianta
## nada: parede interna e so a que veio na planta ou a que o jogador ergueu.
func pode_muro(celula: Vector2i, celula_jogador: Vector2i) -> String:
	if celula == celula_jogador:
		return "você está aqui"
	if tipo_em(celula) != Tipo.PISO:
		return "parede só em piso"
	return ""


## Porta entra em parede, mas tambem direto no piso: a celula ja vira o batente.
##
## Sem isso o jogador caia num ciclo — nao podia erguer a parede que fecharia um
## canto, porque isolaria a estacao, e nao podia pôr a porta que resolveria o
## isolamento, porque ali ainda nao havia parede.
##
## Com eixo informado, a passagem e a que a peca escolheu, e nao a que o mapa
## sugere: o jogador gira a porta com o botao direito, e uma porta solta no meio
## da sala tem piso dos quatro lados — sem o eixo ela sairia sempre deitada.
func pode_porta(celula: Vector2i, celula_jogador: Vector2i, eixo := Vector2i.ZERO) -> String:
	var tipo: int = tipo_em(celula)
	if celula == celula_jogador:
		return "você está aqui"
	if tipo == Tipo.PORTA:
		return "já é porta"
	if tipo == Tipo.PORTAO:
		return "remova o portão antes"
	if tipo == Tipo.OBRA:
		return "espere a obra terminar"
	if tipo == -1 and not eh_casco_automatico(celula):
		return "só na estação"
	if eixo == Vector2i.ZERO:
		eixo = _eixo_da_porta(celula)
		if eixo == Vector2i.ZERO:
			return "precisa de piso dos dois lados"
		return ""
	if not eh_interior(celula + eixo) or not eh_interior(celula - eixo):
		return "precisa de piso dos dois lados"
	return ""


func pode_portao(celula: Vector2i) -> String:
	if tipo_em(celula) == Tipo.PORTAO:
		return "já é portão"
	if tipo_em(celula) == Tipo.OBRA:
		return "espere a obra terminar"
	if not eh_casco_automatico(celula) and tipo_em(celula) != Tipo.MURO:
		return "só em parede"
	if _lado_externo(celula) == Vector2i.ZERO:
		return "precisa de piso dentro e espaço fora"
	return ""


## Recusa da peca inteira, sem aplicar nada. O cursor pergunta isto a cada quadro
## e _encomendar_porta pergunta antes de abrir o canteiro, entao a regra da peca
## mora num lugar so.
func pode_porta_em(celulas: Array[Vector2i], do_jogador: Vector2i) -> String:
	if celulas.size() != 2:
		return "a porta ocupa duas células"
	var passo: Vector2i = celulas[1] - celulas[0]
	if not CARDEAIS.has(passo):
		return "as duas células precisam estar encostadas"
	# O vao abre no eixo perpendicular a folha: porta deitada separa norte de
	# sul, porta em pe separa leste de oeste.
	var eixo := Vector2i(0, 1) if passo.x != 0 else Vector2i(1, 0)
	for celula: Vector2i in celulas:
		var recusa: String = pode_porta(celula, do_jogador, eixo)
		if recusa != "":
			return recusa
	return ""


## Demolir desmonta um degrau de cada vez: parede, porta e portao voltam a ser
## piso, e piso abre vacuo. No casco automatico e no vacuo nao acontece nada —
## casco automatico nao e peca, e o desenho que sai dali.
func pode_demolir(celula: Vector2i, celula_jogador: Vector2i) -> String:
	var tipo: int = tipo_em(celula)
	if tipo == -1:
		return "aqui não tem o que demolir"
	if (tipo == Tipo.PISO or tipo == Tipo.OBRA) and celula == celula_jogador:
		return "você está aqui"
	return ""


# --- edicao em lote ----------------------------------------------------------

enum Acao { EXPANDIR, PAREDE, PORTA, PORTAO, DEMOLIR }


## Aplica uma acao a um conjunto de celulas de uma vez so, tudo ou nada.
##
## E em lote porque o modo de construcao trabalha com retangulo: regra por
## celula nao daria conta de "o retangulo inteiro precisa encostar na estacao",
## e um retangulo meio aplicado deixaria a estacao num estado que o jogador nao
## pediu. Devolve vazio quando deu certo, ou o motivo da recusa.
func aplicar(acao: Acao, celulas: Array[Vector2i], do_jogador: Vector2i) -> String:
	var antes: Dictionary = _celulas.duplicate()
	var estagios_antes: Dictionary = _estagios.duplicate()
	var alvos_antes: Dictionary = _alvos.duplicate()
	# O trabalho ja batido tambem volta. Sem isso uma expansao recusada deixava
	# a celula fora do mapa mas com progresso guardado, e a proxima obra no mesmo
	# lugar comecaria adiantada.
	var trabalho_antes: Dictionary = _trabalho.duplicate()
	var demolindo_antes: Dictionary = _demolindo.duplicate()
	var era_parede_antes: Dictionary = _era_parede.duplicate()
	var motivo: String = _executar(acao, celulas, do_jogador)
	if motivo == "":
		motivo = _validar_ligacao(do_jogador)
	if motivo != "":
		_celulas = antes
		_estagios = estagios_antes
		_trabalho = trabalho_antes
		_alvos = alvos_antes
		_demolindo = demolindo_antes
		_era_parede = era_parede_antes
		return motivo
	reconstruir()
	return ""


func _executar(acao: Acao, celulas: Array[Vector2i], do_jogador: Vector2i) -> String:
	match acao:
		Acao.EXPANDIR:
			return _expandir(celulas)
		Acao.PAREDE:
			return _erguer(celulas, do_jogador)
		Acao.PORTA:
			return _encomendar_porta(celulas, do_jogador)
		Acao.PORTAO:
			return _abrir_portao(celulas)
		Acao.DEMOLIR:
			return _demolir(celulas, do_jogador)
	return ""


## Abre canteiro de obra no que ainda e vacuo ou casco. O que ja esta posto de
## proposito — piso, divisoria, porta, portao — sobrevive ao retangulo: um
## arrasto largo nao pode varrer a estacao existente sem querer, e e por isso
## que selecionar area ja construida simplesmente ignora a parte construida.
##
## O canteiro so cresce a partir do que ja existe, mas o teste de encosto e
## refeito a cada rodada: numa selecao larga a segunda fila encosta na primeira,
## a terceira na segunda, e o retangulo inteiro entra de uma vez.
func _expandir(celulas: Array[Vector2i]) -> String:
	var pendentes: Array[Vector2i] = []
	for celula: Vector2i in celulas:
		if not _celulas.has(celula):
			pendentes.append(celula)
	if pendentes.is_empty():
		return "aqui já é estação"

	var abertas: int = 0
	while not pendentes.is_empty():
		var restantes: Array[Vector2i] = []
		var rodada: int = 0
		for celula: Vector2i in pendentes:
			if not _tem_interior_vizinho(celula):
				restantes.append(celula)
				continue
			_abrir_canteiro(celula, Tipo.PISO)
			rodada += 1
		abertas += rodada
		if rodada == 0:
			break
		pendentes = restantes

	if abertas == 0:
		return "só encostado na estação"
	return ""


## Abre canteiro numa celula, dizendo de que peca ele trata e para que lado
## corre. Construcao parte do primeiro degrau; demolicao, do ultimo.
func _abrir_canteiro(celula: Vector2i, alvo: Tipo, demolindo: bool = false) -> void:
	# Antes de escrever a celula: depois dela nao ha mais como saber o que havia
	# ali, e o casco nao esta em _celulas para ser consultado adiante.
	if eh_casco_automatico(celula):
		_era_parede[celula] = true
	else:
		_era_parede.erase(celula)
	_celulas[celula] = Tipo.OBRA
	_alvos[celula] = alvo
	_estagios[celula] = (int(ESTAGIOS_ATE[alvo]) - 1) if demolindo else int(Estagio.DEMARCADO)
	_trabalho[celula] = 0.0
	if demolindo:
		_demolindo[celula] = true
	else:
		_demolindo.erase(celula)


## Fecha o canteiro entregando o resultado. Construcao vira a peca; demolicao
## devolve o piso, ou vacuo quando o que saiu foi o proprio chao.
func _concluir_canteiro(celula: Vector2i) -> void:
	var alvo: int = _alvos.get(celula, Tipo.PISO)
	if not _demolindo.has(celula):
		_celulas[celula] = alvo
	elif alvo == Tipo.PISO:
		_celulas.erase(celula)
		_abertos.erase(celula)
	else:
		_celulas[celula] = Tipo.PISO
		_abertos.erase(celula)
	_esquecer_canteiro(celula)


## Interrompe o canteiro e devolve a celula ao estado anterior a ele. Demolicao
## cancelada recompoe a peca inteira; construcao cancelada tira o que nem
## chegou a existir.
func _cancelar_canteiro(celula: Vector2i) -> void:
	var alvo: int = _alvos.get(celula, Tipo.PISO)
	if _demolindo.has(celula):
		_celulas[celula] = alvo
	elif alvo == Tipo.PISO:
		_celulas.erase(celula)
		_abertos.erase(celula)
	else:
		_celulas[celula] = Tipo.PISO
		_abertos.erase(celula)
	_esquecer_canteiro(celula)


func _esquecer_canteiro(celula: Vector2i) -> void:
	_alvos.erase(celula)
	_estagios.erase(celula)
	_trabalho.erase(celula)
	_demolindo.erase(celula)
	_era_parede.erase(celula)


func _erguer(celulas: Array[Vector2i], do_jogador: Vector2i) -> String:
	var feito: int = 0
	for celula: Vector2i in celulas:
		if celula == do_jogador or tipo_em(celula) != Tipo.PISO:
			continue
		_abrir_canteiro(celula, Tipo.MURO)
		feito += 1
	if feito == 0:
		return "parede só em piso"
	return ""


## A porta e peca de duas celulas, nao pincel.
##
## A regra mora aqui, e nao so no cursor, porque meia porta nao fecha vao nenhum
## e duas metades soltas em pontos diferentes nao sao porta: quem chamar com
## outra coisa leva recusa, inclusive teste e captura.
func _encomendar_porta(celulas: Array[Vector2i], do_jogador: Vector2i) -> String:
	var recusa: String = pode_porta_em(celulas, do_jogador)
	if recusa != "":
		return recusa
	for celula: Vector2i in celulas:
		_abrir_canteiro(celula, Tipo.PORTA)
	return ""


func _abrir_portao(celulas: Array[Vector2i]) -> String:
	var feito: int = 0
	var motivo: String = ""
	for celula: Vector2i in celulas:
		var recusa: String = pode_portao(celula)
		if recusa != "":
			if motivo == "":
				motivo = recusa
			continue
		_celulas[celula] = Tipo.PORTAO
		_abertos[celula] = _abertos.get(celula, false)
		feito += 1
	if feito == 0:
		return motivo if motivo != "" else "nada aqui aceita isso"
	return ""


## Demolir e a obra ao contrario: a peca desce a mesma escada que subiu, e so no
## ultimo degrau some. Parede, porta e portao param no piso; o piso abre vacuo.
## Nunca constroi nada — piso demolido no meio da sala vira furo aberto para o
## espaco, nao parede.
##
## Sobre um canteiro, demolir CANCELA o trabalho em vez de abrir outro: nao faz
## sentido desmontar degrau por degrau o que ainda nao foi montado, e e assim
## que o jogador interrompe tambem uma demolicao de que se arrependeu.
func _demolir(celulas: Array[Vector2i], do_jogador: Vector2i) -> String:
	var feito: int = 0
	for celula: Vector2i in celulas:
		var tipo: int = tipo_em(celula)
		if tipo == -1:
			continue
		if (tipo == Tipo.PISO or tipo == Tipo.OBRA) and celula == do_jogador:
			continue
		if tipo == Tipo.OBRA:
			_cancelar_canteiro(celula)
		else:
			_abrir_canteiro(celula, tipo as Tipo, true)
		feito += 1
	if feito == 0:
		if celulas.has(do_jogador):
			return "você está aqui"
		return "aqui não tem o que demolir"
	return ""


## Depois de qualquer edicao, todo o chao andavel precisa continuar alcancavel a
## pe a partir do jogador. E o que impede fechar a sala em que se esta e perder
## o resto da estacao do outro lado de uma parede.
##
## Obra fica de fora porque ainda tem colisao: um canteiro novo nao conta como
## caminho, e tambem nao conta como pedaco ilhado enquanto nao vira piso.
func _validar_ligacao(do_jogador: Vector2i) -> String:
	if not eh_andavel(do_jogador):
		return "você ficaria fora da estação"

	var alvo: int = 0
	for celula: Vector2i in _celulas:
		if eh_andavel(celula):
			alvo += 1

	var vistos: Dictionary = {do_jogador: true}
	var fila: Array[Vector2i] = [do_jogador]
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_back()
		for direcao: Vector2i in CARDEAIS:
			var vizinho: Vector2i = atual + direcao
			if vistos.has(vizinho) or not eh_andavel(vizinho):
				continue
			vistos[vizinho] = true
			fila.append(vizinho)
	if vistos.size() != alvo:
		return "isolaria parte da estação"
	return ""


# --- desfazer ----------------------------------------------------------------

## Copia de tudo que o jogador pode editar. O modo de construcao guarda uma ao
## entrar: enquanto a planta nao e confirmada, nada foi gasto e tudo volta.
func instantaneo() -> Dictionary:
	return {
		"celulas": _celulas.duplicate(),
		"abertos": _abertos.duplicate(),
		"estagios": _estagios.duplicate(),
		"trabalho": _trabalho.duplicate(),
		"alvos": _alvos.duplicate(),
		"demolindo": _demolindo.duplicate(),
		"era_parede": _era_parede.duplicate(),
	}


func restaurar(estado: Dictionary) -> void:
	_celulas = (estado["celulas"] as Dictionary).duplicate()
	_abertos = (estado["abertos"] as Dictionary).duplicate()
	_estagios = (estado["estagios"] as Dictionary).duplicate()
	_trabalho = (estado["trabalho"] as Dictionary).duplicate()
	_alvos = (estado["alvos"] as Dictionary).duplicate()
	_demolindo = (estado["demolindo"] as Dictionary).duplicate()
	_era_parede = (estado["era_parede"] as Dictionary).duplicate()
	reconstruir()


## Quantas celulas mudaram desde o instantaneo. E o numero que a barra mostra,
## para o jogador saber o que o cancelamento desfaz antes de apertar.
func diferencas(estado: Dictionary) -> int:
	var antes: Dictionary = estado["celulas"]
	var total: int = 0
	for celula: Vector2i in _celulas:
		if antes.get(celula, -1) != _celulas[celula]:
			total += 1
	for celula: Vector2i in antes:
		if not _celulas.has(celula):
			total += 1
	return total


# --- obras -------------------------------------------------------------------

## Quanto trabalho um estagio desta peca custa. Os estagios de uma peca custam o
## mesmo: dividir o custo igualmente e o que faz a barra de progresso andar
## parelha, e nao ha razao de desenho para o acabamento custar diferente da
## demarcacao.
func trabalho_por_estagio(alvo: int) -> float:
	var degraus: int = int(ESTAGIOS_ATE.get(alvo, 1))
	return float(TRABALHO_POR_CELULA.get(alvo, 0.0)) / maxf(float(degraus), 1.0)


## Bate `quanto` de trabalho no canteiro desta celula e devolve quanto foi
## realmente consumido.
##
## Devolve o consumo, e nao true/false, porque quem chama paga em energia: na
## ultima martelada sobra trabalho, e cobrar a sobra tiraria energia por um
## canteiro que ja nao existe. Uma celula pode fechar mais de um estagio numa
## chamada so — e o que mantem o custo honesto se alguem bater muito de uma vez.
func trabalhar(celula: Vector2i, quanto: float) -> float:
	if quanto <= 0.0 or tipo_em(celula) != Tipo.OBRA:
		return 0.0
	var por_estagio: float = trabalho_por_estagio(_alvos.get(celula, Tipo.PISO))
	if por_estagio <= 0.0:
		return 0.0

	var sobra: float = quanto
	var mudou: bool = false
	while sobra > 0.0 and tipo_em(celula) == Tipo.OBRA:
		var falta: float = por_estagio - float(_trabalho.get(celula, 0.0))
		if sobra < falta:
			_trabalho[celula] = float(_trabalho.get(celula, 0.0)) + sobra
			sobra = 0.0
			break
		sobra -= falta
		mudou = true
		_fechar_estagio(celula)
	if mudou:
		reconstruir()
	return quanto - sobra


## Fecha um degrau da escada. Construcao sobe, demolicao desce, e no fim da
## escada o canteiro entrega.
func _fechar_estagio(celula: Vector2i) -> void:
	var alvo: int = _alvos.get(celula, Tipo.PISO)
	var passo: int = -1 if _demolindo.has(celula) else 1
	var estagio: int = _estagios.get(celula, Estagio.DEMARCADO) + passo
	var acabou: bool = estagio < 0 if passo < 0 else estagio >= int(ESTAGIOS_ATE[alvo])
	if acabou:
		_concluir_canteiro(celula)
		return
	_estagios[celula] = estagio
	_trabalho[celula] = 0.0


## Quanto do canteiro ja esta feito, de 0 a 1, contando os estagios fechados e o
## pedaco do estagio corrente. E o que a barra de obra mostra enquanto se bate.
func progresso_em(celula: Vector2i) -> float:
	if tipo_em(celula) != Tipo.OBRA:
		return 0.0
	var alvo: int = _alvos.get(celula, Tipo.PISO)
	var degraus: int = int(ESTAGIOS_ATE[alvo])
	var estagio: int = _estagios.get(celula, Estagio.DEMARCADO)
	# Numa demolicao a escada e percorrida ao contrario: o degrau de cima e o
	# comeco, e o progresso e o quanto ja se desceu.
	var fechados: float = float(degraus - 1 - estagio) if _demolindo.has(celula) else float(estagio)
	var dentro: float = float(_trabalho.get(celula, 0.0)) / trabalho_por_estagio(alvo)
	return clampf((fechados + dentro) / float(degraus), 0.0, 1.0)


## Canteiro em que a picareta bate: o que esta debaixo dos pes, ou o mais bem
## alinhado com `rumo` dentro do alcance de braco. Devolve a celula do proprio
## ponto quando nao ha nenhum — quem chama confere com tipo_em(), como faz o no
## de trabalho.
##
## Era o mais PERTO, e o mais perto nao se controla. Com um canteiro ao sul e
## outro a leste, a escolha saia do meio pixel em que o jogador tinha parado, e
## virar-se para o que ele queria nao mudava nada. A vista e o unico comando que
## ele tem na mao — empurrar o personagem contra a peca o vira sem tira-lo do
## lugar — entao e ela que escolhe.
##
## O desempate e por distancia, e so entre alinhamentos iguais: duas celulas
## igualmente na mira sao duas celulas em fila, e a de tras nao se alcanca.
##
## `rumo` zerado volta ao criterio antigo, e e o que a captura de tela usa: ela
## posiciona o jogador e nao tem vista para informar.
func canteiro_perto(posicao_global: Vector2, rumo: Vector2 = Vector2.ZERO) -> Vector2i:
	var aqui: Vector2i = celula_de(posicao_global)
	# Canteiro debaixo dos pes dispensa mira: so o de porta e pisavel, e quem
	# esta em cima dele esta trabalhando nele.
	if tipo_em(aqui) == Tipo.OBRA:
		return aqui

	var mira: bool = rumo != Vector2.ZERO
	var achado: Vector2i = aqui
	var melhor: float = -2.0
	var menor: float = ALCANCE_TRABALHO * CELULA
	for celula: Vector2i in _celulas:
		if _celulas[celula] != Tipo.OBRA:
			continue
		var para_la: Vector2 = centro_da(celula) - posicao_global
		var distancia: float = para_la.length()
		if distancia >= ALCANCE_TRABALHO * CELULA:
			continue
		var alinhamento: float = rumo.dot(para_la / distancia) if mira else 0.0
		if mira and alinhamento < COSSENO_DO_ALCANCE:
			continue
		if alinhamento < melhor or (alinhamento == melhor and distancia >= menor):
			continue
		melhor = alinhamento
		menor = distancia
		achado = celula
	return achado


## Congela toda obra pendente num estagio. Existe para os testes e para a
## captura de tela poderem ver cada etapa sem bater celula por celula.
func forcar_estagio(estagio: Estagio) -> void:
	for celula: Vector2i in _trabalho:
		var ultimo: int = int(ESTAGIOS_ATE[_alvos.get(celula, Tipo.PISO)]) - 1
		_estagios[celula] = mini(int(estagio), ultimo) as Estagio
		_trabalho[celula] = 0.0
	reconstruir()


## Fecha um degrau de toda obra pendente. Existe para o teste poder percorrer a
## escada sem simular o jogador batendo em cada celula.
func avancar_um_estagio() -> void:
	for celula: Vector2i in _trabalho.keys():
		_fechar_estagio(celula)
	reconstruir()


## Termina toda obra pendente na hora. Existe para os testes e para a captura de
## tela nao precisarem percorrer a escada inteira.
func concluir_obras() -> void:
	for celula: Vector2i in _trabalho.keys():
		_concluir_canteiro(celula)
	reconstruir()


func alternar_portao_perto(posicao_global: Vector2) -> bool:
	var origem: Vector2 = posicao_global
	var melhor: Vector2i = Vector2i.ZERO
	var menor: float = ALCANCE_PORTAO * CELULA
	var achou: bool = false
	for celula: Vector2i in _celulas:
		if _celulas[celula] != Tipo.PORTAO:
			continue
		var distancia: float = origem.distance_to(centro_da(celula))
		if distancia < menor:
			menor = distancia
			melhor = celula
			achou = true
	if not achou:
		return false
	var grupo: Array[Vector2i] = _grupo_contiguo(melhor, Tipo.PORTAO)
	var novo: bool = not _abertos.get(melhor, false)
	for celula: Vector2i in grupo:
		_abertos[celula] = novo
	reconstruir()
	return true


func ha_portao_perto(posicao_global: Vector2) -> bool:
	for celula: Vector2i in _celulas:
		if _celulas[celula] != Tipo.PORTAO:
			continue
		if posicao_global.distance_to(centro_da(celula)) < ALCANCE_PORTAO * CELULA:
			return true
	return false


# --- desenho -----------------------------------------------------------------

func reconstruir() -> void:
	_recalcular_casco()
	_piso.clear()
	_borda.clear()
	_obra.clear()
	_casco.clear()
	_detalhes.clear()
	_aberturas.clear()
	_portas.clear()
	_vaos.clear()

	for celula: Vector2i in _celulas:
		match _celulas[celula] as Tipo:
			Tipo.PISO:
				_pintar_piso(celula)
			Tipo.PORTA:
				_pintar_piso(celula)
				_portas.append(celula)
				_pintar_porta(celula)
			Tipo.PORTAO:
				_pintar_portao(celula)
			Tipo.MURO:
				_pintar_casco(celula)
			Tipo.OBRA:
				_pintar_obra(celula)

	for celula: Vector2i in _casco_auto:
		_pintar_casco(celula)

	for celula: Vector2i in _buracos:
		_pintar_buraco(celula)

	for celula: Vector2i in _celulas:
		if eh_interior(celula):
			_pintar_borda(celula)

	_agrupar_vaos()
	_pintar_cones()
	_pintar_detalhes()
	mapa_alterado.emit()


func _agrupar_vaos() -> void:
	var vistas: Dictionary = {}
	for celula: Vector2i in _portas:
		if vistas.has(celula):
			continue
		var grupo: Array[Vector2i] = _grupo_contiguo(celula, Tipo.PORTA)
		for membro: Vector2i in grupo:
			vistas[membro] = true
		_vaos.append(grupo)


## Casco e buracos saem do mesmo passo. Toda celula vazia encostada no interior
## e candidata a parede; as que **alcançam o espaco aberto** viram casco macico,
## e as cercadas pela estacao viram buraco — vao aberto para o espaco, com
## parede em volta. Um flood-fill de fora para dentro decide qual e qual.
##
## A diferenca entre os dois e so o desenho, e ela importa: casco macico no meio
## da sala le como bloco que nasceu do nada, e vao sem parede le como obra que
## travou. O buraco e as duas coisas na medida certa — a estacao se fechou EM
## VOLTA do vao.
func _recalcular_casco() -> void:
	_casco_auto.clear()
	_buracos.clear()

	var candidatas: Dictionary = {}
	for celula: Vector2i in _celulas:
		if not eh_interior(celula):
			continue
		for direcao: Vector2i in DIRECOES:
			var alvo: Vector2i = celula + direcao
			if not _celulas.has(alvo):
				candidatas[alvo] = true
	if candidatas.is_empty():
		return

	for celula: Vector2i in _alcancadas_de_fora(candidatas):
		_casco_auto[celula] = true
	for celula: Vector2i in candidatas:
		if not _casco_auto.has(celula):
			_buracos[celula] = true


## Preenchimento a partir de um canto fora de tudo, andando so por celulas que
## nao sao da estacao. Devolve as candidatas que o preenchimento tocou.
func _alcancadas_de_fora(candidatas: Dictionary) -> Array[Vector2i]:
	var caixa: Rect2i = Rect2i(_celulas.keys()[0], Vector2i.ONE)
	for celula: Vector2i in _celulas:
		caixa = caixa.expand(celula).expand(celula + Vector2i.ONE)
	for celula: Vector2i in candidatas:
		caixa = caixa.expand(celula).expand(celula + Vector2i.ONE)
	caixa = caixa.grow(1)

	var inicio: Vector2i = caixa.position
	var vistos: Dictionary = {inicio: true}
	var fila: Array[Vector2i] = [inicio]
	var achadas: Array[Vector2i] = []
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_back()
		if candidatas.has(atual):
			achadas.append(atual)
		for direcao: Vector2i in CARDEAIS:
			var vizinho: Vector2i = atual + direcao
			if vistos.has(vizinho) or not caixa.has_point(vizinho):
				continue
			if _celulas.has(vizinho):
				continue
			vistos[vizinho] = true
			fila.append(vizinho)
	return achadas


func _pintar_piso(celula: Vector2i) -> void:
	# Variacao por hash da coordenada: a mesma celula cai sempre na mesma
	# variacao, entao reconstruir no meio de uma obra nao faz o chao piscar.
	var indice: int = posmod(celula.x * 7 + celula.y * 13, VARIACOES_PISO * VARIACOES_PISO)
	_piso.set_cell(celula, FONTE_PISO, Vector2i(indice % VARIACOES_PISO, indice / VARIACOES_PISO))


func _pintar_borda(celula: Vector2i) -> void:
	var mascara: int = 255 ^ _mascara(celula, func(c: Vector2i) -> bool: return eh_interior(c))
	if mascara == 0:
		return
	_borda.set_cell(celula, FONTE_BORDA, Vector2i(mascara % 16, mascara / 16))


func _pintar_casco(celula: Vector2i, em_obra: bool = false) -> void:
	var mascara: int = 255 ^ _mascara(celula, func(c: Vector2i) -> bool: return pertence(c))
	var alternativa: int = ALT_EM_OBRA if em_obra or _nasceu_da_obra(celula) else 0
	_casco.set_cell(celula, FONTE_CASCO, Vector2i(mascara % 16, mascara / 16), alternativa)


## Parede que so existe por causa de um canteiro de piso ainda aberto: encosta
## nele e em nenhum chao pronto. Enquanto a obra corre ela e desenhada apagada,
## porque a parede sobe junto com o chao — mostra-la pronta em volta de uma area
## que ainda era so baliza foi o que ficou estranho na primeira versao.
func _nasceu_da_obra(celula: Vector2i) -> bool:
	var tem_obra: bool = false
	for direcao: Vector2i in DIRECOES:
		var vizinho: Vector2i = celula + direcao
		match tipo_em(vizinho):
			Tipo.OBRA:
				if _alvos.get(vizinho, Tipo.PISO) == Tipo.PISO:
					tem_obra = true
			Tipo.PISO, Tipo.PORTA:
				return false
	return tem_obra


## O buraco e indexado so pelos quatro lados: a parede nasce onde o vao encosta
## na estacao, e segue aberto onde encosta noutro buraco.
func _pintar_buraco(celula: Vector2i) -> void:
	var mascara: int = 0
	for i: int in CARDEAIS.size():
		if pertence(celula + CARDEAIS[i]):
			mascara |= 1 << i
	_casco.set_cell(celula, FONTE_BURACO, Vector2i(mascara, 0))


func _pintar_obra(celula: Vector2i) -> void:
	if _alvos.get(celula, Tipo.PISO) == Tipo.PISO:
		_pintar_canteiro(celula)
		return
	_pintar_peca_em_obra(celula)


## Canteiro de chao novo, aberto para o espaco.
##
## O primeiro estagio nao sai do mesmo atlas que os outros: a baliza e indexada
## pela vizinhanca, como o casco, para o trilho ambar correr so na divisa do
## canteiro em vez de cercar celula por celula.
func _pintar_canteiro(celula: Vector2i) -> void:
	var estagio: int = _estagios.get(celula, Estagio.DEMARCADO)
	if _era_parede.has(celula):
		_pintar_canteiro_no_casco(celula, estagio)
		return
	if estagio == Estagio.DEMARCADO:
		var vizinhanca: Callable = func(c: Vector2i) -> bool: return eh_interior(c)
		var mascara: int = 255 ^ _mascara(celula, vizinhanca)
		_obra.set_cell(celula, FONTE_DEMARCACAO, Vector2i(mascara % 16, mascara / 16))
		return
	var variacao: int = posmod(celula.x * 5 + celula.y * 11, VARIACOES_OBRA)
	_obra.set_cell(celula, FONTE_OBRA, Vector2i(variacao, estagio - 1))


## Canteiro aberto sobre o casco: a estacao cresce ATRAVESSANDO a parede, e a
## parede fica de pe ate o chao novo ser entregue.
##
## Sem isto a celula saia do casco no clique e o primeiro estagio era a baliza
## sobre o campo estelar: pedir piso onde havia parede abria um buraco para o
## vacuo, que e o contrario do que se pediu. A parede nunca desaparece de uma
## vez — ela some pelo mesmo caminho que o casco novo usa para aparecer:
##
## | Estagio      | O que se ve                                          |
## |--------------|------------------------------------------------------|
## | `DEMARCADO`  | a parede inteira, com a fita de obra por cima        |
## | `ESTRUTURA`  | a chapa ja assentada, vista ATRAVES da parede que cai |
## | `ACABAMENTO` | a parede caiu, e so a chapa crua fica                |
##
## A chapa entra por baixo ja no segundo degrau porque Obra desenha ANTES de
## Casco. Sem ela a parede translucida ficava sobre o campo estelar e lia como
## o mesmo buraco de antes, so que de porta entreaberta — foi o que a primeira
## captura mostrou. Com a chapa atras, translucido le como o que e: parede
## vindo abaixo sobre chao que ja esta posto.
##
## O casco novo, uma celula adiante, corre ao contrario: nasce translucido em
## _nasceu_da_obra e so fecha quando o canteiro entrega. Translucido quer dizer
## "em transito" nos dois sentidos, e nenhum dos dois momentos abre vao.
func _pintar_canteiro_no_casco(celula: Vector2i, estagio: int) -> void:
	if estagio > int(Estagio.DEMARCADO):
		var variacao: int = posmod(celula.x * 5 + celula.y * 11, VARIACOES_OBRA)
		_obra.set_cell(celula, FONTE_OBRA, Vector2i(variacao, int(Estagio.ACABAMENTO) - 1))
	if estagio < int(Estagio.ACABAMENTO):
		_pintar_casco(celula, estagio == int(Estagio.ESTRUTURA))
	# A fita vai em Detalhes, por cima, e sem colisao: quem barra aqui e a
	# propria parede, ou a chapa do ultimo estagio.
	_detalhes.set_cell(celula, FONTE_MARCACAO,
		Vector2i(_mascara_da_obra_no_casco(celula), 1), ALT_MARCACAO_LIVRE)


## Lados em que a fita fecha a volta da obra no casco. Vizinho que e a MESMA
## obra nao conta: uma expansao de seis celulas sai com uma fita so em volta das
## seis. Marca por celula vira papel de parede, que foi o que o jogador recusou
## na baliza.
func _mascara_da_obra_no_casco(celula: Vector2i) -> int:
	var mascara: int = 0
	for i: int in CARDEAIS.size():
		if not _era_parede.has(celula + CARDEAIS[i]):
			mascara |= 1 << i
	return mascara


## Parede ou porta em obra. As duas sobem sobre chao que ja existe, entao o piso
## continua desenhado por baixo; o que muda e o que vem em cima.
##
## No DEMARCADO e a fita no chao, e so; no ESTRUTURA e a propria peca, apagada e
## translucida — a mesma linguagem do casco que nasce de um canteiro. Desenhar
## uma arte intermediaria so para esta fase custaria dois atlas novos e diria a
## mesma coisa.
func _pintar_peca_em_obra(celula: Vector2i) -> void:
	_pintar_piso(celula)
	var alvo: int = _alvos.get(celula, Tipo.MURO)
	var mascara: int = _mascara_da_marcacao(celula)
	if _estagios.get(celula, Estagio.DEMARCADO) == Estagio.DEMARCADO:
		# So a fita de parede colide; a de porta usa a alternativa livre.
		var livre: int = ALT_MARCACAO_LIVRE if alvo == Tipo.PORTA else 0
		_obra.set_cell(celula, FONTE_MARCACAO, Vector2i(mascara, 0), livre)
		return
	if alvo == Tipo.PORTA:
		_pintar_porta(celula, true)
	else:
		# A parede meio erguida e a mesma grade de vigas do canteiro de piso: e
		# estrutura antes de chapa, que e exatamente o que esta acontecendo.
		# Desenha-la como a parede pronta, so que apagada, nao funciona sobre
		# piso — o bloco escuro da parede interna fica igual a sombra da fita.
		var variacao: int = posmod(celula.x * 5 + celula.y * 11, VARIACOES_OBRA)
		_obra.set_cell(celula, FONTE_OBRA, Vector2i(variacao, 0))
	# A fita continua, agora por cima. A peca apagada sozinha le como peca
	# escura, nao como obra — foi o que apareceu na primeira captura. Vai em
	# Detalhes, que desenha depois do casco e nao colide: quem barra aqui e a
	# propria parede.
	_detalhes.set_cell(celula, FONTE_MARCACAO, Vector2i(mascara, 1), ALT_MARCACAO_LIVRE)


## Lados da celula que nao pertencem a mesma marcacao. E o que faz uma parede de
## seis celulas sair com uma fita so em volta das seis, e nao com seis
## quadradinhos em fila. Canteiro de piso nao conta: e outra obra.
func _mascara_da_marcacao(celula: Vector2i) -> int:
	var mascara: int = 0
	for i: int in CARDEAIS.size():
		var alvo: int = alvo_em(celula + CARDEAIS[i])
		if alvo == -1 or alvo == Tipo.PISO:
			mascara |= 1 << i
	return mascara


## Cone e faixa de perigo no piso que encosta no vazio. A colisao ja barra a
## passagem, mas colisao nao avisa: sem a marca o jogador so descobre o rombo
## esbarrando nele.
func _pintar_cones() -> void:
	for celula: Vector2i in _celulas:
		if _celulas[celula] != Tipo.PISO:
			continue
		var mascara: int = 0
		for i: int in CARDEAIS.size():
			if falta_chao(celula + CARDEAIS[i]):
				mascara |= 1 << i
		if mascara != 0:
			_detalhes.set_cell(celula, FONTE_CONE, Vector2i(mascara, 0))


func _pintar_porta(celula: Vector2i, em_obra: bool = false) -> void:
	var linha: int = linha_da_porta(celula)
	# Para onde fica a metade B do vao. Na linha 0 e o leste; a linha 1 sai de
	# um giro anti-horario do atlas, que leva o leste para o norte.
	var para_b: Vector2i = Vector2i(1, 0) if linha == 0 else Vector2i(0, -1)
	var tem_b: bool = _sera_porta(celula + para_b)
	var tem_a: bool = _sera_porta(celula - para_b)

	var segmento: int = SegmentoPorta.INTEIRA
	if tem_a and tem_b:
		segmento = SegmentoPorta.MEIO
	elif tem_b:
		segmento = SegmentoPorta.METADE_A
	elif tem_a:
		segmento = SegmentoPorta.METADE_B

	var coluna: int = segmento * 2 + (1 if _abertos.get(celula, false) else 0)
	var alternativa: int = ALT_EM_OBRA if em_obra else 0
	_aberturas.set_cell(celula, FONTE_PORTA, Vector2i(coluna, linha), alternativa)


## Linha do atlas da porta: 0 deitada (folha correndo leste-oeste, passagem
## norte-sul), 1 em pe.
##
## A metade vizinha manda, e so na falta dela o eixo e lido do mapa. Uma porta
## solta no meio da sala tem piso dos quatro lados, e o mapa sempre responderia
## "deitada" — a porta em pe que o jogador girou sairia desenhada atravessada.
func linha_da_porta(celula: Vector2i) -> int:
	if _sera_porta(celula + Vector2i(1, 0)) or _sera_porta(celula + Vector2i(-1, 0)):
		return 0
	if _sera_porta(celula + Vector2i(0, 1)) or _sera_porta(celula + Vector2i(0, -1)):
		return 1
	return 0 if _eixo_da_porta(celula) == Vector2i(0, 1) else 1


func _pintar_portao(celula: Vector2i) -> void:
	var fora: Vector2i = _lado_externo(celula)
	if fora == Vector2i.ZERO:
		fora = Vector2i(0, -1)
	var coluna: int = CARDEAIS.find(fora)
	var linha: int = 1 if _abertos.get(celula, false) else 0
	_aberturas.set_cell(celula, FONTE_PORTAO, Vector2i(coluna, linha))


# --- enfeites do casco -------------------------------------------------------

## Celulas de parede com exatamente um lado virado para o espaco, mapeadas para
## esse lado. Canto fica de fora de proposito: cano em canto exigiria curva, e
## sem ela a tubulacao atravessaria a propria parede.
func _faces_retas() -> Dictionary:
	var faces: Dictionary = {}
	var candidatas: Array[Vector2i] = []
	for celula: Vector2i in _casco_auto:
		candidatas.append(celula)
	for celula: Vector2i in _celulas:
		if _celulas[celula] == Tipo.MURO:
			candidatas.append(celula)

	for celula: Vector2i in candidatas:
		# Parede que ainda nasceu da obra fica sem cano: tubulacao parafusada
		# numa parede que o jogador ve as estrelas atraves nega o proprio aviso
		# de que ali ainda e canteiro. O enfeite entra quando a obra fecha.
		if _nasceu_da_obra(celula):
			continue
		var fora: int = -1
		var quantos: int = 0
		for i: int in CARDEAIS.size():
			if not pertence(celula + CARDEAIS[i]):
				quantos += 1
				fora = i
		if quantos == 1:
			faces[celula] = fora
	return faces


func _pintar_detalhes() -> void:
	var faces: Dictionary = _faces_retas()
	var visitadas: Dictionary = {}
	for celula: Vector2i in faces:
		if visitadas.has(celula):
			continue
		var orientacao: int = faces[celula]
		var passo: Vector2i = SENTIDO_CORRIDA[orientacao]

		var inicio: Vector2i = celula
		while faces.get(inicio - passo, -1) == orientacao:
			inicio -= passo

		var corrida: Array[Vector2i] = []
		var atual: Vector2i = inicio
		while faces.get(atual, -1) == orientacao:
			visitadas[atual] = true
			corrida.append(atual)
			atual += passo
		_decorar(corrida, orientacao)


## Semente estavel por corrida: a mesma parede ganha sempre a mesma tubulacao,
## entao reconstruir no meio de uma obra nao remexe o resto da estacao.
func _semente(celula: Vector2i) -> int:
	return absi(celula.x * 73856093 ^ celula.y * 19349663)


func _decorar(corrida: Array[Vector2i], orientacao: int) -> void:
	var total: int = corrida.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = _semente(corrida[0])
	var ocupadas: Dictionary = {}

	if total >= 4 and rng.randf() < CHANCE_CANO:
		var comprimento: int = rng.randi_range(3, mini(total, 7))
		var comeco: int = rng.randi_range(0, total - comprimento)
		var ambar: int = rng.randi_range(1, comprimento - 2) if comprimento >= 4 else -1
		for i: int in comprimento:
			var variante: int = Detalhe.CANO
			if i == 0:
				variante = Detalhe.CANO_PONTA_A
			elif i == comprimento - 1:
				variante = Detalhe.CANO_PONTA_B
			elif i == ambar:
				variante = Detalhe.CANO_AMBAR
			else:
				variante = MIOLO_DO_CANO[rng.randi_range(0, MIOLO_DO_CANO.size() - 1)]
			ocupadas[comeco + i] = true
			_detalhes.set_cell(corrida[comeco + i], FONTE_DETALHE, Vector2i(variante, orientacao))

	if total >= 3 and rng.randf() < CHANCE_CAIXA:
		for _tentativa: int in 6:
			var posicao: int = rng.randi_range(0, total - 1)
			if ocupadas.has(posicao):
				continue
			ocupadas[posicao] = true
			_detalhes.set_cell(corrida[posicao], FONTE_DETALHE, Vector2i(Detalhe.CAIXA, orientacao))
			break

	# A luminaria fica na face de dentro, entao so cabe onde o outro lado da
	# parede e piso de verdade — em parede grossa ela acenderia contra concreto.
	var dentro: Vector2i = -CARDEAIS[orientacao]
	for posicao: int in total:
		if ocupadas.has(posicao) or rng.randf() > CHANCE_LUZ:
			continue
		if not eh_interior(corrida[posicao] + dentro):
			continue
		_detalhes.set_cell(corrida[posicao], FONTE_DETALHE, Vector2i(Detalhe.LUZ, orientacao))


func _mascara(celula: Vector2i, tem: Callable) -> int:
	var mascara: int = 0
	for i: int in DIRECOES.size():
		if tem.call(celula + DIRECOES[i]):
			mascara |= 1 << i
	return mascara


# --- portas automaticas ------------------------------------------------------

func _atualizar_portas() -> void:
	if _vaos.is_empty():
		return
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group(&"jogador") as Node2D
		if _jogador == null:
			return
	var alcance: float = ALCANCE_PORTA * CELULA
	var origem: Vector2 = _jogador.global_position
	for vao: Array in _vaos:
		var aberta: bool = false
		for celula: Vector2i in vao:
			if origem.distance_to(centro_da(celula)) < alcance:
				aberta = true
				break
		for celula: Vector2i in vao:
			if _abertos.get(celula, false) == aberta:
				continue
			_abertos[celula] = aberta
			_pintar_porta(celula)


# --- regras ------------------------------------------------------------------

func _tem_interior_vizinho(celula: Vector2i) -> bool:
	for direcao: Vector2i in CARDEAIS:
		if eh_interior(celula + direcao):
			return true
	return false


## Eixo da passagem de uma porta: o par de lados opostos que tem piso. Zero
## quando nao existe par, que e o caso de parede de fora e de canto.
func _eixo_da_porta(celula: Vector2i) -> Vector2i:
	for eixo: Vector2i in [Vector2i(0, 1), Vector2i(1, 0)]:
		if eh_interior(celula + eixo) and eh_interior(celula - eixo):
			return eixo
	return Vector2i.ZERO


## Lado do portao virado para o espaco. Exige piso no lado oposto: um portao
## precisa ligar o interior ao vazio, nao dois pedacos de casco.
func _lado_externo(celula: Vector2i) -> Vector2i:
	for direcao: Vector2i in CARDEAIS:
		if pertence(celula + direcao):
			continue
		if eh_interior(celula - direcao):
			return direcao
	return Vector2i.ZERO


## Celulas vizinhas do mesmo tipo. Serve para o vao da porta e para o portao,
## que abrem como peca unica mesmo ocupando varias celulas.
func _grupo_contiguo(inicio: Vector2i, tipo: Tipo) -> Array[Vector2i]:
	var grupo: Array[Vector2i] = [inicio]
	var vistos: Dictionary = {inicio: true}
	var fila: Array[Vector2i] = [inicio]
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_back()
		for direcao: Vector2i in CARDEAIS:
			var vizinho: Vector2i = atual + direcao
			if vistos.has(vizinho) or tipo_em(vizinho) != tipo:
				continue
			vistos[vizinho] = true
			grupo.append(vizinho)
			fila.append(vizinho)
	return grupo
