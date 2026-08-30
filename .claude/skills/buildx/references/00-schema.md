# 00 — Schema dos artefatos do buildx

Leitura obrigatória em qualquer etapa que grave arquivo de estado (B1 a B6).

O buildx adota o contrato **expx-schema v1**, o mesmo do sprintx, runx e prodx. As regras universais R1 a R14 valem sem exceção e não são repetidas aqui. As mais citadas por quem escreve frontmatter no buildx:

| | |
|---|---|
| **R1** | o bloco YAML é a primeira coisa do arquivo, entre `---` |
| **R2** | chave em `snake_case`, minúscula, sem acento |
| **R3** | valor de enum minúsculo e sem acento |
| **R4** | data ISO `AAAA-MM-DD`, obtida do sistema com `date +%Y-%m-%d` |
| **R6** | chave nunca omitida: `[]` para lista vazia, `null` para ausente |
| **R9** | `atualizado_em` reescrito a cada gravação |
| **R10** | nenhum caminho absoluto em nenhum valor |

## A extensão que o buildx exige

O contrato v1 declara `expx_tool` com dois valores: `sprintx` e `runx`. O buildx **acrescenta um terceiro**:

```yaml
expx_tool: buildx
```

Essa é a única extensão do contrato. Ela precisa entrar no `CONTRATO-expx-schema-v1.md` do repositório do painel para que os artefatos do buildx sejam lidos em vez de reportados como violação. Até lá o painel mostra o artefato com o defeito à vista, que é o comportamento correto do contrato (R6) e não bloqueia nada.

O `prodx` tem a mesma pendência para os kinds dele. Tratar as duas juntas é o caminho mais barato.

## Cabeçalho comum

Todo artefato do buildx carrega estas quatro chaves antes das específicas:

```yaml
expx_schema: 1
expx_tool: buildx
kind: <um dos seis abaixo>
projeto_id: <slug do projeto>
```

`projeto_id` é a chave que costura tudo — é o slug do projeto, derivado do `PROJETO.md`, e aparece em todo artefato do buildx e no `origem_buildx` de cada feature planejada pelo sprintx.

### Como derivar o `projeto_id`

1. Pegue o nome essencial do sistema descrito, sem verbos de pedido.
2. Minúsculas, sem acento (ç → c, ã → a, é → e).
3. Espaços e separadores viram hífen; remova o que estiver fora de `a-z`, `0-9` e `-`; colapse hifens repetidos.
4. No máximo 5 palavras.

Exemplo: "quero um sistema de gestão de contratos para escritório de advocacia" → `gestao-de-contratos`.

## Os kinds

### `projeto` — `docs/projeto/PROJETO.md`

```yaml
expx_schema: 1
expx_tool: buildx
kind: projeto
projeto_id: gestao-de-contratos
titulo: Sistema de gestao de contratos
modo: autonomo            # autonomo | briefing
criado_em: 2026-08-30
atualizado_em: 2026-08-30
etapa: b3                 # b1 | b2 | b3 | b4 | b5 | b6 | concluido
descricao_original: docs/projeto/PROJETO.md#descricao-original
total_features: 11
features_entregues: 4
features_bloqueadas: 0
ciclos_recursao: 0
```

### `premissas` — `docs/projeto/PREMISSAS.md`

```yaml
expx_schema: 1
expx_tool: buildx
kind: premissas
projeto_id: gestao-de-contratos
atualizado_em: 2026-08-30
total: 23
por_origem:
  catalogo_lacunas: 18
  decisao_de_stack: 3
  f2_autonoma: 2
```

Cada premissa no corpo carrega: `id` (`PR-NN`), `assunto`, `decisao`, `por_que`, `o_que_invalida`, `origem`, `etapa`.

### `mapa` — `docs/projeto/MAPA.md`

```yaml
expx_schema: 1
expx_tool: buildx
kind: mapa
projeto_id: gestao-de-contratos
atualizado_em: 2026-08-30
total_features: 11
pendentes: 6
em_andamento: 1
entregues: 4
bloqueadas: 0
```

Cada feature no corpo carrega o contrato completo do B3: `id`, `slug`, `titulo`, `entrega`, `depende_de`, `paralelizavel`, `origem`, `status`.

### `recursao` — `docs/projeto/RECURSAO.md`

```yaml
expx_schema: 1
expx_tool: buildx
kind: recursao
projeto_id: gestao-de-contratos
atualizado_em: 2026-08-30
ciclo_atual: 2
teto_ciclos: 3
pendencias_abertas: 2
pendencias_resolvidas: 5
```

### `validacao` — `docs/projeto/VALIDACAO.md`

```yaml
expx_schema: 1
expx_tool: buildx
kind: validacao
projeto_id: gestao-de-contratos
data: 2026-08-30
veredito: aprovado          # aprovado | aprovado_com_pendencia | reprovado
itens_conferidos: 34
itens_atendidos: 32
itens_pendentes: 2
```

### `relatorio` — `docs/projeto/RELATORIO.md`

```yaml
expx_schema: 1
expx_tool: buildx
kind: relatorio
projeto_id: gestao-de-contratos
data: 2026-08-30
modo: autonomo
features_entregues: 11
prs_abertos: 11
pendencias_declaradas: 2
premissas_registradas: 23
ciclos_recursao: 2
```

## Enums do buildx

| Campo | Valores |
|---|---|
| `modo` | `autonomo` · `briefing` |
| `etapa` | `b1` · `b2` · `b3` · `b4` · `b5` · `b6` · `concluido` |
| `status` (feature) | `pendente` · `em_andamento` · `entregue` · `bloqueada` |
| `origem` (feature) | `descricao` · `premissa` · `recursao` |
| `origem` (premissa) | `catalogo_lacunas` · `decisao_de_stack` · `f2_autonoma` · `recursao` |
| `veredito` (validação) | `aprovado` · `aprovado_com_pendencia` · `reprovado` |
| `classe` (pendência) | `trabalho_novo` · `replanejamento` · `decisao_humana` · `recurso_externo` |

## O que o buildx grava nos artefatos das outras camadas

O buildx nunca reescreve artefato de outra camada. Ele **acrescenta duas chaves** ao frontmatter dos artefatos que a cadeia gera sob seu comando, na gravação normal daquela camada:

| Chave | Onde | Valor |
|---|---|---|
| `origem_buildx` | todo artefato do sprintx da feature | o `projeto_id` |
| `feature_id` | todo artefato do sprintx da feature | o `FT-NN` do `MAPA.md` |

São as duas chaves que permitem, depois, olhar qualquer plano de sprint e saber de qual projeto e de qual feature do mapa ele veio.
