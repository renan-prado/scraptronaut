# -*- coding: utf-8 -*-
"""Monta uma planta de teste com os atlas de assets/tiles/estacao/ e grava um
PNG em screenshots/. Serve para pegar erro grosseiro de mascara antes de abrir
o Godot — a conferencia que vale continua sendo a captura do jogo.

Uso: python tools/conferir_tiles_estacao.py
"""
import os

from PIL import Image

CELULA = 64
LADO_ATLAS = 16
DIRECOES = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]

SALAS = [
	(2, 2, 7, 9), (2, 9, 11, 4),
	(13, 5, 6, 4),
	(15, 9, 10, 10), (18, 4, 5, 6),
	(25, 12, 4, 4),
	(29, 3, 13, 11),
	(6, 19, 9, 8), (11, 17, 5, 3),
	(19, 20, 9, 7), (21, 17, 4, 4),
]


def _mascara(celula, conjunto):
	m = 0
	for i, (dx, dy) in enumerate(DIRECOES):
		if (celula[0] + dx, celula[1] + dy) in conjunto:
			m |= 1 << i
	return m


def _tile(folha, indice, lado=LADO_ATLAS):
	x = (indice % lado) * CELULA
	y = (indice // lado) * CELULA
	return folha.crop((x, y, x + CELULA, y + CELULA))


def main():
	piso_folha = Image.open("assets/tiles/station/floor.png").convert("RGBA")
	borda_folha = Image.open("assets/tiles/station/border.png").convert("RGBA")
	casco_folha = Image.open("assets/tiles/station/hull.png").convert("RGBA")

	interior = set()
	for x0, y0, largura, altura in SALAS:
		for y in range(y0, y0 + altura):
			for x in range(x0, x0 + largura):
				interior.add((x, y))

	casco = set()
	for x, y in interior:
		for dx, dy in DIRECOES:
			alvo = (x + dx, y + dy)
			if alvo not in interior:
				casco.add(alvo)

	ocupado = interior | casco
	xs = [c[0] for c in ocupado]
	ys = [c[1] for c in ocupado]
	largura = (max(xs) - min(xs) + 3) * CELULA
	altura = (max(ys) - min(ys) + 3) * CELULA
	origem = (min(xs) - 1, min(ys) - 1)

	tela = Image.new("RGBA", (largura, altura), (9, 20, 37, 255))

	def colar(imagem, celula):
		tela.alpha_composite(
			imagem, ((celula[0] - origem[0]) * CELULA, (celula[1] - origem[1]) * CELULA)
		)

	for celula in sorted(interior):
		variacao = (celula[0] * 7 + celula[1] * 13) % 16
		colar(_tile(piso_folha, variacao, 4), celula)

	for celula in sorted(interior):
		mascara = 255 ^ _mascara(celula, interior)
		if mascara:
			colar(_tile(borda_folha, mascara), celula)

	for celula in sorted(casco):
		mascara = 255 ^ _mascara(celula, ocupado)
		colar(_tile(casco_folha, mascara), celula)

	os.makedirs("screenshots", exist_ok=True)
	caminho = "screenshots/conferir-tiles-estacao.png"
	tela.convert("RGB").save(caminho)
	print("gravado", caminho, tela.size)


if __name__ == "__main__":
	main()
