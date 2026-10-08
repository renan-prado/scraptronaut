class_name Tecla
extends TextureRect
## Tampa de teclado desenhada, de uma ou de duas letras.
##
## **A tecla e desenho, nao letra.** "E" solto no meio de uma frase em portugues
## le como a conjuncao, e o travessao que separava a tecla da frase era muleta
## disso. A tampa se reconhece antes de a frase ser lida.
##
## Existe como no proprio, e nao como codigo dentro do balao, porque o atalho do
## modo de construcao precisa da mesma tampa — e a ordem das celulas na folha e
## um contrato com tools/gerar_interface.py que nao pode viver em dois lugares.
##
## Sao DUAS folhas porque sao dois tamanhos de tampa. "F1" nao cabe na celula
## quadrada de 11 sem espremer a letra, e esticar a tampa quadrada no Control
## deformaria as tres faces que a fazem ler como peca.

const ARTE_SIMPLES: Texture2D = preload("res://assets/interface/teclas.png")
const ARTE_DUPLA: Texture2D = preload("res://assets/interface/teclas_duplas.png")

## Precisa bater com tools/gerar_interface.py: as folhas saem de la, e a ordem
## das celulas e a mesma decisao nos dois lados — letra -> indice -> celula.
const ORDEM_SIMPLES: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const ORDEM_DUPLA: Array[String] = [
	"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9"
]

const LADO: int = 11
const COLUNAS_SIMPLES: int = 6

## Largura da tampa dupla: as duas letras de 5, o vao de um pixel entre elas e a
## mesma folga lateral de 3 da tampa simples.
const LARGURA_DUPLA: int = 17

## A tampa sai em 2x, como o resto da pixel art ampliada do projeto.
##
## **Era 1:1 ate 2026-10-06, e o numero mudou junto com a FONTE.** Ele sempre
## foi derivado da letra ao lado, nao escolhido: com a fonte de bitmap antiga,
## de 12 px de linha, a tampa em 2x media 22 px de tela — tres vezes a altura da
## letra —, e a linha lia como icone com legenda em vez de frase com uma tecla
## dentro. Com a VT323 a linha tem 25 px e a maiuscula 14, e e a tampa em 1:1
## que passa a estar fora de escala: 11 px de tela ao lado de uma letra de 14
## nao le como tecla, le como marca d'agua. Em 2x ela volta a ficar um pouco
## mais alta que a letra, que e a proporcao de uma tampa de teclado de verdade.
const ESCALA: int = 2


func _init() -> void:
	var recorte := AtlasTexture.new()
	recorte.atlas = ARTE_SIMPLES
	texture = recorte
	stretch_mode = TextureRect.STRETCH_SCALE


func _ready() -> void:
	# O padrao de filtro do projeto ainda e Linear, e a folha e pixel art
	# ampliada: sem isto a tampa sai borrada (ver CLAUDE.md).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Qual tecla a tampa mostra. Aceita uma letra ou digito ("E", "7") e as teclas
## de funcao ("F1"). Nome sem desenho reclama e cai na primeira celula, em vez
## de desenhar lixo em silencio.
##
## `escala` existe porque a tampa aparece em DOIS contextos que medem de formas
## diferentes. Dentro de uma linha de texto — painel, balao — ela se mede pela
## letra ao lado, e o padrao ESCALA e isso. Encavalada num icone de 32 px, como
## no atalho do modo de construcao, ela se mede pelo ICONE: ali o padrao cobre o
## desenho que a tampa deveria estar marcando, e quem chama pede 1:1.
func mostrar(nome: String, escala: int = ESCALA) -> void:
	var recorte := texture as AtlasTexture
	var dupla: int = ORDEM_DUPLA.find(nome.to_upper())
	if dupla >= 0:
		recorte.atlas = ARTE_DUPLA
		recorte.region = Rect2(dupla * LARGURA_DUPLA, 0, LARGURA_DUPLA, LADO)
	else:
		var indice: int = ORDEM_SIMPLES.find(nome.to_upper())
		if indice < 0:
			push_error("tecla sem desenho na folha: %s" % nome)
			indice = 0
		recorte.atlas = ARTE_SIMPLES
		recorte.region = Rect2(
			float((indice % COLUNAS_SIMPLES) * LADO),
			float((indice / COLUNAS_SIMPLES) * LADO),
			float(LADO), float(LADO)
		)
	custom_minimum_size = recorte.region.size * escala
	size = custom_minimum_size
