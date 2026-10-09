# -*- coding: utf-8 -*-
"""Gera os tiles da estacao em assets/tiles/estacao/.

A paleta foi amostrada de inbox/reference/prints/image copy.png, a referencia de
estrutura aprovada para a Lastro.

O casco e a borda nao sao desenhados tile a tile a mao: cada um e um atlas de
256 celulas indexado por uma mascara de 8 bits da vizinhanca. Assim o mapa pode
ter qualquer formato — o script de jogo calcula a mascara da celula e le o tile
direto, sem tabela de autotile nem terrenos do TileSet.

Uso: python tools/gerar_tiles_estacao.py
"""
import random

import numpy as np
from PIL import Image

CELULA = 64
SAIDA = "assets/tiles/estacao"

## Quanto o casco recua da borda da celula no lado virado para o espaco.
## E o numero que controla a espessura aparente da parede: subir afina.
RECUO = 20

## Perfil do casco a partir da borda externa, em pixels de profundidade.
CONTORNO = 1
BANDA = 10
LINHA = 11

COR_PLACA = (58, 83, 114)
COR_PLACA_CLARA = (70, 97, 128)
COR_PLACA_ESCURA = (44, 64, 90)
COR_BANDA = (139, 170, 195)
COR_BANDA_TOPO = (173, 199, 219)
COR_BANDA_BAIXA = (108, 140, 168)
COR_CONTORNO = (12, 22, 40)
COR_LINHA = (22, 36, 61)
COR_PISO = (72, 97, 127)
COR_PISO_CLARO = (83, 109, 139)
COR_PISO_ESCURO = (63, 86, 114)
COR_JUNTA = (62, 84, 111)
COR_SOMBRA = (8, 16, 31)

## N, NE, L, SE, S, SO, O, NO — a ordem define os bits da mascara e precisa
## bater com DIRECOES em scripts/mapa_estacao.gd.
DIRECOES = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]
INDICE = {d: i for i, d in enumerate(DIRECOES)}
CARDEAIS = [(0, -1), (1, 0), (0, 1), (-1, 0)]

LADO_ATLAS = 16


# --- utilidades --------------------------------------------------------------

def _mistura(a, b, t):
	return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _distancia_ate_vazio(solido, alcance):
	"""Distancia 4-conexa de cada pixel solido ate o vazio mais proximo.

	Pixel vazio recebe 0; o primeiro solido recebe 1. Acima de alcance o valor
	satura, que basta porque o perfil do casco so le os primeiros pixels.
	"""
	limite = alcance + 2
	dist = np.where(solido, limite, 0).astype(np.int16)
	for _ in range(limite):
		vizinho = np.full_like(dist, limite)
		vizinho[1:, :] = np.minimum(vizinho[1:, :], dist[:-1, :])
		vizinho[:-1, :] = np.minimum(vizinho[:-1, :], dist[1:, :])
		vizinho[:, 1:] = np.minimum(vizinho[:, 1:], dist[:, :-1])
		vizinho[:, :-1] = np.minimum(vizinho[:, :-1], dist[:, 1:])
		novo = np.minimum(dist, vizinho + 1)
		novo[~solido] = 0
		if np.array_equal(novo, dist):
			break
		dist = novo
	return dist


def _retangulo_corpo(vazio):
	"""Area solida da celula: o quadrado inteiro menos o recuo de cada lado
	virado para o espaco."""
	x0 = RECUO if vazio[(-1, 0)] else 0
	x1 = CELULA - RECUO if vazio[(1, 0)] else CELULA
	y0 = RECUO if vazio[(0, -1)] else 0
	y1 = CELULA - RECUO if vazio[(0, 1)] else CELULA
	return x0, y0, x1, y1


def _contexto_casco(mascara):
	"""Bitmap de 3x3 celulas com o corpo da celula central e o das vizinhas.

	O corpo das vizinhas e reconstruido a partir do que a mascara deixa saber:
	o lado virado para o centro e sempre solido, os dois lados laterais sao
	conhecidos, e o lado de fora e assumido solido — longe demais para
	influenciar os poucos pixels de borda que serao lidos.
	"""
	vazio_de = {}
	for direcao, i in INDICE.items():
		vazio_de[direcao] = bool(mascara & (1 << i))
	vazio_de[(0, 0)] = False

	solido = np.zeros((3 * CELULA, 3 * CELULA), dtype=bool)

	def preencher(origem, retangulo):
		ox, oy = origem
		x0, y0, x1, y1 = retangulo
		bx = (ox + 1) * CELULA
		by = (oy + 1) * CELULA
		solido[by + y0:by + y1, bx + x0:bx + x1] = True

	preencher((0, 0), _retangulo_corpo({c: vazio_de[c] for c in CARDEAIS}))

	# Canto cortado quando so a diagonal e espaco: sem isso a silhueta ganha um
	# dente de 20 px nos cantos reentrantes da estacao.
	for dx, dy in [(1, -1), (1, 1), (-1, 1), (-1, -1)]:
		if not vazio_de[(dx, dy)]:
			continue
		if vazio_de[(dx, 0)] or vazio_de[(0, dy)]:
			continue
		px = CELULA + (CELULA - RECUO if dx > 0 else 0)
		py = CELULA + (CELULA - RECUO if dy > 0 else 0)
		solido[py:py + RECUO, px:px + RECUO] = False

	for origem in DIRECOES:
		if vazio_de[origem]:
			continue
		vizinho_vazio = {}
		for c in CARDEAIS:
			alvo = (origem[0] + c[0], origem[1] + c[1])
			vizinho_vazio[c] = vazio_de.get(alvo, False)
		preencher(origem, _retangulo_corpo(vizinho_vazio))
	return solido


# --- casco -------------------------------------------------------------------

def _perfil_de_parede(solido, semente, painel=True):
	"""Pinta uma celula de parede a partir do mapa de solidez de 3x3 celulas.

	O perfil sai da distancia ate o vazio, entao qualquer silhueta solida ganha
	a mesma leitura: contorno, banda clara que pega a luz, linha escura, chapa.
	E por isso que o buraco pode reusar esta funcao — a borda dele e parede, e
	precisa ser a MESMA parede, nao uma parecida.
	"""
	dist = _distancia_ate_vazio(solido, LINHA + 2)

	recorte = slice(CELULA, 2 * CELULA)
	d = dist[recorte, recorte]
	tela = np.zeros((CELULA, CELULA, 4), dtype=np.uint8)

	rng = random.Random(semente)
	ruido = np.array(
		[[rng.randint(-5, 5) for _ in range(CELULA)] for _ in range(CELULA)], dtype=np.int16
	)
	tela[:, :, :3] = np.clip(np.array(COR_PLACA, dtype=np.int16) + ruido[:, :, None], 0, 255)
	tela[:, :, 3] = np.where(d > 0, 255, 0)

	def pintar(condicao, cor):
		for canal in range(3):
			tela[:, :, canal] = np.where(condicao, cor[canal], tela[:, :, canal])

	for profundidade in range(2, BANDA):
		t = (profundidade - 2) / float(BANDA - 2)
		pintar(d == profundidade, _mistura(COR_BANDA_TOPO, COR_BANDA, t))
	pintar(d == BANDA, COR_BANDA_BAIXA)
	pintar(d == LINHA, COR_LINHA)
	pintar(d == CONTORNO, COR_CONTORNO)

	if painel:
		_painel(tela, d, rng)
	return Image.fromarray(tela, "RGBA")


def _pintar_casco(mascara):
	return _perfil_de_parede(_contexto_casco(mascara), 9000 + mascara)


def _painel(tela, d, rng):
	"""Chapa aparafusada no miolo da placa. So entra quando sobra area: em
	celula estreita o detalhe viraria sujeira."""
	fundo = d > LINHA + 1
	linhas = np.where(fundo.any(axis=1))[0]
	colunas = np.where(fundo.any(axis=0))[0]
	if linhas.size < 20 or colunas.size < 20:
		return
	y0, y1 = int(linhas[0]), int(linhas[-1])
	x0, x1 = int(colunas[0]), int(colunas[-1])

	margem = 5
	px0, py0 = x0 + margem, y0 + margem
	px1, py1 = x1 - margem, y1 - margem
	if px1 - px0 < 12 or py1 - py0 < 12:
		return
	if rng.random() < 0.25:
		return

	if px1 - px0 > py1 - py0 + 14:
		px0 += rng.randint(0, 6)
		px1 -= rng.randint(0, 6)
	elif py1 - py0 > px1 - px0 + 14:
		py0 += rng.randint(0, 6)
		py1 -= rng.randint(0, 6)

	for y in range(py0, py1 + 1):
		for x in range(px0, px1 + 1):
			if not fundo[y, x]:
				continue
			borda = x in (px0, px1) or y in (py0, py1)
			cor = COR_PLACA_ESCURA if borda else COR_PLACA_CLARA
			if not borda and (x == px0 + 1 or y == py0 + 1):
				cor = _mistura(COR_PLACA_CLARA, COR_BANDA, 0.22)
			tela[y, x, :3] = cor

	for cx, cy in [(px0 + 3, py0 + 3), (px1 - 3, py1 - 3)]:
		if fundo[cy, cx]:
			tela[cy, cx, :3] = COR_PLACA_ESCURA
			if fundo[cy - 1, cx]:
				tela[cy - 1, cx, :3] = _mistura(COR_PLACA_CLARA, COR_BANDA, 0.4)


def casco():
	folha = Image.new("RGBA", (LADO_ATLAS * CELULA, LADO_ATLAS * CELULA), (0, 0, 0, 0))
	for mascara in range(256):
		destino = ((mascara % LADO_ATLAS) * CELULA, (mascara // LADO_ATLAS) * CELULA)
		folha.paste(_pintar_casco(mascara), destino)
	folha.save(SAIDA + "/casco.png")


# --- borda: sombra de contato, pintada na celula de piso ---------------------

ALCANCE_SOMBRA = 7


def _pintar_borda(mascara):
	parede = np.zeros((3 * CELULA, 3 * CELULA), dtype=bool)
	for direcao, i in INDICE.items():
		if not (mascara & (1 << i)):
			continue
		bx = (direcao[0] + 1) * CELULA
		by = (direcao[1] + 1) * CELULA
		parede[by:by + CELULA, bx:bx + CELULA] = True

	dist = _distancia_ate_vazio(~parede, ALCANCE_SOMBRA + 1)
	recorte = slice(CELULA, 2 * CELULA)
	d = dist[recorte, recorte].astype(np.float32)

	tela = np.zeros((CELULA, CELULA, 4), dtype=np.uint8)
	for canal in range(3):
		tela[:, :, canal] = COR_SOMBRA[canal]
	intensidade = np.clip((ALCANCE_SOMBRA + 1 - d) / float(ALCANCE_SOMBRA), 0.0, 1.0)
	intensidade = np.where(d <= 0, 0.0, intensidade)
	tela[:, :, 3] = (intensidade ** 1.6 * 150).astype(np.uint8)
	return Image.fromarray(tela, "RGBA")


def borda():
	folha = Image.new("RGBA", (LADO_ATLAS * CELULA, LADO_ATLAS * CELULA), (0, 0, 0, 0))
	for mascara in range(256):
		destino = ((mascara % LADO_ATLAS) * CELULA, (mascara // LADO_ATLAS) * CELULA)
		folha.paste(_pintar_borda(mascara), destino)
	folha.save(SAIDA + "/borda.png")


# --- piso --------------------------------------------------------------------

VARIACOES_PISO = 4


def piso():
	folha = Image.new("RGBA", (VARIACOES_PISO * CELULA, VARIACOES_PISO * CELULA))
	for indice in range(VARIACOES_PISO * VARIACOES_PISO):
		rng = random.Random(4100 + indice)
		tela = np.zeros((CELULA, CELULA, 4), dtype=np.uint8)
		ruido = np.array(
			[[rng.randint(-4, 4) for _ in range(CELULA)] for _ in range(CELULA)], dtype=np.int16
		)
		tela[:, :, :3] = np.clip(np.array(COR_PISO, dtype=np.int16) + ruido[:, :, None], 0, 255)
		tela[:, :, 3] = 255

		# A junta fica so no topo e na esquerda: duas celulas vizinhas desenham
		# uma linha so, entao a grade sai com 1 px em qualquer arranjo.
		tela[0, :, :3] = COR_JUNTA
		tela[:, 0, :3] = COR_JUNTA
		tela[1, :, :3] = _mistura(COR_PISO, COR_PISO_CLARO, 0.5)
		tela[:, 1, :3] = _mistura(COR_PISO, COR_PISO_CLARO, 0.5)

		for _ in range(rng.randint(0, 2)):
			x = rng.randint(6, CELULA - 14)
			y = rng.randint(6, CELULA - 14)
			tela[y:y + rng.randint(1, 2), x:x + rng.randint(4, 10), :3] = COR_PISO_ESCURO

		if rng.random() < 0.35:
			x = rng.randint(10, CELULA - 18)
			y = rng.randint(10, CELULA - 18)
			raio = rng.randint(2, 3)
			for dy in range(-raio, raio + 1):
				for dx in range(-raio, raio + 1):
					if abs(dx) + abs(dy) <= raio:
						tela[y + dy, x + dx, :3] = COR_PISO_ESCURO
			tela[y - raio, x, :3] = _mistura(COR_PISO, COR_PISO_CLARO, 0.8)

		if rng.random() < 0.3:
			x = rng.randint(8, CELULA - 20)
			y = rng.randint(8, CELULA - 20)
			tela[y:y + 12, x:x + 1, :3] = _mistura(COR_PISO, COR_PISO_CLARO, 0.45)

		destino = ((indice % VARIACOES_PISO) * CELULA, (indice // VARIACOES_PISO) * CELULA)
		folha.paste(Image.fromarray(tela, "RGBA"), destino)
	folha.save(SAIDA + "/piso.png")


# --- porta ------------------------------------------------------------------

COR_FOLHA_TOPO = (142, 165, 190)
COR_FOLHA_BAIXO = (66, 88, 117)
COR_FOLHA_ESCURA = (38, 55, 78)
COR_TRILHO = (25, 38, 61)
COR_TRILHO_LUZ = (84, 106, 133)
COR_LARANJA = (235, 131, 9)
COR_LARANJA_CLARO = (255, 189, 99)

## Quanto de folha sobra visivel de cada lado com a porta aberta.
BATENTE_ABERTO = 11

## Segmentos de porta. INTEIRA fecha sozinha no meio da celula; METADE_A e
## METADE_B sao as duas pontas de um vao mais largo, e MEIO e uma celula de
## vao larga que some inteira quando abre.
SEG_INTEIRA, SEG_METADE_A, SEG_METADE_B, SEG_MEIO = range(4)
SEGMENTOS_PORTA = 4

## A borda de ataque e reta. Ja foi diagonal e ja teve dente de encaixe no
## meio: a 64 px os dois viram escada, e com o fio ambar por cima o degrau le
## como rachadura, nao como encaixe. Com a emenda reta a porta fecha limpa.

## Altura do trilho em cada ponta da celula. Fica por fora das folhas, entao
## continua visivel com a porta aberta — e o que faz o vao ler como porta.
TRILHO = 5


def _pintar_porta(aberta, segmento):
	"""Porta de passagem norte-sul: as folhas correm no eixo leste-oeste.

	A celula e sempre cheia porque a regra de construcao so aceita porta em
	parede com piso dos dois lados — logo as celulas vizinhas da linha da
	parede tambem sao cheias, e a folha pode ocupar a altura toda.

	`segmento` diz se a celula e uma porta inteira ou metade de um vao maior.
	Sem isso um vao de duas celulas sai com duas emendas, uma no meio de cada
	celula, e le como duas portinhas em vez de uma porta larga.
	"""
	tela = np.zeros((CELULA, CELULA, 4), dtype=np.uint8)

	def pixel(x, y, cor):
		if 0 <= x < CELULA and 0 <= y < CELULA:
			tela[y, x, :3] = cor
			tela[y, x, 3] = 255

	# Trilho: rasgo escuro com labio claro virado para dentro do vao.
	for y in range(TRILHO):
		for x in range(CELULA):
			pixel(x, y, COR_TRILHO)
			pixel(x, CELULA - 1 - y, COR_TRILHO)
	for x in range(CELULA):
		pixel(x, TRILHO - 1, COR_TRILHO_LUZ)
		pixel(x, CELULA - TRILHO, COR_TRILHO_LUZ)

	# Sulco do trilho: so a sombra, sem luz nenhuma. Toda a cor ambar da porta
	# esta na emenda das folhas — espalhar mais transforma o tile em zebra.
	for x in range(CELULA):
		pixel(x, 1, _mistura(COR_TRILHO, COR_FOLHA_ESCURA, 0.5))
		pixel(x, CELULA - 2, _mistura(COR_TRILHO, COR_FOLHA_ESCURA, 0.5))

	recolhida = BATENTE_ABERTO
	if segmento == SEG_INTEIRA:
		folhas = (
			[(0, recolhida, 1), (CELULA - recolhida, CELULA, -1)] if aberta
			else [(0, CELULA // 2, 1), (CELULA // 2, CELULA, -1)]
		)
	elif segmento == SEG_METADE_A:
		folhas = [(0, recolhida, 1)] if aberta else [(0, CELULA, 1)]
	elif segmento == SEG_METADE_B:
		folhas = [(CELULA - recolhida, CELULA, -1)] if aberta else [(0, CELULA, -1)]
	else:
		folhas = [] if aberta else [(0, CELULA, 0)]

	alto = CELULA - 2 * TRILHO
	for y in range(TRILHO, CELULA - TRILHO):
		t = (y - TRILHO) / float(alto - 1)
		corpo = _mistura(COR_FOLHA_TOPO, COR_FOLHA_BAIXO, t)

		for x0, x1, sentido in folhas:
			for x in range(max(0, x0), min(CELULA, x1)):
				pixel(x, y, corpo)
			if sentido == 0:
				continue
			ataque = (x1 - 1) if sentido > 0 else x0
			# Perfil da borda que fecha, de fora para dentro: fio ambar, vinco
			# escuro, fio de luz. Fechada, os dois fios ambar ficam colados e
			# viram uma emenda unica e brilhante; aberta, cada um marca a folha
			# recolhida no batente.
			pixel(ataque, y, COR_LARANJA_CLARO if y % 9 == 4 else COR_LARANJA)
			pixel(ataque - sentido, y, COR_FOLHA_ESCURA)
			pixel(ataque - sentido * 2, y, _mistura(corpo, COR_FOLHA_TOPO, 0.65))

	# Juntas da folha: um risco raso so, para dar escala sem listrar.
	for y in (TRILHO + 13, CELULA - TRILHO - 14):
		for x in range(CELULA):
			if tela[y, x, 3] and not _eh_ambar(tela[y, x]):
				tela[y, x, :3] = _mistura(tuple(tela[y, x, :3]), COR_FOLHA_ESCURA, 0.55)

	return Image.fromarray(tela, "RGBA")


def _eh_ambar(pixel):
	return int(pixel[0]) > 180 and int(pixel[2]) < 140


def porta():
	folha = Image.new("RGBA", (2 * SEGMENTOS_PORTA * CELULA, 2 * CELULA), (0, 0, 0, 0))
	for segmento in range(SEGMENTOS_PORTA):
		for estado, aberta in enumerate([False, True]):
			tile = _pintar_porta(aberta, segmento)
			coluna = segmento * 2 + estado
			folha.paste(tile, (coluna * CELULA, 0))
			# A rotacao e anti-horaria: o oeste da base cai no sul da linha 1.
			# A metade A, que recolhe para oeste, vira a metade de baixo.
			folha.paste(tile.transpose(Image.ROTATE_90), (coluna * CELULA, CELULA))
	folha.save(SAIDA + "/porta.png")


# --- portao de nave ----------------------------------------------------------

COR_FAIXA_ESCURA = (38, 44, 58)
PERIODO_FAIXA = 8


def _pintar_portao(aberto):
	"""Portao com o espaco ao norte. As outras tres orientacoes saem por
	rotacao, igual a porta."""
	tela = np.zeros((CELULA, CELULA, 4), dtype=np.uint8)

	if aberto:
		# Sobra a soleira junto ao piso do hangar: o vao precisa ler como vazio.
		tela[CELULA - 5:CELULA - 2, :, :3] = COR_PLACA_ESCURA
		tela[CELULA - 5:CELULA - 2, :, 3] = 255
		tela[CELULA - 2:CELULA, :, :3] = COR_LINHA
		tela[CELULA - 2:CELULA, :, 3] = 255
		for x in range(4, CELULA - 4, 16):
			tela[CELULA - 4, x:x + 6, :3] = COR_LARANJA
			tela[CELULA - 4, x:x + 6, 3] = 255
		return Image.fromarray(tela, "RGBA")

	for y in range(RECUO, CELULA):
		for x in range(CELULA):
			profundidade = y - RECUO + 1
			if profundidade == CONTORNO:
				cor = COR_CONTORNO
			elif profundidade < BANDA:
				cor = _mistura(COR_BANDA_TOPO, COR_BANDA, (profundidade - 2) / float(BANDA - 2))
			elif profundidade == BANDA:
				cor = COR_BANDA_BAIXA
			elif profundidade == LINHA:
				cor = COR_LINHA
			elif ((x + y) // PERIODO_FAIXA) % 2 == 0:
				cor = COR_LARANJA
			else:
				cor = COR_FAIXA_ESCURA
			tela[y, x, :3] = cor
			tela[y, x, 3] = 255

	# Travessas: leem como a estrutura que segura as faixas.
	for y in (RECUO + LINHA + 2, CELULA - 6):
		tela[y:y + 4, :, :3] = COR_PLACA
	tela[CELULA - 2:CELULA, :, :3] = COR_PLACA_ESCURA
	return Image.fromarray(tela, "RGBA")


def portao():
	folha = Image.new("RGBA", (4 * CELULA, 2 * CELULA), (0, 0, 0, 0))
	for linha, aberto in enumerate([False, True]):
		base = _pintar_portao(aberto)
		giros = [
			base,
			base.transpose(Image.ROTATE_270),
			base.transpose(Image.ROTATE_180),
			base.transpose(Image.ROTATE_90),
		]
		for coluna, imagem in enumerate(giros):
			folha.paste(imagem, (coluna * CELULA, linha * CELULA))
	folha.save(SAIDA + "/portao.png")


# --- detalhes do casco: canos, caixas e luzes -------------------------------

COR_CANO_FUNDO = (50, 62, 82)
COR_CANO_MEIO = (116, 127, 142)
COR_CANO_LUZ = (158, 168, 180)
COR_CANO_BRILHO = (194, 202, 212)
COR_CANO_BORDA = (9, 16, 29)
COR_CINTA = (66, 76, 92)
COR_CINTA_ALTA = (104, 116, 134)
COR_FERRUGEM = (118, 76, 52)
COR_FERRUGEM_ESCURA = (82, 54, 40)
COR_CAIXA = (129, 138, 151)
COR_CAIXA_ALTA = (168, 177, 188)
COR_CAIXA_BAIXA = (74, 85, 101)
COR_VISOR = (20, 32, 55)
COR_VISOR_LUZ = (108, 170, 219)
COR_LARANJA_FUNDO = (104, 48, 6)

## Eixo do cano e seu raio. O tubo nao cabe inteiro no recuo de 20 px: ele
## monta POR CIMA da borda externa do casco, invadindo uns 4 px da banda. E de
## proposito — assim le como tubulacao parafusada no casco, nao como desenho
## flutuando ao lado dele.
EIXO_CANO = 13
RAIO_CANO = 11

## Direcao da luz, igual para cano reto e para cotovelo. Sem isso o cotovelo
## sairia com o brilho girando junto com o tubo, que le como plastico.
LUZ = (-0.32, -0.95)

VARIANTES_DETALHE = 8


def _campo_tubo(segmentos):
	"""Para cada pixel: distancia ate a linha de centro do tubo e o quanto esse
	pixel esta virado para a luz."""
	ys, xs = np.mgrid[0:CELULA, 0:CELULA].astype(np.float32)
	melhor = np.full((CELULA, CELULA), 1e9, dtype=np.float32)
	ox = np.zeros((CELULA, CELULA), dtype=np.float32)
	oy = np.zeros((CELULA, CELULA), dtype=np.float32)
	for (ax, ay), (bx, by) in segmentos:
		dx, dy = float(bx - ax), float(by - ay)
		comprimento = max(dx * dx + dy * dy, 1e-6)
		t = np.clip(((xs - ax) * dx + (ys - ay) * dy) / comprimento, 0.0, 1.0)
		cx, cy = ax + t * dx, ay + t * dy
		dist = np.hypot(xs - cx, ys - cy)
		troca = dist < melhor
		melhor = np.where(troca, dist, melhor)
		ox = np.where(troca, xs - cx, ox)
		oy = np.where(troca, ys - cy, oy)
	norma = np.maximum(melhor, 1e-6)
	luz = (ox / norma) * LUZ[0] + (oy / norma) * LUZ[1]
	return melhor, np.where(melhor < 0.5, 0.35, luz)


def _pintar_tubo(tela, segmentos, semente, flanges=(), ambar=(), cintas=()):
	dist, luz = _campo_tubo(segmentos)
	ys, xs = np.mgrid[0:CELULA, 0:CELULA].astype(np.float32)

	# Ondulacao de periodo 64 no raio: o tubo perde a retidao de desenho
	# tecnico. Periodo 64 de proposito — qualquer outro quebraria a emenda
	# entre duas celulas da mesma corrida.
	raio = RAIO_CANO + 0.9 * np.sin(xs * (2.0 * np.pi / CELULA)) + 0.4 * np.sin(ys * (np.pi / CELULA))
	for x0, x1 in flanges:
		raio[:, x0:x1] += 4.0
	for x0, x1 in cintas:
		raio[:, x0:x1] += 2.0

	dentro = dist <= raio
	t = np.clip((luz + 1.0) * 0.5, 0.0, 1.0)

	# Rampa em tres faixas largas, nao num degrade continuo: cilindro de pixel
	# art le melhor em bandas chapadas, e o degrade continuo saiu lavado de
	# branco. A quarta faixa e so o fio de brilho.
	cor = np.zeros((CELULA, CELULA, 3), dtype=np.float32)
	for canal in range(3):
		faixa = np.where(t < 0.34, COR_CANO_FUNDO[canal], COR_CANO_MEIO[canal])
		faixa = np.where(t > 0.62, COR_CANO_LUZ[canal], faixa)
		cor[:, :, canal] = faixa

	reflexo = (luz > 0.90) & (luz < 0.99)
	for canal in range(3):
		cor[:, :, canal] = np.where(reflexo, COR_CANO_BRILHO[canal], cor[:, :, canal])

	_enferrujar(cor, dentro, t, semente)

	# Rebites na borda de cada flange, so onde ha tubo: posicao fixa poria
	# parafuso boiando no vazio quando o flange cai na ponta de uma curva.
	for x0, x1 in flanges:
		for parafuso in (x0 + 1, x1 - 3):
			for altura in (EIXO_CANO - 7, EIXO_CANO + 5):
				if not dentro[altura, parafuso]:
					continue
				cor[altura:altura + 2, parafuso:parafuso + 2] = COR_CANO_BORDA
				cor[altura, parafuso] = COR_CANO_LUZ
		# Aro do flange: duas linhas escuras fecham a peca nas pontas.
		for aro in (x0, x1 - 1):
			cor[:, aro] = np.where(dentro[:, aro, None], COR_CANO_BORDA, cor[:, aro])

	for x0, x1 in ambar:
		faixa = np.zeros((CELULA, CELULA), dtype=bool)
		faixa[:, x0:x1] = True
		# Mesma rampa do metal, so que entre dois tons de laranja: a faixa fica
		# cilindrica igual ao resto do tubo em vez de virar adesivo chapado.
		for canal in range(3):
			base = (
				COR_LARANJA_FUNDO[canal]
				+ (COR_LARANJA_CLARO[canal] - COR_LARANJA_FUNDO[canal]) * t
			)
			cor[:, :, canal] = np.where(faixa, base, cor[:, :, canal])

	for x0, x1 in cintas:
		abraca = np.zeros((CELULA, CELULA), dtype=bool)
		abraca[:, x0:x1] = True
		for canal in range(3):
			base = COR_CINTA[canal] + (COR_CINTA_ALTA[canal] - COR_CINTA[canal]) * t
			cor[:, :, canal] = np.where(abraca, base, cor[:, :, canal])
		for aro in (x0, x1 - 1):
			cor[:, aro] = np.where(dentro[:, aro, None], COR_CANO_BORDA, cor[:, aro])
		for parafuso in (x0 + 2, x1 - 4):
			for altura in (EIXO_CANO - 6, EIXO_CANO + 4):
				if dentro[altura, parafuso]:
					cor[altura:altura + 2, parafuso:parafuso + 2] = COR_CANO_BORDA

	# Contorno grosso embaixo e fino em cima: o tubo ganha peso sem perder o
	# fio de luz da quina de cima.
	contorno = (dist > raio - 1.2) | ((dist > raio - 2.2) & (luz < -0.1))
	for canal in range(3):
		cor[:, :, canal] = np.where(contorno, COR_CANO_BORDA[canal], cor[:, :, canal])

	tela[:, :, :3] = np.where(dentro[:, :, None], np.clip(cor, 0, 255).astype(np.uint8), tela[:, :, :3])
	tela[:, :, 3] = np.where(dentro, 255, tela[:, :, 3])


def _enferrujar(cor, dentro, t, semente):
	"""Ferrugem escorrida: riscos finos no eixo do tubo, nao bolhas redondas.

	Ja foi mancha circular grande e ficou lama. O que le como metal velho e um
	escorrido estreito e translucido, concentrado na metade de baixo, onde a
	sujeira se acumularia. Ficam a 8 px das bordas da celula: mancha cortada na
	divisa denunciaria o tile quando duas celulas se encostam.
	"""
	rng = random.Random(semente)
	for _ in range(rng.randint(2, 4)):
		cx = rng.randint(10, CELULA - 18)
		comprimento = rng.randint(5, 13)
		cy = EIXO_CANO + rng.randint(0, RAIO_CANO - 3)
		altura = rng.randint(1, 3)
		escura = rng.random() < 0.45
		alvo = COR_FERRUGEM_ESCURA if escura else COR_FERRUGEM
		peso = 0.3 if escura else 0.22
		for dy in range(altura):
			largura = comprimento - dy * 2
			for dx in range(largura):
				y, x = cy + dy, cx + dx
				if not (0 <= y < CELULA and 0 <= x < CELULA) or not dentro[y, x]:
					continue
				for canal in range(3):
					tom = alvo[canal] * (0.6 + 0.5 * t[y, x])
					cor[y, x, canal] = cor[y, x, canal] * (1.0 - peso) + tom * peso


def _pintar_caixa(tela):
	"""Caixa de juncao: moldura rebitada com visor afundado e tres luzes."""
	x0, x1, y0, y1 = 13, 51, 2, 27
	tela[y0:y1, x0:x1, :3] = COR_CAIXA
	tela[y0:y1, x0:x1, 3] = 255
	for borda in (y0, y1 - 1):
		tela[borda, x0:x1, :3] = COR_CANO_BORDA
	for borda in (x0, x1 - 1):
		tela[y0:y1, borda, :3] = COR_CANO_BORDA
	tela[y0 + 1, x0 + 1:x1 - 1, :3] = COR_CAIXA_ALTA
	tela[y1 - 4:y1 - 1, x0 + 1:x1 - 1, :3] = COR_CAIXA_BAIXA

	vx0, vx1, vy0, vy1 = x0 + 6, x1 - 6, y0 + 6, y1 - 8
	tela[vy0 - 1:vy1 + 1, vx0 - 1:vx1 + 1, :3] = COR_CANO_BORDA
	tela[vy0:vy1, vx0:vx1, :3] = COR_VISOR
	for i, cor in enumerate([COR_VISOR_LUZ, COR_LARANJA, COR_VISOR_LUZ]):
		lx = vx0 + 2 + i * 8
		tela[vy0 + 2:vy0 + 7, lx:lx + 5, :3] = cor
		tela[vy0 + 2, lx:lx + 5, :3] = _mistura(cor, (255, 255, 255), 0.4)

	for bx in range(x0 + 3, x1 - 3, 7):
		for by in (y0 + 3, y1 - 5):
			tela[by:by + 2, bx:bx + 2, :3] = COR_CAIXA_BAIXA
			tela[by, bx, :3] = COR_CAIXA_ALTA

	rng = random.Random(777)
	for _ in range(7):
		mx = rng.randint(x0 + 2, x1 - 4)
		my = rng.randint(y0 + 2, y1 - 3)
		if vx0 - 1 <= mx < vx1 + 1 and vy0 - 1 <= my < vy1 + 1:
			continue
		tela[my, mx:mx + rng.randint(1, 3), :3] = COR_FERRUGEM_ESCURA


def _pintar_luz_interna(tela):
	"""Luminaria na face interna da parede, virada para o piso da sala."""
	x0, x1 = 14, CELULA - 14
	tela[CELULA - 9, x0:x1, :3] = COR_PLACA_ESCURA
	tela[CELULA - 8:CELULA - 6, x0:x1, :3] = COR_LINHA
	tela[CELULA - 6:CELULA - 3, x0:x1, :3] = COR_LARANJA
	tela[CELULA - 5, x0 + 1:x1 - 1, :3] = COR_LARANJA_CLARO
	tela[CELULA - 3:CELULA - 1, x0:x1, :3] = COR_LINHA
	tela[CELULA - 1, x0:x1, :3] = COR_PLACA_ESCURA
	tela[CELULA - 9:CELULA, x0 - 1, :3] = COR_PLACA_ESCURA
	tela[CELULA - 9:CELULA, x1, :3] = COR_PLACA_ESCURA
	tela[CELULA - 9:CELULA, x0 - 1:x1 + 1, 3] = 255


def _pintar_detalhe(variante):
	tela = np.zeros((CELULA, CELULA, 4), dtype=np.uint8)
	reto = [((0, EIXO_CANO), (CELULA, EIXO_CANO))]
	semente = 600 + variante
	if variante == 0:
		_pintar_tubo(tela, reto, semente)
	elif variante == 1:
		_pintar_tubo(tela, reto, semente, flanges=[(23, 31), (37, 45)])
	elif variante == 2:
		_pintar_tubo(tela, reto, semente, flanges=[(18, 25), (41, 48)], ambar=[(25, 41)])
	elif variante == 3:
		_pintar_tubo(tela, reto, semente, cintas=[(26, 40)])
		_pernas_da_cinta(tela, 26, 40)
	elif variante == 4:
		# Cotovelo: o tubo desce para dentro da parede e some. O flange e
		# desenhado a mao porque o parametro flanges trabalha em faixa de x, e
		# numa descida vertical ele engrossaria o trecho inteiro em vez do fim.
		_pintar_tubo(tela, [
			((18, 32), (18, EIXO_CANO)), ((18, EIXO_CANO), (CELULA, EIXO_CANO)),
		], semente)
		_colar_do_cotovelo(tela, 18, 28)
	elif variante == 5:
		_pintar_tubo(tela, [
			((46, 32), (46, EIXO_CANO)), ((46, EIXO_CANO), (0, EIXO_CANO)),
		], semente)
		_colar_do_cotovelo(tela, 46, 28)
	elif variante == 6:
		_pintar_caixa(tela)
	else:
		_pintar_luz_interna(tela)
	return Image.fromarray(tela, "RGBA")


def _colar_do_cotovelo(tela, eixo, base):
	"""Colar no fim da descida do cotovelo, onde o tubo entra na parede."""
	largura = RAIO_CANO + 3
	for altura in (base, base + 5):
		for dx in range(-largura, largura + 1):
			x = eixo + dx
			if not (0 <= x < CELULA):
				continue
			tela[altura:altura + 4, x, :3] = COR_CINTA
			tela[altura:altura + 4, x, 3] = 255
			tela[altura, x, :3] = COR_CINTA_ALTA
			if abs(dx) >= largura - 1:
				tela[altura:altura + 4, x, :3] = COR_CANO_BORDA


def _pernas_da_cinta(tela, x0, x1):
	"""Pe da cinta: duas chapas que descem do tubo e entram no casco."""
	base = EIXO_CANO + RAIO_CANO - 2
	for x in (x0 + 1, x1 - 6):
		tela[base:base + 8, x - 1:x + 6, :3] = COR_CANO_BORDA
		tela[base:base + 8, x - 1:x + 6, 3] = 255
		tela[base:base + 7, x:x + 5, :3] = COR_CINTA
		tela[base:base + 2, x:x + 5, :3] = COR_CINTA_ALTA


def detalhes():
	folha = Image.new("RGBA", (VARIANTES_DETALHE * CELULA, 4 * CELULA), (0, 0, 0, 0))
	for variante in range(VARIANTES_DETALHE):
		base = _pintar_detalhe(variante)
		giros = [
			base,
			base.transpose(Image.ROTATE_270),
			base.transpose(Image.ROTATE_180),
			base.transpose(Image.ROTATE_90),
		]
		for linha, imagem in enumerate(giros):
			folha.paste(imagem, (variante * CELULA, linha * CELULA))
	folha.save(SAIDA + "/detalhes.png")


# --- obra: os tres estagios antes do piso ------------------------------------

COR_VIGA = (84, 97, 117)
COR_VIGA_ALTA = (124, 140, 163)
COR_VIGA_BAIXA = (49, 60, 78)
COR_CHAPA_CRUA = (88, 106, 131)
COR_CHAPA_CRUA_ALTA = (104, 123, 149)
COR_SOLDA = (168, 152, 108)

VARIACOES_OBRA = 4


def _estrutura(tela, rng):
	"""Estagio 2: as vigas ja fecham a celula, mas ainda se ve o espaco pelos
	vaos. E o unico estagio em que o buraco entre as vigas e a leitura toda."""
	# Grade de vigas com a luz vindo de cima, igual ao casco.
	passo = 16
	for x in range(CELULA):
		for y in range(CELULA):
			na_viga = (x % passo) < 6 or (y % passo) < 6 or x < 4 or y < 4
			na_viga = na_viga or x >= CELULA - 4 or y >= CELULA - 4
			if not na_viga:
				continue
			topo = (y % passo) < 2 or y < 2
			base = (y % passo) >= 4 and (y % passo) < 6
			cor = COR_VIGA
			if topo:
				cor = COR_VIGA_ALTA
			elif base:
				cor = COR_VIGA_BAIXA
			tela[y, x, :3] = cor
			tela[y, x, 3] = 255

	for _ in range(rng.randint(2, 4)):
		x = rng.randint(2, CELULA - 10)
		y = rng.randint(2, CELULA - 4)
		if tela[y, x, 3] == 0:
			continue
		tela[y:y + 2, x:x + 6, :3] = COR_SOLDA


def _acabamento(tela, rng):
	"""Estagio 3: chapa inteira assentada, ainda crua — sem junta de piso, com
	marca de solda e um canto por rebarbar."""
	ruido = np.array(
		[[rng.randint(-5, 5) for _ in range(CELULA)] for _ in range(CELULA)], dtype=np.int16
	)
	tela[:, :, :3] = np.clip(np.array(COR_CHAPA_CRUA, dtype=np.int16) + ruido[:, :, None], 0, 255)
	tela[:, :, 3] = 255
	tela[0:2, :, :3] = COR_CHAPA_CRUA_ALTA
	tela[CELULA - 2:CELULA, :, :3] = COR_VIGA_BAIXA
	tela[:, 0:2, :3] = COR_CHAPA_CRUA_ALTA
	tela[:, CELULA - 2:CELULA, :3] = COR_VIGA_BAIXA

	for _ in range(rng.randint(2, 4)):
		x = rng.randint(6, CELULA - 20)
		y = rng.randint(6, CELULA - 8)
		tela[y:y + 2, x:x + rng.randint(8, 16), :3] = COR_SOLDA

	canto = rng.randint(0, 3)
	cx = 4 if canto % 2 == 0 else CELULA - 18
	cy = 4 if canto < 2 else CELULA - 18
	tela[cy:cy + 14, cx:cx + 14, :3] = COR_VIGA
	tela[cy:cy + 2, cx:cx + 14, :3] = COR_VIGA_ALTA


def obra():
	"""Duas linhas, nao tres: DEMARCADO saiu daqui para demarcacao.png, que e
	indexado pela vizinhanca. A linha 0 e ESTRUTURA e a linha 1 e ACABAMENTO."""
	etapas = [_estrutura, _acabamento]
	folha = Image.new("RGBA", (VARIACOES_OBRA * CELULA, len(etapas) * CELULA), (0, 0, 0, 0))
	for linha, etapa in enumerate(etapas):
		for coluna in range(VARIACOES_OBRA):
			tela = np.zeros((CELULA, CELULA, 4), dtype=np.uint8)
			etapa(tela, random.Random(3300 + linha * 10 + coluna))
			folha.paste(Image.fromarray(tela, "RGBA"), (coluna * CELULA, linha * CELULA))
	folha.save(SAIDA + "/obra.png")


# --- demarcacao: a baliza do canteiro, indexada pela vizinhanca ---------------

COR_CANTEIRO = (16, 26, 46)
ALFA_CANTEIRO = 96
COR_GRADE = (104, 134, 170)
ALFA_GRADE = 46

## Profundidade do trilho de baliza a partir da borda aberta da celula.
TRILHO = 5

## Comprimento do traco ambar. O periodo e o dobro e precisa dividir CELULA,
## senao o trilho sai desalinhado na emenda entre duas celulas da mesma divisa.
TRACO = 8


def _baliza(tela, cx, cy):
	"""Poste de canto: quadrado escuro com a luz ambar no miolo."""
	for y in range(cy - 4, cy + 5):
		for x in range(cx - 4, cx + 5):
			if 0 <= x < CELULA and 0 <= y < CELULA:
				tela[y, x, :3] = COR_FAIXA_ESCURA
				tela[y, x, 3] = 255
	for y in range(cy - 2, cy + 3):
		for x in range(cx - 2, cx + 3):
			if 0 <= x < CELULA and 0 <= y < CELULA:
				tela[y, x, :3] = COR_LARANJA
	if 0 <= cy - 2 < CELULA:
		tela[cy - 2, max(cx - 2, 0):cx + 3, :3] = COR_LARANJA_CLARO


def _demarcacao(mascara):
	"""Primeiro estagio da obra: a area esta demarcada e mais nada.

	Indexado pela mascara de 8 bits da vizinhanca, igual ao casco e a borda —
	bit ligado quer dizer lado virado para FORA do canteiro. E por isso que nao
	ha mais cantoneira em cada celula: marcar celula a celula fazia as quatro
	pontas de quatro vizinhas se encontrarem no miolo da area e nascer um '+'
	ambar no meio do nada. Aqui o trilho so aparece na divisa do canteiro, que e
	justamente onde a parede vai subir.
	"""
	tela = np.zeros((CELULA, CELULA, 4), dtype=np.uint8)
	tela[:, :, :3] = COR_CANTEIRO
	tela[:, :, 3] = ALFA_CANTEIRO

	# Grade de planta: so no topo e na esquerda, como a junta do piso, para duas
	# celulas vizinhas desenharem uma linha so.
	tela[0, :, :3] = COR_GRADE
	tela[0, :, 3] = ALFA_GRADE
	tela[:, 0, :3] = COR_GRADE
	tela[:, 0, 3] = ALFA_GRADE

	aberto = [bool(mascara & (1 << INDICE[d])) for d in CARDEAIS]
	for i, (dx, dy) in enumerate(CARDEAIS):
		if not aberto[i]:
			continue
		for ao_longo in range(CELULA):
			# Todo o ambar do trilho num lugar so: o traco acende, o resto fica
			# escuro. Ambar espalhado pelo trilho inteiro vira zebra.
			aceso = (ao_longo % (2 * TRACO)) < TRACO
			for espessura in range(3):
				profundidade = TRILHO + espessura
				if dx != 0:
					x = (CELULA - 1 - profundidade) if dx > 0 else profundidade
					y = ao_longo
				else:
					x = ao_longo
					y = (CELULA - 1 - profundidade) if dy > 0 else profundidade
				cor = COR_FAIXA_ESCURA
				if aceso:
					cor = COR_LARANJA_CLARO if espessura == 1 else COR_LARANJA
				tela[y, x, :3] = cor
				tela[y, x, 3] = 255

	# Poste onde dois lados abertos se encontram: ali e canto da area, e e o
	# unico ponto em que o trilho precisa de uma peca propria.
	meio = TRILHO + 1
	longe = CELULA - 1 - meio
	cantos = [(0, 3, meio, meio), (0, 1, longe, meio), (2, 1, longe, longe), (2, 3, meio, longe)]
	for a, b, cx, cy in cantos:
		if aberto[a] and aberto[b]:
			_baliza(tela, cx, cy)
	return Image.fromarray(tela, "RGBA")


def demarcacao():
	folha = Image.new("RGBA", (LADO_ATLAS * CELULA, LADO_ATLAS * CELULA), (0, 0, 0, 0))
	for mascara in range(256):
		destino = ((mascara % LADO_ATLAS) * CELULA, (mascara // LADO_ATLAS) * CELULA)
		folha.paste(_demarcacao(mascara), destino)
	folha.save(SAIDA + "/demarcacao.png")


# --- cones: o piso avisa onde acaba o chao -----------------------------------

COR_CONE_SOMBRA = (164, 82, 6)
COR_CONE_BASE = (118, 55, 10)
COR_CONE_BASE_LUZ = (158, 79, 18)
COR_FAIXA_BRANCA = (236, 240, 245)

## Faixa pintada no piso: comeca depois da sombra de contato da parede, que
## alcanca 7 px, senao as duas se somam e a faixa some no escuro.
FAIXA_INICIO = 9
FAIXA_FIM = 16

## Tinta gasta, nao plastico novo: ambar rebaixado e alfa parcial. Na saturacao
## cheia a faixa domina a sala inteira assim que a estacao tem alguns furos.
COR_FAIXA_PISO = (201, 113, 13)
ALFA_FAIXA = 180

ALTURA_CONE = 18


def _cone(tela, cx, base_y):
	"""Cone de obra em tres quartos: base achatada, corpo em faixas chapadas e
	uma cinta branca. Degrade continuo lava o volume neste tamanho."""
	for dy in range(-3, 4):
		largura = 10 - abs(dy) * 2
		for x in range(cx - largura, cx + largura + 1):
			y = base_y + dy
			if 0 <= x < CELULA and 0 <= y < CELULA:
				tela[y, x, :3] = COR_CONE_BASE_LUZ if dy <= -2 else COR_CONE_BASE
				tela[y, x, 3] = 255

	for k in range(ALTURA_CONE):
		y = base_y - 3 - k
		meia = max(1, int(round(7.0 - k * 6.0 / (ALTURA_CONE - 1))))
		for x in range(cx - meia, cx + meia + 1):
			if not (0 <= x < CELULA and 0 <= y < CELULA):
				continue
			if 7 <= k <= 10:
				cor = COR_FAIXA_BRANCA if x > cx - meia else (255, 255, 255)
			elif x <= cx - meia:
				cor = COR_LARANJA_CLARO
			elif x >= cx + meia:
				cor = COR_CONE_SOMBRA
			else:
				cor = COR_LARANJA
			tela[y, x, :3] = cor
			tela[y, x, 3] = 255

	ponta = base_y - 3 - ALTURA_CONE
	if 0 <= ponta < CELULA:
		tela[ponta, max(cx - 1, 0):cx + 2, :3] = COR_LARANJA_CLARO
		tela[ponta, max(cx - 1, 0):cx + 2, 3] = 255


## Onde o cone de cada lado fica, na ordem de CARDEAIS. O cone sempre sobra para
## dentro da sala: do lado sul ele precisa ficar ANTES da faixa, ou taparia a
## propria marcacao vista de cima.
POSICAO_CONE = [(32, 38), (40, 42), (32, 46), (24, 42)]


def _cones(mascara):
	"""Faixa de perigo e cone no piso que encosta no vazio. A colisao ja impede
	a passagem; isto e o aviso, que a colisao sozinha nao da."""
	tela = np.zeros((CELULA, CELULA, 4), dtype=np.uint8)
	lados = [i for i in range(4) if mascara & (1 << i)]

	for i in lados:
		dx, dy = CARDEAIS[i]
		for profundidade in range(FAIXA_INICIO, FAIXA_FIM):
			for ao_longo in range(CELULA):
				if dx != 0:
					x = (CELULA - 1 - profundidade) if dx > 0 else profundidade
					y = ao_longo
				else:
					x = ao_longo
					y = (CELULA - 1 - profundidade) if dy > 0 else profundidade
				# Listra a 45 graus com periodo 16: divide 64, entao a faixa
				# atravessa a emenda entre duas celulas sem degrau.
				claro = ((ao_longo + profundidade) // 8) % 2 == 0
				tela[y, x, :3] = COR_FAIXA_PISO if claro else COR_FAIXA_ESCURA
				tela[y, x, 3] = ALFA_FAIXA

	# Dois cones de lados diferentes caem quase no mesmo lugar e saem grudados.
	# Com mais de um lado aberto fica um cone so, no meio: a faixa ja diz por
	# onde o chao acaba, o cone so precisa dizer que ali nao se passa.
	if len(lados) == 1:
		_cone(tela, POSICAO_CONE[lados[0]][0], POSICAO_CONE[lados[0]][1])
	elif lados:
		_cone(tela, 32, 42)
	return Image.fromarray(tela, "RGBA")


def cones():
	folha = Image.new("RGBA", (16 * CELULA, CELULA), (0, 0, 0, 0))
	for mascara in range(16):
		folha.paste(_cones(mascara), (mascara * CELULA, 0))
	folha.save(SAIDA + "/cones.png")


# --- marcacao: o lugar reservado para parede ou porta ------------------------

COR_RESERVA = (14, 22, 40)
ALFA_RESERVA = 50

## Profundidade da fita a partir da borda aberta. Fica rente a divisa porque a
## marcacao e do lugar inteiro: celulas encostadas precisam formar um retangulo
## so, nao um quadrado dentro do outro.
FITA_INICIO = 2
FITA_FIM = 10
ALFA_FITA = 200


def _marcacao(mascara, reservar=True):
	"""Fita de obra de parede e de porta.

	Indexado pela mascara dos quatro lados — bit ligado quer dizer lado que NAO
	faz parte da mesma marcacao. Assim uma parede de seis celulas sai com uma
	fita so em volta das seis, e nao com seis quadradinhos em fila.

	Com reservar, o miolo ganha a sombra de area reservada: e a primeira fase,
	em que nao ha nada alem da marca. Sem ela sobra so a fita, para a segunda
	fase — ali ja existe peca por baixo, e a sombra escondia justamente ela.
	"""
	tela = np.zeros((CELULA, CELULA, 4), dtype=np.uint8)
	if reservar:
		tela[:, :, :3] = COR_RESERVA
		tela[:, :, 3] = ALFA_RESERVA

	aberto = [bool(mascara & (1 << i)) for i in range(4)]
	for i, (dx, dy) in enumerate(CARDEAIS):
		if not aberto[i]:
			continue
		for profundidade in range(FITA_INICIO, FITA_FIM):
			for ao_longo in range(CELULA):
				if dx != 0:
					x = (CELULA - 1 - profundidade) if dx > 0 else profundidade
					y = ao_longo
				else:
					x = ao_longo
					y = (CELULA - 1 - profundidade) if dy > 0 else profundidade
				# Mesma listra a 45 graus dos cones, e pelo mesmo motivo: periodo
				# 16 divide 64, entao a fita atravessa a emenda sem degrau.
				claro = ((ao_longo + profundidade) // 8) % 2 == 0
				tela[y, x, :3] = COR_FAIXA_PISO if claro else COR_FAIXA_ESCURA
				tela[y, x, 3] = ALFA_FITA

	# Prego de canto onde duas fitas se encontram: e ali que a marcacao vira.
	meio = (FITA_INICIO + FITA_FIM) // 2
	longe = CELULA - 1 - meio
	cantos = [(0, 3, meio, meio), (0, 1, longe, meio), (2, 1, longe, longe), (2, 3, meio, longe)]
	for a, b, cx, cy in cantos:
		if not (aberto[a] and aberto[b]):
			continue
		for y in range(cy - 2, cy + 3):
			for x in range(cx - 2, cx + 3):
				if 0 <= x < CELULA and 0 <= y < CELULA:
					tela[y, x, :3] = COR_LARANJA_CLARO
					tela[y, x, 3] = 255
	return Image.fromarray(tela, "RGBA")


def marcacao():
	folha = Image.new("RGBA", (16 * CELULA, 2 * CELULA), (0, 0, 0, 0))
	for mascara in range(16):
		folha.paste(_marcacao(mascara, True), (mascara * CELULA, 0))
		folha.paste(_marcacao(mascara, False), (mascara * CELULA, CELULA))
	folha.save(SAIDA + "/marcacao.png")


# --- buraco: vao aberto para o espaco, com parede em volta --------------------

def _pintar_buraco(mascara):
	"""Rombo cercado pela estacao: o centro fica aberto e a borda e parede.

	A mascara tem quatro bits — bit ligado quer dizer lado que encosta na
	estacao. Nesses lados a parede recua RECUO a partir da divisa, igual ao
	casco; nos outros o vao segue inteiro ate a borda da celula, para duas
	celulas de buraco encostadas abrirem um vao so.

	A primeira versao desenhava a borda rasgada, como chapa arrancada. O jogador
	leu aquilo como obra que travou. Reusar o perfil do casco e o que faz o vao
	ler como acabado: a estacao fechou a parede em volta dele.
	"""
	encosta = [bool(mascara & (1 << i)) for i in range(4)]

	solido = np.zeros((3 * CELULA, 3 * CELULA), dtype=bool)
	solido[CELULA:2 * CELULA, CELULA:2 * CELULA] = True
	x0 = RECUO if encosta[3] else 0
	x1 = CELULA - RECUO if encosta[1] else CELULA
	y0 = RECUO if encosta[0] else 0
	y1 = CELULA - RECUO if encosta[2] else CELULA
	solido[CELULA + y0:CELULA + y1, CELULA + x0:CELULA + x1] = False

	def macica(direcao):
		bx, by = (direcao[0] + 1) * CELULA, (direcao[1] + 1) * CELULA
		solido[by:by + CELULA, bx:bx + CELULA] = True
		return bx, by

	for i, (dx, dy) in enumerate(CARDEAIS):
		bx, by = macica((dx, dy))
		if encosta[i]:
			continue
		# Vizinha que tambem e vao: a abertura atravessa a divisa. Prolongar a
		# abertura do centro para dentro dela e o que mantem a parede inteira —
		# sem isso nasce uma faixa clara de borda no meio do proprio vao.
		if dx != 0:
			solido[by + y0:by + y1, bx:bx + CELULA] = False
		else:
			solido[by:by + CELULA, bx + x0:bx + x1] = False

	for dx, dy in [(1, -1), (1, 1), (-1, 1), (-1, -1)]:
		# A diagonal e assumida macica, menos quando os DOIS lados dela sao vao:
		# ai ela quase sempre faz parte do mesmo vao. Uma mascara de quatro bits
		# nao sabe mais do que isso, e assumir vazio por padrao punha um degrau
		# de borda em todo canto de buraco encostado noutro.
		if not encosta[CARDEAIS.index((dx, 0))] and not encosta[CARDEAIS.index((0, dy))]:
			continue
		macica((dx, dy))

	# Sem chapa aparafusada: a borda tem 20 px, e o painel sairia espremido na
	# moldura em vez de assentado no meio de uma placa.
	return _perfil_de_parede(solido, 7100 + mascara, painel=False)


def buraco():
	folha = Image.new("RGBA", (16 * CELULA, CELULA), (0, 0, 0, 0))
	for mascara in range(16):
		folha.paste(_pintar_buraco(mascara), (mascara * CELULA, 0))
	folha.save(SAIDA + "/buraco.png")


# --- icones das ferramentas de construcao ------------------------------------

SAIDA_INTERFACE = "assets/interface"
ICONE = 32
COR_ICONE = (219, 232, 247)
COR_ICONE_FRACA = (122, 146, 176)
COR_ICONE_PISO = (99, 130, 166)
COR_ICONE_VERMELHO = (236, 112, 112)


def _icone_expandir(p):
	# Quadrado cheio no canto e moldura tracejada grande: a ferramenta cresce a
	# area, e o tracejado e a mesma linguagem do retangulo de selecao.
	for y in range(17, 27):
		for x in range(5, 15):
			p(x, y, COR_ICONE_PISO)
			if x in (5, 14) or y in (17, 26):
				p(x, y, COR_ICONE)
	for i in range(5, 27):
		if (i // 3) % 2 == 0:
			p(i, 5, COR_ICONE_FRACA)
			p(26, i, COR_ICONE_FRACA)
	for i in range(5, 27):
		if (i // 3) % 2 == 0:
			p(i, 26, COR_ICONE_FRACA)
			p(5, i, COR_ICONE_FRACA)
	# Seta apontando para o canto vazio.
	for k in range(7):
		p(13 + k, 14 - k, COR_ICONE)
		p(14 + k, 14 - k, COR_ICONE)
	for k in range(5):
		p(19 + k, 8, COR_ICONE)
		p(23, 8 + k, COR_ICONE)


def _icone_divisoria(p):
	for y in range(4, 28):
		for x in range(11, 22):
			borda = x in (11, 21) or y in (4, 27)
			p(x, y, COR_ICONE if borda else COR_ICONE_FRACA)
	for y in (11, 12, 19, 20):
		for x in range(12, 21):
			p(x, y, COR_ICONE)
	for y, x in [(7, 15), (16, 17), (24, 15)]:
		p(x, y, COR_ICONE)
		p(x + 1, y, COR_ICONE)


def _icone_porta(p):
	for y in range(5, 27):
		for x in list(range(7, 13)) + list(range(19, 25)):
			borda = x in (7, 12, 19, 24) or y in (5, 26)
			p(x, y, COR_ICONE if borda else COR_ICONE_FRACA)
	for y in range(7, 25):
		p(15, y, COR_LARANJA)
		p(16, y, COR_LARANJA)


def _icone_portao(p):
	for y in range(8, 24):
		for x in range(5, 27):
			if x in (5, 26) or y in (8, 23):
				p(x, y, COR_ICONE)
			elif ((x + y) // 4) % 2 == 0:
				p(x, y, COR_LARANJA)
			else:
				p(x, y, (44, 52, 68))


def _icone_remover(p):
	for i in range(20):
		for e in range(3):
			p(6 + i + e, 6 + i, COR_ICONE_VERMELHO)
			p(6 + i + e, 25 - i, COR_ICONE_VERMELHO)


def _icone_construcao(p):
	# Martelo e chave de boca CRUZADOS: o icone do MODO, e nao de uma ferramenta
	# dele. Por isso nao e nenhum dos cinco desenhos acima — se fosse o do
	# "expandir", o atalho de abrir o modo leria como a ferramenta de expandir.
	#
	# Cabo em laranja e cabeca em aco: e a mesma divisao de cor que o resto do
	# jogo usa para separar o que se pega do que trabalha. E os dois cabos tem
	# de se CRUZAR no meio — na primeira versao eles sairam das cabecas para
	# baixo sem se encontrar, e o par lia como dois objetos soltos num V.
	def cabo(x0, y0, passos, para):
		for k in range(passos):
			x = x0 + para * k
			y = y0 + k
			for e in range(3):
				p(x + para * e, y, COR_LARANJA)
			p(x, y, COR_LARANJA_CLARO)

	cabo(21, 12, 17, -1)
	cabo(10, 10, 18, 1)

	# Cabeca do martelo, em cima a esquerda. MACICA: a primeira versao tinha a
	# unha partida, e o vao em U deixava a peca com cara de colchete — ao lado da
	# boca da chave, o par lia como duas letras em vez de duas ferramentas.
	for y in range(3, 12):
		for x in range(3, 13):
			borda = x in (3, 12) or y in (3, 11)
			p(x, y, COR_ICONE if borda else COR_ICONE_FRACA)
	# Pescoco estreito entre a cabeca e o cabo: sem ele o cabo sai do meio de um
	# tijolo, e a cabeca nao le como peca encaixada.
	for y in range(5, 10):
		p(13, y, COR_ICONE)
	for x in range(5, 11):
		p(x, 4, COR_ICONE_PISO)

	# Cabeca da chave, em cima a direita, com a boca aberta para cima.
	for y in range(3, 13):
		for x in range(18, 27):
			borda = x in (18, 26) or y in (3, 12)
			p(x, y, COR_ICONE if borda else COR_ICONE_FRACA)
	for y in range(3, 9):
		for x in range(21, 24):
			p(x, y, None)
		p(20, y, COR_ICONE)
		p(24, y, COR_ICONE)


def icones():
	import os

	os.makedirs(SAIDA_INTERFACE, exist_ok=True)
	# A ordem e o contrato com scripts/modo_construcao.gd: indice -> celula. As
	# cinco primeiras sao as ferramentas, na ordem das teclas 1 a 5; a sexta e o
	# icone do modo inteiro, que o atalho de abrir a construcao usa.
	desenhos = [
		_icone_expandir, _icone_divisoria, _icone_porta, _icone_portao,
		_icone_remover, _icone_construcao,
	]
	folha = Image.new("RGBA", (len(desenhos) * ICONE, ICONE), (0, 0, 0, 0))
	for indice, desenho in enumerate(desenhos):
		tela = np.zeros((ICONE, ICONE, 4), dtype=np.uint8)

		def pixel(x, y, cor, _tela=tela):
			if not (0 <= x < ICONE and 0 <= y < ICONE):
				return
			# Cor None apaga: um desenho que se sobrepoe a si mesmo precisa poder
			# abrir vao, como a boca da chave de boca.
			if cor is None:
				_tela[y, x, :] = 0
				return
			_tela[y, x, :3] = cor[:3]
			_tela[y, x, 3] = 255

		desenho(pixel)
		folha.paste(Image.fromarray(tela, "RGBA"), (indice * ICONE, 0))
	folha.save(SAIDA_INTERFACE + "/ferramentas.png")


if __name__ == "__main__":
	print("gerando em", SAIDA)
	casco()
	borda()
	piso()
	porta()
	portao()
	detalhes()
	obra()
	demarcacao()
	marcacao()
	cones()
	buraco()
	icones()
	print("ok")
