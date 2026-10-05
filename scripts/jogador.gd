extends CharacterBody2D
## Jogador provisorio, usado para verificar colisoes e passagens da estacao.

const VELOCIDADE: float = 230.0
const ACELERACAO: float = 2200.0
const ATRITO: float = 2600.0

## Folha unica, 4x8: uma linha por direcao, quatro quadros de caminhada em cada.
## Gerada por tools/gerar_miro_8dir.py a partir de
## docs/sprites-paste/sprite-miro-walking.png.
const TEXTURA: Texture2D = preload("res://assets/sprites/miro_8dir.png")

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

const QUADROS: int = 4

## O gerador ja gravou o ciclo na ordem certa — contato, passagem, contato,
## passagem — entao a animacao e so percorrer as colunas em sequencia. O quadro
## 0 e tambem a pose de parado.
const QUADRO_PARADO: int = 0

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

## Abaixo disso a velocidade conta como parada, para o sprite nao piscar entre
## andar e parar enquanto o atrito zera o movimento.
const VELOCIDADE_PARADO: float = 8.0

@onready var _sprite: Sprite2D = $Sprite2D

var _andando: bool = false
var _vista: Vista = Vista.BAIXO
var _passo: float = 0.0

## Travado no modo de construcao: la o WASD move a camera, nao o personagem.
var _travado: bool = false


func travar(valor: bool) -> void:
	_travado = valor
	if valor:
		velocity = Vector2.ZERO
		_entrar_parado()


func _ready() -> void:
	_sprite.texture = TEXTURA
	_sprite.hframes = QUADROS
	_sprite.vframes = Vista.size()
	_sprite.offset = OFFSET_SPRITE
	# A folha tem as oito direcoes desenhadas; nada e espelhado.
	_sprite.flip_h = false
	_entrar_parado()


func _physics_process(delta: float) -> void:
	if _travado:
		return
	var direcao: Vector2 = _ler_direcao()
	if direcao == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, ATRITO * delta)
	else:
		velocity = velocity.move_toward(direcao * VELOCIDADE, ACELERACAO * delta)
		_atualizar_vista(direcao)
	move_and_slide()

	var em_movimento: bool = velocity.length() > VELOCIDADE_PARADO
	if em_movimento != _andando:
		if em_movimento:
			_entrar_andando()
		else:
			_entrar_parado()

	if _andando:
		_avancar_passo(delta)


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

func _entrar_parado() -> void:
	_andando = false
	_desenhar(QUADRO_PARADO)


func _entrar_andando() -> void:
	_andando = true
	_passo = 0.0
	_desenhar(0)


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


# --- Caminhada ---------------------------------------------------------------

func _avancar_passo(delta: float) -> void:
	var ciclo: float = ANDAR_PASSADA_EM_PIXELS * ANDAR_ALONGAMENTO
	var distancia: float = velocity.length() * delta
	var avanco: float = distancia / ciclo * QUADROS
	_passo = fmod(_passo + avanco, float(QUADROS))
	_desenhar(int(_passo))


func _desenhar(coluna: int) -> void:
	_sprite.frame_coords = Vector2i(coluna, int(_vista))
