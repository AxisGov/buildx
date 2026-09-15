# AGENTS.md — buildx

Orientação para o agente do OpenCode neste repositório. O Claude Code lê a mesma informação por `.claude/skills/buildx/SKILL.md`.

## O que é o buildx

buildx é a **camada de orquestração do método Expx** (Exponencial): a peça que fica acima de todas as outras e conduz um projeto inteiro, do parágrafo de descrição ao sistema pronto.

As outras camadas são especialistas em uma etapa — `prodx` decide se vale fazer, `sprintx` planeja e executa uma feature, `mergex` entrega, `stackx` formaliza convenções, `memox` lembra. Nenhuma delas olha para um sistema inteiro e decide por onde começar.

## Princípio central

**Uma descrição entra, um sistema sai.** O humano gasta o esforço uma única vez, na descrição e na escolha do modo. Tudo depois é da máquina — inclusive descobrir o que o humano esqueceu de pedir.

## O buildx não implementa nada

Ele é um maestro: sabe qual camada chamar, em que ordem, com qual entrada, e o que fazer quando uma delas devolve bloqueio. Toda a competência real mora nas camadas irmãs.

A única coisa que o buildx faz e nenhuma outra faz é o **B3: quebrar um projeto em features**. Esse é o vão real que ele preenche — o sprintx planeja *uma* feature com rigor e não sabe recortar um sistema.

## A pergunta única

O buildx faz **exatamente uma pergunta**, sempre a primeira:

```
1. AUTÔNOMO TOTAL — eu decido tudo, você não é interrompido até o fim.
2. BRIEFING — uma rodada de perguntas agora, e depois rodo sozinho.
```

No modo autônomo essa foi a última pergunta. Dúvida vira premissa registrada ou bloqueio registrado — nunca interrupção. Relatar progresso não é perguntar.

## As seis etapas

```
B1 CONCEPÇÃO → B2 FUNDAÇÃO → B3 DECOMPOSIÇÃO → B4 CONSTRUÇÃO → B5 RECURSÃO → B6 VALIDAÇÃO
                                                      ↑                │
                                                      └────────────────┘
```

| Etapa | O que faz | Camada que trabalha |
|---|---|---|
| B1 | mapeia o escopo, varre lacunas, registra premissas | prodx (modo greenfield) |
| B2 | escolhe a stack, instala a suíte, monta o esqueleto testável | stackx (invertido) |
| B3 | **quebra o projeto em features** | só o buildx |
| B4 | o laço: por feature, sprintx F1–F6 + mergex, dentro do worktree que a F1 abre | sprintx, mergex |
| B5 | classifica pendências e devolve ao laço | buildx |
| B6 | confere o construído contra o mapa, e relata | prodx (como auditor) |

## Como usar

```
/buildx "quero um sistema para gestão de contratos, com upload de PDF,
         alerta de vencimento e relatório mensal por cliente"
```

| Comando | Função |
|---|---|
| `/buildx <descrição>` | o comando único: recebe a descrição e conduz tudo |
| `/buildx` | roteador: mostra em que etapa o projeto está |
| `/buildx-mapa` | B3 isolada: mostra ou regera o `MAPA.md` |
| `/buildx-retomar` | retoma um projeto interrompido, pelo estado em disco |
| `/buildx-status` | painel seco: features, ciclos, pendências, premissas |

## O que o buildx quebra de propósito

| Regra violada | Camada | Como fica |
|---|---|---|
| "a skill não decide, humano assina" | prodx R1 | o buildx assina, `provisorio: true` |
| "nada vai ao sprintx sem veredito assinado" | prodx R2 | a auto-assinatura satisfaz o portão |
| "a F2 é obrigada a perguntar ao humano" | sprintx R10 | o buildx responde, em quatro degraus, tudo em `00-DECISOES.md` |
| "convenção só se registra com evidência" | stackx | no B2 a origem é `decidido_pelo_buildx` |

Cada violação é restrita ao modo e registrada no artefato que toca.

## O que o buildx nunca quebra

- **Merge é humano.** Nunca invoca `mergex-revisar`, nunca oferece. Entrega PRs abertos, verdes e descritos.
- **TDD do sprintx.** Teste antes da implementação, sempre. Autonomia não é desculpa para serrar o galho que a sustenta.
- **Task só conclui com os dois testes passando.** "Concluída com ressalva" não existe.
- **Regra de negócio não declarada não é decidida.** O buildx decide como o sistema se protege, não o que o sistema faz.
- **Nenhum segredo real em artefato ou commit.**

## As 12 regras invioláveis

1. Uma única pergunta ao usuário: o modo. No autônomo, nenhuma outra chega a ele, de nenhuma camada.
2. Toda decisão tomada no lugar do humano é registrada em `PREMISSAS.md` **antes** de ser usada, com o que a invalidaria.
3. O buildx não implementa, não planeja e não testa. Ele invoca a camada dona e verifica a saída.
4. Bloqueio nunca para o laço: registra, marca a feature, segue para a próxima.
5. O ciclo B4 → B5 tem teto declarado. Atingido, para e reporta.
6. Nenhuma feature entra no `MAPA.md` sem `entrega` verificável e `depende_de` explícito.
7. Feature de fundação vem primeiro; nenhuma feature precede aquilo de que depende.
8. Merge é humano. Nunca invoca `mergex-revisar`, nem oferece.
9. O que não for derivável do `PROJETO.md`, `PREMISSAS.md` ou `CONVENCOES.md` vira premissa nova — nunca invenção silenciosa.
10. Todo artefato usa o frontmatter `expx-schema v1`.
11. Caminhos sempre relativos.
12. O relatório final declara toda pendência.

## Os padrões da casa

O que o buildx assume quando o usuário não diz nada. Detalhe em `references/02-lacunas.md`, Parte I. O usuário sempre ganha do padrão.

| # | Padrão |
|---|---|
| P-1 | três camadas, fronteira explícita |
| P-2 | Next.js, TypeScript, App Router |
| P-3 | SQLite local — dependência mínima é requisito de execução autônoma |
| P-4 | autenticação própria, JWT, hash forte |
| P-5 | usuário de demonstração com dados de exemplo, sempre |
| P-6 | design system do VS Code — tokens Dark+/Light+, tipografia, layout |
| P-7 | skill de frontend design da Anthropic, trabalhando dentro do P-6 |
| P-8 | o projeto nasce com a suíte Expx instalada, Claude Code e OpenCode |

## Estrutura em disco de um projeto do buildx

No **checkout de controle**, onde o buildx roda:

```
docs/
  projeto/
    PROJETO.md        o escopo completo: o pedido, o descoberto, o descartado
    PREMISSAS.md      toda decisão tomada em nome do humano
    MAPA.md           as features, em ordem de dependência
    RECURSAO.md       pendências por ciclo, e o teto
    VALIDACAO.md      a conferência final
    RELATORIO.md      o que o usuário lê no fim
  produto/            do prodx
  stack/              do stackx
```

No **worktree de cada feature** (`../<repo>--<slug>`, branch `feature/<slug>`, aberto pela F1 do sprintx):

```
docs/
  sprintx/features/<slug>/   plano, decisões, auditoria, bloqueios, fechamento
  entregas/<slug>/           registro da entrega e pacote de QA
```

O buildx não faz merge: o código e os artefatos de uma feature **não** aparecem no checkout de controle.

## Dependências

| Camada | Sem ela |
|---|---|
| `prodx`, `sprintx`, `mergex` | **o buildx não roda.** Diz o que falta e como instalar |
| `stackx` | degrada: o buildx grava as convenções direto, perde a revisão automática |
| `memox` | degrada: o B5 perde a consulta ao histórico |
| `legadox` | não participa: projeto novo não tem legado |

## Estrutura deste repositório

| Caminho | Conteúdo |
|---|---|
| `.claude/skills/buildx/SKILL.md` | a skill (lida nativamente pelo OpenCode) |
| `.claude/skills/buildx/references/` | roteiro operacional por etapa |
| `.claude/skills/buildx/references/integracao/` | como cada camada é invocada |
| `.claude/skills/buildx/assets/` | os seis templates |
| `.claude/commands/`, `.opencode/commands/` | os quatro comandos, idênticos |
| `DECISOES-DA-SKILL.md` | as ambiguidades resolvidas, com o que as invalida |
