# Changelog

Todas as mudanças relevantes do Scraptronaut. Formato baseado em
[Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); versionamento por
[SemVer](https://semver.org/lang/pt-BR/), com a ressalva de que **antes do 1.0.0
o jogo é protótipo** e `0.x` pode quebrar o que quiser.

## Como preencher

**Todo commit entra aqui**, em `[Não lançado]`, antes de comitar. A skill
`registrar-mudanca` faz isso.

Cada entrada responde o que mudou **para quem joga ou para quem mexe no código** —
não o que mudou no arquivo. `git log` já conta os arquivos; o changelog conta a
consequência.

| Seção | Para |
|---|---|
| `Adicionado` | funcionalidade que não existia |
| `Alterado` | comportamento que existia e mudou |
| `Corrigido` | bug |
| `Removido` | o que saiu |
| `Equilíbrio` | número de jogo recalibrado — custo, ritmo, alcance |
| `Interno` | refatoração, doc, tooling, teste: nada que o jogador note |

Quando um número de equilíbrio muda, a entrada diz **de quanto para quanto** e
**por quê** — é essa a informação que o `git log` não guarda e que o próximo
recalibre vai procurar.

---

## [Não lançado]

### Interno

- `CLAUDE.md` virou índice: a documentação foi dividida em `docs/arquitetura/`,
  `docs/padroes/`, `docs/fluxo/` e `docs/decisoes/`, de 482 linhas num arquivo
  para ~120 de roteamento. Cada assunto se carrega sozinho, e um pedido sobre
  sprite não traz mais a regra de obra para a janela de contexto
- Padrões de arquitetura documentados em `docs/padroes/arquitetura.md`: seis
  princípios tirados dos guias *Best Practices* do Godot 4.7 e um diagnóstico de
  nove itens do código atual, com evidência e ordem sugerida. **Nenhum item foi
  implementado** — são propostas e esperam decisão
- Convenções de escrita em `docs/padroes/codigo-gdscript.md`, agora com a ordem
  oficial completa do GDScript e a regra de comentário do projeto
  (decisão + motivo + o que foi recusado)
- Skills: `pixel-art`, `rodar-e-capturar`, `editar-planta`, `registrar-mudanca`
- Agents: `revisor-gdscript`, `artista-pixel`, `revisor-de-docs`
- Este changelog

### Corrigido

- A tabela de comandos dizia que `npm run play` abre numa janela; ele abre em
  tela cheia desde que `-Fullscreen` entrou, e quem quer janela usa
  `npm run play:window`
- A referência a `docs/Estacao-Lastro-grid-e-modulos.md` dizia que o documento é
  a entrada de `tools/construir_estacao.gd`. Não é mais: a planta mora nas
  constantes de `mapa_estacao.gd` desde 2026-10-03
- `.gitignore` ignorava a documentação nova: a negação era `!docs/*.md`, que só
  alcança o primeiro nível, e `docs/arquitetura/`, `padroes/`, `fluxo/` e
  `decisoes/` ficariam fora do commit **em silêncio** — o índice de `CLAUDE.md`
  apontaria para o vazio em qualquer clone. Os quatro diretórios agora são
  negados explicitamente; as referências visuais soltas seguem ignoradas

---

## [0.3.0] — 2026-10-05

### Adicionado

- Energia do personagem: `Jogador.ENERGIA_MAXIMA` (100) é **um dia de trabalho**.
  Andar e explorar não gastam nada; só obra gasta
- `F` trabalha no canteiro mais perto, `E` dorme na cama. A tela apaga, o dia
  vira, a energia volta cheia no meio da noite
- Barra de energia em divisões de `>`, montada de peças
  (`tools/gerar_interface.py`). **O número de divisões sai da energia máxima** —
  uma melhoria futura ganha divisões sem arte nova
- Quatro estados de animação do personagem — parado, andando, trabalhando,
  dormindo — derivados da folha de caminhada feita a mão
  (`tools/gerar_miro_estados.py`)
- A cama: nó próprio, duas células em pé, encostada na parede norte do armazém
- Zoom no jogo pela roda do mouse, entre 0,26 e 0,62

### Alterado

- **Obra deixou de ter relógio.** Antes cada estágio durava
  `SEGUNDOS_POR_ESTAGIO` e passava sozinho enquanto o jogador fazia outra coisa;
  agora um estágio só fecha quando alguém bate trabalho naquela célula
- Demolir custa o mesmo trabalho que construir, e é o mesmo canteiro andando
  para trás
- A planta inicial encolheu de 44×30 para 30×21 células — mesma topologia de
  seis salas, menos da metade da área

### Equilíbrio

- Custo de obra caiu seis vezes: piso de 75 para **12,5** por célula. A escala
  anterior deixava o dia acabar antes de uma única célula fechar. A proporção
  não mudou — expandir segue sendo a obra cara, parede a barata
- Oito quadrados de chão por barra cheia de energia. Uma porta inteira custa o
  mesmo que um quadrado
- Ritmo em `MARTELADAS_POR_QUADRADO` (12), e `ENERGIA_POR_SEGUNDO` passou a ser
  **derivado** dele: mudar a cadência da animação sem mexer no ritmo faria a
  conta de marteladas mentir em silêncio. Terceira calibragem — 141 marteladas
  por quadrado foi recusado por acabar rápido demais, 24 por repetição

## [0.2.0] — 2026-10-05

### Adicionado

- Protótipo jogável da Estação Lastro: movimentação em oito direções, câmera,
  campo estelar procedural, menu de pausa
- Mapa **livre, célula a célula**, com o casco derivado a cada reconstrução.
  Quem pinta piso ganha parede de graça
- Modo de construção (`TAB`): expandir, parede, porta, portão e demolir, com
  arrasto em retângulo, validação em lote tudo-ou-nada e confirmar/cancelar
- Canteiro de obra em estágios, com fita de demarcação indexada por máscara
- Portas que abrem por proximidade; portão do hangar no `E`
- Onze atlas de tile gerados em código (`tools/gerar_tiles_estacao.py`), casco e
  borda indexados por máscara de 8 bits — 256 variações cada
- Runner `tools/run.ps1` e os atalhos de `package.json`; captura de tela, que é
  o único jeito de ver o jogo sem abrir o editor
- `tools/testar_estacao.gd`, que sai com o número de falhas

### Alterado

- Demolir piso no meio de uma sala passou a deixar **vão aberto para o espaço
  com parede de verdade em volta**. Terceira versão: bloco de casco maciço foi
  recusado ("parede nasceu do nada") e rombo de borda rasgada também ("não saiu
  dessa fase")

## [0.1.0] — 2026-10-02

### Adicionado

- Projeto Godot 4.7, perfil GL Compatibility
- Documentos de design versionados: história completa, mecânicas, mapa radial de
  exploração e a planta da Lastro em grid
- `CLAUDE.md`

[Não lançado]: https://github.com/renan-prado/scraptronaut/compare/e17fc9e...HEAD
[0.3.0]: https://github.com/renan-prado/scraptronaut/commit/e17fc9e
[0.2.0]: https://github.com/renan-prado/scraptronaut/commit/7a5b0c0
[0.1.0]: https://github.com/renan-prado/scraptronaut/commit/9fd6d45
