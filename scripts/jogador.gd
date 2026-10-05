extends CharacterBody2D
## Jogador: movimento, animacao por estado e a energia do dia de trabalho.
##
## A energia e do PERSONAGEM, nao da estacao. A energia da estacao e a unidade
## unica de docs/Mecanicas-Scraptronaut.md e nao tem nada a ver com esta: aqui
## se mede quanto Lira/Miro ainda aguenta bater picareta hoje. Andar e explorar
## nao gastam nada — so obra gasta, porque e so da obra que o cansaco e assunto.

signal energia_alterada(energia: float, maxima: float)

const VELOCIDADE: float = 230.0
const ACELERACAO: float = 2200.0
const ATRITO: float = 2600.0

## Um dia de trabalho. E a mesma unidade de MapaEstacao.TRABALHO_POR_CELULA, e e
## por isso que a barra cheia se le como "um dia": a tabela de custos de obra foi
## calibrada contra este numero.
const ENERGIA_MAXIMA: float = 100.0

## Abaixo disto a barra fica vermelha. Nao impede nada — e so aviso de que o
## proximo canteiro nao vai terminar hoje.
const ENERGIA_BAIXA: float = 25.0

enum Estado { PARADO, ANDANDO, TRABALHANDO, DORMINDO }

## Folha unica, 4x8: uma linha por direcao, quatro quadros de caminhada em cada.
## Gerada por tools/gerar_miro_8dir.py a partir de
## docs/sprites-paste/sprite-miro-walking.png.
const TEXTURA_ANDANDO: Texture2D = preload("res://assets/sprites/miro_8dir.png")

## As outras tres saem da de caminhada, em tools/gerar_miro_estados.py.
const TEXTURA_PARADO: Texture2D = preload("res://assets/sprites/miro_parado.png")
const TEXTURA_TRABALHO: Texture2D = preload("res://assets/sprites/miro_trabalho.png")
const TEXTURA_DORMINDO: Texture2D = preload("res://assets/sprites/miro_dormindo.png")

## Linhas da folha, na ordem em que foram desenhadas. A ordem veio de medir a
## folha (ver o cabecalho do gerador), nao de supor — e mexer aqui sem mexer em
## DIRECOES no gerador troca as direcoes em silencio.
enum Vista {
	BAIXO,
	DIREITA,
	CIMA,
	ESQUERDA,
	BAIXO_DIREITA,
	BAIXO_ESQUERDA,
	CIMA_DIREITA,
	CIMA_ESQUERDA,
}

## Octante do angulo de movimento -> linha da folha. O indice e
## round(angulo / 45 graus) a partir do eixo +x, com y crescendo para baixo:
## 0 = direita, 1 = baixo-direita, 2 = baixo, e assim por diante no sentido
## horario da tela.
const VISTA_POR_OCTANTE: Array[Vista] = [
	Vista.DIREITA,
	Vista.BAIXO_DIREITA,
	Vista.BAIXO,
	Vista.BAIXO_ESQUERDA,
	Vista.ESQUERDA,
	Vista.CIMA_ESQUERDA,
	Vista.CIMA,
	Vista.CIMA_DIREITA,
]

## Toda figura da folha sai com o chao da linha na base da celula e a cabeca no
## centro horizontal, entao o deslocamento e o mesmo em qualquer quadro.
##
## O valor depende da altura da celula (100 px) e poe a origem do personagem
## 4 px acima dos pes, que e onde a forma de colisao foi desenhada. Quem mexer
## em MARGEM_TOPO no gerador precisa trazer o numero que ele imprime.
const OFFSET_SPRITE: Vector2 = Vector2(0, -46)

## A folha de trabalho tem celula 10 px mais alta, para caber a picareta
## erguida; os pes continuam na base, entao so o centro muda.
const OFFSET_TRABALHO: Vector2 = Vector2(0, -51)

const QUADROS: int = 4

## O gerador ja gravou o ciclo na ordem certa — contato, passagem, contato,
## passagem — entao a animacao e so percorrer as colunas em sequencia.
const QUADRO_INICIAL: int = 0

## A animacao e puxada pela distancia percorrida, nao pelo relogio: desacelerar
## desacelera a passada junto, sem precisar de estado nenhum.
##
## Quanto o personagem anda, em pixels, a cada ciclo completo, se a passada
## casasse com o chao. Medido na vista lateral pelo gerador.
##
## O numero e aproximado: a folha so tem UM quadro de contato aberto por
## direcao, e o outro e bem mais fechado. E o avanco medio do ciclo, nao duas
## passadas iguais.
const ANDAR_PASSADA_EM_PIXELS: float = 84.2

## Quanto a animacao e esticada alem da passada medida.
##
## Em 1.0 o pe nao desliza, mas VELOCIDADE (230 px/s) daria 2,7 ciclos por
## segundo — quase 11 quadros por segundo numa arte de quatro poses, que le
## como corrida. Esticar acalma a cadencia ao custo de o pe patinar.
##
## Em 1.4: 2,0 ciclos por segundo, ~8 quadros por segundo. Subir muito mais
## picota, porque o ciclo e curto.
##
## O jeito de ter cadencia calma E pe no chao e reduzir VELOCIDADE. Isso e
## decisao de game feel, nao foi tomada.
const ANDAR_ALONGAMENTO: float = 1.4

## Duracao de um ciclo, em segundos, nos estados que nao andam.
##
## Parado e lento de proposito: a respiracao tem 2 px de amplitude, e num ciclo
## curto 2 px viram tremor. Dormindo e mais lento ainda, que e o que separa
## alguem dormindo de alguem so deitado. A martelada e o unico rapido — abaixo
## de meio segundo o golpe nao le, acima de um segundo parece desanimo.
const CICLO_PARADO: float = 2.6
const CICLO_TRABALHO: float = 0.8
const CICLO_DORMINDO: float = 4.2

## Abaixo disso a velocidade conta como parada, para o sprite nao piscar entre
## andar e parar enquanto o atrito zera o movimento.
const VELOCIDADE_PARADO: float = 8.0

## Faixa em que a roda do mouse move a camera do jogo, e o quanto cada entalhe
## da roda muda. O passo e o MESMO do modo de construcao, de proposito: e a
## mesma roda e o mesmo gesto, e duas sensibilidades diferentes para a mesma
## acao se notam na hora.
##
## A faixa, essa nao e a mesma. La ela vai de 0,25 a 1,5, que serve para olhar a
## planta inteira ou um canto dela; aqui e so o ajuste pessoal de quem joga em
## volta do padrao de 0,4 — quatro entalhes para cada lado. Mais do que isso e
## uma vista que o jogo nao foi desenhado para ter: afastado demais o
## personagem some, aproximado demais nao cabe uma sala na tela.
const ZOOM_MINIMO: float = 0.26
const ZOOM_MAXIMO: float = 0.62
const PASSO_ZOOM: float = 1.12

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _camera: Camera2D = $Camera2D

var energia: float = ENERGIA_MAXIMA

var _estado: Estado = Estado.PARADO
var _vista: Vista = Vista.BAIXO
var _passo: float = 0.0

## Travado no modo de construcao: la o WASD move a camera, nao o personagem.
var _travado: bool = false


func travar(valor: bool) -> void:
	_travado = valor
	if valor:
		velocity = Vector2.ZERO
		_trocar_estado(Estado.PARADO)


## Entra na pose de martelada, virado para o ponto da obra. E chamada a cada
## quadro enquanto o jogador segura a tecla: trocar de alvo vira o personagem
## sem reiniciar o ciclo, porque todas as linhas tem os mesmos quatro quadros.
func trabalhar_em(alvo_global: Vector2) -> void:
	var rumo: Vector2 = alvo_global - global_position
	if rumo.length() > 1.0:
		_atualizar_vista(rumo.normalized())
	velocity = Vector2.ZERO
	_trocar_estado(Estado.TRABALHANDO)


func parar_de_trabalhar() -> void:
	if _estado == Estado.TRABALHANDO:
		_trocar_estado(Estado.PARADO)


## Deita na cama. A posicao vem da propria cama (Cama.ponto_de_dormir), que sabe
## onde o travesseiro esta na arte — o jogador nao tem como saber.
func deitar(posicao: Vector2) -> void:
	global_position = posicao
	velocity = Vector2.ZERO
	_vista = Vista.BAIXO
	_trocar_estado(Estado.DORMINDO)


func levantar(posicao: Vector2) -> void:
	global_position = posicao
	_trocar_estado(Estado.PARADO)


func esta_dormindo() -> bool:
	return _estado == Estado.DORMINDO


## Gasta ate `quanto` de energia e devolve o que realmente saiu. Devolve o gasto,
## e nao um bool, porque quem paga converte energia em trabalho: no ultimo
## instante do dia sobra menos do que se pediu, e a obra so pode receber o que
## foi pago.
func gastar_energia(quanto: float) -> float:
	var gasto: float = minf(quanto, energia)
	if gasto <= 0.0:
		return 0.0
	energia -= gasto
	energia_alterada.emit(energia, ENERGIA_MAXIMA)
	return gasto


## A barra fica vermelha abaixo deste ponto. E metodo, e nao a constante lida de
## fora, porque constante de script nao e propriedade: quem le o jogador sem
## tipo — como scripts/trabalho.gd, que o pega pelo nome do no — nao alcanca
## ENERGIA_BAIXA por get().
func energia_baixa() -> bool:
	return energia <= ENERGIA_BAIXA


func descansar() -> void:
	energia = ENERGIA_MAXIMA
	energia_alterada.emit(energia, ENERGIA_MAXIMA)


func _ready() -> void:
	_aplicar_folha()
	_desenhar(QUADRO_INICIAL)
	energia_alterada.emit(energia, ENERGIA_MAXIMA)


func _process(delta: float) -> void:
	# Andar e puxado pela distancia, em _physics_process; os outros tres sao
	# puxados pelo relogio, porque nao ha deslocamento nenhum para puxa-los.
	match _estado:
		Estado.PARADO:
			_avancar_ciclo(delta, CICLO_PARADO)
		Estado.TRABALHANDO:
			_avancar_ciclo(delta, CICLO_TRABALHO)
		Estado.DORMINDO:
			_avancar_ciclo(delta, CICLO_DORMINDO)
		_:
			pass


func _physics_process(delta: float) -> void:
	if _travado or _estado == Estado.DORMINDO or _estado == Estado.TRABALHANDO:
		return
	var direcao: Vector2 = _ler_direcao()
	if direcao == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, ATRITO * delta)
	else:
		velocity = velocity.move_toward(direcao * VELOCIDADE, ACELERACAO * delta)
		_atualizar_vista(direcao)
	move_and_slide()

	var em_movimento: bool = velocity.length() > VELOCIDADE_PARADO
	_trocar_estado(Estado.ANDANDO if em_movimento else Estado.PARADO)
	if _estado == Estado.ANDANDO:
		_avancar_passo(delta)


## A roda do mouse aproxima e afasta a camera do jogo.
##
## Fica aqui, e nao no no de construcao que ja trata a roda, porque a camera e
## do jogador. Nao ha disputa: o modo de construcao le a roda em _unhandled_input
## e a consome, e por ser um irmao posterior na arvore ele recebe o evento antes
## — quando o modo esta aberto, nada chega aqui.
func _unhandled_input(evento: InputEvent) -> void:
	if _travado or not (evento is InputEventMouseButton):
		return
	var botao := evento as InputEventMouseButton
	if not botao.pressed:
		return
	var fator: float = 0.0
	if botao.button_index == MOUSE_BUTTON_WHEEL_UP:
		fator = PASSO_ZOOM
	elif botao.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		fator = 1.0 / PASSO_ZOOM
	if fator == 0.0:
		return
	var novo: float = clampf(_camera.zoom.x * fator, ZOOM_MINIMO, ZOOM_MAXIMO)
	_camera.zoom = Vector2(novo, novo)
	get_viewport().set_input_as_handled()


func _ler_direcao() -> Vector2:
	var direcao := Vector2(
		Input.get_axis(&"ui_left", &"ui_right"),
		Input.get_axis(&"ui_up", &"ui_down")
	)
	if Input.is_physical_key_pressed(KEY_A):
		direcao.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direcao.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		direcao.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direcao.y += 1.0
	return direcao.limit_length(1.0)


# --- Troca de estado do sprite ----------------------------------------------

func _trocar_estado(novo: Estado) -> void:
	if novo == _estado:
		return
	_estado = novo
	_passo = 0.0
	_aplicar_folha()
	_desenhar(QUADRO_INICIAL)


## Folha, grade e deslocamento do estado atual. O deslocamento muda junto com a
## folha porque a de trabalho tem celula mais alta: trocar a textura sem trocar
## o offset faria o personagem saltar 5 px ao erguer a picareta.
func _aplicar_folha() -> void:
	match _estado:
		Estado.ANDANDO:
			_sprite.texture = TEXTURA_ANDANDO
			_sprite.offset = OFFSET_SPRITE
			_sprite.vframes = Vista.size()
		Estado.TRABALHANDO:
			_sprite.texture = TEXTURA_TRABALHO
			_sprite.offset = OFFSET_TRABALHO
			_sprite.vframes = Vista.size()
		Estado.DORMINDO:
			# A pose deitada e so uma: vista de cima, quem esta de costas na cama
			# mostra o rosto, e nao ha oito jeitos de deitar nesta cama.
			_sprite.texture = TEXTURA_DORMINDO
			_sprite.offset = OFFSET_SPRITE
			_sprite.vframes = 1
		_:
			_sprite.texture = TEXTURA_PARADO
			_sprite.offset = OFFSET_SPRITE
			_sprite.vframes = Vista.size()
	_sprite.hframes = QUADROS
	# A folha tem as oito direcoes desenhadas; nada e espelhado.
	_sprite.flip_h = false


func _atualizar_vista(direcao: Vector2) -> void:
	var antes: Vista = _vista
	# posmod, nao %: angle() devolve de -PI a PI, entao o octante sai negativo
	# para quem anda para cima, e % em GDScript preserva o sinal.
	var octante: int = posmod(roundi(direcao.angle() / (TAU / 8.0)), 8)
	_vista = VISTA_POR_OCTANTE[octante]

	# Virar no meio da caminhada nao reinicia o ciclo: todas as linhas tem o
	# mesmo numero de quadros, entao e so trocar de linha no quadro atual.
	if _vista != antes:
		_desenhar(int(_passo))


# --- Ciclos ------------------------------------------------------------------

func _avancar_passo(delta: float) -> void:
	var ciclo: float = ANDAR_PASSADA_EM_PIXELS * ANDAR_ALONGAMENTO
	var distancia: float = velocity.length() * delta
	var avanco: float = distancia / ciclo * QUADROS
	_passo = fmod(_passo + avanco, float(QUADROS))
	_desenhar(int(_passo))


func _avancar_ciclo(delta: float, segundos: float) -> void:
	_passo = fmod(_passo + delta / segundos * QUADROS, float(QUADROS))
	_desenhar(int(_passo))


func _desenhar(coluna: int) -> void:
	var linha: int = 0 if _estado == Estado.DORMINDO else int(_vista)
	_sprite.frame_coords = Vector2i(coluna, linha)
