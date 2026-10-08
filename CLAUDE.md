# Scraptronaut

Jogo 2D em pixel art, perspectiva top-down em três quartos, feito em **Godot 4.7** com **GDScript**.

O jogador é um sucateiro (Lira / Miro) que atravessa acidentalmente uma fenda espacial, cai numa estação abandonada (Lastro) e precisa recuperá-la, expandir o alcance da nave e reconstruir a tecnologia de travessia para tentar voltar à Terra — onde há uma meia na lavanderia.

**Estado:** protótipo jogável da Estação Lastro — movimentação, cenário, construção livre de planta e o ciclo de trabalho/descanso do personagem. Mecânica de jogo (módulos como entidade, energia da estação, naves, regiões) continua sem implementação.

---

## Este arquivo é um índice

A documentação está dividida por assunto. **Abrir só o que o pedido exige** — não carregar tudo.

### Arquitetura — como o jogo funciona hoje

| Para mexer em… | Abrir |
|---|---|
| qualquer coisa: árvore de cenas, quem fala com quem, quem come o input | [`docs/arquitetura/README.md`](docs/arquitetura/README.md) |
| planta, casco, tiles, máscaras, portas, buracos, camadas de desenho | [`docs/arquitetura/mapa-da-estacao.md`](docs/arquitetura/mapa-da-estacao.md) |
| ferramentas, cursor, arrasto, canteiro, estágios, demolição | [`docs/arquitetura/construcao-e-obra.md`](docs/arquitetura/construcao-e-obra.md) |
| energia do personagem, custo de obra, martelada, dia, cama | [`docs/arquitetura/trabalho-energia-e-dia.md`](docs/arquitetura/trabalho-energia-e-dia.md) |
| movimento, estados, folhas de sprite, quadros de cada pose | [`docs/arquitetura/personagem-e-animacao.md`](docs/arquitetura/personagem-e-animacao.md) |
| HUD, barra de energia, menu de pausa, zoom das câmeras | [`docs/arquitetura/interface-e-camera.md`](docs/arquitetura/interface-e-camera.md) |
| música, efeito sonoro, volume, o autoload de áudio | [`docs/arquitetura/som.md`](docs/arquitetura/som.md) |

### Padrões — como escrever código aqui

| Para… | Abrir |
|---|---|
| escrever ou revisar `.gd`: nomes, tipagem, ordem, comentários, idioma | [`docs/padroes/codigo-gdscript.md`](docs/padroes/codigo-gdscript.md) |
| criar nó/cena/sistema novo, ou propor refatoração | [`docs/padroes/arquitetura.md`](docs/padroes/arquitetura.md) |
| mexer em `project.godot`, renderização, resolução, filtro de textura | [`docs/configuracao-godot.md`](docs/configuracao-godot.md) |

### Fluxo — como operar o projeto

| Para… | Abrir |
|---|---|
| rodar, capturar screenshot, ver o modo de construção | [`docs/fluxo/rodar-e-capturar.md`](docs/fluxo/rodar-e-capturar.md) |
| regenerar arte, tileset ou o esqueleto da cena | [`docs/fluxo/geradores-e-assets.md`](docs/fluxo/geradores-e-assets.md) |
| rodar ou escrever teste | [`docs/fluxo/testes.md`](docs/fluxo/testes.md) |

### Decisões

| | |
|---|---|
| o que é **fixo** e exige decisão explícita para mudar | [`docs/decisoes/aprovadas.md`](docs/decisoes/aprovadas.md) |
| o que está **aberto** — proposta, não design | [`docs/decisoes/abertas.md`](docs/decisoes/abertas.md) |

### Design — a fonte de verdade

Consultar antes de propor qualquer coisa de história ou mecânica.

| Documento | Conteúdo |
|---|---|
| `docs/Historia-completa-Scraptronaut.md` | História completa, nomes definidos, personagens, os dois finais, pontos narrativos abertos |
| `docs/Mecanicas-Scraptronaut.md` | Módulos da estação, matérias-primas, energia/combustível, naves, reserva de retorno, as cinco regiões |
| `docs/Mapa-exploracao-Scraptronaut.md` | Mapa radial: locais, raios e ângulos de cada região; ampliação de 2026-10-02 |
| `docs/Mapa-radial-Scraptronaut.html` | Visualização interativa do mapa radial |
| `docs/Estacao-Lastro-grid-e-modulos.md` | Planta da Lastro em grid. **Conflita com o código** — ver `docs/decisoes/abertas.md` |

**Não alterar a história nem as mecânicas sem pedido explícito.** Esses documentos registram decisões de uma discussão em andamento; mexer num ponto exige saber se ele era aprovado ou aberto.

---

## Skills — não precisam de doc carregada

Para estas tarefas existe skill própria. **Invocar a skill em vez de ler documentação**: ela traz só o que a tarefa pede.

| Tarefa | Skill |
|---|---|
| desenhar ou alterar sprite, tile, atlas, ícone | `pixel-art` |
| rodar o jogo, tirar screenshot, montar cena de captura | `rodar-e-capturar` |
| mudar a planta inicial da estação | `editar-planta` |
| registrar mudança no `CHANGELOG.md` e comitar | `registrar-mudanca` |

## Agents — trabalham em contexto próprio

| Quando | Agent |
|---|---|
| revisar `.gd` contra os padrões do projeto | `revisor-gdscript` |
| iterar arte até ficar certa na tela (gerar → capturar → olhar) | `artista-pixel` |
| conferir se a documentação ainda descreve o código | `revisor-de-docs` |

---

## Comandos mais usados

| Comando | O que faz |
|---|---|
| `npm run check` | Smoke test headless; **sai com 1** se houver erro de script ou cena |
| `npm run test` | 190 verificações de planta, regras, obra, mira, fonte e interface |
| `npm run shot` | Salva PNG do viewport em `screenshots/` |
| `npm run play` | Abre o jogo numa janela |

A lista completa está em [`docs/fluxo/rodar-e-capturar.md`](docs/fluxo/rodar-e-capturar.md).

---

## Como responder a pedidos

1. **Localizar o assunto** no índice acima e abrir **só** o documento daquele assunto. Se existe skill para a tarefa, usar a skill em vez de ler doc
2. Dizer se o ponto é **aprovado** ou **aberto**. Se aberto, apresentar como proposta e esperar decisão
3. Não implementar mecânica, não criar cena, não alterar a narrativa sem pedido explícito
4. Se um pedido conflita com uma decisão aprovada, apontar o conflito antes de executar
5. Ao mexer em código ou cena, verificar com `npm run check` antes de dizer que está pronto — e com `npm run shot` quando a mudança for visual
6. **Quem mexe no código mexe na documentação do mesmo assunto.** A doc deste projeto registra *por que* cada escolha foi feita e o que já foi recusado; mudança que deixa a doc mentindo custa mais do que a mudança rendeu
7. **Todo commit entra no [`CHANGELOG.md`](CHANGELOG.md).** Usar a skill `registrar-mudanca`

## Confirmar a API antes de escrever

Documentação **4.7** pelo Context7 (`/websites/godotengine_en_4_7`). Não assumir assinaturas de memória nem reaproveitar padrões de Godot 3.x.
