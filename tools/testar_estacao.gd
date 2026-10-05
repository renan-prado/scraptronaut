extends SceneTree
## Confere a planta inicial, as regras do modo de construcao e o dia de trabalho.
##
## Uso: godot --headless --path . --script tools/testar_estacao.gd
## Sai com o numero de falhas, entao serve direto em verificacao automatica.

const C: int = 64

var _falhas: int = 0


func _ponto(celula: Vector2i) -> Vector2:
	return Vector2(celula.x * C + C / 2.0, celula.y * C + C / 2.0)


func _conferir(nome: String, obtido: Variant, esperado: Variant) -> void:
	var ok: bool = obtido == esperado
	if not ok:
		_falhas += 1
	print("[%s] %s -> %s (esperado %s)" % ["OK" if ok else "FALHA", nome, obtido, esperado])


func _recusa(nome: String, motivo: String, deve_recusar: bool) -> void:
	var recusou: bool = motivo != ""
	var ok: bool = recusou == deve_recusar
	if not ok:
		_falhas += 1
	var texto: String = motivo if recusou else "permitido"
	print("[%s] %s -> %s" % ["OK" if ok else "FALHA", nome, texto])


func _initialize() -> void:
	var cena: Node = load("res://cenas/estacao.tscn").instantiate()
	root.add_child(cena)
	await physics_frame
	await physics_frame

	var mapa: MapaEstacao = cena.get_node("Mapa")
	var jogador: CharacterBody2D = cena.get_node("Jogador")
	var construcao: Node2D = cena.get_node("Construcao")
	var trabalho: Node2D = cena.get_node("Trabalho")
	var cama: Cama = cena.get_node("Cama")
	var espaco := jogador.get_world_2d().direct_space_state

	var solido := func(celula: Vector2i) -> bool:
		var consulta := PhysicsPointQueryParameters2D.new()
		consulta.position = _ponto(celula)
		consulta.collision_mask = 1
		return not espaco.intersect_point(consulta).is_empty()

	print("--- colisao da planta inicial")
	_conferir("centro do patio (15,9) livre", solido.call(Vector2i(15, 9)), false)
	_conferir("casco norte do patio (12,4) solido", solido.call(Vector2i(12, 4)), true)
	_conferir("porta do armazem (10,9) livre", solido.call(Vector2i(10, 9)), false)
	_conferir("divisoria do corredor (10,11) solida", solido.call(Vector2i(10, 11)), true)
	_conferir("portao fechado (31,7) solido", solido.call(Vector2i(31, 7)), true)
	_conferir("fora da estacao (60,40) livre", solido.call(Vector2i(60, 40)), false)
	_conferir("a cama ocupa a cabeceira (3,2)", solido.call(Vector2i(3, 2)), true)
	_conferir("e o pe da cama (3,3)", solido.call(Vector2i(3, 3)), true)
	_conferir("mas da para chegar nela por (3,4)", solido.call(Vector2i(3, 4)), false)

	print("--- o jogador atravessa a porta e para na divisoria")
	# O corredor do armazem corre de oeste a leste; a linha da parede e a
	# coluna 10, com porta nas linhas 9 e 10 e divisoria na 11.
	jogador.position = _ponto(Vector2i(8, 10))
	await physics_frame
	_conferir("atravessa a porta (8,10)->(12,10)", jogador.move_and_collide(Vector2(4 * C, 0)) == null, true)
	jogador.position = _ponto(Vector2i(8, 11))
	await physics_frame
	_conferir("divisoria bloqueia (8,11)->leste", jogador.move_and_collide(Vector2(4 * C, 0)) != null, true)

	print("--- a porta abre por proximidade")
	jogador.position = mapa.centro_da(Vector2i(15, 9))
	await process_frame
	_conferir("longe: fechada", mapa.esta_aberto(Vector2i(10, 10)), false)
	jogador.position = mapa.centro_da(Vector2i(9, 10))
	await process_frame
	_conferir("perto: aberta", mapa.esta_aberto(Vector2i(10, 10)), true)

	print("--- regras de construcao")
	var do_jogador: Vector2i = Vector2i(15, 9)
	jogador.position = _ponto(do_jogador)
	await physics_frame

	_recusa("expandir encostado na estacao (19,10)", mapa.pode_expandir(Vector2i(19, 10)), false)
	_recusa("expandir solto no vazio (60,40)", mapa.pode_expandir(Vector2i(60, 40)), true)
	_recusa("expandir sobre piso (15,10)", mapa.pode_expandir(Vector2i(15, 10)), true)
	_recusa("divisoria em piso (15,10)", mapa.pode_muro(Vector2i(15, 10), do_jogador), false)
	_recusa("divisoria no casco (12,4)", mapa.pode_muro(Vector2i(12, 4), do_jogador), true)
	_recusa("porta na parede externa (12,4)", mapa.pode_porta(Vector2i(12, 4), do_jogador), true)
	_recusa("porta na divisoria (14,15)", mapa.pode_porta(Vector2i(14, 15), do_jogador), false)
	_recusa("porta onde o jogador esta", mapa.pode_porta(do_jogador, do_jogador), true)
	_recusa("porta fora da estacao (60,40)", mapa.pode_porta(Vector2i(60, 40), do_jogador), true)
	_recusa("portao na parede externa (12,4)", mapa.pode_portao(Vector2i(12, 4)), false)
	_recusa("portao na divisoria interna (14,15)", mapa.pode_portao(Vector2i(14, 15)), true)
	_recusa("remover a celula do jogador", mapa.pode_demolir(do_jogador, do_jogador), true)
	_recusa("remover o vacuo (60,40)", mapa.pode_demolir(Vector2i(60, 40), do_jogador), true)
	_recusa("remover o casco automatico (12,4)", mapa.pode_demolir(Vector2i(12, 4), do_jogador), true)

	print("--- expandir em retangulo abre canteiro de obra")
	# x 16..22 / y 17..22 e a prensa; a leste dela so ha vazio.
	var area: Array[Vector2i] = []
	for y: int in range(18, 21):
		for x: int in range(23, 28):
			area.append(Vector2i(x, y))
	_recusa("retangulo encostado na prensa", mapa.aplicar(MapaEstacao.Acao.EXPANDIR, area, do_jogador), false)
	await physics_frame
	await physics_frame
	_conferir("a fila rente a prensa virou obra (23,19)", mapa.tipo_em(Vector2i(23, 19)), MapaEstacao.Tipo.OBRA)
	# A fila do fundo so encosta na estacao depois que a da frente vira obra:
	# se o retangulo nao fosse aplicado em rodadas, ela ficaria de fora.
	_conferir("e a fila do fundo tambem (27,19)", mapa.tipo_em(Vector2i(27, 19)), MapaEstacao.Tipo.OBRA)
	_conferir("obra comeca demarcada", mapa.estagio_em(Vector2i(27, 19)), MapaEstacao.Estagio.DEMARCADO)
	_conferir("obra bloqueia a passagem", solido.call(Vector2i(27, 19)), true)
	_conferir("nasceu casco adiante (28,19)", mapa.eh_casco_automatico(Vector2i(28, 19)), true)
	_conferir("o casco novo colide", solido.call(Vector2i(28, 19)), true)

	var solta: Array[Vector2i] = [Vector2i(60, 40), Vector2i(61, 40)]
	_recusa("retangulo solto no vazio", mapa.aplicar(MapaEstacao.Acao.EXPANDIR, solta, do_jogador), true)
	_conferir("e nada foi escrito", mapa.tipo_em(Vector2i(60, 40)), -1)

	print("--- selecionar area ja construida nao e erro")
	# A coluna 11 esta vazia nessas linhas; de 12 em diante ja e piso do patio.
	var meio_a_meio: Array[Vector2i] = []
	for y: int in range(5, 9):
		for x: int in range(11, 15):
			meio_a_meio.append(Vector2i(x, y))
	_recusa("parte construida, parte vazia", mapa.aplicar(
		MapaEstacao.Acao.EXPANDIR, meio_a_meio, do_jogador), false)
	_conferir("o piso existente ficou intacto", mapa.tipo_em(Vector2i(13, 6)), MapaEstacao.Tipo.PISO)
	_conferir("e so a parte vazia virou obra", mapa.tipo_em(Vector2i(11, 6)), MapaEstacao.Tipo.OBRA)

	print("--- a obra so anda com alguem batendo nela")
	var canteiro := Vector2i(27, 19)
	var por_estagio: float = mapa.trabalho_por_estagio(MapaEstacao.Tipo.PISO)
	_conferir("ninguem bateu: continua demarcada",
		mapa.estagio_em(canteiro), MapaEstacao.Estagio.DEMARCADO)
	var meio: float = mapa.trabalhar(canteiro, por_estagio * 0.5)
	await physics_frame
	_conferir("meia marretada e cobrada inteira", is_equal_approx(meio, por_estagio * 0.5), true)
	_conferir("conta no progresso", mapa.progresso_em(canteiro) > 0.0, true)
	_conferir("mas nao fecha o degrau", mapa.estagio_em(canteiro), MapaEstacao.Estagio.DEMARCADO)
	mapa.trabalhar(canteiro, por_estagio * 0.5)
	await physics_frame
	_conferir("fechado o primeiro: estrutura", mapa.estagio_em(canteiro), MapaEstacao.Estagio.ESTRUTURA)
	mapa.trabalhar(canteiro, por_estagio)
	await physics_frame
	_conferir("fechado o segundo: acabamento", mapa.estagio_em(canteiro), MapaEstacao.Estagio.ACABAMENTO)
	# A sobra nao e cobrada: no ultimo degrau o canteiro ja nao existe, e quem
	# paga em energia nao pode pagar por trabalho que nao foi feito.
	var ultimo: float = mapa.trabalhar(canteiro, por_estagio * 10.0)
	await physics_frame
	await physics_frame
	_conferir("a ultima martelada cobra so o que faltava", ultimo < por_estagio * 10.0, true)
	_conferir("e a celula virou piso", mapa.tipo_em(canteiro), MapaEstacao.Tipo.PISO)
	_conferir("e da para andar nele", solido.call(canteiro), false)
	_conferir("bater fora de canteiro nao cobra nada", mapa.trabalhar(canteiro, 50.0), 0.0)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame

	print("--- a picareta bate no canteiro que o personagem encara")
	# Dois canteiros a uma celula do mesmo ponto: um ao sul, outro a leste. Pelo
	# criterio antigo — o mais perto — os dois empatavam e quem decidia era a
	# ordem do dicionario; o pedido e que decida a vista.
	var mira := Vector2i(15, 9)
	var leste := Vector2i(16, 9)
	var sul := Vector2i(15, 10)
	_recusa("ergue parede a leste", mapa.aplicar(
		MapaEstacao.Acao.PAREDE, [leste] as Array[Vector2i], do_jogador), false)
	_recusa("e outra ao sul", mapa.aplicar(
		MapaEstacao.Acao.PAREDE, [sul] as Array[Vector2i], do_jogador), false)
	await physics_frame
	_conferir("virado para leste, pega o de leste",
		mapa.canteiro_perto(_ponto(mira), Vector2(1, 0)), leste)
	_conferir("virado para o sul, pega o do sul",
		mapa.canteiro_perto(_ponto(mira), Vector2(0, 1)), sul)
	# De costas para os dois nao ha alvo: canteiro_perto devolve a propria
	# celula, e quem chama le isso como "nao ha obra na mira".
	_conferir("virado para o norte, nao pega nenhum",
		mapa.canteiro_perto(_ponto(mira), Vector2(0, -1)), mira)
	_conferir("sem rumo, volta a ser o mais perto",
		mapa.tipo_em(mapa.canteiro_perto(_ponto(mira))), MapaEstacao.Tipo.OBRA)
	mapa.aplicar(MapaEstacao.Acao.DEMOLIR, [leste, sul] as Array[Vector2i], do_jogador)
	await physics_frame

	print("--- expandir sobre o casco nao abre buraco para o vacuo")
	var no_casco := Vector2i(12, 4)
	_conferir("a celula escolhida e casco", mapa.eh_casco_automatico(no_casco), true)
	_recusa("expandir ali e aceito", mapa.aplicar(
		MapaEstacao.Acao.EXPANDIR, [no_casco] as Array[Vector2i], do_jogador), false)
	await physics_frame
	_conferir("virou canteiro", mapa.tipo_em(no_casco), MapaEstacao.Tipo.OBRA)
	var casco_layer: TileMapLayer = mapa.get_node("Casco")
	_conferir("e a parede continua desenhada",
		casco_layer.get_cell_source_id(no_casco), MapaEstacao.FONTE_CASCO)
	_conferir("entao nao falta chao ali", mapa.falta_chao(no_casco), false)
	_conferir("e o piso vizinho nao ganha cone",
		mapa.get_node("Detalhes").get_cell_source_id(Vector2i(12, 5)), -1)
	_recusa("parede interna manda demolir, nao expandir",
		mapa.pode_expandir(Vector2i(10, 11)), true)
	mapa.aplicar(MapaEstacao.Acao.DEMOLIR, [no_casco] as Array[Vector2i], do_jogador)
	await physics_frame

	print("--- o custo da obra, em celulas por barra de energia")
	# A tabela e escrita em trabalho por celula, mas foi pedida em celulas por
	# barra cheia. As igualdades abaixo sao a traducao, e existem para alguem
	# que mexa num dos dois lados sem mexer no outro quebrar o teste em vez de
	# passar despercebido.
	var dia_de_energia: float = jogador.get_script().get_script_constant_map()["ENERGIA_MAXIMA"]
	var custo: Dictionary = MapaEstacao.TRABALHO_POR_CELULA
	_conferir("uma barra cheia expande oito quadrados",
		is_equal_approx(custo[MapaEstacao.Tipo.PISO] * 8.0, dia_de_energia), true)
	_conferir("ou ergue vinte paredes",
		is_equal_approx(custo[MapaEstacao.Tipo.MURO] * 20.0, dia_de_energia), true)
	_conferir("ou instala oito portas, de duas celulas cada",
		is_equal_approx(custo[MapaEstacao.Tipo.PORTA] * 2.0 * 8.0, dia_de_energia), true)
	_conferir("e uma porta inteira custa o mesmo que um quadrado de chao",
		is_equal_approx(custo[MapaEstacao.Tipo.PORTA] * 2.0, custo[MapaEstacao.Tipo.PISO]), true)

	print("--- o ritmo da picareta, em marteladas")
	# E a unidade em que o ritmo foi pedido: quantas vezes a picareta sobe e
	# desce ate a celula fechar. Os segundos sao derivados, entao o teste confere
	# a derivacao — mexer na cadencia da animacao sem mexer no ritmo faria a
	# conta de marteladas mentir em silencio.
	var ciclo: float = jogador.get_script().get_script_constant_map()["CICLO_TRABALHO"]
	var constantes_do_dia: Dictionary = trabalho.get_script().get_script_constant_map()
	var segundos_por_quadrado: float = (
		custo[MapaEstacao.Tipo.PISO] / float(constantes_do_dia["ENERGIA_POR_SEGUNDO"])
	)
	_conferir("um quadrado leva as marteladas pedidas",
		is_equal_approx(segundos_por_quadrado / ciclo,
			float(constantes_do_dia["MARTELADAS_POR_QUADRADO"])), true)
	_conferir("e a barra cheia leva oito vezes isso",
		is_equal_approx(float(constantes_do_dia["SEGUNDOS_DE_UM_DIA"]),
			segundos_por_quadrado * 8.0), true)

	print("--- a barra de energia conta quadrados")
	var painel: PainelHud = trabalho.get_node("Interface/Painel")
	var barra: BarraEnergia = painel.get_node("Conteudo/DiaEEnergia/Carga")
	_conferir("o contador do dia mora na mesma placa",
		painel.get_node_or_null("Conteudo/DiaEEnergia/Dia/Conteudo/Contador") != null, true)
	_conferir("uma divisao vale um quadrado de chao",
		is_equal_approx(BarraEnergia.ENERGIA_POR_DIVISAO, custo[MapaEstacao.Tipo.PISO]), true)
	barra.mostrar(dia_de_energia, dia_de_energia)
	await process_frame
	_conferir("com a energia de hoje, oito divisoes", barra.divisoes(), 8)
	var largura_de_oito: float = barra.custom_minimum_size.x
	var direita: float = painel.position.x + painel.size.x
	# O ponto da peca repetida: dobrar a energia maxima tem de dobrar a fila sem
	# arte nova e sem ninguem mexer no desenho.
	barra.mostrar(dia_de_energia * 2.0, dia_de_energia * 2.0)
	await process_frame
	_conferir("o dobro de energia da o dobro de divisoes", barra.divisoes(), 16)
	_conferir("e a barra cresce junto", barra.custom_minimum_size.x > largura_de_oito, true)
	_conferir("a placa cresce junto", painel.size.x > largura_de_oito, true)
	# A placa cresce para a ESQUERDA: sem isso a barra maior sairia da tela pela
	# direita, e crescer e justamente o que ela existe para poder fazer.
	_conferir("e a borda direita nao sai do lugar",
		is_equal_approx(painel.position.x + painel.size.x, direita), true)
	barra.mostrar(dia_de_energia, dia_de_energia)
	await process_frame

	print("--- a roda do mouse ajusta o zoom do jogo")
	var olho: Camera2D = jogador.get_node("Camera2D")
	var zoom_inicial: float = olho.zoom.x
	var roda := InputEventMouseButton.new()
	roda.button_index = MOUSE_BUTTON_WHEEL_UP
	roda.pressed = true
	jogador.call("_unhandled_input", roda)
	_conferir("a roda para cima aproxima", olho.zoom.x > zoom_inicial, true)
	roda.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for _i: int in 20:
		jogador.call("_unhandled_input", roda)
	var minimo: float = jogador.get_script().get_script_constant_map()["ZOOM_MINIMO"]
	_conferir("e nao passa do limite de afastamento",
		is_equal_approx(olho.zoom.x, minimo), true)
	roda.button_index = MOUSE_BUTTON_WHEEL_UP
	for _i: int in 40:
		jogador.call("_unhandled_input", roda)
	var maximo: float = jogador.get_script().get_script_constant_map()["ZOOM_MAXIMO"]
	_conferir("nem do de aproximacao", is_equal_approx(olho.zoom.x, maximo), true)
	# Travado, a roda nao e dele: no modo de construcao quem manda na vista e a
	# camera da construcao.
	jogador.call("travar", true)
	jogador.call("_unhandled_input", roda)
	_conferir("e no modo de construcao a roda nao mexe nesta camera",
		is_equal_approx(olho.zoom.x, maximo), true)
	jogador.call("travar", false)
	olho.zoom = Vector2(zoom_inicial, zoom_inicial)

	print("--- o retangulo nao varre divisoria nem porta")
	var sobre_porta: Array[Vector2i] = [Vector2i(10, 9), Vector2i(10, 10), Vector2i(10, 11)]
	mapa.aplicar(MapaEstacao.Acao.EXPANDIR, sobre_porta, do_jogador)
	_conferir("a porta sobreviveu", mapa.tipo_em(Vector2i(10, 9)), MapaEstacao.Tipo.PORTA)
	_conferir("a divisoria sobreviveu", mapa.tipo_em(Vector2i(10, 11)), MapaEstacao.Tipo.MURO)

	print("--- demolir desce a mesma escada que a obra subiu")
	var parede: Array[Vector2i] = [Vector2i(10, 11)]
	_recusa("parede abre canteiro de demolicao", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, parede, do_jogador), false)
	await physics_frame
	await physics_frame
	_conferir("e um canteiro ao contrario", mapa.esta_demolindo(Vector2i(10, 11)), true)
	_conferir("comecando pelo ultimo degrau", mapa.estagio_em(Vector2i(10, 11)),
		MapaEstacao.Estagio.ESTRUTURA)
	_conferir("a parede ainda barra enquanto desce", solido.call(Vector2i(10, 11)), true)

	print("--- demolir um canteiro cancela o trabalho")
	_recusa("demolir a propria demolicao", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, parede, do_jogador), false)
	_conferir("a parede volta inteira", mapa.tipo_em(Vector2i(10, 11)), MapaEstacao.Tipo.MURO)

	mapa.aplicar(MapaEstacao.Acao.DEMOLIR, parede, do_jogador)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame
	_conferir("virou piso mesmo", mapa.tipo_em(Vector2i(10, 11)), MapaEstacao.Tipo.PISO)
	_recusa("e o piso vira vacuo", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, parede, do_jogador), false)
	_conferir("o chao sai so no fim", mapa.tipo_em(Vector2i(10, 11)), MapaEstacao.Tipo.OBRA)
	_conferir("e comeca pelo acabamento", mapa.estagio_em(Vector2i(10, 11)),
		MapaEstacao.Estagio.ACABAMENTO)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame
	_conferir("saiu do mapa", mapa.tipo_em(Vector2i(10, 11)), -1)
	_recusa("no casco automatico nao acontece nada", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, [Vector2i(31, 3)] as Array[Vector2i], do_jogador), true)
	mapa.definir(Vector2i(10, 11), MapaEstacao.Tipo.MURO)

	print("--- demolir piso no meio da sala abre vao com parede em volta")
	var no_meio := Vector2i(15, 7)
	_recusa("o piso sai", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, [no_meio] as Array[Vector2i], do_jogador), false)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame
	_conferir("virou buraco", mapa.eh_buraco(no_meio), true)
	_conferir("e NAO virou casco macico", mapa.eh_casco_automatico(no_meio), false)
	_conferir("mas barra o jogador", solido.call(no_meio), true)
	mapa.definir(no_meio, MapaEstacao.Tipo.PISO)
	await physics_frame
	await physics_frame
	_conferir("devolver o piso fecha o buraco", mapa.eh_buraco(no_meio), false)

	print("--- a porta e peca de duas celulas")
	# E o que desfaz o ciclo: antes nao dava para erguer a parede que fecharia o
	# canto, porque isolaria a estacao, nem pôr a porta que resolveria, porque
	# ali ainda nao havia parede.
	var par: Array[Vector2i] = [Vector2i(14, 8), Vector2i(15, 8)]
	var meia: Array[Vector2i] = [Vector2i(14, 8)]
	var soltas: Array[Vector2i] = [Vector2i(14, 8), Vector2i(17, 8)]
	_recusa("uma celula so nao e porta", mapa.pode_porta_em(meia, do_jogador), true)
	_recusa("duas celulas separadas tambem nao", mapa.pode_porta_em(soltas, do_jogador), true)
	_recusa("o par encostado passa", mapa.pode_porta_em(par, do_jogador), false)
	var sobre_jogador: Array[Vector2i] = [do_jogador, do_jogador + Vector2i(1, 0)]
	_recusa("e nao entra em cima do jogador",
		mapa.pode_porta_em(sobre_jogador, do_jogador), true)
	_recusa("aplica o par", mapa.aplicar(MapaEstacao.Acao.PORTA, par, do_jogador), false)
	await physics_frame
	_conferir("virou canteiro de porta", mapa.alvo_em(par[0]), MapaEstacao.Tipo.PORTA)
	_conferir("em obra a porta ja deixa passar", solido.call(par[0]), false)
	_conferir("e nao pede cone", mapa.falta_chao(par[0]), false)
	_conferir("a porta deitada usa a linha 0", mapa.linha_da_porta(par[0]), 0)

	print("--- porta e parede levam dois degraus")
	mapa.avancar_um_estagio()
	await physics_frame
	_conferir("depois de um degrau: estrutura", mapa.estagio_em(par[0]),
		MapaEstacao.Estagio.ESTRUTURA)
	_conferir("mas ainda nao e porta", mapa.tipo_em(par[0]), MapaEstacao.Tipo.OBRA)
	mapa.avancar_um_estagio()
	await physics_frame
	await physics_frame
	_conferir("depois de dois: porta pronta", mapa.tipo_em(par[0]), MapaEstacao.Tipo.PORTA)
	_conferir("e continua atravessavel", solido.call(par[0]), false)
	mapa.definir(par[0], MapaEstacao.Tipo.PISO)
	mapa.definir(par[1], MapaEstacao.Tipo.PISO)

	var na_parede := Vector2i(16, 11)
	_recusa("parede abre canteiro", mapa.aplicar(
		MapaEstacao.Acao.PAREDE, [na_parede] as Array[Vector2i], do_jogador), false)
	await physics_frame
	await physics_frame
	_conferir("com alvo de parede", mapa.alvo_em(na_parede), MapaEstacao.Tipo.MURO)
	_conferir("e ja barra a passagem", solido.call(na_parede), true)
	mapa.avancar_um_estagio()
	mapa.avancar_um_estagio()
	await physics_frame
	await physics_frame
	_conferir("dois degraus e vira parede", mapa.tipo_em(na_parede), MapaEstacao.Tipo.MURO)

	print("--- cancelar canteiro de parede devolve o piso, nao vacuo")
	var desistida := Vector2i(17, 11)
	mapa.aplicar(MapaEstacao.Acao.PAREDE, [desistida] as Array[Vector2i], do_jogador)
	_recusa("remover o canteiro", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, [desistida] as Array[Vector2i], do_jogador), false)
	_conferir("o chao continua la", mapa.tipo_em(desistida), MapaEstacao.Tipo.PISO)
	mapa.aplicar(MapaEstacao.Acao.DEMOLIR, [na_parede] as Array[Vector2i], do_jogador)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame

	print("--- ninguem fecha a estacao em si mesmo")
	# Com a porta (10,9) virada divisoria, a (10,10) e a unica passagem do
	# armazem. Remover uma vez so a transforma em piso, e o caminho continua
	# aberto; e a segunda remocao, a que abriria vacuo, que precisa ser recusada.
	mapa.definir(Vector2i(10, 9), MapaEstacao.Tipo.MURO)
	var ultima: Array[Vector2i] = [Vector2i(10, 10)]
	_recusa("porta vira piso", mapa.aplicar(MapaEstacao.Acao.DEMOLIR, ultima, do_jogador), false)
	mapa.concluir_obras()
	await physics_frame
	_recusa("mas abrir vacuo na unica passagem", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, ultima, do_jogador), true)
	_conferir("o piso continua la", mapa.tipo_em(Vector2i(10, 10)), MapaEstacao.Tipo.PISO)
	mapa.definir(Vector2i(10, 9), MapaEstacao.Tipo.PORTA)
	mapa.definir(Vector2i(10, 10), MapaEstacao.Tipo.PORTA)

	print("--- portao do hangar")
	jogador.position = mapa.centro_da(Vector2i(30, 7))
	await physics_frame
	_conferir("ha portao por perto", mapa.ha_portao_perto(jogador.global_position), true)
	_conferir("E alterna o portao", mapa.alternar_portao_perto(jogador.global_position), true)
	await physics_frame
	await physics_frame
	_conferir("portao aberto libera (31,7)", solido.call(Vector2i(31, 7)), false)
	_conferir("abriu o grupo inteiro (31,9)", solido.call(Vector2i(31, 9)), false)
	mapa.alternar_portao_perto(jogador.global_position)
	await physics_frame
	await physics_frame
	_conferir("portao fechado bloqueia de novo", solido.call(Vector2i(31, 7)), true)

	print("--- a cama fecha o dia")
	jogador.position = cama.ponto_de_levantar()
	await physics_frame
	_conferir("de pe no pe da cama, a cama esta ao alcance",
		cama.perto(jogador.global_position), true)
	jogador.position = mapa.centro_da(do_jogador)
	await physics_frame
	_conferir("do patio, nao esta", cama.perto(jogador.global_position), false)

	var gasto: float = jogador.call("gastar_energia", 60.0)
	_conferir("gastar energia cobra o pedido", is_equal_approx(gasto, 60.0), true)
	_conferir("e a barra desce", is_equal_approx(jogador.get("energia"), dia_de_energia - 60.0), true)
	_conferir("nao da para gastar o que nao se tem",
		is_equal_approx(jogador.call("gastar_energia", 999.0), dia_de_energia - 60.0), true)
	_conferir("a energia para no zero", jogador.get("energia"), 0.0)

	jogador.call("deitar", cama.ponto_de_dormir())
	await process_frame
	_conferir("deitou", jogador.call("esta_dormindo"), true)
	_conferir("em cima do colchao",
		jogador.global_position.distance_to(cama.global_position) < 64.0, true)
	var dia_antes: int = trabalho.get("dia")
	trabalho.call("_amanhecer")
	_conferir("a noite devolve a energia", jogador.get("energia"), dia_de_energia)
	_conferir("e vira o dia", trabalho.get("dia"), dia_antes + 1)
	jogador.call("levantar", cama.ponto_de_levantar())
	await process_frame
	_conferir("levantou", jogador.call("esta_dormindo"), false)

	print("--- modo de construcao")
	construcao.alternar()
	await process_frame
	_conferir("modo ativo", construcao.ativo, true)
	_conferir("a camera da construcao assumiu", construcao.get_node("Camera2D").is_current(), true)
	construcao.alternar()
	await process_frame
	_conferir("modo desligado", construcao.ativo, false)
	_conferir("a camera do jogador voltou", jogador.get_node("Camera2D").is_current(), true)

	print("--- confirmar e cancelar a planta")
	jogador.position = _ponto(do_jogador)
	await physics_frame
	var antes_do_rascunho: int = mapa.tipo_em(Vector2i(11, 15))
	construcao.alternar()
	await process_frame
	# (11,15) e vazio rente a parede oeste do corredor patio -> oficina.
	var rascunho: Array[Vector2i] = [Vector2i(11, 15), Vector2i(11, 16)]
	_recusa("expandir com o modo aberto", mapa.aplicar(
		MapaEstacao.Acao.EXPANDIR, rascunho, do_jogador), false)
	construcao.set("_pendentes", mapa.diferencas(construcao.get("_ao_entrar")))
	_conferir("a barra conta as celulas novas", construcao.get("_pendentes"), 2)
	construcao.call("cancelar")
	await process_frame
	_conferir("cancelar fecha o modo", construcao.ativo, false)
	_conferir("e desfaz a expansao", mapa.tipo_em(Vector2i(11, 15)), antes_do_rascunho)
	_conferir("inclusive a segunda celula", mapa.tipo_em(Vector2i(11, 16)), antes_do_rascunho)

	construcao.alternar()
	await process_frame
	mapa.aplicar(MapaEstacao.Acao.EXPANDIR, rascunho, do_jogador)
	construcao.set("_pendentes", mapa.diferencas(construcao.get("_ao_entrar")))
	construcao.call("confirmar")
	await process_frame
	_conferir("confirmar fecha o modo", construcao.ativo, false)
	_conferir("e a obra fica de pe", mapa.tipo_em(Vector2i(11, 15)), MapaEstacao.Tipo.OBRA)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame

	print("--- cones: o piso avisa onde o chao acaba")
	_conferir("piso pronto nao pede cone", mapa.falta_chao(Vector2i(11, 16)), false)
	var furo: Array[Vector2i] = [Vector2i(14, 12)]
	mapa.aplicar(MapaEstacao.Acao.DEMOLIR, furo, do_jogador)
	await physics_frame
	_conferir("canteiro de piso pede cone", mapa.falta_chao(Vector2i(14, 12)), true)
	var detalhes: TileMapLayer = mapa.get_node("Detalhes")
	_conferir("o piso ao norte ganhou cone", detalhes.get_cell_source_id(Vector2i(14, 11)),
		MapaEstacao.FONTE_CONE)
	# Bit 2 de CARDEAIS e o sul: o vazio fica abaixo da celula que leva a marca.
	_conferir("virado para o lado certo", detalhes.get_cell_atlas_coords(Vector2i(14, 11)),
		Vector2i(1 << 2, 0))
	_conferir("piso longe do furo fica limpo",
		detalhes.get_cell_source_id(Vector2i(14, 9)), -1)
	# Descendo: o cone acompanha a demolicao ate o ultimo degrau.
	mapa.forcar_estagio(MapaEstacao.Estagio.DEMARCADO)
	await physics_frame
	_conferir("no ultimo degrau o cone continua",
		detalhes.get_cell_source_id(Vector2i(14, 11)), MapaEstacao.FONTE_CONE)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame
	# O cone some com a obra, nao com o vao: a parede da borda do buraco fica
	# entre o piso e o vazio, e o aviso deixa de ter o que avisar.
	_conferir("acabada a demolicao, o cone sai",
		detalhes.get_cell_source_id(Vector2i(14, 11)), -1)
	_conferir("e o vao ficou com parede em volta", mapa.eh_buraco(Vector2i(14, 12)), true)

	# Subindo: o cone fica ate o piso ser entregue, nao ate a chapa aparecer.
	mapa.aplicar(MapaEstacao.Acao.EXPANDIR, furo, do_jogador)
	mapa.forcar_estagio(MapaEstacao.Estagio.ACABAMENTO)
	await physics_frame
	_conferir("no acabamento o cone continua",
		detalhes.get_cell_source_id(Vector2i(14, 11)), MapaEstacao.FONTE_CONE)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame
	_conferir("so o piso entregue tira o cone",
		detalhes.get_cell_source_id(Vector2i(14, 11)), -1)

	print("--- ESC: sai do modo de construcao antes de abrir o menu")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true

	construcao.alternar()
	await process_frame
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_conferir("primeiro ESC fecha a construção", construcao.ativo, false)
	_conferir("e nao pausa o jogo", paused, false)

	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_conferir("o ESC seguinte abre o menu", paused, true)
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_conferir("e o proximo fecha o menu", paused, false)

	print("--- menu de pausa")
	var menu: CanvasLayer = cena.get_node("MenuPausa")
	# Com PROCESS_MODE_WHEN_PAUSED o menu nao recebe o Esc enquanto o jogo roda,
	# e fica inalcancavel: o teste existe para esse caso exato nao voltar.
	_conferir("processa sempre", menu.process_mode, Node.PROCESS_MODE_ALWAYS)
	menu.pausar()
	await process_frame
	_conferir("pausar interrompe o jogo", paused, true)
	_conferir("e mostra o menu", menu.visible, true)
	menu.retomar()
	await process_frame
	_conferir("voltar ao jogo despausa", paused, false)

	print("falhas: ", _falhas)
	quit(_falhas)
