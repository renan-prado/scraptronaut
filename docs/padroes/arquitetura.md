# Padrões de arquitetura

Carregar antes de criar nó, cena ou sistema novo, e antes de propor refatoração.
As convenções de escrita (nomes, tipagem, ordem, idioma) estão em
[codigo-gdscript.md](codigo-gdscript.md).

Fonte: guias *Best Practices* da documentação oficial do Godot 4.7
(`/websites/godotengine_en_4_7` — "Scene organization", "Autoloads versus
regular nodes", "Static typing in GDScript"). Onde um princípio geral de código
limpo e o Godot discordam, **o Godot ganha**: a engine é o que executa.

## Os seis princípios

### 1. Uma cena não deve exigir nada do ambiente

> *"If at all possible, you should design scenes to have no dependencies. That
> is, you should create scenes that keep everything they need within
> themselves."* — Godot, Scene organization

Cena que só funciona num lugar específico da árvore não é peça, é parte de um
bloco. A pergunta de aceitação é: **esta cena roda sozinha, apertando F6?**

### 2. Chamar para baixo, sinalizar para cima

Pai chama método de filho; filho **emite sinal** e não procura o pai. Um nó pode
conhecer seus filhos, porque os criou; não pode conhecer seus irmãos, porque não
escolheu a companhia.

| Direção | Ferramenta |
|---|---|
| pai → filho | chamada direta, `$Filho.metodo()` |
| filho → pai | `signal` |
| irmão → irmão | **nenhuma das duas** — ver princípio 3 |

### 3. Dependência entra por injeção, não por caminho

Quando um nó precisa de outro que não é seu filho, quem resolve é o **pai**, que
é o único que conhece os dois. O Godot documenta três formas, da melhor para a
pior:

```gdscript
# 1. O pai injeta a referência (preferido quando o pai tem script)
$BuildMode.mapa = $Map

# 2. O filho declara o que precisa e o editor preenche
@export var caminho_do_mapa: NodePath
@onready var _map: StationMap = get_node(caminho_do_mapa)

# 3. Nome único na cena — acoplamento menor que caminho literal,
#    porque sobrevive a mudança de hierarquia
@onready var _map: StationMap = %Map
```

A forma 2 tem variante tipada que o editor valida:
`@export_node_path("Node2D") var caminho_do_mapa`.

**O que nunca entra em código novo:** `get_parent().get_node("Irmao")`. Esse
caminho assume a posição do nó *e* o nome do irmão, e quando um dos dois muda o
erro aparece em tempo de execução, não de carga.

### 4. Autoload só para sistema que se sustenta sozinho

O Godot dá três condições, e exige **as três**:

1. guarda todos os seus dados internamente
2. precisa ser acessível de qualquer lugar
3. existe isolado — não mexe no estado de outros sistemas

> *"If you have systems that modify other systems' data, you should define those
> as their own scripts or scenes, rather than autoloads."*

**Áudio é o primeiro, e hoje é o único**: `scripts/sound.gd`, autoload `Audio`,
cumpre as três. Outros candidatos legítimos quando a hora chegar: save/load e
estado de progressão entre cenas. **Não** são candidatos: `Map`, `Work`,
`BuildMode` — os três mexem no estado um do outro, e autoload transformaria o
acoplamento de hoje em acoplamento global, que é pior porque fica invisível.

#### O nome do autoload não pode ser o nome da classe

Vale para **todo** autoload que este projeto criar, e custou as 165 verificações
de `npm run test` para ser descoberto.

`tools/run.ps1 -Script` roda `godot --headless --script`, e nesse modo a engine
**compila o script pedido antes de a SceneTree existir** — mas o nome global de
um autoload só é registrado quando a SceneTree sobe. Qualquer script que chame o
autoload pelo nome não compila:

```
SCRIPT ERROR: Compile Error: Identifier not found: Sound
   at: GDScript::reload (res://scripts/mapa_estacao.gd:940)
```

Nome de `class_name` não tem esse problema: vem do cache de classes globais, que
a engine lê **antes** de compilar qualquer script. Então a receita é:

1. o script leva `class_name` e expõe a fachada em **funções estáticas** — é esse
   nome que o código do jogo chama
2. o autoload leva nome **diferente**, e existe só para o ciclo de vida
   (`_ready()` monta, `_exit_tree()` solta)
3. autoload com o mesmo nome da classe faz a engine recusar o script inteiro:
   `Class "Sound" hides an autoload singleton`

*Static var* não morre com o nó — vive enquanto o script estiver carregado —,
então `_exit_tree()` tem de soltar o que `_ready()` guardou, ou a engine sai
imprimindo `ERROR: 1 resources still in use at exit`.

O caso completo está em [../arquitetura/som.md](../arquitetura/som.md).

### 5. Um nó, uma responsabilidade — e a maior é separar modelo de desenho

Em jogo 2D de tile, a fronteira que mais rende é entre **o que a estação é** e
**como ela aparece**. Modelo responde perguntas e aplica regras; pintor traduz
modelo em células de `TileMapLayer`. A separação paga em três moedas: o modelo
fica testável sem renderizador, o desenho pode ser reescrito sem risco de
regra, e cada arquivo cabe na cabeça.

Sinais de que um script passou do ponto:

- precisa de mais de um `# --- seção ---` para se navegar
- tem campos que metade dos métodos nunca toca
- muda por dois motivos diferentes na mesma semana

### 6. Entrada de jogo é ação, não tecla

Tecla física espalhada pelo código é decisão de interface escrita em quatro
lugares. O Godot resolve isso com o **InputMap**: as ações vivem em
`project.godot`, e o código pergunta pela ação.

```gdscript
if Input.is_action_pressed(&"work"):   # em vez de KEY_F
if evento.is_action_pressed(&"construir"):  # em vez de KEY_TAB or KEY_B
Input.get_vector(&"mover_esquerda", &"mover_direita", &"mover_cima", &"mover_baixo")
```

Isso é o que destrava remapeamento, controle e `ui_*` consistente — e é
pré-requisito de qualquer tela de opções.

---

## Diagnóstico do código de hoje

Levantado em 2026-10-05 contra o protótipo em `scripts/`. Cada item traz a
evidência; nenhum deles está implementado — **são propostas, e esperam decisão**.

### Alta — custo de manutenção já visível

**1. `station_map.gd` acumula cinco responsabilidades (1346 linhas).**
Modelo de células, regras de construção, canteiro de obra, desenho em seis
camadas e proximidade do jogador (portas, portão) no mesmo arquivo. Fere o
princípio 5. A divisão natural, respeitando as fronteiras que o próprio código já
marca com comentários de seção:

| Arquivo novo | O que leva | Linhas de hoje |
|---|---|---|
| `station_map.gd` | células, tipos, consultas, regras, lote, instantâneo | até ~736 |
| `construction.gd` | estágios, trabalho batido, canteiro perto, demolição ao contrário | 736–878 |
| `station_painter.gd` | as seis camadas, máscaras, enfeite, cones, portas | 880–1346 |

O desenho é o melhor primeiro corte: ele só **lê** o modelo, então sai sem
inverter dependência nenhuma. `StationMap` continuaria sendo a fachada pública,
e nada fora dele mudaria de chamada.

**2. Irmãos encontrados por caminho literal.**
`build_mode.gd:87-89` e `work.gd:88-91` usam
`get_parent().get_node("Map")`. Fere o princípio 3. Migrar para `%Map` (nomes
únicos de cena) é mudança de uma linha por dependência, sem alterar
comportamento — é o item de melhor relação custo/benefício da lista.

**3. Entrada presa a teclas físicas, sem InputMap.**
`project.godot` não tem seção `[input]`; as teclas estão em
`player.gd:281-287`, `build_mode.gd:121-142,373-379`, `work.gd:45-46`
e `hangar_gate.gd:28`. Fere o princípio 6. Ações a declarar, já no idioma do
código: `move_up`, `move_down`, `move_left`, `move_right`, `build`,
`interact`, `work`, `confirm`, `tool_1`–`tool_5`.

### Média — atrito ao crescer

**4. Metade dos scripts não tem `class_name`.**
Só `StationMap`, `Bed` e `EnergyBar` têm. A falta cobra em dois lugares:
`work.gd:15` precisa de `const Player: GDScript = preload(...)` para
alcançar uma constante, e as referências cruzadas caem para `Node2D`
(`_player: Node2D`, `_build_mode: Node2D`), o que apaga autocomplete e
verificação de tipo — exatamente o que a tipagem estática existe para dar.
Adicionar `class_name` a `player.gd`, `work.gd`, `build_mode.gd`,
`pause_menu.gd` e `starfield.gd` é aditivo e não quebra nada.

**5. Regra devolve texto de interface.**
`can_door()`, `can_gate()`, `can_demolish()` e `apply()` devolvem a
mensagem em português (`"Você está parado neste quadrado"`, `"Coloque sobre uma
parede externa"`). Funciona, e mantém a mensagem colada na regra — mas trava
tradução, e o custo ficou visível em 2026-10-06: reescrever a redação das
recusas, que é trabalho de interface, abriu `station_map.gd` em dezessete
pontos. O teste, ao menos, só compara "recusou ou não" — a prosa ele imprime.
A alternativa é `enum Recusa` com uma tabela de texto na camada de interface.
**Tem custo real** (toca as três chamadas e os testes que leem a recusa) e benefício que só
aparece se houver tradução. Fica registrado, não recomendado agora.

**6. Interface montada em código dentro dos nós de lógica.**
`build_mode.gd:440-523` e `work.gd:202-253` constroem ~130 linhas de
`Control` à mão. A causa é conhecida e boa — `.tscn` escrito fora do editor
quebra por `uid://`. O meio-termo sem entrar no editor é extrair para
`scripts/interface/build_bar.gd` e `work_hud.gd`, nós próprios que
recebem dados e não leem estado de jogo.

### Baixa — arrumação

**7. Arquivos mortos.** Sem nenhuma referência viva:
`tools/generate_miro.py`, `tools/generate_miro_4dir.py`, `tools/generate_miro_down.py`,
`tools/generate_miro_right.py`, `tools/generate_tiles.py`,
`tools/check_miro_4dir.py` e `scripts/hangar_gate.gd` (+ `.uid`).
Atenção: `tools/miro_sheet.py` **está vivo** — `generate_miro_8dir.py` o importa.

O `.uid` órfão `tools/_verificar_andando.gd.uid` **saiu em 2026-10-08**, e saiu
sem passar pela decisão dos outros: ele não era arquivo do projeto, era cache do
Godot apontando para um script que não existe. Como nunca chegou a ser
versionado, aparecia em todo `git status` como se houvesse trabalho pendente.

Entraram na lista em 2026-10-06, com a troca da fonte para a VT323:
`tools/generate_font.py`, `tools/check_font.py` (que importa o primeiro) e a
folha que eles produziam, `assets/interface/font.png` e `font.fnt` (+ os dois
`.import`). Nada mais os consome — `gui/theme/custom_font` aponta para o
`.ttf`. Apagar os mortos já é ponto aberto em
[../decisoes/abertas.md](../decisoes/abertas.md).

**8. `scripts/` é plano.** Dez scripts sem agrupamento. Pastas por sistema
(`estacao/`, `personagem/`, `interface/`) ajudariam a leitura, mas mover `.gd`
mexe em `.uid` e nas referências do `.tscn` — risco alto para ganho estético.
Só junto de uma reorganização que já vá abrir o editor.

**9. Teste num bloco só.** `tools/test_station.gd` tem 190 verificações num
único `_initialize()`. O arnês é bom (`_check`, `_refused`, saída com número de
falhas); falta agrupamento por tema para que a saída diga qual sistema caiu.
Ver [../fluxo/testes.md](../fluxo/testes.md).

## Ordem sugerida, se houver aprovação

1. itens 2, 4 e 7 — aditivos ou de uma linha, sem risco de comportamento
2. item 3 (InputMap) — mecânico, e o teste cobre o resultado
3. item 1 (extrair o pintor) — o corte grande, com `npm run test` e
   `npm run shot:planta` antes e depois
4. itens 6, 9 — quando a interface ou o teste for mexido por outro motivo
5. itens 5, 8 — só com motivo externo
