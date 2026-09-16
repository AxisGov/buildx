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

Leia o `slug` da feature no `MAPA.md`. `CONTROL` = `buildx/<projeto_id>`. `INTEGRADA` significa `git merge-base --is-ancestor feature/<slug> CONTROL` responder sim.

| # | O que você encontra | Onde a sessão morreu | O que fazer |
|---|---|---|---|
| **A** | mapa `pendente`, mas `feature/<slug>` ou o worktree **já existem** | antes do commit `em andamento`, ou por criação externa | **PARE E RELATE** a inconsistência. Não reutilize em silêncio, não recrie, não apague |
| **B** | mapa `em_andamento`, `CONTROL == origin`, branch ainda não existe | depois do commit `em andamento`, antes da F1 | `BASE_SHA := HEAD` de `CONTROL`; invoque a F1 com o briefing. A branch nova tem de nascer **exatamente** nesse SHA |
| **C** | mapa `em_andamento`, branch existe e está **à frente** de `BASE_SHA` | no meio de F1–F6 | retomada legítima: os commits à frente são do E1. Prove **ancestralidade** (nunca igualdade de tip), localize o worktree e deixe o sprintx continuar. **Nunca recrie a branch** |
| **D** | `ENTREGA.md` **commitado** na branch com `estado: entregue` e `portao: pronto`, e **não** `INTEGRADA` | depois do E8, antes do fast-forward | valide o estado commitado (`git show feature/<slug>:…`), a publicação da feature (`push_feito` e `origin/feature/<slug>`) e as seis provas; então integre. **Não reexecute portão, PR ou QA** |
| **E** | `INTEGRADA`, mapa ainda `em_andamento` | depois do ff, antes do mapa | **não integre de novo.** Promova, do `BUILDX-PREMISSAS.md` da feature, as premissas que ainda faltarem; atualize o mapa (`entregue` + `Integrada em <sha>`) e commite |
| **F** | mapa `entregue`, e o `PR-NN` já está no `PREMISSAS.md` com o mesmo conteúdo | depois da promoção | **no-op.** A promoção já aconteceu; a existência do id é a marca |
| **G** | o mesmo `PR-NN` existe com conteúdo **diferente** | duas escritas divergentes | **PARE E RELATE.** Não escolha uma das versões |
| **H** | B6 de ciclo **não-final** | validação de um ciclo que vai continuar | a `Branch base` continua sendo `buildx/<projeto_id>`. Não restaure, não gere `PR-FINAL.md`, não abra PR |
| **I** | B6 final, `Branch base` já restaurada, mas commit ou push não completou | no meio do fechamento | **conclua o fechamento** — commit, push, prova de sincronização, PR. Não inicie ciclo novo |
| **J** | `CONTROL != origin` de qualquer forma inesperada | o remoto mudou durante a parada | **PARE E RELATE.** Sem `pull`, sem merge do remoto, sem `rebase`, sem força |
| **K** | branch da feature não descende do `HEAD` de `CONTROL` | replanejamento cuja base envelheceu | **PARE E RELATE.** A barreira serial foi violada; o caminho é feature nova, não integração forçada |

No caso **B**, se a branch não existir mas o worktree sim — ou o contrário —, resolva antes: worktree órfão se reabre sobre a branch existente (`git worktree add ../<repo>--<slug> feature/<slug>`); `git` recusando, **pare e relate**. Nunca crie uma segunda branch para a mesma feature.

Entre **E** e **F** está a diferença que evita promover duas vezes: a promoção é idempotente **pelo `PR-NN`**, não por marcação — mesmo id com mesmo conteúdo já está promovido.

### O que nenhuma retomada faz

Integrar duas vezes — o fast-forward repetido é no-op, e é por isso que **D** é seguro. Promover a mesma premissa duas vezes — o `PR-NN` é a marca. Mover `CONTROL` para um SHA que ninguém esperava. Sobrescrever o remoto. Publicar a branch de uma feature — quem publica é a mergex. Recriar branch existente. `stash`, `reset` destrutivo, `--force`, `pull` automático, ou resolver divergência sozinha.

## 3. Confirme o modo

Leia `modo` no frontmatter do `PROJETO.md` e siga o que está gravado. **Não pergunte de novo** — a pergunta única já foi feita, e refazê-la é violar a regra 1 por um detalhe de sessão.

## 4. Relate onde parou, e siga

Uma linha dizendo o que encontrou e o que vai fazer. Depois continue até o fim, sem perguntar mais nada.

```
Retomando <projeto> na etapa B4, feature FT-05 (sprint 2 de 3). Modo autônomo.
```
