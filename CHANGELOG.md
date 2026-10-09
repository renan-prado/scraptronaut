# Changelog

Todas as mudanças relevantes do Scraptronaut. Formato baseado em
[Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); versionamento por
[SemVer](https://semver.org/lang/pt-BR/), com a ressalva de que **antes do 1.0.0
o jogo é protótipo** e `0.x` pode quebrar o que quiser.

## Como preencher

**Todo commit entra aqui**, em `[Não lançado]`, antes de comitar. A skill
`registrar-mudanca` faz isso.

Cada entrada responde o que mudou **para quem joga ou para quem mexe no código** —
não o que mudou no arquivo. `git log` já conta os arquivos; o changelog conta a
consequência.

| Seção | Para |
|---|---|
| `Adicionado` | funcionalidade que não existia |
| `Alterado` | comportamento que existia e mudou |
| `Corrigido` | bug |
| `Removido` | o que saiu |
| `Equilíbrio` | número de jogo recalibrado — custo, ritmo, alcance |
| `Interno` | refatoração, doc, tooling, teste: nada que o jogador note |

Quando um número de equilíbrio muda, a entrada diz **de quanto para quanto** e
**por quê** — é essa a informação que o `git log` não guarda e que o próximo
recalibre vai procurar.

---

## [Não lançado]

### Adicionado

- **O jogo tem fonte própria** (`assets/interface/vt323.ttf`, apontada por
  `gui/theme/custom_font`): a VT323, de terminal de vídeo. Antes a interface
  saía na fonte padrão do engine, que não tem nada a ver com o resto da arte.
  Todo `Label`, `Button` e `RichTextLabel` já nasce com ela. É **vetorial com
  desenho de pixel**, e por isso tem duas armadilhas silenciosas: importada com
  `antialiasing` ou `subpixel_positioning` ligados ela sai borrada, e **nem todo
  corpo sai limpo** — corpo fora de medida desenha com traço de espessura
  desigual dentro da mesma palavra, sem erro nenhum. Os corpos limpos foram
  medidos olhando (20, 24, 25, 28, 30, 40, 50) e os sujos também (14, 15, 16,
  18, 21, 22, 32, 33, 35, 37); **não há fórmula** que os explique. Por isso os
  três corpos em uso têm nome em `scripts/fonte.gd` — `Fonte.MIUDO` 20,
  `MEDIO` 25, `GRANDE` 30 — e corpo novo se confere na tela antes de entrar
- **Atalho do modo de construção no canto superior esquerdo**: o ícone do modo
  com a tampa de `F1` encavalada nele, sem uma palavra. Era a linha de texto
  `TAB — modo construção` escrita por cima do cenário, que lia como legenda de
  depuração. O ícone é martelo e chave de boca **cruzados**, desenho novo em
  `tools/gerar_tiles_estacao.py`, e não o de nenhuma das cinco ferramentas: o
  atalho abre o modo inteiro, e usar o desenho do "expandir" o faria ler como a
  ferramenta de expandir
- **Painel das ferramentas do modo de construção**, em coluna no canto superior
  direito, na mesma chapa de aço da placa do HUD. Uma linha por ferramenta, com
  a tampa da tecla à esquerda do nome, e `Confirmar · Enter` / `Cancelar · Esc`
  no fim. Em fila as cinco ferramentas com nome mediam mais de meia tela — não
  havia canto que as coubesse, e a coluna é o único arranjo em que a posição
  pedida é um canto de verdade. A linha escolhida fica **mais escura** que a
  chapa, como o rebaixo do contador do dia: o tema padrão do Godot acende o
  botão apertado, e aqui isso virava uma caixa branca maior que a própria placa
- **Tampa de teclado virou nó próprio** (`scripts/tecla.gd`), porque o balão de
  fala e o atalho do modo precisam da mesma peça — e a ordem das células na
  folha é um contrato com `tools/gerar_interface.py` que não pode morar em dois
  lugares. Com ela veio uma **segunda folha**, `teclas_duplas.png`: `F1` não cabe
  na célula quadrada de 11 px sem espremer a letra, e esticar a tampa quadrada
  deformaria as três faces que a fazem ler como peça. São as nove (`F1`–`F9`),
  e não só a que o jogo usa hoje — a folha inteira são alguns bytes, e o preço
  de um atalho novo passa a ser uma linha de código em vez de uma rodada do
  gerador

- **Painel de HUD** (`scripts/painel_hud.gd`): chapa de aço no canto superior
  direito que carrega o contador de dias, num rebaixo cavado nela, e a barra de
  energia. Antes eram texto solto e barra solta sobre o cenário. É moldura de
  nove pedaços com as arestas esticadas a partir de fatias de um pixel, então
  acompanha qualquer conteúdo sem arte nova — `_painel.conteudo` é um
  `VBoxContainer`, e a próxima leitura do HUD entra ali sem mexer em
  `trabalho.gd`
- **Moldura amarela no canteiro da mira**, desenhada antes de o `F` ser
  apertado: é ela que diz em qual célula a picareta vai cair. Fina, transparente
  e vazia por dentro — 3 px a 55%, num amarelo quase branco. Moldura grossa e
  opaca tapava a própria célula que o jogador foi olhar, e no âmbar da obra ela
  sumia dentro do que deveria estar apontando
- **Som** (`scripts/som.gd`, autoload `Audio`): a estação deixou de ser muda.
  Música de fundo em laço, pisada, martelada e porta/portão. A fachada é de
  verbo — `Som.passo()`, `Som.martelada()`, `Som.porta(abrindo)` —, então quem
  anda, martela ou abre porta tem **uma** linha de som cada, e qual amostra toca,
  em que volume e com que variação é assunto só de `som.gd`
- **Passo e martelada saem do quadro da animação**, não de um relógio próprio
  (`CONTATOS` e `IMPACTO` em `jogador.gd`). A caminhada é puxada pela distância
  percorrida, então desacelerar espaça as pisadas de graça; um relógio separado
  sairia de fase na primeira rampa de atrito — pé no chão com silêncio, e som com
  o pé no ar
- **Preparo do áudio cru** (`tools/gerar_audio.py`): `docs/audio/` está fora do
  versionamento, então o gerador converte para `assets/audio/`, que é de onde o
  jogo lê. Ele não copia, corta: `footstep.mp3` são **sete** pisadas numa
  gravação de alguém andando e viram sete amostras de 0,22 s (na velocidade cheia
  o pé bate quase 4×/s, mais que o dobro da gravação); a martelada vira WAV
  porque o MP3 traz 70 ms de silêncio do codificador, que num som casado com
  quadro de animação é atraso que se ouve; e a porta fechando é a de abrir
  **invertida**, porque não há gravação de fechamento. A música fica em MP3 e é
  copiada sem reprocessar — 196 s em WAV seriam ~75 MB contra 7,5
- **Balão de fala** (`scripts/balao.gd`): o personagem passou a falar em cima da
  própria cabeça, com o rabo apontando para ele. A tecla é **desenho** — tampa de
  teclado de `assets/interface/teclas.png` —, não a letra no meio da frase. Na
  cama ele diz o que acha do próprio cansaço ("não está muito cedo para dormir?",
  "estou caindo de sono", "acabei por hoje"), e o degrau do meio é o mesmo que
  pinta a barra de energia de vermelho

### Alterado

- **A recusa do modo de construção saiu do rodapé do painel e virou balão
  ancorado na seleção recusada.** No rodapé ela ficava longe do que reclamava: o
  jogador clica numa célula do outro lado da tela e o aviso acende num canto,
  sem nada ligando uma coisa à outra. O balão tem rabo, aponta, e responde "qual
  quadrado está errado" sem precisar dizer. É o mesmo balão da fala do
  personagem, com a linha em vermelho — a cor do retângulo recusado embaixo
  dela. Ela também passou a **ter prazo** (`DURACAO_DA_RECUSA`, 3 s), que a
  linha no painel não tinha: dentro da chapa uma linha parada era só uma linha
  parada, mas em cima do mapa, presa na célula, o que ninguém apaga vira
  obstáculo
- **Expandir sobre divisória interna agora derruba a parede**, em vez de recusar
  com "parede: demola para virar piso". Pedir chão onde há parede já diz o que o
  jogador quer, e mandá-lo trocar para a Demolir e clicar de novo no mesmo lugar
  eram duas ferramentas para dizer uma coisa só. Ela **não some de graça**: vira
  canteiro de demolição idêntico ao que a Demolir abriria — mesmo alvo, mesma
  escada ao contrário, mesmas marteladas. Continua sendo a **única** peça posta
  que o retângulo derruba: porta e portão são passagem, e varrê-los num arrasto
  largo partiria a estação em pedaços sem ninguém ter pedido
- **As recusas foram reescritas em frase inteira.** Eram etiquetas de
  depuração — "você está aqui", "só em parede", "aqui já é estação" — e viraram
  "Você está parado neste quadrado", "Coloque sobre uma parede externa", "Piso
  já construído". Foi o que a mudança de lugar cobrou: dentro do balão, em cima
  do mapa, a etiqueta curta não tem o contexto do painel para completá-la
- **O bloco de texto no alto da tela do modo de construção saiu inteiro** — o
  título, a dica de cada ferramenta, o manejo do mouse, o tamanho da área e a
  contagem de células alteradas. Eram três linhas de parágrafo de manual
  impressas por cima do cenário, e o modo todo se descobre clicando
- **O modo de construção abre com `F1`**, e não mais com `TAB` ou `B`. A tampa
  desenhada no atalho e a tecla que o `_unhandled_input` escuta são a mesma
  decisão, e andam juntas
- **As duas linhas do balão ficaram do mesmo corpo**, e a hierarquia passou a ser
  a cor e a tampa da tecla — claro para o que o personagem diz, âmbar com tampa
  para o que há para apertar. A fala usava um degrau acima da ação (24 contra 12
  na fonte anterior), mas os corpos limpos da VT323 não formam escada útil aqui:
  no degrau acima de `MIUDO` a fala media **667 px de tela**, mais da metade da
  largura, e uma dica que aparece toda vez que o personagem passa perto da cama
  não pode tomar meia tela
- **A tampa da tecla subiu de 1:1 para 2x** (`Tecla.ESCALA`). O número sempre foi
  derivado da letra ao lado, não escolhido: com a fonte de bitmap de 12 px, 2x
  media 22 px de tela — três vezes a altura da letra — e a linha lia como ícone
  com legenda. Com a VT323 a linha tem 20 px, e é o 1:1 que passa a estar fora de
  escala: 11 px ao lado dela lê como marca d'água, não como tecla
- **Os corpos de texto desceram**, a pedido, depois de vistos na tela: os dois
  balões de 25 para 20 e o menu de pausa de 50 para 30. Os primeiros números
  saíram de uma regra que parecia ser "múltiplo de 25" e que a medição desmentiu
- **`npm run play` voltou a abrir numa janela**, e quem quer tela cheia usa
  `npm run play:full`. Tela cheia atrapalha quem está desenvolvendo e precisa
  ver o editor ao lado; é o comando mais rodado do projeto, e o padrão dele tem
  de ser o caso comum

- **As dicas em texto solto no rodapé saíram**, substituídas pelo balão. Texto no
  rodapé não dizia de quem era a frase nem sobre o que falava: `E — dormir e
  começar o dia 2` podia estar saindo da cama, do portão ou de lugar nenhum
- **A fala do portão mudou de dono**, de `modo_construcao.gd` para `trabalho.gd`.
  Lá ela só aparecia com o modo de construção **fechado**, então nunca foi
  interface de construção: era fala de jogo escrita no vizinho, e o preço era um
  segundo balão capaz de aparecer por cima do primeiro
- **A barra de progresso da obra saiu de dentro da célula** e passou a ficar
  encostada por fora, no lado oposto ao do jogador. Dentro, ela tapava a obra
  que se foi olhar andar; num lado fixo acima, caía na cabeça de quem martelava
- **A fita de obra desenhada sobre peça em obra ficou translúcida** (45%). Ela é
  uma faixa larga nos quatro lados da célula, e opaca comia o quadrado inteiro:
  os estágios passavam sem dar para ver a peça mudar
- **O `F` trabalha no canteiro que o personagem encara**, e não mais no mais
  perto. Com um canteiro ao sul e outro a leste, quem decidia era o meio pixel
  em que o jogador tinha parado, e virar-se para o que ele queria não mudava
  nada. O cone é de 60° para cada lado — com 45 um canteiro na diagonal cairia
  na divisa entre duas vistas e piscaria. Canteiro debaixo dos pés dispensa mira
- **A barra de energia encolheu**: peça de 16×14 para 8×11 e passo entre
  divisões de 11 para 6 — a barra cheia caiu de 252 px de tela para 134, e o
  painel inteiro, já com o dia dentro, fica em 185×36. Quem perdeu altura foi o
  miolo; a moldura manteve as quatro linhas que a fazem ler como calha de aço
- **Expandir sobre divisória interna** passou a recusar com "parede: demola para
  virar piso", em vez do genérico "aqui já é estação" — quem quer chão onde há
  parede usa a Demolir
- **Balão de fala ganhou mais respiro interno** (`RESPIRO_X`/`RESPIRO_Y` em
  `balao.gd`, somados à borda), toda fala passou a abrir com maiúscula, e a
  linha da ação (tecla + texto âmbar) ficou com corpo menor que a fala (11
  contra 14) — eram do mesmo tamanho e liam como duas primeiras linhas, sem
  hierarquia. A tampa da tecla caiu para escala 1:1: em 2× ela media o dobro da
  altura da letra ao lado e lia como ícone com legenda, não tecla dentro da
  frase
- **A fala na cama sem energia trocou** de "a cama devolve o dia" para "Dorma
  para recuperar as energias", e a linha da tecla perdeu o número do dia —
  "dormir e começar o dia N" virou só "Dormir". O contador da placa do HUD já
  mostra o dia; repeti-lo na legenda da tecla fazia a linha mais comprida que a
  própria fala acima dela
- **Música de fundo trocada** (`scraptronaut-audio-2.mp3` no lugar da `-1`):
  216 s contra 196, e o arquivo caiu de 7,8 MB para 3,3 — copiada sem
  reprocessar, como antes. Qual faixa é a música sai de `MUSICA_CRUA` em
  `tools/gerar_audio.py`
- **O som de fechar porta/portão foi desligado**, a título de experimento —
  abrir continua soando, fechar fica em silêncio. `TOCAR_FECHANDO` em
  `som.gd` reverte trocando para `true`

### Corrigido

- **Expandir sobre o casco não abre mais buraco para o vácuo.** A célula saía do
  casco no instante do clique e o primeiro estágio era a baliza desenhada sobre o
  campo estelar: pedir chão onde havia parede abria um vão para o espaço. Agora a
  parede fica de pé até o chão novo ser entregue — inteira no `DEMARCADO`, e no
  `ESTRUTURA` já com a chapa assentada por trás, vista através dela. A estação só
  cresce atravessando o próprio casco, então não havia como evitar o caminho:
  o que mudou foi ele deixar de passar por um buraco
- **Som de abrir porta chegava atrasado em relação à porta já aberta na tela.**
  O desenho da porta troca no mesmo quadro em que o som é mandado tocar — não há
  animação, ver `_pintar_porta` em `mapa_estacao.gd` — mas a gravação trazia uns
  0,4 s de sopro antes da batida de verdade, e o corte anterior só tirava o
  silêncio de borda. `ADIANTAR_PORTA`, em `tools/gerar_audio.py`, adianta o
  início em mais 150 ms sem cortar o corpo do som

### Equilíbrio

- **`VOLUME_PORTA` caiu de −18 para −30 dB** (duas quedas de 6 dB, a pedido): a
  primeira, para o nível do passo, ainda soava alta na escuta
- **`VOLUME_PASSO` caiu de −24 para −30 dB**, a pedido — ficou empatado com a
  porta, os dois efeitos mais frequentes e mais sutis da escada de volumes. A
  martelada segue sozinha no topo, em −14 dB

### Interno

- **Todo nome de arquivo, pasta, script e classe do jogo passou para inglês.**
  Quem mexe no código procura por outro nome a partir daqui: a cena principal é
  `scenes/station.tscn`, o tileset é `resources/tileset_station.tres`, e as
  pastas de arte viraram `assets/objects/` e `assets/tiles/station/`. As classes
  acompanharam — `MapaEstacao` é `StationMap`, `Som` é `Sound`, `Fonte` é
  `Fonts`, `Tecla` é `KeyCap`, `Balao` é `SpeechBubble`, `BarraEnergia` é
  `EnergyBar`, `PainelHud` é `HudPanel`, `Cama` é `Bed` —, e com elas os
  `scripts/*.gd` e os `tools/*`. No `package.json`, `build:estacao` virou
  `build:station`. **O idioma do código é inglês; o da documentação, do
  changelog e do texto que o jogador lê continua português** — nada de interface
  mudou de língua, e `npm run check` e as 190 verificações passam
- **Os comentários longos do `project.godot` encurtaram**, e o *por quê* que
  estava neles agora mora só na documentação: a armadilha de importação da VT323
  e o motivo de `default_font_size` ter de estar escrito no arquivo estão em
  `docs/arquitetura/interface-e-camera.md`; o motivo de o autoload chamar-se
  `Audio` e não `Sound`, em `docs/arquitetura/som.md`
- **A renomeação deixou a documentação desatualizada**: ~149 menções aos nomes
  antigos em 14 arquivos de `docs/` — `mapa_estacao.gd`, `Fonte.rotulo`,
  `cenas/estacao.tscn`, `gerar_tiles.py` e companhia. Também ficaram em português
  `tools/gerar_interface.py`, `tools/conferir_tiles_estacao.py` e o script
  `shot:planta`. **Ponto aberto** — acertar isso é o trabalho seguinte, não parte
  desta mudança

- **O `.uid` órfão `tools/_verificar_andando.gd.uid` foi apagado.** Não era
  arquivo do projeto: era cache do Godot apontando para um script que não
  existe, e como nunca chegou a ser versionado aparecia em todo `git status`
  como se houvesse trabalho pendente. Sai sem passar pela decisão dos outros
  arquivos mortos, que continua aberta
- **`ABAIXO_DO_HUD` subiu de 58 para 71 px** (`modo_construcao.gd`): texto maior
  engordou a placa do HUD de 36 para 49 px de altura, e o painel das ferramentas
  passou a cobrir o contador do dia. Os dois painéis moram no mesmo canto
  superior direito e **não se conhecem** — um é de `trabalho.gd` e o outro de
  `modo_construcao.gd` —, então esse número é o único acordo entre eles. Há
  agora verificação disso em `tools/testar_estacao.gd`, porque na tela o estrago
  só aparece com o modo de construção aberto
- **A suíte foi de 165 para 190 verificações.** As novas cobrem o que não levanta
  erro: a importação da fonte (antialiasing e subpixel desligados, altura de
  linha igual ao corpo, `ç` e `ã` presentes), os três corpos serem corpos
  conferidos, `default_font_size` não ter ficado nos 16 do engine, as duas
  larguras da tampa de tecla, os dois painéis do modo nunca aparecerem juntos e
  nunca se cobrirem, e expandir sobre divisória abrir canteiro de demolição
- **A reescrita das recusas abriu `mapa_estacao.gd` em dezessete pontos**, e isso
  é o custo do item 5 de `docs/padroes/arquitetura.md` ficando visível: a regra
  devolve o texto de interface em português, então mexer na redação — que é
  trabalho de interface — obriga a abrir a camada de regras. Fica registrado
  junto da alternativa (`enum Recusa` com tabela de texto), que continua **não
  recomendada agora**
- **Uma fonte de bitmap foi feita e descartada no mesmo bloco de trabalho.**
  `tools/gerar_fonte.py`, `tools/conferir_fonte.py` e a folha que eles produziam
  (`assets/interface/fonte.png`, `fonte.fnt`) entram no repositório **já
  mortos** — nada os consome desde que `gui/theme/custom_font` passou a apontar
  para o `.ttf`. Entraram na lista de arquivos mortos do item 7 de
  `docs/padroes/arquitetura.md`; apagá-los continua sendo ponto aberto

- **Nome de autoload não pode ser nome de classe**, e o áudio foi quem descobriu.
  Com o autoload chamado `Som`, `npm run test` caía inteiro: `godot --headless
  --script` compila o script pedido **antes** de a SceneTree existir, e o nome
  global de um autoload só é registrado quando ela sobe — `mapa_estacao.gd` não
  compilava com `Identifier not found: Som`, derrubando as 165 verificações em
  cascata e junto `tools/capturar_construcao.gd`. Hoje a classe é `Som` (fachada
  estática, nome que vem do cache de classes globais e resolve em qualquer modo)
  e o autoload é `Audio`, que existe só para começar a música. A receita está em
  `docs/padroes/arquitetura.md`, porque vale para todo autoload futuro
- **Áudio não monta tocador em `--headless`.** Fluxo ainda tocando quando o
  processo fecha fica preso no servidor de áudio, e `npm run check` reprova
  qualquer linha `ERROR:`. A guarda vale para **todos** os tocadores, não só para
  a música: deixar só a faixa quieta não bastou, e `--verbose` apontou
  `porta_fechando.wav` — a última porta que a suíte fechou — vazando com sua
  leitura aberta

- `CLAUDE.md` virou índice: a documentação foi dividida em `docs/arquitetura/`,
  `docs/padroes/`, `docs/fluxo/` e `docs/decisoes/`, de 482 linhas num arquivo
  para ~120 de roteamento. Cada assunto se carrega sozinho, e um pedido sobre
  sprite não traz mais a regra de obra para a janela de contexto
- Padrões de arquitetura documentados em `docs/padroes/arquitetura.md`: seis
  princípios tirados dos guias *Best Practices* do Godot 4.7 e um diagnóstico de
  nove itens do código atual, com evidência e ordem sugerida. **Nenhum item foi
  implementado** — são propostas e esperam decisão
- Convenções de escrita em `docs/padroes/codigo-gdscript.md`, agora com a ordem
  oficial completa do GDScript e a regra de comentário do projeto
  (decisão + motivo + o que foi recusado)
- Skills: `pixel-art`, `rodar-e-capturar`, `editar-planta`, `registrar-mudanca`
- Agents: `revisor-gdscript`, `artista-pixel`, `revisor-de-docs`
- Este changelog

### Corrigido

- A tabela de comandos dizia que `npm run play` abre numa janela. Era mentira na
  época — ele abria em tela cheia desde que `-Fullscreen` entrou —, e a correção
  escrita aqui foi substituída pela troca de nome acima: hoje `play` é a janela
  de novo, e a tabela está certa pelo outro lado
- A referência a `docs/Estacao-Lastro-grid-e-modulos.md` dizia que o documento é
  a entrada de `tools/construir_estacao.gd`. Não é mais: a planta mora nas
  constantes de `mapa_estacao.gd` desde 2026-10-03
- `.gitignore` ignorava a documentação nova: a negação era `!docs/*.md`, que só
  alcança o primeiro nível, e `docs/arquitetura/`, `padroes/`, `fluxo/` e
  `decisoes/` ficariam fora do commit **em silêncio** — o índice de `CLAUDE.md`
  apontaria para o vazio em qualquer clone. Os quatro diretórios agora são
  negados explicitamente; as referências visuais soltas seguem ignoradas

---

## [0.3.0] — 2026-10-05

### Adicionado

- Energia do personagem: `Jogador.ENERGIA_MAXIMA` (100) é **um dia de trabalho**.
  Andar e explorar não gastam nada; só obra gasta
- `F` trabalha no canteiro mais perto, `E` dorme na cama. A tela apaga, o dia
  vira, a energia volta cheia no meio da noite
- Barra de energia em divisões de `>`, montada de peças
  (`tools/gerar_interface.py`). **O número de divisões sai da energia máxima** —
  uma melhoria futura ganha divisões sem arte nova
- Quatro estados de animação do personagem — parado, andando, trabalhando,
  dormindo — derivados da folha de caminhada feita a mão
  (`tools/gerar_miro_estados.py`)
- A cama: nó próprio, duas células em pé, encostada na parede norte do armazém
- Zoom no jogo pela roda do mouse, entre 0,26 e 0,62

### Alterado

- **Obra deixou de ter relógio.** Antes cada estágio durava
  `SEGUNDOS_POR_ESTAGIO` e passava sozinho enquanto o jogador fazia outra coisa;
  agora um estágio só fecha quando alguém bate trabalho naquela célula
- Demolir custa o mesmo trabalho que construir, e é o mesmo canteiro andando
  para trás
- A planta inicial encolheu de 44×30 para 30×21 células — mesma topologia de
  seis salas, menos da metade da área

### Equilíbrio

- Custo de obra caiu seis vezes: piso de 75 para **12,5** por célula. A escala
  anterior deixava o dia acabar antes de uma única célula fechar. A proporção
  não mudou — expandir segue sendo a obra cara, parede a barata
- Oito quadrados de chão por barra cheia de energia. Uma porta inteira custa o
  mesmo que um quadrado
- Ritmo em `MARTELADAS_POR_QUADRADO` (12), e `ENERGIA_POR_SEGUNDO` passou a ser
  **derivado** dele: mudar a cadência da animação sem mexer no ritmo faria a
  conta de marteladas mentir em silêncio. Terceira calibragem — 141 marteladas
  por quadrado foi recusado por acabar rápido demais, 24 por repetição

## [0.2.0] — 2026-10-05

### Adicionado

- Protótipo jogável da Estação Lastro: movimentação em oito direções, câmera,
  campo estelar procedural, menu de pausa
- Mapa **livre, célula a célula**, com o casco derivado a cada reconstrução.
  Quem pinta piso ganha parede de graça
- Modo de construção (`TAB`): expandir, parede, porta, portão e demolir, com
  arrasto em retângulo, validação em lote tudo-ou-nada e confirmar/cancelar
- Canteiro de obra em estágios, com fita de demarcação indexada por máscara
- Portas que abrem por proximidade; portão do hangar no `E`
- Onze atlas de tile gerados em código (`tools/gerar_tiles_estacao.py`), casco e
  borda indexados por máscara de 8 bits — 256 variações cada
- Runner `tools/run.ps1` e os atalhos de `package.json`; captura de tela, que é
  o único jeito de ver o jogo sem abrir o editor
- `tools/testar_estacao.gd`, que sai com o número de falhas

### Alterado

- Demolir piso no meio de uma sala passou a deixar **vão aberto para o espaço
  com parede de verdade em volta**. Terceira versão: bloco de casco maciço foi
  recusado ("parede nasceu do nada") e rombo de borda rasgada também ("não saiu
  dessa fase")

## [0.1.0] — 2026-10-02

### Adicionado

- Projeto Godot 4.7, perfil GL Compatibility
- Documentos de design versionados: história completa, mecânicas, mapa radial de
  exploração e a planta da Lastro em grid
- `CLAUDE.md`

[Não lançado]: https://github.com/renan-prado/scraptronaut/compare/e17fc9e...HEAD
[0.3.0]: https://github.com/renan-prado/scraptronaut/commit/e17fc9e
[0.2.0]: https://github.com/renan-prado/scraptronaut/commit/7a5b0c0
[0.1.0]: https://github.com/renan-prado/scraptronaut/commit/9fd6d45
