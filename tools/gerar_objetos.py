# Gera os objetos soltos da estacao, que nao sao tile nem personagem.
#
#   assets/objetos/cama.png   72x136   beliche metalico da Lastro
#
# POR QUE NAO E UM TILE
#
# Tudo que esta no mapa e indexado por mascara de vizinhanca e cabe numa celula
# de 64. A cama ocupa DUAS celulas em pe, tem uma cabeceira que so faz sentido
# num lado e nao se encaixa com vizinha nenhuma — indexa-la pela vizinhanca
# seria gastar 256 variacoes para desenhar sempre a mesma coisa. Ela e um no
# proprio (scripts/cama.gd), com colisao propria.
#
# A ARTE E MAIOR QUE A CAMA
#
# A imagem tem 72x136 para uma cama de 60x128: a folga de 6 px a direita e
# abaixo e onde cabe a sombra de contato, deslocada como a do casco. Com a cama
# ocupando a imagem inteira, a sombra sairia cortada — ou a cama ficaria fora do
# centro, e o personagem deitado nao cairia no meio do colchao.
#
# AS ALTURAS ENCAIXAM O PERSONAGEM DEITADO
#
# A pose de dormir e a vista de FRENTE do personagem (ver gerar_miro_estados.py)
# posta sobre o colchao. Com o deslocamento de scripts/cama.gd, a linha `y` do
# sprite cai em `y + 18` da arte: cabelo em 25, rosto em 54, cobertor em 74,
# botas em 117. Travesseiro, dobra do lencol e pe da cama saem dessas medidas —
# mexer numa pede conferir a outra.
from PIL import Image, ImageDraw

SAIDA_CAMA = "assets/objetos/cama.png"

LARGURA: int = 72
ALTURA: int = 136

## Caixa da cama dentro da imagem. A sobra e a sombra.
ESQUERDA: int = 6
DIREITA: int = 65
TOPO: int = 4
BASE: int = 131

CONTORNO = (28, 34, 43, 255)
ACO = (126, 139, 155, 255)
ACO_CLARO = (182, 194, 207, 255)
ACO_ESCURO = (74, 84, 98, 255)
PAINEL = (56, 66, 80, 255)
CIANO = (104, 224, 236, 255)
CIANO_FRACO = (48, 118, 132, 255)
AMBAR = (255, 186, 84, 255)
COLCHAO = (66, 78, 92, 255)
COLCHAO_LUZ = (88, 102, 118, 255)
LENCOL = (178, 190, 204, 255)
TRAVESSEIRO = (214, 224, 234, 255)
SOMBRA = (0, 0, 0, 90)

## Linhas da cama, com a parte do personagem deitado que cai em cada uma.
CABECEIRA_BASE: int = 26
COLCHAO_TOPO: int = 24
TRAVESSEIRO_BASE: int = 60  # a cabeca vai de 25 a 68
LENCOL_TOPO: int = 63  # peito, logo acima do cobertor, que comeca em 74
LENCOL_BASE: int = 71
COLCHAO_BASE: int = 124  # as botas terminam em 117
PE_TOPO: int = 120


def _cama() -> Image.Image:
	arte = Image.new("RGBA", (LARGURA, ALTURA), (0, 0, 0, 0))
	desenho = ImageDraw.Draw(arte)

	# Sombra de contato, deslocada para baixo e para a direita como a do casco.
	# Sem ela a cama flutua: nada mais na cena e desenhado sem chao por baixo.
	desenho.rounded_rectangle((ESQUERDA + 4, TOPO + 4, DIREITA + 4, BASE + 4), radius=8, fill=SOMBRA)

	# Cabeceira: painel escuro, com a luz de cabeceira e o piloto de energia.
	desenho.rounded_rectangle(
		(ESQUERDA, TOPO, DIREITA, CABECEIRA_BASE), radius=6, fill=PAINEL, outline=CONTORNO
	)
	desenho.rectangle((17, 10, 54, 16), fill=CIANO_FRACO)
	desenho.rectangle((18, 11, 53, 14), fill=CIANO)
	desenho.ellipse((57, 9, 61, 13), fill=AMBAR)
	for x, y in ((10, 8), (10, 21), (61, 21)):
		desenho.point((x, y), fill=ACO_CLARO)

	# Estrutura: a chapa que segura o colchao, por baixo de tudo.
	desenho.rounded_rectangle(
		(ESQUERDA, CABECEIRA_BASE - 6, DIREITA, BASE - 3), radius=6, fill=ACO_ESCURO, outline=CONTORNO
	)

	# Trilhos laterais, com o fio de luz na aresta de cima — e o que faz o tubo
	# do casco ler como metal, e vale igual aqui.
	for x0 in (ESQUERDA + 1, DIREITA - 5):
		desenho.rectangle((x0, COLCHAO_TOPO, x0 + 4, COLCHAO_BASE), fill=ACO)
		desenho.line((x0 + 1, COLCHAO_TOPO + 1, x0 + 1, COLCHAO_BASE - 1), fill=ACO_CLARO)
		for y in (40, 72, 104):
			desenho.point((x0 + 2, y), fill=ACO_ESCURO)

	# Colchao. As linhas do acolchoado sao claras e espacadas: escuras viram
	# grade, e grade le como estrado sem colchao nenhum.
	desenho.rounded_rectangle(
		(11, COLCHAO_TOPO, 60, COLCHAO_BASE), radius=4, fill=COLCHAO, outline=ACO_ESCURO
	)
	for y in range(COLCHAO_TOPO + 16, COLCHAO_BASE - 6, 16):
		desenho.line((13, y, 58, y), fill=COLCHAO_LUZ)

	# Travesseiro e a dobra do lencol: as duas pecas que dizem que isto e cama e
	# nao maca. O vinco do travesseiro e uma linha so — duas viram almofada.
	desenho.rounded_rectangle(
		(14, COLCHAO_TOPO + 1, 57, TRAVESSEIRO_BASE), radius=5, fill=TRAVESSEIRO, outline=ACO_ESCURO
	)
	desenho.line((35, COLCHAO_TOPO + 6, 35, TRAVESSEIRO_BASE - 5), fill=ACO)
	desenho.rounded_rectangle((14, LENCOL_TOPO, 57, LENCOL_BASE), radius=2, fill=LENCOL)
	desenho.line((14, LENCOL_BASE + 1, 57, LENCOL_BASE + 1), fill=ACO_ESCURO)

	# Pe da cama, com a mesma linguagem da cabeceira para a peca fechar.
	desenho.rounded_rectangle((ESQUERDA, PE_TOPO, DIREITA, BASE), radius=5, fill=PAINEL, outline=CONTORNO)
	for x in (10, 61):
		desenho.point((x, PE_TOPO + 5), fill=ACO_CLARO)

	return arte


def gerar() -> None:
	arte = _cama()
	arte.save(SAIDA_CAMA)
	print("gerado: %s (%dx%d)" % (SAIDA_CAMA, arte.width, arte.height))


if __name__ == "__main__":
	gerar()
