# Convenções de código GDScript

Carregar antes de escrever ou revisar qualquer `.gd`. Os princípios de
arquitetura (acoplamento, responsabilidade, autoload, input) estão em
[arquitetura.md](arquitetura.md).

Base: guia de estilo oficial do GDScript (Godot 4.7) mais as decisões próprias
do projeto. O código em `scripts/` já aplica o que está aqui.

## Nomes, tipagem e privacidade

- Arquivos e pastas: `snake_case`. Classes e nós: `PascalCase`. Funções e variáveis: `snake_case`. Constantes e enums: `CONSTANT_CASE`
- Membros privados com prefixo `_`
- Tipagem estática sempre que possível (`var carga: int = 10`, `func atracar(nave: Nave) -> void:`)

## Tipagem estática não é opcional

A documentação do Godot lista quatro ganhos, e todos valem mais num projeto de
uma pessoa do que num de dez: erro pego antes de rodar, autocomplete depois do
ponto, script que se documenta sozinho e **opcode otimizado** quando o tipo é
conhecido em tempo de compilação.

```gdscript
var celulas: Dictionary = {}                      # explícito
var eixo := Vector2i(0, 1)                        # inferido, quando é óbvio
func work(celula: Vector2i, quanto: float) -> float:
```

Duas regras que seguem disso:

- **todo `func` declara retorno**, inclusive `-> void`
- `Array[Vector2i]` e não `Array` — array tipado verifica o que entra

Quando o tipo cai para `Node2D` ou `Variant` por falta de `class_name` no outro
lado, o problema é lá, não aqui: ver o item 4 do diagnóstico em
[arquitetura.md](arquitetura.md).

## A ordem dentro do arquivo

A ordem oficial do Godot 4.7, na íntegra — vale como checklist de revisão:

```
01. @tool, @icon, @static_unload
02. class_name
03. extends
04. docstring com ##
05. signal
06. enum
07. const
08. static var
09. @export
10. variáveis comuns
11. @onready
12. _static_init() e métodos estáticos
13. virtuais da engine, nesta ordem:
    _init → _enter_tree → _ready → _process → _physics_process → demais
14. métodos sobrescritos
15. métodos públicos
16. métodos privados (_)
17. classes internas
```

Duas notas de leitura do código existente: `player.gd` põe os métodos públicos
(`lock`, `work_toward`, `spend_energy`) **antes** de `_ready`, e
`station_map.gd` declara `enum Action` no meio do arquivo, junto da seção de
edição em lote. Nos dois casos o motivo é proximidade temática, e nos dois casos
a ordem oficial é a de cima — código novo segue a lista.

## Comentários: `##` responde "por quê"

O `##` do GDScript é documentação (aparece no editor e no autocomplete); o `#` é
nota de bastidor. A regra do projeto é mais estreita que a do Godot: **comentário
que descreve o que a linha faz é ruído**; comentário que registra a decisão e o
que foi rejeitado é o ativo mais valioso do repositório.

O padrão a imitar, nessa ordem de qualidade:

- `player.gd` — por que a caminhada é puxada pela distância percorrida e não pelo relógio
- `work.gd` — por que energia vira trabalho nessa ordem e não na inversa
- `station_map.gd` — por que o lote é tudo-ou-nada

A forma que funciona tem três partes: **a decisão**, **o motivo** e **o que foi
tentado antes e recusado**. A terceira é a que impede alguém de refazer o
caminho errado — e é por isso que as tabelas "Versão / Veredito" dos documentos
de arquitetura existem.

## Idioma

A divisão é por **público**, não por tipo de arquivo:

| Onde | Idioma |
|---|---|
| Textos de interface e diálogo | Português, como os documentos de design |
| Código — identificador, nome de arquivo, nome de nó, comentário | Inglês (`player.gd`, `speed`, `_eyes_closed`) |
| Documentação, `CHANGELOG.md`, mensagem de commit | Português |

**Isto mudou em 2026-10-09, e antes era o contrário**: o código de jogo era
escrito em português e só o tooling de execução (`tools/run.ps1`,
`tools/capture.gd`, `package.json`) ficava em inglês. A renomeação passou tudo
para inglês de uma vez — arquivo, pasta, classe, constante, função e nome de nó
da cena —, e por isso quem procurar `mapa_estacao.gd` ou `MapaEstacao` em
commit anterior a essa data vai achar: os nomes velhos são reais, e só pararam
de valer aqui.

**A fronteira que continua valendo é a do público.** Texto que o jogador lê é
português, e o `CHANGELOG.md` e esta documentação também — mudar isso não estava
no pedido e não foi feito. Na prática há um custo conhecido nessa fronteira:
`station_map.gd` devolve a mensagem de recusa em português, então mexer na
redação da interface obriga a abrir a camada de regras. Isso está registrado no
item 5 de [arquitetura.md](arquitetura.md).

Três geradores ficaram de fora e seguem em português: `tools/gerar_interface.py`,
`tools/gerar_tiles_estacao.py` e `tools/conferir_tiles_estacao.py`. Os dois
primeiros são citados por nome pela skill `pixel-art` e pelo agent
`artista-pixel`; renomear exige acertar os três lugares junto. **Ponto aberto.**

## Antes de dizer que está pronto

| Mudou | Verificar com |
|---|---|
| qualquer `.gd` ou `.tscn` | `npm run check` — pega parse e carregamento |
| regra, planta, custo de obra | `npm run test` |
| qualquer coisa visual | `npm run shot` e **olhar** o PNG |
| planta da estação | `npm run shot:planta` |

Nó visual novo precisa de `texture_filter = 1` (Nearest) enquanto o padrão do
projeto for Linear — esquecer é bug silencioso. Ver
[../configuracao-godot.md](../configuracao-godot.md).
