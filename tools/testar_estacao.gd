extends SceneTree
## Confere a planta inicial e as regras do modo de construcao.
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
	var espaco := jogador.get_world_2d().direct_space_state

	var solido := func(celula: Vector2i) -> bool:
		var consulta := PhysicsPointQueryParameters2D.new()
		consulta.position = _ponto(celula)
		consulta.collision_mask = 1
		return not espaco.intersect_point(consulta).is_empty()

	print("--- colisao da planta inicial")
	_conferir("centro do patio (22,13) livre", solido.call(Vector2i(22, 13)), false)
	_conferir("casco norte do patio (19,6) solido", solido.call(Vector2i(19, 6)), true)
	_conferir("porta do armazem (15,13) livre", solido.call(Vector2i(15, 13)), false)
	_conferir("divisoria do corredor (15,15) solida", solido.call(Vector2i(15, 15)), true)
	_conferir("portao fechado (47,8) solido", solido.call(Vector2i(47, 8)), true)
	_conferir("fora da estacao (60,40) livre", solido.call(Vector2i(60, 40)), false)

	print("--- o jogador atravessa a porta e para na divisoria")
	# O corredor do armazem corre de oeste a leste; a linha da parede e a
	# coluna 15, com porta nas linhas 13 e 14 e divisoria na 15.
	jogador.position = _ponto(Vector2i(13, 14))
	await physics_frame
	_conferir("atravessa a porta (13,14)->(17,14)", jogador.move_and_collide(Vector2(4 * C, 0)) == null, true)
	jogador.position = _ponto(Vector2i(13, 15))
	await physics_frame
	_conferir("divisoria bloqueia (13,15)->leste", jogador.move_and_collide(Vector2(4 * C, 0)) != null, true)

	print("--- a porta abre por proximidade")
	jogador.position = mapa.centro_da(Vector2i(22, 13))
	await process_frame
	_conferir("longe: fechada", mapa.esta_aberto(Vector2i(15, 14)), false)
	jogador.position = mapa.centro_da(Vector2i(14, 14))
	await process_frame
	_conferir("perto: aberta", mapa.esta_aberto(Vector2i(15, 14)), true)

	print("--- regras de construcao")
	var do_jogador: Vector2i = Vector2i(22, 13)
	jogador.position = _ponto(do_jogador)
	await physics_frame

	_recusa("expandir encostado na estacao (17,16)", mapa.pode_expandir(Vector2i(17, 16)), false)
	_recusa("expandir solto no vazio (60,40)", mapa.pode_expandir(Vector2i(60, 40)), true)
	_recusa("expandir sobre piso (22,14)", mapa.pode_expandir(Vector2i(22, 14)), true)
	_recusa("divisoria em piso (22,14)", mapa.pode_muro(Vector2i(22, 14), do_jogador), false)
	_recusa("divisoria no casco (19,6)", mapa.pode_muro(Vector2i(19, 6), do_jogador), true)
	_recusa("porta na parede externa (19,6)", mapa.pode_porta(Vector2i(19, 6), do_jogador), true)
	_recusa("porta na divisoria (20,22)", mapa.pode_porta(Vector2i(20, 22), do_jogador), false)
	_recusa("porta onde o jogador esta", mapa.pode_porta(do_jogador, do_jogador), true)
	_recusa("porta fora da estacao (60,40)", mapa.pode_porta(Vector2i(60, 40), do_jogador), true)
	_recusa("portao na parede externa (19,6)", mapa.pode_portao(Vector2i(19, 6)), false)
	_recusa("portao na divisoria interna (20,22)", mapa.pode_portao(Vector2i(20, 22)), true)
	_recusa("remover a celula do jogador", mapa.pode_demolir(do_jogador, do_jogador), true)
	_recusa("remover o vacuo (60,40)", mapa.pode_demolir(Vector2i(60, 40), do_jogador), true)
	_recusa("remover o casco automatico (19,6)", mapa.pode_demolir(Vector2i(19, 6), do_jogador), true)

	print("--- expandir em retangulo abre canteiro de obra")
	# x 21..25 / y 4..6 e a saliencia norte do patio; 1..3 acima dela e vazio.
	var area: Array[Vector2i] = []
	for y: int in range(1, 4):
		for x: int in range(21, 26):
			area.append(Vector2i(x, y))
	_recusa("retangulo encostado no patio", mapa.aplicar(MapaEstacao.Acao.EXPANDIR, area, do_jogador), false)
	await physics_frame
	await physics_frame
	_conferir("a fila rente ao patio virou obra (24,3)", mapa.tipo_em(Vector2i(24, 3)), MapaEstacao.Tipo.OBRA)
	# A fila do fundo so encosta na estacao depois que a da frente vira obra:
	# se o retangulo nao fosse aplicado em rodadas, ela ficaria de fora.
	_conferir("e a fila do fundo tambem (24,1)", mapa.tipo_em(Vector2i(24, 1)), MapaEstacao.Tipo.OBRA)
	_conferir("obra comeca demarcada", mapa.estagio_em(Vector2i(24, 1)), MapaEstacao.Estagio.DEMARCADO)
	_conferir("obra bloqueia a passagem", solido.call(Vector2i(24, 1)), true)
	_conferir("nasceu casco acima (24,0)", mapa.eh_casco_automatico(Vector2i(24, 0)), true)
	_conferir("o casco novo colide", solido.call(Vector2i(24, 0)), true)

	var solta: Array[Vector2i] = [Vector2i(60, 40), Vector2i(61, 40)]
	_recusa("retangulo solto no vazio", mapa.aplicar(MapaEstacao.Acao.EXPANDIR, solta, do_jogador), true)
	_conferir("e nada foi escrito", mapa.tipo_em(Vector2i(60, 40)), -1)

	print("--- selecionar area ja construida nao e erro")
	# A coluna 17 esta vazia nessas linhas; de 18 em diante ja e piso do patio.
	var meio_a_meio: Array[Vector2i] = []
	for y: int in range(7, 10):
		for x: int in range(17, 21):
			meio_a_meio.append(Vector2i(x, y))
	_recusa("parte construida, parte vazia", mapa.aplicar(
		MapaEstacao.Acao.EXPANDIR, meio_a_meio, do_jogador), false)
	_conferir("o piso existente ficou intacto", mapa.tipo_em(Vector2i(19, 8)), MapaEstacao.Tipo.PISO)
	_conferir("e so a parte vazia virou obra", mapa.tipo_em(Vector2i(17, 8)), MapaEstacao.Tipo.OBRA)

	print("--- as obras correm so fora do modo de construcao")
	mapa.correr_obras(false)
	mapa.call("_avancar_obras", MapaEstacao.SEGUNDOS_POR_ESTAGIO * 1.5)
	_conferir("parada: continua demarcada", mapa.estagio_em(Vector2i(24, 1)), MapaEstacao.Estagio.DEMARCADO)
	mapa.correr_obras(true)
	mapa.call("_avancar_obras", MapaEstacao.SEGUNDOS_POR_ESTAGIO)
	await physics_frame
	_conferir("depois de um prazo: estrutura", mapa.estagio_em(Vector2i(24, 1)), MapaEstacao.Estagio.ESTRUTURA)
	mapa.call("_avancar_obras", MapaEstacao.SEGUNDOS_POR_ESTAGIO)
	_conferir("depois de dois: acabamento", mapa.estagio_em(Vector2i(24, 1)), MapaEstacao.Estagio.ACABAMENTO)
	mapa.call("_avancar_obras", MapaEstacao.SEGUNDOS_POR_ESTAGIO)
	await physics_frame
	await physics_frame
	_conferir("depois de tres: piso", mapa.tipo_em(Vector2i(24, 1)), MapaEstacao.Tipo.PISO)
	_conferir("e da para andar nele", solido.call(Vector2i(24, 1)), false)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame

	print("--- o retangulo nao varre divisoria nem porta")
	var sobre_porta: Array[Vector2i] = [Vector2i(15, 13), Vector2i(15, 14), Vector2i(15, 15)]
	mapa.aplicar(MapaEstacao.Acao.EXPANDIR, sobre_porta, do_jogador)
	_conferir("a porta sobreviveu", mapa.tipo_em(Vector2i(15, 13)), MapaEstacao.Tipo.PORTA)
	_conferir("a divisoria sobreviveu", mapa.tipo_em(Vector2i(15, 15)), MapaEstacao.Tipo.MURO)

	print("--- demolir desce a mesma escada que a obra subiu")
	var parede: Array[Vector2i] = [Vector2i(15, 15)]
	_recusa("parede abre canteiro de demolicao", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, parede, do_jogador), false)
	await physics_frame
	await physics_frame
	_conferir("e um canteiro ao contrario", mapa.esta_demolindo(Vector2i(15, 15)), true)
	_conferir("comecando pelo ultimo degrau", mapa.estagio_em(Vector2i(15, 15)),
		MapaEstacao.Estagio.ESTRUTURA)
	_conferir("a parede ainda barra enquanto desce", solido.call(Vector2i(15, 15)), true)

	print("--- demolir um canteiro cancela o trabalho")
	_recusa("demolir a propria demolicao", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, parede, do_jogador), false)
	_conferir("a parede volta inteira", mapa.tipo_em(Vector2i(15, 15)), MapaEstacao.Tipo.MURO)

	mapa.aplicar(MapaEstacao.Acao.DEMOLIR, parede, do_jogador)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame
	_conferir("virou piso mesmo", mapa.tipo_em(Vector2i(15, 15)), MapaEstacao.Tipo.PISO)
	_recusa("e o piso vira vacuo", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, parede, do_jogador), false)
	_conferir("o chao sai so no fim", mapa.tipo_em(Vector2i(15, 15)), MapaEstacao.Tipo.OBRA)
	_conferir("e comeca pelo acabamento", mapa.estagio_em(Vector2i(15, 15)),
		MapaEstacao.Estagio.ACABAMENTO)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame
	_conferir("saiu do mapa", mapa.tipo_em(Vector2i(15, 15)), -1)
	_recusa("no casco automatico nao acontece nada", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, [Vector2i(50, 8)] as Array[Vector2i], do_jogador), true)
	mapa.definir(Vector2i(15, 15), MapaEstacao.Tipo.MURO)

	print("--- demolir piso no meio da sala abre vao com parede em volta")
	var no_meio := Vector2i(22, 10)
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
	var par: Array[Vector2i] = [Vector2i(21, 12), Vector2i(22, 12)]
	var meia: Array[Vector2i] = [Vector2i(21, 12)]
	var soltas: Array[Vector2i] = [Vector2i(21, 12), Vector2i(24, 12)]
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

	print("--- porta e parede levam duas fases")
	mapa.call("_avancar_obras", MapaEstacao.SEGUNDOS_POR_ESTAGIO)
	await physics_frame
	_conferir("depois de um prazo: estrutura", mapa.estagio_em(par[0]),
		MapaEstacao.Estagio.ESTRUTURA)
	_conferir("mas ainda nao e porta", mapa.tipo_em(par[0]), MapaEstacao.Tipo.OBRA)
	mapa.call("_avancar_obras", MapaEstacao.SEGUNDOS_POR_ESTAGIO)
	await physics_frame
	await physics_frame
	_conferir("depois de dois: porta pronta", mapa.tipo_em(par[0]), MapaEstacao.Tipo.PORTA)
	_conferir("e continua atravessavel", solido.call(par[0]), false)
	mapa.definir(par[0], MapaEstacao.Tipo.PISO)
	mapa.definir(par[1], MapaEstacao.Tipo.PISO)

	var na_parede := Vector2i(23, 14)
	_recusa("parede abre canteiro", mapa.aplicar(
		MapaEstacao.Acao.PAREDE, [na_parede] as Array[Vector2i], do_jogador), false)
	await physics_frame
	await physics_frame
	_conferir("com alvo de parede", mapa.alvo_em(na_parede), MapaEstacao.Tipo.MURO)
	_conferir("e ja barra a passagem", solido.call(na_parede), true)
	mapa.call("_avancar_obras", MapaEstacao.SEGUNDOS_POR_ESTAGIO)
	mapa.call("_avancar_obras", MapaEstacao.SEGUNDOS_POR_ESTAGIO)
	await physics_frame
	await physics_frame
	_conferir("duas fases e vira parede", mapa.tipo_em(na_parede), MapaEstacao.Tipo.MURO)

	print("--- cancelar canteiro de parede devolve o piso, nao vacuo")
	var desistida := Vector2i(23, 15)
	mapa.aplicar(MapaEstacao.Acao.PAREDE, [desistida] as Array[Vector2i], do_jogador)
	_recusa("remover o canteiro", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, [desistida] as Array[Vector2i], do_jogador), false)
	_conferir("o chao continua la", mapa.tipo_em(desistida), MapaEstacao.Tipo.PISO)
	mapa.aplicar(MapaEstacao.Acao.DEMOLIR, [na_parede] as Array[Vector2i], do_jogador)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame

	print("--- ninguem fecha a estacao em si mesmo")
	# Com a porta 13 virada divisoria, a 14 e a unica passagem do armazem.
	# Remover uma vez so a transforma em piso, e o caminho continua aberto; e a
	# segunda remocao, a que abriria vacuo, que precisa ser recusada.
	mapa.definir(Vector2i(15, 13), MapaEstacao.Tipo.MURO)
	var ultima: Array[Vector2i] = [Vector2i(15, 14)]
	_recusa("porta vira piso", mapa.aplicar(MapaEstacao.Acao.DEMOLIR, ultima, do_jogador), false)
	mapa.concluir_obras()
	await physics_frame
	_recusa("mas abrir vacuo na unica passagem", mapa.aplicar(
		MapaEstacao.Acao.DEMOLIR, ultima, do_jogador), true)
	_conferir("o piso continua la", mapa.tipo_em(Vector2i(15, 14)), MapaEstacao.Tipo.PISO)
	mapa.definir(Vector2i(15, 13), MapaEstacao.Tipo.PORTA)
	mapa.definir(Vector2i(15, 14), MapaEstacao.Tipo.PORTA)

	print("--- portao do hangar")
	jogador.position = mapa.centro_da(Vector2i(46, 8))
	await physics_frame
	_conferir("ha portao por perto", mapa.ha_portao_perto(jogador.global_position), true)
	_conferir("E alterna o portao", mapa.alternar_portao_perto(jogador.global_position), true)
	await physics_frame
	await physics_frame
	_conferir("portao aberto libera (47,8)", solido.call(Vector2i(47, 8)), false)
	_conferir("abriu o grupo inteiro (47,10)", solido.call(Vector2i(47, 10)), false)
	mapa.alternar_portao_perto(jogador.global_position)
	await physics_frame
	await physics_frame
	_conferir("portao fechado bloqueia de novo", solido.call(Vector2i(47, 8)), true)

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
	var antes_do_rascunho: int = mapa.tipo_em(Vector2i(17, 20))
	construcao.alternar()
	await process_frame
	# (17,20) e vazio rente a parede oeste do corredor patio -> oficina.
	var rascunho: Array[Vector2i] = [Vector2i(17, 20), Vector2i(17, 21)]
	_recusa("expandir com o modo aberto", mapa.aplicar(
		MapaEstacao.Acao.EXPANDIR, rascunho, do_jogador), false)
	construcao.set("_pendentes", mapa.diferencas(construcao.get("_ao_entrar")))
	_conferir("a barra conta as celulas novas", construcao.get("_pendentes"), 2)
	construcao.call("cancelar")
	await process_frame
	_conferir("cancelar fecha o modo", construcao.ativo, false)
	_conferir("e desfaz a expansao", mapa.tipo_em(Vector2i(17, 20)), antes_do_rascunho)
	_conferir("inclusive a segunda celula", mapa.tipo_em(Vector2i(17, 21)), antes_do_rascunho)

	construcao.alternar()
	await process_frame
	mapa.aplicar(MapaEstacao.Acao.EXPANDIR, rascunho, do_jogador)
	construcao.set("_pendentes", mapa.diferencas(construcao.get("_ao_entrar")))
	construcao.call("confirmar")
	await process_frame
	_conferir("confirmar fecha o modo", construcao.ativo, false)
	_conferir("e a obra fica de pe", mapa.tipo_em(Vector2i(17, 20)), MapaEstacao.Tipo.OBRA)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame

	print("--- cones: o piso avisa onde o chao acaba")
	_conferir("piso pronto nao pede cone", mapa.falta_chao(Vector2i(17, 21)), false)
	var furo: Array[Vector2i] = [Vector2i(21, 11)]
	mapa.aplicar(MapaEstacao.Acao.DEMOLIR, furo, do_jogador)
	await physics_frame
	_conferir("canteiro de piso pede cone", mapa.falta_chao(Vector2i(21, 11)), true)
	var detalhes: TileMapLayer = mapa.get_node("Detalhes")
	_conferir("o piso ao norte ganhou cone", detalhes.get_cell_source_id(Vector2i(21, 10)),
		MapaEstacao.FONTE_CONE)
	# Bit 2 de CARDEAIS e o sul: o vazio fica abaixo da celula que leva a marca.
	_conferir("virado para o lado certo", detalhes.get_cell_atlas_coords(Vector2i(21, 10)),
		Vector2i(1 << 2, 0))
	_conferir("piso longe do furo fica limpo",
		detalhes.get_cell_source_id(Vector2i(21, 8)), -1)
	# Descendo: o cone acompanha a demolicao ate o ultimo degrau.
	mapa.forcar_estagio(MapaEstacao.Estagio.DEMARCADO)
	await physics_frame
	_conferir("no ultimo degrau o cone continua",
		detalhes.get_cell_source_id(Vector2i(21, 10)), MapaEstacao.FONTE_CONE)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame
	# O cone some com a obra, nao com o vao: a parede da borda do buraco fica
	# entre o piso e o vazio, e o aviso deixa de ter o que avisar.
	_conferir("acabada a demolicao, o cone sai",
		detalhes.get_cell_source_id(Vector2i(21, 10)), -1)
	_conferir("e o vao ficou com parede em volta", mapa.eh_buraco(Vector2i(21, 11)), true)

	# Subindo: o cone fica ate o piso ser entregue, nao ate a chapa aparecer.
	mapa.aplicar(MapaEstacao.Acao.EXPANDIR, furo, do_jogador)
	mapa.forcar_estagio(MapaEstacao.Estagio.ACABAMENTO)
	await physics_frame
	_conferir("no acabamento o cone continua",
		detalhes.get_cell_source_id(Vector2i(21, 10)), MapaEstacao.FONTE_CONE)
	mapa.concluir_obras()
	await physics_frame
	await physics_frame
	_conferir("so o piso entregue tira o cone",
		detalhes.get_cell_source_id(Vector2i(21, 10)), -1)

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
