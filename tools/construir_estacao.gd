extends SceneTree
## Gera recursos/tileset_estacao.tres e cenas/estacao.tscn.
##
## A planta nao e mais escrita aqui: desde o modo de construcao, quem desenha o
## mapa e scripts/mapa_estacao.gd em tempo de execucao. O que sobra para este
## gerador e o que nao da para montar em tempo de jogo — o TileSet com as
## 256 variacoes de casco e os poligonos de colisao de cada uma — e o esqueleto
## de nos da cena.
##
## Uso: godot --headless --path . --script tools/construir_estacao.gd

const CELULA: int = 64

## Precisa bater com RECUO em tools/gerar_tiles_estacao.py: e o quanto a arte do
## casco recua no lado virado para o espaco, e a colisao segue a arte.
const RECUO: int = 20

## Zoom da camera: valores menores afastam a vista.
const ZOOM_CAMERA: float = 0.4

## Camadas de fisica: 1 = cenario solido, 2 = jogador.
const CAMADA_CENARIO: int = 1
const CAMADA_JOGADOR: int = 2

const CAMINHO_TILESET: String = "res://recursos/tileset_estacao.tres"
const CAMINHO_CENA: String = "res://cenas/estacao.tscn"

const FONTE_PISO: int = 0
const FONTE_BORDA: int = 1
const FONTE_CASCO: int = 2
const FONTE_PORTA: int = 3
const FONTE_PORTAO: int = 4
const FONTE_DETALHE: int = 5
const FONTE_OBRA: int = 6
const FONTE_BURACO: int = 7
const FONTE_DEMARCACAO: int = 8
const FONTE_CONE: int = 9
const FONTE_MARCACAO: int = 10

## Alternativa usada enquanto a peca ainda esta em obra: a mesma arte, apagada e
## translucida. Vale para o casco e para a porta, e precisa bater com
## ALT_EM_OBRA em scripts/mapa_estacao.gd.
const ALT_EM_OBRA: int = 1
const COR_EM_OBRA: Color = Color(0.60, 0.66, 0.78, 0.62)

## Alternativa da marcacao sem colisao. A fita de parede barra a passagem — ja
## e canteiro — mas a de porta nao: porta nunca colide, nem pronta nem em obra,
## e fechar o vao durante a obra tiraria do jogador justamente a saida que a
## porta avulsa existe para dar.
const ALT_MARCACAO_LIVRE: int = 1

## E a MESMA alternativa que e desenhada por cima de peca em obra, entao ela e
## translucida: a fita e uma faixa larga nos quatro lados da celula, e opaca ela
## comia o quadrado inteiro — o jogador batia numa obra sem ver a peca andar de
## um estagio para o outro. A base, essa continua opaca: no primeiro degrau de
## parede nao ha nada por baixo para deixar ver.
const COR_FITA_SOBRE_PECA: Color = Color(1.0, 1.0, 1.0, 0.45)

## Bits da mascara do casco, na ordem de DIRECOES em mapa_estacao.gd.
const BIT_NORTE: int = 1 << 0
const BIT_LESTE: int = 1 << 2
const BIT_SUL: int = 1 << 4
const BIT_OESTE: int = 1 << 6


func _initialize() -> void:
	var tileset: TileSet = _montar_tileset()
	var erro: int = ResourceSaver.save(tileset, CAMINHO_TILESET)
	assert(erro == OK, "falha ao salvar o tileset")

	var raiz: Node2D = _montar_cena(load(CAMINHO_TILESET))
	var empacotada := PackedScene.new()
	assert(empacotada.pack(raiz) == OK, "falha ao empacotar a cena")
	erro = ResourceSaver.save(empacotada, CAMINHO_CENA)
	assert(erro == OK, "falha ao salvar a cena")

	print("gerado: ", CAMINHO_TILESET)
	print("gerado: ", CAMINHO_CENA)
	quit()


# --- Tileset ----------------------------------------------------------------

func _montar_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(CELULA, CELULA)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, CAMADA_CENARIO)

	_adicionar(tileset, FONTE_PISO, "res://assets/tiles/estacao/piso.png", 4, 4)
	_adicionar(tileset, FONTE_BORDA, "res://assets/tiles/estacao/borda.png", 16, 16)

	var casco: TileSetAtlasSource = _adicionar(
		tileset, FONTE_CASCO, "res://assets/tiles/estacao/casco.png", 16, 16
	)
	for mascara: int in 256:
		var coordenada := Vector2i(mascara % 16, mascara / 16)
		var area: Rect2 = _corpo_do_casco(mascara)
		_colidir(casco, coordenada, area)
		# Parede ainda nao construida. E alternativa, e nao atlas proprio,
		# porque o desenho e o mesmo: o que muda e o jogador poder ver as
		# estrelas atraves dela enquanto o canteiro ao lado nao fecha.
		var alternativa: int = casco.create_alternative_tile(coordenada, ALT_EM_OBRA)
		assert(alternativa == ALT_EM_OBRA, "id de alternativa inesperado")
		casco.get_tile_data(coordenada, ALT_EM_OBRA).modulate = COR_EM_OBRA
		_colidir(casco, coordenada, area, ALT_EM_OBRA)

	# Oito colunas: quatro segmentos de vao, cada um fechado e aberto.
	var porta: TileSetAtlasSource = _adicionar(
		tileset, FONTE_PORTA, "res://assets/tiles/estacao/porta.png", 8, 2
	)
	# A porta tambem tem a versao em obra: o batente ja no lugar, apagado, antes
	# de a folha existir. Nenhuma das duas colide.
	for linha: int in 2:
		for coluna: int in 8:
			var vao := Vector2i(coluna, linha)
			porta.create_alternative_tile(vao, ALT_EM_OBRA)
			porta.get_tile_data(vao, ALT_EM_OBRA).modulate = COR_EM_OBRA

	var portao: TileSetAtlasSource = _adicionar(
		tileset, FONTE_PORTAO, "res://assets/tiles/estacao/portao.png", 4, 2
	)
	# So a linha 0 colide: a linha 1 e o portao aberto, que precisa deixar
	# passar a nave e o jogador.
	for coluna: int in 4:
		_colidir(portao, Vector2i(coluna, 0), _corpo_do_portao(coluna))

	# Canos, caixas e luminarias sao enfeite: ficam no recuo do casco, por fora
	# da colisao, e nao podem empurrar o jogador.
	_adicionar(tileset, FONTE_DETALHE, "res://assets/tiles/estacao/detalhes.png", 8, 4)

	# Canteiro de obra, estrutura e acabamento. O primeiro estagio nao esta
	# aqui: a baliza depende da vizinhanca e tem atlas proprio.
	var obra: TileSetAtlasSource = _adicionar(
		tileset, FONTE_OBRA, "res://assets/tiles/estacao/obra.png", 4, 2
	)
	for linha: int in 2:
		for coluna: int in 4:
			_colidir(obra, Vector2i(coluna, linha), _celula_inteira())

	# Baliza do canteiro: 256 variacoes pela mascara de vizinhanca, como o
	# casco. Colide igual aos outros estagios — area demarcada ja e obra.
	var demarcacao: TileSetAtlasSource = _adicionar(
		tileset, FONTE_DEMARCACAO, "res://assets/tiles/estacao/demarcacao.png", 16, 16
	)
	for mascara: int in 256:
		_colidir(demarcacao, Vector2i(mascara % 16, mascara / 16), _celula_inteira())

	# Vao aberto para o espaco, com parede em volta. Colide por inteiro: a
	# parede da borda e fina demais para valer poligono proprio, e atravessar o
	# meio seria sair da estacao a pe.
	var buraco: TileSetAtlasSource = _adicionar(
		tileset, FONTE_BURACO, "res://assets/tiles/estacao/buraco.png", 16, 1
	)
	for mascara: int in 16:
		_colidir(buraco, Vector2i(mascara, 0), _celula_inteira())

	# Fita de obra no chao: primeira fase de parede e de porta. A base colide,
	# a alternativa nao — ver ALT_MARCACAO_LIVRE.
	# Linha 0: fita com a sombra de area reservada, da primeira fase. Linha 1:
	# so a fita, para a segunda, onde ja ha peca por baixo para deixar ver.
	var marcacao: TileSetAtlasSource = _adicionar(
		tileset, FONTE_MARCACAO, "res://assets/tiles/estacao/marcacao.png", 16, 2
	)
	for linha: int in 2:
		for mascara: int in 16:
			var fita := Vector2i(mascara, linha)
			_colidir(marcacao, fita, _celula_inteira())
			var livre: int = marcacao.create_alternative_tile(fita, ALT_MARCACAO_LIVRE)
			assert(livre == ALT_MARCACAO_LIVRE, "id de alternativa inesperado")
			marcacao.get_tile_data(fita, ALT_MARCACAO_LIVRE).modulate = COR_FITA_SOBRE_PECA

	# Cone e faixa de perigo: pintura no piso onde o chao encosta no vazio.
	# Sem colisao de proposito — quem barra e o canteiro do outro lado, e um cone
	# solido deixaria o jogador preso na propria marca.
	_adicionar(tileset, FONTE_CONE, "res://assets/tiles/estacao/cones.png", 16, 1)

	return tileset


func _celula_inteira() -> Rect2:
	return Rect2(Vector2(-CELULA / 2.0, -CELULA / 2.0), Vector2(CELULA, CELULA))


func _adicionar(
	tileset: TileSet, id: int, caminho: String, colunas: int, linhas: int
) -> TileSetAtlasSource:
	var fonte := TileSetAtlasSource.new()
	fonte.texture = load(caminho)
	assert(fonte.texture != null, "textura ausente: " + caminho)
	fonte.texture_region_size = Vector2i(CELULA, CELULA)
	for y: int in linhas:
		for x: int in colunas:
			fonte.create_tile(Vector2i(x, y))
	# A camada de fisica so existe para o TileData depois que a fonte pertence
	# ao TileSet; por isso a colisao e definida fora daqui, apos o add_source.
	tileset.add_source(fonte, id)
	return fonte


func _colidir(
	fonte: TileSetAtlasSource, coordenada: Vector2i, area: Rect2, alternativa: int = 0
) -> void:
	var dados: TileData = fonte.get_tile_data(coordenada, alternativa)
	dados.set_collision_polygons_count(0, 1)
	dados.set_collision_polygon_points(0, 0, PackedVector2Array([
		area.position,
		Vector2(area.end.x, area.position.y),
		area.end,
		Vector2(area.position.x, area.end.y),
	]))


## Retangulo solido da celula de casco, em coordenadas do tile (centro na
## origem). Os cantos cortados da arte sao ignorados de proposito: sao 20 px em
## diagonal, pequenos demais para valer um poligono por variacao.
func _corpo_do_casco(mascara: int) -> Rect2:
	var esquerda: float = -CELULA / 2.0 + (RECUO if mascara & BIT_OESTE else 0)
	var direita: float = CELULA / 2.0 - (RECUO if mascara & BIT_LESTE else 0)
	var topo: float = -CELULA / 2.0 + (RECUO if mascara & BIT_NORTE else 0)
	var base: float = CELULA / 2.0 - (RECUO if mascara & BIT_SUL else 0)
	return Rect2(Vector2(esquerda, topo), Vector2(direita - esquerda, base - topo))


## A coluna do atlas do portao diz qual lado da celula da para o espaco, na
## ordem norte, leste, sul, oeste.
func _corpo_do_portao(coluna: int) -> Rect2:
	var mascara: int = [BIT_NORTE, BIT_LESTE, BIT_SUL, BIT_OESTE][coluna]
	return _corpo_do_casco(mascara)


# --- Cena -------------------------------------------------------------------

func _montar_cena(tileset: TileSet) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Estacao"

	var fundo := CanvasLayer.new()
	fundo.name = "Fundo"
	fundo.layer = -10
	raiz.add_child(fundo)
	fundo.owner = raiz

	var estrelas := Node2D.new()
	estrelas.name = "CampoEstelar"
	estrelas.set_script(load("res://scripts/campo_estelar.gd"))
	fundo.add_child(estrelas)
	estrelas.owner = raiz

	var mapa := Node2D.new()
	mapa.name = "Mapa"
	mapa.set_script(load("res://scripts/mapa_estacao.gd"))
	raiz.add_child(mapa)
	mapa.owner = raiz

	# A ordem e a ordem de desenho: piso, sombra de contato, canteiro de obra,
	# casco, os enfeites presos nele e por fim as aberturas, que cobrem o casco.
	var com_colisao: Array[String] = ["Obra", "Casco", "Aberturas"]
	for nome: String in ["Piso", "Borda", "Obra", "Casco", "Detalhes", "Aberturas"]:
		var camada := TileMapLayer.new()
		camada.name = nome
		camada.tile_set = tileset
		camada.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		camada.collision_enabled = com_colisao.has(nome)
		mapa.add_child(camada)
		camada.owner = raiz

	var cama: Node2D = _montar_cama()
	raiz.add_child(cama)
	_adotar(cama, raiz)

	var jogador: CharacterBody2D = _montar_jogador()
	raiz.add_child(jogador)
	_adotar(jogador, raiz)

	var construcao := Node2D.new()
	construcao.name = "Construcao"
	construcao.set_script(load("res://scripts/modo_construcao.gd"))
	# Fica habilitada: Camera2D desabilitada recusa make_current(). Quem garante
	# que o jogo comeca na camera do jogador e modo_construcao._ready().
	var camera_construcao := Camera2D.new()
	camera_construcao.name = "Camera2D"
	construcao.add_child(camera_construcao)
	raiz.add_child(construcao)
	_adotar(construcao, raiz)

	# Depois da construcao de proposito: _unhandled_input corre em ordem inversa
	# da arvore, e o E precisa chegar aqui antes — perto da cama ele dorme, e
	# longe dela ele passa adiante e abre o portao do hangar.
	var trabalho := Node2D.new()
	trabalho.name = "Trabalho"
	trabalho.set_script(load("res://scripts/trabalho.gd"))
	raiz.add_child(trabalho)
	_adotar(trabalho, raiz)

	var menu := CanvasLayer.new()
	menu.name = "MenuPausa"
	menu.layer = 100
	menu.visible = false
	# Sempre: o menu precisa receber o Esc com o jogo rodando para abrir, e
	# com o jogo pausado para fechar.
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.set_script(load("res://scripts/menu_pausa.gd"))
	raiz.add_child(menu)
	menu.owner = raiz

	return raiz


func _adotar(no: Node, dono: Node) -> void:
	no.owner = dono
	for filho: Node in no.get_children():
		_adotar(filho, dono)


## A cama fica na celula que o mapa escolheu, e o no cai na DIVISA entre as duas
## celulas que ela ocupa — que e o centro da arte, e o que faz os deslocamentos
## de scripts/cama.gd fecharem.
func _montar_cama() -> Node2D:
	var mapa_script: GDScript = load("res://scripts/mapa_estacao.gd")
	var celula: Vector2i = mapa_script.get_script_constant_map()["CELULA_DA_CAMA"]
	var cama_script: GDScript = load("res://scripts/cama.gd")
	var constantes: Dictionary = cama_script.get_script_constant_map()
	var altura: int = constantes["CELULAS_DE_ALTURA"]

	var cama := Node2D.new()
	cama.name = "Cama"
	cama.position = (
		Vector2(celula) * CELULA + Vector2(CELULA, CELULA * altura) * 0.5
	)
	cama.set_script(cama_script)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/objetos/cama.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cama.add_child(sprite)

	var corpo := StaticBody2D.new()
	corpo.name = "Corpo"
	corpo.collision_layer = CAMADA_CENARIO
	cama.add_child(corpo)

	var forma := RectangleShape2D.new()
	forma.size = constantes["COLISAO"]
	var colisao := CollisionShape2D.new()
	colisao.name = "Colisao"
	colisao.shape = forma
	corpo.add_child(colisao)

	return cama


func _montar_jogador() -> CharacterBody2D:
	var mapa_script: GDScript = load("res://scripts/mapa_estacao.gd")
	var celula: Vector2i = mapa_script.get_script_constant_map()["CELULA_INICIAL_JOGADOR"]

	var jogador := CharacterBody2D.new()
	jogador.name = "Jogador"
	jogador.position = Vector2(celula) * CELULA + Vector2(CELULA, CELULA) * 0.5
	jogador.collision_layer = CAMADA_JOGADOR
	jogador.collision_mask = CAMADA_CENARIO
	jogador.set_script(load("res://scripts/jogador.gd"))
	# O mapa procura o jogador pelo grupo para abrir as portas por proximidade.
	jogador.add_to_group(&"jogador", true)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	# A folha de parado: e nela que o jogo abre. scripts/jogador.gd troca a
	# textura, a grade e o offset a cada estado.
	sprite.texture = load("res://assets/sprites/miro_parado.png")
	sprite.hframes = 4
	sprite.vframes = 8
	sprite.frame = 0
	sprite.offset = Vector2(0, -46)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	jogador.add_child(sprite)

	var forma := RectangleShape2D.new()
	forma.size = Vector2(34, 26)
	var colisao := CollisionShape2D.new()
	colisao.name = "Colisao"
	colisao.shape = forma
	colisao.position = Vector2(0, -13)
	jogador.add_child(colisao)

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(ZOOM_CAMERA, ZOOM_CAMERA)
	jogador.add_child(camera)

	return jogador
