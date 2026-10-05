# Scraptronaut — Grid e módulos da estação Lastro

Este documento consolida as decisões aprovadas para a estrutura modular da estação. As medidas são expressas em células quadradas do grid. A dimensão de cada célula em pixels será definida posteriormente.

## 1. Estrutura básica

O jogador expande a estação escolhendo qual módulo construir em uma posição disponível. Todos os módulos usam o mesmo tamanho e o mesmo alinhamento de conexões.

| Elemento | Medida ou regra |
|---|---|
| Interior utilizável | 10×10 células |
| Módulo isolado, incluindo paredes | 12×12 células |
| Bloco de parede | 1×1 célula |
| Espessura das paredes | Uma célula |
| Porta comum | Duas células contíguas na linha da parede |
| Circulação reservada | Duas células de largura |
| Passo de encaixe entre módulos | 11 células |

O interior de 10×10 é cercado por uma parede de uma célula em cada lado. Por isso, o módulo isolado ocupa 12×12, e não 10×10 incluindo as paredes.

As paredes seguem rigorosamente as linhas e colunas do grid. Não há deslocamentos, blocos inclinados, pilares que aumentem a espessura ou diferenças de escala entre módulos.

## 2. Paredes compartilhadas

Dois módulos adjacentes compartilham uma única linha de parede. Não se colocam duas paredes lado a lado.

Consequentemente, a origem do módulo vizinho fica 11 células distante da origem do primeiro. A última coluna ou linha de um coincide com a primeira do outro.

Exemplo horizontal, com coordenadas inteiras:

- Módulo A: colunas 0 a 11; interior nas colunas 1 a 10.
- Módulo B: colunas 11 a 22; interior nas colunas 12 a 21.
- A coluna 11 é a parede compartilhada.
- Uma porta nessa coluna conecta diretamente os dois interiores.

Uma fileira de `n` módulos ocupa `11 × n + 1` células, contando as paredes externas. Dois módulos ocupam 23 células; três ocupam 34.

A parede compartilhada deve existir como uma única estrutura no mapa. Sua abertura, fechamento e representação precisam ser consistentes para ambos os módulos.

## 3. Portas comuns e posições reservadas

Cada módulo possui uma posição padronizada de porta no centro de cada lado. Portas comuns ocupam duas células.

Usando coordenadas locais de 0 a 11:

| Lado | Células da porta |
|---|---|
| Norte | (5, 0) e (6, 0) |
| Sul | (5, 11) e (6, 11) |
| Oeste | (0, 5) e (0, 6) |
| Leste | (11, 5) e (11, 6) |

Uma porta horizontal ocupa 2×1 células. Uma porta vertical ocupa 1×2. A espessura continua sendo de uma célula.

Quando não existe conexão naquele lado, as células reservadas podem continuar como parede. O caminho interno até a futura porta permanece livre. Equipamentos não podem ocupar esse caminho apenas porque a porta ainda não foi aberta.

Na planta, portas conectadas são passagens entre pisos. Nenhum teto, viga, equipamento ou parede bloqueia sua circulação.

## 4. Dois padrões de organização interna

### Padrão A — Quatro cantos

Usado por **oficina de desmontagem, pátio e armazém**.

O interior possui quatro áreas de instalação de 4×4. Uma cruz de circulação com largura de duas células separa essas áreas e conecta as quatro posições de porta.

| Área | Colunas locais | Linhas locais | Tamanho |
|---|---|---|---|
| Noroeste | 1 a 4 | 1 a 4 | 4×4 |
| Nordeste | 7 a 10 | 1 a 4 | 4×4 |
| Sudoeste | 1 a 4 | 7 a 10 | 4×4 |
| Sudeste | 7 a 10 | 7 a 10 | 4×4 |

A circulação ocupa as colunas 5 e 6 e as linhas 5 e 6 do interior. São 64 células disponíveis para instalações e 36 células de circulação reservada, totalizando as 100 células internas.

As áreas de instalação delimitam o espaço máximo disponível; não representam objetos que obrigatoriamente preencherão todo o canto. Um equipamento pode ocupar uma parte da área, deixando piso no restante.

Objetos e suas áreas necessárias de operação devem caber nesse padrão sem bloquear a cruz de circulação.

### Padrão B — Área central

Usado por **prensa e hangar**.

Uma área de instalação de 6×6 fica no centro, cercada por circulação de duas células de largura. Essa faixa permite acessar o equipamento central e alcançar as portas.

| Área | Colunas locais | Linhas locais | Tamanho |
|---|---|---|---|
| Instalação central | 3 a 8 | 3 a 8 | 6×6 |

São 36 células para a instalação central e 64 para circulação, totalizando as 100 células internas.

O equipamento pode ocupar menos que 6×6. A prensa e seu encaixe de moldes devem ficar dentro dessa área; a nave estacionada também deve respeitá-la. O portão externo do hangar constitui a exceção descrita abaixo.

## 5. Exceção do hangar

O hangar tem um portão externo de **cinco células contíguas**, alinhado ao eixo da nave. Ele substitui a porta comum do lado escolhido para saída.

Esse lado não permite encaixar módulos. A saída para o espaço precisa permanecer desobstruída.

Na configuração inicial:

- O portão fica na parede leste do hangar.
- Ocupa as células (11, 3), (11, 4), (11, 5), (11, 6) e (11, 7).
- A nave aponta para leste, com o nariz em direção ao portão.
- O eixo vertical da nave e do portão coincide na coordenada local 5,5, considerando as células como intervalos entre coordenadas.
- A conexão interna com o pátio continua sendo uma porta comum de duas células na parede oeste.

Como o portão tem largura ímpar e o módulo tem dimensão par, o portão fica deslocado meia célula do centro geométrico do módulo. O alinhamento aprovado é com a nave, preservando as cinco células inteiras do portão.

A circulação lateral de duas células é uma regra de organização do hangar estacionado. A rota de movimentação da nave até o portão é uma função específica desse módulo e não uma conexão comum entre salas.

## 6. Estação inicial

A planta aprovada usa cinco módulos em cruz:

```text
              ARMAZÉM
                 │
PRENSA ─────── PÁTIO ─────── HANGAR → saída para o espaço
                 │
               OFICINA
```

| Módulo | Padrão interno | Estado inicial | Organização |
|---|---|---|---|
| Pátio | Quatro cantos | Computador de Nilo quebrado | Terminal e projetor em uma área de canto, com circulação central livre. |
| Armazém | Quatro cantos | Quebrado | Duas prateleiras vazias e quebradas, uma em cada canto superior. Os dois cantos inferiores ficam livres para futuras prateleiras. |
| Oficina de desmontagem | Quatro cantos | Funcional | Equipamentos acessíveis a partir do interior da sala, com suas faces de uso voltadas para piso livre. |
| Prensa | Área central | Quebrada | Prensa com um encaixe retangular conectado à máquina para colocar moldes de peças. |
| Hangar | Área central | Disponível para a sucateira | Nave orientada para o portão externo de cinco células. |

Não há módulo de habitação nesta configuração inicial mais recente. Sua inclusão posterior pode ser discutida como expansão.

### Coordenadas da planta inicial

| Módulo | Origem X | Origem Y |
|---|---:|---:|
| Armazém | 11 | 0 |
| Prensa | 0 | 11 |
| Pátio | 11 | 11 |
| Hangar | 22 | 11 |
| Oficina | 11 | 22 |

A cruz cabe em uma área de 34×34 células. Os quatro cantos externos dessa área não contêm módulos e permanecem como espaço exterior.

## 7. Instalação e acesso aos objetos

- Objetos ficam dentro das áreas de instalação do respectivo padrão.
- Não é necessário ocupar toda a área; as células restantes podem ser piso.
- A face de interação de bancadas, fornos, terminais e máquinas precisa estar voltada para uma posição acessível ao personagem.
- A área de operação dos objetos não pode bloquear as passagens reservadas nem depender de acessar o outro lado de uma parede.
- O encaixe de moldes da prensa é uma parte visível e acessível da máquina.
- No armazém, as duas posições de futuras prateleiras continuam reservadas nos cantos inferiores.

## 8. Expansão da estação

O jogador escolhe um módulo e uma posição adjacente disponível. O encaixe respeita o passo de 11 células e o alinhamento das portas.

Ao construir:

1. Verificar se a posição não está ocupada e não bloqueia a saída do hangar.
2. Alinhar o novo módulo à mesma grade global.
3. Compartilhar a parede de contato com o módulo existente.
4. Abrir a passagem de duas células na posição padronizada.
5. Preservar os caminhos internos e as áreas de instalação dos módulos envolvidos.

Os padrões internos tornam as posições de conexão previsíveis, permitindo ao jogador montar a estação sem precisar deslocar equipamentos para abrir uma nova porta.

## 9. Pontos ainda a definir

- Tamanho de cada célula em pixels e escala dos personagens.
- Desenho final dos tiles de piso, parede e porta.
- Dimensões exatas de cada objeto e suas melhorias.
- Animação e funcionamento das portas e do portão.
- Regras para girar, mover ou remover módulos já construídos.
- Distância exterior necessária para manobra da nave e extensão do bloqueio de construção diante do hangar.
- Padrão interno dos demais módulos aprovados, além dos cinco iniciais.

Esses pontos permanecem abertos. As medidas da grade, os dois padrões, as paredes compartilhadas e o portão de cinco células do hangar estão definidos.
