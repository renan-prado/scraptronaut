# Geradores e assets

Carregar para regenerar arte, tileset ou o esqueleto da cena.

> Para **desenhar** algo novo (um sprite, um tile, um ícone), use a skill
> `pixel-art`: ela carrega as regras de desenho que este documento não repete.

**Os scripts de `tools/` são geradores e testes, não código de jogo.** `construir_estacao.gd` regenera o `.tres` (inclusive os 256 polígonos de colisão do casco) e o esqueleto de nós do `.tscn`; a planta **não está mais lá**, e sim nas constantes de `mapa_estacao.gd`. Os `.py` convertem ou desenham o que está em `assets/`: `gerar_tiles_estacao.py` os onze atlas da estação e os ícones da barra, `gerar_miro_8dir.py` a folha de caminhada (a partir da arte feita a mão), `gerar_miro_estados.py` as folhas de parado, trabalho e sono (a partir da de caminhada), `gerar_objetos.py` a cama e `gerar_interface.py` as peças da barra de energia. Reexecutar um deles sobrescreve a saída.

## Quem gera o quê

| Gerador | Entrada | Saída |
|---|---|---|
| `tools/gerar_tiles_estacao.py` | nada, desenha em código | os onze atlas de `assets/tiles/estacao/` e `assets/interface/ferramentas.png` |
| `tools/gerar_miro_8dir.py` | `docs/sprites-paste/sprite-miro-walking.png` (arte feita a mão) | `assets/sprites/miro_8dir.png` |
| `tools/gerar_miro_estados.py` | `assets/sprites/miro_8dir.png` | `miro_parado.png`, `miro_trabalho.png`, `miro_dormindo.png` |
| `tools/gerar_objetos.py` | nada | `assets/objetos/cama.png` |
| `tools/gerar_interface.py` | nada | `assets/interface/energia.png` |
| `tools/construir_estacao.gd` | as constantes de `mapa_estacao.gd` | `recursos/tileset_estacao.tres` e o esqueleto de `cenas/estacao.tscn` |

Dois são biblioteca ou conferência, não geradores: `tools/folha_miro.py` é
importado por `gerar_miro_8dir.py` (**não apagar**), e
`conferir_miro_8dir.py` / `conferir_tiles_estacao.py` só inspecionam a saída.

A cadeia tem ordem: `gerar_miro_8dir` → `gerar_miro_estados`. Mexer na folha de
caminhada sem reexecutar a de estados deixa as quatro poses desencontradas.

## O número que amarra arte e colisão

`RECUO`, em `gerar_tiles_estacao.py`, é o quanto o casco recua da borda da célula no lado virado para o espaço — é o único número que controla a espessura aparente da parede. `construir_estacao.gd` repete o valor para a colisão acompanhar a arte: mudar um exige mudar o outro.

## Regenerar

```powershell
python tools/gerar_tiles_estacao.py      # atlas da estação + ícones
python tools/gerar_miro_estados.py       # as três poses derivadas
python tools/gerar_objetos.py            # a cama
python tools/gerar_interface.py          # barra de energia
npm run build:estacao                    # tileset .tres + esqueleto do .tscn
```

**Reexecutar sobrescreve a saída sem avisar.** Depois de qualquer um deles:
`npm run check`, e `npm run shot` para olhar o resultado — mock aprovado fora do
Godot já ficou feio na tela antes.
