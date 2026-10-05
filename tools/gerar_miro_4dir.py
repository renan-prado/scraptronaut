# Gera assets/sprites/miro_4dir.png a partir de docs/miro-sprite.png.
#
# Esta e a primeira folha do Miro com as QUATRO direcoes desenhadas. As folhas
# anteriores (miro.png, miro_direita.png, miro_baixo.png) vinham de desenhos
# soltos, cada um numa escala diferente, e nao tinham vista de costas — subir
# reaproveitava a lateral. Esta substitui as tres.
#
# A folha de origem e uma grade 4x4 sobre fundo transparente:
#
#   linha 0  frente (baixo)     linha 1  direita
#   linha 2  costas (cima)      linha 3  esquerda
#
# A direcao de cada linha foi medida, nao suposta: o centroide horizontal dos
# pixels de pele na faixa da cabeca cai em 0,47 da largura na linha 0 (rosto
# centrado), 0,60 na linha 1 (rosto puxado para a direita), 0,42 na linha 3, e
# a linha 2 nao tem pixel de pele nenhum — e a nuca.
#
# Dentro de cada linha a ordem de leitura NAO e a ordem da animacao. Medindo a
# abertura dos pes na faixa inferior:
#
#   linha 0 (frente)   col 0 = 120   col 1 = 119   col 2 = 102   col 3 =  99
#   linha 1 (direita)  col 0 = 120   col 1 = 120   col 2 = 185   col 3 = 123
#
# As colunas 0 e 1 sao as duas poses de pes juntos (passagem) e as colunas 2 e
# 3 sao os dois contatos, com as pernas trocadas — na vista de frente da para
# ver que numa o pe de um lado sobe e na outra o do outro. Dai o ciclo
# passagem, contato, passagem, contato: [0, 2, 1, 3].
#
# Ancora: centro da CABECA na horizontal, chao na base da celula — a mesma das
# folhas antigas, pelo mesmo motivo (a caixa da figura respira com as pernas e
# os bracos; a cabeca e rigida). As 16 figuras dividem UMA celula so, entao
# qualquer quadro de qualquer direcao usa o mesmo offset no Sprite2D.
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import folha_miro

ORIGEM = "docs/miro-sprite.png"
SAIDA = "assets/sprites/miro_4dir.png"

LINHAS: int = 4
COLUNAS: int = 4

## Nomes das linhas, na ordem da folha. Viram a ordem do enum em jogador.gd.
DIRECOES: list[str] = ["baixo", "direita", "cima", "esquerda"]

## Ordem de animacao dentro de cada linha, em indices da ordem de leitura.
ORDEM: list[int] = [0, 2, 1, 3]

## Folga em cada lado da celula, em pixels da folha de origem (~7 px no sprite
## final). So evita que o quadro mais largo encoste na borda.
MARGEM: int = 24


def _figuras_e_folga() -> tuple[list[Image.Image], list[int]]:
	"""Recorta as 16 figuras e mede a folga de cada uma ate o chao da linha.

	folha_miro.figuras() corta cada desenho na propria caixa, o que joga fora a
	linha do chao: duas figuras da mesma linha podem terminar em alturas
	diferentes so porque uma tem o pe erguido. Bater as caixas pela base faz a
	cabeca subir e descer sozinha, um sobe-desce que nao esta no desenho.

	Aqui o chao e o pixel mais baixo da LINHA inteira, e cada figura guarda o
	quanto sobra abaixo dela. Nesta folha a diferenca chega a 6 px de origem
	(~1,6 px no sprite), que e pouco mas aparece: e um quadro sim, um quadro
	nao, exatamente a cadencia do passo.
	"""
	folha = Image.open(ORIGEM).convert("RGBA")
	alfa = folha.getchannel("A").load()
	largura, altura = folha.size
	figuras: list[Image.Image] = []
	folgas: list[int] = []
	bandas = folha_miro._faixas(altura, lambda y: any(alfa[x, y] > 128 for x in range(largura)))
	for y0, y1 in bandas:
		colunas = folha_miro._faixas(largura, lambda x: any(alfa[x, y] > 128 for y in range(y0, y1)))
		bases: list[int] = []
		celulas: list[Image.Image] = []
		for x0, x1 in colunas:
			ys = [y for y in range(y0, y1) if any(alfa[x, y] > 128 for x in range(x0, x1))]
			bases.append(ys[-1])
			celula = folha.crop((x0, y0, x1, y1))
			celulas.append(celula.crop(celula.getbbox()))
		chao = max(bases)
		figuras.extend(celulas)
		folgas.extend(chao - b for b in bases)
	return figuras, folgas


def _abertura(figura: Image.Image) -> int:
	"""Distancia horizontal entre o pe de tras e o da frente."""
	alfa = figura.getchannel("A").load()
	largura, altura = figura.size
	faixa = range(int(altura * 0.90), altura)
	colunas = [x for x in range(largura) if any(alfa[x, y] > 128 for y in faixa)]
	return colunas[-1] - colunas[0] if colunas else 0


def gerar() -> None:
	figuras, folgas = _figuras_e_folga()
	assert len(figuras) == LINHAS * COLUNAS, (
		f"esperava {LINHAS * COLUNAS} desenhos, achei {len(figuras)}"
	)

	centros = [folha_miro.centro_da_cabeca(f) for f in figuras]
	escala = folha_miro.escala(figuras)

	# Uma celula unica para as 16 figuras: simetrica em torno da cabeca, com a
	# altura do sprite parado e os pes na base. A margem existe porque sem ela
	# o quadro mais largo nasce com folga zero e qualquer arredondamento da
	# reducao come pixel do contorno.
	alcance = max(
		max(centros),
		max(f.width - c for f, c in zip(figuras, centros)),
	)
	meia = alcance + MARGEM
	largura = int(meia * 2)
	# A altura da celula sai da figura mais alta da folha, nao de ALTURA_FINAL:
	# nesta folha a pose mais esticada passa 1,5% do que a escala da cabeca
	# previa, e cortar o pixel de cima para fechar em 96 nao vale o estrago.
	# O sprite final fica um pixel mais alto que o das folhas antigas.
	altura = max(f.height + g for f, g in zip(figuras, folgas))

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

	# O ciclo tem dois contatos; cada um e um passo. jogador.gd usa isso para
	# casar a cadencia da animacao com o deslocamento real.
	lado = DIRECOES.index("direita")
	contatos = [
		_abertura(figuras[lado * COLUNAS + ORDEM[1]]) * escala,
		_abertura(figuras[lado * COLUNAS + ORDEM[3]]) * escala,
	]
	ciclo = sum(contatos)
	print(f"gerado: {SAIDA} ({folha.width}x{folha.height}, {COLUNAS}x{LINHAS} quadros de {fw}x{fh})")
	print(f"linhas: {DIRECOES}")
	print(f"ordem de animacao em cada linha: {ORDEM}")
	print(f"passo medio: {ciclo / 2:.1f} px   ciclo completo (dois passos): {ciclo:.1f} px")


if __name__ == "__main__":
	gerar()
