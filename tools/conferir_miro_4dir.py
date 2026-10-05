# Monta screenshots/miro_4dir_conferencia.png: as 16 celulas de
# assets/sprites/miro_4dir.png ampliadas e nomeadas.
#
# Serve para apontar um quadro errado pelo nome ("direita q1") em vez de
# descrever a pose. Cada celula tambem mostra de onde veio na folha de origem,
# porque a ordem da animacao nao e a ordem de leitura da folha.
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
import gerar_miro_4dir as g

FOLHA = "assets/sprites/miro_4dir.png"
SAIDA = "screenshots/miro_4dir_conferencia.png"

ZOOM: int = 4
FUNDO = (38, 38, 46, 255)


def conferir() -> None:
	folha = Image.open(FOLHA).convert("RGBA")
	fw = folha.width // g.COLUNAS
	fh = folha.height // g.LINHAS

	cw, ch = fw * ZOOM + 20, fh * ZOOM + 46
	fora = Image.new("RGBA", (cw * g.COLUNAS + 70, ch * g.LINHAS + 10), FUNDO)
	pincel = ImageDraw.Draw(fora)
	for linha in range(g.LINHAS):
		pincel.text((6, 10 + linha * ch + ch // 2), g.DIRECOES[linha][:4], fill=(255, 210, 120, 255))
		for coluna in range(g.COLUNAS):
			celula = folha.crop((coluna * fw, linha * fh, (coluna + 1) * fw, (linha + 1) * fh))
			celula = celula.resize((fw * ZOOM, fh * ZOOM), Image.NEAREST)
			x0, y0 = 70 + coluna * cw, 10 + linha * ch
			pincel.rectangle(
				[x0, y0, x0 + fw * ZOOM + 19, y0 + fh * ZOOM + 40],
				outline=(120, 120, 140, 255),
			)
			fora.alpha_composite(celula, (x0 + 10, y0 + 32))
			pincel.text(
				(x0 + 10, y0 + 10),
				f"{g.DIRECOES[linha]} q{coluna}   (folha linha {linha} col {g.ORDEM[coluna]})",
				fill=(200, 220, 255, 255),
			)
	Path(SAIDA).parent.mkdir(exist_ok=True)
	fora.save(SAIDA)
	print(f"gerado: {SAIDA} ({fora.width}x{fora.height})")


conferir()
