# Modo de construção e obra

`scripts/modo_construcao.gd` (planejar) e a parte de canteiros de
`scripts/mapa_estacao.gd` (executar).

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

Cada botão da barra tem um ícone de `assets/interface/ferramentas.png`, gerado por `icones()` no mesmo script dos tiles.

**Confirmar e cancelar.** `_entrar()` guarda um `MapaEstacao.instantaneo()` — células, aberturas, estágios e trabalho batido — e `cancelar()` o devolve com `restaurar()`. Existe porque o jogador precisa poder experimentar uma planta inteira antes de aceitá-la: sem isso o único caminho de volta seria remover célula por célula, e a expansão nem tem volta exata, já que remover piso abre vácuo em vez de devolver o casco. A barra mostra quantas células mudaram (`diferencas()`), e **Cancelar fica apagado enquanto não há o que desfazer** — botão sempre aceso sugere que sair por ali custa alguma coisa, e não custa.

Nada disso é irreversível antes de confirmar porque **confirmar não constrói nada**: a planta aceita é só a lista do que há para fazer, e nenhum canteiro anda enquanto ninguém for até lá bater nele. Ver abaixo.

**Tudo é aplicado em lote por `MapaEstacao.aplicar()`**, que é tudo-ou-nada: ele guarda uma cópia do mapa, executa, valida, e desfaz se o resultado não servir. É em lote porque regra por célula não dá conta de "o retângulo inteiro precisa encostar na estação", e um retângulo meio aplicado deixaria a estação num estado que ninguém pediu. `MAXIMO_POR_ARRASTO` (2500 células) impede um arrasto distraído com a vista afastada.

A área é lida **antes** de zerar `_arrastando`, em `_unhandled_input`. Zerar antes encolhia todo arrasto para a única célula sob o cursor na hora de soltar — que quase sempre é vácuo solto, e a recusa saía como "só encostado na estação" em cima de um arrasto perfeitamente válido.

Os métodos `pode_*` continuam existindo, mas **só para colorir o cursor**: eles testam uma célula. O cursor fica verde quando *alguma* célula da área aceita a ferramenta, porque é isso que `aplicar()` vai fazer — julgar só a âncora pintaria de vermelho o arrasto que começa no vazio e termina encostando na estação, que é o mais comum.

As regras de hoje:

- **Expandir** abre canteiro de obra no que é vácuo ou casco, e **ignora o que já está construído** — selecionar uma área metade cheia constrói só a metade vazia. Piso, parede, porta e portão sobrevivem ao retângulo: um arrasto largo não pode varrer a estação existente sem querer. O canteiro só cresce a partir do que já existe, mas o teste de encosto é refeito em rodadas, então a segunda fila encosta na primeira e um retângulo fundo entra inteiro de uma vez. Sobre **divisória interna** ele recusa com "parede: demola para virar piso" — quem quer chão onde há parede usa a Demolir, que devolve piso.
- **Parede** só em piso, e também em área. Abre canteiro; não entrega parede na hora.
- **Porta** é peça de duas células (acima), entra em parede **e direto no piso** — a célula já vira o batente. Sem isso o jogador caía num ciclo: não podia erguer a parede que fecharia um canto, porque isolaria a estação, e não podia pôr a porta que resolveria, porque ali ainda não havia parede.
- **Portão** só em parede com piso dentro e espaço fora.
- **Demolir** desmonta um degrau por vez e **custa o mesmo trabalho que construir**: parede, porta e portão viram piso; piso sai do mapa. Demolir o chão no meio de uma sala deixa um **vão aberto para o espaço com parede em volta**, não um bloco maciço nem um rombo sem acabamento. Nunca constrói nada. No casco automático e no vácuo não acontece nada. Sobre um canteiro, demolir **cancela o trabalho** em vez de abrir outro — ver abaixo.
- Nada pode isolar parte da estação do jogador nem tirar o chão de onde ele está.

## Obra: construir custa trabalho

Nenhuma das três construções entrega a peça na hora: todas abrem um **canteiro**, que percorre estágios. `_alvos` guarda o que cada célula vai entregar — `PISO`, `MURO` ou `PORTA` — e `ESTAGIOS_ATE` diz quantos estágios cada alvo percorre.

**Não há relógio.** Até 2026-10-05 cada estágio durava `SEGUNDOS_POR_ESTAGIO` e passava sozinho enquanto o jogador fazia outra coisa; hoje um estágio só fecha quando alguém bate `TRABALHO_POR_CELULA / ESTAGIOS_ATE` de trabalho naquela célula, com `MapaEstacao.trabalhar()`. `_trabalho` guarda quanto já foi batido no estágio corrente, e é ele que `instantaneo()` copia e `restaurar()` devolve.

| Alvo | Estágios | Por quê |
|---|---|---|
| `PISO` | 3 | nasce do nada e precisa de chão |
| `MURO`, `PORTA` | 2 | sobem sobre piso que já existe: demarcar e erguer bastam |

**Parede e porta em obra** continuam com o piso desenhado por baixo. No `DEMARCADO` é a fita de obra no chão (`marcacao.png`, 16 variações pela máscara dos quatro lados, para uma parede de seis células sair com uma fita só em volta das seis). No `ESTRUTURA` entra a peça meio pronta, e a fita continua **por cima**, na camada `Detalhes`, agora sem a sombra de área reservada — a linha 1 do mesmo atlas.

A parede meio erguida reaproveita a **grade de vigas do canteiro de piso**: é estrutura antes de chapa, que é exatamente o que está acontecendo. Desenhá-la como a parede pronta, só que apagada, não funciona sobre piso — foi tentado, e o bloco escuro da parede interna ficou idêntico à sombra da fita. Contra o vazio o apagado lê; contra o piso, não.

Só a fita de **parede** colide. A de porta usa `ALT_MARCACAO_LIVRE`, a mesma arte sem polígono.

**Essa alternativa é translúcida** (`COR_FITA_SOBRE_PECA`, 45%), e é a mesma que o canteiro desenha por cima de peça em obra. A fita é uma faixa larga nos quatro lados da célula: opaca, ela comia o quadrado inteiro, e quem batia numa obra não via a peça andar de um estágio para o outro — foi o que o jogador apontou em 2026-10-05. A base continua opaca, porque no primeiro degrau de parede não há nada por baixo para deixar ver.

**Demolir é o mesmo canteiro andando para trás.** `_demolindo` marca quais correm ao contrário: a peça começa no último degrau e desce um por vez, com o mesmo desenho que teve ao subir, até sumir. Parede, porta e portão param no piso; o piso abre vácuo. É por isso que `_alvos` guarda *a peça de que o canteiro trata*, e não "o que vai ser entregue": numa demolição a peça é o que está sendo desmontado.

Enquanto desce, a peça continua colidindo como colidia pronta — é o que mantém a validação de ligação honesta. Demolir o chão de um corredor é recusado na hora se isso partir a estação em duas, e não depois que o trabalho já foi gasto.

`_cancelar_canteiro()` interrompe o trabalho e devolve a célula ao estado anterior a ele: construção cancelada tira o que nem chegou a existir, demolição cancelada **recompõe a peça inteira**. É isso que a ferramenta Demolir faz quando cai sobre um canteiro — não faz sentido desmontar degrau por degrau o que ainda não foi montado, e é assim que o jogador interrompe uma demolição de que se arrependeu depois de já ter confirmado a planta.

### Expandir sobre o casco não abre buraco

A estação só cresce **atravessando o próprio casco**: o casco é derivado, não é peça, e toda célula vizinha do interior é casco por definição — não há como expandir sem passar por ele. Até 2026-10-05 a célula saía do casco no instante do clique e o primeiro estágio era a baliza desenhada sobre o campo estelar: pedir chão onde havia parede **abria um buraco para o vácuo**, que é o contrário do que se estava pedindo. Foi o que o jogador apontou.

Hoje `_era_parede` marca os canteiros abertos onde já havia parede, e a parede fica de pé até o chão novo ser entregue:

| Estágio | O que se vê |
|---|---|
| `DEMARCADO` | a parede inteira, com a fita de obra por cima |
| `ESTRUTURA` | a chapa já assentada, vista **através** da parede que cai |
| `ACABAMENTO` | a parede caiu, e só a chapa crua fica |

A chapa entra por baixo já no segundo degrau porque a camada `Obra` desenha **antes** da `Casco`. Sem ela a parede translúcida ficava sobre o campo estelar e lia como o mesmo buraco de antes, só que de porta entreaberta — foi o que a primeira captura mostrou. Com a chapa atrás, translúcido lê como o que é: parede vindo abaixo sobre chão que já está posto.

O casco novo, uma célula adiante, corre ao contrário: nasce translúcido em `_nasceu_da_obra` e só fecha quando o canteiro entrega. Translúcido quer dizer "em trânsito" nos dois sentidos, e **nenhum dos dois momentos abre vão**.

`_era_parede` precisa ser guardado, e não deduzido depois: o que separa casco de vão fechado é o preenchimento de fora para dentro de `_recalcular_casco`, e ele já correu quando chega a hora de desenhar. Entra em `instantaneo()`, em `restaurar()` e no desfazer de `aplicar()`, como os outros dicionários do canteiro. Essas células também ficam fora de `falta_chao()`: cone apontando para uma parede inteira não avisa de nada.

A expansão de piso **no vácuo** segue com os três estágios de sempre:

| Estágio | Leitura | Tile |
|---|---|---|
| `DEMARCADO` | área marcada no vazio, nada construído | `demarcacao.png`, 256 variações por máscara |
| `ESTRUTURA` | vigas fechando a célula, ainda se vê o espaço | `obra.png` linha 0 |
| `ACABAMENTO` | chapa assentada, ainda crua | `obra.png` linha 1 |

O `DEMARCADO` **não sai do mesmo atlas que os outros dois**: é indexado pela máscara de 8 bits da vizinhança, como o casco e a borda, e por isso o trilho âmbar corre só na divisa do canteiro. A primeira versão marcava célula por célula, com cantoneira nos quatro cantos de cada uma; as pontas de quatro vizinhas se encontravam e nascia um **`+` âmbar no meio do nada**, que foi o que o jogador recusou. Marca de área se indexa pela vizinhança; marca por célula vira padrão de papel de parede.

**A parede nasce apagada junto com o canteiro.** `_nasceu_da_obra()` reconhece o casco que só existe por causa de uma obra aberta — encosta em obra e em nenhum piso — e o desenha com `ALT_CASCO_EM_OBRA`, uma alternativa do mesmo tile com `modulate` translúcido. É alternativa, e não atlas próprio, porque o desenho não muda: o que muda é o jogador ver as estrelas através da parede enquanto o canteiro não fecha. Pelo mesmo motivo essa parede **não recebe cano nem luminária** — tubulação parafusada numa parede que ainda não existe nega o próprio aviso. Mostrar a parede pronta em volta de uma área que ainda era só baliza foi a outra metade do que ficou estranho.

Esses três **têm colisão**; só o piso final libera passagem.

`forcar_estagio()`, `avancar_um_estagio()` e `concluir_obras()` existem para teste e captura não precisarem simular o jogador martelando célula por célula.

Fora do modo, `F` trabalha no canteiro que o personagem **encara** e `E` dorme (perto da cama) ou abre e fecha o portão do hangar (perto dele). O mesmo `E` serve as duas coisas porque elas nunca estão ao alcance ao mesmo tempo: `Trabalho` é **irmão posterior** a `Construcao` na árvore, recebe o evento primeiro — `_unhandled_input` corre em ordem inversa — e só o consome perto da cama, deixando o resto passar. As portas comuns abrem sozinhas por proximidade e nunca têm colisão.

**O mapa editado não é salvo.** Formato de save é ponto aberto, então reabrir o jogo volta à planta inicial.

