# Utilidades comuns as folhas de referencia do Miro em docs/.
#
# Todas as folhas vem como uma grade de desenhos soltos sobre fundo
# transparente. Nenhuma respeita uma grade exata: alguns desenhos invadem a
# celula vizinha. Por isso a separacao e feita por faixas totalmente vazias,
# nao por divisao aritmetica.
from PIL import Image

## Largura final da cabeca, em pixels do jogo. Vem da folha do sprite parado:
## 193 px de cabeca numa figura de 401 px que virou um sprite de 96 px.
##
## Cada folha de referencia e desenhada numa escala um pouco diferente — as
## folhas de caminhada tem a cabeca 5% maior que a do parado. Normalizar pela
## altura da figura nao resolve, porque a altura tambem muda com a pose (perna
## dobrada encurta o desenho). A cabeca e o unico ponto estavel entre poses,
## entao e ela que fixa a escala de todas as folhas.
ALTURA_FINAL: int = 96
LARGURA_CABECA_FINAL: float = 193.0 * ALTURA_FINAL / 401.0


def _faixas(tamanho: int, ocupado) -> list[tuple[int, int]]:
	faixas: list[tuple[int, int]] = []
	inicio = -1
	for i in range(tamanho):
		if ocupado(i):
			if inicio < 0:
				inicio = i
		elif inicio >= 0:
			faixas.append((inicio, i))
			inicio = -1
	if inicio >= 0:
		faixas.append((inicio, tamanho))
	return faixas


def figuras(caminho: str) -> list[Image.Image]:
	"""Recorta cada desenho da folha, em ordem de leitura."""
	folha = Image.open(caminho).convert("RGBA")
	dados = folha.getchannel("A").load()
	largura, altura = folha.size
	recortes: list[Image.Image] = []
	for y0, y1 in _faixas(altura, lambda y: any(dados[x, y] > 128 for x in range(largura))):
		colunas = _faixas(largura, lambda x: any(dados[x, y] > 128 for y in range(y0, y1)))
		for x0, x1 in colunas:
			celula = folha.crop((x0, y0, x1, y1))
			recortes.append(celula.crop(celula.getbbox()))
	return recortes


def centro_da_cabeca(figura: Image.Image) -> float:
	"""Centro horizontal da cabeca — a ancora de todas as folhas.

	A caixa da figura nao serve: ela cresce e encolhe conforme as pernas e os
	bracos abrem. O centro de massa do tronco tambem nao, e esse erro ja custou
	uma animacao: a faixa do tronco pega os bracos junto, entao o braco que
	balanca para a frente puxa a ancora com ele e o corpo inteiro escorrega de
	lado a cada passo.

	A cabeca e a unica parte rigida do desenho. Medida por correlacao, ela bate
	entre 97% e 99% de um quadro para o outro, e a faixa usada aqui fica acima
	dos ombros, onde nenhum membro entra.

	A folha do parado (docs/sprite-miro-maior.png) tem o centro da cabeca
	exatamente no centro da celula. Toda folha de animacao precisa repetir isso,
	senao o personagem salta de lado ao trocar de parado para andando.
	"""
	alfa = figura.getchannel("A").load()
	largura, altura = figura.size
	colunas = [
		x
		for x in range(largura)
		for y in range(int(altura * 0.04), int(altura * 0.26))
		if alfa[x, y] > 128
	]
	return (min(colunas) + max(colunas)) / 2.0


def largura_da_cabeca(figura: Image.Image) -> int:
	"""Maior largura da figura na faixa da cabeca."""
	alfa = figura.getchannel("A").load()
	largura, altura = figura.size
	maior = 0
	for y in range(int(altura * 0.05), int(altura * 0.30)):
		linha = [x for x in range(largura) if alfa[x, y] > 128]
		if linha:
			maior = max(maior, linha[-1] - linha[0] + 1)
	return maior


def escala(figuras: list[Image.Image]) -> float:
	"""Escala que poe a cabeca desta folha no tamanho do sprite parado."""
	cabecas = sorted(largura_da_cabeca(f) for f in figuras)
	meio = len(cabecas) // 2
	mediana = (cabecas[meio] + cabecas[~meio]) / 2.0
	return LARGURA_CABECA_FINAL / mediana
