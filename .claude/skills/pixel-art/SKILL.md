---
name: pixel-art
description: Desenhar ou alterar arte do Scraptronaut — sprite, tile, atlas, ícone, objeto de cenário — pelos geradores Python de tools/. Use quando o pedido envolver criar, redesenhar ou ajustar qualquer imagem do jogo (parede, piso, cano, cone, porta, personagem, pose, HUD, barra, ícone de ferramenta), mexer em RECUO/espessura de parede, em máscara de vizinhança, ou quando a arte "ficou estranha" na tela.
---

# Pixel art do Scraptronaut

A arte deste jogo **não é desenhada à mão em editor de imagem** (com uma exceção:
a folha de caminhada do personagem, em `docs/sprites-paste/`). Ela é desenhada
**em código Python**, em `tools/gerar_*.py`, e reexecutar o gerador sobrescreve o
PNG. Alterar arte significa alterar o gerador.

## A regra que vem antes de todas

**Mock aprovado fora do Godot já ficou feio na tela.** Nenhuma alteração de arte
está pronta antes de rodar o jogo e olhar:

```powershell
python tools/gerar_tiles_estacao.py   # ou o gerador que você mexeu
npm run check                         # pega erro de import/cena
npm run shot                          # e OLHE o PNG em screenshots/
npm run shot:planta                   # quando a mudança afeta a estação inteira
```

Conferir pelo PNG do atlas isoladamente não serve: o tile aparece **ladrilhado,
vizinho de outros, por cima da sombra de contato e sob a câmera em três quartos**.
É nessa composição que os erros aparecem.

Nó visual novo precisa de `texture_filter = 1` (Nearest) — o padrão do projeto
ainda é Linear, e esquecer disso borra a pixel art em silêncio.

## A grade

| Medida | Valor | Onde |
|---|---|---|
| célula de cenário | **64 px** | `MapaEstacao.CELULA` |
| personagem | 64 px por célula, folha 4×8 | `assets/sprites/` |
| folha de trabalho | **100×110**, não 70×100 | a picareta alcança 30 px e a cabeça da ferramenta cairia fora nas vistas laterais |
| recuo do casco | `RECUO = 20` | `tools/gerar_tiles_estacao.py` |

`RECUO` é **o único número que controla a espessura aparente da parede**, e
`tools/construir_estacao.gd` repete o valor para a colisão acompanhar a arte:
mudar um exige mudar o outro, e regenerar os dois.

> O valor atual de `RECUO` **nunca foi aprovado explicitamente** pelo usuário.
> Mudança de espessura de parede é decisão dele, não ajuste técnico.

## Emenda entre células: o período precisa dividir 64

Qualquer padrão que corra ao longo de uma parede ou de um piso atravessa a divisa
entre duas células do mesmo tipo. Se o período não divide 64, a emenda aparece
como degrau.

| Padrão | Período | Por quê |
|---|---|---|
| ondulação do raio do cano | **64** | qualquer outro quebra a emenda entre duas células da mesma corrida |
| listra de perigo a 45° | **16** | divide 64, atravessa a emenda sem degrau |

Detalhe que **denuncia** a divisa fica longe da borda: a ferrugem para a 8 px das
bordas, e a faixa de perigo começa a 9 px — depois da sombra de contato, que
alcança 7. Encostada nela, a faixa some no escuro.

## Volume se pinta em bandas, não em degradê

O cilindro do cano é **três faixas chapadas mais um fio de brilho**. O degradê
contínuo foi tentado e saiu lavado de branco: pixel art de tubo lê melhor em
bandas.

Pela mesma razão, ferrugem é **escorrido fino na metade de baixo**, nunca mancha
redonda — mancha vira lama.

E peça que invade de propósito: o tubo tem raio 11 com eixo em 13, então **não
cabe no recuo de 20 px**. Ele monta por cima da borda externa do casco invadindo
~4 px da banda clara, e é isso que o faz ler como peça parafusada no casco em vez
de desenho flutuando ao lado dele.

## Deformar personagem: por linha ou por bloco, nunca rotação

A arte toda usa contorno de **um pixel**, e rotação esfarrapa contorno de um
pixel. Todo gesto em `tools/gerar_miro_estados.py` é cisalhamento ou compressão:

| Gesto | Técnica | Quanto |
|---|---|---|
| respiração (parado) | compressão por linha, pés fixos | 2 px numa figura de 93 — 3 px já lê como agachamento |
| inclinação (golpe) | cisalhamento por linha, pivô no chão | 8 px no topo da cabeça, ~2 na mão, 0 nas botas |
| agachamento (golpe) | a mesma compressão da respiração | 4 px no impacto |
| braço | a mão sobe, encurtando o braço | 7 px no quadro erguido, 0 no impacto |

Três travas aprendidas na tela, e as três custaram uma versão recusada:

- **A compressão se reparte entre pescoço e cintura**, senão abre um degrau no pescoço
- **A mão nunca desce abaixo da origem.** Subir encurta o braço, e a luva cobre o antebraço; descer abre um vão entre punho e manga, que lê como braço descolado. O **impacto é o zero da escala**
- **A mão é recolocada por cima da ferramenta.** Com a mão por baixo, a empunhadura larga some sobre ela e o quadro sai com um bloco vermelho no lugar — ninguém segurando nada

Para achar a mão, o preenchimento começa no centroide da luva e aceita **do
vermelho escuro ao realce claro** — parar no vermelho médio deixa a sombra da
manga para trás, e ela aparece no lugar antigo como anel vazado. Mas **não aceita
o quase-preto**: o contorno é um fio contínuo da luva até a bota, e aceitá-lo faz
o preenchimento correr por ele e tomar a coxa. O contorno entra depois, por
crescimento. Uma caixa em volta da mão é a trava final.

Objeto desenhado por cima resolve o que deformação não resolve: o **cobertor** do
estado dormindo não é enfeite — sem ele o desenho das pernas em pé continuaria
visível e leria como alguém de pé visto de cima.

## Atlas indexado por máscara de vizinhança

Casco, borda e demarcação **não usam regra de autotile**: cada um é um atlas de
**256 células indexado por máscara de 8 bits** da vizinhança, e o script lê
`Vector2i(mascara % 16, mascara / 16)` direto. Buraco, cones e marcação usam o
mesmo princípio com **4 bits** (16 células), só os lados cardeais.

É isso que deixa a planta ter qualquer formato.

**A ordem dos bits está em `DIRECOES`, em dois arquivos:**
`scripts/mapa_estacao.gd` **e** `tools/gerar_tiles_estacao.py`.

> Mudar de um lado só embaralha o atlas inteiro **em silêncio** — e o resultado
> ainda parece plausível na tela. É o erro mais caro desta base de código.

Marca de **área** se indexa pela vizinhança; marca por **célula** vira padrão de
papel de parede. A primeira demarcação marcava célula por célula, com cantoneira
nos quatro cantos: as pontas de quatro vizinhas se encontravam e nascia um `+`
âmbar no meio do nada, que foi recusado.

## Cor que o Control colore vem em cinza

As peças da barra de energia saem do gerador **em cinza**, e quem as tinge é
`barra_energia.gd`. Desenhá-las já verdes travava a cor: o aviso de energia baixa
é vermelho, e nenhuma multiplicação leva verde a vermelho — o R teria de crescer
onde o G já está alto, e o que saía era oliva.

Peça que o Control estica deve ser fatia de **um pixel** na direção do esticamento:
esticar na horizontal repete colunas, e numa moldura de linhas horizontais isso
não deforma nada.

## Os geradores

| Gerador | Saída |
|---|---|
| `tools/gerar_tiles_estacao.py` | os onze atlas de `assets/tiles/estacao/` + `assets/interface/ferramentas.png` |
| `tools/gerar_miro_8dir.py` | `assets/sprites/miro_8dir.png`, da arte feita a mão |
| `tools/gerar_miro_estados.py` | `miro_parado`, `miro_trabalho`, `miro_dormindo` — **depende da folha acima** |
| `tools/gerar_objetos.py` | `assets/objetos/cama.png` |
| `tools/gerar_interface.py` | `assets/interface/energia.png` |
| `tools/construir_estacao.gd` | `recursos/tileset_estacao.tres` (inclusive os 256 polígonos de colisão) |

`tools/folha_miro.py` é biblioteca, importada por `gerar_miro_8dir.py` — não
apagar. `conferir_miro_8dir.py` e `conferir_tiles_estacao.py` só inspecionam.

A cama existe em **dois** geradores que precisam concordar: `gerar_objetos.py`
desenha o móvel e `gerar_miro_estados.py` desenha quem está deitado nele. O
travesseiro, a dobra do lençol e o pé da cama estão nas alturas em que a cabeça,
o peito e os pés da vista frontal caem. Mexer numa pede conferir a outra.

## Fluxo de uma alteração

1. descobrir qual gerador produz o arquivo (tabela acima)
2. ler o trecho que desenha a peça — os comentários registram o que já foi recusado
3. alterar, respeitando grade, período e técnica de deformação
4. reexecutar o gerador, e os dependentes se houver
5. `npm run check`, `npm run shot`, **olhar**
6. se mexeu em máscara: conferir `DIRECOES` nos dois arquivos
7. se mexeu em `RECUO`: `npm run build:estacao` para a colisão acompanhar
8. registrar no `CHANGELOG.md` (skill `registrar-mudanca`) e atualizar o documento
   de arquitetura do assunto
