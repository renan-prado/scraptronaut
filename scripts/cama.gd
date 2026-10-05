class_name Cama
extends Node2D
## Beliche metalico do armazem: o unico lugar da Lastro onde o dia termina.
##
## A cama nao esta no mapa. MapaEstacao indexa tudo por mascara de vizinhanca,
## numa grade de 64, e esta peca ocupa duas celulas em pe, tem cabeceira de um
## lado so e nao se encaixa com vizinha nenhuma — seria gastar 256 variacoes de
## atlas para desenhar sempre a mesma coisa. Ela e no proprio, com arte e
## colisao proprias, e quem a procura e scripts/trabalho.gd.

const ARTE: Texture2D = preload("res://assets/objetos/cama.png")

## A peca ocupa a celula do no e a de baixo. O no fica na divisa entre as duas,
## que e o centro da arte.
const CELULAS_DE_ALTURA: int = 2

## Onde o no do jogador vai parar quando ele deita.
##
## Nao e o centro da cama: o sprite do personagem tem os pes na base da celula e
## a origem 4 px acima deles, entao por a origem no centro do colchao deixaria a
## cabeca fora do travesseiro. O numero casa com as alturas anotadas em
## tools/gerar_objetos.py — a linha `y` do sprite cai em `y + 18` da arte.
const DESLOCAMENTO_DEITADO: Vector2 = Vector2(0, 46)

## Onde ele volta a ficar de pe: a celula logo abaixo do pe da cama, que e por
## onde se chega nela. Levantar no centro do colchao deixaria o personagem
## dentro da propria colisao.
const DESLOCAMENTO_DO_PE: Vector2 = Vector2(0, 96)

## Distancia que aceita o E, em celulas. Precisa alcancar a celula do pe (1,5
## celulas do no) e nao a seguinte.
const ALCANCE: float = 2.2

## Caixa solida, um pouco menor que a arte: encostar na cama nao pode travar
## quem passa raspando pelo corredor do armazem.
const COLISAO: Vector2 = Vector2(56, 120)

const CAMADA_CENARIO: int = 1


func _ready() -> void:
	var sprite := get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = ARTE
		# O filtro padrao do projeto ainda e Linear: todo no visual novo precisa
		# repetir isto, ou a arte sai borrada (ver CLAUDE.md).
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func ponto_de_dormir() -> Vector2:
	return global_position + DESLOCAMENTO_DEITADO


func ponto_de_levantar() -> Vector2:
	return global_position + DESLOCAMENTO_DO_PE


func perto(posicao_global: Vector2) -> bool:
	return posicao_global.distance_to(global_position) < ALCANCE * MapaEstacao.CELULA
