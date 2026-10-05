extends SceneTree
## Verifica a troca de linha e de quadro do jogador na folha de 8 direcoes.
##
## Uso: godot --headless --path . --script tools/testar_jogador.gd

var _falhas: int = 0


func _checar(nome: String, obtido: Variant, esperado: Variant) -> void:
	var ok: bool = obtido == esperado
	if not ok:
		_falhas += 1
	print("[%s] %s -> %s esperado=%s" % ["OK" if ok else "FALHA", nome, obtido, esperado])


func _andar(acoes: Array[StringName], quadros: int) -> void:
	for acao in acoes:
		Input.action_press(acao)
	for i in quadros:
		await physics_frame
		await process_frame
	for acao in acoes:
		Input.action_release(acao)


func _initialize() -> void:
	var cena: Node = load("res://cenas/estacao.tscn").instantiate()
	root.add_child(cena)
	await physics_frame

	var jogador: CharacterBody2D = cena.get_node("Jogador")
	var sprite: Sprite2D = jogador.get_node("Sprite2D")

	_checar("textura", sprite.texture.resource_path, "res://assets/sprites/miro_8dir.png")
	_checar("hframes", sprite.hframes, 4)
	_checar("vframes", sprite.vframes, 8)
	# A folha tem as oito direcoes desenhadas, entao nada e espelhado.
	_checar("sem espelhamento", sprite.flip_h, false)
	_checar("parado: olha para baixo", sprite.frame_coords, Vector2i(0, 0))

	# Uma linha por direcao, na ordem do enum Vista de scripts/jogador.gd. As
	# diagonais entram aqui porque e exatamente onde o octante pode sair
	# invertido: angle() devolve angulo negativo para quem anda para cima.
	var linhas: Array = [
		[[&"ui_right"], 1, "direita"],
		[[&"ui_right", &"ui_down"], 4, "baixo-direita"],
		[[&"ui_down"], 0, "baixo"],
		[[&"ui_left", &"ui_down"], 5, "baixo-esquerda"],
		[[&"ui_left"], 3, "esquerda"],
		[[&"ui_left", &"ui_up"], 7, "cima-esquerda"],
		[[&"ui_up"], 2, "cima"],
		[[&"ui_right", &"ui_up"], 6, "cima-direita"],
	]
	for caso in linhas:
		var acoes: Array[StringName] = []
		acoes.assign(caso[0])
		await _andar(acoes, 12)
		_checar("andando %s: linha da folha" % caso[2], sprite.frame_coords.y, caso[1])

	# O laco acima anda nas oito direcoes, entao a posicao final nao diz nada.
	# Este trecho mede um deslocamento isolado.
	var antes: Vector2 = jogador.position
	await _andar([&"ui_left"], 12)
	_checar("andou para a esquerda", jogador.position.x < antes.x, true)
	antes = jogador.position
	await _andar([&"ui_up"], 12)
	_checar("andou para cima", jogador.position.y < antes.y, true)

	var vistos: Dictionary = {}
	Input.action_press(&"ui_right")
	for i in 40:
		await physics_frame
		await process_frame
		vistos[sprite.frame_coords.x] = true
	Input.action_release(&"ui_right")
	_checar("andando: percorre os quatro quadros", vistos.size(), 4)

	for i in 60:
		await physics_frame
		await process_frame
	_checar("parou: volta ao quadro de descanso", sprite.frame_coords, Vector2i(0, 1))

	print("falhas: ", _falhas)
	quit(1 if _falhas > 0 else 0)
