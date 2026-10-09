# Som

`scripts/sound.gd` e `tools/gerar_audio.py`.

Carregar para mexer em música de fundo, volume, efeito sonoro novo, ou para
entender por que o áudio é a única coisa do projeto que mora num autoload.

## O que faz som hoje

Quatro sons, e é tudo o que o protótipo tem.

| Som | Quem dispara | Amostra |
|---|---|---|
| Música de fundo | o próprio autoload, em `_ready()` | `assets/audio/lastro_music.mp3`, em laço |
| Passo | `jogador.gd`, nos quadros de contato da caminhada | `footstep_1..7.wav`, sorteadas |
| Martelada | `jogador.gd`, no quadro de impacto do trabalho | `hammer_hit.wav` |
| Porta e portão | `mapa_estacao.gd`, quando o vão muda de estado | `door_opening.wav` / `door_closing.wav` |

## A interface é de verbo

`Sound.footstep()`, e não `Sound.play("footstep_3.wav")`. Quem chama sabe **o que
aconteceu no jogo**; qual amostra toca, quantas existem, em que volume e com que
variação de altura é assunto exclusivo de `sound.gd`. É o que mantém `jogador.gd` e
`mapa_estacao.gd` com uma linha de som cada.

Acrescentar som novo é, na ordem: a amostra em `tools/gerar_audio.py`, o
`preload` e o volume em `sound.gd`, um verbo novo, e **uma** linha em quem sabe que
o evento aconteceu.

## Os dois nomes: classe `Sound`, autoload `Audio`

**Isto parece descuido e não é.** `scripts/sound.gd` declara `class_name Sound`, e o
autoload em `project.godot` chama-se `Audio`. Os dois nomes **têm** de diferir, e
o motivo é a ordem em que a engine carrega as coisas.

`tools/run.ps1 -Script` roda `godot --headless --script`, que é como executam
`npm run test`, `npm run build:estacao` e os geradores de `tools/`. Nesse modo a
engine **compila o script pedido antes de a SceneTree existir** — e o nome global
de um autoload só é registrado quando a SceneTree sobe. Com o autoload chamado
`Sound`, o nó nascia normalmente em `/root`, mas a compilação quebrava antes:

```
SCRIPT ERROR: Compile Error: Identifier not found: Som
   at: GDScript::reload (res://scripts/mapa_estacao.gd:940)
```

Isso derrubou as 165 verificações de `npm run test` em cascata, e junto
`tools/capturar_construcao.gd`. Nome de `class_name`, ao contrário, vem do cache
de classes globais, que a engine lê **antes** de compilar qualquer script — é por
isso que `MapaEstacao` e `Cama` resolvem no mesmo modo em que `Sound` falhava.

Daí o arranjo de hoje:

- `class_name Sound`, **fachada estática**: resolve em tempo de compilação em todo
  modo — jogo, editor e `--script`
- autoload `Audio`, que é o único motivo de haver nó: alguém precisa **começar a
  música**. Sem nó na árvore a fachada só acordaria na primeira chamada, e a
  primeira chamada é um passo ou uma porta — a faixa de fundo só entraria quando
  o jogador andasse
- `_ready()` monta os tocadores e enche as referências estáticas;
  `_exit_tree()` as solta

**Renomear o autoload é livre, menos para `Sound`**: ali volta a colisão, e a
engine recusa o script inteiro com `Class "Som" hides an autoload singleton`.

`_exit_tree()` solta as quatro referências porque *static var* não morre com o
nó — vive enquanto o script estiver carregado —, e sem isso os tocadores ficariam
pendurados numa classe depois de a árvore que os criou ter sido desmontada. É
**higiene de referência**, e não o que resolve vazamento de áudio no fim do
processo: quem resolve é não montar tocador em headless (abaixo).

## Onde ficam os volumes

Quatro constantes no topo de `sound.gd`, e é o primeiro lugar a mexer.

| Constante | Hoje |
|---|---|
| `MUSIC_VOLUME` | −34 dB |
| `FOOTSTEP_VOLUME` | −30 dB |
| `HAMMER_HIT_VOLUME` | −14 dB |
| `DOOR_VOLUME` | −30 dB |

**Os quatro são deliberadamente baixos: o pedido foi fundo discreto e efeito
sutil.** A primeira mixagem saiu de pico medido de arquivo (−24 / −10 / −4 / −7)
e ficou alta na escuta.

Decibel é logarítmico, e isso engana ao ajustar: −12 dB não é "metade", é 25% da
amplitude. **Cada −6 dB corta a amplitude pela metade** — para subir ou descer de
verdade, mexer de 6 em 6.

A ordem entre os efeitos importa e sobreviveu à queda: a martelada é a mais alta
porque é o retorno de uma ação que o jogador está pedindo com o dedo na tecla, e
o passo o mais baixo porque toca quatro vezes por segundo — som repetido cansa
num volume em que som eventual não cansaria. Mexer num sem olhar os outros
desmancha essa escada.

A porta caiu 12 dB ao todo a pedido (−18 → −24 → −30, em duas rodadas): a
primeira queda, para o nível do passo, ainda não bastou na escuta.

O passo caiu os mesmos 6 dB depois, também a pedido, de −24 para −30 — e as
duas quedas pousaram juntas. Não é coincidência virar empate: passo e porta são
os dois efeitos mais frequentes e mais sutis da escada, então descer um faz o
outro se destacar. A martelada continua sozinha no topo.

## O que o nó deliberadamente não tem

**Sem som posicional.** `AudioStreamPlayer`, e não `AudioStreamPlayer2D`. Tudo o
que faz som acontece em cima do jogador ou a menos de três células dele — porta e
portão só mudam de estado por proximidade (`ALCANCE_PORTA`, `ALCANCE_PORTAO`).
Com toda fonte dentro do alcance de audição, atenuação por distância não mudaria
nada e cada efeito custaria um nó no mundo com posição para manter em dia.

Isso muda quando houver som que **nasça longe** — máquina de módulo, nave
chegando, alarme de outra sala. Aí passa a ser um `AudioStreamPlayer2D` por
fonte, e esta fachada continua sendo a porta de entrada.

**Sem barramentos.** Tudo sai no Master. Barramento "Música" e "Efeitos" existe
para uma tela de opções mexer num deslizante, e não há tela de opções — criar os
dois agora seria estrutura esperando um usuário que não existe. Quando a tela
chegar, o lugar é `_ready()`, com `AudioServer.add_bus`, e nenhum chamador muda.

**Sem montar tocador nenhum em `--headless`.** `_no_audio_output()` olha
`DisplayServer.get_name()`, e é a primeira linha de `_ready()`: com as
referências estáticas vazias, todo verbo da fachada não faz nada. Fluxo que ainda
está **tocando** quando o processo fecha fica preso no servidor de áudio, e `npm
run check` reprova qualquer linha `ERROR:`.

**A guarda vale para todos os tocadores, não só para a música** — e é o erro que
a primeira versão cometeu. Deixar só a faixa de fundo quieta não bastava: os
efeitos continuavam chamando `play()`, o que em headless sai no driver mudo mas
deixa a leitura viva no servidor. `npm run test` com `--verbose` apontou o
culpado:

```
Leaked instance: AudioStreamWAV
Leaked instance: AudioStreamPlaybackWAV
Resource still in use: res://assets/audio/door_closing.wav
```

Era a **última porta que a suíte fechou**, ainda tocando quando o processo
morreu. Medido nas duas pontas: com o autoload desligado o vazamento
desaparecia, e com os tocadores não montados também — e as 165 verificações
continuam passando, em 3 de 3 execuções.

Os `preload` continuam valendo em headless, e é neles que mora o erro que
importa: arquivo que falta ou não importou.

Foi medido e **recusado**, nesta ordem: `stop()` em `_exit_tree` (com e sem
soltar o fluxo, e com `free()` no tocador — `stop()` só marca a leitura para sair
na próxima mistura do servidor, e nessa altura não há próxima); `loop = false` (o
vazamento não é do laço — 216 s ainda estão tocando no quadro 60 de qualquer
jeito); e soltar só as referências estáticas em `_exit_tree` (continua vazando —
o problema não é quem aponta para a amostra, é a leitura aberta no servidor).

## A música atravessa o menu de pausa

`process_mode = PROCESS_MODE_ALWAYS` no autoload. Em Godot 4 um
`AudioStreamPlayer` de nó pausado para junto com a árvore, e cortar a faixa no
`Esc` lê como defeito: o menu de pausa não é troca de cena, e o jogo continua ali
atrás.

O laço é propriedade **do recurso**, não do tocador, e o importador de MP3 nasce
com ela desligada — sem ligar em `_ready()`, a faixa toca uma vez e a estação
fica em silêncio depois de três minutos. Passa por uma variável porque GDScript
recusa atribuição através de um `const`. A outra saída era `loop=true` no
`.import`, e foi **recusada**: dali a decisão desaparece de vista, e quem
reimportar o MP3 com os padrões do editor desliga o laço em silêncio.

## Por que o passo sai do quadro de animação

O gatilho é a **troca de coluna** do sprite, em `jogador.gd` — `CONTATOS` para a
caminhada, `IMPACTO` para a martelada —, e não um temporizador próprio. A
caminhada é puxada pela distância percorrida (`ANDAR_PASSADA_EM_PIXELS`), então
desacelerar espaça as pisadas junto, de graça. Um relógio de passo separado teria
de refazer essa conta e sairia de fase na primeira rampa de atrito: pé no chão
com silêncio, e som com o pé no ar.

O detalhe de quais colunas são contato está em
[personagem-e-animacao.md](personagem-e-animacao.md).

## As amostras: de onde vêm e por que são cortadas

Os arquivos crus ficam em `docs/audio/`, que o `.gitignore` **não versiona** (só
`.md` e `.html` passam em `docs/`). `tools/gerar_audio.py` os converte para
`assets/audio/`, que é versionado e é de onde o jogo lê — sem o gerador, o jogo
carregaria áudio que o repositório não tem.

Copiar na mão esconderia os cortes que o áudio cru **exige**, e é isso que o
cabeçalho do gerador registra em detalhe. O resumo:

- **WAV nos efeitos, MP3 só na música.** MP3 é por quadro: o decodificador
  devolve o silêncio que o codificador acrescentou, e `metal-hammer-hit.mp3` tem
  70 ms dele. Num som percussivo casado com um quadro de animação, 70 ms é atraso
  que se ouve — o golpe sai depois da faísca. A música fica em MP3 pelo motivo
  inverso: 216 s em WAV são ~76 MB contra 3,3 do MP3, e latência de decodificação
  de faixa contínua não importa. Ela é **copiada** sem reprocessar. Qual faixa é a
  música sai de `RAW_MUSIC` em `tools/gerar_audio.py` — trocar a trilha é trocar
  esse nome e rodar o gerador, que o jogo carrega sempre `lastro_music.mp3`
- **A pisada é fatiada.** `footstep.mp3` não é uma pisada: são **sete**, espaçadas
  0,54 s. Tocar o arquivo inteiro em laço foi a primeira ideia e está errada — na
  velocidade cheia o pé bate quase 4 vezes por segundo, mais que o dobro da
  gravação. Fatiado, cada quadro de contato dispara **uma** pisada, e as sete
  viram variação
- **A janela da pisada é curta de propósito.** 0,22 s. O arquivo deixa 0,54 s de
  ar depois de cada pisada; guardar esse ar deixaria três amostras soando juntas
  na cadência do jogo, e o passo viraria arrasto
- **A porta fechando é a mesma amostra invertida.** Foi o pedido, e é truque
  conhecido: `open-door.mp3` é um crescendo até o pico com queda curta, então ao
  contrário vira entrada suave que termina em batida seca — a leitura de uma folha
  encostando no batente. Não há gravação de fechamento

Os cortes **medem**, não assumem: trocar `footstep.mp3` por outra gravação muda o
número de fatias e o espaçamento sem mexer em nada no gerador.

Toda amostra aparada leva entrada e saída curtas nas bordas. Corte seco em
amostra diferente de zero é um clique, e com cauda ainda audível o clique fica
mais alto que o próprio som.

## Variação, para não soar como arquivo em laço

| Constante | O que desmancha |
|---|---|
| `FOOTSTEP_PITCH_VARIATION` (1,08) | o ciclo das sete amostras, perceptível em caminhada longa |
| `FOOTSTEP_VOLUME_VARIATION` (2 dB) | pé humano não bate duas vezes com a mesma força |
| `HAMMER_HIT_PITCH_VARIATION` (1,06) | doze golpes por quadrado, e a amostra é uma só |

O `AudioStreamRandomizer` fica em "aleatório sem repetir", que é o que se quer:
sorteio puro repete a mesma pisada duas vezes seguidas com frequência alta o
bastante para se ouvir. Com uma amostra só o sorteio não escolhe nada, e o nó
continua valendo pelo desvio — é assim que a martelada deixa de soar como arquivo
em laço.

Acima de ~1,15 na altura a bota começa a trocar de tamanho a cada passo.

`CONCURRENT_PLAYS` é **3**, e não 1: `max_polyphony` padrão é 1, e nele cada toque
novo **corta** o anterior. A pisada dura 0,22 s numa cadência de 0,26 s, o que
passa raspando — qualquer desaceleração, e a cauda de um passo seria decapitada
pelo seguinte, que é justamente o estalo que se ouve em jogo com som de passo mal
resolvido.

## Regenerar

```powershell
python tools/gerar_audio.py
```

Precisa de `ffmpeg` e `ffprobe` no PATH (nenhuma biblioteca de Python instalada
aqui lê MP3) e de `numpy`. **Reexecutar sobrescreve a saída sem avisar.**

Verificar depois com `npm run check`. Volume e mixagem **não** se verificam
headless: para ouvir, `npm run play`.
