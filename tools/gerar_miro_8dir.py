# Gera assets/sprites/miro_8dir.png a partir de
# docs/sprites-paste/sprite-miro-walking.png.
#
# Folha de origem: 792x2880, grade EXATA de 4 colunas por 8 linhas, celulas de
# 198x360. As linhas 0 a 3 repetem, pixel a pixel nas medidas, a folha anterior
# (docs/miro-sprite.png); as linhas 4 a 7 sao as diagonais, novas.
#
# POR QUE A GRADE E ARITMETICA E NAO POR FAIXAS VAZIAS
#
# folha_miro.figuras() separa os desenhos por faixas totalmente vazias. Isso
# funciona enquanto sobra folga entre os desenhos, e nesta folha NAO sobra: a
# figura mais apertada (linha 3, coluna 2) chega a 1 px da borda esquerda e a
# 1 px da direita da propria celula, e ha pixels a menos de 3 px de quatro das
# linhas de corte. Com folga de 1 px, qualquer desenho que encoste no vizinho
# funde as duas faixas e o recorte sai com dois personagens — ou, pior, com uma
# tira do vizinho colada na borda.
#
# Como a grade aqui e exata e verificavel, o recorte e aritmetico e a folha e
# AUDITADA em _conferir_vazamento(): se algum desenho atravessar uma linha de
# corte, a geracao para em vez de produzir sprite sujo em silencio.
#
# ORDEM DAS DIRECOES (medida, nao suposta)
#
#   linha 0  baixo      rosto centrado (centroide de pele em 0,48 da largura)
#   linha 1  direita    rosto em 0,59
#   linha 2  cima       zero pixel de pele — e a nuca
#   linha 3  esquerda   rosto em 0,43
#   linha 4  baixo-dir  rosto em 0,56, ombros largos (frontal, virado a direita)
#   linha 5  baixo-esq  rosto em 0,34
#   linha 6  cima-dir   zero pixel de pele
#   linha 7  cima-esq   30 pixels de pele em 0,26 — a bochecha espiando a
#                       ESQUERDA de quem olha, que e o que aparece quando as
#                       costas giram para noroeste
#
# Os pares foram confirmados por espelhamento: a silhueta espelhada de cada
# linha bate melhor com a sua par do que com qualquer outra (direita/esquerda
# 0,89; baixo-dir/baixo-esq 0,91; cima-dir/cima-esq 0,88), e baixo e cima dao
# consigo mesmas. A folha tambem e consistente na ordem: em cada par a versao
# da direita vem primeiro.
#
# ORDEM DA ANIMACAO — este e o ponto fraco, e esta assumido
#
# Nas linhas 0 a 3 da para medir: as colunas 0 e 1 tem a figura mais alta e os
# dois pes plantados e separados (contato), as colunas 2 e 3 sao ~11 px mais
# baixas e com os pes fundidos num blob so (passagem, um pe cruzando o outro).
# Dai o ciclo contato, passagem, contato, passagem: [0, 2, 1, 3].
#
# Nas linhas 4 a 7 essa medida nao decide nada: a vista de tres quartos comprime
# a passada e as quatro figuras ficam na mesma altura (cima-dir: 342, 342, 343,
# 343). Testei deduzir a ordem por suavidade do ciclo e o metodo foi reprovado —
# ele nao recupera [0, 2, 1, 3] nem nas linhas onde a resposta e conhecida, e as
# margens entre as ordens candidatas sao ruido (0,3751 contra 0,3768).
#
# Entao ORDEM vale para as oito linhas por ASSUNCAO de que a folha e desenhada
# com o mesmo layout em todas elas — o que as linhas 0 a 3 sustentam, por serem
# identicas as da folha anterior. Se a caminhada em diagonal sair com um
# tranco, e aqui que se mexe.
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import folha_miro

ORIGEM = "docs/sprites-paste/sprite-miro-walking.png"
SAIDA = "assets/sprites/miro_8dir.png"

COLUNAS: int = 4
LINHAS: int = 8

## Nomes das linhas, na ordem da folha. Viram a ordem do enum Vista em
## scripts/jogador.gd — mexer aqui exige mexer la.
DIRECOES: list[str] = [
	"baixo",
	"direita",
	"cima",
	"esquerda",
	"baixo_direita",
	"baixo_esquerda",
	"cima_direita",
	"cima_esquerda",
]

## Ordem de animacao dentro de cada linha, em indices da ordem de leitura.
ORDEM: list[int] = [0, 2, 1, 3]

## Folga em cada lado da celula final, em pixels da folha de origem.
MARGEM: int = 20

## Folga acima da cabeca, em pixels da folha de origem (~3 px no sprite final).
##
## Sem ela as figuras mais altas (linhas esquerda e cima-esquerda) encostavam no
## topo da celula com folga zero: a altura da celula nascia da propria figura
## mais alta, entao o arredondamento da reducao comia o pixel de cima do cabelo.
## A base NAO leva folga — ali o encosto e de proposito, e a linha do chao.
MARGEM_TOPO: int = 12

## Manchas soltas menores que isto sao descartadas. A folha tem exatamente uma:
## um pixel isolado cor (24, 50, 55) na linha 4, coluna 0. E sujeira do desenho,
## nao pedaco de vizinho — o vizinho mais proximo esta a dezenas de pixels.
RUIDO_MAXIMO: int = 8


def _celulas() -> list[Image.Image]:
	"""Corta as 32 celulas na grade aritmetica, sem heuristica nenhuma."""
	folha = Image.open(ORIGEM).convert("RGBA")
	largura, altura = folha.size
	assert largura % COLUNAS == 0 and altura % LINHAS == 0, (
		f"folha {largura}x{altura} nao divide em {COLUNAS}x{LINHAS}"
	)
	cw, ch = largura // COLUNAS, altura // LINHAS
	return [
		folha.crop((c * cw, l * ch, (c + 1) * cw, (l + 1) * ch))
		for l in range(LINHAS)
		for c in range(COLUNAS)
	]


def _conferir_vazamento() -> None:
	"""Falha se algum desenho atravessar uma linha de corte da grade.

	Um desenho cortado deixa rastro: existe uma linha de pixels ocupada dos dois
	lados da linha de corte, ou seja, o traco continua de uma celula para a
	outra. E a unica evidencia direta de vazamento, e vale mais que olhar folga:
	folga pequena incomoda, folga atravessada estraga.
	"""
	folha = Image.open(ORIGEM).convert("RGBA")
	alfa = folha.getchannel("A").load()
	largura, altura = folha.size
	cw, ch = largura // COLUNAS, altura // LINHAS

	for c in range(1, COLUNAS):
		x = c * cw
		cruza = [y for y in range(altura) if alfa[x - 1, y] > 0 and alfa[x, y] > 0]
		assert not cruza, f"desenho atravessa o corte vertical x={x} em {len(cruza)} linhas"
	for l in range(1, LINHAS):
		y = l * ch
		cruza = [x for x in range(largura) if alfa[x, y - 1] > 0 and alfa[x, y] > 0]
		assert not cruza, f"desenho atravessa o corte horizontal y={y} em {len(cruza)} colunas"


def _limpar(celula: Image.Image) -> tuple[Image.Image, int]:
	"""Mantem so o maior blob conectado. Devolve a celula e o ruido removido."""
	alfa = celula.getchannel("A")
	pixels = alfa.load()
	largura, altura = celula.size
	visto = [[False] * largura for _ in range(altura)]
	blobs: list[list[tuple[int, int]]] = []
	for y0 in range(altura):
		for x0 in range(largura):
			if pixels[x0, y0] <= 128 or visto[y0][x0]:
				continue
			pilha = [(x0, y0)]
			visto[y0][x0] = True
			blob: list[tuple[int, int]] = []
			while pilha:
				x, y = pilha.pop()
				blob.append((x, y))
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = x + dx, y + dy
					if (
						0 <= nx < largura
						and 0 <= ny < altura
						and pixels[nx, ny] > 128
						and not visto[ny][nx]
					):
						visto[ny][nx] = True
						pilha.append((nx, ny))
			blobs.append(blob)
	blobs.sort(key=len, reverse=True)
	ruido = sum(len(b) for b in blobs[1:])
	assert all(len(b) <= RUIDO_MAXIMO for b in blobs[1:]), (
		f"celula tem um segundo blob de {len(blobs[1])} px — grande demais para ser "
		f"sujeira, parece pedaco de outro desenho"
	)
	if len(blobs) > 1:
		limpa = celula.copy()
		desenho = limpa.load()
		for blob in blobs[1:]:
			for x, y in blob:
				desenho[x, y] = (0, 0, 0, 0)
		return limpa, ruido
	return celula, 0


def gerar() -> None:
	_conferir_vazamento()

	celulas = _celulas()
	ruido_total = 0
	limpas: list[Image.Image] = []
	for celula in celulas:
		limpa, ruido = _limpar(celula)
		ruido_total += ruido
		limpas.append(limpa)

	# Recorta na caixa, mas guardando quanto sobra ate o chao da LINHA. Bater as
	# caixas pela base faria a cabeca subir e descer sozinha, porque uma figura
	# de pe erguido termina mais alto que a vizinha — um sobe-desce de ate 6 px
	# de origem que cairia exatamente na cadencia do passo.
	figuras: list[Image.Image] = []
	folgas: list[int] = []
	for linha in range(LINHAS):
		bases: list[int] = []
		recortes: list[Image.Image] = []
		for coluna in range(COLUNAS):
			celula = limpas[linha * COLUNAS + coluna]
			caixa = celula.getbbox()
			bases.append(caixa[3])
			recortes.append(celula.crop(caixa))
		chao = max(bases)
		figuras.extend(recortes)
		folgas.extend(chao - b for b in bases)

	centros = [folha_miro.centro_da_cabeca(f) for f in figuras]
	escala = folha_miro.escala(figuras)

	alcance = max(
		max(centros),
		max(f.width - c for f, c in zip(figuras, centros)),
	)
	meia = alcance + MARGEM
	largura = int(meia * 2)
	altura = max(f.height + g for f, g in zip(figuras, folgas)) + MARGEM_TOPO

	fw = round(largura * escala)
	fh = round(altura * escala)
	folha = Image.new("RGBA", (fw * COLUNAS, fh * LINHAS), (0, 0, 0, 0))
	for linha in range(LINHAS):
		for coluna, origem in enumerate(ORDEM):
			i = linha * COLUNAS + origem
			celula = Image.new("RGBA", (largura, altura), (0, 0, 0, 0))
			celula.paste(
				figuras[i],
				(int(meia - centros[i]), altura - figuras[i].height - folgas[i]),
			)
			folha.paste(celula.resize((fw, fh), Image.BOX), (coluna * fw, linha * fh))
	folha.save(SAIDA)

	print(f"gerado: {SAIDA} ({folha.width}x{folha.height}, {COLUNAS}x{LINHAS} quadros de {fw}x{fh})")
	print(f"linhas: {DIRECOES}")
	print(f"ordem de animacao em cada linha: {ORDEM}")
	print(f"ruido removido: {ruido_total} px")
	# O offset do Sprite2D depende da altura da celula: os pes ficam na base,
	# e a origem do personagem fica 4 px acima deles (o mesmo das folhas
	# anteriores, para a forma de colisao continuar valendo).
	print(f"offset do Sprite2D para scripts/jogador.gd: Vector2(0, {-(fh / 2.0 - 4.0):.1f})")


if __name__ == "__main__":
	gerar()
