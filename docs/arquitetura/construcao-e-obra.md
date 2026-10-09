# Modo de construção e obra

`scripts/build_mode.gd` (planejar) e a parte de canteiros de
`scripts/station_map.gd` (executar).

Carregar para mexer em ferramentas, cursor, arrasto, validação em lote,
confirmar/cancelar, estágios de obra ou demolição. O custo em energia e a
picareta estão em [trabalho-energia-e-dia.md](trabalho-energia-e-dia.md).

## Modo de construção

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

Cada botão da barra tem um ícone de `assets/interface/tools.png`, gerado por `icones()` no mesmo script dos tiles.

**Confirmar e cancelar.** `_enter()` guarda um `StationMap.snapshot()` — células, aberturas, estágios e trabalho batido — e `cancel()` o devolve com `restore()`. Existe porque o jogador precisa poder experimentar uma planta inteira antes de aceitá-la: sem isso o único caminho de volta seria remover célula por célula, e a expansão nem tem volta exata, já que remover piso abre vácuo em vez de devolver o casco. A barra mostra quantas células mudaram (`differences()`), e **Cancelar fica apagado enquanto não há o que desfazer** — botão sempre aceso sugere que sair por ali custa alguma coisa, e não custa.

Nada disso é irreversível antes de confirmar porque **confirmar não constrói nada**: a planta aceita é só a lista do que há para fazer, e nenhum canteiro anda enquanto ninguém for até lá bater nele. Ver abaixo.

**Tudo é aplicado em lote por `StationMap.apply()`**, que é tudo-ou-nada: ele guarda uma cópia do mapa, executa, valida, e desfaz se o resultado não servir. É em lote porque regra por célula não dá conta de "o retângulo inteiro precisa encostar na estação", e um retângulo meio aplicado deixaria a estação num estado que ninguém pediu. `MAX_PER_DRAG` (2500 células) impede um arrasto distraído com a vista afastada.

A área é lida **antes** de zerar `_dragging`, em `_unhandled_input`. Zerar antes encolhia todo arrasto para a única célula sob o cursor na hora de soltar — que quase sempre é vácuo solto, e a recusa saía como "Só é possível estender o piso a partir da estação" em cima de um arrasto perfeitamente válido.

**A recusa sai num balão ancorado na seleção**, não no painel das ferramentas. `_announce()` guarda o motivo devolvido por `apply()`, põe a ponta do rabo no meio da borda de cima da área tentada (`_refusal_point`, em coordenada de mundo) e mostra um `SpeechBubble` na mesma `CanvasLayer` dos painéis. É o balão da fala do personagem com a linha em vermelho — a cor do retângulo recusado embaixo dela —, e não caixa nova: o modo tem uma interface só.

Ela morava no rodapé do painel até 2026-10-06, e saiu de lá a pedido. Lá a recusa ficava longe do que reclamava: o jogador clica numa célula do outro lado da tela e o aviso acende num canto, sem nada ligando uma coisa à outra. O balão tem rabo, aponta, e responde "qual quadrado está errado" sem precisar dizer.

O ponto é **guardado, e não recalculado a cada quadro**: a recusa é de uma tentativa que já passou, e o cursor anda depois dela — o balão tem de ficar apontando para onde o clique foi dado. Como ele mora numa `CanvasLayer` e só a posição vem do mundo, `_process()` o recoloca depois de mover a câmera.

A recusa também **tem prazo** (`REFUSAL_DURATION`, 3 s), que a linha no painel não tinha. É consequência da mudança de lugar: dentro da chapa uma linha parada era só uma linha parada, mas em cima do mapa, presa na célula, o que ninguém apaga vira obstáculo — o jogador já corrigiu a seleção e continua com o aviso cobrindo o casco atrás dela. Trocar de ferramenta, girar a peça, acertar a aplicação ou sair do modo também a calam.

Os métodos `pode_*` continuam existindo, mas **só para colorir o cursor**: eles testam uma célula. O cursor fica verde quando *alguma* célula da área aceita a ferramenta, porque é isso que `apply()` vai fazer — julgar só a âncora pintaria de vermelho o arrasto que começa no vazio e termina encostando na estação, que é o mais comum.

As regras de hoje:

- **Expandir** abre canteiro de obra no que é vácuo ou casco, **derruba a divisória interna** que encontrar, e **ignora o resto do que já está construído** — selecionar uma área metade cheia constrói só a metade vazia. O canteiro só cresce a partir do que já existe, mas o teste de encosto é refeito em rodadas, então a segunda fila encosta na primeira e um retângulo fundo entra inteiro de uma vez.

  **A divisória é a única peça posta que o retângulo derruba, e isso mudou em 2026-10-06, a pedido.** Antes ela era recusada com um "demola para virar piso", e o jogador tinha de trocar para a Demolir e clicar de novo no mesmo lugar — duas ferramentas para dizer uma coisa só. Pedir chão onde há parede já diz o que ele quer. Ela não some de graça: vira **canteiro de demolição**, idêntico ao que a Demolir abriria — mesmo alvo, mesma escada ao contrário, mesmas marteladas. O canteiro é aberto *antes* das rodadas de encosto, porque obra já conta como interior: assim o vácuo encostado naquela parede entra na mesma aplicação em vez de ficar para uma segunda.

  **Piso, porta e portão continuam sobrevivendo ao retângulo.** Porta e portão são passagem: varrê-los num arrasto largo partiria a estação em pedaços sem o jogador ter pedido, e quem quer uma porta fora usa a Demolir.
- **Parede** só em piso, e também em área. Abre canteiro; não entrega parede na hora.
- **Porta** é peça de duas células (acima), entra em parede **e direto no piso** — a célula já vira o batente. Sem isso o jogador caía num ciclo: não podia erguer a parede que fecharia um canto, porque isolaria a estação, e não podia pôr a porta que resolveria, porque ali ainda não havia parede.
- **Portão** só em parede com piso dentro e espaço fora.
- **Demolir** desmonta um degrau por vez e **custa o mesmo trabalho que construir**: parede, porta e portão viram piso; piso sai do mapa. Demolir o chão no meio de uma sala deixa um **vão aberto para o espaço com parede em volta**, não um bloco maciço nem um rombo sem acabamento. Nunca constrói nada. No casco automático e no vácuo não acontece nada. Sobre um canteiro, demolir **cancela o trabalho** em vez de abrir outro — ver abaixo.
- Nada pode isolar parte da estação do jogador nem tirar o chão de onde ele está.

## Obra: construir custa trabalho

Nenhuma das três construções entrega a peça na hora: todas abrem um **canteiro**, que percorre estágios. `_targets` guarda o que cada célula vai entregar — `FLOOR`, `WALL` ou `DOOR` — e `STAGES_TO` diz quantos estágios cada alvo percorre.

**Não há relógio.** Até 2026-10-05 cada estágio durava `SEGUNDOS_POR_ESTAGIO` e passava sozinho enquanto o jogador fazia outra coisa; hoje um estágio só fecha quando alguém bate `WORK_PER_CELL / STAGES_TO` de trabalho naquela célula, com `StationMap.work()`. `_work` guarda quanto já foi batido no estágio corrente, e é ele que `snapshot()` copia e `restore()` devolve.

| Alvo | Estágios | Por quê |
|---|---|---|
| `FLOOR` | 3 | nasce do nada e precisa de chão |
| `WALL`, `DOOR` | 2 | sobem sobre piso que já existe: demarcar e erguer bastam |

**Parede e porta em obra** continuam com o piso desenhado por baixo. No `MARKED` é a fita de obra no chão (`tape.png`, 16 variações pela máscara dos quatro lados, para uma parede de seis células sair com uma fita só em volta das seis). No `STRUCTURE` entra a peça meio pronta, e a fita continua **por cima**, na camada `Details`, agora sem a sombra de área reservada — a linha 1 do mesmo atlas.

A parede meio erguida reaproveita a **grade de vigas do canteiro de piso**: é estrutura antes de chapa, que é exatamente o que está acontecendo. Desenhá-la como a parede pronta, só que apagada, não funciona sobre piso — foi tentado, e o bloco escuro da parede interna ficou idêntico à sombra da fita. Contra o vazio o apagado lê; contra o piso, não.

Só a fita de **parede** colide. A de porta usa `ALT_TAPE_NO_COLLISION`, a mesma arte sem polígono.

**Essa alternativa é translúcida** (`TAPE_OVER_PIECE_COLOR`, 45%), e é a mesma que o canteiro desenha por cima de peça em obra. A fita é uma faixa larga nos quatro lados da célula: opaca, ela comia o quadrado inteiro, e quem batia numa obra não via a peça andar de um estágio para o outro — foi o que o jogador apontou em 2026-10-05. A base continua opaca, porque no primeiro degrau de parede não há nada por baixo para deixar ver.

**Demolir é o mesmo canteiro andando para trás.** `_demolishing` marca quais correm ao contrário: a peça começa no último degrau e desce um por vez, com o mesmo desenho que teve ao subir, até sumir. Parede, porta e portão param no piso; o piso abre vácuo. É por isso que `_targets` guarda *a peça de que o canteiro trata*, e não "o que vai ser entregue": numa demolição a peça é o que está sendo desmontado.

Enquanto desce, a peça continua colidindo como colidia pronta — é o que mantém a validação de ligação honesta. Demolir o chão de um corredor é recusado na hora se isso partir a estação em duas, e não depois que o trabalho já foi gasto.

`_cancel_site()` interrompe o trabalho e devolve a célula ao estado anterior a ele: construção cancelada tira o que nem chegou a existir, demolição cancelada **recompõe a peça inteira**. É isso que a ferramenta Demolir faz quando cai sobre um canteiro — não faz sentido desmontar degrau por degrau o que ainda não foi montado, e é assim que o jogador interrompe uma demolição de que se arrependeu depois de já ter confirmado a planta.

### Expandir sobre o casco não abre buraco

A estação só cresce **atravessando o próprio casco**: o casco é derivado, não é peça, e toda célula vizinha do interior é casco por definição — não há como expandir sem passar por ele. Até 2026-10-05 a célula saía do casco no instante do clique e o primeiro estágio era a baliza desenhada sobre o campo estelar: pedir chão onde havia parede **abria um buraco para o vácuo**, que é o contrário do que se estava pedindo. Foi o que o jogador apontou.

Hoje `_was_wall` marca os canteiros abertos onde já havia parede, e a parede fica de pé até o chão novo ser entregue:

| Estágio | O que se vê |
|---|---|
| `MARKED` | a parede inteira, com a fita de obra por cima |
| `STRUCTURE` | a chapa já assentada, vista **através** da parede que cai |
| `FINISH` | a parede caiu, e só a chapa crua fica |

A chapa entra por baixo já no segundo degrau porque a camada `Construction` desenha **antes** da `Hull`. Sem ela a parede translúcida ficava sobre o campo estelar e lia como o mesmo buraco de antes, só que de porta entreaberta — foi o que a primeira captura mostrou. Com a chapa atrás, translúcido lê como o que é: parede vindo abaixo sobre chão que já está posto.

O casco novo, uma célula adiante, corre ao contrário: nasce translúcido em `_born_from_construction` e só fecha quando o canteiro entrega. Translúcido quer dizer "em trânsito" nos dois sentidos, e **nenhum dos dois momentos abre vão**.

`_was_wall` precisa ser guardado, e não deduzido depois: o que separa casco de vão fechado é o preenchimento de fora para dentro de `_recompute_hull`, e ele já correu quando chega a hora de desenhar. Entra em `snapshot()`, em `restore()` e no desfazer de `apply()`, como os outros dicionários do canteiro. Essas células também ficam fora de `is_missing_floor()`: cone apontando para uma parede inteira não avisa de nada.

A expansão de piso **no vácuo** segue com os três estágios de sempre:

| Estágio | Leitura | Tile |
|---|---|---|
| `MARKED` | área marcada no vazio, nada construído | `marking.png`, 256 variações por máscara |
| `STRUCTURE` | vigas fechando a célula, ainda se vê o espaço | `construction.png` linha 0 |
| `FINISH` | chapa assentada, ainda crua | `construction.png` linha 1 |

O `MARKED` **não sai do mesmo atlas que os outros dois**: é indexado pela máscara de 8 bits da vizinhança, como o casco e a borda, e por isso o trilho âmbar corre só na divisa do canteiro. A primeira versão marcava célula por célula, com cantoneira nos quatro cantos de cada uma; as pontas de quatro vizinhas se encontravam e nascia um **`+` âmbar no meio do nada**, que foi o que o jogador recusou. Marca de área se indexa pela vizinhança; marca por célula vira padrão de papel de parede.

**A parede nasce apagada junto com o canteiro.** `_born_from_construction()` reconhece o casco que só existe por causa de uma obra aberta — encosta em obra e em nenhum piso — e o desenha com `ALT_UNDER_CONSTRUCTION`, uma alternativa do mesmo tile com `modulate` translúcido. É alternativa, e não atlas próprio, porque o desenho não muda: o que muda é o jogador ver as estrelas através da parede enquanto o canteiro não fecha. Pelo mesmo motivo essa parede **não recebe cano nem luminária** — tubulação parafusada numa parede que ainda não existe nega o próprio aviso. Mostrar a parede pronta em volta de uma área que ainda era só baliza foi a outra metade do que ficou estranho.

Esses três **têm colisão**; só o piso final libera passagem.

`force_stage()`, `advance_one_stage()` e `finish_all_construction()` existem para teste e captura não precisarem simular o jogador martelando célula por célula.

Fora do modo, `F` trabalha no canteiro que o personagem **encara** e `E` dorme (perto da cama) ou abre e fecha o portão do hangar (perto dele). O mesmo `E` serve as duas coisas porque elas nunca estão ao alcance ao mesmo tempo: `Work` é **irmão posterior** a `BuildMode` na árvore, recebe o evento primeiro — `_unhandled_input` corre em ordem inversa — e só o consome perto da cama, deixando o resto passar. As portas comuns abrem sozinhas por proximidade e nunca têm colisão.

**O mapa editado não é salvo.** Formato de save é ponto aberto, então reabrir o jogo volta à planta inicial.

