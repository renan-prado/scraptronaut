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

### Corrigido

- **Expandir sobre o casco não abre mais buraco para o vácuo.** A célula saía do
  casco no instante do clique e o primeiro estágio era a baliza desenhada sobre o
  campo estelar: pedir chão onde havia parede abria um vão para o espaço. Agora a
  parede fica de pé até o chão novo ser entregue — inteira no `DEMARCADO`, e no
  `ESTRUTURA` já com a chapa assentada por trás, vista através dela. A estação só
  cresce atravessando o próprio casco, então não havia como evitar o caminho:
  o que mudou foi ele deixar de passar por um buraco

### Interno

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

- A tabela de comandos dizia que `npm run play` abre numa janela; ele abre em
  tela cheia desde que `-Fullscreen` entrou, e quem quer janela usa
  `npm run play:window`
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
