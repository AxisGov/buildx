# B4 — Construção

O laço. Percorrer o `MAPA.md` em ordem de dependência e, para cada feature, conduzir o sprintx de ponta a ponta — a entrega vem junto, porque a F6 a conduz.

Entrada: `MAPA.md`. Saída: uma área de trabalho própria, um plano e uma entrega registrada por feature — com o portão verde e o PR aberto, quando a ferramenta do serviço existiu; o `MAPA.md` atualizado no checkout de controle.

O B4 é longo mas é a etapa mais simples do buildx: ele quase não decide nada. A competência está no sprintx e na mergex; o trabalho aqui é invocar na ordem certa, com a entrada certa, e não parar quando algo falha.

## O ciclo de uma feature

```
CONTROL = checkout de controle = buildx/<projeto_id>
          (docs/projeto/, docs/stack/ — e o produto acumulado)
  │
  0. GATES:  HEAD de CONTROL == origin/buildx/<projeto_id>
  │          cada FT em depende_de integrada e alcançável
  │
  1. MAPA: FT-NN → em_andamento
  2. commit   chore(buildx): FT-NN em andamento
  3. push origin buildx/<projeto_id>
  4. BASE_SHA := HEAD de CONTROL
  │
  5. sprintx F1 ── nasce de BASE_SHA ──► worktree ../<repo>--<slug>
  │                                      branch  feature/<slug>  (tip == BASE_SHA)
  │                                      00-PLANEJAMENTO.md  criar <slug> 3 buildx
  │                                           │
  │   ┌─ JANELA FECHADA ─────────────┐        ├─ F2 → F5   plano e auditoria
  │   │ CONTROL não recebe commit    │        │            + checkpoints locais da sprintx
  │   │ nenhum enquanto isto roda    │        │  planejamento.sh fase decide:
  │   └──────────────────────────────┘        │    F6 ─────┐    PARAR/orcamento_esgotado
  │                                           │            │    → portão terminal pré-F6
  │                                           └─ F6        execução sob TDD
  │                                                        + entrega inteira:
  │                                                        E0 · E1 por task ·
  │                                           │            FECHAMENTO.md · E2→E8
  ◄──────── volta ao checkout de controle ────┘
  6. lê ENTREGA.md + FECHAMENTO.md COMMITADOS (git show feature/<slug>:...)
  7. PROVAS: A HEAD==BASE_SHA · B origin==BASE_SHA · C ancestral · D CONTROL limpa
             E worktree da feature limpa · F estado final no HEAD da feature
             + entrega publicada: push_feito e origin/feature == feature
  8. git merge --ff-only feature/<slug>
  9. MAPA: entregue + Integrada em <FEATURE_SHA>
 10. commit   chore(buildx): FT-NN entregue
 11. push origin buildx/<projeto_id>          →  próxima feature
```

Nenhuma etapa é pulada, e o sprintx nunca é invocado fora de ordem — a máquina de estados dele detecta a fase pelo disco de `docs/sprintx/features/<slug>/`, então basta invocar a skill **de dentro da área de trabalho certa** e ela continua de onde parou.

## Três níveis, e nenhum se confunde com o outro

```
main                        intocada do B2 até o PR final
  └─ buildx/<projeto_id>    CONTROL: estado do projeto + produto acumulado
       └─ feature/<slug>    worktree temporário de uma feature
```

| Árvore | O que mora nela | Quem escreve |
|---|---|---|
| **branch principal** | o commit inicial do B2, e mais nada | ninguém, até o merge humano do PR final |
| **`buildx/<projeto_id>`** = checkout de controle | `docs/projeto/*`, `docs/stack/CONVENCOES.md`, e **cada feature já integrada** | o buildx (só o próprio estado) e o fast-forward das features |
| **worktree da feature** — `../<repo>--<slug>` | `docs/sprintx/features/<slug>/`, `docs/entregas/<slug>/` e o código daquela feature | o sprintx e a mergex |

O worktree é criado pela **F1 do sprintx** (regra 21 dele), a partir de `buildx/<projeto_id>` — é isso que faz a `FT-02` nascer enxergando a `FT-01`. O buildx **não cria branch de feature e não cria worktree**: ele entra no que a F1 abriu, acompanha até a F6, e volta.

## A invariante que sustenta tudo

> **Entre o nascimento de `feature/<slug>` e a integração dela — ou o seu encerramento terminal —, `buildx/<projeto_id>` não recebe nenhum commit que não venha dessa própria feature.**

A branch da feature, ela sim, avança dentro da janela: pelos **checkpoints de planejamento da sprintx** (fim da F2, da F3, da F4 e cada veredito da F5), pelos **commits E1** e pelos commits de método e de entrega posteriores. Nada disso quebra a janela — nenhum deles toca a `CONTROL`.

O `git merge --ff-only` do passo 7 não é apenas o mecanismo de integração: ele é o **teste** dessa invariante. Se o fast-forward falhar, ele está dizendo que alguma coisa avançou `CONTROL` no meio do caminho — e a resposta certa é **parar e relatar**, nunca trocar de mecanismo.

Nunca substitua o ff-only por `merge --no-ff`, `rebase`, `cherry-pick`, `update-ref`, `reset`, `stash` ou qualquer forma de `--force`. Cada um deles faz o sintoma sumir e o problema ficar.

## Passo 1 — Os três portões, e o commit que fixa a base

Nada começa antes destes portões. Todos são binários, e todos param o laço quando falham — parar aqui é barato; descobrir depois que a feature nasceu da árvore errada, não.

### Portão 0 — a feature realmente é nova

Vale quando o `MAPA.md` diz `pendente`. Antes de marcar `em_andamento`, confirme que **nada daquela feature já existe**:

```
git rev-parse --verify --quiet refs/heads/feature/<slug>
git worktree list --porcelain
```

| O que você encontra | O que fazer |
|---|---|
| Nenhuma branch, nenhum worktree, nenhum artefato antigo | siga |
| Branch ou worktree existindo com o mapa dizendo `pendente` | **PARE E RELATE** a inconsistência |

**Nunca reutilize em silêncio.** Uma branch que já existe com o mapa em `pendente` significa uma de três coisas: uma execução anterior morreu antes de o mapa ser atualizado, alguém criou a branch por fora, ou o slug está sendo reaproveitado. As três são decisão humana, e nenhuma se resolve começando por cima.

### Portão 1 — local e remoto no mesmo ponto

Havendo remoto:

```
git fetch origin
git rev-parse HEAD
git rev-parse origin/buildx/<projeto_id>
```

Exija **igualdade estrita**. Local à frente, local atrás ou divergente: **pare e relate**.

Não é preciosismo. Se o local estiver **à frente**, a base remota está velha, e o PR que a mergex abrir para esta feature vai calcular o diff contra um SHA antigo — o PR passaria a mostrar também o trabalho da feature anterior. Se estiver **atrás**, alguém moveu o remoto e o push do fim seria rejeitado.

**Nunca** resolva sozinho: sem `pull`, sem merge do remoto, sem `rebase`, sem `--force`. Sem remoto configurado, este portão é `n/a`.

### Portão 2 — as dependências estão integradas

Para cada `FT-XX` em `depende_de` (`references/04-decomposicao.md`), duas condições, as duas obrigatórias:

1. o `MAPA.md` traz `**Integrada em:** <sha>` para a `FT-XX`;
2. o SHA está na árvore:

```
git merge-base --is-ancestor <sha> buildx/<projeto_id>
```

**`status: entregue` no `MAPA.md` não basta** — ele diz o que o buildx achou que fez; só o Git diz o que está na árvore.

**Mapa dizendo `entregue` sem SHA é inconsistência de estado.** A única rederivação automática permitida é a evidência que só existe se o conteúdo entrou de fato:

```
git cat-file -e buildx/<projeto_id>:docs/entregas/<slug>/ENTREGA.md
```

com aquele arquivo, **na árvore integrada**, declarando `estado: entregue`. Então derive e repare o mapa:

```
git rev-list -1 buildx/<projeto_id> -- docs/entregas/<slug>/ENTREGA.md
```

Sem essa evidência, a dependente **não inicia**: marque `bloqueada` com o motivo `dependencia_nao_integrada` e siga para a próxima feature. **A existência de `feature/<slug>` não é prova de nada** — a branch pode ter sido removida, reaberta ou reutilizada.

### Marcar, commitar, publicar, fixar a base

Passados os dois portões:

1. `MAPA.md`: a feature vira `em_andamento` — **agora**, não no fim, porque é disso que o `/buildx-retomar` depende;
2. commit do estado: `chore(buildx): FT-NN em andamento`;
3. `git push origin buildx/<projeto_id>` — push normal; rejeitado, **pare e relate**;
4. **`BASE_SHA` := `HEAD` de `CONTROL`.** É este SHA — igual no local, no remoto e na base que a F1 vai usar — que fecha a janela.

**Não invoque `mergex-abrir`.** A branch e o worktree são da F1, e a mergex entra depois: quem aciona o E0 dela é a própria F6 do sprintx, já dentro do worktree. Chamar `mergex-abrir` antes da F1 tenta abrir uma segunda área de trabalho para a mesma feature.

## Passo 2 — A F1, com o briefing do buildx

**A F1 abre a área de trabalho e monta a base de conhecimento** — nessa ordem. Antes do scaffold, ela cria ou retoma o worktree `../<repo>--<slug>` na branch `feature/<slug>`; a partir daí, tudo da feature acontece lá dentro. Se a F1 anunciar a área de trabalho e encerrar (é o comportamento dela quando o harness não troca de árvore sozinho), **continue de dentro do diretório que ela indicou** — não recomece a fase na árvore de controle.

**A base vem do `CONVENCOES.md`, e o buildx confere.** A F1 resolve a base sozinha, e a primeira precedência dela é a seção de versionamento — onde o B2 gravou `Branch base: buildx/<projeto_id>`. O que o buildx confere depois depende de **como** esta feature chegou aqui, e a diferença importa:

### Caminho A — feature nova: igualdade exata

Imediatamente depois de a F1 abrir a área de trabalho, **antes da F2 e antes de qualquer commit da feature** — o primeiro checkpoint da sprintx só acontece no fim da F2:

```
git rev-parse feature/<slug>        # tem que ser exatamente BASE_SHA
```

**Exatamente**, não "descendente". A F1 não implementa, não commita produto e não faz checkpoint: uma branch recém-criada aponta para o mesmo commit da base. Se o tip já está à frente, a branch **não é nova** — carrega commits que ninguém auditou, e que entrariam na árvore do projeto no fast-forward sem nunca terem passado por um portão.

Diferente de `BASE_SHA`: **pare e relate.**

Descendência (`git merge-base --is-ancestor`) não basta aqui, e é justamente essa a lacuna: uma branch antiga que por acaso descenda de `BASE_SHA` passaria na prova de ancestralidade carregando trabalho estranho.

### Caminho B — retomada: ancestralidade

Quando o `MAPA.md` já dizia `em_andamento` e a feature volta de uma sessão interrompida, a branch pode estar **legitimamente** à frente, por três razões, nesta ordem no tempo:

1. **checkpoints de planejamento da sprintx** — commits com o trailer `Planejamento: checkpoint`, só em `docs/sprintx/features/<slug>/**`, antes da F6;
2. **commits E1** — um por task, na F6;
3. **commits de método e de entrega** da mergex, até o E8.

Ela também pode estar **exatamente** em `BASE_SHA`, se a sessão morreu antes do primeiro checkpoint. Aqui a prova é a de ancestralidade:

```
git merge-base --is-ancestor <BASE_SHA> feature/<slug>
```

E `BASE_SHA` é derivado da `CONTROL` congelada — o `HEAD` dela, que não se moveu desde o início da janela. **Nunca recrie a branch**, nunca exija igualdade de tip numa retomada, nunca faça `rebase`. Worktree perdido se reabre **sobre a mesma branch** (`git worktree add ../<repo>--<slug> feature/<slug>`), e a sprintx retoma pelo `planejamento.sh fase` (passo 4).

Nos dois caminhos, falhar significa a mesma coisa: a feature nasceu de outro lugar — `CONVENCOES.md` alterado, seção marcada `PROPOSTA`, branch reaproveitada. Integrar depois seria impossível, e seguir seria construir sobre a árvore errada.

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

E, sempre, o orçamento da F5, literalmente:

```
max_reprovacoes_f5: 3
orcamento_declarado_por: buildx
```

A F1 o repassa ao criar o estado do planejamento — `planejamento.sh criar <slug> 3 buildx` — e dali em diante **a sprintx é a única dona da contagem** (`references/integracao/sprintx.md`, "O orçamento da F5, declarado no briefing"). O buildx não cria nem edita o `00-PLANEJAMENTO.md`.

Acrescente `origem_buildx` e `feature_id` ao frontmatter dos artefatos da feature (`references/00-schema.md`).

**A regra 9 do sprintx vale sem atenuação:** na F1 nada de invenção. O que a base não afirma é `NÃO DOCUMENTADO`.

## Passo 3 — A F2 respondida pelo buildx

**O ponto mais delicado do método, e a violação mais séria que o buildx comete.**

A regra 10 do sprintx obriga a F2 a entrevistar o humano em blocos de até cinco perguntas, esperando resposta. No buildx o humano já falou — na descrição e, no modo briefing, na rodada única. Então o buildx **responde no lugar dele**.

Como responder, na ordem, sem pular degrau:

1. **Derivável do `PROJETO.md`?** Use, e cite a seção na justificativa.
2. **Derivável do `PREMISSAS.md`?** Use, e cite o `PR-NN`.
3. **Derivável do `CONVENCOES.md`?** Use, e cite a regra.
4. **Nenhum dos três responde?** → **crie uma premissa nova**, e só então responda com ela.

O degrau 4 é o que separa decisão auditável de invenção. Nunca responda a F2 com algo que não esteja escrito — se não estiver, escreva primeiro, com o `o_que_invalida` preenchido, e responda depois. Essa ordem **não muda**.

O que muda é **onde** se escreve.

### A premissa nasce na feature, não no estado global

Estamos dentro da janela fechada: `CONTROL` está em `BASE_SHA` e precisa terminar limpa para o fast-forward. Editar `CONTROL/docs/projeto/PREMISSAS.md` durante a F2 sujaria a árvore de controle, e o portão pré-ff barraria a própria feature que a premissa serve.

Editar a cópia de `docs/projeto/PREMISSAS.md` **dentro da branch da feature** também não serve: para a mergex, ele é arquivo de produto fora da lista de qualquer task — vira desvio de escopo e reprova o portão (V9).

Então a premissa nasce **feature-local**, em arquivo próprio do buildx, dentro da pasta canônica da feature — que a mergex já trata inteira como artefato de método:

```
docs/sprintx/features/<slug>/BUILDX-PREMISSAS.md
```

**Não é o `00-DECISOES.md`.** Aquele arquivo é da sprintx: ela define o frontmatter `kind: decisoes`, as linhas `D-NN` e `PENDENTE-NN`, e ela o regenera quando a F2 roda de novo. Guardar estado do buildx ali daria dois donos ao mesmo arquivo, e o buildx passaria a vida reparando prosa que não é dele (D-24).

Formato, sem frontmatter e sem schema novo — exatamente os campos que a promoção vai precisar:

```markdown
# Premissas pendentes do BuildX

### PR-07 — Política de expiração da sessão

- origem: f2_autonoma
- decisao: Sessao expira apos 8 horas
- justificativa: PR-02 e CONVENCOES.md estabelecem sessao stateless
- o_que_invalida: requisito explicito de sessao permanente
- status: pendente_promocao
```

`origem` é `f2_autonoma`, ou `f3_autonoma` quando vier da R11 da F3.

### Reservar o `PR-NN` antes de usar

1. **determine o próximo número** lendo o `PREMISSAS.md` da `CONTROL` em `BASE_SHA` — a árvore congelada. Como só há uma feature por vez e `CONTROL` não se move dentro da janela, o número reservado **permanece estável** até a integração;
2. **confira o `BUILDX-PREMISSAS.md` da feature.** A mesma premissa já está lá: **reuse**, com o `PR-NN` que ela já tem;
3. **senão, grave-a** no `BUILDX-PREMISSAS.md`;
4. **só então** use essa premissa para responder à F2 (ou à F3);
5. **grave a decisão resultante no `00-DECISOES.md`**, no schema da sprintx, citando a fonte em `motivo` — que aqui é `BUILDX-PREMISSAS.md#PR-NN`.

Várias premissas na mesma feature seguem numerando a partir dali, na ordem em que nascem.

A divisão é essa, e é o que mantém cada arquivo com um dono só: **a sprintx é dona da decisão**, no `00-DECISOES.md`; **o buildx é dono da premissa** que pode virar estado global, no `BUILDX-PREMISSAS.md`. O humano abre os dois e vê a decisão e a premissa que a sustenta, cada uma no arquivo de quem a escreveu.

### A proveniência mora em `motivo`, e o schema não muda

O item de decisão do `kind: decisoes` aceita seis chaves — `id`, `decisao`, `alternativa_descartada`, `motivo`, `status`, `bloqueante` — e só. **Não acrescente chave nenhuma** — nem uma para registrar quem respondeu —, não crie frontmatter paralelo, não abra bloco privado do buildx ali. Um campo fora do contrato passa despercebido em revisão e só aparece quando a cadeia roda inteira, que foi exatamente como este foi encontrado (D-25). O `00-DECISOES.md` é da sprintx; o buildx responde no formato que ela já entende.

A rastreabilidade continua inteira, em `motivo`: uma linha de texto que diz **de onde a resposta veio**, nominalmente. E o marcador `(HIPOTESE)` não é enfeite — a sprintx define que decisão **sem** ele é lida como confirmada pelo usuário, em qualquer modo. Então classifique a origem antes de escrever:

| Caso | De onde a resposta veio | `(HIPOTESE)`? | `motivo` |
|---|---|---|---|
| **A** | declaração direta do usuário, no pedido ou no briefing | **não** | `Fonte: PROJETO.md#descricao-original — declarado pelo usuario no briefing BuildX` |
| **B** | premissa assumida pelo buildx (`BUILDX-PREMISSAS.md` ou `PREMISSAS.md`) | **sim** | `(HIPOTESE) fonte: BUILDX-PREMISSAS.md#PR-07 — convencao escolhida pelo BuildX para manter a execucao reversivel` |
| **C** | convenção do `CONVENCOES.md` | **depende** | confirmada pelo usuário: factual, como no A. Decidida pelo buildx ou detectada pelo stackx: `(HIPOTESE) fonte: CONVENCOES.md#<regra> — decidido_pelo_buildx no B2` |

**O caso C é onde se erra.** "Está estabelecida no arquivo" não é "o usuário confirmou": a maior parte do `CONVENCOES.md` de um projeto novo nasce marcada `decidido_pelo_buildx`, e uma decisão derivada dela sem `(HIPOTESE)` afirma ao leitor uma confirmação humana que nunca houve. Na dúvida, marque — hipótese declarada se confirma depois; confirmação inventada não se desfaz.

**Prosa e YAML dizem a mesma coisa.** A linha `D-NN | decisão | alternativa descartada | motivo` da prosa usa **o mesmo `motivo`** do frontmatter. Sem coluna nova, sem campo extra, sem apêndice.

**Na retomada, preserve.** O `BUILDX-PREMISSAS.md` existente vale inteiro. Mesmo `PR-NN` com o mesmo conteúdo: reuse, é no-op. Mesmo `PR-NN` com conteúdo diferente: **pare e relate** — não escolha uma das versões.

**A F2 e a F3 podem rodar de novo, e o `00-DECISOES.md` pode ser regenerado do zero pela sprintx.** A premissa sobrevive, porque não está lá. Quando a decisão nova voltar a usá-la, cite `BUILDX-PREMISSAS.md#PR-NN` outra vez, em `motivo`, com `(HIPOTESE)` como da primeira vez. O buildx **não preserva campo estrangeiro** no arquivo regenerado — não há campo do buildx ali para preservar.

### A fronteira que a F2 não atravessa

Se a F2 levantar uma questão de **regra de negócio** que nenhum dos três arquivos responde — quanto tempo um contrato fica válido, se o desconto acumula, qual imposto se aplica — o buildx **não inventa**. Isso não é requisito não-funcional; é o que o sistema faz, e decidir isso no lugar do usuário produz um sistema que funciona e está errado.

Nesse caso: registre **na própria feature** — o bloqueio na pasta dela e a premissa provisória no `BUILDX-PREMISSAS.md` — e **siga com a decisão mais reversível possível**, marcada como provisória no código e na premissa. O `RECURSAO.md` **não** é escrito agora: a `CONTROL` está em `BASE_SHA`, e qualquer escrita nela mataria o fast-forward. A pendência global nasce quando a tentativa termina — no commit de estado que fecha a feature, entregue ou terminalmente bloqueada (a triagem, adiante). O relatório final lista todas essas — são a primeira coisa que o humano precisa olhar.

## Passo 4 — F3 a F5, dentro da janela fechada

**Da F1 até a integração — ou o encerramento terminal —, `CONTROL` não recebe commit nenhum, e nem sequer fica suja.** Nem do buildx, nem de ninguém: `MAPA.md`, `PREMISSAS.md`, `CONVENCOES.md`, `PROJETO.md` e `RECURSAO.md` não são editados enquanto a feature roda. Premissa nova nasce **feature-local** (passo 3) e só vira estado global depois da integração (passo 8); pendência da feature fica em artefato feature-local e só vira pendência global quando a tentativa termina.

É só isso que garante o fast-forward — e é a regra mais fácil de quebrar sem perceber, porque o impulso natural é "registrar agora que está fresco". O registro acontece agora, na feature; o que espera é o **estado global**.

Rodam sem intervenção do buildx. Os pontos de atenção:

**A F3 pode perguntar.** A regra 11 do sprintx permite uma pergunta quando a F3 encontra decisão que exigiria humano em execução. No modo autônomo essa pergunta não chega ao usuário: o buildx a responde pelo mesmo procedimento de quatro degraus do passo 3.

**A F5 é auditoria de verdade.** Achado de severidade alta manda voltar à F3 — e o buildx obedece, sem atalho. A tentação de seguir com um plano que a auditoria reprovou é grande no modo autônomo, e ceder a ela é o que transforma execução autônoma em dano autônomo.

**Quem decide o passo seguinte é o `planejamento.sh fase`.** Depois de cada fase, antes de avançar e em toda retomada, o buildx consulta a sprintx de dentro do worktree e age **só** pela saída dela — a tabela está em `references/integracao/sprintx.md`, "O buildx consulta, não interpreta". Em resumo:

| A sprintx responde | O buildx |
|---|---|
| `F3` · `F4` · `F5`, `persistencia=duravel` | continua a sprintx nessa fase, na mesma branch e no mesmo worktree |
| `F6`, `estado=aprovado`, `persistencia=duravel` | segue para a F6 (passo 5) |
| `PARAR`, `estado=orcamento_esgotado`, `persistencia=duravel` | **portão terminal pré-F6** (abaixo) |
| `CHECKPOINT`, `persistencia=pendente` | pede à sprintx que complete o checkpoint, e **nada mais**: não bloqueia, não mexe no mapa, não roda B5, não começa outra feature |
| `persistencia_falhou` num checkpoint | **para a orquestração da feature** e relata; preserva worktree e branch. Não é `orcamento_esgotado`, não é `bloqueada`, não é `decisao_humana` |

**O orçamento é contado pela sprintx.** O buildx declarou `3` no briefing; a sprintx registra cada veredito no `historico` do `00-PLANEJAMENTO.md` e decide `replanejar` ou `orcamento_esgotado`. O buildx não conta reprovações, não lê "rodada N" de prosa, não soma linhas `VEREDITO:`, não sobe o teto e não o reinicia numa retomada.

**O buildx não comita artefato da sprintx.** O checkpoint é dela — commit local, só da pasta da feature, com o trailer `Planejamento: checkpoint`. Esse commit não é task concluída, não é E1, não é entrega, não é push e não é PR.

**A F3.5 é opcional.** A estimativa não muda nada no modo autônomo — não há prazo a negociar. Rode se for barata; pule sem cerimônia.

## O portão terminal pré-F6

Quando a sprintx responde `fase=PARAR`, `estado=orcamento_esgotado`, `persistencia=duravel`, a tentativa terminou antes da F6 — e esta feature **não será integrada**. É isso que permite à `CONTROL` avançar. Mas relato de modelo não move a `CONTROL`: o que move é evidência no Git. **Antes de qualquer escrita em `CONTROL`**, havendo remoto `git fetch origin` primeiro, prove:

| # | Prova | Como |
|---|---|---|
| **A** | `CONTROL` continua onde a feature nasceu | `git rev-parse HEAD` == `BASE_SHA` |
| **B** | o remoto da `CONTROL` continua no mesmo ponto, quando houver remoto | `git rev-parse origin/buildx/<projeto_id>` == `BASE_SHA` |
| **C** | a feature descende da base | `git merge-base --is-ancestor <BASE_SHA> feature/<slug>` |
| **D** | a árvore de controle está limpa | `git status --porcelain` vazio, em `CONTROL` |
| **E** | a árvore da feature está limpa | `git status --porcelain` vazio, no worktree da feature |
| **F** | o estado terminal está **commitado** | `git show feature/<slug>:docs/sprintx/features/<slug>/00-PLANEJAMENTO.md` com `estado: orcamento_esgotado` |
| **G** | a sprintx não está em checkpoint pendente | `planejamento.sh fase <slug>` responde `PARAR` / `orcamento_esgotado` / `duravel` — nunca `CHECKPOINT` |
| **H** | não há produto antes da F6 | ver abaixo |
| **I** | a auditoria da rodada terminal está commitada | o commit mais recente que tocou o `00-PLANEJAMENTO.md` na branch (`git log -1 --format=%H feature/<slug> -- docs/sprintx/features/<slug>/00-PLANEJAMENTO.md`) contém `docs/sprintx/features/<slug>/00-AUDITORIA.md`, esse arquivo não mudou depois dele e termina em `VEREDITO: NÃO` |

**Falhou qualquer uma: pare e relate.** Não marque `bloqueada`, não escreva `MAPA.md`, `PROJETO.md` nem `RECURSAO.md`. Working tree — arquivo no disco que não está no `HEAD` — nunca move a `CONTROL`.

### A prova H — sem produto antes da F6

Não basta olhar o working tree. Compare o **histórico** da feature desde a base:

```
git log --format= --name-only <BASE_SHA>..feature/<slug>
git log --format=%B <BASE_SHA>..feature/<slug>
```

Até `orcamento_esgotado`, a sprintx só commitou checkpoints: **todo** path tocado começa por `docs/sprintx/features/<slug>/` — a pasta que a própria sprintx declara como único conteúdo do checkpoint, e onde também mora o `BUILDX-PREMISSAS.md` — e **todo** commit traz o trailer `Planejamento: checkpoint`. Apareceu `src/`, teste de produto, `package.json`, arquivo funcional qualquer, ou um commit sem o trailer: **pare**. Não avance a `CONTROL`: há trabalho na branch que ninguém auditou, e classificá-lo como "plano esgotado" esconderia isso.

Passado o portão, a janela desta feature se encerra, e só então a `CONTROL` pode receber o commit de estado do bloqueio (a triagem, adiante). A branch da feature continua **local e preservada** — o buildx não a publica, não a apaga e não a reescreve.

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

O que o buildx faz é **ler dois artefatos — na branch, não na árvore de trabalho**:

```
git show feature/<slug>:docs/entregas/<slug>/ENTREGA.md
git show feature/<slug>:docs/sprintx/features/<slug>/FECHAMENTO.md
```

| Arquivo | Quem grava | O que o buildx lê |
|---|---|---|
| `docs/entregas/<slug>/ENTREGA.md` | mergex, no E8 | `estado`, `portao`, `pr_url`, `pr_estado`, `push_feito`, `desvios`, `entregue_em` |
| `docs/sprintx/features/<slug>/FECHAMENTO.md` | sprintx, ao fim da F6 | `fechado_em`, `resumo`, `risco_residual`, `testes_adicionados` |

Nenhum campo além desses é inventado: são os que os contratos das duas skills declaram.

**Por que o commitado, e não o arquivo da árvore.** O E8 da mergex fecha persistindo o registro final num commit próprio — o fechamento existe no histórico, não só no disco. E o que o fast-forward vai levar para a árvore do projeto são **commits**. Ler o arquivo da worktree seria decidir por uma evidência que pode não estar no que vai ser integrado; ler o commitado prova que a integração carregará exatamente o que o buildx acabou de ler.

**Arquivo da worktree contradizendo o commitado: pare e relate.** Significa que alguém escreveu depois do fechamento, ou que o E8 não conseguiu persistir — e nos dois casos o estado real é incerto.

### A regra de decisão

| O que o `ENTREGA.md` diz | `MAPA.md` | O que registrar |
|---|---|---|
| `estado: entregue` e `portao: pronto` | **`entregue`** | `pr_url` quando houver, os testes de `testes_adicionados`, e o `risco_residual` do fechamento |
| `portao: bloqueado` (com `estado: bloqueado`) | **`bloqueada`** | o motivo que o portão registrou, e os `desvios`, se houver |
| `estado: aberto` depois de a F6 ter devolvido o controle | **`bloqueada`** | entrega interrompida no meio; o motivo é o que a F6 relatou |

**`pr_url: null` não reprova a feature.** O contrato da mergex é explícito: PR não aberto — porque a ferramenta do serviço não estava disponível ou autenticada — não é falha, e a descrição fica em `docs/entregas/<slug>/PR.md`. O que decide é o portão, não a existência da URL. Registre no `MAPA.md` que a descrição está em arquivo, para o relatório final apontar para lá.

### O portão bloqueado tem registro próprio

`E2 BLOQUEADO` **não pula o E8**. No contrato atual da mergex, o bloqueio segue direto para o E8 em **fechamento bloqueado**: E3 a E7 não executam, o registro grava `estado: bloqueado` e `portao: bloqueado`, e esse registro é **commitado** — mas a branch **não é publicada**.

Então, numa feature bloqueada:

| O que você vê | Como ler |
|---|---|
| `push_feito: false` | **correto.** O E6 não rodou |
| `pr_url: null`, `pr_estado: null` | **correto.** O E7 não rodou |
| nenhum PR aberto para a feature | **correto**, e não é defeito adicional |
| o `ENTREGA.md` commitado na branch, com o bloqueio | **é a evidência**, e é o que a triagem lê |

Não trate a ausência de PR ou de push como problema a mais: é o portão funcionando. O que a triagem decide é outra coisa — se aquilo se resolve replanejando agora.

### Quando os artefatos não estão lá

Com a mergex instalada — e ela é obrigatória —, a ausência de `ENTREGA.md` **commitado** depois da F6 significa que **a sprintx ou a mergex instaladas não têm o contrato E0/E1/E2→E8 com fechamento persistido**. Isso é incompatibilidade de versão, não trabalho pendente.

Nesse caso: marque a feature `bloqueada` com o motivo `incompatibilidade_de_versao`, registre a pendência no `RECURSAO.md` dizendo qual artefato faltou, e **siga para a próxima feature**.

**Não complete o fluxo à mão.** Não rode `mergex-check`, `mergex-pr`, `mergex-qa` nem `mergex-abrir` para "terminar o que faltou": um ciclo de entrega conduzido pela metade por cada lado produz commit sem portão, PR sem pacote de QA, ou entrega registrada duas vezes. Falha explícita de versão é melhor que execução dupla — e o B5 classifica a pendência depois.

**O merge não acontece.** O buildx nunca invoca `mergex-revisar`, nunca oferece, nunca sugere no fim — e a F6 também não o encadeia. Integrar código é decisão humana e essa é a última rede antes de produção. A entrega do buildx é um conjunto de features entregues e descritas, cada uma com o portão verde e, quando a ferramenta do serviço existiu, um PR aberto.

## Passo 7 — Integrar a feature na árvore do projeto

Só chega aqui a feature cujo `ENTREGA.md` diz `estado: entregue` **e** `portao: pronto`. Qualquer outra coisa vai para a triagem, mais abaixo.

### As seis provas, antes de tocar em qualquer coisa

Havendo remoto, `git fetch origin` primeiro. Então:

| # | Prova | Comando |
|---|---|---|
| **A** | `CONTROL` continua onde a feature nasceu | `git rev-parse HEAD` == `BASE_SHA` |
| **B** | o remoto da `CONTROL` continua no mesmo ponto | `git rev-parse origin/buildx/<projeto_id>` == `BASE_SHA` |
| **C** | a feature descende daquela base | `git merge-base --is-ancestor <BASE_SHA> feature/<slug>` |
| **D** | a árvore de controle está limpa | `git status --porcelain` vazio, em `CONTROL` |
| **E** | a árvore da feature está limpa | `git status --porcelain` vazio, no worktree da feature |
| **F** | o estado final está no HEAD da feature | `git show feature/<slug>:docs/entregas/<slug>/ENTREGA.md` declara `estado: entregue` e `portao: pronto` |

**Falhou qualquer uma: pare e relate.** Não tente entender, não tente consertar, não escolha outro caminho — A e C falhando significam que a invariante foi violada; B, que outra sessão ou outra pessoa mexeu no remoto. Quem decide é gente.

A prova **E** merece nota. Numa entrega `PRONTO`, a árvore da feature termina limpa: o E8 da mergex commita os artefatos de método que sobraram, e arquivo de produto fora do plano teria reprovado o portão antes (V9). Derivado e ignorado — o rastro de eventos, o `estado.json` da barra — não aparece em `git status --porcelain` e não conta. Então sujeira rastreável ali é **contradição**: a entrega diz pronta e a árvore diz que ficou coisa fora. Pare.

### A entrega precisa estar publicada

Havendo remoto e `versionado: true`, o E8 da mergex publica o commit final. O buildx confere, sem nunca republicar:

```
git fetch origin
git rev-parse feature/<slug>
git rev-parse origin/feature/<slug>
```

| Situação | O que fazer |
|---|---|
| `push_feito: true` e os dois SHAs iguais | siga para o fast-forward |
| `push_feito: false` com remoto configurado | **PARE E RELATE.** A entrega não está no remoto |
| `origin/feature/<slug>` ausente, inesperadamente | **PARE E RELATE** |
| SHAs diferentes | **PARE E RELATE** |

**O buildx não republica.** A posse é clara: a **mergex publica a feature**, o buildx consome o resultado. Empurrar a branch de outra skill para "consertar" quebraria essa fronteira e esconderia a causa — que é sempre uma das duas: o push final falhou, ou alguém mexeu na branch.

Sem remoto, `push_feito: false` é o esperado, esta prova é `n/a`, e o fast-forward local continua permitido.

### O fast-forward

```
git merge --ff-only feature/<slug>
```

É a única forma de integrar. Ele **não cria commit**, não reescreve nada, não resolve conflito e não pode trazer conteúdo que não esteja na feature. Repetir é inofensivo: numa feature já integrada ele responde `Already up to date`, e é isso que torna a retomada segura.

**Se ele falhar, pare.** Não use `--no-ff` (mascararia a divergência mesclando o que deveria travar), não use `rebase` (reescreveria commits que já têm PR aberto, e o hook da sprintx o barra), não use `cherry-pick` (duplicaria commits e destruiria a ancestralidade de que o portão de dependência depende), não use `update-ref` (faria o mesmo sem nenhuma verificação), não use `reset`, `stash` nem `--force`.

Depois do ff, `FEATURE_SHA` := `HEAD` de `CONTROL`. É esse SHA que vai para o mapa.

## Passo 8 — Fechar a feature

**Só agora — depois do fast-forward — `CONTROL` volta a receber commit.**

### Promover as premissas pendentes

O `BUILDX-PREMISSAS.md` da feature acabou de entrar na árvore pelo fast-forward. **Antes** do commit de estado, leia-o e promova:

```
docs/sprintx/features/<slug>/BUILDX-PREMISSAS.md   →   docs/projeto/PREMISSAS.md
```

Cada premissa com `status: pendente_promocao` vira premissa do projeto, **com o mesmo `PR-NN`**, `origem` preservada e todos os campos que o `references/00-schema.md` exige.

A idempotência é pelo próprio `PR-NN`, e não por marcação:

| O que você encontra no `PREMISSAS.md` | O que fazer |
|---|---|
| o `PR-NN` não existe | promova |
| o `PR-NN` existe com o mesmo conteúdo | **no-op** — já foi promovido numa passagem anterior |
| o `PR-NN` existe com conteúdo **diferente** | **PARE E RELATE** a inconsistência |

Nada é escrito de volta no `BUILDX-PREMISSAS.md` para marcar a promoção. Ele é o registro do que aquela feature assumiu, já está integrado, e reescrevê-lo só para carimbar "promovido" criaria um segundo lugar onde a verdade pode divergir. A existência idêntica do `PR-NN` no `PREMISSAS.md` **é** a prova da promoção.

**Só feature integrada promove.** Premissa de feature bloqueada ou em replanejamento continua onde está (ver a triagem, adiante).

### Atualizar o mapa

No `MAPA.md`, no checkout de controle:

- `status` para `entregue`, e os contadores do frontmatter;
- `**Integrada em:** <FEATURE_SHA>` no bloco daquela feature;
- o PR (ou o caminho do `PR.md`), os testes de `testes_adicionados` e o `risco_residual` do `FECHAMENTO.md`.

Junto vai o `PREMISSAS.md` com as premissas recém-promovidas, e o mais que estiver represado. Então:

```
commit   chore(buildx): FT-NN entregue
git push origin buildx/<projeto_id>
```

Push normal. **Rejeitado: pare e relate** — nunca `--force`, nunca `--force-with-lease`, nunca um `pull` para "resolver".

O `MAPA.md` é do projeto, não da feature: ele nunca é editado dentro do worktree, senão a atualização fica presa na branch daquela feature e a próxima nasce de um mapa desatualizado.

O worktree da feature **fica onde está**, e o buildx **nunca o remove sozinho**. O conteúdo já está na árvore do projeto, mas a branch continua sendo a referência do PR daquela feature até o merge humano do PR final. Quando o relatório final listar árvores que podem ser removidas, quem remove é a pessoa.

**Depois da primeira feature integrada**, rode a revisão de convenções do B2 — e agora ela roda **no próprio checkout de controle**, porque o código real acabou de entrar nele. Converta cada regra de `decidido_pelo_buildx` para a evidência encontrada; regra contradita pelo código vira achado a resolver. **Duas linhas ficam de fora, sempre:** `Branch principal` e `Branch base` da seção de versionamento pertencem ao contrato do buildx, não descrevem o código, e só o B6 as altera.

## A triagem imediata — a barreira serial

Feature que não integrou exige uma decisão **na hora**, antes de qualquer outra feature começar. É uma pergunta binária: **isto se resolve replanejando agora?**

| Situação | Classe | O que fazer |
|---|---|---|
| achado alto da F5 com a sprintx respondendo `replanejar` | **replanejável** | a sprintx replaneja **agora**, na mesma branch e no mesmo worktree |
| regra de negócio não declarada, credencial ausente, acesso que falta | **terminal** (`decisao_humana`, `recurso_externo`) | marque `bloqueada` e siga |
| a sprintx responde `PARAR` / `orcamento_esgotado`, durável | **terminal** (orçamento esgotado) | portão terminal pré-F6; passou, marque `bloqueada` e siga |

### Replanejável: `CONTROL` não se mexe

Replanejar é da sprintx: com `estado: replanejar`, `planejamento.sh fase` responde `F3`, e o buildx continua a sprintx na F3 de dentro do mesmo worktree. O buildx **não apaga, não move e não regera** plano nenhum — quem regera o plano é a F3, lendo o `00-AUDITORIA.md`, e cada versão anterior já está no histórico dos checkpoints. E o buildx **não commita estado nenhum**:

- `MAPA.md` continua `em_andamento`;
- `CONTROL` continua exatamente em `BASE_SHA`;
- nenhuma outra feature começa;
- **as premissas pendentes ficam onde estão**, no `BUILDX-PREMISSAS.md` da feature, e são **reutilizadas** na nova tentativa — mesmo `PR-NN`, sem duplicar e sem renumerar. **Não apague o arquivo no replanejamento:** a F2 e a F3 podem rodar de novo e o `00-DECISOES.md` pode ser regerado pela sprintx, e é justamente por a premissa não morar lá que ela sobrevive. Nenhuma delas vai para o `PREMISSAS.md` global: o plano ainda não virou produto.

**É isto que mantém o fast-forward possível.** Se o buildx commitasse um "FT-NN replanejando" aqui, `CONTROL` andaria para `BASE_SHA+1`, deixaria de ser ancestral da feature, e a integração depois seria impossível — exatamente o beco que a barreira serial existe para evitar. O teto é o orçamento do briefing, contado pela sprintx: duas voltas de replanejamento, e a reprovação que o atinge leva a `orcamento_esgotado`.

### Terminal: aí sim o laço segue

`MAPA.md` para `bloqueada`, com o motivo e a pendência no `RECURSAO.md`; commit `chore(buildx): FT-NN bloqueada`; push normal. Aquela branch **nunca será integrada**, e é justamente por isso que `CONTROL` pode avançar sem risco.

**As premissas pendentes dela não são promovidas.** Elas permanecem no `BUILDX-PREMISSAS.md` daquela feature como evidência histórica da tentativa, e o B5 e o relatório final podem lê-las de lá — `git show feature/<slug>:docs/sprintx/features/<slug>/BUILDX-PREMISSAS.md` — quando precisarem explicar as decisões provisórias de uma feature bloqueada. A premissa global representa decisão **incorporada ao produto integrado** — não plano abandonado. Promover a premissa de uma feature que nunca entrou faria o `PREMISSAS.md` afirmar uma decisão que nenhum código realiza, que é exatamente a falha mais cara deste método.

### Isto não fere a regra 4

"Bloqueio nunca para o laço" proíbe **parar e esperar humano** — e aqui nada espera humano: ou o buildx faz o trabalho de replanejar agora, ou classifica como terminal e segue. O que muda é a **ordem** do trabalho, não a autonomia. Nenhuma pergunta chega ao usuário.

## O relato de progresso

Nos dois modos o buildx relata — relatar não é perguntar. Uma linha por transição de feature, seca:

```
FT-03 autenticacao-e-usuarios ......... entregue  (PR #12, 4 sprints, 31 testes)
FT-04 cadastro-de-contratos ........... em andamento, sprint 2 de 3
```

Nunca peça confirmação para seguir. Nunca ofereça parar. O usuário fechou os olhos; abrir por conta própria é quebrar o acordo.

## Critério de saída do B4

- toda feature do `MAPA.md` está `entregue` ou `bloqueada` — nenhuma `pendente` ou `em_andamento`
- toda feature `entregue` tem `**Integrada em:** <sha>` no mapa, e o SHA é alcançável em `buildx/<projeto_id>`
- cada feature trabalhada tem worktree e branch próprios, abertos pela F1 — nenhuma segunda branch foi criada para a mesma feature
- nenhuma feature começou com dependência não integrada
- toda feature nova nasceu com o tip **exatamente** em `BASE_SHA`
- todo briefing declarou `max_reprovacoes_f5: 3` e `orcamento_declarado_por: buildx`, e o `00-PLANEJAMENTO.md` commitado de cada feature o confirma
- nenhuma decisão do buildx sobre o planejamento veio de outra fonte que não `planejamento.sh fase`; nenhuma foi tomada com a sprintx em `CHECKPOINT`
- o buildx não commitou artefato nenhum da sprintx
- `CONTROL` recebeu, por feature, no máximo dois commits do buildx: um antes da F1, outro depois da integração (ou o de bloqueio terminal)
- toda decisão de integrar veio do `ENTREGA.md` **commitado** na branch da feature, não do arquivo da árvore
- toda feature integrada com remoto estava publicada (`push_feito: true`, `origin/feature/<slug>` igual ao local); o buildx não publicou branch de feature nenhuma
- toda integração foi fast-forward; nenhuma usou `--no-ff`, rebase, cherry-pick, `update-ref` ou força
- o `MAPA.md` foi atualizado no checkout de controle, não dentro de um worktree
- toda feature entregue tem `ENTREGA.md` com `estado: entregue` e `portao: pronto` — com o PR aberto, ou com a descrição em `PR.md` quando a ferramenta do serviço não estava disponível
- nenhuma etapa da mergex foi executada pelo buildx depois da F6
- toda feature bloqueada tem o motivo registrado no `MAPA.md` e a pendência no `RECURSAO.md`
- as convenções foram revisadas contra o código real depois da primeira entrega
- nenhuma pergunta chegou ao usuário

## Erros que esta etapa comete

- **Commitar estado no meio da janela.** Uma premissa nova registrada "enquanto está fresco", entre a F1 e a integração, move `CONTROL` e mata o fast-forward. Ela espera o passo 8 — o arquivo é gravado, o commit é que aguarda.
- **Começar outra feature com um replanejamento pendente.** É a barreira serial. A árvore não pode avançar enquanto uma feature ainda vai voltar para dentro dela.
- **Contar reprovação por conta própria.** O teto foi declarado no briefing; quem conta é a sprintx. Ler "rodada 3" numa prosa, somar `VEREDITO:` ou lembrar da sessão anterior é decidir por uma evidência que o script não reconhece.
- **Decidir em cima de `CHECKPOINT`.** O estado do disco ainda não está no `HEAD`: não bloqueie, não avance o mapa, não rode B5, não comece outra feature. Peça à sprintx o checkpoint.
- **Comitar o checkpoint no lugar da sprintx.** Nem `git add` da pasta, nem `--no-verify` para contornar hook. `persistencia_falhou` é parada e relato.
- **Tratar checkpoint como entrega.** `Planejamento: checkpoint` não é E1, não é task concluída, não é push nem PR.
- **Trocar o mecanismo quando o ff falha.** O ff falhando é informação, não obstáculo: ele está dizendo que a invariante quebrou. `--no-ff` esconde; `rebase` e `cherry-pick` destroem a ancestralidade de que os portões dependem.
- **Aceitar `entregue` no mapa como prova de integração.** Só `git merge-base --is-ancestor` prova. O mapa diz o que o buildx achou que fez.
- **Resolver divergência de remoto sozinho.** `pull`, merge do remoto, rebase ou força: nenhum. Divergência é decisão humana.
- **Rodar `mergex-check`, `mergex-pr` ou `mergex-qa` depois da F6.** É o fluxo antigo, e hoje duplica o que a F6 acabou de conduzir. Depois da F6 o buildx **lê** o resultado; não o produz de novo.
- **Completar à mão uma entrega que não aconteceu.** Artefato ausente com a mergex instalada é incompatibilidade de versão da sprintx: registra, bloqueia a feature, segue. Terminar o ciclo por fora cria dois donos para a mesma entrega.
- **Chamar `mergex-abrir` antes da F1.** É o fluxo antigo. A branch e o worktree são da F1; abrir branch antes dela cria uma segunda área de trabalho para a mesma feature, ou falha — e nos dois casos o trabalho se perde de vista.
- **Trabalhar a feature na árvore de controle.** Da F2 até o fim da F6, tudo acontece dentro do worktree que a F1 abriu. A árvore de controle só guarda o estado do projeto.
- **Procurar o artefato de uma feature ainda não integrada no checkout de controle.** Antes do fast-forward ele não está lá — está no worktree e na branch daquela feature. Depois, está aqui, porque o ff o trouxe. Feature bloqueada nunca chega: leia da branch dela.
- **Parar no primeiro bloqueio.** O laço não para: registra, marca, segue. Uma feature bloqueada com dez entregues é um bom dia; dez pendentes porque a primeira travou não é.
- **Responder a F2 com invenção.** Os quatro degraus existem para isso. Sem premissa registrada, a resposta não é auditável e o `00-DECISOES.md` vira ficção.
- **Decidir regra de negócio.** A fronteira é dura: o buildx decide como o sistema se protege, não o que ele faz.
- **Ignorar achado alto da F5.** Execução autônoma sem auditoria respeitada é dano autônomo.
- **Forçar PR com o portão bloqueado.** A mergex disse não; o buildx não tem autoridade para dizer sim.
- **Deixar o acabamento para depois.** Não há depois: a feature seguinte já começou, e o acabamento vira dívida que ninguém paga.
