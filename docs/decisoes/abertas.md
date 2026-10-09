# Propostas abertas

Não tratar como design nem implementar sem decisão. Lista completa em "Próximas
definições" (`Mecanicas-Scraptronaut.md`) e "Pontos ainda abertos para
desenvolvimento" (`Historia-completa-Scraptronaut.md`). O que já está fechado
está em [aprovadas.md](aprovadas.md).

**Arquitetura do código**
- O diagnóstico de [../padroes/arquitetura.md](../padroes/arquitetura.md) levantou **nove itens** com evidência em `arquivo:linha` — da divisão de `station_map.gd` (1.346 linhas, cinco responsabilidades) à adoção de InputMap. Todos são propostas, nenhum foi implementado, e o documento traz uma ordem sugerida. A aprovação é **por item**, não em bloco

**Conflito aberto entre o código e o design**
- `docs/Estacao-Lastro-grid-e-modulos.md` define interior de 10×10, módulo de 12×12 e passo de encaixe de 11 células. O mapa implementado é **livre, célula a célula**, a pedido explícito do usuário em 2026-10-03. As duas coisas não convivem: ou o documento passa a descrever construção livre, ou o código volta a encaixar módulos. **Nada foi decidido, e o documento não foi alterado.** O que sobreviveu da planta aprovada: célula de 64 px, parede de uma célula, porta comum de duas células e portão do hangar de cinco
- `scripts/hangar_gate.gd` e `assets/tiles/` (`wall.png`, `door.png`, `door_vertical.png`, `hangar_gate.png`, `floor.png`) ficaram **sem uso**: a lógica do portão virou tile e a arte virou `assets/tiles/station/`. `tools/generate_tiles.py` ainda os regenera. Apagar ou manter é decisão pendente
- **A energia do personagem não está em documento nenhum.** Foi pedida e implementada em 2026-10-05 (`Player.MAX_ENERGY`, um dia de trabalho), mas `docs/Mecanicas-Scraptronaut.md` só descreve a energia **da estação**, que é a unidade única aprovada. São duas coisas diferentes com o mesmo nome, e o documento não foi alterado

**Técnico**
- **O portão de nave ainda é instantâneo.** Todas as outras construções abrem canteiro e custam trabalho; o portão aparece pronto no clique, e só a demolição dele cobra. Tornar o portão um canteiro exige que o canteiro viva no **casco**, que não está em `_cells` — hoje abrir obra ali transformaria a célula de casco em interior e a planta cresceria em volta dela
- **A cama não é conhecida pelo mapa.** Demolir o chão sob ela é aceito e deixa a cama flutuando sobre o vácuo. Fazer o mapa reservar as células da cama é mudança pequena, mas ninguém pediu
- **O dia não volta sozinho.** Não há ciclo de dia/noite nem relógio de mundo: `day` só avança quando o jogador dorme, e a energia só volta aí. Se dormir vai passar a ter outros efeitos (obras de terceiros, prazo da lavanderia, decaimento), isso é decisão de design
- Resolução base do viewport (p. ex. 640×360) e modo de stretch definitivo — para pixel art a documentação do Godot 4.7 recomenda stretch `viewport` com scale mode `integer`; o projeto hoje usa `canvas_items` + `expand`
- Adotar `Nearest` como filtro de textura padrão do projeto, substituindo o `texture_filter` repetido nó a nó em `station.tscn`
- Remover ou manter as configurações 3D herdadas do editor
- Autoloads, arquitetura de cenas e formato de save — nada decidido. A estrutura de pastas já se firmou na prática (`scenes/`, `scripts/`, `assets/`, `resources/`, `tools/`, `docs/`), mas nunca foi decidida formalmente
- O que entra no versionamento: `docs/`, e também `assets/` e `resources/`, que são gerados por `tools/` e poderiam ser reconstruídos em vez de comitados
- Se o protótipo atual (`station.tscn` e `scripts/`) é base para o jogo ou descartável

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

