# Gera a arte da interface de jogo.
#
#   assets/interface/energia.png   6 pecas de 8x11
#   assets/interface/painel.png    duas chapas de 9x9, para moldura de nove
#   assets/interface/balao.png     balao de fala de nove pedacos, mais o rabo
#   assets/interface/teclas.png    36 teclas de 11x11: A-Z e 0-9
#
# A BARRA E MONTADA, NAO DESENHADA INTEIRA
#
# O numero de divisoes muda: hoje a barra tem oito, uma por quadrado de chao que
# a energia cheia constroi, e a ideia e que melhorias acrescentem divisoes ao
# longo do jogo. Uma arte de barra inteira teria de ser redesenhada a cada
# tamanho novo, entao o que sai daqui sao PECAS que scripts/barra_energia.gd
# repete e posiciona: a divisao cheia, a vazia, a ponta e a gema.
#
# A moldura tambem sai daqui, e nao de retangulos chapados no Control: assim a
# paleta vive num lugar so. O trecho reto dela e uma fatia de UM pixel de
# largura que o Control estica — esticar na horizontal repete colunas, e numa
# moldura de linhas horizontais isso nao deforma nada.
#
# POR QUE A DIVISAO CHEIA E A VAZIA TEM A MESMA SILHUETA
#
# A divisao e um ">" inclinado, e cheia ou vazia ela ocupa exatamente os mesmos
# pixels: o que muda e so a cor do miolo. Silhuetas diferentes fariam a fila
# inteira andar um pixel quando uma divisao se esvazia.
from PIL import Image, ImageDraw

SAIDA_ENERGIA = "assets/interface/energia.png"
SAIDA_PAINEL = "assets/interface/painel.png"
SAIDA_BALAO = "assets/interface/balao.png"
SAIDA_TECLAS = "assets/interface/teclas.png"

## Altura da arte. A barra e desenhada na tela com escala inteira (ver
## barra_energia.gd), entao este e o tamanho do pixel grande, nao o da tela.
##
## Encolheu de 14 para 11 em 2026-10-05, a pedido: a barra ocupava um quinto da
## largura da tela e so media uma coisa. Quem perdeu altura foi o MIOLO — a
## moldura continua com as mesmas quatro linhas, porque sao elas que fazem a
## peca ler como calha de aco, e cortar uma deixa o sulco sem fundo.
ALTURA: int = 11

## Largura da celula na folha. Sobra de proposito: o ">" se inclina para a
## direita e precisa de espaco alem do passo com que as divisoes se repetem.
LARGURA: int = 8

## Primeira e ultima linha do miolo. Fora delas fica a moldura, que o Control
## desenha — a arte so precisa caber dentro.
TOPO: int = 2
BASE: int = 8

## Largura do corpo do ">" e quanto a ponta avanca. O passo com que as divisoes
## se repetem e CORPO + FOLGA, e a FOLGA e o sulco escuro entre uma e outra:
## como o avanco da ponta e o mesmo em todas, o sulco sai com largura constante
## em todas as linhas, que e o que faz a fila parecer uma peca so repetida.
CORPO: int = 4
PONTA: int = 3
FOLGA: int = 2
PASSO: int = CORPO + FOLGA

## Colunas da folha, na ordem em que barra_energia.gd as usa.
CHEIA: int = 0
VAZIA: int = 1
SETA: int = 2
GEMA: int = 3
TRILHO: int = 4
TAMPA: int = 5
COLUNAS: int = 6

## Largura util das duas pecas de moldura. O trilho e esticado pelo Control, e
## por isso tem um pixel: o resto da celula fica transparente.
LARGURA_TRILHO: int = 1
LARGURA_TAMPA: int = 2

# Paleta: a mesma do casco e da cama, mais o verde da energia. A moldura e de
# aco porque a barra e um instrumento da estacao, nao um adorno de menu.
CONTORNO = (18, 22, 30, 255)
ACO = (126, 139, 155, 255)
ACO_CLARO = (182, 194, 207, 255)
ACO_ESCURO = (74, 84, 98, 255)
CALHA = (34, 41, 52, 255)
SULCO = (52, 62, 76, 255)

# A divisao cheia e a gema saem em CINZA, e quem as colore e o Control, por
# modulate. Desenha-las ja verdes travava a cor: o aviso de energia baixa e
# vermelho, e nenhuma multiplicacao leva um verde ao vermelho — o R teria de
# crescer onde o G ja esta alto, e o que saia era oliva. Em cinza, qualquer
# cor futura e uma linha no Control.
TINTA_LUZ = (240, 240, 240, 255)
TINTA = (178, 178, 178, 255)
TINTA_SOMBRA = (104, 104, 104, 255)


def _avanco(y: int) -> int:
	"""Quanto a ponta do ">" avanca nesta linha: zero nas beiradas, PONTA no meio."""
	meio = (TOPO + BASE) / 2.0
	return int(round(PONTA * (1.0 - abs(y - meio) / (meio - TOPO))))


def _divisao(arte: Image.Image, coluna: int, cheia: bool) -> None:
	desenho = ImageDraw.Draw(arte)
	base = coluna * LARGURA
	for y in range(TOPO, BASE + 1):
		x0 = base + _avanco(y)
		x1 = x0 + CORPO - 1
		if not cheia:
			# Vazia: o sulco da calha, um tom acima do fundo. Nao e preta — uma
			# divisao gasta ainda e uma divisao, e some de todo se nao aparecer.
			desenho.line((x0, y, x1, y), fill=SULCO)
			continue
		# Cheia: tres faixas chapadas, como o tubo do casco. Degrade continuo
		# sai lavado numa peca desta altura, e com o miolo em sete linhas a
		# reparticao e 2/3/2 — duas de luz, tres de meio-tom, duas de sombra.
		if y <= TOPO + 1:
			cor = TINTA_LUZ
		elif y >= BASE - 1:
			cor = TINTA_SOMBRA
		else:
			cor = TINTA
		desenho.line((x0, y, x1, y), fill=cor)


def _seta(arte: Image.Image, coluna: int) -> None:
	"""Ponta que fecha a barra: a moldura vira bico em vez de cortar reto.

	Desenhada como poligono, e nao linha a linha com o bico calculado por
	altura: a versao por linha deixava a aresta serrilhada, com o contorno
	saindo em degraus soltos em vez de um fio continuo.
	"""
	desenho = ImageDraw.Draw(arte)
	base = coluna * LARGURA
	meio = (ALTURA - 1) // 2
	bico = base + LARGURA - 2
	corpo = [(base, 0), (bico, meio), (base, ALTURA - 1)]
	desenho.polygon(corpo, fill=CALHA, outline=CONTORNO)
	# Chanfro de aco por dentro da aresta: o mesmo fio de luz em cima e sombra
	# embaixo que faz o trilho da cama ler como metal.
	desenho.line([(base, 1), (bico - 1, meio)], fill=ACO_CLARO)
	desenho.line([(base, ALTURA - 2), (bico - 1, meio)], fill=ACO_ESCURO)


def _gema(arte: Image.Image, coluna: int) -> None:
	"""Losango que ancora a barra, como na referencia.

	E o unico pedaco que nao se repete: serve de marca do que a barra mede, e
	fica fora da fila de divisoes.
	"""
	desenho = ImageDraw.Draw(arte)
	base = coluna * LARGURA
	centro = (base + LARGURA // 2, (ALTURA - 1) // 2)
	raio = ALTURA // 2 - 1
	for dy in range(-raio, raio + 1):
		largura = raio - abs(dy)
		y = centro[1] + dy
		desenho.line((centro[0] - largura, y, centro[0] + largura, y), fill=CONTORNO)
		if largura >= 1:
			cor = TINTA_LUZ if dy < 0 else TINTA
			desenho.line((centro[0] - largura + 1, y, centro[0] + largura - 1, y), fill=cor)
	# Brilho em cruz: e o que separa gema de bolota — pedra chapada nao tem face.
	desenho.line(
		(centro[0], centro[1] - raio + 2, centro[0], centro[1] + raio - 2), fill=TINTA_SOMBRA
	)
	desenho.point(centro, fill=TINTA_LUZ)


def _moldura(arte: Image.Image, coluna: int, largura: int, com_tampa: bool) -> None:
	"""Fatia da moldura: o trilho reto, ou a tampa que fecha a esquerda."""
	desenho = ImageDraw.Draw(arte)
	base = coluna * LARGURA
	fim = base + largura - 1
	desenho.rectangle((base, 0, fim, ALTURA - 1), fill=CALHA)
	# Luz em cima, sombra embaixo: a calha le como sulco cavado na chapa, e nao
	# como retangulo pintado.
	desenho.line((base, 0, fim, 0), fill=CONTORNO)
	desenho.line((base, 1, fim, 1), fill=ACO_CLARO)
	desenho.line((base, ALTURA - 2, fim, ALTURA - 2), fill=ACO_ESCURO)
	desenho.line((base, ALTURA - 1, fim, ALTURA - 1), fill=CONTORNO)
	if com_tampa:
		desenho.line((base, 0, base, ALTURA - 1), fill=CONTORNO)
		desenho.line((base + 1, 1, base + 1, ALTURA - 2), fill=ACO)
		# Dois rebites na tampa: e o detalhe que diz que a calha e parafusada na
		# placa, e nao um retangulo pintado nela. Um so le como falha no pixel.
		for y in (2, ALTURA - 3):
			desenho.point((base + 1, y), fill=ACO_CLARO)


# ---------------------------------------------------------------- painel ---
#
# A placa do HUD e uma MOLDURA DE NOVE PEDACOS: quatro cantos de tamanho fixo,
# quatro arestas esticadas numa direcao so e o miolo esticado nas duas. Por isso
# a arte e um quadrado de LADO_PAINEL com a divisa em BORDA_PAINEL — a aresta de
# cima e a coluna do meio, de um pixel, e esticar um pixel na horizontal e
# repetir coluna, que numa chapa de linhas horizontais nao deforma nada.
#
# Sao DUAS chapas na mesma folha, uma por linha: a de cima e relevo (luz em
# cima, sombra embaixo) e a de baixo e encaixe (sombra em cima, luz embaixo).
# Mesma geometria, luz invertida — e o que separa "placa parafusada" de "rebaixo
# cavado na placa", e o que deixa o contador do dia parecer encaixado nela.

## Lado da chapa e espessura da moldura. Com 9 e 4 sobra UM pixel no centro, que
## e o miolo esticado: canto, aresta e miolo saem todos deste quadrado.
LADO_PAINEL: int = 9
BORDA_PAINEL: int = 4

RELEVO: int = 0
ENCAIXE: int = 1

## Fundo das duas chapas. A placa precisa ficar CLARAMENTE acima do fundo: na
## primeira versao ela era quase da cor do espaco, e so o chanfro aparecia — o
## painel lia como uma moldura vazia em vez de uma chapa com coisas em cima.
##
## Nenhuma das duas e opaca: o HUD fica por cima do jogo, e chapa fechada no
## canto da tela tapa estrela e casco como se fosse cenario.
CHAPA = (58, 68, 86, 235)
CHAPA_ENCAIXE = (26, 32, 44, 240)


def _chapa(arte: Image.Image, linha: int, cavada: bool) -> None:
	"""Uma das duas chapas da folha, na linha pedida.

	A geometria e a mesma; o que separa relevo de encaixe e de que lado vem a
	luz. No relevo o chanfro claro fica em cima e a esquerda; no encaixe ele
	troca de lado E escurece, porque rebaixo cavado tem sombra propria em cima,
	nao so menos luz.
	"""
	desenho = ImageDraw.Draw(arte)
	topo = linha * LADO_PAINEL
	fim = LADO_PAINEL - 1
	alta = CONTORNO if cavada else ACO
	baixa = ACO if cavada else ACO_ESCURO
	desenho.rectangle(
		(0, topo, fim, topo + fim), fill=CHAPA_ENCAIXE if cavada else CHAPA, outline=CONTORNO
	)
	# Chanfro de um pixel por dentro do contorno: em cima e a esquerda de um
	# lado, embaixo e a direita do outro.
	desenho.line((1, topo + 1, fim - 1, topo + 1), fill=alta)
	desenho.line((1, topo + 1, 1, topo + fim - 1), fill=alta)
	desenho.line((1, topo + fim - 1, fim - 1, topo + fim - 1), fill=baixa)
	desenho.line((fim - 1, topo + 1, fim - 1, topo + fim - 1), fill=baixa)
	if cavada:
		return
	# Rebite nos quatro cantos, so no relevo. Cabe porque canto tem BORDA_PAINEL
	# de lado: no miolo ele seria esticado e viraria uma risca de ponta a ponta.
	for x in (2, fim - 2):
		for y in (2, fim - 2):
			desenho.point((x, topo + y), fill=ACO_ESCURO)
			desenho.point((x, topo + y - 1), fill=ACO_CLARO)


def gerar_painel() -> None:
	arte = Image.new("RGBA", (LADO_PAINEL, LADO_PAINEL * 2), (0, 0, 0, 0))
	_chapa(arte, RELEVO, False)
	_chapa(arte, ENCAIXE, True)
	arte.save(SAIDA_PAINEL)
	print("gerado: %s (%dx%d, 2 chapas de %d, borda %d)" % (
		SAIDA_PAINEL, arte.width, arte.height, LADO_PAINEL, BORDA_PAINEL
	))


def gerar() -> None:
	arte = Image.new("RGBA", (LARGURA * COLUNAS, ALTURA), (0, 0, 0, 0))
	_divisao(arte, CHEIA, True)
	_divisao(arte, VAZIA, False)
	_seta(arte, SETA)
	_gema(arte, GEMA)
	_moldura(arte, TRILHO, LARGURA_TRILHO, False)
	_moldura(arte, TAMPA, LARGURA_TAMPA, True)
	arte.save(SAIDA_ENERGIA)
	print("gerado: %s (%dx%d, %d pecas de %dx%d, passo %d)" % (
		SAIDA_ENERGIA, arte.width, arte.height, COLUNAS, LARGURA, ALTURA, PASSO
	))


# ----------------------------------------------------------------- teclas ---
#
# As dicas de tecla eram texto: "E — dormir". Letra solta nao le como tecla, e
# "E" no meio de uma frase em portugues le como a conjuncao. Entao a tecla virou
# DESENHO: uma tampa de teclado com a letra gravada, que se reconhece antes de
# ler a frase.
#
# A folha traz o ALFABETO INTEIRO mais os dez digitos, e nao so as teclas que o
# jogo usa hoje (E e F). Sao 36 celulas de 11x11 — um punhado de bytes de PNG —
# e o custo de acrescentar uma dica nova passa a ser uma letra no codigo em vez
# de uma rodada de gerador.
#
# A tampa NAO sai em cinza para o Control tingir, ao contrario das divisoes da
# barra: ela e feita de tres tons de aco mais a letra clara, e multiplicar o
# conjunto tingiria o aco junto com a letra. Tecla e objeto, nao indicador.

## Lado da tampa e quantas cabem por linha na folha. 11 com a letra de 5x7
## deixa uma linha de luz em cima, uma de saia embaixo e duas colunas de folga
## de cada lado — o minimo para a tampa ler como peca de tres faces.
LADO_TECLA: int = 11
COLUNAS_TECLAS: int = 6

## Onde a letra cai dentro da tampa. Sobra mais em cima do que embaixo de
## proposito: a saia escura embaixo e a face frontal da tecla, e letra centrada
## na peca inteira pareceria baixa demais na face de cima.
LETRA_X: int = 3
LETRA_Y: int = 2
LETRA_LARGURA: int = 5
LETRA_ALTURA: int = 7

FACE_TECLA = ACO_ESCURO
LUZ_TECLA = ACO
SAIA_TECLA = CALHA
LETRA = TINTA_LUZ

## Fonte de 5x7, desenhada aqui porque e a unica do projeto: o resto da
## interface usa a fonte do Godot, que e vetorial e nao caberia legivel em sete
## linhas de pixel. 5 de largura e o minimo que da M e W sem fundir as hastes.
FONTE = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"J": ["....#", "....#", "....#", "....#", "#...#", "#...#", ".###."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#...#", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "#...#", ".###."],
}

## A ordem da folha. O script acha a celula por esta string, entao ela e o
## contrato entre o gerador e scripts/balao.gd: letra -> indice -> celula.
ORDEM = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"


def _tampa(arte: Image.Image, coluna: int, linha: int, letra: str) -> None:
	"""Uma tecla: tampa de aco de tres faces com a letra gravada.

	As tres faces sao a mesma receita do tubo do casco e da calha da barra —
	uma linha de luz em cima, o corpo no meio e a saia escura embaixo. Sem a
	saia a peca le como quadrado com letra dentro, nao como tecla.
	"""
	desenho = ImageDraw.Draw(arte)
	bx = coluna * LADO_TECLA
	by = linha * LADO_TECLA
	fim = LADO_TECLA - 1
	desenho.rectangle((bx, by, bx + fim, by + fim), fill=FACE_TECLA, outline=CONTORNO)
	desenho.line((bx + 1, by + 1, bx + fim - 1, by + 1), fill=LUZ_TECLA)
	desenho.line((bx + 1, by + fim - 1, bx + fim - 1, by + fim - 1), fill=SAIA_TECLA)
	# Canto cortado em um pixel: tampa de teclado tem canto arredondado, e a
	# quina viva deixava a peca parecida com a chapa do painel.
	for cx in (bx, bx + fim):
		for cy in (by, by + fim):
			desenho.point((cx, cy), fill=(0, 0, 0, 0))
	for y, linha_da_letra in enumerate(FONTE[letra]):
		for x, ponto in enumerate(linha_da_letra):
			if ponto == "#":
				desenho.point((bx + LETRA_X + x, by + LETRA_Y + y), fill=LETRA)


def gerar_teclas() -> None:
	linhas = (len(ORDEM) + COLUNAS_TECLAS - 1) // COLUNAS_TECLAS
	arte = Image.new(
		"RGBA", (COLUNAS_TECLAS * LADO_TECLA, linhas * LADO_TECLA), (0, 0, 0, 0)
	)
	for indice, letra in enumerate(ORDEM):
		_tampa(arte, indice % COLUNAS_TECLAS, indice // COLUNAS_TECLAS, letra)
	arte.save(SAIDA_TECLAS)
	print("gerado: %s (%dx%d, %d teclas de %d, letra %dx%d)" % (
		SAIDA_TECLAS, arte.width, arte.height, len(ORDEM), LADO_TECLA,
		LETRA_LARGURA, LETRA_ALTURA
	))


# ------------------------------------------------------------------ balao ---
#
# O balao de fala e outra MOLDURA DE NOVE PEDACOS, como a placa do HUD, mais um
# rabo apontando para quem fala. A diferenca de desenho e deliberada: a placa e
# chapa clara parafusada no canto da tela, e o balao e vidro escuro com fio de
# luz na borda. Sao duas vozes diferentes — a placa e instrumento da estacao, o
# balao e o personagem falando — e se as duas tivessem a mesma cara o jogador
# leria a fala como mais uma leitura do painel.
#
# A borda tem DOIS pixels: contorno escuro por fora e fio claro por dentro. Com
# um so, o balao sumia sobre o casco claro ou sobre o espaco, conforme onde o
# personagem estivesse — e ele anda pelos dois.

LADO_BALAO: int = 9
BORDA_BALAO: int = 4

## O rabo e mais largo que o balao e mora embaixo dele na folha. As duas
## primeiras linhas dele cobrem as duas de borda do balao: sem isso a boca do
## rabo ficaria fechada pela propria borda, e o rabo leria como peca solta.
RABO_Y: int = LADO_BALAO
RABO_LARGURA: int = 11
RABO_ALTURA: int = 7
RABO_SOBREPOSICAO: int = 2

## O fundo do balao precisa ficar CLARAMENTE acima do espaco. A primeira versao
## era (16,21,32), a um passo dos (11,16,36) do campo estelar: o miolo do balao
## sumia no fundo e o rabo, que nao tem texto em cima, lia como um V de dois
## fios de luz soltos. Fica tambem claramente abaixo do piso da estacao
## (78,103,133), que e o que deixa a letra clara legivel por cima.
BALAO_FUNDO = (34, 42, 60, 240)
BALAO_LUZ = ACO_CLARO


def _balao(desenho: ImageDraw.ImageDraw) -> None:
	"""A moldura de nove pedacos do balao, com os quatro cantos cortados."""
	fim = LADO_BALAO - 1
	desenho.rectangle((0, 0, fim, fim), fill=BALAO_FUNDO, outline=CONTORNO)
	desenho.rectangle((1, 1, fim - 1, fim - 1), outline=BALAO_LUZ)
	for x in (0, fim):
		for y in (0, fim):
			desenho.point((x, y), fill=(0, 0, 0, 0))
	# O corte joga o contorno uma casa para dentro na diagonal, e o fio de luz
	# atras dele: sem os dois a esquina fica com um degrau claro para fora.
	for x, dentro_x in ((0, 1), (fim, fim - 1)):
		for y, dentro_y in ((0, 1), (fim, fim - 1)):
			desenho.point((dentro_x, dentro_y), fill=CONTORNO)
			desenho.point(
				(dentro_x + (1 if x == 0 else -1), dentro_y + (1 if y == 0 else -1)),
				fill=BALAO_LUZ,
			)


def _rabo(desenho: ImageDraw.ImageDraw) -> None:
	"""O rabo, desenhado linha a linha e nao por poligono.

	A ponta precisa cair no pixel exato de quem fala, e poligono arredonda a
	quina por conta propria.

	**O fio de luz nao desce pelo talude**, so vira a esquina na boca. O balao
	tem borda de dois pixels, e repetir os dois no talude foi tentado: num
	caimento de 45 graus ampliado em 2, um fio de um pixel vira contas brancas
	em escada, e o rabo saia com cara de ziper. So o contorno escuro desce.
	"""
	fim = RABO_LARGURA - 1
	for r in range(RABO_ALTURA):
		y = RABO_Y + r
		# As duas primeiras linhas sao a boca: largura cheia, para cobrir a
		# borda de baixo do balao.
		recuo = 0 if r < RABO_SOBREPOSICAO else r - RABO_SOBREPOSICAO + 1
		esquerda = recuo
		direita = fim - recuo
		if direita - esquerda >= 2:
			desenho.line((esquerda + 1, y, direita - 1, y), fill=BALAO_FUNDO)
		desenho.point((esquerda, y), fill=CONTORNO)
		desenho.point((direita, y), fill=CONTORNO)
	# A esquina: a linha de cima da boca cobre a linha de luz do balao, entao e
	# nela que o fio claro vira para dentro do rabo e para.
	desenho.point((1, RABO_Y), fill=BALAO_LUZ)
	desenho.point((fim - 1, RABO_Y), fill=BALAO_LUZ)


def gerar_balao() -> None:
	arte = Image.new("RGBA", (RABO_LARGURA, RABO_Y + RABO_ALTURA), (0, 0, 0, 0))
	desenho = ImageDraw.Draw(arte)
	_balao(desenho)
	_rabo(desenho)
	arte.save(SAIDA_BALAO)
	print("gerado: %s (%dx%d, balao de %d borda %d, rabo %dx%d)" % (
		SAIDA_BALAO, arte.width, arte.height, LADO_BALAO, BORDA_BALAO,
		RABO_LARGURA, RABO_ALTURA
	))


if __name__ == "__main__":
	gerar()
	gerar_painel()
	gerar_balao()
	gerar_teclas()
