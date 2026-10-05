# Gera as folhas de estado do personagem a partir de assets/sprites/miro_8dir.png.
#
#   assets/sprites/miro_parado.png     4x8   respiracao, uma linha por direcao
#   assets/sprites/miro_trabalho.png   4x8   picareta batendo, uma por direcao
#   assets/sprites/miro_dormindo.png   4x1   deitado na cama, respirando
#
# POR QUE DERIVAR EM VEZ DE DESENHAR DE NOVO
#
# A folha de caminhada veio de arte feita a mao (docs/sprites-paste/), e nao de
# um gerador: redesenhar o personagem em codigo daria outro personagem. Todas as
# poses daqui saem do quadro 0 de cada linha — a pose de parado — com
# deformacoes pequenas e um objeto desenhado por cima. E por isso que a
# respiracao e de 1 a 2 px e nao de 6: o que da para fazer sem redesenhar o
# corpo e comprimir a silhueta, e compressao grande vira borracha.
#
# A CELULA DA FOLHA DE TRABALHO E MAIOR
#
# A picareta sai da mao e alcanca ate 30 px: na celula de 70x100 a cabeca da
# ferramenta cairia fora nas vistas laterais. A folha de trabalho usa 100x110,
# com o mesmo chao na base e o mesmo centro horizontal — e por isso o offset do
# Sprite2D muda junto, e scripts/jogador.gd guarda um offset por estado.
import math

from PIL import Image, ImageDraw

ORIGEM = "assets/sprites/miro_8dir.png"
SAIDA_PARADO = "assets/sprites/miro_parado.png"
SAIDA_TRABALHO = "assets/sprites/miro_trabalho.png"
SAIDA_DORMINDO = "assets/sprites/miro_dormindo.png"

COLUNAS: int = 4
LINHAS: int = 8

## Ordem das linhas da folha de origem. E a mesma de DIRECOES em
## gerar_miro_8dir.py e do enum Vista em scripts/jogador.gd.
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

## Quadro de origem: a pose de parado de cada linha.
QUADRO_BASE: int = 0

# --- medidas da figura -------------------------------------------------------

## Linhas de corte da celula de origem (70x100), medidas no mapa de cores da
## folha, nao supostas. Valem para as oito vistas porque todas as figuras foram
## montadas na mesma grade, com os pes na base da celula — as diferencas de
## altura entre elas sao de 1 a 3 px.
##
##   7..50   cabelo e rosto
##  50..64   ombros e peito
##  64..80   maos, nas pontas, com o tronco entre elas
##  80..89   pernas
##  89..100  botas
OMBRO: int = 50
QUADRIL: int = 80
CHAO: int = 100

# --- respiracao --------------------------------------------------------------

## Linhas em que a respiracao reparte a compressao. Nao sao articulacoes: foram
## escolhidas pelo resultado na tela. O corte alto cai no meio do rosto, e e
## isso que faz a compressao se diluir em duas faixas em vez de abrir um degrau
## visivel no pescoco.
PESCOCO: int = 34
CINTURA: int = 56

## Quanto a figura afunda em cada quadro do ciclo. A cabeca desce o valor
## inteiro e o tronco desce a metade, entao a compressao se reparte em vez de
## abrir um degrau no pescoco.
##
## Dois pixels numa figura de 93 e 2%: aparece como peito subindo e descendo, e
## nao como personagem encolhendo. Tres ja le como agachamento — e e exatamente
## por isso que a martelada usa quatro.
RESPIRACAO: list[int] = [0, 1, 2, 1]


def _afundar(celula: Image.Image, quanto: int) -> Image.Image:
	"""Desce a cabeca `quanto` px e o tronco metade disso, pes parados."""
	if quanto <= 0:
		return celula.copy()
	largura, altura = celula.size
	cabeca = celula.crop((0, 0, largura, PESCOCO))
	tronco = celula.crop((0, PESCOCO, largura, CINTURA))
	meio = quanto // 2
	saida = celula.copy()
	# Apaga da cintura para cima antes de recolar: o recorte tem alfa, e colar
	# por cima deixaria o contorno velho aparecendo acima do novo.
	ImageDraw.Draw(saida).rectangle((0, 0, largura, CINTURA - 1), fill=(0, 0, 0, 0))
	saida.alpha_composite(tronco, (0, PESCOCO + meio))
	saida.alpha_composite(cabeca, (0, quanto))
	return saida


## Quanto a linha `y` desceu num afundamento de `quanto`. E a mesma reparticao
## de _afundar lida ao contrario, e existe para a picareta saber onde a luva
## foi parar: a mao fica abaixo da cintura, que e a faixa que nao se mexe.
def _afundamento_em(y: int, quanto: int) -> int:
	if quanto <= 0:
		return 0
	if y < PESCOCO:
		return quanto
	if y < CINTURA:
		return quanto // 2
	return 0


# --- picareta ----------------------------------------------------------------

## Angulos da ferramenta nos quatro quadros, em graus de tela: 0 e para a
## direita e o angulo cresce para baixo. A ordem e erguida, descendo, batida,
## voltando.
##
## O arco e curto de proposito. Nenhuma pose de braco erguido existe na folha,
## entao uma martelada de 180 graus deixaria a picareta descrevendo um circulo
## que o corpo nao acompanha. Curto, ela le como quem lasca chapa com o pulso —
## e agora o tronco e o braco entram junto, em _golpear().
##
## As linhas viradas para a esquerda sao as viradas para a direita refletidas no
## eixo vertical (a -> 180 - a), e estao escritas ja refletidas.
ANGULOS: dict = {
	"baixo": [-80.0, -20.0, 65.0, -30.0],
	"direita": [-75.0, -30.0, 25.0, -25.0],
	"esquerda": [-105.0, -150.0, 155.0, -155.0],
	"baixo_direita": [-78.0, -25.0, 45.0, -28.0],
	"baixo_esquerda": [-102.0, -155.0, 135.0, -152.0],
	# As tres vistas de costas sao o caso dificil: o alvo fica do lado de la do
	# corpo, e um arco centrado nele some atras das costas — foi o que saiu na
	# primeira versao, com quatro quadros sem ferramenta nenhuma. Aqui o arco
	# corre na MARGEM, do lado da mao que segura, e so o trecho que cruza o
	# corpo fica escondido. Le como quem bate de lado, que e o melhor que uma
	# silhueta de costas sustenta sem braco redesenhado.
	"cima": [-140.0, -175.0, 150.0, 170.0],
	"cima_direita": [-40.0, -5.0, 30.0, 10.0],
	"cima_esquerda": [-140.0, -175.0, 150.0, 170.0],
}

## Mao que segura a ferramenta em cada linha: e o centroide da luva vermelha,
## medido na folha. A picareta nasce dela — nao do centro da figura — porque
## ferramenta solta no meio do peito nao parece segura por ninguem.
MAO: dict = {
	"baixo": (51, 70),
	"direita": (49, 68),
	"esquerda": (21, 67),
	"baixo_direita": (52, 67),
	"baixo_esquerda": (17, 66),
	# De costas a mao escolhida e a do lado para onde a ferramenta corre. Sao os
	# centroides medidos, sem empurrao: a primeira versao deslocava a mao 3 px
	# para fora das costas e a ferramenta saia flutuando ao lado do corpo, sem
	# nada segurando — agora a propria mao e recolocada por cima do cabo, e ela
	# precisa cair onde a luva esta de verdade.
	"cima": (18, 70),
	"cima_direita": (51, 68),
	"cima_esquerda": (18, 67),
}

## Linhas em que a ferramenta fica do lado de LA do corpo. Quem esta de costas
## bate num ponto mais longe que ele proprio, e a picareta passa por tras.
ATRAS: set = {"cima", "cima_direita", "cima_esquerda"}

# --- o golpe do corpo --------------------------------------------------------
#
# A primeira versao mexia so na ferramenta: o boneco ficava parado e a picareta
# girava ao lado dele. O que faltava era o personagem bater — entao o gesto hoje
# tem tres partes, todas deformacoes por LINHA ou por BLOCO, nunca rotacao.
# Rotacionar uma figura de 70x100 com reamostragem esfarrapa o contorno de um
# pixel que a arte inteira usa.

## Quanto o tronco inclina no sentido do golpe, em pixels no topo da cabeca.
##
## A inclinacao decai linearmente ate zero nos pes (CHAO), entao a cabeca anda
## os oito pixels inteiros, a mao pouco menos de um terco disso e as botas nada.
## E o peso indo para a frente e voltando — o unico jeito de o golpe sair do
## braco e virar corpo inteiro sem redesenhar pose nenhuma.
INCLINACAO: list[int] = [-6, -2, 8, -3]

## Quanto a figura afunda em cada quadro, na mesma mecanica da respiracao.
## Quatro pixels seria agachamento numa pose parada; num golpe e exatamente o
## que se quer — o corpo cede sobre a ferramenta no impacto.
AGACHAMENTO: list[int] = [0, 1, 4, 2]

## Quanto a mao que segura sobe em cada quadro.
##
## Sempre para CIMA, nunca abaixo do lugar de origem: subir encurta o braco, que
## e o que o cotovelo faz ao dobrar, e a mao se sobrepoe ao antebraco sem deixar
## falha. Descer abriria um vao entre o punho e a manga — braco descolado.
## Por isso o impacto e o zero da escala: no golpe o braco esta estendido, que e
## a pose certa, e os outros tres quadros o recolhem.
ALTURA_DA_MAO: list[int] = [-7, -3, 0, -5]

def _inclinar(celula: Image.Image, quanto: int) -> Image.Image:
	"""Inclina a figura `quanto` px no topo, decaindo a zero nos pes.

	E um cisalhamento por LINHA — cada linha de pixels inteira anda para o lado,
	sem reamostragem — e por isso nenhum contorno esfarrapa. Uma rotacao de
	verdade daria o mesmo gesto e destruiria o traco de um pixel.
	"""
	if quanto == 0:
		return celula.copy()
	largura, altura = celula.size
	saida = Image.new("RGBA", celula.size, (0, 0, 0, 0))
	for y in range(altura):
		saida.alpha_composite(
			celula.crop((0, y, largura, y + 1)), (round(quanto * _perfil(y)), y)
		)
	return saida


## Quanto da inclinacao chega a esta linha: 1 no topo da figura, 0 no chao.
## Linear, e nao so acima do quadril, de proposito — as pernas acompanham com
## um pixel, que e a transferencia de peso. Travadas, o tronco pareceria
## dobrar sobre uma estatua.
def _perfil(y: int) -> float:
	return max(0.0, (CHAO - y) / float(CHAO))


## Meia-caixa em que o preenchimento da mao pode andar, em pixels. A mao medida
## cabe em 14x16, entao a caixa tem folga de sobra e ainda termina longe do
## centro do tronco. E a trava final contra um preenchimento que escape.
CAIXA_DA_MAO: tuple = (14, 12)

## Ate onde a mascara cresce para capturar o contorno da mao, em pixels.
##
## Dois, e nao um: o desenho fecha a luva com fio escuro MAIS uma sombra, e com
## um pixel so a sombra ficava para tras no lugar antigo — um anel vermelho
## vazado ao lado do braco, a coisa mais visivel da folha inteira. O crescimento
## so aceita pixel escuro, senao os dois pixels levariam junto uma lasca do
## traje azul.
CONTORNO_DA_MAO: int = 2
ESCURO_MAXIMO: int = 170


def _regiao_da_mao(celula: Image.Image, centro: tuple) -> list:
	"""Pixels da mao que segura: os que mudam de lugar e os que sao apagados.

	Preenchimento a partir do centroide da luva, andando so por pele e pelo
	vermelho da luva. A faixa de vermelho e estreita de proposito: o contorno
	escuro do desenho e um fio continuo que vai da luva ate a bota, e aceitar o
	vermelho quase preto fazia o preenchimento correr por ele e tomar a coxa.
	O contorno entra depois, pelo crescimento, que nao propaga.
	"""
	px = celula.load()
	largura, altura = celula.size

	def na_caixa(x: int, y: int) -> bool:
		return abs(x - centro[0]) <= CAIXA_DA_MAO[0] and abs(y - centro[1]) <= CAIXA_DA_MAO[1]

	def da_mao(x: int, y: int) -> bool:
		if not na_caixa(x, y):
			return False
		r, g, b, a = px[x, y]
		if a < 128:
			return False
		if r > 225 and 140 < g < 215 and 90 < b < 180:
			return True  # pele
		# A faixa vai do vermelho escuro ao realce claro da luva. O teto baixo da
		# primeira versao deixava o realce para tras, e ele sobrava no lugar
		# antigo como um fio vermelho vazado. O cabelo cai nesta mesma faixa e
		# nao e problema: a caixa nao chega perto dele.
		return 40 < r < 215 and g < 80 and b < 90  # luva

	semente = None
	for raio in range(8):
		for dy in range(-raio, raio + 1):
			for dx in range(-raio, raio + 1):
				x, y = centro[0] + dx, centro[1] + dy
				if 0 <= x < largura and 0 <= y < altura and da_mao(x, y):
					semente = (x, y)
					break
			if semente:
				break
		if semente:
			break
	if semente is None:
		return [], []

	vistos = {semente}
	pilha = [semente]
	while pilha:
		x, y = pilha.pop()
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			n = (x + dx, y + dy)
			if n in vistos or not (0 <= n[0] < largura and 0 <= n[1] < altura):
				continue
			if da_mao(n[0], n[1]):
				vistos.add(n)
				pilha.append(n)

	def crescer(acima: int, abaixo: int, com_vermelho: bool) -> set:
		fora = set(vistos)
		for x, y in vistos:
			for dx in range(-abaixo, abaixo + 1):
				for dy in range(-acima, abaixo + 1):
					n = (x + dx, y + dy)
					if not (0 <= n[0] < largura and 0 <= n[1] < altura) or not na_caixa(*n):
						continue
					r, g, b, a = px[n[0], n[1]]
					if a <= 128:
						continue
					if r + g + b < ESCURO_MAXIMO:
						fora.add(n)
					elif com_vermelho and r > g * 1.6 and r > b * 1.6:
						fora.add(n)
		return fora

	# A mao e COLADA com o contorno justo e APAGADA com uma margem maior — mas a
	# margem extra so vale para BAIXO. A mao sobe, entao e embaixo que fica o
	# rastro; apagar a mesma margem por cima comia o antebraco, e a luva subia
	# deixando um vao entre ela e a manga. O vao era pior que o rastro.
	#
	# Para colar, so o escuro do contorno entra; para apagar, o vermelho tambem,
	# porque o que sobrava embaixo era o realce claro da luva. Vermelho embaixo
	# da mao e sempre luva: o traje ali e azul, e o cachecol fica bem acima.
	justo: int = CONTORNO_DA_MAO
	return (
		sorted(crescer(justo, justo, False)),
		sorted(crescer(justo, justo + 3, True)),
	)


## Mancha solta menor que isto, depois de a mao mudar de lugar, e resto do
## lugar antigo. A figura de origem e um blob so — gerar_miro_8dir.py garante
## isso — entao qualquer ilha que apareca aqui foi este gerador que deixou.
RESTO_MAXIMO: int = 14


def _so_a_mao(celula: Image.Image, colar: list, subir: int) -> Image.Image:
	"""Uma imagem do tamanho da celula com a mao e mais nada, ja na altura dela.

	Serve para recolocar a mao DEPOIS da ferramenta. A empunhadura e larga o
	bastante para cobrir o punho, e com a mao por baixo o quadro saia com um
	bloco vermelho no lugar dela — ninguem segurando coisa nenhuma. Por cima, os
	dedos ficam na frente do cabo, que e como se segura uma picareta.
	"""
	saida = Image.new("RGBA", celula.size, (0, 0, 0, 0))
	if not colar:
		return saida
	origem = celula.load()
	desenho = saida.load()
	for x, y in colar:
		if y - subir >= 0:
			desenho[x, y - subir] = origem[x, y]
	return saida


def _limpar_restos(celula: Image.Image) -> Image.Image:
	"""Apaga ilhas de pixels que sobraram do lugar antigo da mao.

	A margem apagada em _regiao_da_mao resolve quase tudo, mas ela so alcanca o
	escuro: um pixel de realce claro da luva escapa de vez em quando. Pixel solto
	ao lado de uma figura limpa e o que o olho acha primeiro, entao a varredura
	fecha a conta sem precisar afinar faixa de cor nenhuma.
	"""
	largura, altura = celula.size
	px = celula.load()
	visto = [[False] * largura for _ in range(altura)]
	saida = celula.copy()
	desenho = saida.load()
	for y0 in range(altura):
		for x0 in range(largura):
			if visto[y0][x0] or px[x0, y0][3] <= 128:
				continue
			pilha = [(x0, y0)]
			visto[y0][x0] = True
			ilha = []
			while pilha:
				x, y = pilha.pop()
				ilha.append((x, y))
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = x + dx, y + dy
					if (
						0 <= nx < largura
						and 0 <= ny < altura
						and not visto[ny][nx]
						and px[nx, ny][3] > 128
					):
						visto[ny][nx] = True
						pilha.append((nx, ny))
			if len(ilha) <= RESTO_MAXIMO:
				for x, y in ilha:
					desenho[x, y] = (0, 0, 0, 0)
	return saida


def _dobrar_o_braco(celula: Image.Image, mao: tuple, subir: int) -> Image.Image:
	"""Sobe a mao `subir` px, deixando o resto do braco onde esta.

	O vazio que sobra embaixo e o braco encurtando — que e o que o cotovelo faz
	ao dobrar — e nao um buraco: a mao fica na PONTA da silhueta, entao o que
	some e a ponta. E por isso que `subir` nunca e negativo: descer abriria um
	vao entre o punho e a manga, e isso le como braco descolado.
	"""
	colar, apagar = mao
	if subir <= 0 or not colar:
		return celula.copy()
	saida = celula.copy()
	desenho = saida.load()
	origem = celula.load()
	for x, y in apagar:
		desenho[x, y] = (0, 0, 0, 0)
	for x, y in colar:
		if y - subir >= 0:
			desenho[x, y - subir] = origem[x, y]
	return saida


## Medidas da picareta, em pixels da celula de origem. O cabo passa 9 px alem da
## mao para a empunhadura aparecer dos dois lados do punho.
CABO: int = 30
RABO: int = 9
CABECA: int = 9

COR_CABO = (92, 71, 52, 255)
COR_CABO_LUZ = (138, 108, 78, 255)
COR_PUNHO = (134, 46, 44, 255)
COR_FERRO = (126, 139, 155, 255)
COR_FERRO_LUZ = (198, 212, 226, 255)
COR_FERRO_SOMBRA = (48, 56, 70, 255)
COR_FAISCA = (255, 226, 150, 255)

## Folga da celula de trabalho em volta da celula de origem. 15 de cada lado
## cabem os 30 px do cabo nas vistas laterais; 10 em cima cabem a ferramenta
## erguida sem encostar na borda.
FOLGA_LADO: int = 15
FOLGA_TOPO: int = 10


def _desenhar_picareta(tela: Image.Image, pivo: tuple, graus: float, bate: bool) -> None:
	rad = math.radians(graus)
	dx, dy = math.cos(rad), math.sin(rad)
	nx, ny = -dy, dx
	px, py = pivo

	def ponto(ao_longo: float, ao_lado: float = 0.0) -> tuple:
		return (px + dx * ao_longo + nx * ao_lado, py + dy * ao_longo + ny * ao_lado)

	desenho = ImageDraw.Draw(tela)
	# Cabo: contorno escuro, madeira, e um fio de luz na aresta de cima.
	desenho.line([ponto(-RABO), ponto(CABO)], fill=COR_FERRO_SOMBRA, width=5)
	desenho.line([ponto(-RABO), ponto(CABO)], fill=COR_CABO, width=3)
	desenho.line([ponto(-RABO + 2, -1), ponto(CABO - 3, -1)], fill=COR_CABO_LUZ, width=1)
	# Empunhadura, na cor das luvas: e o que amarra a ferramenta a mao. Curta,
	# porque a mao e recolocada por cima dela — uma empunhadura longa aparecia
	# dos dois lados do punho como um bloco vermelho solto.
	desenho.line([ponto(-RABO + 3), ponto(1)], fill=COR_PUNHO, width=3)

	# Cabeca: hexagono que afina para as duas pontas, uma de bico e outra de pa.
	corpo = [
		ponto(CABO + 1, -CABECA),
		ponto(CABO + 4, -3),
		ponto(CABO + 4, 3),
		ponto(CABO + 1, CABECA),
		ponto(CABO - 3, 3),
		ponto(CABO - 3, -3),
	]
	desenho.polygon(corpo, fill=COR_FERRO, outline=COR_FERRO_SOMBRA)
	desenho.line([ponto(CABO + 2, -CABECA + 2), ponto(CABO + 3, -3)], fill=COR_FERRO_LUZ, width=1)

	if bate:
		# Faiscas so no quadro da batida, e so na ponta que encosta.
		for ao_longo, ao_lado in ((CABO + 6, -11), (CABO + 8, -7), (CABO + 7, -14)):
			desenho.point(ponto(ao_longo, ao_lado), fill=COR_FAISCA)


# --- dormindo ----------------------------------------------------------------

## Caixas dos dois olhos na linha "baixo", medidas na folha. A pose deitada e a
## frontal: visto de cima, quem esta de costas na cama mostra o rosto, com a
## cabeca no travesseiro e os pes na beira — exatamente o enquadramento da
## vista de frente.
OLHOS: list = [(29, 36, 30, 42), (39, 36, 41, 42)]

## Cor da pele do rosto, lida ao lado dos olhos na propria folha.
COR_PELE = (252, 194, 148, 255)
COR_CILIO = (92, 48, 36, 255)

## Cobertor: comeca no peito e cobre ate os pes. Nao e enfeite — e o que resolve
## a pose. Deitado de costas, o desenho das pernas em pe continuaria ali e leria
## como alguem de pe visto de cima; coberto, some.
COBERTOR_TOPO: int = 56
COBERTOR_BASE: int = 96
COBERTOR_ESQUERDA: int = 12
COBERTOR_DIREITA: int = 58

COR_COBERTOR = (44, 86, 102, 255)
COR_COBERTOR_LUZ = (72, 128, 146, 255)
COR_COBERTOR_VULTO = (50, 93, 110, 255)
COR_COBERTOR_SOMBRA = (24, 52, 64, 255)


def _cobrir(celula: Image.Image, quanto: int) -> None:
	"""Poe o cobertor por cima da figura, subindo e descendo com o peito."""
	desenho = ImageDraw.Draw(celula)
	topo = COBERTOR_TOPO + quanto
	desenho.rounded_rectangle(
		(COBERTOR_ESQUERDA, topo, COBERTOR_DIREITA, COBERTOR_BASE),
		radius=7,
		fill=COR_COBERTOR,
		outline=COR_COBERTOR_SOMBRA,
	)
	# Dobra de cima: a faixa clara e o que da espessura ao pano, e sem ela o
	# cobertor le como tampa encostada no peito.
	desenho.rounded_rectangle(
		(COBERTOR_ESQUERDA + 1, topo + 1, COBERTOR_DIREITA - 1, topo + 4),
		radius=2,
		fill=COR_COBERTOR_LUZ,
	)
	# O vulto do corpo por baixo. E o que separa cobertor de caixa: um pano
	# chapado de ponta a ponta nao tem ninguem dentro.
	desenho.rounded_rectangle(
		(22, topo + 7, 48, COBERTOR_BASE - 12), radius=8, fill=COR_COBERTOR_VULTO
	)
	for x in (21, 39):
		desenho.ellipse((x, COBERTOR_BASE - 14, x + 11, COBERTOR_BASE - 4), fill=COR_COBERTOR_VULTO)
	# Vincos curtos, saindo do vulto para a beira — pano caindo dos lados do
	# corpo. Riscos retos de ponta a ponta viram ripa de engradado.
	for x0, x1 in ((20, 15), (50, 55)):
		for desvio in (10, 22):
			desenho.line(
				(x0, topo + 9 + desvio, x1, topo + 15 + desvio), fill=COR_COBERTOR_SOMBRA
			)


def _fechar_olhos(celula: Image.Image) -> None:
	desenho = ImageDraw.Draw(celula)
	for x0, y0, x1, y1 in OLHOS:
		desenho.rectangle((x0, y0, x1, y1), fill=COR_PELE)
		# A palpebra fechada e mais larga que o olho aberto, e e so uma linha.
		desenho.line((x0 - 1, (y0 + y1) // 2, x1 + 1, (y0 + y1) // 2), fill=COR_CILIO)


# --- montagem ----------------------------------------------------------------


def gerar() -> None:
	folha = Image.open(ORIGEM).convert("RGBA")
	cw, ch = folha.width // COLUNAS, folha.height // LINHAS
	bases = [
		folha.crop((QUADRO_BASE * cw, l * ch, (QUADRO_BASE + 1) * cw, (l + 1) * ch))
		for l in range(LINHAS)
	]

	parado = Image.new("RGBA", (cw * COLUNAS, ch * LINHAS), (0, 0, 0, 0))
	for linha in range(LINHAS):
		for coluna, quanto in enumerate(RESPIRACAO):
			parado.paste(_afundar(bases[linha], quanto), (coluna * cw, linha * ch))
	parado.save(SAIDA_PARADO)

	tw, th = cw + FOLGA_LADO * 2, ch + FOLGA_TOPO
	trabalho = Image.new("RGBA", (tw * COLUNAS, th * LINHAS), (0, 0, 0, 0))
	for linha in range(LINHAS):
		direcao = DIRECOES[linha]
		mao = MAO[direcao]
		atras = direcao in ATRAS
		angulos = ANGULOS[direcao]
		# Para que lado o corpo joga o peso: o mesmo lado para onde a ferramenta
		# aponta no impacto. Lido do proprio angulo, e nao de uma tabela a parte,
		# para a inclinacao nunca brigar com o golpe.
		sentido = 1 if math.cos(math.radians(angulos[2])) >= 0.0 else -1
		# A mao e achada no quadro base, antes de qualquer deformacao: as
		# deformacoes sao todas de bloco ou de linha, entao os mesmos pixels
		# continuam sendo a mao depois delas.
		pixels_da_mao = _regiao_da_mao(bases[linha], mao)
		for coluna, graus in enumerate(angulos):
			inclinacao = INCLINACAO[coluna] * sentido
			subir = -ALTURA_DA_MAO[coluna]
			corpo = _dobrar_o_braco(bases[linha], pixels_da_mao, subir)
			corpo = _limpar_restos(corpo)
			corpo = _afundar(corpo, AGACHAMENTO[coluna])
			corpo = _inclinar(corpo, inclinacao)

			# O punho segue o corpo: a mao subiu, o tronco inclinou e a figura
			# afundou, entao o cabo tem de nascer onde a luva foi parar. Sem
			# isso a ferramenta fica para tras e some a empunhadura.
			altura_da_mao = mao[1] - subir + _afundamento_em(mao[1], AGACHAMENTO[coluna])
			pivo = (
				mao[0] + FOLGA_LADO + inclinacao * _perfil(altura_da_mao),
				altura_da_mao + FOLGA_TOPO,
			)

			celula = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
			if atras:
				_desenhar_picareta(celula, pivo, graus, coluna == 2)
				celula.alpha_composite(corpo, (FOLGA_LADO, FOLGA_TOPO))
			else:
				celula.alpha_composite(corpo, (FOLGA_LADO, FOLGA_TOPO))
				_desenhar_picareta(celula, pivo, graus, coluna == 2)
			# A mao volta por cima da ferramenta, com as mesmas deformacoes do
			# corpo — a translacao ao colar, o cisalhamento depois. O
			# afundamento nao entra: a mao fica abaixo da cintura, que e a faixa
			# que nao se mexe.
			mao_na_frente = _inclinar(
				_so_a_mao(bases[linha], pixels_da_mao[0], subir), inclinacao
			)
			celula.alpha_composite(mao_na_frente, (FOLGA_LADO, FOLGA_TOPO))
			trabalho.paste(celula, (coluna * tw, linha * th))
	trabalho.save(SAIDA_TRABALHO)

	dormindo = Image.new("RGBA", (cw * COLUNAS, ch), (0, 0, 0, 0))
	for coluna, quanto in enumerate(RESPIRACAO):
		celula = _afundar(bases[DIRECOES.index("baixo")], quanto)
		_fechar_olhos(celula)
		_cobrir(celula, quanto)
		dormindo.paste(celula, (coluna * cw, 0))
	dormindo.save(SAIDA_DORMINDO)

	print("gerado: %s (%dx%d, quadros de %dx%d)" % (SAIDA_PARADO, parado.width, parado.height, cw, ch))
	print("gerado: %s (%dx%d, quadros de %dx%d)" % (SAIDA_TRABALHO, trabalho.width, trabalho.height, tw, th))
	print("gerado: %s (%dx%d, quadros de %dx%d)" % (SAIDA_DORMINDO, dormindo.width, dormindo.height, cw, ch))
	print("offset do Sprite2D parado/dormindo: Vector2(0, %.1f)" % -(ch / 2.0 - 4.0))
	print("offset do Sprite2D trabalhando:     Vector2(0, %.1f)" % -(th / 2.0 - 4.0))


if __name__ == "__main__":
	gerar()
