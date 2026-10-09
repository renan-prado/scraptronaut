# Arquitetura — visão geral

Este é o documento de entrada. Ele diz **onde** cada coisa mora e **quem fala com
quem**; o detalhe de cada sistema está nos documentos irmãos.

| Quero mexer em… | Documento |
|---|---|
| planta, casco, tiles, máscaras, portas, buracos | [mapa-da-estacao.md](mapa-da-estacao.md) |
| ferramentas, cursor, arrasto, canteiro, demolição | [construcao-e-obra.md](construcao-e-obra.md) |
| energia, picareta, custo de obra, dia, cama | [trabalho-energia-e-dia.md](trabalho-energia-e-dia.md) |
| movimento, estados, folhas de sprite | [personagem-e-animacao.md](personagem-e-animacao.md) |
| HUD, barra de energia, menu de pausa, zoom | [interface-e-camera.md](interface-e-camera.md) |
| música, efeito sonoro, volume, autoload de áudio | [som.md](som.md) |
| princípios e dívidas de arquitetura | [../padroes/arquitetura.md](../padroes/arquitetura.md) |

O projeto **saiu da fase de só-design**: existe um protótipo jogável da Estação Lastro, com construção livre, obra que custa trabalho, energia do personagem e ciclo de dia.

| Caminho | Conteúdo |
|---|---|
| `scenes/station.tscn` | Cena principal: campo estelar, `Map` com seis TileMapLayer vazios, `Bed`, jogador com câmera, `BuildMode` com câmera própria, `Work`, menu de pausa |
| `scripts/station_map.gd` | **Modelo e desenho do mapa.** Guarda as células, deriva o casco, pinta as camadas, abre portas por proximidade, alterna portões e recebe o trabalho batido nos canteiros |
| `scripts/build_mode.gd` | Modo de construção: cursor, ferramentas, câmera livre, interface |
| `scripts/work.gd` | **O dia de trabalho:** energia, picareta (`F`), cama (`E`), contador de dias e a barra de obra |
| `scripts/player.gd` | CharacterBody2D: movimento, oito direções, quatro estados de animação, energia, `lock()` para o modo de construção |
| `scripts/bed.gd` | A cama: arte, colisão e os dois pontos (deitar e levantar) |
| `scripts/energy_bar.gd` | A barra de energia em divisões de `>`, montada de peças e dimensionada pela energia máxima |
| `scripts/speech_bubble.gd` | O balão de fala do personagem: o que ele diz e a tecla que faz aquilo, em cima da cabeça de quem fala. Também carrega a recusa do modo de construção, ancorada na célula recusada |
| `scripts/fonts.gd` | Os três corpos de texto do jogo (`SMALL` 20, `MEDIUM` 25, `LARGE` 30) e a fábrica de `Label`. Quais corpos saem limpos na VT323 foi **medido na tela**, não deduzido |
| `scripts/keycap.gd` | A tampa de teclado desenhada, de uma ou duas letras. A tecla é desenho, não letra |
| `scripts/hud_panel.gd` | A chapa de aço de nove pedaços, em relevo ou encaixe: a moldura de toda a interface |
| `scripts/pause_menu.gd` | O menu de pausa e o `ESC` que o abre |
| `scripts/sound.gd` | **Som do jogo:** música de fundo e os três efeitos. `class_name Sound` com fachada estática, acordado pelo autoload `Audio` — ver [som.md](som.md) |
| `scripts/starfield.gd` | Fundo procedural |
| `resources/tileset_station.tres` | TileSet gerado: piso, borda, casco (256 variações com colisão, mais 256 alternativas apagadas), porta (com alternativa em obra), portão, detalhes, obra, demarcação (256), buraco, cones, marcação |
| `assets/tiles/station/` | Os onze atlas da estação, gerados por `tools/gerar_tiles_estacao.py` |
| `assets/interface/tools.png` | Ícones da barra de construção, do mesmo gerador |
| `assets/interface/energy.png` | Peças da barra de energia, geradas por `tools/gerar_interface.py` |
| `assets/interface/panel.png`, `speech_bubble.png`, `keys.png`, `dual_keys.png` | Chapas do HUD, o balão de fala, as 36 tampas de teclado e as 9 tampas largas (`F1`–`F9`), do mesmo gerador |
| `assets/interface/vt323.ttf` | A fonte de todo o texto do jogo. Não é gerada: é um `.ttf` de fora, apontado por `gui/theme/custom_font` |
| `assets/objects/bed.png` | A cama, gerada por `tools/generate_objects.py` |
| `assets/audio/` | Música e efeitos, preparados de `entrada/referencias/audio/` por `tools/generate_audio.py` |
| `assets/sprites/` | Sprites do personagem, 64 px por célula de cenário. `miro_8dir.png` é a folha de caminhada, feita a mão; `miro_idle`, `miro_working` e `miro_sleeping` saem dela, em `tools/generate_miro_states.py` |
| `entrada/referencias/` | Material de consulta, **fora do git e fora do import do Godot**: folhas de referência, prints, áudio cru. `prints/image copy.png` é a referência de estrutura da estação. Ver `entrada/LEIA-ME.md` |
| `tools/` | Geradores, testes e execução (ver abaixo) |

`run/main_scene` já aponta para `res://scenes/station.tscn`.


## A árvore de cenas

`scenes/station.tscn` é a cena única do protótipo. A ordem dos irmãos não é
cosmética — ver "Quem come o input" abaixo.

O autoload entra **antes** da cena, e é filho de `root`, não dela:

```
root
├── Audio                     sound.gd — música e efeitos (fachada: `Sound`)
└── Station                   a cena abaixo
```

```
Station (Node2D)
├── Background (CanvasLayer, layer -10)
│   └── Starfield          starfield.gd — fundo procedural
├── Map (Node2D)             station_map.gd — modelo + desenho
│   ├── Floor  Border  Construction     seis TileMapLayer, nessa ordem de pintura
│   └── Hull  Details  Openings
├── Bed (Node2D)             bed.gd — arte, colisão, dois pontos
├── Player (CharacterBody2D) player.gd — grupo "player", camada 2
│   ├── Sprite2D  Collision
│   └── Camera2D              zoom 0,4 — a câmera do jogo
├── BuildMode (Node2D)       build_mode.gd
│   └── Camera2D              a câmera livre do modo de construção
├── Work (Node2D)         work.gd — energy, obra, day, HUD
└── PauseMenu (CanvasLayer)   pause_menu.gd — PROCESS_MODE_ALWAYS
```

## Quem fala com quem

Três nós se conhecem, e hoje **por caminho na árvore**:

| Nó | Procura | Como |
|---|---|---|
| `BuildMode` | `Map`, `Player`, a câmera do jogador | `get_parent().get_node("Map")` |
| `Work` | `Map`, `Player`, `BuildMode`, `Bed` | idem, com `get_node_or_null` só para a cama |
| `Map` | `Player` | pelo grupo `player` |

`StationMap` emite `map_changed`; `Player` emite `energy_changed`. Fora
desses dois sinais, a comunicação é chamada direta.

**`Sound` é a exceção, e é de propósito.** `player.gd` e `station_map.gd` chamam
`Sound.footstep()`, `Sound.hammer_hit()` e `Sound.door()` sem procurar nó nenhum: a
fachada é estática e o nome é global. Não é dívida como os caminhos literais
acima — quem anda, quem martela e quem abre porta são três nós sem parentesco, e
som não devolve resposta nem guarda estado de ninguém. Ver [som.md](som.md).

**Isso é dívida conhecida, não padrão a imitar.** Nó que procura irmão por nome
literal quebra em silêncio quando a cena é reorganizada ou reaproveitada. A
alternativa recomendada pelo Godot e o plano de migração estão em
[../padroes/arquitetura.md](../padroes/arquitetura.md).

## Quem come o input

`_input` de qualquer nó corre antes de todo `_unhandled_input`, e entre irmãos o
`_unhandled_input` corre **na ordem inversa da árvore**: o último irmão recebe
primeiro. Daí a prioridade de hoje:

| Prioridade | Nó | Onde | O que consome |
|---|---|---|---|
| 1 | `BuildMode` | `_input` | `ESC` quando o modo está aberto |
| 2 | `PauseMenu` | `_unhandled_input` | `ui_cancel` (abre e fecha o menu) |
| 3 | `Work` | `_unhandled_input` | `E` só quando está perto da cama |
| 4 | `BuildMode` | `_unhandled_input` | `TAB`, `B`, `Enter`, `1`–`5`, mouse, roda |
| 5 | `Player` | `_unhandled_input` | roda do mouse (zoom do jogo) |

Três comportamentos do jogo dependem dessa ordem e quebram se alguém reordenar
os irmãos no `.tscn`:

- o mesmo `E` serve cama e portão, porque `Work` só consome o evento perto da cama e deixa o resto passar para `BuildMode`
- o primeiro `ESC` fecha a construção e só o segundo abre o menu
- com o modo de construção aberto, a roda não chega ao zoom do jogador

## O que ainda não existe

Mecânica de jogo (módulos como entidade, energia **da estação**, naves, regiões) continua **sem nenhuma implementação**. O que existe é protótipo de movimentação, cenário, construção livre de planta e o ciclo de trabalho/descanso do personagem.
