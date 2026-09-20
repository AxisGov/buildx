---
description: Retoma um projeto do buildx interrompido, a partir do estado em disco — detecta a etapa, a feature em andamento, e continua sem repetir trabalho.
---

Use a skill `buildx`.

Uma execução do buildx é longa e pode ser interrompida a qualquer momento. Todo o estado está em disco: este comando o lê e continua.

## 1. Detecte a etapa

| Estado do disco | Etapa |
|---|---|
| `docs/projeto/PROJETO.md` não existe | B1 — peça a descrição do projeto |
| `PROJETO.md` existe, `docs/stack/CONVENCOES.md` não | B2 |
| `CONVENCOES.md` existe, `MAPA.md` não | B3 |
| há feature `pendente` ou `em_andamento` no `MAPA.md` | B4 |
| todas `entregue` ou `bloqueada`, recursão desatualizada | B5 |
| sem pendência resolvível, `VALIDACAO.md` não existe | B6 |
| `VALIDACAO.md` com `veredito: aprovado` | concluído |

## 2. Se havia feature em andamento

Não recomece a feature — e **não rode `mergex-abrir` para retomar**. Cada feature tem uma árvore de trabalho própria, aberta pela F1 do sprintx.

### Primeiro, situe-se

```
git rev-parse --abbrev-ref HEAD        # deve ser buildx/<projeto_id>
git fetch origin                        # havendo remoto
git rev-parse HEAD  e  git rev-parse origin/buildx/<projeto_id>
git worktree list --porcelain
git log --oneline -3
```

Se este comando foi chamado **de dentro de um worktree de feature**, o estado do projeto está no checkout de controle, não aqui: leia-o de lá antes de decidir.

**O Git é a verdade; o `MAPA.md` é derivado.** Onde os dois discordarem, o Git ganha — e o mapa é corrigido.

### A matriz

Leia o `slug` da feature no `MAPA.md`. `CONTROL` = `buildx/<projeto_id>`. `BASE_SHA` = o `HEAD` de `CONTROL`, congelado desde o commit `em andamento`. `INTEGRADA` significa `git merge-base --is-ancestor feature/<slug> CONTROL` responder sim. `SPRINTX` é a resposta de `planejamento.sh fase <slug>`, rodado **de dentro do worktree da feature** — a sprintx é a dona da interpretação do `00-PLANEJAMENTO.md`; o buildx não o lê para decidir.

`ENTREGA` é o `docs/entregas/<slug>/ENTREGA.md` **commitado** no `HEAD` da feature — `git show feature/<slug>:docs/entregas/<slug>/ENTREGA.md` —, nunca o arquivo da worktree. Terminais são exatamente as duas combinações que o E8 da mergex grava ao fechar: `estado: entregue` com `portao: pronto` (linha **L**) e `estado: bloqueado` com `portao: bloqueado` (linha **R**). `ENTREGA` ausente, ou `estado: aberto`, não é terminal: a matriz segue pela `SPRINTX`. Qualquer outra coisa — `estado` ou `portao` ausente ou repetido, valor fora do enum, `entregue` sem `pronto`, `bloqueado` sem `bloqueado` — é **Q**: nunca infira bloqueio.

Avalie **K primeiro**, depois A; com a branch existindo, J e a ancestralidade; então **a `ENTREGA` terminal (L, R)**, depois **o terminal da F6 commitado (T)** — e só então as demais. A `ENTREGA` terminal vem **antes** de qualquer linha que dependa da `SPRINTX` ou do worktree (D, E, F, G, H, I, S, T). Logo depois dela vem a linha **T**, que também não precisa de worktree: o terminal da F6 é lido do `00-PLANEJAMENTO.md` **commitado** no `HEAD` da feature, pela sprintx, e perder o diretório não apaga o que ela gravou e checkpointou (D-38) — a retomada só com a branch chega ao mesmo terminal, e por isso T é avaliada antes de H e I. O `planejamento.sh` descreve a máquina da sprintx, que termina em `aprovado` e ali fica; a `ENTREGA` terminal descreve o resultado da execução. Uma entrega terminal commitada **não é apagada** por um planejamento que permaneceu `F6` / `aprovado` — nem com o worktree perdido, nem com `CHECKPOINT` pendente (D-35). A linha D manda completar o checkpoint antes de qualquer decisão da matriz **somente quando não existe `ENTREGA` terminal commitada**; existindo, L ou R vencem, e o checkpoint pendente fica como está.

| # | O que você encontra | Onde a sessão morreu | O que fazer |
|---|---|---|---|
| **K** | `CONTROL != origin` de qualquer forma inesperada | o remoto mudou durante a parada | **PARE E RELATE.** Sem `pull`, sem merge do remoto, sem `rebase`, sem força |
| **A** | mapa `pendente`, mas `feature/<slug>` ou o worktree **já existem** | antes do commit `em andamento`, ou por criação externa | **PARE E RELATE** a inconsistência. Não reutilize em silêncio, não recrie, não apague |
| **B** | mapa `em_andamento` e a branch **ainda não existe**, ou existe **exatamente** em `BASE_SHA` | antes da F1, ou antes do primeiro checkpoint | branch ausente: invoque a F1 com o briefing — ela nasce **exatamente** em `BASE_SHA`. Branch em `BASE_SHA`: é a mesma branch; siga a sprintx na fase que `SPRINTX` devolver (F1 ou F2) |
| **C** | branch **à frente** de `BASE_SHA` **só com checkpoints da sprintx** (todo commit com `Planejamento: checkpoint`, todo path em `docs/sprintx/features/<slug>/`) | no meio do planejamento | **retomada legítima.** Prove **ancestralidade** (nunca igualdade de tip) e siga pela linha de `SPRINTX` abaixo. **Nunca recrie a branch** |
| **D** | `SPRINTX`: `fase=CHECKPOINT`, `persistencia=pendente`, **sem** `ENTREGA` terminal | depois de uma transição gravada e não persistida | **complete o checkpoint antes de qualquer decisão do buildx** — com `ENTREGA` terminal commitada, a linha é L ou R, nunca D: peça à sprintx `planejamento.sh checkpoint <slug>`. Não bloqueie, não mexa no mapa, não rode B5, não comece outra feature. Recusado de novo (`persistencia_falhou`): **pare e relate**, preservando worktree e branch |
| **E** | `SPRINTX`: `F3` (`aguardando_f3` ou `replanejar`), `F4` ou `F5`, `persistencia=duravel`, sem rodada de replanejamento da execução ativa | no laço F3 ↔ F5 | continue a sprintx **na fase devolvida**, no mesmo worktree. Não conte reprovação, não regere plano por fora |
| **F** | `SPRINTX`: `F6`, `estado=aprovado`, `persistencia=duravel` — com ou sem commits E1 à frente, e **sem** `ENTREGA` terminal — e **sem** `B-NN` `defeito_de_plano` aberto no worktree | aprovado, antes ou durante a execução — inclusive depois de uma rodada aprovada | siga a F6; a sprintx e a mergex retomam de onde pararam, pelas tasks que restam. **Com** `defeito_de_plano` aberto, a execução normal não retoma (D-37): o único passo é o `replanejar-execucao` do passo 3 da F6, e **a sprintx decide e grava** — rodada nova, `replanejamento_execucao_esgotado` ou `replanejamento_execucao_recusado` com o motivo (D-38). **Nenhuma** task nova, e o buildx não classifica nada daqui: o terminal é lido do commit, na linha **T**. Produto sujo no worktree, ou qualquer outra resposta: **pare e relate** |
| **G** | `SPRINTX`: `PARAR`, `estado=orcamento_esgotado`, `persistencia=duravel`, mapa `em_andamento` | depois do checkpoint terminal, antes do registro do bloqueio | **portão terminal pré-F6** (`references/05-construcao.md`); passou, um único commit de estado: pendência `aguardando_classificacao` no `RECURSAO.md` com a evidência commitada e os `PR-NN` reservados, feature `bloqueada` no `MAPA.md`, `features_bloqueadas` no `PROJETO.md`. Falhou, **pare e relate** — nada é escrito |
| **H** | worktree **perdido**, branch à frente com checkpoint | a sessão levou o diretório | reabra o worktree **sobre a mesma branch** (`git worktree prune`, que só limpa registro de diretório inexistente; depois `git worktree add ../<repo>--<slug> feature/<slug>`) e continue pela `SPRINTX` |
| **I** | worktree **perdido**, branch **exatamente** em `BASE_SHA` | antes do primeiro checkpoint | reabra **sobre a mesma branch**, do mesmo jeito, e deixe a sprintx retomar — a F1 que não chegou a checkpoint é refeita por ela |
| **J** | `INTEGRADA`, mapa ainda `em_andamento` | depois do ff, antes do mapa | **não integre de novo.** Promova, do `BUILDX-PREMISSAS.md` da feature, as premissas que ainda faltarem; atualize o mapa (`entregue` + `Integrada em <sha>`) e commite |
| **L** | `ENTREGA.md` **commitado** na branch com `estado: entregue` e `portao: pronto`, e **não** `INTEGRADA` — qualquer que seja a `SPRINTX` | depois do E8, antes do fast-forward | valide o estado commitado (`git show feature/<slug>:…`), a publicação da feature (`push_feito` e `origin/feature/<slug>`) e as seis provas; então integre. **Não reexecute portão, PR ou QA** |
| **R** | `ENTREGA.md` **commitado** na branch com `estado: bloqueado` e `portao: bloqueado`, mapa `em_andamento` — qualquer que seja a `SPRINTX` | depois do E8 bloqueado, antes do registro do bloqueio | **triagem terminal**, gatilho `entrega_bloqueada` (`references/05-construcao.md`), com o `ENTREGA.md` commitado como evidência: um único commit de estado — pendência `aguardando_classificacao` no `RECURSAO.md` com os `PR-NN` reservados, feature `bloqueada` no `MAPA.md`, `features_bloqueadas` no `PROJETO.md`. **Não** volte à F6, **não** deixe o E0 rodar, **não** reabra o `ENTREGA.md`, **não** reexecute E2 a E8, **não** publique a branch |
| **S** | `SPRINTX`: `F3`, `F4` ou `F5` com `replanejamento_execucao=ativo` (`replanejar_execucao`, `aguardando_f4`, `aguardando_f5`, ou `replanejar` de uma F5 reprovada na rodada), `persistencia=duravel`; branch com o produto concluído antes da rodada e **só checkpoints** desde o checkpoint que a abriu (`Fase: f6`, `Estado: replanejar_execucao`) | no meio da rodada de replanejamento da execução | a feature **continua em execução**: siga a sprintx **na fase devolvida**, no mesmo worktree — a revisão do plano, nunca F1, F2 ou F6. **Não** chame `replanejar-execucao` de novo, **não** registre bloqueio, **não** crie pendência nem feature, **não** toque task concluída. `replanejamentos_f6` diferente do número de checkpoints que abriram rodada, ou produto depois da abertura: **pare e relate** |
| **T** | o `00-PLANEJAMENTO.md` **commitado** no `HEAD` da feature está num terminal da F6 — `replanejamento_execucao_esgotado`, `replanejamento_execucao_recusado` (motivo em `recusa_replanejamento_f6`) ou `orcamento_esgotado` **com rodada aberta** —, lido pela sprintx sobre aquele commit; **sem** `ENTREGA` terminal, mapa `em_andamento`. **Com ou sem worktree** | depois do checkpoint terminal da F6, antes do registro do bloqueio | **portão terminal da F6** (`references/05-construcao.md`); passou, um único commit de estado: pendência `aguardando_classificacao` no `RECURSAO.md` com o gatilho daquele terminal — `replanejamento_execucao_esgotado`, `replanejamento_execucao_recusado` (com `causa: <motivo>`) ou `orcamento_f5_esgotado_durante_replanejamento_execucao` —, a evidência commitada e os `PR-NN` reservados, feature `bloqueada` no `MAPA.md`, `features_bloqueadas` no `PROJETO.md`. **Nenhuma** rodada nova, **nenhuma** sucessora, **nenhuma** task reaberta, branch e commits válidos preservados. Motivo fora do enum, registro que a sprintx recusa ou evidência contraditória: **pare e relate** — nada é escrito |
| **M** | mapa `entregue`, e o `PR-NN` já está no `PREMISSAS.md` com o mesmo conteúdo | depois da promoção | **no-op.** A promoção já aconteceu; a existência do id é a marca |
| **N** | o mesmo `PR-NN` existe com conteúdo **diferente** | duas escritas divergentes | **PARE E RELATE.** Não escolha uma das versões |
| **O** | B6 de ciclo **não-final** | validação de um ciclo que vai continuar | a `Branch base` continua sendo `buildx/<projeto_id>`. Não restaure, não gere `PR-FINAL.md`, não abra PR |
| **P** | B6 final, `Branch base` já restaurada, mas commit ou push não completou | no meio do fechamento | **conclua o fechamento** — commit, push, prova de sincronização, PR. Não inicie ciclo novo |
| **Q** | branch da feature não descende de `BASE_SHA`; ou à frente, antes da F6 e fora de uma rodada **S**, com commit que **não** é checkpoint ou com path fora da pasta da feature; ou `SPRINTX` fora de todas as linhas acima; ou `ENTREGA.md` commitado que não é ausente, `aberto` nem uma das duas combinações terminais | base envelhecida, trabalho estranho, contrato quebrado | **PARE E RELATE.** O caminho nunca é recriar, rebasear ou integrar à força |

**Nunca recrie uma branch que já existe**, em linha nenhuma. Worktree e branch se reencontram sempre pela mesma branch; `git` recusando, **pare e relate**. Nunca crie uma segunda branch para a mesma feature.

**Commit à frente não é sinônimo de E1.** Antes da F6, os commits à frente de `BASE_SHA` podem ser checkpoints da sprintx legítimos; depois dela, commits E1 e de entrega. Checkpoint (`Planejamento: checkpoint`) não é task concluída, não é entrega, não é push e não é PR.

Entre **J** e **M** está a diferença que evita promover duas vezes: a promoção é idempotente **pelo `PR-NN`**, não por marcação — mesmo id com mesmo conteúdo já está promovido.

### O que nenhuma retomada faz

Integrar duas vezes — o fast-forward repetido é no-op, e é por isso que **L** é seguro. Promover a mesma premissa duas vezes — o `PR-NN` é a marca. Mover `CONTROL` para um SHA que ninguém esperava. Sobrescrever o remoto. Publicar a branch de uma feature — quem publica é a mergex. Devolver à F6 uma feature com `ENTREGA` terminal commitada — o E0 a reabriria. Recriar branch existente. `stash`, `reset` destrutivo, `--force`, `pull` automático, ou resolver divergência sozinha.

## 3. Confirme o modo

Leia `modo` no frontmatter do `PROJETO.md` e siga o que está gravado. **Não pergunte de novo** — a pergunta única já foi feita, e refazê-la é violar a regra 1 por um detalhe de sessão.

## 4. Relate onde parou, e siga

Uma linha dizendo o que encontrou e o que vai fazer. Depois continue até o fim, sem perguntar mais nada.

```
Retomando <projeto> na etapa B4, feature FT-05 (sprint 2 de 3). Modo autônomo.
```
