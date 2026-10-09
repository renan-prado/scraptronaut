# Testes

Carregar para rodar ou escrever teste.

## O que existe

| Arquivo | Cobre | Como rodar |
|---|---|---|
| `tools/test_station.gd` | 190 verificações: colisão da planta inicial, regras de construção em lote, peça de porta, portão, demolição, custo de obra contra `MAX_ENERGY`, mira do `F`, expansão sobre o casco, importação e grade da fonte, tampa de tecla, painel do HUD e divisões da barra, câmeras | `npm run test` |
| `tools/test_player.gd` | troca de linha e de quadro na folha de 8 direções | `./tools/run.ps1 -Script tools/test_player.gd` |

O segundo **não tem atalho em `package.json`** — é um teste de regressão de
sprite, rodado à mão quando a folha de caminhada muda.

## O arnês

Os dois são `SceneTree` rodados com `--script`, e **saem com o número de
falhas**: zero é sucesso, e qualquer outro valor reprova em verificação
automática sem precisar ler a saída.

```gdscript
func _check(name: String, actual: Variant, expected: Variant) -> void
func _refused(name: String, reason: String, should_refuse: bool) -> void
```

`_refused` existe porque as regras de construção devolvem a mensagem de recusa
como `String`, e o que o teste quer saber é só **se** recusou — comparar a prosa
amarraria o teste ao texto da interface.

Um teste novo é uma chamada a uma dessas duas funções. Não há descoberta
automática: tudo corre dentro de `_initialize()`, na ordem em que está escrito,
sobre **uma única** instância de `scenes/station.tscn` carregada no começo.

## As três armadilhas

**1. Dois `await physics_frame` antes de qualquer consulta.** A cena precisa dos
dois quadros para que `_ready` corra e o mapa se reconstrua. Teste que consulta
antes vê um mapa vazio e falha de um jeito que parece bug de regra.

**2. Coordenadas de célula estão escritas à mão.** `test_station.gd` repete
células da planta inicial em números literais. Mexer em `INITIAL_WALLS`,
`INITIAL_DOORS`, `INITIAL_GATE`, `INITIAL_PLAYER_CELL` ou
`BED_CELL` quebra o teste — e é de propósito: é o que impede uma mudança
de planta de passar sem ninguém conferir. A skill `editar-planta` lista os seis
lugares a mexer juntos.

**3. O custo de obra é verificado por igualdade.** O teste confere que
`WORK_PER_CELL[FLOOR] × 8 == Player.MAX_ENERGY` e que a barra ganha
divisões quando a energia máxima dobra. Mudar um número sem o outro reprova em
vez de passar despercebido — e é o único lugar onde o equilíbrio do jogo está
travado por teste.

## Estado do arquivo

As 190 verificações estão num `_initialize()` só, sem agrupamento por tema: a
saída diz qual linha caiu, não qual sistema. Agrupar em funções por assunto
(`_test_blueprint`, `_test_building`, `_test_work`, `_test_interface`) é
proposta registrada no item 9 de [../padroes/arquitetura.md](../padroes/arquitetura.md),
e não foi decidida.
