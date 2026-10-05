class_name Som
extends Node
## Som do jogo: a musica de fundo e os tres efeitos do protótipo.
##
## **A fachada e ESTATICA, e o autoload se chama `Audio` — nao `Som`.** Os dois
## nomes diferentes nao sao descuido; e o unico arranjo que funciona nos dois
## modos em que este projeto roda a engine.
##
## O QUE QUEBRA COM AUTOLOAD CHAMADO `Som`
##
## `tools/run.ps1 -Script` roda `godot --headless --script`, que e como `npm run
## test`, `npm run build:estacao` e os geradores de tools/ executam. Nesse modo a
## engine COMPILA o script pedido antes de a SceneTree existir — e o nome global
## de um autoload so e registrado quando a SceneTree sobe. Resultado medido: o
## no `Som` nasce em `/root` normalmente, mas `mapa_estacao.gd` nao compila,
## porque na hora da compilacao o identificador `Som` ainda nao existe:
##
##     SCRIPT ERROR: Compile Error: Identifier not found: Som
##        at: GDScript::reload (res://scripts/mapa_estacao.gd:940)
##
## Isso derrubou as 165 verificacoes de `npm run test` em cascata. Nome de
## `class_name`, ao contrario, vem do cache de classes globais, que a engine le
## ANTES de compilar qualquer script — e por isso `MapaEstacao` e `Cama`
## resolvem no mesmo modo em que `Som` falhava.
##
## POR QUE ENTAO NAO SO UM `class_name` ESTATICO, SEM AUTOLOAD
##
## Porque alguem precisa comecar a musica. Sem no na arvore, a fachada so
## acordaria na primeira chamada — e a primeira chamada e um passo ou uma porta,
## entao a faixa de fundo so entraria quando o jogador andasse. O autoload existe
## por esse motivo e so por ele: `_ready()` monta os tocadores, enche as
## referencias estaticas e toca a musica.
##
## Mexer no nome do autoload em project.godot e livre, MENOS para `Som`: ali
## volta a colisao, e a engine recusa o script com "Class \"Som\" hides an
## autoload singleton".
##
## Os tres requisitos que docs/padroes/arquitetura.md exige de um autoload — e
## que `Mapa`, `Trabalho` e `Construcao` nao cumprem — estao cumpridos aqui:
## guarda todo o seu estado dentro de si (as amostras e os tocadores), precisa
## ser alcancavel de qualquer lugar (quem anda, quem martela e quem abre porta
## sao tres nos diferentes, nenhum filho do outro) e nao le nem escreve estado
## de ninguem. Ele so recebe "aconteceu isto" e toca.
##
## POR QUE A INTERFACE E DE VERBO
##
## `Som.passo()`, e nao `Som.tocar("passo_3.wav")`. Quem chama sabe o que
## aconteceu no jogo; QUAL amostra toca, quantas existem, em que volume e com
## que variacao de altura e assunto exclusivamente deste arquivo. Foi o que
## manteve `jogador.gd` e `mapa_estacao.gd` com uma linha de som cada.
##
## POR QUE NAO HA SOM POSICIONAL
##
## `AudioStreamPlayer`, e nao `AudioStreamPlayer2D`. Tudo o que faz som neste
## protótipo acontece em cima do jogador ou a menos de tres celulas dele: o
## passo e dele, a martelada e dele, e porta e portao so mudam de estado por
## proximidade (ver ALCANCE_PORTA e ALCANCE_PORTAO em mapa_estacao.gd). Com toda
## fonte dentro do alcance de audicao, atenuacao por distancia nao mudaria nada
## e cada efeito custaria um no no mundo com posicao para manter em dia.
##
## Isso muda quando houver som que nasca longe — maquina de modulo, nave
## chegando, alarme de outra sala. Ai o nó passa a dar um `AudioStreamPlayer2D`
## por fonte, e esta fachada continua sendo a porta de entrada.
##
## POR QUE NAO HA BARRAMENTOS
##
## Tudo sai no Master, e o volume de cada som e uma constante aqui. Barramento
## "Musica" e "Efeitos" existe para uma tela de opcoes mexer num deslizante, e
## nao ha tela de opcoes — criar os dois agora seria estrutura esperando um
## usuario que nao existe. Quando a tela chegar, o lugar e `_ready`, com
## `AudioServer.add_bus`, e nenhum chamador muda.

## A faixa de fundo. MP3 e nao WAV porque sao 196 s: ver o cabecalho de
## tools/gerar_audio.py.
const MUSICA: AudioStreamMP3 = preload("res://assets/audio/musica_lastro.mp3")

## As sete pisadas fatiadas da gravacao. Sao sete amostras e nao uma porque na
## cadencia da caminhada o pe bate quase quatro vezes por segundo, e a mesma
## amostra nessa taxa le como metralhadora.
const PASSOS: Array[AudioStream] = [
	preload("res://assets/audio/passo_1.wav"),
	preload("res://assets/audio/passo_2.wav"),
	preload("res://assets/audio/passo_3.wav"),
	preload("res://assets/audio/passo_4.wav"),
	preload("res://assets/audio/passo_5.wav"),
	preload("res://assets/audio/passo_6.wav"),
	preload("res://assets/audio/passo_7.wav"),
]

const MARTELADA: AudioStream = preload("res://assets/audio/martelada.wav")
const PORTA_ABRINDO: AudioStream = preload("res://assets/audio/porta_abrindo.wav")
const PORTA_FECHANDO: AudioStream = preload("res://assets/audio/porta_fechando.wav")

## **Este e o "bem baixinho".** Um unico numero, e e o primeiro a mexer.
##
## -34 dB sao cerca de 2% da amplitude: a faixa fica no limite de se notar, que
## foi o pedido. Decibel e logaritmico, e isso engana ao mexer — -12 dB nao e
## "metade", e 25% da amplitude; cada -6 dB e que corta a amplitude pela metade.
## Para subir ou descer de verdade, mexer de 6 em 6.
const VOLUME_MUSICA: float = -34.0

## Volumes dos efeitos, em dB.
##
## **Os tres sao de propósito baixos: o pedido foi efeito sutil, nao audivel.**
## As amostras saem da gravacao quase na escala cheia (pico de 0,95 na pisada,
## 0,84 na martelada, 1,0 na porta) — a 0 dB a pisada sozinha encheria a
## mixagem, e mesmo os -10/-4/-7 da primeira mixagem ficaram altos na escuta.
##
## A ordem entre eles e que importa, e sobreviveu a queda: a martelada e a mais
## alta porque e o retorno de uma acao que o jogador esta pedindo com o dedo na
## tecla, e a pisada a mais baixa porque toca quatro vezes por segundo — som
## repetido cansa num volume em que som eventual nao cansaria. Mexer num deles
## sem olhar os outros desmancha essa escada.
##
## A porta caiu 12 dB ao todo a pedido (-18 -> -24 -> -30, em duas rodadas):
## a primeira queda, para o nivel da pisada, ainda nao bastou na escuta.
##
## A pisada caiu os mesmos 6 dB depois, tambem a pedido, de -24 para -30 — e as
## duas quedas pousaram juntas. Nao e coincidencia virar empate: pisada e porta
## sao os dois efeitos mais frequentes e mais sutis da escada, entao descer um
## e ouvir o outro destacar e natural. A martelada continua sozinha no topo.
const VOLUME_PASSO: float = -30.0
const VOLUME_MARTELADA: float = -14.0
const VOLUME_PORTA: float = -30.0

## Variacao de altura das pisadas, como multiplicador de frequencia: cada toque
## sai entre 1/1,08 e 1,08 do original. Mesmo com sete amostras o ciclo se
## percebe em caminhada longa, e um desvio pequeno o desmancha sem soar
## desafinado — acima de ~1,15 a bota comeca a trocar de tamanho a cada passo.
const VARIACAO_PASSO: float = 1.08

## Variacao de volume das pisadas, em dB para cada lado. Pe humano nao bate duas
## vezes com a mesma forca.
const VARIACAO_VOLUME_PASSO: float = 2.0

## Variacao de altura da martelada. Fechar um quadrado de chao sao doze golpes
## (MARTELADAS_POR_QUADRADO em trabalho.gd) e a amostra e uma so: sem desvio, a
## sequencia soa como um arquivo em laco em vez de alguem batendo.
const VARIACAO_MARTELADA: float = 1.06

## Quantos toques do MESMO efeito podem soar juntos.
##
## Tres, e nao um: `max_polyphony` padrao e 1, e nele cada toque novo CORTA o
## anterior. A pisada dura 0,22 s numa cadencia de 0,26 s, o que passa raspando
## — qualquer desaceleracao, e a cauda de um passo seria decapitada pelo
## seguinte, que e justamente o estalo que se ouve em jogo com som de passo mal
## resolvido. Tres cobre a sobreposicao real sem deixar um efeito preso tocando.
const TOQUES_JUNTOS: int = 3

## Os tocadores, ESTATICOS: quem chama `Som.passo()` nao tem instancia na mao,
## e e o autoload `Audio` que enche estas quatro em `_ready()`.
##
## Nascem nulas, e toda funcao de verbo confere antes de tocar — ver `_pronto()`.
static var _musica: AudioStreamPlayer
static var _passos: AudioStreamPlayer
static var _marteladas: AudioStreamPlayer
static var _portas: AudioStreamPlayer


## Um pe no chao. Chamado pelos quadros de CONTATO da caminhada, em jogador.gd:
## o som sai junto do quadro em que o pe encosta, e nao num relogio proprio, que
## e o que mantem passo e desenho casados quando o personagem desacelera.
static func passo() -> void:
	if _pronto():
		_passos.play()


## Um golpe de picareta. Sai do quadro de impacto da folha de trabalho, o mesmo
## em que o gerador desenha as faiscas.
static func martelada() -> void:
	if _pronto():
		_marteladas.play()


## Fechar em silencio, a titulo de experimento — se nao agradar, e so voltar
## para true. A amostra de fechar continua gerada normalmente; so o toque fica
## desligado.
const TOCAR_FECHANDO: bool = false

## Porta ou portao mudando de estado. A amostra de fechar e a de abrir ao
## contrario — ver tools/gerar_audio.py.
static func porta(abrindo: bool) -> void:
	if not _pronto():
		return
	if not abrindo and not TOCAR_FECHANDO:
		return
	_portas.stream = PORTA_ABRINDO if abrindo else PORTA_FECHANDO
	_portas.play()


## Os tocadores ja existem.
##
## Falso nos tools/ de `--script` que carregam uma cena do jogo sem subir o
## autoload junto, e no intervalo de um quadro entre a cena nascer e `_ready()`
## daqui rodar. Sem esta guarda, `mapa_estacao.gd` derrubaria o gerador no
## primeiro `Som.porta()` — e som que falta nao e motivo para o gerador falhar.
static func _pronto() -> bool:
	return _passos != null


## Esta execucao nao tem para onde mandar som.
##
## Vale para `--headless`, que e como rodam `npm run check`, `npm run test` e
## todo gerador de tools/: dezenas de execucoes por sessao, nenhuma com
## dispositivo de audio e nenhuma com mais de uns segundos de vida. Comecar a
## decodificar 196 s de MP3 em cada uma e trabalho jogado fora.
##
## E HA UM SEGUNDO MOTIVO, QUE FOI O QUE REVELOU O PRIMEIRO
##
## Fluxo que ainda esta TOCANDO quando o processo fecha fica preso no servidor de
## audio, e a engine sai imprimindo "ObjectDB instances were leaked" e "ERROR: 1
## resources still in use at exit". `npm run check` conta qualquer linha `ERROR:`
## como falha, entao audio reprovava o verificador do projeto.
##
## **A guarda vale para TODOS os tocadores, nao so para a musica.** A primeira
## versao so deixava de tocar a faixa de fundo, e os efeitos continuavam
## chamando `play()` — o que em headless sai no driver mudo, mas deixa a leitura
## viva no servidor. Medido com `--verbose` em `npm run test`:
##
##     Leaked instance: AudioStreamWAV
##     Leaked instance: AudioStreamPlaybackWAV
##     Resource still in use: res://assets/audio/porta_fechando.wav
##
## Era a ULTIMA porta que a suite fechou, ainda tocando quando o processo
## morreu. Com o autoload desligado o vazamento desaparecia; com os tocadores
## nao montados, tambem — e as 165 verificacoes continuam passando.
##
## O que foi medido e RECUSADO, nesta ordem:
##
## - `stop()` em `_exit_tree`, com e sem soltar o fluxo, e com `free()` no
##   tocador. `_exit_tree` roda (confirmado com print), e o vazamento continua:
##   `stop()` so marca a leitura para sair na proxima mistura do servidor, e
##   nessa altura nao ha proxima.
## - `loop = false`. O vazamento nao e do laco: uma faixa de 216 s ainda esta
##   tocando no quadro 60 de qualquer jeito, e vaza igual.
## - soltar so as referencias estaticas em `_exit_tree`. Continua vazando: o
##   problema nao e quem aponta para a amostra, e a leitura aberta no servidor.
##
## Nao e defeito do jogo — e a ordem de desmontagem da engine, e acontece
## tambem com janela, onde ninguem le a saida. Nao montar tocador onde nao ha
## saida de audio resolve o verificador pelo lado certo, sem afrouxar o filtro de
## erro de tools/run.ps1 (que entao deixaria passar vazamento de verdade) e sem
## deixar de carregar amostra nenhuma: os `preload` acima continuam valendo em
## headless, e e neles que mora o erro que importa — arquivo que falta ou nao
## importou.
static func _sem_saida_de_audio() -> bool:
	return DisplayServer.get_name() == "headless"


## Roda no no do autoload `Audio`, uma vez. Daqui para frente a fachada e
## estatica e este no so existe para ser o pai dos tocadores.
func _ready() -> void:
	# A musica atravessa o menu de pausa. Em Godot 4 um AudioStreamPlayer de no
	# pausado para junto com a arvore, e cortar a faixa no Esc le como defeito:
	# o menu de pausa nao e troca de cena, e o jogo continua ali atras.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# O laco e propriedade do RECURSO, nao do tocador, e o importador de MP3
	# nasce com ela desligada — sem ligar aqui, a faixa toca uma vez e a estacao
	# fica em silencio depois de tres minutos.
	#
	# Passa por uma variavel porque GDScript recusa atribuicao atraves de um
	# const, mesmo a uma propriedade do recurso apontado. A outra saida era
	# `loop=true` no .import do arquivo, e foi recusada: dali a decisao
	# desaparece de vista, e quem reimportar o MP3 com os padroes do editor
	# desliga o laco em silencio.
	# Sem saida de audio nao se monta tocador NENHUM, e por isso esta guarda e a
	# primeira coisa: com as referencias estaticas vazias, todo verbo da fachada
	# nao faz nada (ver _pronto()). Ver _sem_saida_de_audio() para o motivo.
	if _sem_saida_de_audio():
		return

	var faixa: AudioStreamMP3 = MUSICA
	faixa.loop = true

	_musica = _tocador(&"Musica", faixa, VOLUME_MUSICA, 1)

	_passos = _tocador(&"Passos", _sortear(PASSOS, VARIACAO_PASSO, VARIACAO_VOLUME_PASSO), VOLUME_PASSO, TOQUES_JUNTOS)
	_marteladas = _tocador(&"Marteladas", _sortear([MARTELADA], VARIACAO_MARTELADA, 0.0), VOLUME_MARTELADA, TOQUES_JUNTOS)
	# A porta nao sorteia nada: sao duas amostras com significado proprio, e
	# qual das duas toca e o chamador que sabe.
	_portas = _tocador(&"Portas", null, VOLUME_PORTA, TOQUES_JUNTOS)

	_musica.play()


## Solta as referencias estaticas quando a arvore desmonta.
##
## **Static var nao morre com o no.** Ela vive enquanto o SCRIPT estiver
## carregado, entao sem isto os quatro tocadores continuariam referenciados por
## uma classe depois de a arvore que os criou ter sido desmontada.
##
## Isto e higiene de referencia, e **nao** e o que resolve vazamento de audio no
## fim do processo: quem resolve e nao montar tocador em headless, em `_ready()`.
## Ver _sem_saida_de_audio().
func _exit_tree() -> void:
	_musica = null
	_passos = null
	_marteladas = null
	_portas = null


## Monta um tocador e o pendura neste no. Fica numa funcao so para os quatro
## nascerem com as mesmas decisoes: tudo no Master, polifonia explicita e nome
## visivel no depurador remoto.
func _tocador(nome: StringName, fluxo: AudioStream, volume: float, juntos: int) -> AudioStreamPlayer:
	var tocador := AudioStreamPlayer.new()
	tocador.name = nome
	tocador.stream = fluxo
	tocador.volume_db = volume
	tocador.max_polyphony = juntos
	add_child(tocador)
	return tocador


## Embrulha amostras num sorteador com desvio de altura e de volume.
##
## O modo padrao do AudioStreamRandomizer e "aleatorio sem repetir", que e o que
## se quer: sorteio puro repete a mesma pisada duas vezes seguidas com
## frequencia alta o bastante para se ouvir.
##
## Com uma amostra so o sorteio nao escolhe nada, e o nó continua valendo pelo
## desvio — e assim que a martelada deixa de soar como arquivo em laco.
func _sortear(amostras: Array, altura: float, volume: float) -> AudioStreamRandomizer:
	var sorteador := AudioStreamRandomizer.new()
	sorteador.random_pitch = altura
	sorteador.random_volume_offset_db = volume
	for i: int in amostras.size():
		sorteador.add_stream(i, amostras[i])
	return sorteador

