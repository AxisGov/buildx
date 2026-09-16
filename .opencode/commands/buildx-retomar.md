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

Leia o `slug` da `FT-NN` `em_andamento` no `MAPA.md`. `CONTROL` = `buildx/<projeto_id>`. `INTEGRADA` significa `git merge-base --is-ancestor feature/<slug> CONTROL` responder sim.

| # | O que você encontra | Onde a sessão morreu | O que fazer |
|---|---|---|---|
| **A** | `CONTROL == origin`, sem branch `feature/<slug>` | depois do commit `em andamento`, antes da F1 | `BASE_SHA := HEAD`; invoque a F1 com o briefing |
| **B** | branch e worktree existem, disco em F1–F5 | no meio do plano | entre no worktree e invoque o sprintx: a máquina de estados dele continua de onde parou |
| **C** | `ENTREGA.md` com `estado: entregue` e `portao: pronto`, **não** `INTEGRADA` | depois da entrega, antes do fast-forward | rode as quatro provas do B4 e integre. **Não reexecute portão, PR ou QA** |
| **D** | `INTEGRADA`, mapa ainda `em_andamento` | depois do ff, antes do mapa | só atualize o mapa (`entregue` + `Integrada em <sha>`) e commite |
| **E** | local à frente do remoto **apenas** pelos commits de estado esperados | depois do commit do mapa, antes do push | `git push origin buildx/<projeto_id>`, push normal |
| **F** | `CONTROL != origin` de qualquer outra forma | o remoto mudou durante a parada | **PARE E RELATE.** Sem `pull`, sem merge do remoto, sem `rebase`, sem força |
| **G** | branch da feature não descende do `HEAD` de `CONTROL` | replanejamento cuja base envelheceu | **PARE E RELATE.** A barreira serial foi violada; o caminho é feature nova, não integração forçada |

No caso **A**, se a branch não existir mas o worktree sim — ou o contrário —, resolva antes: worktree órfão se reabre sobre a branch existente (`git worktree add ../<repo>--<slug> feature/<slug>`); `git` recusando, **pare e relate**. Nunca crie uma segunda branch para a mesma feature.

### O que nenhuma retomada faz

Integrar duas vezes — o fast-forward repetido é no-op, e é por isso que **C** é seguro. Mover `CONTROL` para um SHA que ninguém esperava. Sobrescrever o remoto. Recriar branch existente. `stash`, `reset` destrutivo, `--force`, `pull` automático, ou resolver divergência sozinha.

## 3. Confirme o modo

Leia `modo` no frontmatter do `PROJETO.md` e siga o que está gravado. **Não pergunte de novo** — a pergunta única já foi feita, e refazê-la é violar a regra 1 por um detalhe de sessão.

## 4. Relate onde parou, e siga

Uma linha dizendo o que encontrou e o que vai fazer. Depois continue até o fim, sem perguntar mais nada.

```
Retomando <projeto> na etapa B4, feature FT-05 (sprint 2 de 3). Modo autônomo.
```
