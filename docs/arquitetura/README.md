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
| `cenas/estacao.tscn` | Cena principal: campo estelar, `Mapa` com seis TileMapLayer vazios, `Cama`, jogador com câmera, `Construcao` com câmera própria, `Trabalho`, menu de pausa |
| `scripts/mapa_estacao.gd` | **Modelo e desenho do mapa.** Guarda as células, deriva o casco, pinta as camadas, abre portas por proximidade, alterna portões e recebe o trabalho batido nos canteiros |
| `scripts/modo_construcao.gd` | Modo de construção: cursor, ferramentas, câmera livre, interface. Também a dica de `E` do portão |
| `scripts/trabalho.gd` | **O dia de trabalho:** energia, picareta (`F`), cama (`E`), contador de dias e a barra de obra |
| `scripts/jogador.gd` | CharacterBody2D: movimento, oito direções, quatro estados de animação, energia, `travar()` para o modo de construção |
| `scripts/cama.gd` | A cama: arte, colisão e os dois pontos (deitar e levantar) |
| `scripts/barra_energia.gd` | A barra de energia em divisões de `>`, montada de peças e dimensionada pela energia máxima |
| `scripts/som.gd` | **Som do jogo:** música de fundo e os três efeitos. `class_name Som` com fachada estática, acordado pelo autoload `Audio` — ver [som.md](som.md) |
| `scripts/campo_estelar.gd` | Fundo procedural |
| `recursos/tileset_estacao.tres` | TileSet gerado: piso, borda, casco (256 variações com colisão, mais 256 alternativas apagadas), porta (com alternativa em obra), portão, detalhes, obra, demarcação (256), buraco, cones, marcação |
| `assets/tiles/estacao/` | Os onze atlas da estação, gerados por `tools/gerar_tiles_estacao.py` |
| `assets/interface/ferramentas.png` | Ícones da barra de construção, do mesmo gerador |
| `assets/interface/energia.png` | Peças da barra de energia, geradas por `tools/gerar_interface.py` |
| `assets/objetos/cama.png` | A cama, gerada por `tools/gerar_objetos.py` |
| `assets/audio/` | Música e efeitos, preparados de `docs/audio/` por `tools/gerar_audio.py` |
| `assets/sprites/` | Sprites do personagem, 64 px por célula de cenário. `miro_8dir.png` é a folha de caminhada, feita a mão; `miro_parado`, `miro_trabalho` e `miro_dormindo` saem dela, em `tools/gerar_miro_estados.py` |
| `docs/*.png`, `docs/print-paste/` | Folhas de referência cruas; `print-paste/image copy.png` é a referência de estrutura da estação |
| `tools/` | Geradores, testes e execução (ver abaixo) |

`run/main_scene` já aponta para `res://cenas/estacao.tscn`.


## A árvore de cenas

`cenas/estacao.tscn` é a cena única do protótipo. A ordem dos irmãos não é
cosmética — ver "Quem come o input" abaixo.

O autoload entra **antes** da cena, e é filho de `root`, não dela:

```
root
├── Audio                     som.gd — música e efeitos (fachada: `Som`)
└── Estacao                   a cena abaixo
```

```
Estacao (Node2D)
├── Fundo (CanvasLayer, layer -10)
│   └── CampoEstelar          campo_estelar.gd — fundo procedural
├── Mapa (Node2D)             mapa_estacao.gd — modelo + desenho
│   ├── Piso  Borda  Obra     seis TileMapLayer, nessa ordem de pintura
│   └── Casco  Detalhes  Aberturas
├── Cama (Node2D)             cama.gd — arte, colisão, dois pontos
├── Jogador (CharacterBody2D) jogador.gd — grupo "jogador", camada 2
│   ├── Sprite2D  Colisao
│   └── Camera2D              zoom 0,4 — a câmera do jogo
├── Construcao (Node2D)       modo_construcao.gd
│   └── Camera2D              a câmera livre do modo de construção
├── Trabalho (Node2D)         trabalho.gd — energia, obra, dia, HUD
└── MenuPausa (CanvasLayer)   menu_pausa.gd — PROCESS_MODE_ALWAYS
```

## Quem fala com quem

Três nós se conhecem, e hoje **por caminho na árvore**:

| Nó | Procura | Como |
|---|---|---|
| `Construcao` | `Mapa`, `Jogador`, a câmera do jogador | `get_parent().get_node("Mapa")` |
| `Trabalho` | `Mapa`, `Jogador`, `Construcao`, `Cama` | idem, com `get_node_or_null` só para a cama |
| `Mapa` | `Jogador` | pelo grupo `jogador` |

`MapaEstacao` emite `mapa_alterado`; `Jogador` emite `energia_alterada`. Fora
desses dois sinais, a comunicação é chamada direta.

**`Som` é a exceção, e é de propósito.** `jogador.gd` e `mapa_estacao.gd` chamam
`Som.passo()`, `Som.martelada()` e `Som.porta()` sem procurar nó nenhum: a
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
| 1 | `Construcao` | `_input` | `ESC` quando o modo está aberto |
| 2 | `MenuPausa` | `_unhandled_input` | `ui_cancel` (abre e fecha o menu) |
| 3 | `Trabalho` | `_unhandled_input` | `E` só quando está perto da cama |
| 4 | `Construcao` | `_unhandled_input` | `TAB`, `B`, `Enter`, `1`–`5`, mouse, roda |
| 5 | `Jogador` | `_unhandled_input` | roda do mouse (zoom do jogo) |

Três comportamentos do jogo dependem dessa ordem e quebram se alguém reordenar
os irmãos no `.tscn`:

- o mesmo `E` serve cama e portão, porque `Trabalho` só consome o evento perto da cama e deixa o resto passar para `Construcao`
- o primeiro `ESC` fecha a construção e só o segundo abre o menu
- com o modo de construção aberto, a roda não chega ao zoom do jogador

## O que ainda não existe

Mecânica de jogo (módulos como entidade, energia **da estação**, naves, regiões) continua **sem nenhuma implementação**. O que existe é protótipo de movimentação, cenário, construção livre de planta e o ciclo de trabalho/descanso do personagem.
