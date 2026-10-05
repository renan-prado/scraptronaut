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
$Construcao.mapa = $Mapa

# 2. O filho declara o que precisa e o editor preenche
@export var caminho_do_mapa: NodePath
@onready var _mapa: MapaEstacao = get_node(caminho_do_mapa)

# 3. Nome único na cena — acoplamento menor que caminho literal,
#    porque sobrevive a mudança de hierarquia
@onready var _mapa: MapaEstacao = %Mapa
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

Candidatos legítimos no Scraptronaut, quando a hora chegar: save/load, estado de
progressão entre cenas, áudio. **Não** são candidatos: `Mapa`, `Trabalho`,
`Construcao` — os três mexem no estado um do outro, e autoload transformaria o
acoplamento de hoje em acoplamento global, que é pior porque fica invisível.

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
if Input.is_action_pressed(&"trabalhar"):   # em vez de KEY_F
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

**1. `mapa_estacao.gd` acumula cinco responsabilidades (1346 linhas).**
Modelo de células, regras de construção, canteiro de obra, desenho em seis
camadas e proximidade do jogador (portas, portão) no mesmo arquivo. Fere o
princípio 5. A divisão natural, respeitando as fronteiras que o próprio código já
marca com comentários de seção:

| Arquivo novo | O que leva | Linhas de hoje |
|---|---|---|
| `mapa_estacao.gd` | células, tipos, consultas, regras, lote, instantâneo | até ~736 |
| `obras.gd` | estágios, trabalho batido, canteiro perto, demolição ao contrário | 736–878 |
| `pintor_da_estacao.gd` | as seis camadas, máscaras, enfeite, cones, portas | 880–1346 |

O desenho é o melhor primeiro corte: ele só **lê** o modelo, então sai sem
inverter dependência nenhuma. `MapaEstacao` continuaria sendo a fachada pública,
e nada fora dele mudaria de chamada.

**2. Irmãos encontrados por caminho literal.**
`modo_construcao.gd:87-89` e `trabalho.gd:88-91` usam
`get_parent().get_node("Mapa")`. Fere o princípio 3. Migrar para `%Mapa` (nomes
únicos de cena) é mudança de uma linha por dependência, sem alterar
comportamento — é o item de melhor relação custo/benefício da lista.

**3. Entrada presa a teclas físicas, sem InputMap.**
`project.godot` não tem seção `[input]`; as teclas estão em
`jogador.gd:281-287`, `modo_construcao.gd:121-142,373-379`, `trabalho.gd:45-46`
e `portao_hangar.gd:28`. Fere o princípio 6. Ações a declarar: `mover_cima`,
`mover_baixo`, `mover_esquerda`, `mover_direita`, `construir`, `interagir`,
`trabalhar`, `confirmar`, `ferramenta_1`–`ferramenta_5`.

### Média — atrito ao crescer

**4. Metade dos scripts não tem `class_name`.**
Só `MapaEstacao`, `Cama` e `BarraEnergia` têm. A falta cobra em dois lugares:
`trabalho.gd:15` precisa de `const Jogador: GDScript = preload(...)` para
alcançar uma constante, e as referências cruzadas caem para `Node2D`
(`_jogador: Node2D`, `_construcao: Node2D`), o que apaga autocomplete e
verificação de tipo — exatamente o que a tipagem estática existe para dar.
Adicionar `class_name` a `jogador.gd`, `trabalho.gd`, `modo_construcao.gd`,
`menu_pausa.gd` e `campo_estelar.gd` é aditivo e não quebra nada.

**5. Regra devolve texto de interface.**
`pode_porta()`, `pode_portao()`, `pode_demolir()` e `aplicar()` devolvem a
mensagem em português (`"você está aqui"`, `"só em parede"`). Funciona, e mantém
a mensagem colada na regra — mas trava tradução e faz o teste comparar prosa.
A alternativa é `enum Recusa` com uma tabela de texto na camada de interface.
**Tem custo real** (toca as três chamadas e os testes que leem a recusa) e benefício que só
aparece se houver tradução. Fica registrado, não recomendado agora.

**6. Interface montada em código dentro dos nós de lógica.**
`modo_construcao.gd:440-523` e `trabalho.gd:202-253` constroem ~130 linhas de
`Control` à mão. A causa é conhecida e boa — `.tscn` escrito fora do editor
quebra por `uid://`. O meio-termo sem entrar no editor é extrair para
`scripts/interface/barra_construcao.gd` e `hud_trabalho.gd`, nós próprios que
recebem dados e não leem estado de jogo.

### Baixa — arrumação

**7. Arquivos mortos.** Sem nenhuma referência viva:
`tools/gerar_miro.py`, `tools/gerar_miro_4dir.py`, `tools/gerar_miro_baixo.py`,
`tools/gerar_miro_direita.py`, `tools/gerar_tiles.py`,
`tools/conferir_miro_4dir.py`, `scripts/portao_hangar.gd` (+ `.uid`) e o `.uid`
órfão `tools/_verificar_andando.gd.uid`. Atenção: `tools/folha_miro.py` **está
vivo** — `gerar_miro_8dir.py` o importa. Apagar os mortos já é ponto aberto em
[../decisoes/abertas.md](../decisoes/abertas.md).

**8. `scripts/` é plano.** Dez scripts sem agrupamento. Pastas por sistema
(`estacao/`, `personagem/`, `interface/`) ajudariam a leitura, mas mover `.gd`
mexe em `.uid` e nas referências do `.tscn` — risco alto para ganho estético.
Só junto de uma reorganização que já vá abrir o editor.

**9. Teste num bloco só.** `tools/testar_estacao.gd` tem 165 verificações num
único `_initialize()`. O arnês é bom (`_conferir`, `_recusa`, saída com número de
falhas); falta agrupamento por tema para que a saída diga qual sistema caiu.
Ver [../fluxo/testes.md](../fluxo/testes.md).

## Ordem sugerida, se houver aprovação

1. itens 2, 4 e 7 — aditivos ou de uma linha, sem risco de comportamento
2. item 3 (InputMap) — mecânico, e o teste cobre o resultado
3. item 1 (extrair o pintor) — o corte grande, com `npm run test` e
   `npm run shot:planta` antes e depois
4. itens 6, 9 — quando a interface ou o teste for mexido por outro motivo
5. itens 5, 8 — só com motivo externo
