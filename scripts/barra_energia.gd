class_name BarraEnergia
extends Control
## Barra de energia em divisoes de ">", montada a partir de pecas.
##
## **O numero de divisoes nao e fixo.** Cada uma vale ENERGIA_POR_DIVISAO, e a
## conta e feita a partir da energia maxima do personagem — entao o dia em que
## uma melhoria aumentar Jogador.ENERGIA_MAXIMA, a barra ganha divisoes sozinha,
## sem arte nova e sem mexer aqui. E tambem por isso que a arte sao pecas
## repetidas (tools/gerar_interface.py) e nao uma barra inteira desenhada.
##
## Uma divisao vale exatamente um quadrado de chao. A barra entao nao mede so
## "quanto resta": ela conta quantos quadrados ainda da para construir hoje, que
## e a pergunta que o jogador faz ao olhar para ela.

const ARTE: Texture2D = preload("res://assets/interface/energia.png")

## Precisa bater com tools/gerar_interface.py — a folha e gerada la, e a ordem
## das colunas e o passo das divisoes sao a mesma decisao nos dois lados.
const LARGURA_PECA: int = 9
const ALTURA_PECA: int = 11
const PASSO: int = 7
const LARGURA_TRILHO: int = 1
const LARGURA_TAMPA: int = 3

enum Peca { CHEIA, VAZIA, SETA, GEMA, TRILHO, TAMPA }

## Quanto vale uma divisao. E o custo de um quadrado de chao: ver o cabecalho.
const ENERGIA_POR_DIVISAO: float = MapaEstacao.TRABALHO_POR_CELULA[MapaEstacao.Tipo.PISO]

## A arte e desenhada em pixel grande. Escala INTEIRA, sempre: fracionaria
## borraria a pixel art, que e o motivo de todo nó visual deste projeto repetir
## texture_filter nearest.
const ESCALA: int = 2

## Folga entre a gema e o inicio da moldura, em pixels da arte.
const FOLGA_DA_GEMA: int = 2

## Cor das divisoes e da gema. A arte sai em cinza de tools/gerar_interface.py
## justamente para a cor morar aqui: trocar o verde por outra coisa, ou dar
## cores a tipos de energia que ainda nao existem, e mexer nestas duas linhas.
const COR_ENERGIA: Color = Color(0.42, 0.84, 0.48)

## Abaixo desta fracao a barra avisa em vermelho. Nao impede nada — e so o aviso
## de que o proximo canteiro nao fecha hoje.
const FRACAO_BAIXA: float = 0.25
const COR_BAIXA: Color = Color(0.88, 0.26, 0.22)

var _energia: float = 0.0
var _maxima: float = 1.0


func _ready() -> void:
	# O padrao de filtro do projeto ainda e Linear, e a barra e pixel art
	# ampliada: sem isto ela sai borrada (ver CLAUDE.md).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _tamanho()


func mostrar(energia: float, maxima: float) -> void:
	_energia = energia
	_maxima = maxf(maxima, 1.0)
	custom_minimum_size = _tamanho()
	queue_redraw()


## Quantas divisoes a barra tem. Arredonda para cima: uma energia maxima que nao
## feche uma divisao redonda ainda precisa de um lugar para a sobra aparecer.
func divisoes() -> int:
	return maxi(1, ceili(_maxima / ENERGIA_POR_DIVISAO))


func _tamanho() -> Vector2:
	var util: int = LARGURA_PECA + FOLGA_DA_GEMA + _largura_da_moldura() + LARGURA_PECA
	return Vector2(util, ALTURA_PECA) * ESCALA


## Largura da moldura reta, sem a seta: a tampa mais as divisoes. A ultima
## divisao precisa de PASSO como as outras, e a ponta dela avanca sobre a seta —
## que e exatamente o encaixe que a seta foi desenhada para receber.
func _largura_da_moldura() -> int:
	return LARGURA_TAMPA + divisoes() * PASSO


func _draw() -> void:
	var total: int = divisoes()
	var cheias: float = _energia / ENERGIA_POR_DIVISAO
	var tinta: Color = COR_BAIXA if _energia <= _maxima * FRACAO_BAIXA else COR_ENERGIA

	_peca(Peca.GEMA, 0, LARGURA_PECA, tinta)

	var moldura: int = LARGURA_PECA + FOLGA_DA_GEMA
	_peca(Peca.TAMPA, moldura, LARGURA_TAMPA)
	# O trilho e uma fatia de um pixel esticada: a moldura acompanha qualquer
	# numero de divisoes sem peca nova.
	_esticar(Peca.TRILHO, moldura + LARGURA_TAMPA, total * PASSO)
	_peca(Peca.SETA, moldura + _largura_da_moldura(), LARGURA_PECA)

	# As vazias primeiro, todas; depois as cheias por cima. A ponta de uma
	# divisao avanca sobre a vizinha, e desenhar na ordem da fila deixaria a
	# vazia seguinte mordendo a ponta da cheia anterior.
	var x: int = moldura + LARGURA_TAMPA
	for i: int in total:
		_peca(Peca.VAZIA, x + i * PASSO, LARGURA_PECA)
	for i: int in total:
		var parte: float = clampf(cheias - float(i), 0.0, 1.0)
		if parte <= 0.0:
			continue
		# A divisao em curso e cortada na vertical: a parte esquerda do ">" fica
		# verde e a direita segue no sulco. E o que da leitura dentro da divisao
		# — sem isso a barra andaria aos saltos de um quadrado inteiro.
		_peca(Peca.CHEIA, x + i * PASSO, ceili(LARGURA_PECA * parte), tinta)


func _peca(peca: Peca, x: int, largura: int, tinta: Color = Color.WHITE) -> void:
	if largura <= 0:
		return
	var recorte := Rect2(int(peca) * LARGURA_PECA, 0, largura, ALTURA_PECA)
	var destino := Rect2(x * ESCALA, 0, largura * ESCALA, ALTURA_PECA * ESCALA)
	draw_texture_rect_region(ARTE, destino, recorte, tinta)


func _esticar(peca: Peca, x: int, largura: int) -> void:
	if largura <= 0:
		return
	var recorte := Rect2(int(peca) * LARGURA_PECA, 0, LARGURA_TRILHO, ALTURA_PECA)
	var destino := Rect2(x * ESCALA, 0, largura * ESCALA, ALTURA_PECA * ESCALA)
	draw_texture_rect_region(ARTE, destino, recorte)
