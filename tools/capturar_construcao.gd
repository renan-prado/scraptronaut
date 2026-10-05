extends SceneTree
## Abre a cena ja no modo de construcao, aponta o cursor para uma celula
## escolhida e salva um PNG. E o unico jeito de ver a interface de construcao
## sem sentar no teclado: tools/capture.gd captura a cena parada, e o modo so
## existe depois de alguem apertar TAB.
##
## Usa o mouse de verdade para posicionar o cursor, entao precisa de janela.
##
## godot --path . -s tools/capturar_construcao.gd -- <saida> <ferramenta> <x> <y> <zoom> [rx ry rw rh]
##
## Os quatro opcionais sao um retangulo onde a MESMA ferramenta e aplicada antes
## da captura — serve para montar a cena que se quer ver: expandir, erguer
## parede, ou abrir buraco com a ferramenta 4 (Remover). Com ferramenta >= 0 ele
## passa pelo modo de construcao, como se o jogador tivesse arrastado o mouse;
## com ferramenta negativa, direto no mapa, e sempre como expansao. O decimo
## argumento congela a obra num estagio (0, 1 ou 2); outro valor entrega o piso.
##
## Com apenas DOIS opcionais o script finge um arrasto em curso a partir deles,
## que e o unico jeito de ver o retangulo de selecao desenhado.

func _init() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var cena: Node = load("res://cenas/estacao.tscn").instantiate()
	root.add_child(cena)
	for _i: int in 20:
		await process_frame

	var argumentos: PackedStringArray = OS.get_cmdline_user_args()
	var saida: String = argumentos[0]
	var ferramenta: int = argumentos[1].to_int()
	var alvo := Vector2i(argumentos[2].to_int(), argumentos[3].to_int())
	var zoom: float = argumentos[4].to_float()

	var mapa: MapaEstacao = cena.get_node("Mapa")
	var tem_retangulo: bool = argumentos.size() > 8
	var area := Rect2i()
	if tem_retangulo:
		area = Rect2i(
			argumentos[5].to_int(), argumentos[6].to_int(),
			argumentos[7].to_int(), argumentos[8].to_int()
		)

	# Estagio opcional da obra: 0..2 congela o canteiro nesse estagio, e
	# qualquer outro valor entrega o piso pronto.
	var congelar := func() -> void:
		if argumentos.size() <= 9:
			return
		var estagio: int = argumentos[9].to_int()
		if estagio >= 0 and estagio <= 2:
			mapa.forcar_estagio(estagio as MapaEstacao.Estagio)
		else:
			mapa.concluir_obras()

	# Ferramentas negativas nao entram no modo de construcao: -1 poe o jogador na
	# celula pedida e captura o jogo normal (e assim que se confere porta
	# abrindo por proximidade); -2 faz o mesmo e ainda abre o menu de pausa;
	# -3 poe a picareta batendo no canteiro mais perto; -4 deita na cama.
	if ferramenta < 0:
		if tem_retangulo:
			var celulas: Array[Vector2i] = []
			for y: int in range(area.position.y, area.end.y):
				for x: int in range(area.position.x, area.end.x):
					celulas.append(Vector2i(x, y))
			var do_jogador: Vector2i = mapa.celula_de(cena.get_node("Jogador").global_position)
			print("retangulo: ", area, " -> '", mapa.aplicar(
				MapaEstacao.Acao.EXPANDIR, celulas, do_jogador), "'")
			congelar.call()
		var jogador: Node2D = cena.get_node("Jogador")
		jogador.global_position = mapa.centro_da(alvo)
		var olho: Camera2D = jogador.get_node("Camera2D")
		olho.zoom = Vector2(zoom, zoom)
		if ferramenta == -2:
			cena.get_node("MenuPausa").call("pausar")
		# -3: a picareta batendo no canteiro mais perto. O no de trabalho le a
		# tecla F a cada quadro, e tecla fisica nao da para fingir — entao ele e
		# desligado e o estado e posto a mao. E o unico jeito de a captura ver a
		# animacao de trabalho e a barra de obra.
		if ferramenta == -3:
			var canteiro: Vector2i = mapa.canteiro_perto(jogador.global_position)
			var trabalho: Node2D = cena.get_node("Trabalho")
			trabalho.set_process(false)
			trabalho.set("_canteiro", canteiro)
			trabalho.set("_batendo", true)
			trabalho.queue_redraw()
			jogador.call("trabalhar_em", mapa.centro_da(canteiro))
		# -4: dormindo na cama, com o personagem ja deitado.
		if ferramenta == -4:
			var cama: Cama = cena.get_node("Cama")
			var trabalho: Node2D = cena.get_node("Trabalho")
			trabalho.set_process(false)
			jogador.call("deitar", cama.ponto_de_dormir())
		for _i: int in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(saida)
		print("salvo: ", saida)
		quit()
		return

	var construcao: Node2D = cena.get_node("Construcao")
	construcao.alternar()
	construcao.call("_escolher", ferramenta)

	# O retangulo entra DEPOIS de abrir o modo e pela mesma funcao que o mouse
	# usa: so assim a captura mostra a barra como o jogador a veria, com o
	# contador de alteracoes e o botao de cancelar aceso.
	if tem_retangulo:
		# Peca de tamanho fixo ignora o retangulo e sai sob o cursor, que neste
		# ponto ainda esta onde o mouse estiver. O canto do retangulo e a celula
		# pedida, entao e ele que vira cursor.
		if construcao.call("_peca_fixa"):
			construcao.set("_celula", area.position)
		construcao.call("_aplicar", 1, area)
		congelar.call()

	var camera: Camera2D = construcao.get_node("Camera2D")
	camera.zoom = Vector2(zoom, zoom)
	camera.global_position = mapa.centro_da(alvo)
	for _i: int in 4:
		await process_frame
	Input.warp_mouse(Vector2(root.size) * 0.5)
	for _i: int in 20:
		await process_frame

	# Dois argumentos extras fingem um arrasto em andamento, com a ancora na
	# celula pedida: e o unico jeito de ver o retangulo de selecao desenhado.
	# Com ferramenta de peca fixa nao ha arrasto, entao o primeiro deles vira a
	# rotacao da peca — o que o botao direito faz no jogo.
	if argumentos.size() == 7:
		if construcao.call("_peca_fixa"):
			construcao.set("_rotacao", argumentos[5].to_int())
		else:
			construcao.set("_ancora", Vector2i(argumentos[5].to_int(), argumentos[6].to_int()))
			construcao.set("_arrastando", 1)
		construcao.call("_avaliar")
		construcao.call("_atualizar_interface")
		construcao.queue_redraw()
		for _i: int in 4:
			await process_frame
	await RenderingServer.frame_post_draw

	root.get_texture().get_image().save_png(saida)
	print("salvo: ", saida)
	quit()
