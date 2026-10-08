class_name Fonte
extends RefCounted
## Os corpos de texto do jogo e a fabrica de `Label` que os usa.
##
## A fonte em si nao mora aqui: ela e a fonte padrao do projeto
## (`gui/theme/custom_font` em project.godot), e todo `Label`, `Button` e
## `RichTextLabel` ja nasce com ela. O que mora aqui sao **os tres corpos**, e
## eles precisam de um lugar so por um motivo tecnico.
##
## **A VT323 e vetorial mas com desenho de pixel, e nem todo corpo sai limpo
## nela.** Corpo fora de medida continua desenhando — e sai com traco de
## espessura desigual dentro da mesma palavra, porque as hastes caem em meio
## pixel e a fonte e rasterizada sem antialiasing. Nao ha erro nenhum: so fica
## feio na tela.
##
## **Nao ha formula.** Isto aqui foi medido olhando, em 2026-10-06, com a fonte
## desenhada pela propria engine e ampliada:
##
##   limpos  — 20, 24, 25, 28, 30, 40, 50
##   sujos   — 14, 15, 16, 18, 21, 22, 32, 33, 35, 37
##
## A metrica explica parte (`unitsPerEm` 1000, `capHeight` 560, avanco 400: os
## tres so caem em pixel inteiro em multiplo de 25), mas nao tudo — 24 e 28 sao
## limpos e nao sao multiplos de nada util, e 15 e multiplo de 5 e e sujo. Por
## isso a lista acima vale mais que a conta. **Corpo novo se confere na tela
## antes de entrar.**
##
## Por isso os corpos tem nome: quem escreve interface escolhe entre os tres, e
## nao espalha numero solto que ninguem conferiu.

## O texto que flutua sobre o mundo e o das linhas do painel de ferramentas.
##
## **E tambem `gui/theme/default_font_size`**, e por isso e o corpo de todo
## `Button` e `Label` que nao pede outro. Sem esse ajuste no project.godot o
## padrao seria o do engine, 16 — que esta na lista dos sujos.
const MIUDO: int = 20

## A leitura da placa do HUD: hoje so o contador do dia, dentro do rebaixo.
## Maior que o resto da interface de proposito — e o unico numero que o jogador
## procura em vez de ler de passagem.
const MEDIO: int = 25

## O menu de pausa, e so ele. Ocupa a tela inteira, e corpo de canto de tela
## dentro de um botao de 220 px lia como etiqueta solta no meio do vazio.
##
## **Era 50 e caiu para 30 em 2026-10-06, a pedido:** 50 e o dobro exato de
## MEDIO e foi escolhido quando a regra ainda parecia ser "multiplo de 25", mas
## na tela o menu saiu grande demais.
const GRANDE: int = 30


## Um `Label` com cor e corpo postos.
##
## **Sem contorno.** A VT323 e vetorial, entao `outline_size` hoje funcionaria —
## mas o texto que precisava dele porque flutuava sobre o casco ja tem chapa
## atras: ou a placa do HUD, ou o balao. Contorno aqui so engorda a letra.
static func rotulo(cor: String, corpo: int = MIUDO) -> Label:
	var escrito := Label.new()
	escrito.add_theme_color_override(&"font_color", Color(cor))
	escrito.add_theme_font_size_override(&"font_size", corpo)
	return escrito
