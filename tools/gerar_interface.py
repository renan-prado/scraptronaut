# Gera a arte da interface de jogo.
#
#   assets/interface/energia.png   4 celulas de 16x14
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

## Altura da arte. A barra e desenhada na tela com escala inteira (ver
## barra_energia.gd), entao este e o tamanho do pixel grande, nao o da tela.
ALTURA: int = 14

## Largura da celula na folha. Sobra de proposito: o ">" se inclina para a
## direita e precisa de espaco alem do passo com que as divisoes se repetem.
LARGURA: int = 16

## Primeira e ultima linha do miolo. Fora delas fica a moldura, que o Control
## desenha — a arte so precisa caber dentro.
TOPO: int = 2
BASE: int = 11

## Largura do corpo do ">" e quanto a ponta avanca. O passo com que as divisoes
## se repetem e CORPO + FOLGA, e a FOLGA e o sulco escuro entre uma e outra:
## como o avanco da ponta e o mesmo em todas, o sulco sai com largura constante
## em todas as linhas, que e o que faz a fila parecer uma peca so repetida.
CORPO: int = 9
PONTA: int = 4
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
LARGURA_TAMPA: int = 3

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
		# sai lavado numa peca de dez pixels de altura.
		if y <= TOPO + 2:
			cor = TINTA_LUZ
		elif y >= BASE - 2:
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


if __name__ == "__main__":
	gerar()
