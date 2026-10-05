# Gera assets/sprites/miro_direita.png a partir de docs/sprites-paste/miro-right.png.
#
# A folha tem seis desenhos numa grade 3x2, e a ordem de leitura NAO e a ordem
# da animacao. A ordem foi deduzida medindo as figuras:
#
#   - abertura dos pes (distancia entre o pe de tras e o da frente):
#       fig 0 = 145   fig 3 = 146     mesmo instante do passo
#       fig 2 = 122   fig 4 = 115     mesmo instante do passo
#       fig 1 = 219   fig 5 = 229     contato, pernas abertas
#
#   - os tres pares caem a exatamente 3 de distancia num ciclo de 6, que e o
#     que se espera de uma caminhada: cada metade repete a outra com as pernas
#     trocadas.
#
#   - fig 1 e fig 5 sao as duas metades, e o que prova isso e o BRACO: na fig 1
#     o braco de perto vai atras, na fig 5 ele vai a frente. Como o braco se
#     opoe a perna, na fig 1 quem esta a frente e a perna de perto e na fig 5
#     e a de longe.
#
#     Na folha miro-right.png o emblema do peito sumia na fig 5 e servia de
#     pista secundaria. Em miro-right-2.png ele foi redesenhado e aparece nos
#     seis quadros — que era o ponto da correcao, porque um emblema piscando
#     uma vez por ciclo aparece na tela. A pose nao mudou (a abertura dos pes
#     foi de 231 para 229), entao a ordem continua valendo.
#
#   - a cor NAO distingue as pernas nesta folha: o desenhista clareia sempre a
#     perna da frente, seja ela a de perto ou a de longe. A folha anterior
#     (docs/sprite-miro-maior-2.png) seguia a convencao oposta, e foi por isso
#     que ela virou meio passo: as oito figuras tinham sempre a mesma perna a
#     frente, entao so dava para abrir e fechar o compasso.
#
# Dentro de cada metade a abertura vai 147 -> 121 -> 220, ou seja apoio,
# passagem e contato. Daí a ordem final.
#
# Ancora: centro da CABECA na horizontal, chao na base da celula.
#
# A versao anterior ancorava no centro de massa do tronco, e a animacao saiu
# torta: a faixa do tronco pega os bracos junto, entao nos dois quadros de
# contato — onde um braco vai a frente e o outro atras — a ancora era puxada
# para lados opostos e o corpo escorregava de lado a cada passo. A cabeca e
# rigida (97% a 99% de correlacao entre quadros) e fica acima dos ombros.
#
# O centro da cabeca cai no centro da celula, que e exatamente onde ele cai na
# folha do parado. E isso que impede o personagem de saltar ao trocar de estado.
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import folha_miro

ORIGEM = "docs/sprites-paste/miro-right-2.png"
SAIDA = "assets/sprites/miro_direita.png"

## Ordem de animacao, em indices da ordem de leitura da folha.
ORDEM: list[int] = [0, 2, 1, 3, 4, 5]

## Folga em cada lado da celula, em pixels da folha de origem (~5 px no sprite
## final). So evita que o quadro mais largo encoste na borda.
MARGEM: int = 24

## Quanto o personagem anda, em pixels do jogo, a cada ciclo completo de seis
## quadros. Sao dois passos; cada passo e a abertura entre os pes no contato.
## Usado por scripts/jogador.gd para casar a animacao com o deslocamento.
PASSO_EM_PIXELS_DO_JOGO = 0.0  # calculado em gerar()


def _abertura(figura: Image.Image) -> int:
	"""Distancia horizontal entre o pe de tras e o da frente."""
	alfa = figura.getchannel("A").load()
	largura, altura = figura.size
	faixa = range(int(altura * 0.88), altura)
	colunas = [x for x in range(largura) if any(alfa[x, y] > 128 for y in faixa)]
	return colunas[-1] - colunas[0] if colunas else 0


def gerar() -> None:
	figuras = folha_miro.figuras(ORIGEM)
	assert len(figuras) == len(ORDEM), f"esperava {len(ORDEM)} desenhos, achei {len(figuras)}"

	# Confere a premissa da ordem: figuras a 3 de distancia sao o mesmo
	# instante do passo. Se a folha de origem mudar, isto avisa em vez de
	# gerar uma animacao torta em silencio.
	metade = len(ORDEM) // 2
	for i in range(metade):
		a, b = _abertura(figuras[ORDEM[i]]), _abertura(figuras[ORDEM[i + metade]])
		assert abs(a - b) <= max(16, a * 0.08), (
			f"quadros {ORDEM[i]} e {ORDEM[i + metade]} deviam ser o mesmo instante "
			f"do passo, mas abrem {a} e {b}"
		)

	centros = [folha_miro.centro_da_cabeca(f) for f in figuras]
	escala = folha_miro.escala(figuras)

	# A celula e simetrica em torno da cabeca, e tem a altura do sprite parado,
	# com os pes na base. Assim toda folha de direcao usa o mesmo offset.
	#
	# A margem existe porque sem ela os dois quadros de contato encostavam na
	# borda: a celula nascia do proprio alcance maximo, entao o quadro mais
	# largo ficava com folga zero e qualquer arredondamento da reducao comia
	# pixel do contorno.
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

	contatos = [_abertura(figuras[i]) * escala for i in (ORDEM[metade - 1], ORDEM[-1])]
	ciclo = sum(contatos)
	print(f"gerado: {SAIDA} ({folha.width}x{folha.height}, {len(celulas)} quadros de {fw}x{fh})")
	print(f"ordem de animacao: {ORDEM}")
	print(f"passo medio: {ciclo / 2:.1f} px   ciclo completo (dois passos): {ciclo:.1f} px")


gerar()
