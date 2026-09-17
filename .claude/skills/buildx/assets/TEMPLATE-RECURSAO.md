---
expx_schema: 1
expx_tool: buildx
kind: recursao
projeto_id: <slug-do-projeto>
atualizado_em: <AAAA-MM-DD>
ciclo_atual: 1
teto_ciclos: 3
pendencias_abertas: 0
pendencias_resolvidas: 0
---

# <titulo> — Recursão

Tudo que ficou pelo caminho, uma pendência por bloco, cada bloco na seção do seu `estado`.
O ciclo é B4 → B5 → features sucessoras → B4, até o teto. Estas cinco seções são fixas:
nenhuma execução acrescenta, renomeia ou remove seção.

## Aguardando classificação do B5

<Pendência registrada no commit que encerrou uma tentativa — `estado: aguardando_classificacao`,
`classe: null`. O B5 a classifica pela tabela gatilho → classe.>

## Em resolução pela máquina

<`estado: em_resolucao`, `classe: trabalho_novo`: uma feature sucessora, nova, está no
`MAPA.md` e é o `destino`.>

## Aberto — decisão humana

<`estado: decisao_humana`. Vai para a PRIMEIRA seção do relatório final. Nunca vira feature,
nunca é resolvida por chute.>

## Aberto — recurso externo

<`estado: recurso_externo`. Vai para a SEGUNDA seção do relatório final.>

## Resolvido nos ciclos

<`estado: resolvida`: a sucessora foi entregue.>

<!--
O BLOCO DE UMA PENDÊNCIA — sempre inteiro, chave nunca omitida (ausente é null ou []):

### PEND-01 — <assunto>

- id: PEND-01
- estado: aguardando_classificacao
- gatilho: orcamento_f5_esgotado
- classe: null
- origem: FT-03
- ciclo: 1
- evidencia: feature/<slug>@<sha>:docs/sprintx/features/<slug>/00-PLANEJAMENTO.md ; feature/<slug>@<sha>:docs/sprintx/features/<slug>/00-AUDITORIA.md
- causa: null
- clausula_central: [item 2][fraco:criterio],[item 9]
- raiz: null
- detectada_em: <AAAA-MM-DD>
- classificada_em: null
- regra_aplicada: null
- destino: null
- pr_reservadas: [PR-09, PR-10]
- resolvida_em: null
- nota: null

Campos específicos, acrescentados quando a classe os exige:

  decisao_humana   - decisao: <o que precisa ser decidido, em uma frase>
                   - opcoes: <as alternativas reais, com o efeito de cada uma>
                   - provisorio: <o que o buildx fez enquanto isso, e onde está>
                   - reversibilidade: <o que custa mudar depois>

  recurso_externo  - o_que_falta: <credencial, acesso, conta, domínio, chave>
                   - o_que_destrava: <o que passa a funcionar quando providenciado>
                   - estado_atual: <o que existe sem isso>

  trabalho_novo    - sucede: <FT-XX, a feature bloqueada que não volta>
                   - slug_sucessora: <slug novo; nunca o da bloqueada>

OS ESTADOS — um por seção, nesta ordem

  aguardando_classificacao → Aguardando classificação do B5   (classe: null)
  em_resolucao             → Em resolução pela máquina        (classe: trabalho_novo)
  decisao_humana           → Aberto — decisão humana
  recurso_externo          → Aberto — recurso externo
  resolvida                → Resolvido nos ciclos

AS CLASSES DO B5 — só estas três são escritas

  trabalho_novo    → feature SUCESSORA nova no MAPA.md (slug novo, origem recursao)
  decisao_humana   → fica aqui, vai para o relatório. NUNCA vira feature
  recurso_externo  → fica aqui, vai para o relatório

Replanejar a mesma feature não é classe do B5: existe só dentro do B4, pela sprintx, antes de
o orçamento acabar. RECURSAO.md antigo com classe `replanejamento` é lido como `trabalho_novo`,
e nunca reescrito com ela.

A TABELA GATILHO → CLASSE, O DETECTOR DE LAÇO E O TETO: references/06-recursao.md.
-->
