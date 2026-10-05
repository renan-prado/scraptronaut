# Converte os tilesets de referencia em docs/ para atlas de 64x64 px por celula,
# gravados em assets/tiles/. Reexecutar apos trocar a arte de origem.
from PIL import Image

CELULA = 64
SAIDA = "assets/tiles"


def _reduzir(img: Image.Image, colunas: int, linhas: int) -> Image.Image:
	return img.resize((colunas * CELULA, linhas * CELULA), Image.BOX)


def piso() -> None:
	im = Image.open("docs/tileset-piso-2x2.png").convert("RGBA")
	_reduzir(im, 2, 2).save(f"{SAIDA}/piso.png")


def parede() -> None:
	im = Image.open("docs/tileset-parede-2x2.png").convert("RGBA")
	_reduzir(im, 2, 2).save(f"{SAIDA}/parede.png")


def porta() -> None:
	# A arte tem 4 celulas na horizontal, centralizadas verticalmente com padding.
	im = Image.open("docs/tileset-porta-1x4.png").convert("RGBA").crop((0, 221, 1774, 666))
	horizontal = _reduzir(im, 4, 1)
	horizontal.save(f"{SAIDA}/porta.png")
	horizontal.transpose(Image.ROTATE_90).save(f"{SAIDA}/porta_vertical.png")


def portao_hangar() -> None:
	# 5 celulas de largura x 2 linhas: linha 0 fechado, linha 1 aberto.
	im = _reduzir(Image.open("docs/tileset-portao-hangar-2x5.png").convert("RGBA"), 5, 2)
	fechado = im.crop((0, 0, 5 * CELULA, CELULA)).transpose(Image.ROTATE_90)
	aberto = im.crop((0, CELULA, 5 * CELULA, 2 * CELULA)).transpose(Image.ROTATE_90)
	folha = Image.new("RGBA", (2 * CELULA, 5 * CELULA), (0, 0, 0, 0))
	folha.paste(fechado, (0, 0))
	folha.paste(aberto, (CELULA, 0))
	folha.save(f"{SAIDA}/portao_hangar.png")


piso()
parede()
porta()
portao_hangar()
print("tiles gerados em", SAIDA)


def jogador_placeholder() -> None:
	# Recorta "Lira sem capacete" da folha de referencia e remove o fundo bege.
	im = Image.open("docs/prototipo-lira-e-miro.png").convert("RGBA")
	fundo = im.getpixel((5, 5))[:3]
	dados = []
	for r, g, b, a in im.getdata():
		perto = abs(r - fundo[0]) + abs(g - fundo[1]) + abs(b - fundo[2]) < 40
		dados.append((r, g, b, 0) if perto else (r, g, b, a))
	im.putdata(dados)
	figura = im.crop((150, 150, 500, 720))
	caixa = figura.getbbox()
	figura = figura.crop(caixa)
	altura = 96
	largura = max(1, round(figura.width * altura / figura.height))
	figura.resize((largura, altura), Image.BOX).save("assets/sprites/lira.png")


jogador_placeholder()
