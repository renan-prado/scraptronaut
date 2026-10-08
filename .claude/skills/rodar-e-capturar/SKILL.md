---
name: rodar-e-capturar
description: Rodar o jogo Scraptronaut, tirar screenshot e montar cena de captura sem abrir o editor do Godot. Use quando precisar executar, testar, validar visualmente uma mudança, ver o modo de construção, ver a picareta batendo, o menu de pausa, a planta inteira, ou quando run.ps1 / npm run der erro.
---

# Rodar e capturar

Captura é o **único jeito de ver este jogo** sem abrir o editor: a CLI do Godot
não tira screenshot sozinha. `tools/capture.gd` instancia a cena, espera N
quadros, aguarda `RenderingServer.frame_post_draw` e salva o PNG.
`screenshots/` está no `.gitignore`.

O Godot fica em `C:/tools/godot/` (`godot.exe` e `godot_console.exe`), e a pasta
está no `PATH`.

## Receitas

| Quero | Comando |
|---|---|
| jogar | `npm run play` (janela) · `npm run play:full` (tela cheia) |
| saber se quebrei algo | `npm run check` — **sai com 1** se houver erro de script ou cena |
| rodar os testes | `npm run test` — sai com o número de falhas |
| ver a tela | `npm run shot` → `screenshots/` |
| ver a tela depois de assentar | `npm run shot:long` (180 quadros) |
| **conferir mudança de planta** | `npm run shot:planta` (zoom 0,16: cabe a estação inteira) |
| regenerar tileset e esqueleto da cena | `npm run build:estacao` |
| abrir o editor | `npm run editor` |

Flag solta exige chamar o script direto:

```powershell
./tools/run.ps1 -Screenshot -Output screenshots/station.png -Frames 45
```

Parâmetros: `-Scene`, `-Headless`, `-Screenshot`, `-Fullscreen`, `-Script`,
`-Output`, `-Frames`, `-Zoom`, `-Godot`.

## As três armadilhas (todas já tratadas em run.ps1)

1. **`npm run` engole flags** no estilo `-Frames` e repassa só o valor solto, que
   cairia como nome de cena e rodaria errado em silêncio. Por isso `run.ps1`
   recusa um `-Scene` que não termine em `.tscn`, e por isso as variantes viraram
   scripts nomeados. **Não tente passar flag por `npm run` — chame o `.ps1`.**
2. **`-Screenshot` não combina com `-Headless`**: sem janela o renderizador é
   dummy e o PNG sai em branco. O script bloqueia a combinação. `-Fullscreen`
   também não combina com nenhum dos dois.
3. **PowerShell 5.1 embrulha stderr de exe nativo em `ErrorRecord`**, o que
   viraria erro terminante sob `$ErrorActionPreference = "Stop"` antes de
   qualquer diagnóstico. O modo headless relaxa a preferência só em volta da
   chamada.

## Capturar o que o jogador vê, mas `capture.gd` não alcança

A interface do modo de construção só existe depois de alguém apertar `TAB`, e a
câmera parada de `capture.gd` nunca mostra porta abrindo por proximidade. Para
isso existe `capturar_construcao.gd`:

```powershell
godot --path . -s tools/capturar_construcao.gd -- <saída> <ferramenta> <x> <y> <zoom> [opcionais]
```

**Ferramenta ≥ 0** entra no modo de construção e aponta o cursor para a célula:

| Valor | Ferramenta |
|---|---|
| 0 | Expandir |
| 1 | Parede |
| 2 | Porta |
| 3 | Portão |
| 4 | Demolir |

O retângulo opcional entra **pela mesma função que o mouse usa**, já dentro do
modo, então a barra aparece como o jogador a veria — com contador de alterações e
botão de cancelar aceso.

**Ferramenta negativa** não entra no modo e põe o **jogador** na célula pedida:

| Valor | Captura |
|---|---|
| `-1` | o jogo normal — é assim que se confere porta abrindo por proximidade |
| `-2` | o mesmo, com o menu de pausa aberto |
| `-3` | a picareta batendo no canteiro mais perto |
| `-4` | deitado na cama |

Nos dois últimos o nó `Trabalho` é **desligado** antes: ele lê a tecla `F` a cada
quadro, e tecla física não dá para fingir.

### Os opcionais, que mudam de sentido conforme a quantidade

| Quantos | O que viram |
|---|---|
| **2** | finge um **arrasto em curso** — único jeito de ver o retângulo de seleção desenhado. Com peça de tamanho fixo, o primeiro vira a **rotação** |
| **4** (`rx ry rw rh`) | retângulo onde a **mesma ferramenta** é aplicada antes da captura. Com ferramenta negativa é sempre expansão, aplicada direto no mapa |
| **5** (o décimo argumento) | congela a obra num estágio: `0` demarcado, `1` estrutura, `2` acabamento |

Ferramenta de peça fixa (porta) ignora o tamanho do retângulo e usa o canto dele
como célula do cursor.

### Exemplos

```powershell
# a planta inteira, para conferir mudança de constantes
npm run shot:planta

# o modo de construção com um retângulo de expansão de 6×4 já aplicado
godot --path . -s tools/capturar_construcao.gd -- screenshots/obra.png 0 20 10 0.5 20 10 6 4

# o mesmo, congelado no primeiro estágio
godot --path . -s tools/capturar_construcao.gd -- screenshots/obra.png 0 20 10 0.5 20 10 6 4 0

# a porta em pé na mão do jogador (rotação 1), com o arrasto fingido
godot --path . -s tools/capturar_construcao.gd -- screenshots/porta.png 2 15 9 0.6 1 0

# a picareta batendo
godot --path . -s tools/capturar_construcao.gd -- screenshots/picareta.png -3 15 9 0.5
```

## Depois de capturar

**Olhar o PNG.** A captura existe para ser vista, não para registrar que foi
tirada. Mock aprovado fora do Godot já ficou feio na tela antes — é o motivo de
toda esta engenharia existir.
