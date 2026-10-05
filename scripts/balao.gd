class_name Balao
extends MarginContainer
## Balao de fala do personagem: o que ele diz e a tecla que faz aquilo.
##
## Substitui as dicas em texto solto no rodape da tela. Texto no rodape nao diz
## de quem e a frase nem sobre o que ela fala: "E — dormir e comecar o dia 2"
## podia estar saindo da cama, do portao ou de lugar nenhum. O balao nasce em
## cima da cabeca de quem fala, com o rabo apontando para ele, e isso responde
## as duas coisas de uma vez — quem fala e sobre o que.
##
## **A tecla e desenho, nao letra.** assets/interface/teclas.png traz o alfabeto
## e os digitos em tampa de teclado (tools/gerar_interface.py): "E" solto no
## meio de uma frase em portugues le como a conjuncao, e o travessao que
## separava a tecla da frase era muleta disso.
##
## O no mora numa CanvasLayer, e nao no mundo. No mundo ele seria desenhado com
## o zoom da camera do jogo — 0,26 a 0,62 — e a letra sairia menor do que um
## pixel de tela a cada afastada. Aqui ele tem tamanho de interface, e so a
## POSICAO vem do mundo, por seguir().

const ARTE: Texture2D = preload("res://assets/interface/balao.png")
const ARTE_TECLAS: Texture2D = preload("res://assets/interface/teclas.png")

## Precisa bater com tools/gerar_interface.py: as folhas sao geradas la, e onde
## o balao se divide em canto, aresta e miolo e a mesma decisao nos dois lados.
const LADO: int = 9
const BORDA: int = 4
const RABO_Y: int = 9
const RABO_LARGURA: int = 11
const RABO_ALTURA: int = 7

## Quantas linhas do rabo sobem por cima da borda de baixo do balao. Sao as duas
## linhas de boca do rabo: sem elas a borda do balao fecharia a boca, e o rabo
## leria como peca solta embaixo dele.
const RABO_SOBREPOSICAO: int = 2

const LADO_TECLA: int = 11
const COLUNAS_TECLAS: int = 6

## A ordem das celulas na folha de teclas. E o contrato com o gerador: letra ->
## indice -> celula.
const ORDEM_DAS_TECLAS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

## Escala inteira, como toda pixel art ampliada do projeto — a mesma da placa do
## HUD e da barra de energia. Fracionaria daria ao balao pixel de tamanho
## diferente do da interface que ele acompanha.
const ESCALA: int = 2

## Corpo da letra da fala. Menor que o padrao do Godot (16): o personagem tem uns
## 40 px de tela no zoom de jogo, e com o corpo padrao o balao ficava mais alto
## do que quem estava falando.
const CORPO_DA_FALA: int = 14

## A fala e clara, como o resto do texto de interface; a linha da acao e ambar,
## que e a cor que este jogo ja usava para "aperte isto".
const COR_FALA: String = "dbe8f7"
const COR_ACAO: String = "ffd98a"

## Folga entre a tecla e o que ela faz.
const SEPARACAO: int = 6

var _fala: Label
var _acao: Label
var _tecla: TextureRect
var _linha: HBoxContainer


func _init() -> void:
	var conteudo := VBoxContainer.new()
	conteudo.name = "Conteudo"
	conteudo.add_theme_constant_override(&"separation", 2)
	add_child(conteudo)

	_fala = _escrever(COR_FALA)
	_fala.name = "Fala"
	conteudo.add_child(_fala)

	_linha = HBoxContainer.new()
	_linha.name = "Acao"
	_linha.add_theme_constant_override(&"separation", SEPARACAO)
	conteudo.add_child(_linha)

	var recorte := AtlasTexture.new()
	recorte.atlas = ARTE_TECLAS
	_tecla = TextureRect.new()
	_tecla.name = "Tecla"
	_tecla.texture = recorte
	_tecla.stretch_mode = TextureRect.STRETCH_SCALE
	_tecla.custom_minimum_size = Vector2(LADO_TECLA, LADO_TECLA) * ESCALA
	_tecla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_linha.add_child(_tecla)

	_acao = _escrever(COR_ACAO)
	_acao.name = "Texto"
	_acao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_linha.add_child(_acao)


func _ready() -> void:
	# O padrao de filtro do projeto ainda e Linear, e as duas folhas sao pixel
	# art ampliada: sem isto o balao e a tecla saem borrados (ver CLAUDE.md).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tecla.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var folga: int = BORDA * ESCALA
	add_theme_constant_override(&"margin_left", folga)
	add_theme_constant_override(&"margin_right", folga)
	add_theme_constant_override(&"margin_top", folga)
	add_theme_constant_override(&"margin_bottom", folga)
	# O balao nunca pode ficar mais estreito que o proprio rabo: uma acao curta
	# deixaria a boca mais larga que a caixa, e o rabo sairia pelos lados.
	custom_minimum_size = Vector2((RABO_LARGURA + BORDA) * ESCALA, 0)


## O que o personagem diz. `fala` vazia mostra so a tecla e a acao; `tecla`
## vazia mostra a acao sem tampa — e o caso em que nao ha o que apertar, como o
## aviso de que a energia acabou.
func dizer(fala: String, tecla: String, acao: String) -> void:
	_fala.text = fala
	_fala.visible = fala != ""
	_acao.text = acao
	_linha.visible = acao != ""
	_tecla.visible = tecla != ""
	if tecla != "":
		(_tecla.texture as AtlasTexture).region = _celula_da_tecla(tecla)
	visible = true


func calar() -> void:
	visible = false


## Poe a ponta do rabo no ponto do MUNDO pedido. Precisa ser chamado a cada
## quadro: quem fala anda, e a camera anda com ele.
func seguir(alvo_global: Vector2) -> void:
	size = get_combined_minimum_size()
	var na_tela: Vector2 = get_viewport().get_canvas_transform() * alvo_global
	var alto: float = size.y + float((RABO_ALTURA - RABO_SOBREPOSICAO) * ESCALA)
	# Arredondado: meio pixel de posicao nao borra com o filtro Nearest, mas faz
	# a borda do balao engordar e afinar de um lado conforme o personagem anda.
	position = (na_tela - Vector2(size.x * 0.5, alto)).round()


## Sem contorno no texto, ao contrario das dicas que havia na tela: aqui existe
## fundo atras da letra, e o contorno que a salvava sobre o casco so a engorda.
func _escrever(cor: String) -> Label:
	var rotulo := Label.new()
	rotulo.add_theme_color_override(&"font_color", Color(cor))
	rotulo.add_theme_font_size_override(&"font_size", CORPO_DA_FALA)
	return rotulo


func _celula_da_tecla(tecla: String) -> Rect2:
	var indice: int = ORDEM_DAS_TECLAS.find(tecla.to_upper())
	if indice < 0:
		push_error("tecla sem desenho na folha: %s" % tecla)
		indice = 0
	return Rect2(
		float((indice % COLUNAS_TECLAS) * LADO_TECLA),
		float((indice / COLUNAS_TECLAS) * LADO_TECLA),
		float(LADO_TECLA),
		float(LADO_TECLA)
	)


## Moldura de nove pedacos mais o rabo. A mesma divisao da placa do HUD — quatro
## cantos fixos, quatro arestas esticadas numa direcao so e o miolo esticado nas
## duas — porque e ela que deixa o balao caber em qualquer frase sem arte nova.
func _draw() -> void:
	var borda: float = float(BORDA * ESCALA)
	var largura: float = maxf(size.x - borda * 2.0, 0.0)
	var altura: float = maxf(size.y - borda * 2.0, 0.0)
	var fim: int = LADO - BORDA

	_pedaco(Rect2(0, 0, BORDA, BORDA), Rect2(0, 0, borda, borda))
	_pedaco(Rect2(fim, 0, BORDA, BORDA), Rect2(size.x - borda, 0, borda, borda))
	_pedaco(Rect2(0, fim, BORDA, BORDA), Rect2(0, size.y - borda, borda, borda))
	_pedaco(
		Rect2(fim, fim, BORDA, BORDA),
		Rect2(size.x - borda, size.y - borda, borda, borda)
	)

	_pedaco(Rect2(BORDA, 0, 1, BORDA), Rect2(borda, 0, largura, borda))
	_pedaco(Rect2(BORDA, fim, 1, BORDA), Rect2(borda, size.y - borda, largura, borda))
	_pedaco(Rect2(0, BORDA, BORDA, 1), Rect2(0, borda, borda, altura))
	_pedaco(Rect2(fim, BORDA, BORDA, 1), Rect2(size.x - borda, borda, borda, altura))

	_pedaco(Rect2(BORDA, BORDA, 1, 1), Rect2(borda, borda, largura, altura))

	# O rabo por ultimo: as duas primeiras linhas dele apagam a borda de baixo
	# do balao, que e o que abre a boca.
	var rabo := Vector2(RABO_LARGURA, RABO_ALTURA) * ESCALA
	var canto := Vector2(
		roundf((size.x - rabo.x) * 0.5),
		size.y - float(RABO_SOBREPOSICAO * ESCALA)
	)
	_pedaco(Rect2(0, RABO_Y, RABO_LARGURA, RABO_ALTURA), Rect2(canto, rabo))


func _pedaco(recorte: Rect2, destino: Rect2) -> void:
	if destino.size.x <= 0.0 or destino.size.y <= 0.0:
		return
	draw_texture_rect_region(ARTE, destino, recorte)
