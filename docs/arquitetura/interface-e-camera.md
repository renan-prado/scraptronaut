# Interface e câmera

`scripts/barra_energia.gd`, `scripts/menu_pausa.gd`, o zoom das duas câmeras e a
interface montada em código dentro de `trabalho.gd` e `modo_construcao.gd`.

Carregar para mexer em HUD, barra de energia, menu de pausa ou enquadramento.

## A barra de energia

A barra é a referência que o jogador trouxe: uma fila de `>` que se esvazia da direita para a esquerda, com a gema de um lado e a ponta de seta do outro, na paleta de aço da estação.

**O número de divisões não é fixo**, e esse é o ponto. Cada uma vale `ENERGIA_POR_DIVISAO`, e a conta vem da energia máxima do personagem — no dia em que uma melhoria aumentar `Jogador.ENERGIA_MAXIMA`, a barra ganha divisões sozinha, sem arte nova e sem ninguém mexer em `barra_energia.gd`. O teste confere isso dobrando a energia e esperando o dobro de divisões.

É por isso que `tools/gerar_interface.py` produz **peças**, e não uma barra inteira: divisão cheia, divisão vazia, seta, gema, e duas de moldura. A moldura reta é uma fatia de **um pixel** que o Control estica — esticar na horizontal repete colunas, e numa moldura de linhas horizontais isso não deforma nada. Uma barra desenhada inteira precisaria de arte nova a cada tamanho.

**Uma divisão vale exatamente um quadrado de chão.** A barra então não mede só "quanto resta": ela conta quantos quadrados ainda dá para construir hoje, que é a pergunta que se faz ao olhar para ela.

Três decisões de desenho:

- A divisão cheia e a vazia têm **a mesma silhueta** — o que muda é só o miolo. Silhuetas diferentes fariam a fila inteira andar um pixel quando uma divisão se esvazia.
- O passo entre divisões é `CORPO + FOLGA`, e como o avanço da ponta é o mesmo em todas, o **sulco escuro entre elas sai com largura constante em todas as linhas**. É o que faz a fila parecer uma peça só repetida em vez de oito desenhos.
- A divisão cheia e a gema saem da arte em **cinza**, e quem as colore é o Control. Desenhá-las já verdes travava a cor: o aviso de energia baixa é vermelho, e nenhuma multiplicação leva um verde ao vermelho — o R teria de crescer onde o G já está alto, e o que saía era oliva.

A divisão em curso é cortada na vertical, com a parte esquerda colorida e a direita no sulco. Sem isso a barra andaria aos saltos de um quadrado inteiro.

As vazias são desenhadas todas primeiro, e as cheias por cima: a ponta de uma divisão avança sobre a vizinha, e desenhar na ordem da fila deixaria a vazia seguinte mordendo a ponta da cheia anterior.

A caixa que contém a barra acompanha a largura dela. Com borda esquerda fixa, uma energia máxima maior empurraria a barra para fora da tela — e crescer é justamente o que ela existe para poder fazer.

**O sinal de energia é emitido antes de `Trabalho` conectar**: o jogador emite o valor inicial no `_ready` dele, que roda primeiro por ser irmão anterior na árvore. Por isso `Trabalho` sincroniza a barra na hora de conectar — sem isso ela nasceria com a energia máxima zerada, numa divisão só.

## Zoom

A roda do mouse aproxima e afasta a câmera nos **dois modos**, com o mesmo passo (`PASSO_ZOOM`, 1,12): é a mesma roda e o mesmo gesto, e duas sensibilidades diferentes para a mesma ação se notam na hora.

A **faixa**, essa não é a mesma. No modo de construção vai de 0,25 a 1,5, que serve para olhar a planta inteira ou um canto dela; no jogo vai de 0,26 a 0,62 — quatro entalhes para cada lado do padrão de 0,4. É ajuste pessoal de quem joga, não enquadramento: afastado demais o personagem some, aproximado demais não cabe uma sala na tela.

O zoom do jogo mora em `jogador.gd`, porque a câmera é dele. Não há disputa com o modo de construção: lá a roda é lida em `_unhandled_input` e consumida, e por ser um irmão posterior na árvore o modo recebe o evento antes — com ele aberto, nada chega ao jogador. O `travar()` é a segunda tranca.


## Menu de pausa

`ESC` abre e fecha; os botões são "Voltar ao jogo" e "Sair do jogo". A interface é montada em código, em `menu_pausa.gd`.

O nó usa `PROCESS_MODE_ALWAYS`, não `WHEN_PAUSED`: com `WHEN_PAUSED` o `_unhandled_input` ficava desligado enquanto o jogo rodava, e o `ESC` que deveria **abrir** o menu nunca chegava nele — o menu existia e era inalcançável.

Quem está no modo de construção come o `ESC` antes, em `_input` (que roda antes de todo `_unhandled_input`), então o primeiro `ESC` fecha a construção e só o seguinte abre o menu. Sem isso o menu ganharia o evento, por ser um irmão posterior na árvore.

