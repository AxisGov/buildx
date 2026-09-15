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

Não recomece a feature — e **não rode `mergex-abrir` para retomar**. Cada feature tem uma árvore de trabalho própria, aberta pela F1 do sprintx, e retomar é voltar para dentro dela.

1. **Leia o `slug`** daquela `FT-NN` no `MAPA.md` (checkout de controle). A branch é `feature/<slug>`.
2. **Procure a árvore de trabalho:**
   ```
   git worktree list --porcelain
   ```
   Ele lista, para cada árvore, o `worktree <caminho>` e o `branch refs/heads/<nome>`.
3. **Branch associada a um worktree:** retome **de dentro daquele diretório**. Se a sessão atual está em outra árvore, anuncie o caminho e continue de lá — nunca trabalhe a feature a partir do checkout de controle.
4. **Branch existe, sem worktree associado:** reabra a árvore sobre a branch que já existe, sem criar outra e sem trocar a branch do checkout de controle:
   ```
   git worktree add ../<repo>--<slug> feature/<slug>
   ```
   Se `git` recusar (a branch está em uso por outra árvore, ou o diretório já existe), **pare e relate** — nunca force, nunca remova worktree de ninguém, nunca crie uma segunda branch para a mesma feature.
5. **Nem branch nem worktree:** a F1 não chegou a rodar. Invoque o sprintx normalmente com o briefing da feature: é ela que abre a área de trabalho.

**Só dentro da área certa** deixe a máquina de estados do sprintx detectar a fase, que ela lê do disco de `docs/sprintx/features/<slug>/` — invoque a skill e ela continua de onde parou.

A existência da branch **não** diz onde continuar: ela não prova que a árvore existe, nem em que fase a feature está. Quem responde isso é o worktree mais o disco daquela feature.

Se este comando foi chamado **de dentro de um worktree de feature**, o estado do projeto (`docs/projeto/MAPA.md`) está no checkout de controle, não aqui: leia-o de lá (`git worktree list --porcelain` mostra qual é a árvore principal) antes de decidir a etapa.

## 3. Confirme o modo

Leia `modo` no frontmatter do `PROJETO.md` e siga o que está gravado. **Não pergunte de novo** — a pergunta única já foi feita, e refazê-la é violar a regra 1 por um detalhe de sessão.

## 4. Relate onde parou, e siga

Uma linha dizendo o que encontrou e o que vai fazer. Depois continue até o fim, sem perguntar mais nada.

```
Retomando <projeto> na etapa B4, feature FT-05 (sprint 2 de 3). Modo autônomo.
```
