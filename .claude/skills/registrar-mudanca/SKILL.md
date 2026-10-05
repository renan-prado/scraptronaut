---
name: registrar-mudanca
description: Registrar uma mudança no CHANGELOG.md do Scraptronaut e comitar. Use sempre antes de comitar, e quando o pedido for "commita", "registra isso", "atualiza o changelog" ou ao fechar qualquer trabalho que tocou código, arte, documentação ou tooling.
---

# Registrar mudança e comitar

Regra do projeto: **todo commit entra no `CHANGELOG.md`**, em `[Não lançado]`,
**antes** do commit — na mesma mudança, não depois.

## A pergunta que a entrada responde

O que mudou **para quem joga, ou para quem mexe no código**. Não o que mudou no
arquivo: `git log` já conta os arquivos, e o changelog existe para contar a
consequência.

| Ruim | Bom |
|---|---|
| "Altera `TRABALHO_POR_CELULA`" | "Custo de obra caiu seis vezes: piso de 75 para 12,5 por célula — a escala anterior deixava o dia acabar antes de uma célula fechar" |
| "Refatora `mapa_estacao.gd`" | "Desenho da estação saiu para `pintor_da_estacao.gd`; `MapaEstacao` segue sendo a fachada e nenhuma chamada externa mudou" |
| "Corrige bug na porta" | "Porta de duas células deixou de sair com duas emendas âmbar, que liam como duas portinhas" |

## As seis seções

| Seção | Para |
|---|---|
| `Adicionado` | funcionalidade que não existia |
| `Alterado` | comportamento que existia e mudou |
| `Corrigido` | bug |
| `Removido` | o que saiu |
| `Equilíbrio` | número de jogo recalibrado — custo, ritmo, alcance |
| `Interno` | refatoração, doc, tooling, teste: nada que o jogador note |

`Equilíbrio` é separado de `Alterado` de propósito: número de jogo é recalibrado
muitas vezes, e quem for recalibrar de novo precisa achar rápido **de quanto para
quanto** e **por quê**. Toda entrada de equilíbrio traz os dois, e, quando houve,
o que foi recusado — "141 marteladas por quadrado foi recusado por acabar rápido
demais".

## Passos

1. **Ler o que mudou de verdade**, não o que foi pedido:
   ```powershell
   git status --short
   git diff --stat
   ```
2. **Escrever a entrada** em `## [Não lançado]`, na seção certa. Criar a seção se
   não existir, na ordem da tabela acima
3. **Conferir se a documentação acompanhou.** A doc deste projeto registra *por
   que* cada escolha foi feita; mudança que deixa a doc mentindo custa mais do
   que rendeu:

   | Mexeu em | Atualizar |
   |---|---|
   | mapa, tiles, portas, casco | `docs/arquitetura/mapa-da-estacao.md` |
   | construção, canteiro, demolição | `docs/arquitetura/construcao-e-obra.md` |
   | energia, custo, dia, cama | `docs/arquitetura/trabalho-energia-e-dia.md` |
   | movimento, sprite, pose | `docs/arquitetura/personagem-e-animacao.md` |
   | HUD, barra, menu, zoom | `docs/arquitetura/interface-e-camera.md` |
   | árvore de cenas, acoplamento, input | `docs/arquitetura/README.md` |
   | decisão nova do usuário | `docs/decisoes/aprovadas.md` ou `abertas.md` |

4. **Verificar**, conforme o que mudou:
   ```powershell
   npm run check    # qualquer .gd ou .tscn
   npm run test     # regra, planta, custo de obra
   npm run shot     # qualquer coisa visual — e OLHAR o PNG
   ```
5. **Comitar**, assunto em português: verbo no imperativo ("Adiciona CLAUDE.md e
   versiona documentos de design") ou o nome do que foi entregue ("Protótipo
   jogável da Estação Lastro", "Energia, obra que custa trabalho e os estados do
   personagem") — o histórico usa as duas formas. O corpo explica o **por quê**
   quando não é óbvio pelo assunto

## Quando cortar uma versão

`[Não lançado]` vira `[0.x.0] — AAAA-MM-DD` quando o usuário pedir. Antes do
1.0.0 o jogo é protótipo e `0.x` pode quebrar o que quiser; o critério prático em
uso é **um bloco de trabalho que mudou como o jogo se joga**. Ao cortar,
acrescentar o link de comparação no fim do arquivo, no padrão dos que já estão lá.

## O que não entra

Nada de `screenshots/` (está no `.gitignore`) nem de `.godot/` (cache local).
Mudança que só existe na máquina de quem desenvolve não é mudança do projeto.
