# Rodar e capturar o jogo

Carregar para rodar, testar ou tirar screenshot sem abrir o editor.

> A skill `rodar-e-capturar` cobre o mesmo terreno em formato de receita. Prefira
> a skill quando o objetivo for **executar**; este documento é a referência.

## Os comandos

O Godot fica em `C:/tools/godot/` (`godot.exe` e `godot_console.exe`, nomes estáveis — para atualizar, trocar os dois arquivos). A pasta está no `PATH` do usuário.

`tools/run.ps1` é o runner; `package.json` só embrulha os modos em `npm run`:

| Comando | O que faz |
|---|---|
| `npm run play` | Abre o jogo numa janela |
| `npm run play:full` | Abre em tela cheia |
| `npm run check` | Smoke test headless; **sai com código 1** se a saída tiver erro de script ou cena |
| `npm run test` | Roda `tools/testar_estacao.gd`: colisão da planta, regras de construção, portão, câmeras. Sai com o número de falhas |
| `npm run build:estacao` | Regenera `recursos/tileset_estacao.tres` e `cenas/estacao.tscn` |
| `npm run shot` | Salva um PNG do viewport em `screenshots/` |
| `npm run shot:long` | Igual, com 180 frames, para a cena assentar antes da captura |
| `npm run shot:planta` | Captura com zoom 0.16, que cabe a estação inteira — é assim que se confere uma mudança de planta |
| `npm run editor` | Abre o editor do Godot no projeto |

Flags livres exigem chamar o script direto: `./tools/run.ps1 -Screenshot -Output screenshots/station.png -Frames 45`. Parâmetros: `-Scene`, `-Headless`, `-Screenshot`, `-Fullscreen`, `-Script`, `-Output`, `-Frames`, `-Zoom`, `-Godot`. `-Fullscreen` só vale no modo de jogo — com `-Headless` ou `-Screenshot` o script recusa.

A interface do modo de construção só aparece depois de alguém apertar TAB, então `capture.gd` não a alcança. Para vê-la: `./tools/run.ps1` e apertar TAB, ou `godot --path . -s tools/capturar_construcao.gd -- <saída> <ferramenta> <x> <y> <zoom> [rx ry rw rh]`, que entra no modo, aponta o cursor para a célula pedida e, com o retângulo opcional, ainda expande a estação antes de capturar.

Com ferramenta `>= 0` o retângulo entra **pela mesma função que o mouse usa**, já dentro do modo, então a captura mostra a barra como o jogador a veria — com o contador de alterações e o botão de cancelar aceso. Ferramenta de peça fixa ignora o tamanho do retângulo e usa o canto dele como célula do cursor; com **dois** opcionais, o primeiro vira a rotação da peça em vez de fingir um arrasto.

Ferramentas negativas não entram no modo e põem o **jogador** na célula pedida: `-1` captura o jogo normal — é assim que se confere porta abrindo por proximidade, que a câmera parada de `capture.gd` nunca mostra; `-2` faz o mesmo e abre o menu de pausa; `-3` põe a picareta batendo no canteiro mais perto; `-4` deita na cama. Nos dois últimos o nó `Trabalho` é **desligado** antes: ele lê a tecla `F` a cada quadro, e tecla física não dá para fingir.

Os quatro argumentos opcionais são um retângulo onde a **mesma ferramenta** é aplicada antes da captura, então dá para montar qualquer cena: expandir, erguer parede, ou abrir um vão com a ferramenta 5. Com ferramenta negativa o retângulo é sempre expansão, aplicada direto no mapa. Um décimo argumento congela a obra num estágio (0, 1 ou 2). Com apenas **dois** opcionais o script finge um arrasto em curso, que é o único jeito de ver o retângulo de seleção desenhado.

Três armadilhas já encontradas, todas tratadas no script:

- **`npm run` engole flags** no estilo `-Frames` e repassa só o valor solto, que cairia como nome de cena e rodaria errado em silêncio. Por isso `run.ps1` recusa um `-Scene` que não termine em `.tscn`, e por isso as variantes viraram scripts nomeados.
- **`-Screenshot` não combina com `-Headless`**: sem janela o renderizador é dummy e o PNG sai em branco. O script bloqueia a combinação.
- **PowerShell 5.1 embrulha o stderr de exe nativo em `ErrorRecord`**, o que viraria erro terminante sob `$ErrorActionPreference = "Stop"` antes de qualquer diagnóstico. O modo headless relaxa a preferência só em volta da chamada.

A captura é o único jeito de eu **ver** o jogo — a CLI do Godot não tira screenshot sozinha; `tools/capture.gd` instancia a cena, espera N frames, aguarda `RenderingServer.frame_post_draw` e salva o PNG. `screenshots/` está no `.gitignore`.

