# B4 — Construção

O laço. Percorrer o `MAPA.md` em ordem de dependência e, para cada feature, conduzir o sprintx de ponta a ponta — a entrega vem junto, porque a F6 a conduz.

Entrada: `MAPA.md`. Saída: uma área de trabalho própria, um plano e uma entrega registrada por feature — com o portão verde e o PR aberto, quando a ferramenta do serviço existiu; o `MAPA.md` atualizado no checkout de controle.

O B4 é longo mas é a etapa mais simples do buildx: ele quase não decide nada. A competência está no sprintx e na mergex; o trabalho aqui é invocar na ordem certa, com a entrada certa, e não parar quando algo falha.

## O ciclo de uma feature

```
checkout de controle (MAPA.md, PROJETO.md, PREMISSAS.md)
  │
  1. marca a feature em_andamento no MAPA.md
  │
  2. sprintx F1 ─── cria ou retoma ───► worktree ../<repo>--<slug>
  │                                     branch  feature/<slug>
  │                                          │
  │                                          ├─ 3. sprintx F2  descoberta, RESPONDIDA PELO BUILDX
  │                                          ├─ 4. sprintx F3  plano de sprints, fases e tasks
  │                                          ├─ 5. sprintx F4  ORQUESTRADOR.md
  │                                          ├─ 6. sprintx F5  auditoria do plano
  │                                          └─ 7. sprintx F6  execução TDD — e a entrega inteira:
  │                                                 ├─ mergex E0        no início
  │                                                 ├─ mergex E1        a cada task concluída
  │                                                 ├─ FECHAMENTO.md
  │                                                 └─ mergex E2 → E8   portão, PR, QA, registro
  │                                          │
  ◄──────────── volta ao checkout de controle ┘
  8. LÊ o resultado da entrega (ENTREGA.md + FECHAMENTO.md)
  9. atualiza o MAPA.md  →  próxima feature
```

Nenhuma etapa é pulada, e o sprintx nunca é invocado fora de ordem — a máquina de estados dele detecta a fase pelo disco de `docs/sprintx/features/<slug>/`, então basta invocar a skill **de dentro da área de trabalho certa** e ela continua de onde parou.

## O checkout de controle e o worktree da feature

São duas árvores diferentes, e confundi-las é o erro mais caro desta etapa.

| Árvore | O que mora nela | Quem escreve |
|---|---|---|
| **checkout de controle** — onde o buildx roda | `docs/projeto/PROJETO.md`, `PREMISSAS.md`, `MAPA.md`, `RECURSAO.md`, `VALIDACAO.md`, `RELATORIO.md`, e `docs/stack/CONVENCOES.md` | o buildx |
| **worktree da feature** — `../<repo>--<slug>`, branch `feature/<slug>` | `docs/sprintx/features/<slug>/` (base, decisões, plano, orquestrador, auditoria, bloqueios, fechamento) e **o código da feature** | o sprintx e a mergex |

O worktree é criado pela **F1 do sprintx** (regra 21 dele: uma feature por árvore de trabalho). O buildx **não cria branch e não cria worktree** — ele entra no que a F1 abriu, trabalha lá do F2 ao PR, e volta.

**O checkout de controle não recebe o código das features.** O buildx não faz merge (regra 8), então nunca presuma que o plano, os artefatos ou o código de uma feature estão visíveis na árvore de controle: eles estão no worktree e na branch daquela feature.

## Passo 1 — Marcar a feature e chamar a F1

Marque a feature como `em_andamento` no `MAPA.md` **agora**, no checkout de controle, não no fim. Se a sessão morrer no meio, o `/buildx-retomar` precisa saber onde estava.

**Não invoque `mergex-abrir`.** A branch e o worktree são da F1, e a mergex entra depois: quem aciona o E0 dela é a própria F6 do sprintx, já dentro do worktree, quando o `ORQUESTRADOR.md` existe. Chamar `mergex-abrir` antes da F1 tenta abrir uma segunda área de trabalho para a mesma feature — na melhor hipótese ela é recusada, na pior o trabalho se divide em duas árvores.

## Passo 2 — A F1, com o briefing do buildx

**A F1 abre a área de trabalho e monta a base de conhecimento** — nessa ordem. Antes do scaffold, ela cria ou retoma o worktree `../<repo>--<slug>` na branch `feature/<slug>`; a partir daí, tudo da feature acontece lá dentro. Se a F1 anunciar a área de trabalho e encerrar (é o comportamento dela quando o harness não troca de árvore sozinho), **continue de dentro do diretório que ela indicou** — não recomece a fase na árvore de controle.

Sem git, ou com worktree recusado, a F1 segue na árvore atual e nada aqui muda: o buildx continua não abrindo branch.

Ela recebe do buildx um briefing por feature, montado a partir do `MAPA.md`, do `PROJETO.md` e do `PREMISSAS.md` — o mesmo papel que o `BRIEFING.md` do prodx cumpre num pedido isolado.

O briefing da feature carrega:

| Campo | De onde vem |
|---|---|
| problema | a `entrega` da feature no `MAPA.md` |
| escopo | o recorte da feature, e o que pertence a outras |
| não-objetivos | as features vizinhas, nominalmente — evita que a F2 invada escopo alheio |
| critérios de aceite de negócio | os do `PROJETO.md` que esta feature cobre |
| premissas aplicáveis | as `PR-NN` que esta feature realiza |
| convenções | ponteiro para `docs/stack/CONVENCOES.md` |

Acrescente `origem_buildx` e `feature_id` ao frontmatter dos artefatos da feature (`references/00-schema.md`).

**A regra 9 do sprintx vale sem atenuação:** na F1 nada de invenção. O que a base não afirma é `NÃO DOCUMENTADO`.

## Passo 3 — A F2 respondida pelo buildx

**O ponto mais delicado do método, e a violação mais séria que o buildx comete.**

A regra 10 do sprintx obriga a F2 a entrevistar o humano em blocos de até cinco perguntas, esperando resposta. No buildx o humano já falou — na descrição e, no modo briefing, na rodada única. Então o buildx **responde no lugar dele**.

Como responder, na ordem, sem pular degrau:

1. **Derivável do `PROJETO.md`?** Use, e cite a seção na justificativa.
2. **Derivável do `PREMISSAS.md`?** Use, e cite o `PR-NN`.
3. **Derivável do `CONVENCOES.md`?** Use, e cite a regra.
4. **Nenhum dos três responde?** → **crie uma premissa nova** em `PREMISSAS.md`, com `origem: f2_autonoma`, e só então responda com ela.

O degrau 4 é o que separa decisão auditável de invenção. Nunca responda a F2 com algo que não esteja escrito em um dos três arquivos — se não estiver, escreva primeiro, com o `o_que_invalida` preenchido, e responda depois.

Grave em `00-DECISOES.md` com `respondido_por: buildx`, e a fonte de cada resposta. O humano precisa poder abrir o arquivo depois e ver, decisão a decisão, o que foi decidido em nome dele e com base em quê.

### A fronteira que a F2 não atravessa

Se a F2 levantar uma questão de **regra de negócio** que nenhum dos três arquivos responde — quanto tempo um contrato fica válido, se o desconto acumula, qual imposto se aplica — o buildx **não inventa**. Isso não é requisito não-funcional; é o que o sistema faz, e decidir isso no lugar do usuário produz um sistema que funciona e está errado.

Nesse caso: registre em `00-BLOQUEIOS.md`, registre como pendência `decisao_humana` no `RECURSAO.md`, e **siga com a decisão mais reversível possível**, marcada como provisória no código e na premissa. O relatório final lista todas essas — são a primeira coisa que o humano precisa olhar.

## Passo 4 — F3 a F5

Rodam sem intervenção do buildx. Três pontos de atenção:

**A F3 pode perguntar.** A regra 11 do sprintx permite uma pergunta quando a F3 encontra decisão que exigiria humano em execução. No modo autônomo essa pergunta não chega ao usuário: o buildx a responde pelo mesmo procedimento de quatro degraus do passo 3.

**A F5 é auditoria de verdade.** Achado de severidade alta manda voltar à F3 — e o buildx obedece, sem atalho. A tentação de seguir com um plano que a auditoria reprovou é grande no modo autônomo, e ceder a ela é o que transforma execução autônoma em dano autônomo. Se a F3 e a F5 entrarem em laço (o replanejamento é reprovado três vezes), pare a feature, marque `bloqueada`, e deixe para o B5.

**A F3.5 é opcional.** A estimativa não muda nada no modo autônomo — não há prazo a negociar. Rode se for barata; pule sem cerimônia.

## Passo 5 — A F6 e o acabamento

A F6 executa o plano auditado sob TDD estrito. O buildx não interfere: a regra 8 do sprintx já diz o que fazer com dúvida nova — registra em `00-BLOQUEIOS.md`, pula a task, segue para a próxima paralelizável, nunca para e espera.

**A F6 conduz a entrega inteira**, e é aqui que o buildx mais precisa ficar de fora. Dentro dela, a sprintx aciona a mergex três vezes, nesta ordem: **E0** no início, **E1** a cada task que fecha, e — depois de gravar o `FECHAMENTO.md` — **E2 a E8**: portão de prontidão, classificação da atenção, descrição do PR, pacote de QA, push, abertura do PR e registro da entrega.

Quando a F6 devolve o controle, **a entrega da feature já aconteceu**. O buildx não a refaz: ele lê o resultado (passo 6).

**O acabamento visual acontece aqui**, dentro das tasks de interface, não numa passada depois. Todo componente é construído sobre os tokens do design system (P-6, detalhado em `08-design-system.md`) — nenhum valor de cor literal entra em componente. Se a skill de frontend design estiver disponível (P-7), ela trabalha dentro desse vocabulário, não escolhe outro.

Toda tela entregue tem as duas variantes de tema, os três estados obrigatórios (vazio, carregando, erro) e funciona em tela de celular.

**O que o buildx nunca relaxa na F6:**

- TDD: teste antes da implementação, sempre
- task só é concluída com os dois testes passando; não existe "concluída com ressalva"
- nenhum segredo real em código, artefato ou commit

## Passo 6 — Ler o resultado da entrega

**O buildx não executa etapa nenhuma da mergex aqui.** A F6 já conduziu E0, E1 e E2 a E8 dentro do worktree. Rodar `mergex-check`, `mergex-pr` ou `mergex-qa` agora repetiria o que acabou de acontecer — dois donos para o mesmo ciclo, dois PRs possíveis para a mesma branch, e um portão avaliado duas vezes sobre estados diferentes.

O que o buildx faz é **ler dois artefatos**, na árvore da feature:

| Arquivo | Quem grava | O que o buildx lê |
|---|---|---|
| `docs/entregas/<slug>/ENTREGA.md` | mergex, no E8 | `estado`, `portao`, `pr_url`, `pr_estado`, `push_feito`, `desvios`, `entregue_em` |
| `docs/sprintx/features/<slug>/FECHAMENTO.md` | sprintx, ao fim da F6 | `fechado_em`, `resumo`, `risco_residual`, `testes_adicionados` |

Nenhum campo além desses é inventado: são os que os contratos das duas skills declaram.

### A regra de decisão

| O que o `ENTREGA.md` diz | `MAPA.md` | O que registrar |
|---|---|---|
| `estado: entregue` e `portao: pronto` | **`entregue`** | `pr_url` quando houver, os testes de `testes_adicionados`, e o `risco_residual` do fechamento |
| `portao: bloqueado` (com `estado: bloqueado`) | **`bloqueada`** | o motivo que o portão registrou, e os `desvios`, se houver |
| `estado: aberto` depois de a F6 ter devolvido o controle | **`bloqueada`** | entrega interrompida no meio; o motivo é o que a F6 relatou |

**`pr_url: null` não reprova a feature.** O contrato da mergex é explícito: PR não aberto — porque a ferramenta do serviço não estava disponível ou autenticada — não é falha, e a descrição fica em `docs/entregas/<slug>/PR.md`. O que decide é o portão, não a existência da URL. Registre no `MAPA.md` que a descrição está em arquivo, para o relatório final apontar para lá.

### Quando os artefatos não estão lá

Com a mergex instalada — e ela é obrigatória —, a ausência de `ENTREGA.md` depois da F6 significa que **a sprintx instalada não tem o contrato E0/E1/E2→E8**. Isso é incompatibilidade de versão, não trabalho pendente.

Nesse caso: marque a feature `bloqueada` com o motivo `incompatibilidade_de_versao`, registre a pendência no `RECURSAO.md` dizendo qual artefato faltou, e **siga para a próxima feature**.

**Não complete o fluxo à mão.** Não rode `mergex-check`, `mergex-pr`, `mergex-qa` nem `mergex-abrir` para "terminar o que faltou": um ciclo de entrega conduzido pela metade por cada lado produz commit sem portão, PR sem pacote de QA, ou entrega registrada duas vezes. Falha explícita de versão é melhor que execução dupla — e o B5 classifica a pendência depois.

**O merge não acontece.** O buildx nunca invoca `mergex-revisar`, nunca oferece, nunca sugere no fim — e a F6 também não o encadeia. Integrar código é decisão humana e essa é a última rede antes de produção. A entrega do buildx é um conjunto de features entregues e descritas, cada uma com o portão verde e, quando a ferramenta do serviço existiu, um PR aberto.

## Passo 7 — Fechar a feature

**Volte ao checkout de controle** e atualize o `MAPA.md`: `status` para `entregue` ou `bloqueada`, e os contadores do frontmatter. O `MAPA.md` é do projeto, não da feature: ele nunca é editado dentro do worktree, senão a atualização fica presa na branch daquela feature e a próxima nasce de um mapa desatualizado.

O worktree da feature **fica onde está** ao fim do ciclo. Ele é a única cópia dos artefatos e do código daquela feature até o humano fazer o merge do PR — o B5 e o B6 ainda vão lê-lo, e removê-lo apagaria trabalho que ninguém integrou.

**Depois da primeira feature entregue**, rode a revisão de convenções do B2 **na árvore daquela feature** — é lá que o código real existe; o checkout de controle ainda só tem o template do B2. Converta cada regra de `decidido_pelo_buildx` para a evidência encontrada, citando o arquivo e a linha como eles aparecem naquela branch; regra contradita pelo código vira achado a resolver. O `CONVENCOES.md` atualizado é do projeto: grave-o **no checkout de controle**, como todo artefato de `docs/stack/`. É quando o projeto passa a acreditar em si mesmo em vez de no buildx.

## O relato de progresso

Nos dois modos o buildx relata — relatar não é perguntar. Uma linha por transição de feature, seca:

```
FT-03 autenticacao-e-usuarios ......... entregue  (PR #12, 4 sprints, 31 testes)
FT-04 cadastro-de-contratos ........... em andamento, sprint 2 de 3
```

Nunca peça confirmação para seguir. Nunca ofereça parar. O usuário fechou os olhos; abrir por conta própria é quebrar o acordo.

## Critério de saída do B4

- toda feature do `MAPA.md` está `entregue` ou `bloqueada` — nenhuma `pendente` ou `em_andamento`
- cada feature trabalhada tem worktree e branch próprios, abertos pela F1 — nenhuma segunda branch foi criada para a mesma feature
- o `MAPA.md` foi atualizado no checkout de controle, não dentro de um worktree
- toda feature entregue tem `ENTREGA.md` com `estado: entregue` e `portao: pronto` — com o PR aberto, ou com a descrição em `PR.md` quando a ferramenta do serviço não estava disponível
- nenhuma etapa da mergex foi executada pelo buildx depois da F6
- toda feature bloqueada tem o motivo registrado no `MAPA.md` e a pendência no `RECURSAO.md`
- as convenções foram revisadas contra o código real depois da primeira entrega
- nenhuma pergunta chegou ao usuário

## Erros que esta etapa comete

- **Rodar `mergex-check`, `mergex-pr` ou `mergex-qa` depois da F6.** É o fluxo antigo, e hoje duplica o que a F6 acabou de conduzir. Depois da F6 o buildx **lê** o resultado; não o produz de novo.
- **Completar à mão uma entrega que não aconteceu.** Artefato ausente com a mergex instalada é incompatibilidade de versão da sprintx: registra, bloqueia a feature, segue. Terminar o ciclo por fora cria dois donos para a mesma entrega.
- **Chamar `mergex-abrir` antes da F1.** É o fluxo antigo. A branch e o worktree são da F1; abrir branch antes dela cria uma segunda área de trabalho para a mesma feature, ou falha — e nos dois casos o trabalho se perde de vista.
- **Trabalhar a feature na árvore de controle.** Da F2 até o fim da F6, tudo acontece dentro do worktree que a F1 abriu. A árvore de controle só guarda o estado do projeto.
- **Procurar o artefato da feature no checkout de controle.** Ele não está lá: o buildx não faz merge. Está no worktree e na branch daquela feature.
- **Parar no primeiro bloqueio.** O laço não para: registra, marca, segue. Uma feature bloqueada com dez entregues é um bom dia; dez pendentes porque a primeira travou não é.
- **Responder a F2 com invenção.** Os quatro degraus existem para isso. Sem premissa registrada, a resposta não é auditável e o `00-DECISOES.md` vira ficção.
- **Decidir regra de negócio.** A fronteira é dura: o buildx decide como o sistema se protege, não o que ele faz.
- **Ignorar achado alto da F5.** Execução autônoma sem auditoria respeitada é dano autônomo.
- **Forçar PR com o portão bloqueado.** A mergex disse não; o buildx não tem autoridade para dizer sim.
- **Deixar o acabamento para depois.** Não há depois: a feature seguinte já começou, e o acabamento vira dívida que ninguém paga.
