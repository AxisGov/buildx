---
description: Painel seco do buildx — features, ciclos de recursão, pendências e premissas. Só lê, não executa etapa nenhuma.
---

Use a skill `buildx`. **Este comando não executa etapa nenhuma.** Lê e mostra.

Sem `docs/projeto/PROJETO.md`: diga que não há projeto do buildx aqui, e que `/buildx <descrição>` começa um.

```
buildx — <titulo>
Etapa: <B-N> · Modo: <autonomo | briefing>

FEATURES                                    <n> de <n> entregues
| ID | feature | status | detalhe | PR | testes |
|----|---------|--------|---------|----|--------|

RECURSÃO
Ciclo <n> de <teto>
Aguardando classificação: <n> · Em resolução: <n> · Decisão humana: <n> · Recurso externo: <n> · Resolvidas: <n>

PENDÊNCIAS
| # | estado | gatilho | classe | origem | destino |
|---|--------|---------|--------|--------|---------|

PREMISSAS
Registradas: <n> · Provisórias: <n> · Sem feature que as realize: <n>

VALIDAÇÃO
<veredito, se o B6 já rodou; senão "não executada">
```

O `status` de feature continua sendo um dos quatro do `MAPA.md` — `pendente`, `em_andamento`, `entregue`, `bloqueada` — e nenhum outro. A coluna **detalhe** diz o resto, lido de onde ele mora, sem inventar estado:

| `status` | detalhe | De onde vem |
|---|---|---|
| `em_andamento` | `planejamento: <estado> · reprovações <n> de <teto>`, ou `CHECKPOINT pendente` | `planejamento.sh fase <slug>` no worktree da feature, e o `00-PLANEJAMENTO.md` **commitado** na branch (`git show feature/<slug>:…`) |
| `em_andamento` | `execução` | a sprintx responde `F6` |
| `bloqueada` | `PEND-NN aguardando classificação`, ou a classe final | a pendência do `RECURSAO.md` |
| `pendente` com `origem: recursao` | `sucede FT-XX · resolve PEND-NN` | o bloco da feature no `MAPA.md` |

## Comente três coisas, quando se aplicarem

- **Premissa sem feature que a realize** — é a falha mais cara do método: documenta uma proteção que ninguém construiu. Diga quais são.
- **Ciclo de recursão no teto** — diga que o buildx vai parar de tentar e que o resto vira decisão humana.
- **Sucessora bloqueada pelo mesmo gatilho e pela mesma cláusula da pendência raiz** — laço em falso; a raiz deveria ter sido reclassificada como `decisao_humana`.

Não ofereça consertar nada. Este comando só informa.
