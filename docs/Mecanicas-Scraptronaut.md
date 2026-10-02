# Scraptronaut — Mecânicas em desenvolvimento

Este documento registra as decisões da discussão. Pontos explicitamente indicados como abertos ainda precisam ser definidos.

## Plataforma e engine

- Engine escolhida: **Godot**.
- Direção visual: jogo 2D em pixel art, com perspectiva top-down em três quartos.
- O projeto passa a ser pensado como jogo desenvolvido em engine, sem a obrigação inicial de rodar no navegador.
- Publicação na Steam é uma possibilidade futura, ainda sem compromisso de lançamento.
- Versão da engine, linguagem e detalhes de implementação serão definidos posteriormente. GDScript foi sugerido, mas ainda não constitui uma decisão do projeto.
- A etapa atual continua sendo o desenvolvimento da ideia, da narrativa, das mecânicas e do balanceamento.

## Estação inicial

| Módulo | Estado inicial e função |
|---|---|
| Pátio central | Conecta os módulos; computador de Nilo começa quebrado. |
| Habitação | Quarto inicial de Lira/Miro. |
| Hangar | Abriga a sucateira e permite os primeiros reparos. |
| Oficina de desmontagem | Disponível para recuperar materiais e peças prontas das sucatas. |
| Armazém | Começa quebrado. |
| Prensa | Começa quebrada. |

A oficina fornece peças recuperadas com resultados variáveis e controle limitado. Consertar a prensa permite fabricar peças específicas usando materiais e moldes. Objetos avariados podem ser desmontados ou guardados para reparo.

## Módulos aprovados

- Pátio central.
- Corredor.
- Armazém.
- Hangar.
- Oficina de desmontagem.
- Prensa.
- Refinaria energética.
- Fábrica de eletrônicos.
- Habitação.
- Módulo de Dricono, destinado ao Macrovolvulador-extremamicrobacteriano.
- Módulo de estabilização, ligado à abertura final da fenda.

Custos, funções detalhadas, níveis de melhoria e regras de expansão ainda serão definidos.

## Matérias-primas

Lista candidata aprovada como base para discussão: sucata metálica, alumínio, cobre, ferro, silício, carbono, titânio, ouro e um material Asteriano ainda sem nome.

Os usos específicos desses materiais permanecem abertos. Sucata continua necessária ao longo da progressão, mesmo depois da descoberta de materiais mais valiosos.

## Energia e combustível

O sistema usa uma única unidade de energia. Objetos diferentes podem fornecer quantidades diferentes de resíduo energético; sua natureza e seu nome ainda serão definidos.

A concentração do combustível evolui conforme o mineral processado e a capacidade da refinaria. Os estágios discutidos são bruto, refinado e concentrado. Receitas e rendimentos permanecem abertos.

Combustível mais concentrado permite armazenar mais energia no mesmo tanque. O alcance também depende do tamanho do tanque e da eficiência da nave: combustível avançado não elimina as diferenças entre modelos.

## Naves

| Nave | Especialidade |
|---|---|
| Sucateira | Nave inicial. |
| Cargueira | Melhor para coletar perto da estação; muita carga e baixa velocidade. |
| Exploradora | Rápida e com pouco espaço de carga. |
| Planetária | Única capaz de pousar e decolar dos planetas. |
| De travessia | Preparada para passar pela fenda. |

Capacidades, custos e melhorias ainda serão definidos. O peso da carga influencia o alcance, especialmente nas operações da cargueira.

## Reserva de retorno e emergências

**Decisão aprovada:** a nave preserva uma reserva calculada para voltar à Lastro. Ao atingir esse limite, inicia o retorno automático, sem punição adicional nem perda de carga. Resgates pagos ficam reservados a imprevistos que impossibilitem o retorno normal.

### Cálculo da reserva

A nave calcula o combustível necessário para o trajeto de retorno, considerando a eficiência do motor e as condições relevantes da viagem. Na superfície de um planeta, o cálculo inclui decolagem e retorno à estação.

O painel apresenta três situações compreensíveis:

| Situação | Comportamento |
|---|---|
| Seguro | Há energia disponível para continuar explorando e voltar. |
| Reserva próxima | O jogador recebe aviso de que continuar levará ao limite da volta. Pode retornar manualmente. |
| Limite de retorno atingido | O piloto automático inicia a volta à Lastro usando a reserva. |

A reserva é o combustível necessário à volta, não uma fonte gratuita de energia. O jogador não fica à deriva por simplesmente explorar até o limite normal.

### Consequência do retorno automático

A expedição termina e a nave precisa ser reabastecida. O jogador conserva toda a carga e não recebe dano, multa ou perda adicional apenas por atingir a reserva. Achados que não conseguiu recolher ficam para outra viagem.

### Resgate por imprevistos

Quando um acidente ou perda inesperada de combustível impede o retorno, a nave pode emitir um sinalizador de resgate e ser rebocada até a estação.

O resgate tem um custo, que pode virar uma dívida paga em materiais ou serviços. A falta de recursos para pagar imediatamente não deve bloquear a continuidade do jogo. Valores, formas de pagamento e regras de acidentes ainda serão definidos.

Bobobacau pode assumir resgates em uma fase posterior, conforme sua participação e os equipamentos disponíveis. Os detalhes dessa função permanecem abertos.

### Viagens planetárias

Antes do pouso, o jogo informa se a nave possui energia suficiente para descer, decolar e voltar à Lastro. O custo da decolagem não deve ser uma surpresa descoberta apenas depois do pouso.

## Regiões de exploração e progressão

**Estrutura aprovada:** o mapa possui cinco regiões de alcance. A expansão por distância termina na terceira região planetária, onde fica Asterianos. Depois disso, a evolução continua por meio da exploração dos planetas e demais locais dessas mesmas regiões, reunindo recursos específicos para a travessia final.

| Ordem | Região | Papel na jornada |
|---|---|---|
| 1 | Vizinhança | Coletas iniciais e recuperação da estação: prensa, armazém e ativação de Nilo. |
| 2 | Campo de destroços | Destroços maiores, novos metais e equipamentos; preparação para ampliar a exploração. |
| 3 | Primeira região planetária | Descoberta do primeiro planeta e necessidade de construir a nave planetária para explorá-lo. |
| 4 | Segunda região planetária + Aurora | Novos planetas e recursos; encontro com a Morgon's em Aurora e recuperação de NILO 2. |
| 5 | Terceira região planetária + Asterianos | Última expansão de alcance convencional; encontro com Adonus e obtenção de conhecimento e apoio para a travessia. |

### Acesso e exploração

Alcançar uma região não significa conseguir explorar todos os seus locais imediatamente. A nave pode chegar perto de um planeta antes que o jogador tenha a nave planetária necessária para pousar. Áreas, recursos e equipamentos podem exigir ferramentas, melhorias, informações ou acordos obtidos posteriormente.

As condições exatas de acesso a cada região, distâncias, receitas e custos ainda serão definidos. A sequência discutida usa melhoria inicial de motor para chegar ao campo de destroços, combustível refinado para alcançar a primeira região planetária e avanços posteriores de nave e combustível para as duas regiões seguintes.

### Preparação final dentro do mapa conhecido

Depois de chegar a Asterianos, Adonus, Nilo e NILO 2 ajudam a identificar o que será necessário para construir o novo núcleo, instalar a estabilização da Lastro e preparar a nave de travessia.

Esses projetos exigem recursos específicos distribuídos pelas cinco regiões. Não é necessário acrescentar uma sexta região mais distante para concluir o jogo.

A nave de travessia é especializada em atravessar a fenda. O desafio final combina conhecimento, materiais, produção e colaboração dentro do espaço já alcançado.

### Possibilidades para revisitar locais

Os exemplos abaixo são propostas de desenvolvimento, ainda sem planetas ou recursos específicos definidos:

| Local | Possível motivo para revisitar |
|---|---|
| Planeta da primeira região | Uma ferramenta melhor permite extrair um recurso antes inacessível. |
| Planeta da segunda região | Um acordo com seus habitantes libera acesso a um recurso protegido. |
| Campo de destroços | Informações de NILO 2 permitem reconhecer um componente anteriormente considerado sucata comum. |
| Aurora | O apoio Asteriano permite recuperar equipamento antes mantido inacessível pela Morgon's. |
| Planeta da terceira região | Equipamentos avançados permitem explorar uma área perigosa. |

Sempre que possível, a primeira visita apresenta o obstáculo ou o achado inacessível. Ao obter a capacidade necessária, o jogador tem um motivo reconhecível para retornar.

### Organização do balanceamento

- Até Asterianos: calcular custos de expansão do alcance, capacidade de coleta e produção.
- Depois de Asterianos: calcular custos dos projetos finais e distribuir seus recursos pelas regiões existentes.
- Próximo passo: definir materiais e descobertas de cada região, depois receitas, rendimentos e quantidade esperada de expedições por conquista.

## Próximas definições

- Produtos que cada módulo consegue fabricar ou recuperar.
- Moldes, receitas e aplicações dos materiais.
- Rendimentos energéticos e concentrações de combustível.
- Capacidades e melhorias das naves.
- Custos e níveis dos módulos.
- Regras específicas dos imprevistos e resgates.
