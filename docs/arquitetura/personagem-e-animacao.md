# O personagem e sua animação

`scripts/player.gd` e o gerador `tools/generate_miro_states.py`.

Carregar para mexer em movimento, estados, folhas de sprite ou nos quadros de
cada pose. As regras gerais de pixel art estão na skill `pixel-art`, não aqui.

## Os quatro estados

`player.gd` tem quatro estados, cada um com sua folha, sua grade e seu deslocamento de `Sprite2D`:

| Estado | Folha | Puxada por |
|---|---|---|
| `IDLE` | `miro_idle.png` 4×8 | relógio, ciclo de 2,6 s |
| `WALKING` | `miro_8dir.png` 4×8 | distância percorrida |
| `WORKING` | `miro_working.png` 4×8 | relógio, ciclo de 0,8 s |
| `SLEEPING` | `miro_sleeping.png` 4×1 | relógio, ciclo de 4,2 s |

## Quais colunas fazem som

Duas constantes de `player.gd`, e são **a ponte entre a animação e o áudio**:

| Constante | Colunas | O que dispara |
|---|---|---|
| `CONTACT_FRAMES` | 0 e 2 | `Sound.footstep()` — as duas colunas de **contato** do ciclo de caminhada |
| `IMPACT_FRAME` | 2 | `Sound.hammer_hit()` — a coluna do golpe da picareta |

A ordem gravada pelo gerador é `ORDER = [0, 2, 1, 3]` (ver
`tools/generate_miro_8dir.py`): os dois quadros de **pés plantados e separados**
viram as colunas 0 e 2, e os dois de **passagem** — pés fundidos, um cruzando o
outro — as colunas 1 e 3. Pé que está no ar não faz barulho, então **mexer em
`ORDER` lá pede mexer em `CONTACT_FRAMES` aqui**.

`IMPACT_FRAME` é a mesma coluna em que o gerador desenha as faíscas e o maior
agachamento (ver `ANGLES` e `CROUCH` em `tools/generate_miro_states.py`). Som
de golpe em qualquer outra sairia antes ou depois de a ferramenta encostar.

O gatilho é a **troca de coluna** desenhada, guardada em `_drawn_frame`, e
não um temporizador próprio: a caminhada é puxada pela distância percorrida, então
desacelerar espaça as pisadas junto, de graça. `_drawn_frame` nasce em −1 e
não em 0 porque 0 é coluna válida — com zero ali o primeiro quadro não contaria
como troca e a pisada inicial se perderia. Virar no meio do ciclo não soa duas
vezes: redesenhar a mesma coluna em outra linha não é troca de coluna.

O resto do áudio está em [som.md](som.md).

## As folhas

A de caminhada é arte feita a mão (`entrada/referencias/sprites/`); **as outras três saem dela**, em `tools/generate_miro_states.py`, a partir do quadro 0 de cada linha. Redesenhar o personagem em código daria outro personagem, então tudo ali é deformação pequena mais objeto desenhado por cima.

**Parado respira**: a cabeça desce 0, 1, 2, 1 px no ciclo e o tronco a metade disso, com os pés parados. Dois pixels numa figura de 93 é 2% — aparece como peito subindo e descendo; três já lê como agachamento. A compressão se reparte entre pescoço e cintura para não abrir um degrau no pescoço.

**A picareta nasce da luva**, cujo centroide foi medido linha a linha, e não do centro da figura: ferramenta solta no meio do peito não parece segura por ninguém. O arco é curto de propósito — não existe pose de braço erguido na folha, então uma martelada de 180° deixaria a ferramenta descrevendo um círculo que o corpo não acompanha.

As três vistas **de costas** foram o caso difícil: o alvo fica do lado de lá do corpo, e um arco centrado nele some atrás das costas — a primeira versão saiu com quatro quadros sem ferramenta nenhuma. Nelas o arco corre na **margem**, do lado da mão que segura, e só o trecho que cruza o corpo fica escondido.

**O golpe é do corpo, não só da ferramenta.** A primeira versão deixava o boneco parado com a picareta girando ao lado, e foi recusada. Hoje o gesto tem três partes, todas deformações por **linha** ou por **bloco** — nunca rotação, que esfarrapa o contorno de um pixel que a arte inteira usa:

| Parte | O que faz | Quanto |
|---|---|---|
| Inclinação | cisalhamento por linha, pivô no chão | 8 px no topo da cabeça, ~2 na mão, 0 nas botas |
| Agachamento | a mesma compressão da respiração | 4 px no impacto — o que lá seria agachamento, aqui é o golpe |
| Braço | a mão sobe, encurtando o braço | 7 px no quadro erguido, 0 no impacto |

**A mão nunca desce abaixo da origem.** Subir encurta o braço — que é o que o cotovelo faz — e a luva se sobrepõe ao antebraço sem deixar falha; descer abriria um vão entre o punho e a manga, que lê como braço descolado. Por isso o **impacto é o zero da escala**: no golpe o braço está estendido, e os outros três quadros o recolhem.

A mão é achada sozinha, por preenchimento a partir do centroide da luva, e não por caixa medida vista a vista. Três detalhes nasceram de erros vistos na tela, nessa ordem:

- A faixa de vermelho aceita **do escuro ao realce claro**. Parando no vermelho médio, a sombra da manga ficava para trás e aparecia no lugar antigo como um **anel vazado** ao lado do braço.
- Mas o preenchimento **não aceita o quase-preto**: o contorno do desenho é um fio contínuo da luva até a bota, e aceitá-lo fazia o preenchimento correr por ele e tomar a coxa. O contorno entra depois, por crescimento, que não propaga. Uma caixa em volta da mão é a trava final.
- A margem apagada é **maior que a colada, e só para baixo**. A mão sobe, então o rastro fica embaixo; apagar a mesma margem por cima comia o antebraço e a luva subia deixando um vão. O que escapa disso, uma varredura de ilhas remove.

**A mão é recolocada por cima da ferramenta**, com as mesmas deformações. A empunhadura é larga o bastante para cobrir o punho, e com a mão por baixo o quadro saía com um bloco vermelho no lugar dela — ninguém segurando coisa nenhuma.

A célula da folha de trabalho é **100×110**, e não 70×100: a picareta alcança 30 px e a cabeça da ferramenta cairia fora nas vistas laterais. O chão e o centro horizontal são os mesmos, então só o `offset` muda — e é por isso que `_apply_sheet()` troca textura e deslocamento juntos.

**Dormindo**, os olhos são fechados sobre caixas medidas na folha (preenche de pele, risca uma pálpebra) e o **cobertor** entra por cima. O cobertor não é enfeite: deitado de costas, o desenho das pernas em pé continuaria ali e leria como alguém de pé visto de cima. Coberto, some. O vulto do corpo por baixo do pano é o que separa cobertor de caixa.

