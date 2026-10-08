class_name Balao
extends MarginContainer
## Balao de fala do personagem: o que ele diz e a tecla que faz aquilo.
##
## Substitui as dicas em texto solto no rodape da tela. Texto no rodape nao diz
## de quem e a frase nem sobre o que ela fala: "E — dormir"
## podia estar saindo da cama, do portao ou de lugar nenhum. O balao nasce em
## cima da cabeca de quem fala, com o rabo apontando para ele, e isso responde
## as duas coisas de uma vez — quem fala e sobre o que.
##
## **A tecla e desenho, nao letra**, e quem a desenha e scripts/tecla.gd.
##
## O no mora numa CanvasLayer, e nao no mundo. No mundo ele seria desenhado com
## o zoom da camera do jogo — 0,26 a 0,62 — e a letra sairia menor do que um
## pixel de tela a cada afastada. Aqui ele tem tamanho de interface, e so a
## POSICAO vem do mundo, por seguir().

const ARTE: Texture2D = preload("res://assets/interface/balao.png")

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

## Escala inteira, como toda pixel art ampliada do projeto — a mesma da placa do
## HUD e da barra de energia. Fracionaria daria ao balao pixel de tamanho
## diferente do da interface que ele acompanha.
const ESCALA: int = 2

## Corpo da fala e corpo da acao. **Hoje sao o MESMO, e nem sempre foram.**
##
## A fala usava Fonte.GRANDE e a acao, MIUDO: com a fonte de bitmap antiga isso
## era 24 contra 12, e a diferenca de corpo era a hierarquia do balao.
##
## A troca para a VT323 em 2026-10-06 tirou esse degrau. Os corpos limpos dela
## nao formam uma escada util para o balao (ver scripts/fonte.gd): no degrau
## acima de MIUDO a fala media 667 px de tela, mais da metade da largura, e uma
## dica que aparece toda vez que o personagem passa perto da cama nao pode tomar
## meia tela.
##
## Entao as duas linhas sao MIUDO, e a hierarquia passou a ser a COR e a tampa
## da tecla, que o balao ja usava — claro para o que ele diz, ambar com tampa
## para o que ha para apertar.
##
## MIUDO caiu de 25 para 20 no mesmo dia, tambem a pedido: o balao ficou grande
## demais sobre o mundo. **Os dois balões do jogo moram nesta medida** — a fala
## do personagem e a recusa do modo de construcao.
const CORPO_DA_FALA: int = Fonte.MIUDO
const CORPO_DA_ACAO: int = Fonte.MIUDO

## A fala e clara, como o resto do texto de interface; a linha da acao e ambar,
## que e a cor que este jogo ja usava para "aperte isto".
const COR_FALA: String = "dbe8f7"
const COR_ACAO: String = "ffd98a"

## Folga entre a tecla e o que ela faz.
const SEPARACAO: int = 5

## Respiro entre a borda desenhada e o texto, ALEM da propria borda. So a borda
## (8 px de tela) encostava a letra no fio de luz, e balao apertado le como
## caixa de aviso e nao como fala. Mais folga em pe do que deitado porque a
## altura da linha do Label ja traz um pouco de ar que a largura nao traz.
const RESPIRO_X: int = 8
const RESPIRO_Y: int = 5

var _fala: Label
var _acao: Label
var _tecla: Tecla
var _linha: HBoxContainer


func _init() -> void:
	var conteudo := VBoxContainer.new()
	conteudo.name = "Conteudo"
	conteudo.add_theme_constant_override(&"separation", 2)
	add_child(conteudo)

	_fala = Fonte.rotulo(COR_FALA, CORPO_DA_FALA)
	_fala.name = "Fala"
	conteudo.add_child(_fala)

	_linha = HBoxContainer.new()
	_linha.name = "Acao"
	_linha.add_theme_constant_override(&"separation", SEPARACAO)
	conteudo.add_child(_linha)

	_tecla = Tecla.new()
	_tecla.name = "Tecla"
	_tecla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_linha.add_child(_tecla)

	_acao = Fonte.rotulo(COR_ACAO, CORPO_DA_ACAO)
	_acao.name = "Texto"
	_acao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_linha.add_child(_acao)


func _ready() -> void:
	# O padrao de filtro do projeto ainda e Linear, e a folha do balao e pixel
	# art ampliada: sem isto ele sai borrado (ver CLAUDE.md). A tampa da tecla
	# cuida do filtro dela, em scripts/tecla.gd.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var folga: int = BORDA * ESCALA
	add_theme_constant_override(&"margin_left", folga + RESPIRO_X)
	add_theme_constant_override(&"margin_right", folga + RESPIRO_X)
	add_theme_constant_override(&"margin_top", folga + RESPIRO_Y)
	add_theme_constant_override(&"margin_bottom", folga + RESPIRO_Y)
	# O balao nunca pode ficar mais estreito que o proprio rabo: uma acao curta
	# deixaria a boca mais larga que a caixa, e o rabo sairia pelos lados.
	custom_minimum_size = Vector2((RABO_LARGURA + BORDA) * ESCALA, 0)


## O que o personagem diz. `fala` vazia mostra so a tecla e a acao; `tecla`
## vazia mostra a acao sem tampa — e o caso em que nao ha o que apertar, como o
## aviso de que a energia acabou.
##
## `cor` existe por causa da RECUSA do modo de construcao, que e o unico texto
## deste balao que nao e um convite: ela sai em vermelho porque o retangulo do
## cursor embaixo dela ja esta vermelho, e um balao ambar apontando para uma
## selecao recusada diria o contrario do que ela diz.
func dizer(fala: String, tecla: String, acao: String, cor: String = COR_ACAO) -> void:
	_fala.text = fala
	_fala.visible = fala != ""
	_acao.text = acao
	_acao.add_theme_color_override(&"font_color", Color(cor))
	_linha.visible = acao != ""
	_tecla.visible = tecla != ""
	if tecla != "":
		_tecla.mostrar(tecla)
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
