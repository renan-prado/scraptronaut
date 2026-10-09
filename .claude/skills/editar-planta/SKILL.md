---
name: editar-planta
description: Alterar a planta inicial da Estação Lastro — salas, corredores, divisórias, portas, portão do hangar, onde o jogador nasce, onde fica a cama. Use quando o pedido for mudar o tamanho, a forma ou a topologia da estação inicial, acrescentar ou remover sala, ou mover a posição de partida.
---

# Editar a planta inicial

A planta **não está em documento nenhum** — está nas constantes de
`scripts/station_map.gd`, a partir da linha ~139. `tools/build_station.gd`
as lê para posicionar o nó da cama na cena.

> `docs/Estacao-Lastro-grid-e-modulos.md` descreve módulos de 12×12 com passo de
> encaixe de 11 células. **Isso não é mais o que o código faz** — o mapa é livre,
> célula a célula, desde 2026-10-03. O conflito está registrado em
> `docs/decisoes/abertas.md` e nunca foi resolvido. Não use aquele documento como
> especificação da planta.

## As seis constantes, que mudam juntas

| Constante | O que é | Hoje |
|---|---|---|
| `INITIAL_ROOMS` | `Array[Rect2i]`, e o piso é a **união** de todos | 12 retângulos, caixa útil 30×21 |
| `INITIAL_WALLS` | divisórias que fecham a boca de cada corredor | 4 células |
| `INITIAL_DOORS` | portas de **duas células encostadas**, aos pares | 8 células = 4 portas |
| `INITIAL_GATE` | portão do hangar, cinco células na parede leste | coluna 31, linhas 5–9 |
| `INITIAL_PLAYER_CELL` | onde o jogador nasce | `(15, 9)` |
| `BED_CELL` | cabeceira; a peça ocupa esta e a de baixo | `(3, 2)` |

**Os retângulos de `INITIAL_ROOMS` se sobrepõem de propósito** — é a sobreposição
que produz salas recortadas em vez de caixas iguais. Sala com saliência ou degrau
é dois ou três `Rect2i` sobrepostos, como o Armazém (`2,2,6,7` + `3,9,5,3`).

## O sétimo lugar: o teste

`tools/test_station.gd` repete coordenadas da planta **em números literais** —
divisória em `(10,11)`, porta em `(10,9)`, portão em `(14,15)`, e o trajeto que o
jogador percorre atravessando a porta.

Isso é de propósito: é o que impede uma mudança de planta de passar sem ninguém
conferir. **Mudar a planta sem mudar o teste reprova `npm run test`**, e é o sinal
funcionando, não um defeito.

## O que o código deriva sozinho, e não se escreve

Não existe constante de parede externa. O casco é **derivado a cada
reconstrução**: toda célula vazia encostada no interior é candidata, e um
flood-fill de fora para dentro decide o que é casco maciço (alcança o espaço
aberto) e o que é **buraco** (cercado pela estação — vão aberto com parede em
volta). Quem pinta piso ganha parede de graça.

Também derivados: borda de contato, canos e luminárias, cones de beira, o segmento
de cada porta e os agrupamentos de vão que abrem juntos.

## Duas regras que a planta precisa respeitar

1. **Nada pode isolar parte da estação do jogador.** A validação usa
   `is_walkable`, e um corredor sem porta parte a estação em duas
2. **Porta ocupa exatamente duas células encostadas**, aos pares em
   `INITIAL_DOORS`. Meia porta não fecha vão nenhum, e `can_door_at()` recusa

## Fluxo

```powershell
# 1. editar as constantes em scripts/station_map.gd

# 2. a cama é posicionada pelo gerador a partir de BED_CELL
npm run build:station

# 3. o jogo ainda carrega?
npm run check

# 4. o teste reprova — atualizar as coordenadas literais de tools/test_station.gd
npm run test

# 5. OLHAR a estação inteira, que é o que shot:planta existe para mostrar
npm run shot:planta
```

Terminando: registrar no `CHANGELOG.md` (skill `registrar-mudanca`) e atualizar
o parágrafo da planta em `docs/arquitetura/mapa-da-estacao.md`, que cita as
dimensões e a data do último encolhimento.
