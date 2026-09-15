# B4 — Construção

O laço. Percorrer o `MAPA.md` em ordem de dependência e, para cada feature, conduzir sprintx e mergex de ponta a ponta.

Entrada: `MAPA.md`. Saída: uma área de trabalho própria, um plano, um PR aberto e verde por feature; o `MAPA.md` atualizado no checkout de controle.

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
  │                                          ├─ 7. sprintx F6  execução TDD — e é ela que aciona a mergex E0
  │                                          ├─ 8. mergex-check  portão de prontidão
  │                                          ├─ 9. mergex-pr     descrição, push, PR aberto
  │                                          └─ 10. mergex-qa    pacote de teste manual
  │                                          │
  ◄──────────── volta ao checkout de controle ┘
  11. atualiza o MAPA.md  →  próxima feature
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

**O acabamento visual acontece aqui**, dentro das tasks de interface, não numa passada depois. Todo componente é construído sobre os tokens do design system (P-6, detalhado em `08-design-system.md`) — nenhum valor de cor literal entra em componente. Se a skill de frontend design estiver disponível (P-7), ela trabalha dentro desse vocabulário, não escolhe outro.

Toda tela entregue tem as duas variantes de tema, os três estados obrigatórios (vazio, carregando, erro) e funciona em tela de celular.

**O que o buildx nunca relaxa na F6:**

- TDD: teste antes da implementação, sempre
- task só é concluída com os dois testes passando; não existe "concluída com ressalva"
- nenhum segredo real em código, artefato ou commit

## Passo 6 — O portão e o PR

As três chamadas da mergex rodam **de dentro do worktree da feature**, onde estão os commits, o plano e o `docs/entregas/<slug>/`. Rodá-las da árvore de controle olharia para a branch errada.

A branch já existe desde a F1, e a entrega já foi registrada pelo E0 que a **F6 acionou**. O buildx não abre branch aqui — nem antes, nem agora. Se a versão do sprintx instalada não acionar o E0, a `mergex-check` dirá que falta o registro da entrega: nesse caso rode `/mergex-abrir` **de dentro do worktree**, onde o E0 adota a branch que já existe. Nunca antes da F1, e nunca para retomar.

`mergex-check` roda as dez verificações. Devolveu **BLOQUEADO**: não force o PR. Trate como bloqueio da feature — marque `bloqueada` no `MAPA.md` com o motivo que a mergex deu, e siga para a próxima feature. O B5 decide o que fazer.

Devolveu **PRONTO**: `mergex-pr` monta a descrição, sobe a branch e abre o PR. A descrição referencia o `projeto_id` e o `FT-NN`.

`mergex-qa` gera o pacote de teste manual. Vale a pena mesmo no modo autônomo: é o que permite a uma pessoa validar a feature sem ler código, e o usuário de demonstração (P-5) é o ambiente desse roteiro.

**O merge não acontece.** O buildx nunca invoca `mergex-revisar`, nunca oferece, nunca sugere no fim. Integrar código é decisão humana e essa é a última rede antes de produção. A entrega do buildx é um conjunto de PRs abertos, verdes e descritos.

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
- toda feature entregue tem PR aberto, com a suíte verde
- toda feature bloqueada tem o motivo registrado no `MAPA.md` e a pendência no `RECURSAO.md`
- as convenções foram revisadas contra o código real depois da primeira entrega
- nenhuma pergunta chegou ao usuário

## Erros que esta etapa comete

- **Chamar `mergex-abrir` antes da F1.** É o fluxo antigo. A branch e o worktree são da F1; abrir branch antes dela cria uma segunda área de trabalho para a mesma feature, ou falha — e nos dois casos o trabalho se perde de vista.
- **Trabalhar a feature na árvore de controle.** Do F2 ao PR, tudo acontece dentro do worktree que a F1 abriu. A árvore de controle só guarda o estado do projeto.
- **Procurar o artefato da feature no checkout de controle.** Ele não está lá: o buildx não faz merge. Está no worktree e na branch daquela feature.
- **Parar no primeiro bloqueio.** O laço não para: registra, marca, segue. Uma feature bloqueada com dez entregues é um bom dia; dez pendentes porque a primeira travou não é.
- **Responder a F2 com invenção.** Os quatro degraus existem para isso. Sem premissa registrada, a resposta não é auditável e o `00-DECISOES.md` vira ficção.
- **Decidir regra de negócio.** A fronteira é dura: o buildx decide como o sistema se protege, não o que ele faz.
- **Ignorar achado alto da F5.** Execução autônoma sem auditoria respeitada é dano autônomo.
- **Forçar PR com o portão bloqueado.** A mergex disse não; o buildx não tem autoridade para dizer sim.
- **Deixar o acabamento para depois.** Não há depois: a feature seguinte já começou, e o acabamento vira dívida que ninguém paga.
