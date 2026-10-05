# Gera assets/sprites/miro_baixo.png a partir de docs/sprites-paste/image.png.
#
# A folha tem seis desenhos de frente numa grade 3x2, mas so quatro formam
# ciclo. Medindo qual pe esta a frente (na vista de frente, o pe da frente e
# desenhado mais baixo) e quanto:
#
#   fig 0 = esquerdo, 26     fig 2 = direito, 25     <- par
#   fig 1 = esquerdo, 30     fig 4 = direito, 33     <- par
#   fig 3 = direito,  27     fig 5 = direito, 20     <- sem par
#
# Ou seja: QUATRO desenhos tem o pe direito a frente e so DOIS tem o esquerdo.
# Uma caminhada precisa de metades iguais, entao fig 3 e fig 5 ficam de fora —
# usa-las faria o personagem mancar, favorecendo uma perna.
#
# Os bracos nao ajudam a desempatar: as maos ficam na mesma altura nos seis
# quadros (diferenca de +-2 px), ou seja os bracos nao balancam nesta folha.
#
# Com quatro quadros o ciclo fica contato -> passagem para cada perna, que e o
# formato classico de caminhada em quatro tempos. Se as duas poses que faltam
# forem desenhadas (pe ESQUERDO a frente, para parear com fig 3 e fig 5), da
# para subir para seis mudando so a ORDEM aqui.
#
# ESCALA: esta folha NAO e normalizada pela largura da cabeca como as outras.
# Uma cabeca de frente e 4% mais estreita que a de perfil, porque o perfil
# inclui o cabelo que sobra atras. Normalizar pela largura deixaria o
# personagem 4% maior de frente — e a figura sairia com 98,6 px numa celula de
# 96. Em vez disso a escala casa a ALTURA da figura com a da caminhada
# lateral: o personagem nao muda de tamanho ao virar.
#
# Ancora: centro da cabeca na horizontal, chao na base da celula — a mesma
# convencao do parado e da lateral.
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import folha_miro

ORIGEM = "docs/sprites-paste/image.png"
SAIDA = "assets/sprites/miro_baixo.png"

## Ordem de animacao, em indices da ordem de leitura da folha.
ORDEM: list[int] = [0, 1, 2, 4]

## Altura da figura, em pixels do sprite final. E a altura que a caminhada
## lateral tem depois de reduzida — medida em assets/sprites/miro_direita.png.
## O parado tem 96; a caminhada tem 92 nas duas direcoes porque os desenhos de
## caminhada sao um pouco mais baixos que o do parado.
ALTURA_DA_FIGURA: int = 92

## Folga em cada lado da celula, em pixels da folha de origem.
MARGEM: int = 24


def _pe_a_frente(figura: Image.Image) -> int:
	"""Quanto o pe de um lado esta mais baixo que o do outro.

	Negativo = pe esquerdo a frente, positivo = direito. Na vista de frente e
	a altura que diz qual pe esta a frente, nao a separacao horizontal.
	"""
	alfa = figura.getchannel("A").load()
	largura, altura = figura.size
	centro = int(folha_miro.centro_da_cabeca(figura))

	def base(x0: int, x1: int) -> int:
		for y in range(altura - 1, int(altura * 0.80), -1):
			if any(alfa[x, y] > 128 for x in range(x0, x1)):
				return altura - 1 - y
		return 0

	return base(0, centro) - base(centro, largura)


def gerar() -> None:
	figuras = folha_miro.figuras(ORIGEM)
	assert len(figuras) == 6, f"esperava 6 desenhos, achei {len(figuras)}"

	# Confere a premissa da ordem: quadros a meio ciclo de distancia sao a
	# mesma pose com as pernas trocadas. Se a folha mudar, isto avisa em vez
	# de gerar um manco em silencio.
	metade = len(ORDEM) // 2
	for i in range(metade):
		a = _pe_a_frente(figuras[ORDEM[i]])
		b = _pe_a_frente(figuras[ORDEM[i + metade]])
		assert a * b < 0, (
			f"quadros {ORDEM[i]} e {ORDEM[i + metade]} deviam ter pes opostos "
			f"a frente, mas deram {a} e {b}"
		)
		assert abs(abs(a) - abs(b)) <= 8, (
			f"quadros {ORDEM[i]} e {ORDEM[i + metade]} deviam ser a mesma pose "
			f"espelhada, mas abrem {abs(a)} e {abs(b)}"
		)

	centros = [folha_miro.centro_da_cabeca(f) for f in figuras]
	escala = ALTURA_DA_FIGURA / max(f.height for f in figuras)

	alcance = max(
		max(centros),
		max(f.width - c for f, c in zip(figuras, centros)),
	)
	meia = alcance + MARGEM
	largura = int(meia * 2)
	altura = round(folha_miro.ALTURA_FINAL / escala)
	assert altura >= max(f.height for f in figuras), "figura mais alta que a celula"

	celulas: list[Image.Image] = []
	for i in ORDEM:
		celula = Image.new("RGBA", (largura, altura), (0, 0, 0, 0))
		celula.paste(figuras[i], (int(meia - centros[i]), altura - figuras[i].height))
		celulas.append(celula)

	fw = round(largura * escala)
	fh = folha_miro.ALTURA_FINAL
	folha = Image.new("RGBA", (fw * len(celulas), fh), (0, 0, 0, 0))
	for i, celula in enumerate(celulas):
		folha.paste(celula.resize((fw, fh), Image.BOX), (i * fw, 0))
	folha.save(SAIDA)

	print(f"gerado: {SAIDA} ({folha.width}x{folha.height}, {len(celulas)} quadros de {fw}x{fh})")
	print(f"ordem de animacao: {ORDEM}   descartados: "
	      f"{[i for i in range(6) if i not in ORDEM]} (sem par espelhado)")


gerar()
