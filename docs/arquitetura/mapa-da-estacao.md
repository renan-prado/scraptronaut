# O mapa da Estação Lastro

Modelo e desenho do mapa: `scripts/station_map.gd`.

Carregar este documento para mexer em planta, casco, tiles, máscaras, portas,
buracos ou nas camadas de desenho. Para o canteiro de obra e o modo de
construção, ver [construcao-e-obra.md](construcao-e-obra.md).

## Como o mapa funciona

A estação **não é mais feita de módulos de 12×12**. `station_map.gd` guarda um dicionário de célula → tipo (`FLOOR`, `WALL`, `DOOR`, `GATE`, `CONSTRUCTION`) e **deriva o casco** a cada reconstrução.

A planta inicial foi **encolhida em 2026-10-05**, a pedido: a topologia é a mesma — seis salas ligadas por corredores com porta, portão do hangar a leste — mas a caixa útil caiu de 44×30 células para 30×21, menos da metade da área. Quem mexer nela mexe junto em `INITIAL_WALLS`, `INITIAL_DOORS`, `INITIAL_GATE`, `INITIAL_PLAYER_CELL`, `BED_CELL` e nas coordenadas de `tools/test_station.gd`, que são escritas à mão.

A derivação tem duas etapas. Toda célula vazia encostada no interior é candidata a parede; as que **alcançam o espaço aberto** viram casco maciço, e as cercadas pela estação viram **buraco** — vão aberto para o espaço, com parede em volta. Um flood-fill de fora para dentro decide qual é qual.

A diferença entre os dois é só o desenho, e ela importa. Três versões foram necessárias para achar o ponto:

| Versão | O que saía ao demolir piso no meio da sala | Veredito |
|---|---|---|
| 2026-10-03, antes | bloco de casco maciço | recusado: "parede nasceu do nada" |
| 2026-10-03 a 10-05 | rombo de borda **rasgada**, cercado de cone | recusado: "não saiu dessa fase" |
| hoje | vão aberto com **parede de verdade** em volta | é o pedido |

O que faltava não era a geometria — o buraco já era um vão com borda — e sim a borda **ser parede**. A versão rasgada desenhava chapa arrancada, com recorte aleatório ao longo da divisa, e isso lê como obra que travou. Hoje `_paint_hole()` monta a silhueta sólida (anel de `RECESS` nos lados que encostam na estação, aberto nos que continuam noutro buraco) e entrega a `_perfil_de_parede()` — a **mesma** função que pinta o casco. Não é um perfil parecido: é o mesmo contorno, a mesma banda clara, a mesma linha escura.

O desenho usa seis camadas, nessa ordem: `Floor`, `Border` (sombra de contato), `Construction` (canteiro, com colisão), `Hull`, `Details` (canos, luminárias e os cones de beira) e `Openings` (portas e portões por cima). O tile de casco e o de borda não são escolhidos por regra de autotile: cada um é um atlas de 256 células **indexado por uma máscara de 8 bits da vizinhança**, e o script lê `Vector2i(mascara % 16, mascara / 16)` direto. Por isso a planta pode ter qualquer formato. Buraco, cones e marcação usam o mesmo princípio com 4 bits, só os lados cardeais.

**`is_interior()` e `is_walkable()` não são a mesma pergunta.** Obra conta como interior (o casco nasce junto com o canteiro, para o jogador ver o contorno do que mandou construir) mas em geral não como andável. A exceção é o canteiro de **porta**: porta não colide nem pronta nem em obra, e se colidisse, instalar uma porta num vão fecharia a passagem até alguém terminar a obra — e a validação de ligação recusaria justamente a porta que destrava o canto. A validação usa `is_walkable`.

A ordem dos bits está em `DIRECTIONS`, em `station_map.gd` **e** em `tools/gerar_tiles_estacao.py`. Mudar de um lado só embaralha o atlas inteiro em silêncio — e o resultado ainda parece plausível na tela.

## Enfeite do casco

Canos, caixa de junção e luminária interna ficam na camada `Details`, sem colisão: são enfeite e não empurram ninguém.

O tubo tem raio 11 com eixo em 13, então **não cabe no recuo de 20 px** — ele monta por cima da borda externa do casco de propósito, invadindo uns 4 px da banda clara. É isso que faz a tubulação ler como peça parafusada no casco em vez de desenho flutuando ao lado dele.

O cilindro é pintado em **três faixas chapadas** mais um fio de brilho, não num degradê contínuo: o degradê saiu lavado de branco, e pixel art de tubo lê melhor em bandas. O raio tem uma ondulação senoidal de **período 64** — qualquer outro período quebraria a emenda entre duas células da mesma corrida. A ferrugem é escorrido fino na metade de baixo, nunca mancha redonda: mancha vira lama, e fica a 8 px das bordas para não denunciar a divisa entre tiles.

A distribuição é calculada em `_paint_details()`. Só entram paredes **retas** — célula de casco com exatamente um lado virado para o espaço; canto exigiria curva de tubulação que não existe no atlas. As células retas viram corridas percorridas no sentido horário (`RUN_DIRECTION`), e cada corrida sorteia o próprio enfeite com semente derivada da célula inicial, para que reconstruir no meio de uma obra não remexa o resto da estação.

As quatro rotações do atlas saem de girar o desenho base (espaço ao norte). É por isso que o sentido da corrida importa: girar o tile gira junto o lado em que cai a ponta do cano. A luminária só entra onde o outro lado da parede é piso de verdade.

`PIPE_CHANCE`, `BOX_CHANCE` e `LIGHT_CHANCE` regulam a densidade. Subir demais some com a silhueta da estação.

## Cones na beira do vazio

Todo piso cuja célula vizinha **ainda não tem chão** ganha faixa de perigo pintada e um cone, na camada `Details`, indexado por uma máscara de 4 bits. Isso é `is_missing_floor()`: canteiro de **piso**, subindo ou descendo, em qualquer estágio. Canteiro de parede e de porta não conta — sobe sobre chão que já existe, e não há vácuo atrás dele.

A marca vale a escada inteira e sai só quando a célula vira piso — ou, numa demolição, quando o buraco se fecha com sua parede. No `FINISH` a chapa já está assentada, mas ninguém pisa nela: a cerca acompanha a obra, não a aparência do vão.

**A marca é sempre temporária**, e buraco pronto não leva cone. Parece contradizer o pedido original ("cone onde o piso encosta no vácuo"), mas não encosta: a borda do buraco é parede, e ela fica entre o chão e o vazio. Cone em buraco acabado também usaria a mesma listra da fita de obra, e era justamente isso que fazia um vão pronto parecer canteiro parado.

A colisão já barra a passagem; o cone existe porque **colisão não avisa**. Sem a marca, a única forma de descobrir o canteiro é esbarrar nele.

A faixa é listra a 45° com período 16 — divide 64, então atravessa a emenda entre duas células sem degrau — e começa a 9 px da borda, depois da sombra de contato, que alcança 7: encostada nela a faixa some no escuro. Com mais de um lado aberto fica **um cone só, no meio**: dois cones de lados diferentes caíam quase no mesmo pixel e saíam grudados.

## Portas

O atlas de porta tem quatro segmentos — inteira, metade A, metade B e meio — vezes fechada e aberta, vezes duas orientações. `_paint_door()` escolhe o segmento olhando se a célula vizinha **na linha da parede** também é porta. Sem isso um vão de duas células sai com duas emendas âmbar, uma no meio de cada célula, e lê como duas portinhas em vez de uma porta larga.

Pelo mesmo motivo as células encostadas formam um vão único em `_gaps`, e abrem juntas por proximidade: meia folha abrindo de cada vez lê como defeito.


## A porta é peça, não pincel

A porta ocupa **exatamente duas células encostadas**, e a regra mora em `StationMap.can_door_at()`, não só no cursor: meia porta não fecha vão nenhum e duas metades soltas em pontos diferentes não são porta. Quem chamar `apply(Action.DOOR, ...)` com outra coisa leva recusa — teste e captura inclusive.

O botão direito **gira a peça de 90 em 90** (`_rotation`, índice de `CARDINALS`): são quatro posições, porque o que gira é para que lado a segunda célula aponta a partir do cursor. Com a porta na mão o botão direito não remove — peça de tamanho fixo não tem arrasto, e girar é a única escolha que sobra.

A prévia é a **própria arte do tile**, meio transparente, nas duas células. É a arte e não um retângulo porque a peça tem orientação: duas células realçadas não dizem se a folha corre deitada ou em pé.

`door_row()` escolhe a linha do atlas pela **metade vizinha**, e só na falta dela lê o eixo do mapa. Uma porta solta no meio da sala tem piso dos quatro lados, e o mapa sempre responderia "deitada" — a porta em pé que o jogador girou sairia desenhada atravessada.

A porta é recusada na célula do jogador, fora da estação, e em cima de portão, obra ou outra porta.

