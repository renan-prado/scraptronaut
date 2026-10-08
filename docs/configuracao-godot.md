# Configuração do projeto e trabalho com Godot 4.7

Carregar para mexer em `project.godot`, renderização, resolução, filtro de
textura ou ao criar cenas e recursos.

## O que está verificado

`project.godot` — `config_version=5`, `config/features=PackedStringArray("4.7", "GL Compatibility")`.

- **Engine: Godot 4.7** (binário 4.7.2-stable), perfil **GL Compatibility**
- `run/main_scene = "res://cenas/estacao.tscn"`
- `renderer/rendering_method = "gl_compatibility"` (desktop e mobile)
- `rendering_device/driver.windows = "d3d12"`
- `window/stretch/mode = "canvas_items"`, `window/stretch/aspect = "expand"`
- `3d/physics_engine = "Jolt Physics"` — valor padrão do editor; **irrelevante** para um jogo 2D
- Não há `window/size/viewport_width` / `viewport_height` definidos → a resolução base é o padrão do editor (1152×648), que é o tamanho das capturas
- `gui/theme/custom_font = "res://assets/interface/vt323.ttf"` — a fonte de todo o texto do jogo, desde 2026-10-06. Todo `Label`, `Button` e `RichTextLabel` nasce com ela, e o corpo se escolhe por `Fonte.MIUDO`/`MEDIO`/`GRANDE`, nunca por número solto. É uma fonte **vetorial com desenho de pixel**: `antialiasing`, `hinting` e `subpixel_positioning` têm de ficar em **0** no `.import`, senão ela sai borrada sem erro nenhum
- `gui/theme/default_font_size = 20` — o corpo de todo `Button` e `Label` que não pede outro, e **tem de estar escrito**: sem ele o padrão é o do engine, 16, que é um dos corpos em que esta fonte sai com traço desigual. É o mesmo valor de `Fonte.MIUDO`, e há verificação disso em `tools/testar_estacao.gd`

  Os porquês dos dois estão em [arquitetura/interface-e-camera.md](arquitetura/interface-e-camera.md)
- Não há `rendering/textures/canvas_textures/default_texture_filter` definido → **o filtro padrão do projeto continua Linear**

Sobre o filtro: a pixel art não está borrada porque `estacao.tscn` define `texture_filter = 1` (Nearest) nó a nó — nos dois TileMapLayer e nos dois Sprite2D. É contorno, não correção. **Todo nó visual novo precisa repetir esse ajuste** enquanto o padrão do projeto não mudar; esquecer disso é um bug silencioso que só aparece ao olhar a tela.

Esses pontos são lacunas reais, mas a correção é uma **proposta aberta** (ver abaixo), não uma decisão tomada.


## Trabalhando com Godot 4.7

- Confirmar a API na documentação **4.7** (Context7: `/websites/godotengine_en_4_7`) antes de escrever código. Não assumir assinaturas de memória nem reaproveitar padrões de Godot 3.x
- `project.godot` é editado pelo editor. Alterar à mão funciona, mas o editor pode reescrever e reordenar o arquivo
- `.godot/` está no `.gitignore` — é cache local e nunca deve ser comitado
- Scripts `.gd` referenciados por cenas ou recursos precisam de um `.uid` companheiro gerado pelo editor (Godot 4.4+). Criar um `.gd` fora do editor exige abrir o projeto para que o `.uid` apareça. **Exceção:** script rodado via `-s` (como `tools/capture.gd`) é carregado por caminho e funciona sem `.uid`
- Depois de mexer em script ou cena, rodar `npm run check`: ele pega erro de parse e de carregamento sem abrir o editor. Para conferir o resultado visual, `npm run shot` e olhar o PNG
- O perfil **GL Compatibility** limita a renderização: sem SDFGI, sem volumetric fog, e vários parâmetros de `CanvasItem`/shader se comportam de forma diferente do Forward+. Verificar o suporte antes de propor efeitos visuais
- `.gitattributes` normaliza EOL para LF; `.editorconfig` define UTF-8. GDScript usa **tabs** para indentação (padrão do estilo oficial)
- Ao criar cenas e recursos, preferir o editor quando a estrutura importa; `.tscn` escrito à mão quebra com facilidade por causa de `uid://` e `load_steps`

