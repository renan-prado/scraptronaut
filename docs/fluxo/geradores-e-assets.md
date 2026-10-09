# Geradores e assets

Carregar para regenerar arte, tileset ou o esqueleto da cena.

> Para **desenhar** algo novo (um sprite, um tile, um ícone), use a skill
> `pixel-art`: ela carrega as regras de desenho que este documento não repete.

**Os scripts de `tools/` são geradores e testes, não código de jogo.** `build_station.gd` regenera o `.tres` (inclusive os 256 polígonos de colisão do casco) e o esqueleto de nós do `.tscn`; a planta **não está mais lá**, e sim nas constantes de `station_map.gd`. Os `.py` convertem ou desenham o que está em `assets/`: `gerar_tiles_estacao.py` os onze atlas da estação e os ícones da barra, `generate_miro_8dir.py` a folha de caminhada (a partir da arte feita a mão), `generate_miro_states.py` as folhas de parado, trabalho e sono (a partir da de caminhada), `generate_objects.py` a cama, `gerar_interface.py` as peças da barra de energia, as chapas do HUD, o balão de fala e as tampas de teclado, e `generate_audio.py` a música e os efeitos. Reexecutar um deles sobrescreve a saída.

## Quem gera o quê

| Gerador | Entrada | Saída |
|---|---|---|
| `tools/gerar_tiles_estacao.py` | nada, desenha em código | os onze atlas de `assets/tiles/station/` e `assets/interface/tools.png` |
| `tools/generate_miro_8dir.py` | `entrada/referencias/sprites/sprite-miro-walking.png` (arte feita a mão) | `assets/sprites/miro_8dir.png` |
| `tools/generate_miro_states.py` | `assets/sprites/miro_8dir.png` | `miro_idle.png`, `miro_working.png`, `miro_sleeping.png` |
| `tools/generate_objects.py` | nada | `assets/objects/bed.png` |
| `tools/gerar_interface.py` | nada | `assets/interface/`: `energy.png`, `panel.png`, `speech_bubble.png`, `keys.png`, `dual_keys.png` |
| `tools/generate_audio.py` | `entrada/referencias/audio/*.mp3` (áudio cru, **fora do versionamento**) | `assets/audio/`: música, 7 passos, martelada, porta abrindo e fechando |
| `tools/build_station.gd` | as constantes de `station_map.gd` | `resources/tileset_station.tres` e o esqueleto de `scenes/station.tscn` |

Dois são biblioteca ou conferência, não geradores: `tools/miro_sheet.py` é
importado por `generate_miro_8dir.py` (**não apagar**), e
`check_miro_8dir.py` / `conferir_tiles_estacao.py` só inspecionam a saída.

**`tools/generate_font.py` e `tools/check_font.py` não alimentam mais nada.**
Eles produziam e conferiam `assets/interface/font.png` / `font.fnt`, a fonte
de bitmap do jogo até 2026-10-06. A fonte hoje é a VT323, um `.ttf` de fora que
ninguém gera — ver
[../arquitetura/interface-e-camera.md](../arquitetura/interface-e-camera.md).
Continuam no repositório, e apagá-los é ponto aberto junto com os outros
arquivos mortos.

A cadeia tem ordem: `gerar_miro_8dir` → `gerar_miro_estados`. Mexer na folha de
caminhada sem reexecutar a de estados deixa as quatro poses desencontradas.

## Por que existe um gerador de áudio

`entrada/` está inteira no `.gitignore`, então arquivo cru em
`entrada/referencias/audio/` **nunca entraria num commit**: o jogo carregaria
áudio que o repositório não tem. `assets/` é versionado, e é de lá que o jogo lê.

Mas copiar na mão esconderia os cortes que o áudio cru **exige**: `footstep.mp3`
não é uma pisada, são sete em sequência; a martelada em MP3 traz 70 ms de
silêncio do codificador, que num som percussivo é atraso que se ouve; e a porta
fechando é a de abrir **invertida**, porque não há gravação de fechamento. O
cabeçalho de `tools/generate_audio.py` registra cada corte e por quê — e
[../arquitetura/som.md](../arquitetura/som.md) resume.

Precisa de `ffmpeg` e `ffprobe` no PATH (nenhuma biblioteca de Python instalada
aqui lê MP3) e de `numpy`.

**Volume e mixagem não se verificam headless.** Depois de regenerar áudio, ouvir
com `npm run play`; os volumes são quatro constantes no topo de `scripts/sound.gd`.

## O número que amarra arte e colisão

`RECESS`, em `gerar_tiles_estacao.py`, é o quanto o casco recua da borda da célula no lado virado para o espaço — é o único número que controla a espessura aparente da parede. `build_station.gd` repete o valor para a colisão acompanhar a arte: mudar um exige mudar o outro.

## Regenerar

```powershell
python tools/gerar_tiles_estacao.py      # atlas da estação + ícones
python tools/generate_miro_states.py       # as três poses derivadas
python tools/generate_objects.py            # a cama
python tools/gerar_interface.py          # barra, painel, balão e teclas
python tools/generate_audio.py              # música e efeitos (precisa de ffmpeg)
npm run build:station                    # tileset .tres + esqueleto do .tscn
```

**Reexecutar sobrescreve a saída sem avisar.** Depois de qualquer um deles:
`npm run check`, e `npm run shot` para olhar o resultado — mock aprovado fora do
Godot já ficou feio na tela antes.
