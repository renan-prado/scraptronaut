# Prova da fonte: renderiza frases do jogo com a metrica de gerar_fonte.py,
# salva um PNG ampliado em screenshots/ e confere que nenhum texto do jogo pede
# um glifo que a folha nao tem.
#
# A PROVA EM IMAGEM existe porque fonte nao se confere lendo a tabela de glifos.
# Uma letra errada e invisivel na lista de "#" e salta aos olhos numa palavra —
# e o "a" ao lado do "o" e a unica prova de que os dois nao viraram o mesmo
# desenho.
#
# A VARREDURA DOS SCRIPTS existe porque glifo que falta NAO reclama: a engine
# desenha o nada e segue. Uma frase nova com um caractere fora da folha sairia
# com um buraco no meio, e ninguem saberia ate alguem olhar aquela tela.
import glob
import re
import sys

from PIL import Image

import gerar_fonte as fonte

SAIDA = "screenshots/_fonte.png"

## Texto entre aspas duplas, sem atravessar a quebra de linha.
ENTRE_ASPAS = re.compile(r'"([^"\n]*)"')

AMPLIACAO = 5
MARGEM = 6
FUNDO = (26, 32, 44, 255)
TINTA = (219, 232, 247, 255)

FRASES = [
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"abcdefghijklmnopqrstuvwxyz",
	"0123456789  .,:;!?()-—·×/%",
	"áàâã éê í óôõ úü ç ÁÂÃ ÉÊ Ç",
	"Não está muito cedo para dormir?",
	"Estou caindo de sono · Acabei por hoje",
	"CONSTRUÇÃO · Portão de nave · Demolir",
	"Dia 12 · 22 células alteradas · F1",
]


def _largura(tabela: dict, frase: str) -> int:
	total = 0
	for letra in frase:
		if letra == " ":
			total += fonte.ESPACO
			continue
		desenho, _ = tabela[letra]
		total += fonte._tamanho(desenho)[0] + fonte.AVANCO
	return total


def _escrever(arte: Image.Image, tabela: dict, frase: str, x: int, y: int) -> None:
	for letra in frase:
		if letra == " ":
			x += fonte.ESPACO
			continue
		desenho, topo = tabela[letra]
		for dy, linha in enumerate(desenho):
			for dx, ponto in enumerate(linha):
				if ponto == "#":
					arte.putpixel((x + dx, y + topo + dy), TINTA)
		x += fonte._tamanho(desenho)[0] + fonte.AVANCO


def _conferir_os_scripts(tabela: dict) -> int:
	"""Varre o texto entre aspas de scripts/*.gd atras de glifo que falta.

	Varrer demais e de proposito: caminho de recurso, nome de no e nome de sinal
	entram na conta junto com a frase que o jogador le. Sao todos ASCII, entao
	nao geram alarme falso, e o filtro que os tirasse custaria mais do que eles.
	"""
	faltando = {}
	for caminho in sorted(glob.glob("scripts/*.gd")):
		with open(caminho, encoding="utf-8") as arquivo:
			for texto in re.findall(ENTRE_ASPAS, arquivo.read()):
				for letra in texto:
					if letra != " " and letra not in tabela:
						faltando.setdefault(letra, caminho)
	for letra, caminho in sorted(faltando.items()):
		print("sem glifo: %r, usado em %s" % (letra, caminho))
	return len(faltando)


def gerar() -> None:
	tabela = fonte.glifos()
	faltando = sorted({c for f in FRASES for c in f if c != " " and c not in tabela})
	if faltando:
		print("sem glifo: %s" % " ".join(faltando))
		sys.exit(1)
	largura = max(_largura(tabela, f) for f in FRASES) + MARGEM * 2
	altura = len(FRASES) * fonte.ALTURA_LINHA + MARGEM * 2
	arte = Image.new("RGBA", (largura, altura), FUNDO)
	for i, frase in enumerate(FRASES):
		_escrever(arte, tabela, frase, MARGEM, MARGEM + i * fonte.ALTURA_LINHA)
	arte = arte.resize((largura * AMPLIACAO, altura * AMPLIACAO), Image.NEAREST)
	arte.save(SAIDA)
	print("gerado: %s (%dx%d, %dx)" % (SAIDA, arte.width, arte.height, AMPLIACAO))
	if _conferir_os_scripts(tabela):
		sys.exit(1)
	print("os scripts nao pedem nenhum glifo que a folha nao tenha")


if __name__ == "__main__":
	gerar()
