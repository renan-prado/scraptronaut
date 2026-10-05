# Audita assets/sprites/miro_8dir.png e monta uma folha de conferencia.
#
# O gerador ja audita a ORIGEM (nenhum desenho atravessa a grade). Aqui se
# audita o RESULTADO, que e onde um erro de ancora ou de escala apareceria:
#
#   1. cada celula do sprite final e um blob conectado so — sobra de vizinho
#      entraria como segundo blob
#   2. nenhuma celula encosta na propria borda — encostar significa que a
#      figura foi cortada, nao recortada
#   3. a cabeca cai no mesmo lugar em todos os quadros da mesma linha — e
#      disso que vem o personagem escorregar de lado a cada passo
#
# Sai tambem screenshots/miro_8dir_conferencia.png, com as 32 celulas
# ampliadas e nomeadas, para apontar um quadro errado pelo nome ("cima_direita
# q2") em vez de descrever a pose.
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
import gerar_miro_8dir as g

FOLHA = "assets/sprites/miro_8dir.png"
SAIDA = "screenshots/miro_8dir_conferencia.png"

ZOOM: int = 3
FUNDO = (38, 38, 46, 255)

## Quanto a cabeca pode variar dentro de uma linha, em pixels do sprite final.
## Acima disso o personagem escorrega de lado visivelmente a cada quadro.
TOLERANCIA_ANCORA: float = 1.5


def _blobs(celula: Image.Image) -> list[int]:
	alfa = celula.getchannel("A").load()
	largura, altura = celula.size
	visto = [[False] * largura for _ in range(altura)]
	tamanhos: list[int] = []
	for y0 in range(altura):
		for x0 in range(largura):
			if alfa[x0, y0] <= 128 or visto[y0][x0]:
				continue
			fila = deque([(x0, y0)])
			visto[y0][x0] = True
			n = 0
			while fila:
				x, y = fila.popleft()
				n += 1
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = x + dx, y + dy
					if (
						0 <= nx < largura
						and 0 <= ny < altura
						and alfa[nx, ny] > 128
						and not visto[ny][nx]
					):
						visto[ny][nx] = True
						fila.append((nx, ny))
			tamanhos.append(n)
	tamanhos.sort(reverse=True)
	return tamanhos


def auditar(folha: Image.Image, fw: int, fh: int) -> int:
	falhas = 0
	for linha in range(g.LINHAS):
		ancoras: list[float] = []
		for coluna in range(g.COLUNAS):
			nome = f"{g.DIRECOES[linha]} q{coluna}"
			celula = folha.crop((coluna * fw, linha * fh, (coluna + 1) * fw, (linha + 1) * fh))

			tamanhos = _blobs(celula)
			if len(tamanhos) != 1:
				falhas += 1
				print(f"[FALHA] {nome}: {len(tamanhos)} blobs {tamanhos} (esperava 1)")

			caixa = celula.getbbox()
			# A base encosta de proposito: o chao e a base da celula.
			if caixa[0] == 0 or caixa[2] == fw or caixa[1] == 0:
				falhas += 1
				print(f"[FALHA] {nome}: figura encosta na borda da celula, caixa={caixa}")

			ancoras.append(folha_ancora(celula))

		espalhamento = max(ancoras) - min(ancoras)
		marca = "OK" if espalhamento <= TOLERANCIA_ANCORA else "FALHA"
		if marca == "FALHA":
			falhas += 1
		print(
			f"[{marca}] {g.DIRECOES[linha]}: cabeca varia {espalhamento:.2f} px na linha "
			f"(limite {TOLERANCIA_ANCORA}) — {[round(a, 1) for a in ancoras]}"
		)
	return falhas


def folha_ancora(celula: Image.Image) -> float:
	"""Centro horizontal da cabeca, na mesma faixa que o gerador usa."""
	alfa = celula.getchannel("A").load()
	largura, altura = celula.size
	caixa = celula.getbbox()
	alto = caixa[3] - caixa[1]
	colunas = [
		x
		for x in range(largura)
		for y in range(caixa[1] + int(alto * 0.04), caixa[1] + int(alto * 0.26))
		if alfa[x, y] > 128
	]
	return (min(colunas) + max(colunas)) / 2.0


def conferir() -> None:
	folha = Image.open(FOLHA).convert("RGBA")
	fw = folha.width // g.COLUNAS
	fh = folha.height // g.LINHAS
	print(f"{FOLHA}: {folha.width}x{folha.height}, celulas de {fw}x{fh}\n")

	falhas = auditar(folha, fw, fh)

	cw, ch = fw * ZOOM + 16, fh * ZOOM + 40
	fora = Image.new("RGBA", (cw * g.COLUNAS + 10, ch * g.LINHAS + 10), FUNDO)
	pincel = ImageDraw.Draw(fora)
	for linha in range(g.LINHAS):
		for coluna in range(g.COLUNAS):
			celula = folha.crop((coluna * fw, linha * fh, (coluna + 1) * fw, (linha + 1) * fh))
			celula = celula.resize((fw * ZOOM, fh * ZOOM), Image.NEAREST)
			x0, y0 = 5 + coluna * cw, 5 + linha * ch
			pincel.rectangle(
				[x0, y0, x0 + fw * ZOOM + 15, y0 + fh * ZOOM + 35],
				outline=(120, 120, 140, 255),
			)
			fora.alpha_composite(celula, (x0 + 8, y0 + 28))
			pincel.text(
				(x0 + 8, y0 + 8),
				f"{g.DIRECOES[linha]} q{coluna}  (folha col {g.ORDEM[coluna]})",
				fill=(200, 220, 255, 255),
			)
	Path(SAIDA).parent.mkdir(exist_ok=True)
	fora.save(SAIDA)
	print(f"\ngerado: {SAIDA} ({fora.width}x{fora.height})")
	print(f"falhas: {falhas}")
	sys.exit(1 if falhas else 0)


if __name__ == "__main__":
	conferir()
