---
expx_schema: 1
expx_tool: buildx
kind: mapa
projeto_id: gestao-de-contratos
atualizado_em: 2026-08-30
total_features: 9
pendentes: 5
em_andamento: 1
entregues: 3
bloqueadas: 0
---

# Gestão de contratos — Mapa de features

Ordem de dependência. Nenhuma feature precede aquilo de que depende.

> Exemplo gerado a partir da descrição: *"quero um sistema para gestão de
> contratos, com upload de PDF, alerta de vencimento e relatório mensal por
> cliente"*. Modo autônomo.
>
> Repare que a descrição menciona **três** coisas. O mapa tem **nove
> features** — as outras seis vieram da varredura de lacunas do B1, e cada
> uma aponta a premissa que a justifica.

## Painel

| ID | Feature | Status | PR |
|---|---|---|---|
| FT-01 | Acesso ao sistema | entregue | #3 |
| FT-02 | Cadastro de clientes | entregue | #7 |
| FT-03 | Cadastro de contratos | entregue | #11 |
| FT-04 | Upload e leitura de PDF | em_andamento | — |
| FT-05 | Alerta de vencimento | pendente | — |
| FT-06 | Relatório mensal por cliente | pendente | — |
| FT-07 | Trilha de auditoria | pendente | — |
| FT-08 | Conta e dados pessoais | pendente | — |
| FT-09 | Backup e restauração | pendente | — |

---

### FT-01 — Acesso ao sistema

**Slug:** `acesso-ao-sistema` → `docs/sprintx/features/acesso-ao-sistema/`, na branch `feature/acesso-ao-sistema`
**Entrega:** uma pessoa entra com e-mail e senha e cai no painel; um administrador cadastra os outros usuários e atribui papel; cada um edita o próprio perfil e troca a própria senha.
**Depende de:** []
**Paralelizável:** false
**Origem:** premissa
**Premissas que realiza:** [PR-01, PR-02, PR-03, PR-04, PR-11, PR-12, PR-14]
**Status:** entregue
**PR:** #3 · **Sprints:** 3 · **Testes:** 51

> A fundação. Carrega junto o usuário de demonstração (PR-11), a casca
> visual do design system (PR-12) e o esqueleto de aplicação (PR-14):
> painel inicial, Configurações → Usuários, Meu perfil e troca de senha,
> com os itens já na barra lateral. São o que a torna demonstrável — sem
> eles a primeira entrega seria uma tela de login vazia, sem conta para
> entrar e sem lugar aonde chegar depois, indistinguível de um sistema
> quebrado.
>
> Repare que ninguém pediu cadastro de usuários nem troca de senha. É o
> P-9: não é escopo do sistema, é a moldura dele — e é o que separa um
> sistema demonstrável de um sistema operável por quem não é o
> desenvolvedor.

---

### FT-02 — Cadastro de clientes

**Slug:** `cadastro-de-clientes`
**Entrega:** o usuário cadastra, edita, busca e arquiva os clientes do escritório.
**Depende de:** [FT-01]
**Paralelizável:** false
**Origem:** descricao
**Premissas que realiza:** []
**Status:** entregue
**PR:** #7 · **Sprints:** 2 · **Testes:** 28

> A descrição não pediu "cadastro de clientes" — pediu "relatório mensal
> **por cliente**". O P2 do prodx converteu a solução em problema, e daí
> saiu a entidade que a FT-06 vai precisar.

---

### FT-03 — Cadastro de contratos

**Slug:** `cadastro-de-contratos`
**Entrega:** o usuário registra um contrato vinculado a um cliente, com vigência, valor e situação, e encontra depois.
**Depende de:** [FT-02]
**Paralelizável:** false
**Origem:** descricao
**Premissas que realiza:** []
**Status:** entregue
**PR:** #11 · **Sprints:** 3 · **Testes:** 41

---

### FT-04 — Upload e leitura de PDF

**Slug:** `upload-de-pdf`
**Entrega:** o usuário anexa o PDF ao contrato, vê na tela e baixa depois.
**Depende de:** [FT-03]
**Paralelizável:** false
**Origem:** descricao
**Premissas que realiza:** [PR-15, PR-16]
**Status:** em_andamento

> PR-15 limita tipo e tamanho do arquivo; PR-16 guarda fora da raiz servida.
> Nenhuma das duas foi pedida — a descrição dizia só "upload de PDF".

---

### FT-05 — Alerta de vencimento

**Slug:** `alerta-de-vencimento`
**Entrega:** o usuário vê os contratos que vencem em breve, e recebe aviso antes de vencerem.
**Depende de:** [FT-03]
**Paralelizável:** true
**Origem:** descricao
**Premissas que realiza:** [PR-18]
**Status:** pendente

> `paralelizavel: true` porque não toca nos arquivos da FT-04 nem da FT-06.
>
> **Pendência PEND-01, `decisao_humana`:** com quantos dias de antecedência
> o alerta dispara? Não foi declarado, e é regra de negócio — o buildx não
> chuta. Provisório: 30 dias, configurável, marcado no código. Vai para a
> primeira seção do relatório final.

---

### FT-06 — Relatório mensal por cliente

**Slug:** `relatorio-mensal-por-cliente`
**Entrega:** o usuário gera o relatório do mês de um cliente e exporta.
**Depende de:** [FT-02, FT-03]
**Paralelizável:** true
**Origem:** descricao
**Premissas que realiza:** []
**Status:** pendente

---

### FT-07 — Trilha de auditoria

**Slug:** `trilha-de-auditoria`
**Entrega:** um administrador vê quem alterou ou removeu um contrato, e quando.
**Depende de:** [FT-03]
**Paralelizável:** true
**Origem:** premissa
**Premissas que realiza:** [PR-07]
**Status:** pendente

> Ninguém pediu. Saiu do eixo L12: o sistema guarda documento com efeito
> jurídico, e alteração sem rastro num contrato é um problema que só
> aparece quando alguém precisa provar o que estava escrito antes.

---

### FT-08 — Conta e dados pessoais

**Slug:** `conta-e-dados-pessoais`
**Entrega:** o usuário exporta os próprios dados e apaga a conta, e a exclusão apaga de fato.
**Depende de:** [FT-01]
**Paralelizável:** true
**Origem:** premissa
**Premissas que realiza:** [PR-09, PR-10]
**Status:** pendente

> Eixo L11. "Apaga de fato" é a parte que quase todo projeto erra: uma
> exclusão que só marca uma coluna não cumpre a LGPD.

---

### FT-09 — Backup e restauração

**Slug:** `backup-e-restauracao`
**Entrega:** o administrador gera uma cópia dos dados e a restaura numa base limpa.
**Depende de:** []
**Paralelizável:** true
**Origem:** premissa
**Premissas que realiza:** [PR-13]
**Status:** pendente

> Eixo L14, e a parte que importa é a segunda metade. Backup que nunca foi
> restaurado não é backup — é um arquivo. A entrega inclui a restauração
> testada, não só a geração.

---

<!--
O QUE ESTE EXEMPLO MOSTRA

A descrição do usuário tinha três itens: upload de PDF, alerta de
vencimento, relatório mensal. O mapa tem nove features.

  origem: descricao  → 4 features (FT-02 a FT-06)
  origem: premissa   → 5 features (FT-01, FT-07, FT-08, FT-09)

A FT-02 é o caso interessante: ninguém pediu cadastro de clientes. O P2 do
prodx converteu "relatório mensal por cliente" (solução) em "o escritório
precisa ver o que cada cliente tem" (problema), e a entidade apareceu.

As cinco de origem premissa são o que o buildx descobriu que faltava. Sem
elas o sistema funcionaria — e teria cinco defeitos conhecidos que ninguém
tinha visto.
-->
