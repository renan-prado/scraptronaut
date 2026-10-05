class_name PainelHud
extends MarginContainer
## Chapa de aco do HUD: moldura de nove pedacos com o conteudo dentro.
##
## Existe para o canto da tela deixar de ser texto solto sobre o cenario. O
## contador do dia e a barra de energia moram na MESMA placa, e e por isso que
## este no e um container e nao um desenho: o painel nasceu com uma linha, e a
## proxima leitura do HUD entra em `conteudo` sem mexer em nada daqui.
##
## A moldura vem de assets/interface/painel.png em NOVE pedacos — quatro cantos
## de tamanho fixo, quatro arestas esticadas numa direcao so e o miolo esticado
## nas duas. As arestas sao fatias de UM pixel: esticar um pixel e repetir
## coluna ou linha, e numa chapa de linhas retas isso nao deforma nada. E o
## mesmo truque do trilho da barra de energia, e pela mesma razao — a placa
## precisa acompanhar qualquer conteudo sem arte nova.
##
## A mesma folha traz DUAS chapas, uma por linha: relevo e encaixe. Sao a mesma
## geometria com a luz invertida, e e so isso que separa "placa parafusada" de
## "rebaixo cavado nela". O contador do dia e um PainelHud em ENCAIXE dentro de
## um PainelHud em RELEVO.

const ARTE: Texture2D = preload("res://assets/interface/painel.png")

## Precisa bater com tools/gerar_interface.py: a folha e gerada la, e onde a
## moldura se divide em canto, aresta e miolo e a mesma decisao nos dois lados.
const LADO: int = 9
const BORDA: int = 4

## Escala inteira, como toda pixel art ampliada do projeto. Fracionaria borraria
## a chapa, e a placa ficaria com pixel de tamanho diferente do da barra que ela
## guarda — que e o que mais denuncia interface remendada.
const ESCALA: int = 2

## Linha da folha. RELEVO e a placa; ENCAIXE e o rebaixo cavado nela.
enum Chapa { RELEVO, ENCAIXE }

var chapa: Chapa = Chapa.RELEVO

## Onde o conteudo do painel entra. Uma linha por assunto, de cima para baixo:
## quem acrescentar leitura ao HUD acrescenta filho aqui.
var conteudo: VBoxContainer


func _init(qual: Chapa = Chapa.RELEVO) -> void:
	chapa = qual
	conteudo = VBoxContainer.new()
	conteudo.name = "Conteudo"
	add_child(conteudo)


func _ready() -> void:
	# O padrao de filtro do projeto ainda e Linear, e a chapa e pixel art
	# ampliada: sem isto ela sai borrada (ver CLAUDE.md).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A margem do container e a propria espessura da moldura: assim o conteudo
	# nunca encosta na borda desenhada, e mudar BORDA move as duas coisas juntas.
	var folga: int = BORDA * ESCALA
	add_theme_constant_override(&"margin_left", folga)
	add_theme_constant_override(&"margin_right", folga)
	add_theme_constant_override(&"margin_top", folga)
	add_theme_constant_override(&"margin_bottom", folga)


func _draw() -> void:
	var borda: float = float(BORDA * ESCALA)
	var largura: float = maxf(size.x - borda * 2.0, 0.0)
	var altura: float = maxf(size.y - borda * 2.0, 0.0)
	var topo: int = int(chapa) * LADO
	var fim: int = LADO - BORDA

	# Cantos: tamanho fixo, nunca esticados — e neles que mora o rebite.
	_pedaco(Rect2(0, topo, BORDA, BORDA), Rect2(0, 0, borda, borda))
	_pedaco(Rect2(fim, topo, BORDA, BORDA), Rect2(size.x - borda, 0, borda, borda))
	_pedaco(Rect2(0, topo + fim, BORDA, BORDA), Rect2(0, size.y - borda, borda, borda))
	_pedaco(
		Rect2(fim, topo + fim, BORDA, BORDA),
		Rect2(size.x - borda, size.y - borda, borda, borda)
	)

	# Arestas: fatia de um pixel esticada ao longo do lado.
	_pedaco(Rect2(BORDA, topo, 1, BORDA), Rect2(borda, 0, largura, borda))
	_pedaco(Rect2(BORDA, topo + fim, 1, BORDA), Rect2(borda, size.y - borda, largura, borda))
	_pedaco(Rect2(0, topo + BORDA, BORDA, 1), Rect2(0, borda, borda, altura))
	_pedaco(Rect2(fim, topo + BORDA, BORDA, 1), Rect2(size.x - borda, borda, borda, altura))

	# Miolo: um pixel esticado nas duas direcoes.
	_pedaco(Rect2(BORDA, topo + BORDA, 1, 1), Rect2(borda, borda, largura, altura))


func _pedaco(recorte: Rect2, destino: Rect2) -> void:
	if destino.size.x <= 0.0 or destino.size.y <= 0.0:
		return
	draw_texture_rect_region(ARTE, destino, recorte)
