# Integração — sprintx

O sprintx planeja e executa uma feature, F1 a F6. O buildx o invoca uma vez por feature do `MAPA.md`, dentro do laço do B4.

## A divisão

| Pergunta | Quem responde |
|---|---|
| Que sistema é este? | buildx, B1 (via prodx) |
| Quais features ele tem? | **buildx, B3** — o vão que só o buildx preenche |
| Em que ordem? | buildx, B3 |
| Como construir esta feature? | sprintx, F3 |
| Em que ordem dentro da feature? | sprintx, F3 |
| Quanto custa? | sprintx, F3.5 |

O sprintx é excelente em profundidade e não tem opinião sobre largura: ele planeja *uma* feature com rigor e não sabe olhar um sistema e decidir onde cortar. O buildx corta; o sprintx aprofunda.

## A F1 é dona da área de trabalho

A regra 21 do sprintx — **uma feature por árvore de trabalho** — é anterior a qualquer coisa que o buildx faça na feature. Com git, a F1 cria ou retoma um `git worktree` próprio, em diretório irmão do checkout (`../<repo>--<slug>`), na branch `feature/<slug>`. Tudo da feature passa a viver lá: `docs/sprintx/features/<slug>/` e o código.

| Quem | Faz |
|---|---|
| sprintx F1 | cria ou retoma o worktree e a branch `feature/<slug>` |
| buildx | entra no worktree que a F1 abriu, conduz F2 → F6, **lê o resultado da entrega** e volta ao checkout de controle |
| sprintx F6 | conduz a entrega inteira: aciona a mergex no E0, no E1 de cada task e em E2 → E8 depois do `FECHAMENTO.md` |
| mergex | acionada **sempre pela sprintx**, nunca pelo buildx; no E0 apenas adota a branch que a F1 abriu |

O buildx **não abre branch, não abre worktree e não invoca `mergex-abrir`**. Se a F1 anunciar a área de trabalho e encerrar a fase — o comportamento dela quando o harness não troca de árvore sozinho —, continue de dentro do diretório indicado.

### De onde a feature nasce

A F1 resolve a base sozinha, e a **primeira precedência dela é a seção de versionamento do `CONVENCOES.md`**. É exatamente por isso que o B2 grava ali:

```
Branch base: buildx/<projeto_id>
```

como convenção estabelecida — nunca `PROPOSTA`, que por contrato não governa. Sem argumento novo, sem campo no `ORQUESTRADOR.md`, sem tocar no `expx-schema`: o buildx escreve uma convenção que a sprintx **já lê hoje**, e que sobrevive à morte da sessão porque está no disco.

Depois que a F1 abrir a área de trabalho, o buildx confere que a base foi mesmo essa (`git merge-base --is-ancestor <BASE_SHA> feature/<slug>`). Não foi: **para e relata** — integrar depois seria impossível.

Sem git, ou com "sem worktree" explícito, a F1 trabalha na árvore atual (`worktree: null` no `ORQUESTRADOR.md`) e nada disso muda para o buildx.

**O que o buildx guarda de cada feature** é só o que cabe no `MAPA.md` — id, slug, status, PR. O detalhe fica no worktree dela, e o buildx o lê de lá; como não há merge automático, ele **não** aparece no checkout de controle.

## O que o buildx entrega por feature

Um briefing montado do `MAPA.md`, `PROJETO.md` e `PREMISSAS.md` — o mesmo papel do `BRIEFING.md` do prodx num pedido isolado:

| Campo | De onde vem | Por que a F1 não teria sozinha |
|---|---|---|
| problema | `entrega` da feature | o requisito já destilado pelo P2 |
| escopo | o recorte do B3 | a fronteira com as features vizinhas |
| não-objetivos | as features vizinhas, nominalmente | impede a F2 de invadir escopo alheio |
| critérios de aceite de negócio | `PROJETO.md` | os que esta feature cobre |
| premissas aplicáveis | os `PR-NN` que esta feature realiza | as decisões já tomadas, com o que as invalida |
| convenções | ponteiro para `CONVENCOES.md` | o dialeto do projeto, decidido no B2 |

Mais duas chaves no frontmatter de todo artefato da feature: `origem_buildx` (o `projeto_id`) e `feature_id` (o `FT-NN`). São elas que permitem, depois, abrir qualquer plano de sprint e saber de qual projeto e qual feature ele veio.

### O orçamento da F5, declarado no briefing

Além dos seis campos de conteúdo, o briefing de **toda** feature declara o orçamento de reprovações da F5, literalmente:

```
max_reprovacoes_f5: 3
orcamento_declarado_por: buildx
```

**A forma de passagem é a que a sprintx P0.1 já tem**, sem campo novo em artefato nenhum: o pedido que aciona a sprintx traz as duas linhas, e a F1 as repassa ao script dono do estado do planejamento, ao criar o `00-PLANEJAMENTO.md` (`references/01-ingestao.md` da sprintx, Passo 1):

```
bash <raiz-da-sprintx>/scripts/planejamento.sh criar <slug> 3 buildx
```

O buildx **não** cria o `00-PLANEJAMENTO.md`, não o edita e não escreve o orçamento em nenhum outro arquivo — nem no `00-DECISOES.md`, nem no `ORQUESTRADOR.md`, cujos schemas não têm esse campo. O `kind: planejamento` é exclusivo da sprintx e só o script o grava.

`3` significa três **vereditos NÃO**: duas voltas de replanejamento, e a terceira reprovação termina a tentativa. É o mesmo limite que o buildx sempre teve — agora contado por quem roda o laço.

**Depois da F1, a contagem é só da sprintx.** O buildx não incrementa contador, não interpreta "rodada 1/2/3" de prosa nenhuma, não soma linhas `VEREDITO:`, não aumenta o teto e não o reinicia numa retomada (orçamento diferente numa retomada é erro de contrato do próprio script, código `4`).

**Conferência.** Depois do primeiro checkpoint (fim da F2), o buildx confere o orçamento **no commitado** — `git show feature/<slug>:docs/sprintx/features/<slug>/00-PLANEJAMENTO.md` com `max_reprovacoes_f5: 3` e `orcamento_declarado_por: buildx`. Outro teto, ou `null`: **pare e relate** — a feature estaria rodando com um orçamento que o buildx não declarou.

**O briefing não contém decisão técnica** — a mesma fronteira do prodx (regra 10 dele). Arquitetura, camada e biblioteca são do sprintx. A exceção é o `CONVENCOES.md`, que não é decisão desta feature: é o dialeto que o projeto inteiro já adotou no B2, e todas as features o respeitam igualmente.

## A F2 autônoma

**A única regra do sprintx que o buildx quebra**, e a mais séria.

A regra 10 obriga a F2 a entrevistar o humano em blocos de até cinco perguntas, esperando resposta. No modo autônomo isso é incompatível com a promessa: o usuário fechou os olhos.

Então o buildx responde. O procedimento tem quatro degraus, na ordem, sem pular:

| Degrau | Fonte | O que registrar |
|---|---|---|
| 1 | `PROJETO.md` | a seção que responde |
| 2 | `PREMISSAS.md` | o `PR-NN` |
| 3 | `CONVENCOES.md` | a regra |
| 4 | nenhuma responde | **crie a premissa primeiro** — feature-local, em `docs/sprintx/features/<slug>/BUILDX-PREMISSAS.md`, com `origem: f2_autonoma` e `status: pendente_promocao` — e só então responda com ela |

O degrau 4 grava **na feature**, nunca no `PREMISSAS.md` do projeto: estamos dentro da janela fechada, e sujar a árvore de controle ali barraria o fast-forward da própria feature. A promoção ao estado global acontece depois da integração (`references/05-construcao.md`, passo 8).

O degrau 4 é o que separa decisão auditável de invenção. Nunca responda com algo que não esteja escrito em um dos três — se não estiver, escreva antes.

**Cada arquivo tem um dono só.** O `00-DECISOES.md` é da sprintx: o buildx grava ali a **decisão**, no schema `kind: decisoes` **sem acrescentar chave nenhuma**, e a proveniência vai no `motivo` — que, no degrau 4, cita `BUILDX-PREMISSAS.md#PR-NN` e começa com `(HIPOTESE)`, porque a premissa foi assumida, não confirmada. O `BUILDX-PREMISSAS.md` é do buildx: guarda a **premissa** que pode virar estado do projeto. O registro de decisões da feature continua sendo o da sprintx; muda apenas quem decidiu, e isso fica à vista — no campo que ela já tem (D-25).

**O marcador segue a semântica da sprintx, não a do buildx.** Ela declara que decisão **sem** `(HIPOTESE)` é lida como confirmada pelo usuário, em qualquer modo. Então: declaração direta do usuário no pedido ou no briefing vai sem marcador, com a fonte nomeada; premissa assumida pelo buildx e convenção que o próprio buildx decidiu no B2 vão **com** marcador. Os três casos estão em `references/05-construcao.md`, passo 3.

É por isso que a premissa não mora numa seção do `00-DECISOES.md`: o contrato da sprintx cobre o frontmatter `kind: decisoes` e as linhas `D-NN` e `PENDENTE-NN`, e a F2 reexecutada pode regerar o arquivo. Uma seção estrangeira ali obrigaria o buildx a reparar, depois de cada reexecução, prosa que não é dele (D-24).

### A fronteira que a F2 não atravessa

Se a F2 levantar **regra de negócio** que nenhum dos três arquivos responde — prazo de validade de um contrato, se desconto acumula, qual imposto incide — o buildx não decide.

Isso não é requisito não-funcional. É o que o sistema faz, e decidir no lugar do usuário produz um sistema que funciona e está errado — o pior resultado possível, porque parece pronto.

Nesse caso: registre na própria feature, no arquivo do buildx — a premissa provisória no `BUILDX-PREMISSAS.md`, marcada provisória e com `o_que_invalida` preenchido; o `00-BLOQUEIOS.md` é da sprintx — e siga com **a decisão mais reversível possível**, marcada como provisória no código e na premissa. **Nada vai para o `RECURSAO.md` agora:** a `CONTROL` está em `BASE_SHA`, dentro da janela fechada. A pendência global é escrita pelo buildx só quando a tentativa termina — integrada ou encerrada terminalmente (`references/05-construcao.md`, "A triagem imediata") —, e o relatório final abre com essas.

## As regras do sprintx que o buildx não toca

| Regra | Por que se mantém |
|---|---|
| **R3** — TDD obrigatório | a rede que torna a execução autônoma possível. Relaxar aqui é serrar o galho |
| **R4** — task só conclui com os dois testes passando | "concluída com ressalva" não existe, nem no modo autônomo |
| **R8** — dúvida vira bloqueio, nunca parada | já é exatamente o comportamento que o buildx precisa |
| **R14** — a F5 audita e não corrige; achado alto volta à F3 | execução autônoma sem auditoria respeitada é dano autônomo |
| **R15** — proibido código antes da F6 | o B2 entrega esqueleto, não funcionalidade |

A R8 merece nota: ela já foi escrita pensando em execução autônoma, e é o que faz o laço do B4 funcionar sem o buildx precisar inventar tratamento de erro.

## As fases, uma a uma, sob o buildx

| Fase | Sob o buildx |
|---|---|
| F1 ingestão | normal, com o briefing do buildx como entrada. **É ela que abre a área de trabalho**: worktree `../<repo>--<slug>` e branch `feature/<slug>` (regra 21). É ela também que cria o `00-PLANEJAMENTO.md` com o orçamento do briefing (`criar <slug> 3 buildx`), sem checkpoint |
| F2 descoberta | **respondida pelo buildx**, quatro degraus |
| F3 plano | normal. A pergunta da R11 é respondida pelo mesmo procedimento |
| F3.5 estimativa | **opcional.** Não há prazo a negociar; rode se for barata |
| F4 orquestrador | normal |
| F5 auditoria | normal, e obedecida. Cada veredito vira rodada no `historico` e checkpoint; o estado seguinte é da sprintx (`replanejar`, `aprovado` ou `orcamento_esgotado`) |
| F6 execução | normal. É ela que aciona a mergex de ponta a ponta: **E0** no início, **E1** a cada task concluída e, depois do `FECHAMENTO.md`, **E2 → E8**. Quando devolve o controle, a entrega já aconteceu — o buildx lê o resultado, não o refaz. O acabamento visual acontece nas tasks de interface, sobre os tokens do design system (P-6, P-7) |

## O laço F3 ↔ F5, contado pela sprintx

Achado alto manda voltar à F3. Sem limite, isso gira — e o limite é o orçamento que o briefing declarou. Um plano que esgota três reprovações tem problema que replanejar a mesma feature não resolve: normalmente o recorte do B3 estava errado, ou falta decisão.

### O buildx consulta, não interpreta

A sprintx é a dona da interpretação do `00-PLANEJAMENTO.md`. O buildx não duplica a máquina de estados dela: em todo ponto de decisão — depois de cada fase, antes de avançar, numa retomada — ele roda, **de dentro do worktree da feature**:

```
bash <raiz-da-sprintx>/scripts/planejamento.sh fase <slug>
```

e decide só pela saída (`fase=`, `estado=`, `fonte=`, `persistencia=`):

| `fase` | `estado` | `persistencia` | O que o buildx faz |
|---|---|---|---|
| `F1` · `F2` | `null` | qualquer | continua a sprintx nessa fase — nada durável ainda |
| `F3` | `aguardando_f3` · `replanejar` | `duravel` | continua a sprintx na F3 |
| `F4` | `aguardando_f4` | `duravel` | continua a sprintx na F4 |
| `F5` | `aguardando_f5` | `duravel` | continua a sprintx na F5 |
| `F6` | `aprovado` | `duravel` | segue para a F6 — **salvo** `ENTREGA.md` terminal commitado na feature, que precede esta tabela (abaixo) |
| `PARAR` | `orcamento_esgotado` | `duravel` | **portão terminal pré-F6** (`references/05-construcao.md`) |
| `CHECKPOINT` | qualquer | `pendente` | **só completar o checkpoint** — ver abaixo; salvo `ENTREGA.md` terminal commitado, que precede esta tabela |
| qualquer outra combinação, `fonte=legado` depois da F2, `persistencia=disco`, `INCONSISTENTE`, saída vazia | — | — | **pare e relate** |

`persistencia=disco` sob o buildx é parada: significa que o worktree não está na `feature/<slug>` ou não é a raiz do repositório — e o buildx sempre roda a feature com Git, na branch da F1.

**A única leitura que precede esta tabela é a da entrega terminal.** Depois do E8 a sprintx continua respondendo `F6` / `aprovado`: o planejamento terminou aprovado, e é isso que ela descreve. O resultado da execução está no `ENTREGA.md` **commitado** no `HEAD` da feature, e uma entrega terminal — `entregue` com `pronto`, ou `bloqueado` com `bloqueado` — vence a linha `F6`: a feature não volta à F6 e o E0 não roda de novo (`references/05-construcao.md`, passo 6; D-35). Essa leitura não interpreta o planejamento: lê o que a mergex fechou.

### `CHECKPOINT` pendente

`fase=CHECKPOINT` com `persistencia=pendente` diz que a sprintx gravou uma transição no disco que ainda **não está no `HEAD`** da `feature/<slug>`. O estado lógico do arquivo não é durável e **não decide nada**. Enquanto for assim, o buildx **não**:

- marca a feature `bloqueada`;
- avança o `MAPA.md`;
- executa o B5;
- inicia outra feature;
- lê o `estado` do arquivo como se fosse durável.

A ação é uma só: ficar no worktree da feature e pedir à sprintx que complete o checkpoint (`planejamento.sh checkpoint <slug>`, pelo roteiro dela). Só com `fase` voltando a responder um estado durável o buildx decide o próximo passo pela tabela acima.

**A exceção é a entrega terminal commitada.** Com `ENTREGA.md` `entregue` · `pronto` ou `bloqueado` · `bloqueado` no `HEAD` da feature, ela decide mesmo com `CHECKPOINT` pendente: o buildx não completa nem pede o checkpoint para decidir, e a transição pendente fica como está. O que o `CHECKPOINT` impede é decidir pelo planejamento não durável — e aqui quem decide é a entrega, já durável (`references/05-construcao.md`, passo 6; D-35).

**O buildx nunca faz o `git commit` do checkpoint**, nem `git add` da pasta da feature, nem `--no-verify`: o checkpoint é da sprintx (DS-131), e um commit do buildx ali criaria dois donos para o mesmo estado.

### `persistencia_falhou`

Quando o commit do checkpoint é rejeitado (hook do projeto, código `3`, `checkpoint=persistencia_falhou`), **a orquestração daquela feature para**. Não é conclusão metodológica: **não** vira `orcamento_esgotado`, **não** vira `bloqueada`, **não** vira pendência `decisao_humana`. O buildx relata `persistencia_falhou` com a causa que a sprintx devolveu e preserva worktree e branch exatamente como estão. A retomada cai de novo em `CHECKPOINT`, e segue pela regra acima.

### `orcamento_esgotado`

Só é terminal quando `fase` responde `fase=PARAR`, `estado=orcamento_esgotado` **e** `persistencia=duravel`. Mesmo assim, a `CONTROL` só se move depois do portão terminal pré-F6 provar tudo pelo Git — inclusive o `00-PLANEJAMENTO.md` com `estado: orcamento_esgotado` e o `00-AUDITORIA.md` da rodada terminal **commitados** no `HEAD` da feature (`references/05-construcao.md`, "O portão terminal pré-F6"). Working tree não move a `CONTROL`.

### Checkpoint de planejamento não é entrega

O commit da sprintx com o trailer

```
Planejamento: checkpoint
```

não é task concluída, não é commit E1, não é entrega, não é push e não é PR. É o planejamento sobrevivendo à sessão. Por isso a `feature/<slug>` pode estar **à frente de `BASE_SHA` antes da F6** sem que nada tenha sido executado: os commits à frente podem ser checkpoints da sprintx legítimos e, depois da F6, commits E1 e de entrega da mergex. A janela fechada continua inteira — nenhum deles toca a `CONTROL`.

A mergex continua entrando **só na F6** (E0, E1, E2 → E8). O buildx não a antecipa para persistir planejamento.

## Comportamento sem sprintx

O buildx **não roda**. O sprintx é o motor de tudo que acontece no B4. Diga que falta e como instalar (`npx expxdev init`), e pare.
