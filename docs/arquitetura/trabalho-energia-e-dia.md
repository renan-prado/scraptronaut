# Trabalho, energia e o dia

`scripts/trabalho.gd` e a energia de `scripts/jogador.gd`.

Carregar para mexer em energia do personagem, custo de obra, ritmo da martelada,
contador de dias ou na cama. A barra que mostra essa energia está em
[interface-e-camera.md](interface-e-camera.md).

## O laço: energia, picareta e o dia

`scripts/trabalho.gd` fecha o laço: planejar no modo de construção, ir até a obra, bater nela até a energia acabar, dormir, continuar no dia seguinte. O nó junta energia, obra e cama porque as três são a mesma coisa — separá-las daria três nós perguntando o estado um do outro a cada quadro.

**A energia é do personagem, não da estação.** A energia de `docs/Mecanicas-Scraptronaut.md` é a unidade única da estação e não tem nada a ver com esta: aqui se mede quanto Lira/Miro ainda aguenta bater picareta hoje. `Jogador.ENERGIA_MAXIMA` (100) é **um dia de trabalho**, e andar e explorar não gastam nada — só obra gasta, porque é só da obra que o cansaço é assunto.

| Tecla | Ação |
|---|---|
| `F` segurado | Trabalha no canteiro que o personagem **encara** (até 1,9 célula) |
| `E` perto da cama | Dorme: a tela apaga, o dia vira, a energia volta cheia |
| Roda | Zoom entre 0,26 e 0,62 — ver abaixo |

Enquanto bate, o jogador não anda: o estado `TRABALHANDO` suspende o movimento, e soltar `F` devolve o controle.

## Em qual canteiro o `F` bate

Era o **mais perto**, e o mais perto não se controla. Com um canteiro ao sul e outro a leste, quem decidia era o meio pixel em que o jogador tinha parado, e virar-se para o que ele queria não mudava nada — foi o que o jogador apontou em 2026-10-05.

Hoje decide a **vista**: `MapaEstacao.canteiro_perto()` recebe o rumo de `Jogador.rumo()` e escolhe o canteiro mais bem alinhado com ele. A vista é o único comando que o jogador tem na mão para isso, e é um comando barato: empurrar o personagem contra a peça o vira **sem tirá-lo do lugar**, porque canteiro tem colisão.

- O cone é de **60°** para cada lado (`COSSENO_DO_ALCANCE`, 0,5), e não 45. As oito vistas da folha estão a 45° uma da outra: com o cone justo, um canteiro exatamente na diagonal cairia na divisa entre duas vistas e piscaria. Com 60°, quem olha para leste alcança o canteiro a nordeste e a sudeste — e segue **sem** alcançar o que está ao sul, que é o ponto do pedido
- O desempate é por distância, e só entre alinhamentos iguais: duas células igualmente na mira são duas células em fila, e a de trás não se alcança
- **Canteiro debaixo dos pés dispensa mira.** Só o de porta é pisável, e quem está em cima dele está trabalhando nele
- `rumo` zerado volta ao critério antigo. É o que `tools/capturar_construcao.gd` usa: a captura posiciona o jogador e não tem vista para informar

**O canteiro na mira é desenhado com uma moldura amarela**, em `trabalho.gd`. Ela aparece **antes** de o `F` ser apertado, porque é ela que diz onde o `F` vai cair — sem isso a mira existiria e seria invisível. Fica no mundo, e não na interface: numa obra de vinte células uma marca no canto da tela não apontaria nenhuma. A grossura é de 6 px de mundo porque a câmera do jogo anda perto de 0,4 de zoom, e 3 px sumiriam na tela.

**A conversão de energia em trabalho tem ordem fixa**, em `_bater()`: o mapa só recebe o que o jogador pode pagar, e o jogador só paga o que o canteiro aceitou. Pagar primeiro cobraria a sobra da última martelada, quando o canteiro já fechou — e `trabalhar()` devolve o consumo, não um `bool`, exatamente para isso.

**O custo é por célula, e se lê em quantas células cabem numa barra cheia.** A tabela de hoje saiu do pedido de "8 quadrados por barra de energia cheia":

| Alvo | Custo por célula | Numa barra cheia |
|---|---|---|
| `PISO` (expandir e demolir chão) | 12,5 | **8 quadrados** |
| `MURO` | 5,0 | 20 paredes |
| `PORTA` | 6,25 | 8 portas — a peça tem sempre 2 células |

Uma porta inteira custa o mesmo que um quadrado de chão, e é assim que a proporção fica legível sem tabela.

**A escala anterior era seis vezes maior** (75 por célula de piso: quatro células davam três dias). Ela veio do primeiro pedido — "expandir ou encolher a nave, tipo 3 dias" — e foi substituída em 2026-10-05, a pedido, por ter deixado o dia acabar antes de uma única célula fechar. O que mudou foi a escala, não a proporção: expandir continua sendo a obra cara e parede a barata.

`tools/testar_estacao.gd` confere essas igualdades contra `ENERGIA_MAXIMA`, então mexer num número sem mexer no outro quebra o teste em vez de passar despercebido.

**`MARTELADAS_POR_QUADRADO` (12) é o botão do ritmo**, e está em marteladas porque é assim que o golpe se conta na mão: quem joga não mede segundos, mede quantas vezes a picareta sobe e desce até a célula fechar.

`ENERGIA_POR_SEGUNDO` é **derivado** dele — `TRABALHO_POR_CELULA[PISO] / (MARTELADAS_POR_QUADRADO × Jogador.CICLO_TRABALHO)` — e não escrito à mão. É o que mantém a martelada visível casada com o custo: mudar a cadência da animação sem mexer no ritmo faria a conta de marteladas mentir em silêncio. `SEGUNDOS_DE_UM_DIA` sai dos dois e existe só para leitura e teste.

Mexer nesse número estica ou encurta o dia inteiro sem tocar no equilíbrio — os custos de obra estão em energia, e a energia não muda. Continuam sendo oito quadrados por barra.

| Versão | Um quadrado | Barra cheia | Veredito |
|---|---|---|---|
| primeira | 112,5 s = 141 marteladas | 1,3 quadrado | recusado: "acabando muito rápido" |
| segunda | 18,8 s = 24 marteladas | 8 quadrados | recusado: repetição demais |
| hoje | **9,6 s = 12 marteladas** | 8 quadrados, 77 s | é o pedido |

A barra de progresso é desenhada dentro da mesma moldura, **dentro** da célula do canteiro, e não flutuando acima dela: quem bate está sempre na célula vizinha, e uma barra acima do canteiro cai justamente em cima de quem está martelando — foi o que apareceu na primeira captura.

Uma consequência que não foi projetada, mas é bem-vinda: canteiro de piso tem colisão, então uma expansão funda **só pode ser trabalhada fila por fila**, de dentro para fora, conforme o chão novo vira piso e o jogador consegue pisar nele.


## A cama

A cama fica encostada na parede norte do armazém (`MapaEstacao.CELULA_DA_CAMA`), ocupa **duas células em pé** e é o único lugar da Lastro onde o dia termina.

**Ela não está no mapa.** `MapaEstacao` indexa tudo por máscara de vizinhança numa grade de 64; a cama tem cabeceira de um lado só e não se encaixa com vizinha nenhuma — indexá-la pela vizinhança seria gastar 256 variações de atlas para desenhar sempre a mesma coisa. É nó próprio (`scripts/cama.gd`), com arte e colisão próprias, e `tools/construir_estacao.gd` a posiciona na **divisa** entre as duas células, que é o centro da arte.

A pose de dormir é a vista **de frente** do personagem: visto de cima, quem está de costas na cama mostra o rosto, com a cabeça no travesseiro e os pés na beira — exatamente o enquadramento da vista frontal. Por isso o travesseiro, a dobra do lençol e o pé da cama estão nas alturas em que a cabeça, o peito e os pés daquela figura caem; as medidas estão anotadas nos dois geradores, e mexer numa pede conferir a outra.

A energia volta **no meio da noite**, com a tela apagada: ver a barra encher com o personagem ainda deitado estraga a leitura de que o dia virou.

