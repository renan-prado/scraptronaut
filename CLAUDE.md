# Scraptronaut

Jogo 2D em pixel art, perspectiva top-down em três quartos, feito em **Godot** com **GDScript**.

O jogador é um sucateiro (Lira / Miro) que atravessa acidentalmente uma fenda espacial, cai numa estação abandonada (Lastro) e precisa recuperá-la, expandir o alcance da nave e reconstruir a tecnologia de travessia para tentar voltar à Terra — onde há uma meia na lavanderia.

## Estado atual do repositório

O projeto **saiu da fase de só-design**: existe um protótipo jogável da Estação Lastro. Nada disso está comitado ainda — tudo aparece como untracked sobre os dois commits existentes.

| Caminho | Conteúdo |
|---|---|
| `cenas/estacao.tscn` | Cena principal, 17 nós: campo estelar, `Mapa` com seis TileMapLayer vazios, jogador com câmera, `Construcao` com câmera própria, menu de pausa |
| `scripts/mapa_estacao.gd` | **Modelo e desenho do mapa.** Guarda as células, deriva o casco, pinta as camadas, abre portas por proximidade e alterna portões |
| `scripts/modo_construcao.gd` | Modo de construção: cursor, ferramentas, câmera livre, interface. Também a dica de `E` do portão |
| `scripts/jogador.gd` | CharacterBody2D: movimento, caminhada em oito direções, `travar()` para o modo de construção |
| `scripts/campo_estelar.gd` | Fundo procedural |
| `recursos/tileset_estacao.tres` | TileSet gerado: piso, borda, casco (256 variações com colisão, mais 256 alternativas apagadas), porta (com alternativa em obra), portão, detalhes, obra, demarcação (256), buraco, cones, marcação |
| `assets/tiles/estacao/` | Os onze atlas da estação, gerados por `tools/gerar_tiles_estacao.py` |
| `assets/interface/ferramentas.png` | Ícones da barra de construção, do mesmo gerador |
| `assets/sprites/` | Sprites do personagem, 64 px por célula de cenário |
| `docs/*.png`, `docs/print-paste/` | Folhas de referência cruas; `print-paste/image copy.png` é a referência de estrutura da estação |
| `tools/` | Geradores, testes e execução (ver abaixo) |

`run/main_scene` já aponta para `res://cenas/estacao.tscn`.

### Como o mapa funciona agora

A estação **não é mais feita de módulos de 12×12**. `mapa_estacao.gd` guarda um dicionário de célula → tipo (`PISO`, `MURO`, `PORTA`, `PORTAO`, `OBRA`) e **deriva o casco** a cada reconstrução.

A derivação tem duas etapas. Toda célula vazia encostada no interior é candidata a parede; as que **alcançam o espaço aberto** viram casco maciço, e as cercadas pela estação viram **buraco** — vão aberto para o espaço, com parede em volta. Um flood-fill de fora para dentro decide qual é qual.

A diferença entre os dois é só o desenho, e ela importa. Três versões foram necessárias para achar o ponto:

| Versão | O que saía ao demolir piso no meio da sala | Veredito |
|---|---|---|
| 2026-10-03, antes | bloco de casco maciço | recusado: "parede nasceu do nada" |
| 2026-10-03 a 10-05 | rombo de borda **rasgada**, cercado de cone | recusado: "não saiu dessa fase" |
| hoje | vão aberto com **parede de verdade** em volta | é o pedido |

O que faltava não era a geometria — o buraco já era um vão com borda — e sim a borda **ser parede**. A versão rasgada desenhava chapa arrancada, com recorte aleatório ao longo da divisa, e isso lê como obra que travou. Hoje `_pintar_buraco()` monta a silhueta sólida (anel de `RECUO` nos lados que encostam na estação, aberto nos que continuam noutro buraco) e entrega a `_perfil_de_parede()` — a **mesma** função que pinta o casco. Não é um perfil parecido: é o mesmo contorno, a mesma banda clara, a mesma linha escura.

O desenho usa seis camadas, nessa ordem: `Piso`, `Borda` (sombra de contato), `Obra` (canteiro, com colisão), `Casco`, `Detalhes` (canos, luminárias e os cones de beira) e `Aberturas` (portas e portões por cima). O tile de casco e o de borda não são escolhidos por regra de autotile: cada um é um atlas de 256 células **indexado por uma máscara de 8 bits da vizinhança**, e o script lê `Vector2i(mascara % 16, mascara / 16)` direto. Por isso a planta pode ter qualquer formato. Buraco, cones e marcação usam o mesmo princípio com 4 bits, só os lados cardeais.

**`eh_interior()` e `eh_andavel()` não são a mesma pergunta.** Obra conta como interior (o casco nasce junto com o canteiro, para o jogador ver o contorno do que mandou construir) mas em geral não como andável. A exceção é o canteiro de **porta**: porta não colide nem pronta nem em obra, e se colidisse, instalar uma porta num vão fecharia a passagem por vinte segundos — e a validação de ligação recusaria justamente a porta que destrava o canto. A validação usa `eh_andavel`.

A ordem dos bits está em `DIRECOES`, em `mapa_estacao.gd` **e** em `tools/gerar_tiles_estacao.py`. Mudar de um lado só embaralha o atlas inteiro em silêncio — e o resultado ainda parece plausível na tela.

### Enfeite do casco

Canos, caixa de junção e luminária interna ficam na camada `Detalhes`, sem colisão: são enfeite e não empurram ninguém.

O tubo tem raio 11 com eixo em 13, então **não cabe no recuo de 20 px** — ele monta por cima da borda externa do casco de propósito, invadindo uns 4 px da banda clara. É isso que faz a tubulação ler como peça parafusada no casco em vez de desenho flutuando ao lado dele.

O cilindro é pintado em **três faixas chapadas** mais um fio de brilho, não num degradê contínuo: o degradê saiu lavado de branco, e pixel art de tubo lê melhor em bandas. O raio tem uma ondulação senoidal de **período 64** — qualquer outro período quebraria a emenda entre duas células da mesma corrida. A ferrugem é escorrido fino na metade de baixo, nunca mancha redonda: mancha vira lama, e fica a 8 px das bordas para não denunciar a divisa entre tiles.

A distribuição é calculada em `_pintar_detalhes()`. Só entram paredes **retas** — célula de casco com exatamente um lado virado para o espaço; canto exigiria curva de tubulação que não existe no atlas. As células retas viram corridas percorridas no sentido horário (`SENTIDO_CORRIDA`), e cada corrida sorteia o próprio enfeite com semente derivada da célula inicial, para que reconstruir no meio de uma obra não remexa o resto da estação.

As quatro rotações do atlas saem de girar o desenho base (espaço ao norte). É por isso que o sentido da corrida importa: girar o tile gira junto o lado em que cai a ponta do cano. A luminária só entra onde o outro lado da parede é piso de verdade.

`CHANCE_CANO`, `CHANCE_CAIXA` e `CHANCE_LUZ` regulam a densidade. Subir demais some com a silhueta da estação.

### Cones na beira do vazio

Todo piso cuja célula vizinha **ainda não tem chão** ganha faixa de perigo pintada e um cone, na camada `Detalhes`, indexado por uma máscara de 4 bits. Isso é `falta_chao()`: canteiro de **piso**, subindo ou descendo, em qualquer estágio. Canteiro de parede e de porta não conta — sobe sobre chão que já existe, e não há vácuo atrás dele.

A marca vale a escada inteira e sai só quando a célula vira piso — ou, numa demolição, quando o buraco se fecha com sua parede. No `ACABAMENTO` a chapa já está assentada, mas ninguém pisa nela: a cerca acompanha a obra, não a aparência do vão.

**A marca é sempre temporária**, e buraco pronto não leva cone. Parece contradizer o pedido original ("cone onde o piso encosta no vácuo"), mas não encosta: a borda do buraco é parede, e ela fica entre o chão e o vazio. Cone em buraco acabado também usaria a mesma listra da fita de obra, e era justamente isso que fazia um vão pronto parecer canteiro parado.

A colisão já barra a passagem; o cone existe porque **colisão não avisa**. Sem a marca, a única forma de descobrir o canteiro é esbarrar nele.

A faixa é listra a 45° com período 16 — divide 64, então atravessa a emenda entre duas células sem degrau — e começa a 9 px da borda, depois da sombra de contato, que alcança 7: encostada nela a faixa some no escuro. Com mais de um lado aberto fica **um cone só, no meio**: dois cones de lados diferentes caíam quase no mesmo pixel e saíam grudados.

### Portas

O atlas de porta tem quatro segmentos — inteira, metade A, metade B e meio — vezes fechada e aberta, vezes duas orientações. `_pintar_porta()` escolhe o segmento olhando se a célula vizinha **na linha da parede** também é porta. Sem isso um vão de duas células sai com duas emendas âmbar, uma no meio de cada célula, e lê como duas portinhas em vez de uma porta larga.

Pelo mesmo motivo as células encostadas formam um vão único em `_vaos`, e abrem juntas por proximidade: meia folha abrindo de cada vez lê como defeito.

**Os scripts de `tools/` são geradores e testes, não código de jogo.** `construir_estacao.gd` regenera o `.tres` (inclusive os 256 polígonos de colisão do casco) e o esqueleto de nós do `.tscn`; a planta **não está mais lá**, e sim nas constantes de `mapa_estacao.gd`. Os `.py` convertem ou desenham os atlas de `assets/`. Reexecutar um deles sobrescreve a saída.

`RECUO`, em `gerar_tiles_estacao.py`, é o quanto o casco recua da borda da célula no lado virado para o espaço — é o único número que controla a espessura aparente da parede. `construir_estacao.gd` repete o valor para a colisão acompanhar a arte: mudar um exige mudar o outro.

Mecânica de jogo (módulos como entidade, energia, naves, regiões) continua **sem nenhuma implementação**. O que existe é protótipo de movimentação, cenário e construção livre de planta.

### A porta é peça, não pincel

A porta ocupa **exatamente duas células encostadas**, e a regra mora em `MapaEstacao.pode_porta_em()`, não só no cursor: meia porta não fecha vão nenhum e duas metades soltas em pontos diferentes não são porta. Quem chamar `aplicar(Acao.PORTA, ...)` com outra coisa leva recusa — teste e captura inclusive.

O botão direito **gira a peça de 90 em 90** (`_rotacao`, índice de `CARDEAIS`): são quatro posições, porque o que gira é para que lado a segunda célula aponta a partir do cursor. Com a porta na mão o botão direito não remove — peça de tamanho fixo não tem arrasto, e girar é a única escolha que sobra.

A prévia é a **própria arte do tile**, meio transparente, nas duas células. É a arte e não um retângulo porque a peça tem orientação: duas células realçadas não dizem se a folha corre deitada ou em pé.

`linha_da_porta()` escolhe a linha do atlas pela **metade vizinha**, e só na falta dela lê o eixo do mapa. Uma porta solta no meio da sala tem piso dos quatro lados, e o mapa sempre responderia "deitada" — a porta em pé que o jogador girou sairia desenhada atravessada.

A porta é recusada na célula do jogador, fora da estação, e em cima de portão, obra ou outra porta.

### Modo de construção

`TAB` (ou `B`) entra; `TAB`, `Enter` ou o botão **Confirmar** saem deixando a planta de pé. `ESC` ou **Cancelar** saem **desfazendo tudo** que foi feito desde que o modo abriu. Dentro dele o jogador fica travado e a câmera é livre.

| Tecla | Ação |
|---|---|
| `1`–`5` | Expandir, Parede, Porta, Portão de nave, Demolir |
| Botão direito, com a Porta | Gira a peça 90° |
| `Enter` | Confirma e sai |
| `ESC` | Cancela, desfaz e sai |
| Botão esquerdo | Clique seco aplica uma célula; **arrastar aplica o retângulo** entre âncora e cursor |
| Botão direito | Demole, qualquer que seja a ferramenta — também em retângulo. Exceto com a Porta, que gira |
| Roda | Zoom entre 0,25 e 1,5 |
| `WASD` / setas | Move a câmera |

Cada botão da barra tem um ícone de `assets/interface/ferramentas.png`, gerado por `icones()` no mesmo script dos tiles.

**Confirmar e cancelar.** `_entrar()` guarda um `MapaEstacao.instantaneo()` — células, aberturas, estágios e relógios — e `cancelar()` o devolve com `restaurar()`. Existe porque o jogador precisa poder experimentar uma planta inteira antes de aceitá-la: sem isso o único caminho de volta seria remover célula por célula, e a expansão nem tem volta exata, já que remover piso abre vácuo em vez de devolver o casco. A barra mostra quantas células mudaram (`diferencas()`), e **Cancelar fica apagado enquanto não há o que desfazer** — botão sempre aceso sugere que sair por ali custa alguma coisa, e não custa.

Nada disso é irreversível antes de confirmar porque a obra só começa a correr ao sair: ver abaixo.

**Tudo é aplicado em lote por `MapaEstacao.aplicar()`**, que é tudo-ou-nada: ele guarda uma cópia do mapa, executa, valida, e desfaz se o resultado não servir. É em lote porque regra por célula não dá conta de "o retângulo inteiro precisa encostar na estação", e um retângulo meio aplicado deixaria a estação num estado que ninguém pediu. `MAXIMO_POR_ARRASTO` (2500 células) impede um arrasto distraído com a vista afastada.

A área é lida **antes** de zerar `_arrastando`, em `_unhandled_input`. Zerar antes encolhia todo arrasto para a única célula sob o cursor na hora de soltar — que quase sempre é vácuo solto, e a recusa saía como "só encostado na estação" em cima de um arrasto perfeitamente válido.

Os métodos `pode_*` continuam existindo, mas **só para colorir o cursor**: eles testam uma célula. O cursor fica verde quando *alguma* célula da área aceita a ferramenta, porque é isso que `aplicar()` vai fazer — julgar só a âncora pintaria de vermelho o arrasto que começa no vazio e termina encostando na estação, que é o mais comum.

As regras de hoje:

- **Expandir** abre canteiro de obra no que é vácuo ou casco, e **ignora o que já está construído** — selecionar uma área metade cheia constrói só a metade vazia. Piso, parede, porta e portão sobrevivem ao retângulo: um arrasto largo não pode varrer a estação existente sem querer. O canteiro só cresce a partir do que já existe, mas o teste de encosto é refeito em rodadas, então a segunda fila encosta na primeira e um retângulo fundo entra inteiro de uma vez.
- **Parede** só em piso, e também em área. Abre canteiro; não entrega parede na hora.
- **Porta** é peça de duas células (acima), entra em parede **e direto no piso** — a célula já vira o batente. Sem isso o jogador caía num ciclo: não podia erguer a parede que fecharia um canto, porque isolaria a estação, e não podia pôr a porta que resolveria, porque ali ainda não havia parede.
- **Portão** só em parede com piso dentro e espaço fora.
- **Demolir** desmonta um degrau por vez e **leva o mesmo tempo que construir**: parede, porta e portão viram piso; piso sai do mapa. Demolir o chão no meio de uma sala deixa um **vão aberto para o espaço com parede em volta**, não um bloco maciço nem um rombo sem acabamento. Nunca constrói nada. No casco automático e no vácuo não acontece nada. Sobre um canteiro, demolir **cancela o trabalho** em vez de abrir outro — ver abaixo.
- Nada pode isolar parte da estação do jogador nem tirar o chão de onde ele está.

### Obra: construir leva tempo

Nenhuma das três construções entrega a peça na hora: todas abrem um **canteiro**, que passa por estágios de `SEGUNDOS_POR_ESTAGIO` (10 s) cada. `_alvos` guarda o que cada célula vai entregar — `PISO`, `MURO` ou `PORTA` — e `ESTAGIOS_ATE` diz quantos estágios cada alvo percorre.

| Alvo | Estágios | Por quê |
|---|---|---|
| `PISO` | 3 | nasce do nada e precisa de chão |
| `MURO`, `PORTA` | 2 | sobem sobre piso que já existe: demarcar e erguer bastam |

**Parede e porta em obra** continuam com o piso desenhado por baixo. No `DEMARCADO` é a fita de obra no chão (`marcacao.png`, 16 variações pela máscara dos quatro lados, para uma parede de seis células sair com uma fita só em volta das seis). No `ESTRUTURA` entra a peça meio pronta, e a fita continua **por cima**, na camada `Detalhes`, agora sem a sombra de área reservada — a linha 1 do mesmo atlas.

A parede meio erguida reaproveita a **grade de vigas do canteiro de piso**: é estrutura antes de chapa, que é exatamente o que está acontecendo. Desenhá-la como a parede pronta, só que apagada, não funciona sobre piso — foi tentado, e o bloco escuro da parede interna ficou idêntico à sombra da fita. Contra o vazio o apagado lê; contra o piso, não.

Só a fita de **parede** colide. A de porta usa `ALT_MARCACAO_LIVRE`, a mesma arte sem polígono.

**Demolir é o mesmo canteiro andando para trás.** `_demolindo` marca quais correm ao contrário: a peça começa no último degrau e desce um por vez, com o mesmo desenho que teve ao subir, até sumir. Parede, porta e portão param no piso; o piso abre vácuo. É por isso que `_alvos` guarda *a peça de que o canteiro trata*, e não "o que vai ser entregue": numa demolição a peça é o que está sendo desmontado.

Enquanto desce, a peça continua colidindo como colidia pronta — é o que mantém a validação de ligação honesta. Demolir o chão de um corredor é recusado na hora se isso partir a estação em duas, e não vinte segundos depois.

`_cancelar_canteiro()` interrompe o trabalho e devolve a célula ao estado anterior a ele: construção cancelada tira o que nem chegou a existir, demolição cancelada **recompõe a peça inteira**. É isso que a ferramenta Demolir faz quando cai sobre um canteiro — não faz sentido desmontar degrau por degrau o que ainda não foi montado, e é assim que o jogador interrompe uma demolição de que se arrependeu depois de já ter confirmado a planta.

A expansão de piso segue com os três estágios de sempre:

| Estágio | Leitura | Tile |
|---|---|---|
| `DEMARCADO` | área marcada no vazio, nada construído | `demarcacao.png`, 256 variações por máscara |
| `ESTRUTURA` | vigas fechando a célula, ainda se vê o espaço | `obra.png` linha 0 |
| `ACABAMENTO` | chapa assentada, ainda crua | `obra.png` linha 1 |

O `DEMARCADO` **não sai do mesmo atlas que os outros dois**: é indexado pela máscara de 8 bits da vizinhança, como o casco e a borda, e por isso o trilho âmbar corre só na divisa do canteiro. A primeira versão marcava célula por célula, com cantoneira nos quatro cantos de cada uma; as pontas de quatro vizinhas se encontravam e nascia um **`+` âmbar no meio do nada**, que foi o que o jogador recusou. Marca de área se indexa pela vizinhança; marca por célula vira padrão de papel de parede.

**A parede nasce apagada junto com o canteiro.** `_nasceu_da_obra()` reconhece o casco que só existe por causa de uma obra aberta — encosta em obra e em nenhum piso — e o desenha com `ALT_CASCO_EM_OBRA`, uma alternativa do mesmo tile com `modulate` translúcido. É alternativa, e não atlas próprio, porque o desenho não muda: o que muda é o jogador ver as estrelas através da parede enquanto o canteiro não fecha. Pelo mesmo motivo essa parede **não recebe cano nem luminária** — tubulação parafusada numa parede que ainda não existe nega o próprio aviso. Mostrar a parede pronta em volta de uma área que ainda era só baliza foi a outra metade do que ficou estranho.

Esses três **têm colisão**; só o piso final libera passagem. O relógio corre em `_process` e **só fora do modo de construção** — `correr_obras(false)` ao entrar, `true` ao sair — porque o prazo conta a partir do momento em que o jogador salva, não enquanto ele ainda está decidindo a planta.

`forcar_estagio()` e `concluir_obras()` existem para teste e captura não esperarem 30 segundos de relógio real.

Fora do modo, `E` perto do portão do hangar abre ou fecha o grupo inteiro de células contíguas. As portas comuns abrem sozinhas por proximidade e nunca têm colisão.

**O mapa editado não é salvo.** Formato de save é ponto aberto, então reabrir o jogo volta à planta inicial.

### Menu de pausa

`ESC` abre e fecha; os botões são "Voltar ao jogo" e "Sair do jogo". A interface é montada em código, em `menu_pausa.gd`.

O nó usa `PROCESS_MODE_ALWAYS`, não `WHEN_PAUSED`: com `WHEN_PAUSED` o `_unhandled_input` ficava desligado enquanto o jogo rodava, e o `ESC` que deveria **abrir** o menu nunca chegava nele — o menu existia e era inalcançável.

Quem está no modo de construção come o `ESC` antes, em `_input` (que roda antes de todo `_unhandled_input`), então o primeiro `ESC` fecha a construção e só o seguinte abre o menu. Sem isso o menu ganharia o evento, por ser um irmão posterior na árvore.

## Documentos de referência

Consultar antes de propor qualquer coisa. São a fonte de verdade do design.

| Documento | Conteúdo |
|---|---|
| `docs/Historia-completa-Scraptronaut.md` | História completa, nomes definidos, personagens, os dois finais, pontos narrativos abertos |
| `docs/Mecanicas-Scraptronaut.md` | Módulos da estação, matérias-primas, energia/combustível, naves, reserva de retorno, as cinco regiões |
| `docs/Mapa-exploracao-Scraptronaut.md` | Mapa radial: locais, raios e ângulos de cada região; ampliação de 2026-10-02 |
| `docs/Mapa-radial-Scraptronaut.html` | Visualização interativa do mapa radial |
| `docs/Estacao-Lastro-grid-e-modulos.md` | Planta da Lastro em grid: posição e tamanho de cada módulo. É a entrada de `tools/construir_estacao.gd` |

**Não alterar a história nem as mecânicas sem pedido explícito.** Esses documentos registram decisões de uma discussão em andamento; mexer num ponto exige saber se ele era aprovado ou aberto.

## Configuração do projeto (verificada)

`project.godot` — `config_version=5`, `config/features=PackedStringArray("4.7", "GL Compatibility")`.

- **Engine: Godot 4.7** (binário 4.7.2-stable), perfil **GL Compatibility**
- `run/main_scene = "res://cenas/estacao.tscn"`
- `renderer/rendering_method = "gl_compatibility"` (desktop e mobile)
- `rendering_device/driver.windows = "d3d12"`
- `window/stretch/mode = "canvas_items"`, `window/stretch/aspect = "expand"`
- `3d/physics_engine = "Jolt Physics"` — valor padrão do editor; **irrelevante** para um jogo 2D
- Não há `window/size/viewport_width` / `viewport_height` definidos → a resolução base é o padrão do editor (1152×648), que é o tamanho das capturas
- Não há `rendering/textures/canvas_textures/default_texture_filter` definido → **o filtro padrão do projeto continua Linear**

Sobre o filtro: a pixel art não está borrada porque `estacao.tscn` define `texture_filter = 1` (Nearest) nó a nó — nos dois TileMapLayer e nos dois Sprite2D. É contorno, não correção. **Todo nó visual novo precisa repetir esse ajuste** enquanto o padrão do projeto não mudar; esquecer disso é um bug silencioso que só aparece ao olhar a tela.

Esses pontos são lacunas reais, mas a correção é uma **proposta aberta** (ver abaixo), não uma decisão tomada.

## Rodar o jogo sem abrir o editor

O Godot fica em `C:/tools/godot/` (`godot.exe` e `godot_console.exe`, nomes estáveis — para atualizar, trocar os dois arquivos). A pasta está no `PATH` do usuário.

`tools/run.ps1` é o runner; `package.json` só embrulha os modos em `npm run`:

| Comando | O que faz |
|---|---|
| `npm run play` | Abre o jogo numa janela |
| `npm run check` | Smoke test headless; **sai com código 1** se a saída tiver erro de script ou cena |
| `npm run test` | Roda `tools/testar_estacao.gd`: colisão da planta, regras de construção, portão, câmeras. Sai com o número de falhas |
| `npm run build:estacao` | Regenera `recursos/tileset_estacao.tres` e `cenas/estacao.tscn` |
| `npm run shot` | Salva um PNG do viewport em `screenshots/` |
| `npm run shot:long` | Igual, com 180 frames, para a cena assentar antes da captura |
| `npm run shot:planta` | Captura com zoom 0.16, que cabe a estação inteira — é assim que se confere uma mudança de planta |
| `npm run editor` | Abre o editor do Godot no projeto |

Flags livres exigem chamar o script direto: `./tools/run.ps1 -Screenshot -Output screenshots/station.png -Frames 45`. Parâmetros: `-Scene`, `-Headless`, `-Screenshot`, `-Script`, `-Output`, `-Frames`, `-Zoom`, `-Godot`.

A interface do modo de construção só aparece depois de alguém apertar TAB, então `capture.gd` não a alcança. Para vê-la: `./tools/run.ps1` e apertar TAB, ou `godot --path . -s tools/capturar_construcao.gd -- <saída> <ferramenta> <x> <y> <zoom> [rx ry rw rh]`, que entra no modo, aponta o cursor para a célula pedida e, com o retângulo opcional, ainda expande a estação antes de capturar.

Com ferramenta `>= 0` o retângulo entra **pela mesma função que o mouse usa**, já dentro do modo, então a captura mostra a barra como o jogador a veria — com o contador de alterações e o botão de cancelar aceso. Ferramenta de peça fixa ignora o tamanho do retângulo e usa o canto dele como célula do cursor; com **dois** opcionais, o primeiro vira a rotação da peça em vez de fingir um arrasto. Ferramentas negativas não entram no modo: `-1` põe o **jogador** na célula pedida e captura o jogo normal — é assim que se confere porta abrindo por proximidade, que a câmera parada de `capture.gd` nunca mostra; `-2` faz o mesmo e ainda abre o menu de pausa.

Os quatro argumentos opcionais são um retângulo onde a **mesma ferramenta** é aplicada antes da captura, então dá para montar qualquer cena: expandir, erguer parede, ou abrir um vão com a ferramenta 5. Com ferramenta negativa o retângulo é sempre expansão, aplicada direto no mapa. Um décimo argumento congela a obra num estágio (0, 1 ou 2). Com apenas **dois** opcionais o script finge um arrasto em curso, que é o único jeito de ver o retângulo de seleção desenhado.

Três armadilhas já encontradas, todas tratadas no script:

- **`npm run` engole flags** no estilo `-Frames` e repassa só o valor solto, que cairia como nome de cena e rodaria errado em silêncio. Por isso `run.ps1` recusa um `-Scene` que não termine em `.tscn`, e por isso as variantes viraram scripts nomeados.
- **`-Screenshot` não combina com `-Headless`**: sem janela o renderizador é dummy e o PNG sai em branco. O script bloqueia a combinação.
- **PowerShell 5.1 embrulha o stderr de exe nativo em `ErrorRecord`**, o que viraria erro terminante sob `$ErrorActionPreference = "Stop"` antes de qualquer diagnóstico. O modo headless relaxa a preferência só em volta da chamada.

A captura é o único jeito de eu **ver** o jogo — a CLI do Godot não tira screenshot sozinha; `tools/capture.gd` instancia a cena, espera N frames, aguarda `RenderingServer.frame_post_draw` e salva o PNG. `screenshots/` está no `.gitignore`.

## Decisões aprovadas

Tratar como fixo. Mudanças aqui exigem decisão explícita do usuário.

**Técnico**
- Engine Godot; direção visual 2D pixel art top-down em três quartos
- Linguagem: GDScript
- Jogo de engine, sem obrigação de rodar no navegador
- Steam é possibilidade futura, sem compromisso de lançamento

**Narrativa** — tudo em `Historia-completa-Scraptronaut.md` sob "Nomes definidos" e a sequência principal dos capítulos:
- Nomes: Orbita, Morgon's, Lastro, Aurora, Asterianos (civilização e planeta), Lira/Miro, Nilo, NILO 2, Adonus, Hera, Bobobacau, Dricono, Macrovolvulador-extremamicrobacteriano, Terra
- A mãe do protagonista permanece sem nome; o funcionário da corporação e a lavanderia também
- Dois finais: atravessar a fenda ou ficar na Lastro
- A finalidade do Macrovolvulador nunca é revelada, em nenhum final

**Mecânicas**
- Estação inicial com 6 módulos; computador de Nilo, armazém e prensa começam quebrados
- 11 módulos aprovados (pátio central, corredor, armazém, hangar, oficina de desmontagem, prensa, refinaria energética, fábrica de eletrônicos, habitação, módulo de Dricono, módulo de estabilização)
- Energia como **unidade única**; combustível em três estágios: bruto, refinado, concentrado
- 5 naves com especialidades distintas (sucateira, cargueira, exploradora, planetária, de travessia)
- **Reserva de retorno**: a nave reserva combustível para voltar à Lastro e inicia retorno automático ao atingir o limite — sem punição, sem perda de carga. Três estados de painel: Seguro / Reserva próxima / Limite atingido
- **5 regiões de alcance**; a expansão por distância termina na terceira região planetária (Asterianos). Depois disso a progressão é por profundidade dentro das regiões existentes — **não há sexta região**
- Mapa radial com Lastro no centro; locais posicionados por raio + ângulo (norte = 0°, sentido horário)

## Propostas abertas

Não tratar como design nem implementar sem decisão. Lista completa em "Próximas definições" (`Mecanicas-`) e "Pontos ainda abertos para desenvolvimento" (`Historia-`).

**Conflito aberto entre o código e o design**
- `docs/Estacao-Lastro-grid-e-modulos.md` define interior de 10×10, módulo de 12×12 e passo de encaixe de 11 células. O mapa implementado é **livre, célula a célula**, a pedido explícito do usuário em 2026-10-03. As duas coisas não convivem: ou o documento passa a descrever construção livre, ou o código volta a encaixar módulos. **Nada foi decidido, e o documento não foi alterado.** O que sobreviveu da planta aprovada: célula de 64 px, parede de uma célula, porta comum de duas células e portão do hangar de cinco
- `scripts/portao_hangar.gd` e `assets/tiles/` (`parede.png`, `porta.png`, `porta_vertical.png`, `portao_hangar.png`, `piso.png`) ficaram **sem uso**: a lógica do portão virou tile e a arte virou `assets/tiles/estacao/`. `tools/gerar_tiles.py` ainda os regenera. Apagar ou manter é decisão pendente

**Técnico**
- Resolução base do viewport (p. ex. 640×360) e modo de stretch definitivo — para pixel art a documentação do Godot 4.7 recomenda stretch `viewport` com scale mode `integer`; o projeto hoje usa `canvas_items` + `expand`
- Adotar `Nearest` como filtro de textura padrão do projeto, substituindo o `texture_filter` repetido nó a nó em `estacao.tscn`
- Remover ou manter as configurações 3D herdadas do editor
- Autoloads, arquitetura de cenas e formato de save — nada decidido. A estrutura de pastas já se firmou na prática (`cenas/`, `scripts/`, `assets/`, `recursos/`, `tools/`, `docs/`), mas nunca foi decidida formalmente
- O que entra no versionamento: `docs/`, e também `assets/` e `recursos/`, que são gerados por `tools/` e poderiam ser reconstruídos em vez de comitados
- Se o protótipo atual (`estacao.tscn` e `scripts/`) é base para o jogo ou descartável

**Design**
- Produtos que cada módulo fabrica ou recupera; moldes, receitas e aplicações dos materiais
- Rendimentos energéticos e concentrações; nome e natureza do recurso energético
- Capacidades, custos, níveis e melhorias de naves e módulos
- Regras de imprevistos, resgates e dívidas; papel de Bobobacau nos resgates
- Materiais e descobertas de cada região; condições de acesso; distâncias reais de combustível
- Nome do material Asteriano
- Identidades de P1–P9, D1–D15, C1–C3, E1–E4, S1–S4, N1 e das duas luas
- Aparência de Lira/Miro e como a escolha entre as duas versões é apresentada
- Cronologia da jornada em relação ao prazo de noventa dias da lavanderia
- Variações dos epílogos conforme vínculos e decisões do jogador

## Trabalhando com Godot 4.7 + GDScript

- Confirmar a API na documentação **4.7** (Context7: `/websites/godotengine_en_4_7`) antes de escrever código. Não assumir assinaturas de memória nem reaproveitar padrões de Godot 3.x
- `project.godot` é editado pelo editor. Alterar à mão funciona, mas o editor pode reescrever e reordenar o arquivo
- `.godot/` está no `.gitignore` — é cache local e nunca deve ser comitado
- Scripts `.gd` referenciados por cenas ou recursos precisam de um `.uid` companheiro gerado pelo editor (Godot 4.4+). Criar um `.gd` fora do editor exige abrir o projeto para que o `.uid` apareça. **Exceção:** script rodado via `-s` (como `tools/capture.gd`) é carregado por caminho e funciona sem `.uid`
- Depois de mexer em script ou cena, rodar `npm run check`: ele pega erro de parse e de carregamento sem abrir o editor. Para conferir o resultado visual, `npm run shot` e olhar o PNG
- O perfil **GL Compatibility** limita a renderização: sem SDFGI, sem volumetric fog, e vários parâmetros de `CanvasItem`/shader se comportam de forma diferente do Forward+. Verificar o suporte antes de propor efeitos visuais
- `.gitattributes` normaliza EOL para LF; `.editorconfig` define UTF-8. GDScript usa **tabs** para indentação (padrão do estilo oficial)
- Ao criar cenas e recursos, preferir o editor quando a estrutura importa; `.tscn` escrito à mão quebra com facilidade por causa de `uid://` e `load_steps`

## Convenções de código

Seguem o guia de estilo oficial do GDScript, e o código existente em `scripts/` já as aplica.

- Arquivos e pastas: `snake_case`. Classes e nós: `PascalCase`. Funções e variáveis: `snake_case`. Constantes e enums: `CONSTANT_CASE`
- Membros privados com prefixo `_`
- Tipagem estática sempre que possível (`var carga: int = 10`, `func atracar(nave: Nave) -> void:`)
- Ordem no script: `class_name`, `extends`, docstring, `signal`, `enum`, `const`, `@export`, variáveis, `_init`, `_ready`, callbacks da engine, métodos públicos, métodos privados
- Comentário `##` explica **por que**, não o quê — ver `jogador.gd`, onde o comentário justifica por que o intervalo entre piscadas é sorteado em vez de fixo

**Idioma — a divisão é por público, não por tipo de arquivo:**

| Onde | Idioma |
|---|---|
| Textos de interface e diálogo | Português, como os documentos de design |
| Código de jogo (`scripts/`, `cenas/`) — identificadores e comentários | Português (`jogador.gd`, `velocidade`, `_olhos_fechados`) |
| Tooling de execução (`tools/run.ps1`, `tools/capture.gd`, `package.json`) | Inglês |

Os geradores em `tools/` (`construir_estacao.gd`, `gerar_*.py`) ainda estão em português e não foram renomeados — `construir_estacao.gd` tem `.uid` e é referenciado pelo fluxo de geração, então renomear exige cuidado. Padronizar isso é ponto aberto.

## Como responder a pedidos

1. Localizar o assunto nos documentos de `docs/` antes de responder
2. Dizer se o ponto é **aprovado** ou **aberto**. Se aberto, apresentar como proposta e esperar decisão
3. Não implementar mecânica, não criar cena, não alterar a narrativa sem pedido explícito
4. Se um pedido conflita com uma decisão aprovada, apontar o conflito antes de executar
5. Ao mexer em código ou cena, verificar com `npm run check` antes de dizer que está pronto — e com `npm run shot` quando a mudança for visual
