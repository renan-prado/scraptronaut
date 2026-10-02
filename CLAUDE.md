# Scraptronaut

Jogo 2D em pixel art, perspectiva top-down em três quartos, feito em **Godot** com **GDScript**.

O jogador é um sucateiro (Lira / Miro) que atravessa acidentalmente uma fenda espacial, cai numa estação abandonada (Lastro) e precisa recuperá-la, expandir o alcance da nave e reconstruir a tecnologia de travessia para tentar voltar à Terra — onde há uma meia na lavanderia.

## Estado atual do repositório

**O projeto está em branco.** Não existe código, cena, asset ou autoload. Há apenas:

- `project.godot` — configuração mínima gerada pelo editor
- `icon.svg` (+ `.import`) — ícone padrão do Godot
- `docs/` — documentos de design (ainda não versionados; aparecem como untracked)
- Um único commit: `Initial commit: Godot project setup`

A fase atual do projeto é **design**: narrativa, mecânicas e balanceamento. Nada de mecânica foi implementado e nada deve ser implementado sem pedido explícito.

## Documentos de referência

Consultar antes de propor qualquer coisa. São a fonte de verdade do design.

| Documento | Conteúdo |
|---|---|
| `docs/Historia-completa-Scraptronaut.md` | História completa, nomes definidos, personagens, os dois finais, pontos narrativos abertos |
| `docs/Mecanicas-Scraptronaut.md` | Módulos da estação, matérias-primas, energia/combustível, naves, reserva de retorno, as cinco regiões |
| `docs/Mapa-exploracao-Scraptronaut.md` | Mapa radial: locais, raios e ângulos de cada região; ampliação de 2026-10-02 |
| `docs/Mapa-radial-Scraptronaut.html` | Visualização interativa do mapa radial |

**Não alterar a história nem as mecânicas sem pedido explícito.** Esses documentos registram decisões de uma discussão em andamento; mexer num ponto exige saber se ele era aprovado ou aberto.

## Configuração do projeto (verificada)

`project.godot` — `config_version=5`, `config/features=PackedStringArray("4.7", "GL Compatibility")`.

- **Engine: Godot 4.7**, perfil **GL Compatibility**
- `renderer/rendering_method = "gl_compatibility"` (desktop e mobile)
- `rendering_device/driver.windows = "d3d12"`
- `window/stretch/mode = "canvas_items"`, `window/stretch/aspect = "expand"`
- `3d/physics_engine = "Jolt Physics"` — valor padrão do editor; **irrelevante** para um jogo 2D
- Não há `window/size/viewport_width` / `viewport_height` definidos → a resolução base é o padrão do editor (1152×648)
- Não há `rendering/textures/canvas_textures/default_texture_filter` definido → **o filtro padrão é Linear**, que deixa pixel art borrada

Os três últimos pontos são lacunas reais, mas a correção é uma **proposta aberta** (ver abaixo), não uma decisão tomada.

## Decisões aprovadas

Tratar como fixo. Mudanças aqui exigem decisão explícita do usuário.

**Técnico**
- Engine Godot; direção visual 2D pixel art top-down em três quartos
- Linguagem: GDScript
- Jogo de engine, sem obrigação de rodar no navegador
- Steam é possibilidade futura, sem compromisso de lançamento

**Narrativa** — tudo em `Historia-completa-Scraptronaut.md` sob "Nomes definidos" e a sequência principal dos capítulos:
- Nomes: Orbita, Morgon's, Lastro, Aurora, Asterianos (civilização e planeta), Lira/Miro, Nilo, NILO 2, Adonus, Hera, Bobobacau, Dricono, Macrovolvulador-extremamicrobacteriano, Terra
- A mãe do protagonista permanece sem nome; o funcionário da corporação e a lavanderia também
- Dois finais: atravessar a fenda ou ficar na Lastro
- A finalidade do Macrovolvulador nunca é revelada, em nenhum final

**Mecânicas**
- Estação inicial com 6 módulos; computador de Nilo, armazém e prensa começam quebrados
- 11 módulos aprovados (pátio central, corredor, armazém, hangar, oficina de desmontagem, prensa, refinaria energética, fábrica de eletrônicos, habitação, módulo de Dricono, módulo de estabilização)
- Energia como **unidade única**; combustível em três estágios: bruto, refinado, concentrado
- 5 naves com especialidades distintas (sucateira, cargueira, exploradora, planetária, de travessia)
- **Reserva de retorno**: a nave reserva combustível para voltar à Lastro e inicia retorno automático ao atingir o limite — sem punição, sem perda de carga. Três estados de painel: Seguro / Reserva próxima / Limite atingido
- **5 regiões de alcance**; a expansão por distância termina na terceira região planetária (Asterianos). Depois disso a progressão é por profundidade dentro das regiões existentes — **não há sexta região**
- Mapa radial com Lastro no centro; locais posicionados por raio + ângulo (norte = 0°, sentido horário)

## Propostas abertas

Não tratar como design nem implementar sem decisão. Lista completa em "Próximas definições" (`Mecanicas-`) e "Pontos ainda abertos para desenvolvimento" (`Historia-`).

**Técnico**
- Resolução base do viewport (p. ex. 640×360) e modo de stretch definitivo — para pixel art a documentação do Godot 4.7 recomenda stretch `viewport` com scale mode `integer`; o projeto hoje usa `canvas_items` + `expand`
- Adotar `Nearest` como filtro de textura padrão do projeto
- Remover ou manter as configurações 3D herdadas do editor
- Estrutura de pastas, autoloads, arquitetura de cenas, formato de save — nada decidido
- Se `docs/` entra no versionamento

**Design**
- Produtos que cada módulo fabrica ou recupera; moldes, receitas e aplicações dos materiais
- Rendimentos energéticos e concentrações; nome e natureza do recurso energético
- Capacidades, custos, níveis e melhorias de naves e módulos
- Regras de imprevistos, resgates e dívidas; papel de Bobobacau nos resgates
- Materiais e descobertas de cada região; condições de acesso; distâncias reais de combustível
- Nome do material Asteriano
- Identidades de P1–P9, D1–D15, C1–C3, E1–E4, S1–S4, N1 e das duas luas
- Aparência de Lira/Miro e como a escolha entre as duas versões é apresentada
- Cronologia da jornada em relação ao prazo de noventa dias da lavanderia
- Variações dos epílogos conforme vínculos e decisões do jogador

## Trabalhando com Godot 4.7 + GDScript

- Confirmar a API na documentação **4.7** (Context7: `/websites/godotengine_en_4_7`) antes de escrever código. Não assumir assinaturas de memória nem reaproveitar padrões de Godot 3.x
- `project.godot` é editado pelo editor. Alterar à mão funciona, mas o editor pode reescrever e reordenar o arquivo
- `.godot/` está no `.gitignore` — é cache local e nunca deve ser comitado
- Scripts `.gd` precisam de um arquivo `.uid` companheiro gerado pelo editor (Godot 4.4+). Criar um `.gd` fora do editor exige abrir o projeto para que o `.uid` seja gerado
- O perfil **GL Compatibility** limita a renderização: sem SDFGI, sem volumetric fog, e vários parâmetros de `CanvasItem`/shader se comportam de forma diferente do Forward+. Verificar o suporte antes de propor efeitos visuais
- `.gitattributes` normaliza EOL para LF; `.editorconfig` define UTF-8. GDScript usa **tabs** para indentação (padrão do estilo oficial)
- Ao criar cenas e recursos, preferir o editor quando a estrutura importa; `.tscn` escrito à mão quebra com facilidade por causa de `uid://` e `load_steps`

## Convenções para quando houver código

Baseadas no guia de estilo oficial do GDScript, já que não há código no repositório para imitar:

- Arquivos e pastas: `snake_case`. Classes e nós: `PascalCase`. Funções e variáveis: `snake_case`. Constantes e enums: `CONSTANT_CASE`
- Membros privados com prefixo `_`
- Tipagem estática sempre que possível (`var carga: int = 10`, `func atracar(nave: Nave) -> void:`)
- Ordem no script: `class_name`, `extends`, docstring, `signal`, `enum`, `const`, `@export`, variáveis, `_init`, `_ready`, callbacks da engine, métodos públicos, métodos privados
- Textos de interface e diálogo em **português**, como os documentos de design

## Como responder a pedidos

1. Localizar o assunto nos documentos de `docs/` antes de responder
2. Dizer se o ponto é **aprovado** ou **aberto**. Se aberto, apresentar como proposta e esperar decisão
3. Não implementar mecânica, não criar cena, não alterar a narrativa sem pedido explícito
4. Se um pedido conflita com uma decisão aprovada, apontar o conflito antes de executar
