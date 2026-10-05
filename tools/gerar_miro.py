# Gera assets/sprites/miro.png a partir de docs/sprite-miro-maior.png.
#
# A folha de referencia tem oito desenhos em grade 4x2, mas eles NAO sao
# quadros de animacao: sao oito redesenhos independentes do mesmo personagem
# (seis de olhos abertos, dois de olhos fechados). Alinhados pela silhueta, a
# sobreposicao fica entre 95% e 98% — ou seja, de 2% a 5% do contorno muda de
# um desenho para o outro. Em pixel art isso aparece como fervilhamento do
# corpo inteiro, nao como animacao.
#
# Por isso o quadro de piscar nao e o desenho de olhos fechados inteiro: so a
# faixa dos olhos dele e colada sobre o desenho base. O corpo fica identico nos
# dois quadros e so os olhos mudam.
#
# O par escolhido (indices BASE e PISCAR) e o de melhor alinhamento da folha:
# sobreposicao de 0,985 com deslocamento zero, o unico par que dispensa ajuste.
#
# Saida: folha horizontal de 2 quadros — 0 = olhos abertos, 1 = piscando.
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import folha_miro

ORIGEM = "docs/sprite-miro-maior.png"
SAIDA = "assets/sprites/miro.png"

## Indices das figuras na folha, em ordem de leitura (linha, depois coluna).
BASE = 2
PISCAR = 3

## Faixa dos olhos em coordenadas da figura BASE ja recortada.
## Cobre com folga sobrancelhas (y87-101) e olhos (y108-128).
FAIXA = (78, 83, 166, 134)


def gerar() -> None:
	figuras = folha_miro.figuras(ORIGEM)
	aberto = figuras[BASE]
	fechado = figuras[PISCAR]

	piscando = aberto.copy()
	piscando.paste(fechado.crop(FAIXA), (FAIXA[0], FAIXA[1]))

	escala = folha_miro.escala(figuras)
	largura = round(aberto.width * escala)
	altura = round(aberto.height * escala)
	quadros = [q.resize((largura, altura), Image.BOX) for q in (aberto, piscando)]

	folha = Image.new("RGBA", (largura * len(quadros), altura), (0, 0, 0, 0))
	for i, quadro in enumerate(quadros):
		folha.paste(quadro, (i * largura, 0))
	folha.save(SAIDA)
	print(f"gerado: {SAIDA} ({folha.width}x{folha.height}, {len(quadros)} quadros)")


gerar()
