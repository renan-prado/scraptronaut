# Gera a fonte de texto do jogo.
#
#   assets/interface/fonte.png   atlas dos glifos, branco sobre transparente
#   assets/interface/fonte.fnt   metrica BMFont que o Godot importa
#
# POR QUE UMA FONTE PROPRIA
#
# Ate aqui todo texto do jogo saia na fonte padrao do Godot, que e vetorial: ao
# lado de uma estacao desenhada pixel a pixel, a letra antiserrilhada denuncia
# duas resolucoes na mesma tela. A folha de teclas ja tinha um alfabeto de
# pixel (tools/gerar_interface.py), mas so em caixa alta e so para a tampa.
#
# A METRICA MANDA NO RESTO
#
# A linha tem ALTURA_LINHA pixels de arte e o Godot a desenha em ESCALA INTEIRA
# (TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY): pedir corpo 12 da 1x, corpo 24 da
# 2x, e nao existe meio termo. Por isso a altura da linha e pequena — e o passo
# entre o texto miudo da interface e o texto grande da fala, e um passo de 2x
# so cabe se o primeiro degrau for baixo.
#
#   linhas 0-1   acento
#   linha  2     a folga entre o acento e a letra
#   linhas 3-8   caixa alta e ascendente (6 linhas)
#   linhas 5-8   caixa baixa (4 linhas)
#   linha  9     a base; dai para baixo so desce perna
#   linhas 9-10  descendente
#
# A LINHA DE FOLGA NAO E SOBRA. Sem ela o til encostava no "a" e os dois saiam
# como uma mancha so: "Nao" ficava com um bloco no lugar do "a". Um pixel de ar
# e o que separa a marca da letra em caixa alta, que e onde o aperto e maior.
#
# OS ACENTOS SAO COMPOSTOS, NAO DESENHADOS
#
# Portugues precisa de treze letras acentuadas em cada caixa. Desenhar as vinte
# e seis a mao seria vinte e seis lugares para o mesmo "a" sair diferente: aqui
# o acento e uma marca pequena que o gerador assenta ACIMA da letra, e a letra
# base continua sendo uma so.
from PIL import Image

SAIDA_PNG = "assets/interface/fonte.png"
SAIDA_FNT = "assets/interface/fonte.fnt"

## A metrica, em pixels de arte. Mexer aqui mexe no corpo de todo texto do jogo.
ALTURA_LINHA: int = 12
BASE: int = 9
TOPO_ALTA: int = 3
TOPO_BAIXA: int = 5

## Linha em branco entre a marca de acento e a letra. Ver o cabecalho.
FOLGA_ACENTO: int = 1

## Folga entre uma letra e a seguinte. Um pixel: varios desenhos ja trazem
## coluna vazia propria, e dois abririam buraco no meio da palavra.
AVANCO: int = 1

## Largura do espaco, em pixels de arte.
ESPACO: int = 3

## Celula do atlas e quantas cabem por linha. Grade folgada de proposito: a
## folha inteira sai com alguns kilobytes, e empacotamento apertado so faria o
## gerador dificil de ler sem economizar nada que se note.
CELULA_X: int = 8
CELULA_Y: int = 12
COLUNAS: int = 16

BRANCO = (255, 255, 255, 255)


# --- os glifos ---------------------------------------------------------------
#
# Cada desenho e uma lista de linhas, "#" e tinta. A linha do topo de cada
# desenho vai na tabela ao lado, porque e ela que separa ascendente de
# descendente: "b" comeca em TOPO_ALTA e "p" em TOPO_BAIXA.

ALTA = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#"],
	"B": ["####.", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["####", "#...", "###.", "#...", "#...", "####"],
	"F": ["####", "#...", "###.", "#...", "#...", "#..."],
	"G": [".###.", "#...#", "#....", "#..##", "#...#", ".###."],
	"H": ["#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["###", ".#.", ".#.", ".#.", ".#.", "###"],
	"J": ["..##", "...#", "...#", "...#", "#..#", ".##."],
	"K": ["#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#...", "#...", "#...", "#...", "#...", "####"],
	"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#..#.", "#...#"],
	"S": [".####", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
	"X": ["#...#", ".#.#.", "..#..", "..#..", ".#.#.", "#...#"],
	"Y": ["#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".##.", "#..#", "#.##", "##.#", "#..#", ".##."],
	"1": [".#..", "##..", ".#..", ".#..", ".#..", "###."],
	"2": [".##.", "#..#", "...#", "..#.", ".#..", "####"],
	"3": ["####", "...#", "..#.", "...#", "#..#", ".##."],
	"4": ["..#.", ".##.", "#.#.", "####", "..#.", "..#."],
	"5": ["####", "#...", "###.", "...#", "#..#", ".##."],
	"6": [".##.", "#...", "###.", "#..#", "#..#", ".##."],
	"7": ["####", "...#", "..#.", "..#.", ".#..", ".#.."],
	"8": [".##.", "#..#", ".##.", "#..#", "#..#", ".##."],
	"9": [".##.", "#..#", "#..#", ".###", "...#", ".##."],
}

## Caixa baixa. A chave e a letra; o valor e (topo, desenho). Quem comeca em
## TOPO_ALTA tem haste subindo e quem passa da linha 7 tem perna descendo — e a
## mistura das tres alturas que faz uma palavra em caixa baixa ler como palavra,
## e nao como fila de caixas iguais.
BAIXA = {
	"a": (TOPO_BAIXA, [".###", "#..#", "#..#", ".###"]),
	"b": (TOPO_ALTA, ["#...", "#...", "###.", "#..#", "#..#", "###."]),
	"c": (TOPO_BAIXA, [".###", "#...", "#...", ".###"]),
	"d": (TOPO_ALTA, ["...#", "...#", ".###", "#..#", "#..#", ".###"]),
	"e": (TOPO_BAIXA, [".##.", "####", "#...", ".###"]),
	"f": (TOPO_ALTA, [".##", "#..", "###", "#..", "#..", "#.."]),
	"g": (TOPO_BAIXA, [".##.", "#..#", "#..#", ".###", "...#", "###."]),
	"h": (TOPO_ALTA, ["#...", "#...", "###.", "#..#", "#..#", "#..#"]),
	"i": (TOPO_ALTA, ["#", ".", "#", "#", "#", "#"]),
	"j": (TOPO_ALTA, ["..#", "...", "..#", "..#", "..#", "..#", "..#", "##."]),
	"k": (TOPO_ALTA, ["#...", "#...", "#.#.", "##..", "#.#.", "#..#"]),
	"l": (TOPO_ALTA, ["#", "#", "#", "#", "#", "#"]),
	"m": (TOPO_BAIXA, ["#####", "#.#.#", "#.#.#", "#.#.#"]),
	"n": (TOPO_BAIXA, ["###.", "#..#", "#..#", "#..#"]),
	"o": (TOPO_BAIXA, [".##.", "#..#", "#..#", ".##."]),
	"p": (TOPO_BAIXA, ["###.", "#..#", "#..#", "###.", "#...", "#..."]),
	"q": (TOPO_BAIXA, [".##.", "#..#", "#..#", ".###", "...#", "...#"]),
	"r": (TOPO_BAIXA, ["#.#", "##.", "#..", "#.."]),
	"s": (TOPO_BAIXA, [".###", "##..", "..##", "###."]),
	"t": (TOPO_ALTA + 1, [".#.", "###", ".#.", ".#.", ".##"]),
	"u": (TOPO_BAIXA, ["#..#", "#..#", "#..#", ".###"]),
	"v": (TOPO_BAIXA, ["#...#", "#...#", ".#.#.", "..#.."]),
	"w": (TOPO_BAIXA, ["#...#", "#.#.#", "#.#.#", ".#.#."]),
	"x": (TOPO_BAIXA, ["#..#", ".##.", ".##.", "#..#"]),
	"y": (TOPO_BAIXA, ["#..#", "#..#", "#..#", ".###", "...#", "###."]),
	"z": (TOPO_BAIXA, ["####", "..#.", ".#..", "####"]),
}

## Pontuacao e sinais. Mesmo formato da caixa baixa: (topo, desenho).
SINAIS = {
	".": (BASE - 1, ["#"]),
	",": (BASE - 1, [".#", "#."]),
	":": (TOPO_BAIXA + 1, ["#", ".", "#"]),
	";": (TOPO_BAIXA + 1, [".#", "..", ".#", "#."]),
	"!": (TOPO_ALTA, ["#", "#", "#", "#", ".", "#"]),
	"?": (TOPO_ALTA, [".##.", "#..#", "...#", "..#.", "....", "..#."]),
	"'": (TOPO_ALTA, ["#", "#"]),
	'"': (TOPO_ALTA, ["#.#", "#.#"]),
	"(": (TOPO_ALTA, [".#", "#.", "#.", "#.", "#.", "#.", ".#"]),
	")": (TOPO_ALTA, ["#.", ".#", ".#", ".#", ".#", ".#", "#."]),
	"-": (TOPO_BAIXA + 1, ["###"]),
	"—": (TOPO_BAIXA + 1, ["#####"]),
	"·": (TOPO_BAIXA + 1, ["#"]),
	"×": (TOPO_BAIXA - 1, ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]),
	"+": (TOPO_BAIXA - 1, ["..#..", "..#..", "#####", "..#..", "..#.."]),
	"=": (TOPO_BAIXA, ["####", "....", "####"]),
	"/": (TOPO_ALTA, ["...#", "...#", "..#.", ".#..", "#...", "#..."]),
	"\\": (TOPO_ALTA, ["#...", "#...", ".#..", "..#.", "...#", "...#"]),
	"%": (TOPO_ALTA, ["##..#", "##.#.", "..#..", ".#.##", "#..##", "....."]),
	"°": (TOPO_ALTA, ["##", "##"]),
	"[": (TOPO_ALTA, ["##", "#.", "#.", "#.", "#.", "#.", "##"]),
	"]": (TOPO_ALTA, ["##", ".#", ".#", ".#", ".#", ".#", "##"]),
	"<": (TOPO_BAIXA - 1, ["..#", ".#.", "#..", ".#.", "..#"]),
	">": (TOPO_BAIXA - 1, ["#..", ".#.", "..#", ".#.", "#.."]),
	"_": (BASE + 1, ["####"]),
	"*": (TOPO_ALTA, ["#.#", ".#.", "#.#"]),
	"#": (TOPO_ALTA, [".#.#.", "#####", ".#.#.", "#####", ".#.#."]),
	"@": (TOPO_ALTA, [".###.", "#...#", "#.###", "#.###", "#....", ".###."]),
	"&": (TOPO_ALTA, [".##..", "#..#.", ".##..", "#..#.", "#...#", ".####"]),
	"…": (BASE - 1, ["#.#.#"]),
}

## As marcas de acento, assentadas ACIMA da letra. Cada uma tem a largura que
## precisa: o til e o circunflexo nao leem na largura de dois do agudo.
MARCAS = {
	"agudo": [".#", "#."],
	"grave": ["#.", ".#"],
	"circunflexo": [".#.", "#.#"],
	# O til e um degrau, e nao uma onda: onda precisa de sobe-desce-sobe, e em
	# duas linhas isso vira tabuleiro de xadrez — a marca lia como sujeira sobre
	# a letra em vez de til. O degrau e a unica forma que ainda le a esta altura.
	"til": [".###", "##.."],
	"trema": ["#.#"],
}

## Letra acentuada -> (letra base, marca). A cedilha e o unico caso em que a
## marca desce em vez de subir, e por isso tem tabela propria.
ACENTUADAS = {
	"á": ("a", "agudo"), "à": ("a", "grave"),
	"â": ("a", "circunflexo"), "ã": ("a", "til"),
	"é": ("e", "agudo"), "ê": ("e", "circunflexo"),
	"í": ("i", "agudo"),
	"ó": ("o", "agudo"), "ô": ("o", "circunflexo"),
	"õ": ("o", "til"),
	"ú": ("u", "agudo"), "ü": ("u", "trema"),
	"Á": ("A", "agudo"), "À": ("A", "grave"),
	"Â": ("A", "circunflexo"), "Ã": ("A", "til"),
	"É": ("E", "agudo"), "Ê": ("E", "circunflexo"),
	"Í": ("I", "agudo"),
	"Ó": ("O", "agudo"), "Ô": ("O", "circunflexo"),
	"Õ": ("O", "til"),
	"Ú": ("U", "agudo"), "Ü": ("U", "trema"),
}

## O "i" acentuado nao leva pingo: o acento ocupa o lugar dele. Compor "í" a
## partir do "i" inteiro deixava duas marcas empilhadas sobre a mesma haste.
SEM_PINGO = {"i": (["#", "#", "#", "#"], TOPO_BAIXA)}

## A cedilha: um gancho que sai da base da letra e curva para a esquerda. Nao e
## um acento virado de cabeca para baixo — desenha-la assim dava um risco solto
## embaixo do "c", sem ligacao com ele.
CEDILHA = ["..#", ".##"]
CEDILHADAS = {"ç": "c", "Ç": "C"}


def _tamanho(desenho: list) -> tuple:
	return max(len(linha) for linha in desenho), len(desenho)


def _compor(base: list, topo: int, marca: list) -> tuple:
	"""Letra mais acento, numa so grade. Devolve (desenho, topo).

	Os dois sao centrados um no outro, com FOLGA_ACENTO linhas em branco entre
	eles. Sem essa folga o til encostava no "a" e saia uma mancha so no lugar da
	letra — ver o cabecalho.
	"""
	largura_base, _ = _tamanho(base)
	largura_marca, altura_marca = _tamanho(marca)
	largura = max(largura_base, largura_marca)
	recuo_base = (largura - largura_base) // 2
	recuo_marca = (largura - largura_marca) // 2
	linhas = []
	for linha in marca:
		linhas.append(("." * recuo_marca + linha).ljust(largura, "."))
	linhas += ["." * largura] * FOLGA_ACENTO
	for linha in base:
		linhas.append(("." * recuo_base + linha).ljust(largura, "."))
	return linhas, topo - altura_marca - FOLGA_ACENTO


def _cedilhar(base: list, topo: int) -> tuple:
	"""Letra mais cedilha. A marca desce, entao o topo nao muda."""
	largura_base, _ = _tamanho(base)
	largura = max(largura_base, len(CEDILHA[0]))
	recuo_base = (largura - largura_base) // 2
	recuo_marca = (largura - len(CEDILHA[0])) // 2
	linhas = [("." * recuo_base + linha).ljust(largura, ".") for linha in base]
	for linha in CEDILHA:
		linhas.append(("." * recuo_marca + linha).ljust(largura, "."))
	return linhas, topo


def glifos() -> dict:
	"""Todos os glifos da fonte: caractere -> (desenho, topo)."""
	tabela = {}
	for letra, desenho in ALTA.items():
		tabela[letra] = (desenho, TOPO_ALTA)
	for letra, (topo, desenho) in BAIXA.items():
		tabela[letra] = (desenho, topo)
	for sinal, (topo, desenho) in SINAIS.items():
		tabela[sinal] = (desenho, topo)
	for letra, (base, marca) in ACENTUADAS.items():
		desenho, topo = SEM_PINGO.get(base, tabela[base])
		tabela[letra] = _compor(desenho, topo, MARCAS[marca])
	for letra, base in CEDILHADAS.items():
		desenho, topo = tabela[base]
		tabela[letra] = _cedilhar(desenho, topo)
	return tabela


def gerar() -> None:
	tabela = glifos()
	ordem = sorted(tabela.keys(), key=ord)
	linhas_atlas = (len(ordem) + COLUNAS - 1) // COLUNAS
	atlas = Image.new(
		"RGBA", (COLUNAS * CELULA_X, linhas_atlas * CELULA_Y), (0, 0, 0, 0)
	)
	registros = []
	for indice, caractere in enumerate(ordem):
		desenho, topo = tabela[caractere]
		largura, altura = _tamanho(desenho)
		cx = (indice % COLUNAS) * CELULA_X
		cy = (indice // COLUNAS) * CELULA_Y
		for y, linha in enumerate(desenho):
			for x, ponto in enumerate(linha):
				if ponto == "#":
					atlas.putpixel((cx + x, cy + y), BRANCO)
		registros.append({
			"id": ord(caractere), "x": cx, "y": cy,
			"width": largura, "height": altura,
			"xoffset": 0, "yoffset": topo, "xadvance": largura + AVANCO,
		})
	# O espaco nao tem desenho, so avanco: celula de largura zero no atlas.
	registros.append({
		"id": 32, "x": 0, "y": 0, "width": 0, "height": 0,
		"xoffset": 0, "yoffset": 0, "xadvance": ESPACO,
	})
	atlas.save(SAIDA_PNG)

	nome_png = SAIDA_PNG.rsplit("/", 1)[-1]
	saida = [
		'info face="Scraptronaut" size=%d bold=0 italic=0 charset="" unicode=1'
		' stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0'
		% ALTURA_LINHA,
		"common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0"
		% (ALTURA_LINHA, BASE, atlas.width, atlas.height),
		'page id=0 file="%s"' % nome_png,
		"chars count=%d" % len(registros),
	]
	for r in registros:
		saida.append(
			"char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d"
			" xadvance=%d page=0 chnl=15"
			% (r["id"], r["x"], r["y"], r["width"], r["height"],
				r["xoffset"], r["yoffset"], r["xadvance"])
		)
	saida.append("kernings count=0")
	with open(SAIDA_FNT, "w", encoding="utf-8", newline="\n") as arquivo:
		arquivo.write("\n".join(saida) + "\n")

	print("gerado: %s (%dx%d, %d glifos)" % (
		SAIDA_PNG, atlas.width, atlas.height, len(registros)
	))
	print("gerado: %s (linha %d, base %d)" % (SAIDA_FNT, ALTURA_LINHA, BASE))


if __name__ == "__main__":
	gerar()
