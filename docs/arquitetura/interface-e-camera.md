# Interface e câmera

`scripts/fonte.gd`, `scripts/tecla.gd`, `scripts/painel_hud.gd`,
`scripts/barra_energia.gd`, `scripts/balao.gd`, `scripts/menu_pausa.gd`, o zoom
das duas câmeras e a interface montada em código dentro de `trabalho.gd` e
`modo_construcao.gd`.

Carregar para mexer na fonte, no painel do HUD, na barra de energia, no balão de
fala, no contador de dias, no menu de pausa ou no enquadramento.

## A fonte

**VT323**, em `assets/interface/vt323.ttf`, apontada por `gui/theme/custom_font`
em `project.godot`. Todo `Label`, `Button` e `RichTextLabel` já nasce com ela.

É uma fonte **vetorial com desenho de pixel**, e é assim que ela tem de ser
importada: `antialiasing` e `subpixel_positioning` **desligados** no
`.import`. A documentação do 4.7 é explícita — fonte de aparência pixelada com
subpixel ligado sai com pixel de tamanho desigual. Há verificação disso em
`tools/testar_estacao.gd`, porque nenhum dos dois levanta erro: só fica borrado
na tela.

**Nem todo corpo sai limpo nela, e não há fórmula.** Corpo fora de medida
continua desenhando, e sai com traço de espessura desigual dentro da mesma
palavra: as hastes caem em meio pixel e a fonte é rasterizada sem antialiasing.
Nenhum erro é levantado — só fica feio.

A lista foi medida olhando, com a fonte desenhada pela própria engine e
ampliada:

| | |
|---|---|
| **limpos** | 20, 24, 25, 28, 30, 40, 50 |
| **sujos** | 14, 15, 16, 18, 21, 22, 32, 33, 35, 37 |

A métrica explica parte — `unitsPerEm` 1000, `capHeight` 560 e avanço 400 só
caem em pixel inteiro em múltiplo de 25 —, mas **não tudo**: 24 e 28 são limpos
e não são múltiplos de nada útil, e 15 é múltiplo de 5 e é sujo. A lista vale
mais que a conta, e **corpo novo se confere na tela antes de entrar**.

Por isso os corpos têm nome, e são três:

| | | |
|---|---|---|
| `Fonte.MIUDO` | 20 | os dois balões e as linhas do painel de ferramentas |
| `Fonte.MEDIO` | 25 | o contador do dia, no rebaixo da placa do HUD |
| `Fonte.GRANDE` | 30 | o menu de pausa, e só ele |

**`MIUDO` é também `gui/theme/default_font_size`**, e é por isso que ele vale
para todo `Button` e `Label` que não pede outro corpo — as linhas do painel de
ferramentas, hoje. Sem esse ajuste no `project.godot` elas cairiam no padrão do
engine, **16, que está na lista dos sujos** — e foi exatamente o que aconteceu
por algumas horas em 2026-10-06. Com a fonte de bitmap anterior o descuido era
invisível: ela só desenhava em múltiplo inteiro da arte, então pedir 16 dava o
mesmo 12 de sempre. Numa fonte vetorial, 16 é 16.

`Fonte.rotulo(cor, corpo)` é a fábrica de `Label`. Sem contorno: a VT323 é
vetorial e `outline_size` hoje funcionaria, mas o texto que precisava dele por
flutuar sobre o casco já tem chapa atrás — a placa do HUD ou o balão.

**Substituiu em 2026-10-06 uma fonte de BITMAP** gerada por
`tools/gerar_fonte.py`, a pedido: a legibilidade dela estava ruim. O gerador,
`assets/interface/fonte.png` e `fonte.fnt` continuam no repositório mas **não
alimentam mais nada**. A troca puxou três números atrás dela, todos registrados
onde moram: a escala da tampa de tecla, o corpo da fala do balão e
`ABAIXO_DO_HUD` em `modo_construcao.gd`.

Os corpos **desceram no mesmo dia, a pedido**: os balões de 25 para 20 e o menu
de pausa de 50 para 30. Os primeiros números saíram de uma regra que parecia ser
"múltiplo de 25" e que a medição acima desmentiu.

## O painel do HUD

No canto superior direito há uma **chapa de aço** (`scripts/painel_hud.gd`) que hoje carrega duas coisas: o contador de dias, num rebaixo cavado nela, e a barra de energia. Antes eram texto solto e barra solta sobre o cenário, e o jogador pediu os dois na mesma peça — com espaço para o que vier depois.

A placa é uma **moldura de nove pedaços**: quatro cantos de tamanho fixo, quatro arestas esticadas numa direção só e o miolo esticado nas duas. As arestas são fatias de **um pixel**, pelo mesmo motivo do trilho da barra: esticar um pixel é repetir coluna, e numa chapa de linhas retas isso não deforma nada. É o que deixa a placa acompanhar qualquer conteúdo sem arte nova.

A mesma folha (`assets/interface/painel.png`) traz **duas chapas**, uma por linha: relevo e encaixe. Mesma geometria, luz invertida — é só isso que separa "placa parafusada" de "rebaixo cavado nela". O contador do dia é um `PainelHud` em `ENCAIXE` dentro de um `PainelHud` em `RELEVO`.

Na primeira versão a chapa era quase da cor do espaço e só o chanfro aparecia: o painel lia como moldura vazia, não como chapa com coisas em cima. O fundo precisa ficar **claramente** acima do fundo do jogo, e mesmo assim não pode ser opaco — chapa fechada no canto da tela tapa estrela e casco como se fosse cenário.

O rebaixo do dia usa `apertar()`, que aproxima o conteúdo da moldura. Só a chapa **sem rebite** pode: o rebite ocupa os pixels de dentro do canto, e conteúdo em cima dele lê como peça montada torta. O desenho da moldura em si ocupa dois pixels de arte, e esse é o piso.

**Onde entra o que vier depois:** `_painel.conteudo` é um `VBoxContainer`, uma linha por assunto. Hoje há uma, com o dia e a energia lado a lado. Acrescentar leitura ao HUD é acrescentar filho ali — `trabalho.gd` não precisa mudar.

A placa **cresce para a esquerda e para baixo** (`grow_horizontal = GROW_DIRECTION_BEGIN`), ancorada no canto. É o que substituiu a conta de largura que havia em `trabalho.gd`: uma energia máxima maior dá mais divisões à barra, e a placa inteira se alarga pelo lado de dentro da tela em vez de empurrar a borda direita para fora dela. O teste confere que a borda direita não sai do lugar quando a energia máxima dobra.

## O balão de fala

`scripts/balao.gd`. **Substituiu as dicas em texto solto no rodapé da tela**, que
havia em `trabalho.gd` e em `modo_construcao.gd`.

Texto no rodapé não diz de quem é a frase nem sobre o que ela fala: `E — dormir`
podia estar saindo da cama, do portão ou de lugar nenhum. O
balão nasce **em cima da cabeça de quem fala**, com o rabo apontando para ele, e
isso responde as duas coisas de uma vez — quem fala e sobre o quê.

**A tecla é desenho, não letra.** `assets/interface/teclas.png` traz A–Z e 0–9 em
tampa de teclado: `E` solto no meio de uma frase em português lê como a
conjunção, e o travessão que separava a tecla da frase era muleta disso. A folha
sai de `tools/gerar_interface.py`, e `ORDEM_SIMPLES` em `scripts/tecla.gd` é o
contrato com ela — letra → índice → célula. São **duas folhas**, porque são dois
tamanhos de tampa: `F1` não cabe na célula quadrada de 11 sem espremer a letra.

**A tampa sai em 2x** (`Tecla.ESCALA`), e esse número é derivado da letra ao
lado, não escolhido. Com a fonte de bitmap antiga, de 12 px de linha, 2x media
22 px de tela — três vezes a altura da letra — e a linha lia como ícone com
legenda; por isso ela era 1:1. Com a VT323 a linha tem 20 px e é o 1:1 que passa
a estar fora de escala: 11 px de tela ao lado dela lê como marca d'água, não
como tecla. Em 2x a tampa mede 22 px — um pouco mais alta que a linha, que é a
proporção de uma tampa de teclado de verdade.

`mostrar()` aceita uma escala por chamada porque a tampa aparece em **dois
contextos que medem de formas diferentes**. Dentro de uma linha de texto ela se
mede pela letra, e o padrão serve. Encavalada num ícone de 32 px — o atalho de
`F1` no canto, com o modo fechado — ela se mede pelo **ícone**, e ali o padrão
cobriria o desenho que a tampa deveria estar marcando: esse chamador pede 1:1.

O nó mora numa **`CanvasLayer`, e não no mundo**. No mundo ele seria desenhado
com o zoom da câmera do jogo (0,26 a 0,62) e a letra sairia menor que um pixel de
tela a cada afastada. Aqui ele tem tamanho de interface, e só a **posição** vem
do mundo, por `seguir()` — que precisa ser chamado a cada quadro, porque quem
fala anda e a câmera anda com ele. A posição é **arredondada**: meio pixel não
borra com o filtro Nearest, mas faz a borda engordar e afinar de um lado conforme
o personagem anda.

É a mesma **moldura de nove pedaços** da placa do HUD, mais o rabo. O rabo é
desenhado por último e sobrepõe duas linhas da borda de baixo
(`RABO_SOBREPOSICAO`) — é isso que abre a boca; sem elas a borda fecharia o balão
e o rabo leria como peça solta embaixo. E o balão nunca fica mais estreito que o
próprio rabo, senão a boca sairia pelos lados numa ação curta.

Sem contorno no texto, ao contrário das dicas que havia na tela: aqui existe
fundo atrás da letra, e o contorno que a salvava sobre o casco só a engorda.

**As duas linhas são hoje do mesmo corpo, e nem sempre foram.** A fala usava
`Fonte.GRANDE` e a ação, `MIUDO`: com a fonte de bitmap isso era 24 contra 12, e
a diferença de corpo era a hierarquia do balão.

A troca para a VT323 tirou esse degrau: os corpos limpos dela não formam uma
escada útil para o balão. No degrau acima de `MIUDO` a fala media **667 px de
tela**, mais da metade da largura — e uma dica que aparece toda vez que o
personagem passa perto da cama não pode tomar meia tela. Então as duas linhas
são `MIUDO`.

A hierarquia das duas linhas passou a ser a **cor e a tampa da tecla**, que o
balão já usava — claro para o que ele diz, âmbar com tampa para o que há para
apertar.

Entre a borda desenhada e o texto há `RESPIRO_X`/`RESPIRO_Y` **além da própria
borda**. Só a borda (8 px de tela) encostava a letra no fio de luz, e balão
apertado lê como caixa de aviso, não como fala. Sobra mais em pé do que deitado
porque a altura de linha do `Label` já traz um pouco de ar que a largura não
traz.

`dizer(fala, tecla, acao, cor)` aceita parte vazia: sem `fala` mostra só a tecla
e a ação; sem `tecla` mostra a ação sem tampa — é o caso em que **não há o que
apertar**, como o aviso de energia esgotada. O que ele diz em cada situação é
decisão de `trabalho.gd`, em
[trabalho-energia-e-dia.md](trabalho-energia-e-dia.md).

`cor` existe por causa do **segundo usuário do balão**: a recusa do modo de
construção, que desde 2026-10-06 saiu do rodapé do painel e virou balão ancorado
na seleção recusada (ver
[construcao-e-obra.md](construcao-e-obra.md)). É o único texto desta caixa que
não é um convite, e sai em vermelho porque o retângulo do cursor embaixo dela já
está vermelho — balão âmbar apontando para uma seleção recusada diria o
contrário do que ela diz. Os dois nunca aparecem juntos: `trabalho.gd` cala o do
personagem enquanto o modo de construção está aberto.

## A barra de energia

A barra é a referência que o jogador trouxe: uma fila de `>` que se esvazia da direita para a esquerda, com a gema de um lado e a ponta de seta do outro, na paleta de aço da estação.

**Encolheu em 2026-10-05, em duas rodadas, a pedido.** A peça foi de 16×14 para 8×11 e o passo entre divisões de 11 para 6 — a barra cheia caiu de **252 px de tela para 134**, e o painel inteiro, com o dia dentro, ficava em 185×36. Com a troca da fonte em 2026-10-06 ele mede **212×49** — a barra não mudou, o texto em volta dela é que cresceu. É dessa altura que sai `ABAIXO_DO_HUD` em `modo_construcao.gd`, o número que mantém o painel de ferramentas fora da placa.

Quem perdeu altura foi o **miolo**: a moldura continua com as mesmas quatro linhas, porque são elas que fazem a peça ler como calha de aço, e cortar uma deixa o sulco sem fundo. Com o miolo em sete linhas, as três faixas chapadas se repartem 2/3/2. A largura veio do corpo do `>` (de 9 para 4) e das folgas em volta — a gema, a tampa e a separação entre o dia e a barra.

**O número de divisões não é fixo**, e esse é o ponto. Cada uma vale `ENERGIA_POR_DIVISAO`, e a conta vem da energia máxima do personagem — no dia em que uma melhoria aumentar `Jogador.ENERGIA_MAXIMA`, a barra ganha divisões sozinha, sem arte nova e sem ninguém mexer em `barra_energia.gd`. O teste confere isso dobrando a energia e esperando o dobro de divisões.

É por isso que `tools/gerar_interface.py` produz **peças**, e não uma barra inteira: divisão cheia, divisão vazia, seta, gema, e duas de moldura. A moldura reta é uma fatia de **um pixel** que o Control estica — esticar na horizontal repete colunas, e numa moldura de linhas horizontais isso não deforma nada. Uma barra desenhada inteira precisaria de arte nova a cada tamanho.

**Uma divisão vale exatamente um quadrado de chão.** A barra então não mede só "quanto resta": ela conta quantos quadrados ainda dá para construir hoje, que é a pergunta que se faz ao olhar para ela.

Três decisões de desenho:

- A divisão cheia e a vazia têm **a mesma silhueta** — o que muda é só o miolo. Silhuetas diferentes fariam a fila inteira andar um pixel quando uma divisão se esvazia.
- O passo entre divisões é `CORPO + FOLGA`, e como o avanço da ponta é o mesmo em todas, o **sulco escuro entre elas sai com largura constante em todas as linhas**. É o que faz a fila parecer uma peça só repetida em vez de oito desenhos.
- A divisão cheia e a gema saem da arte em **cinza**, e quem as colore é o Control. Desenhá-las já verdes travava a cor: o aviso de energia baixa é vermelho, e nenhuma multiplicação leva um verde ao vermelho — o R teria de crescer onde o G já está alto, e o que saía era oliva.

A divisão em curso é cortada na vertical, com a parte esquerda colorida e a direita no sulco. Sem isso a barra andaria aos saltos de um quadrado inteiro.

As vazias são desenhadas todas primeiro, e as cheias por cima: a ponta de uma divisão avança sobre a vizinha, e desenhar na ordem da fila deixaria a vazia seguinte mordendo a ponta da cheia anterior.

**O sinal de energia é emitido antes de `Trabalho` conectar**: o jogador emite o valor inicial no `_ready` dele, que roda primeiro por ser irmão anterior na árvore. Por isso `Trabalho` sincroniza a barra na hora de conectar — sem isso ela nasceria com a energia máxima zerada, numa divisão só.

## Zoom

A roda do mouse aproxima e afasta a câmera nos **dois modos**, com o mesmo passo (`PASSO_ZOOM`, 1,12): é a mesma roda e o mesmo gesto, e duas sensibilidades diferentes para a mesma ação se notam na hora.

A **faixa**, essa não é a mesma. No modo de construção vai de 0,25 a 1,5, que serve para olhar a planta inteira ou um canto dela; no jogo vai de 0,26 a 0,62 — quatro entalhes para cada lado do padrão de 0,4. É ajuste pessoal de quem joga, não enquadramento: afastado demais o personagem some, aproximado demais não cabe uma sala na tela.

O zoom do jogo mora em `jogador.gd`, porque a câmera é dele. Não há disputa com o modo de construção: lá a roda é lida em `_unhandled_input` e consumida, e por ser um irmão posterior na árvore o modo recebe o evento antes — com ele aberto, nada chega ao jogador. O `travar()` é a segunda tranca.


## Menu de pausa

`ESC` abre e fecha; os botões são "Voltar ao jogo" e "Sair do jogo". A interface é montada em código, em `menu_pausa.gd`.

O nó usa `PROCESS_MODE_ALWAYS`, não `WHEN_PAUSED`: com `WHEN_PAUSED` o `_unhandled_input` ficava desligado enquanto o jogo rodava, e o `ESC` que deveria **abrir** o menu nunca chegava nele — o menu existia e era inalcançável.

Quem está no modo de construção come o `ESC` antes, em `_input` (que roda antes de todo `_unhandled_input`), então o primeiro `ESC` fecha a construção e só o seguinte abre o menu. Sem isso o menu ganharia o evento, por ser um irmão posterior na árvore.

