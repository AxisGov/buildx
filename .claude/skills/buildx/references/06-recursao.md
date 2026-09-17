# B5 — Recursão

Varrer tudo que ficou pelo caminho no B4, classificar cada pendência por uma tabela determinística, e devolver ao laço — como **feature sucessora nova** — o que a máquina ainda consegue resolver.

Entrada: `MAPA.md`, `RECURSAO.md` com as pendências que o B4 registrou ao encerrar tentativas, os artefatos **commitados** de cada feature, e o `PREMISSAS.md`. Saída: `docs/projeto/RECURSAO.md` atualizado no checkout de controle, e possivelmente features sucessoras no `MAPA.md`.

**O B5 roda fora da janela fechada.** Nenhuma feature está aberta quando ele começa: toda feature do mapa está `entregue` ou `bloqueada`, e a `CONTROL` pode receber commit. É por isso que o `RECURSAO.md` só é escrito aqui e no commit de estado que **encerra** uma tentativa (a triagem do B4) — nunca durante F2 a F6 de uma feature.

**Feature integrada já está aqui.** O que entrou em `buildx/<projeto_id>` pelo fast-forward veio inteiro — código e artefatos —, então o `00-BLOQUEIOS.md`, o `00-AUDITORIA.md` e o `FECHAMENTO.md` de cada feature entregue são lidos direto no checkout de controle.

**Feature bloqueada, não.** Ela nunca foi integrada: os artefatos dela existem só na branch dela. Leia **do commit**, sem trocar de árvore — `git show feature/<slug>:docs/sprintx/features/<slug>/00-AUDITORIA.md` — e cite o SHA. **Artefato que não aparece no checkout de controle não é artefato inexistente**; e artefato que só existe no working tree de um worktree não é evidência.

O B5 é o que separa "rodou até o fim" de "entregou". Sem ele o buildx produziria um repositório com nove features prontas e três bloqueadas, e chamaria isso de terminado.

## Passo 1 — A varredura

Colete de todas as fontes, sem filtrar nada ainda:

| Fonte | O que colher |
|---|---|
| `RECURSAO.md` | toda pendência em `aguardando_classificacao` — o B4 a registrou no commit que encerrou a tentativa |
| `MAPA.md` | toda feature `bloqueada`, conferindo que cada uma já tem a sua pendência |
| `docs/sprintx/features/<slug>/00-BLOQUEIOS.md` | toda dúvida que a F6 registrou e pulou — no commit da feature: integrada, na `CONTROL`; bloqueada, na branch dela |
| `docs/entregas/<slug>/ENTREGA.md` | `portao: bloqueado` e o que ele apontou, mais os `desvios` — commitado |
| `PREMISSAS.md` | toda premissa marcada provisória |

Toda pendência nova encontrada aqui entra no `RECURSAO.md` como `aguardando_classificacao`, com a evidência commitada, e só então é classificada.

Consulte o `memox`, se instalado: uma pendência que já apareceu em ciclo anterior e voltou não é a mesma pendência — é sinal de que a tentativa anterior não resolveu.

## Passo 2 — A máquina de pendências

### Os estados, e a seção de cada um

O `RECURSAO.md` tem **exatamente** cinco seções, nesta ordem, e cada pendência mora na seção do seu `estado`. Nenhuma execução acrescenta, renomeia ou remove seção — situação que "não cabe" numa delas é um estado que falta ao contrato, e isso é **parar e relatar**, não inventar título.

| `estado` | Seção | `classe` |
|---|---|---|
| `aguardando_classificacao` | `## Aguardando classificação do B5` | `null` |
| `em_resolucao` | `## Em resolução pela máquina` | `trabalho_novo` |
| `decisao_humana` | `## Aberto — decisão humana` | `decisao_humana` |
| `recurso_externo` | `## Aberto — recurso externo` | `recurso_externo` |
| `resolvida` | `## Resolvido nos ciclos` | a que tinha — normalmente `trabalho_novo` |

`resolvida` é **estado**, não classe.

### Os campos

Cada pendência é um bloco `### PEND-NN — <assunto>` com uma linha `- chave: valor` por campo, **nenhum omitido** — ausente é `null` ou `[]` (forma exata em `assets/TEMPLATE-RECURSAO.md`):

| Campo | Conteúdo |
|---|---|
| `id` | `PEND-NN`, sequencial no arquivo, nunca reutilizado |
| `estado` | um dos cinco acima |
| `gatilho` | a linha da tabela do passo 3 que a originou |
| `classe` | `null` enquanto `aguardando_classificacao`; depois, uma das três classes |
| `origem` | `FT-NN`, ou a etapa (`b1`, `b2`, `b6`) que a levantou |
| `ciclo` | o ciclo em que foi detectada |
| `evidencia` | referências **commitadas**, `feature/<slug>@<sha>:<caminho>` (ou `buildx/<projeto_id>@<sha>:<caminho>`), separadas por ` ; ` |
| `causa` | nas entregas: o gatilho que a evidência commitada aponta; senão `null` |
| `clausula_central` | o que o detector de laço compara (passo 5) |
| `raiz` | `PEND-NN` da pendência que a sucessora bloqueada tentava resolver; senão `null` |
| `detectada_em` · `classificada_em` · `resolvida_em` | datas `AAAA-MM-DD`, ou `null` |
| `regra_aplicada` | a regra da tabela que decidiu a classe, literalmente (`orcamento_f5_esgotado/alta_item_7`, `teto_de_ciclos_atingido`, …) |
| `destino` | `FT-NN` da sucessora, quando `trabalho_novo`; senão `null` |
| `pr_reservadas` | os `PR-NN` do `BUILDX-PREMISSAS.md` commitado da feature que terminou sem integrar (passo 7), ou `[]` |
| `nota` | `teto_de_ciclos_atingido`, `laco_detectado`, `segue PEND-NN` (a raiz que acompanha a filha, passo 4), ou `null` |

E os específicos da classe: `decisao_humana` registra `decisao`, `opcoes`, `provisorio` e `reversibilidade`; `recurso_externo` registra `o_que_falta`, `o_que_destrava` e `estado_atual`; `trabalho_novo` registra `sucede` (a `FT-XX` bloqueada) e `slug_sucessora`.

## Passo 3 — A classificação

As classes finais do B5 são **três**, e só estas são escritas:

| Classe | Destino |
|---|---|
| `trabalho_novo` | **feature sucessora** nova no `MAPA.md` (passo 4) |
| `decisao_humana` | fica no `RECURSAO.md`, vai para a primeira seção do relatório. **Nunca vira feature** |
| `recurso_externo` | fica no `RECURSAO.md`, vai para a segunda seção do relatório |

**Replanejar não é classe do B5.** Replanejar a mesma feature existe **só** dentro do B4, pela sprintx, enquanto o orçamento da F5 não terminou — na mesma branch e no mesmo worktree. Quando a pendência chega ao B5, aquela tentativa já acabou: o que continua é trabalho novo, em feature nova.

### A tabela gatilho → classe

Determinística: a mesma evidência commitada dá sempre a mesma classe. Nenhuma linha depende de julgamento sobre "quanto esforço vale".

| Gatilho | Classe | `regra_aplicada` |
|---|---|---|
| `orcamento_f5_esgotado` | pela última `00-AUDITORIA.md` commitada — abaixo | `orcamento_f5_esgotado/alta_item_7` · `/alta_item_8` · `/alta_qualidade_plano` |
| `regra_de_negocio_nao_declarada` | `decisao_humana` | `regra_de_negocio_nao_declarada` |
| `recurso_externo_ausente` | `recurso_externo` | `recurso_externo_ausente` |
| `incompatibilidade_de_versao` | `decisao_humana` | `incompatibilidade_de_versao` |
| `violacao_de_convencao` | `trabalho_novo` | `violacao_de_convencao` |
| `dependencia_nao_integrada` | a classe da pendência raiz — a da dependência que não integrou —, quando identificável; senão `decisao_humana`, com a ambiguidade na `evidencia` | `dependencia_nao_integrada/segue_raiz` · `/raiz_ambigua` |
| `entrega_bloqueada` | pela `causa` commitada: um gatilho desta tabela → a classe dele; `falha_tecnica` (portão reprovado por suíte, cobertura ou escopo) → `trabalho_novo`; sem causa commitada identificável → `decisao_humana` | `entrega_bloqueada/causa_<gatilho>` · `/falha_tecnica` · `/causa_nao_commitada` |
| `entrega_interrompida` | pela `causa` commitada, quando ela é um gatilho desta tabela; senão `trabalho_novo` — tecnicamente resolvível sem decisão | `entrega_interrompida/causa_<gatilho>` · `/resolvivel_sem_decisao` |

### `orcamento_f5_esgotado` — os prefixos `[item N]` da sprintx

Leia a `00-AUDITORIA.md` **commitada** da rodada terminal (a referência está na `evidencia`) e considere só os achados `ALTA` — todo achado começa por `[item N]` desde a sprintx P0.1. Nesta ordem:

1. existe **qualquer** `ALTA` `[item 7]` (task que exigiria decisão humana) → **`decisao_humana`**;
2. senão, existe **qualquer** `ALTA` `[item 8]` (pré-requisito externo não declarado) → **`recurso_externo`**;
3. senão — os `ALTA` são problemas de qualidade ou de planejamento que a máquina corrige: teste fraco, critério subjetivo, dependência, paralelismo, base ignorada, granularidade — → **`trabalho_novo`**.

**Mistura:** o `[item 7]` vence, porque exige decisão humana e nenhuma sucessora a produz; sem `[item 7]`, o `[item 8]` vence. Nenhuma `ALTA` na auditoria terminal é contrato quebrado — `orcamento_esgotado` só existe com `VEREDITO: NÃO` —: **pare e relate**.

A regra que decidiu vai para `regra_aplicada`, literalmente. **Nunca tente reabrir a feature antiga.**

### Compatibilidade

Um `RECURSAO.md` antigo pode trazer a classe `replanejamento`. Ela é **lida** como `trabalho_novo` — e a pendência segue o passo 4 como qualquer outra. Nenhuma escrita nova usa `replanejamento`: ao regravar aquele bloco, a classe sai `trabalho_novo`.

## Passo 4 — `trabalho_novo` vira feature sucessora

A feature bloqueada **permanece `bloqueada` para sempre**. A branch dela não descende mais da `CONTROL` atual, e o plano dela esgotou o orçamento: não há como voltá-la a `pendente`, e tentar seria recomeçar pelo lado que já falhou.

O que continua é uma **feature sucessora**:

- `FT-NN` novo, no `MAPA.md`, na posição correta de dependência;
- **slug novo** — nunca o da bloqueada;
- `origem: recursao`, com `**Sucede:** FT-XX` e `**Pendência:** PEND-NN` no bloco dela;
- nasce, no B4, do `HEAD` **atual** de `buildx/<projeto_id>` — enxergando tudo que foi entregue desde a tentativa antiga;
- passa por uma F1 nova, com worktree novo e branch nova, e com o briefing de sempre — inclusive o orçamento da F5.

**Nunca** volte a feature velha para `pendente`; **nunca** `rebase`, `cherry-pick`, `merge --no-ff` ou `--force` sobre a branch antiga. Ela fica como está, local, para o relatório apontar.

A pendência passa a `estado: em_resolucao`, `classe: trabalho_novo`, `destino: FT-NN`, com `sucede` e `slug_sucessora` preenchidos, e muda para a seção "Em resolução pela máquina".

**Quando a sucessora é entregue** (integrada pelo passo 7 do B4), a pendência vira `estado: resolvida`, com `resolvida_em`, e vai para "Resolvido nos ciclos" — no mesmo commit de estado que marca a sucessora `entregue`.

**Quando a sucessora também é bloqueada**, o B4 registra, no commit do bloqueio dela, uma pendência nova `aguardando_classificacao` com `raiz: PEND-NN` apontando a que ela tentava resolver. O B5 a classifica começando pelo detector de laço (passo 5). A raiz acompanha a filha: filha `em_resolucao` → raiz continua `em_resolucao`, com `destino` na sucessora nova; filha `decisao_humana`, `recurso_externo` ou `resolvida` → raiz no mesmo estado, com `nota` apontando a filha.

A propagação é mecânica, e só lê o que está gravado:

- **O `MAPA.md` manda; o `RECURSAO.md` acompanha.** Para cada pendência `em_resolucao`, o status do `destino`: `pendente`, `em_andamento` ou `bloqueada` → a raiz **continua** `em_resolucao` (bloqueada espera o B5 classificar a filha); `entregue` → `resolvida`. **`destino` que não existe no `MAPA.md` é inconsistência: pare e relate**, sem gravar nada — nenhum estado é inventado.
- **A raiz que segue a filha** em `decisao_humana` ou `recurso_externo` recebe a `classe` e a `regra_aplicada` dela, e `nota: segue PEND-NN` (a filha). A propagação sobe a cadeia `raiz` enquanto o ancestral está `em_resolucao`; o que já saiu de `em_resolucao` não é tocado.
- **A entrega resolve uma cadeia, e só uma.** As pendências `em_resolucao` com `destino` na sucessora entregue — a filha e as raízes que a acompanham — precisam formar **uma única** cadeia `raiz`. Duas raízes sem parentesco no mesmo `destino` é inconsistência: pare e relate, sem resolver nenhuma.

## Passo 5 — O detector de laço

Antes da tabela, para toda pendência com `raiz`:

> **Mesmo `gatilho` e mesma `clausula_central` da raiz → a raiz é reclassificada `decisao_humana`**, com `regra_aplicada: laco_detectado` e `nota: laco_detectado`, e a filha segue a raiz.

A `clausula_central` é derivada da evidência commitada, nunca escolhida:

| Gatilho | `clausula_central` |
|---|---|
| `orcamento_f5_esgotado` | os prefixos distintos dos achados `ALTA` da auditoria terminal, em ordem — `[item N]`, e `[item 2][fraco:<tipo>]` no item 2 —, separados por vírgula |
| `entrega_bloqueada` · `entrega_interrompida` | a `causa` |
| os demais | o identificador do item commitado que a evidência cita (`B-NN` do `00-BLOQUEIOS.md`, `PR-NN`, o artefato ausente) |

A sucessora que bloqueia pela mesma cláusula mostrou que trabalho novo não resolve aquilo: gerar outra seria girar em falso. **Nenhuma pendência gera sucessora indefinidamente.**

Independente disso, reclassifique para `decisao_humana` quando um ciclo inteiro terminar sem nenhuma pendência `resolvida` e sem nenhuma sucessora entregue (`nota: laco_detectado`).

"Ciclo inteiro sem conversão" é lido do `MAPA.md` e do `RECURSAO.md`, nunca da sessão:

- **Só vale do ciclo 2 em diante.** O ciclo 1 é o B4 original e não roda sucessora: nele nada poderia ter convertido, e o detector não se aplica.
- **As sucessoras que o ciclo `n` rodou** são as features `Origem: recursao` que integraram com a `**Pendência:**` do ciclo `n-1` que as criou, e as que bloquearam registrando, no commit do bloqueio, a filha do ciclo `n`. Sucessora do ciclo ainda `pendente` ou `em_andamento` quer dizer que o ciclo não terminou: pare e relate.
- **Converteu** se ao menos uma delas está `entregue` **e** a pendência dela está `resolvida`. `entregue` sem a pendência `resolvida` é o commit de estado incompleto: pare e relate. Sucessora que bloqueou de novo — pelo mesmo ramo ou não — não é conversão.
- **O ciclo é um só.** Se alguma sucessora do ciclo converteu, o detector não dispara para nenhuma pendência; a que não converteu segue a tabela, o detector de mesma cláusula e o teto.
- **O que dispara:** a pendência `aguardando_classificacao` que a tabela levaria a `trabalho_novo` é gravada `decisao_humana`, `regra_aplicada: laco_detectado/ciclo_sem_conversao`, `nota: laco_detectado`, e a raiz a acompanha. Nenhuma sucessora nasce. Pendência já em `decisao_humana`, `recurso_externo` ou `resolvida` não é tocada.
- **Precedência:** detector de mesma cláusula, depois a tabela; para `trabalho_novo`, o teto (passo 6), depois este detector — que dispara abaixo do teto, sem esperá-lo. Reaplicar tudo sobre o mesmo estado não muda nada.

## Passo 6 — O teto de ciclos

**Teto padrão: 3 ciclos**, declarado em `teto_ciclos` no frontmatter desde o primeiro.

O ciclo agora é:

```
B4  →  B5  →  features sucessoras novas  →  B4
```

— nunca "reabrir a F3 de uma branch antiga". O ciclo 1 é o B4 original; cada volta ao B4 com sucessoras incrementa `ciclo_atual`.

Atingido o teto (`ciclo_atual` == `teto_ciclos`), toda pendência que ainda seria resolvível pela máquina — `aguardando_classificacao` que a tabela levaria a `trabalho_novo` — é gravada `estado: decisao_humana`, `classe: decisao_humana`, `regra_aplicada: teto_de_ciclos_atingido`, `nota: teto_de_ciclos_atingido`. Nenhuma sucessora nova nasce. O buildx segue para o B6 com o que existe, e o relatório final declara tudo, sem eufemismo.

**Por que 3.** O ciclo 2 resolve o que o B3 recortou mal — é o mais produtivo. O ciclo 3 resolve o que o ciclo 2 criou. Do quarto em diante, o que sobra normalmente não é falta de trabalho, é falta de decisão.

## Passo 7 — `PR-NN` de feature que não integrou continuam reservados

Uma feature bloqueada pode ter um `BUILDX-PREMISSAS.md` com premissas que **nunca foram promovidas**. Os `PR-NN` delas não voltam para o estoque: reusá-los numa sucessora faria dois textos diferentes disputarem o mesmo id — um no artefato morto, outro no `PREMISSAS.md` — e a promoção idempotente pelo id passaria a mentir.

1. Ao registrar a pendência de uma feature que termina sem integrar, leia o `BUILDX-PREMISSAS.md` **commitado** dela (`git show feature/<slug>:docs/sprintx/features/<slug>/BUILDX-PREMISSAS.md`) e grave os ids em `pr_reservadas`.
2. Toda alocação de premissa nova feature-local considera ocupados: os `PR-NN` do `PREMISSAS.md`, **todos** os `pr_reservadas` do `RECURSAO.md`, e os que já existem no `BUILDX-PREMISSAS.md` daquela feature. O próximo número é o maior ocupado mais um.
3. **Nunca renumere artefato morto** e **nunca promova premissa de feature bloqueada**: a premissa global representa decisão incorporada ao produto integrado. A sucessora que precisar da mesma decisão a registra de novo, com `PR-NN` novo, e ela é promovida quando a sucessora integrar.

## Passo 8 — Devolver ao laço

Se sobrou pendência classificada `trabalho_novo` e o teto não foi atingido:

1. acrescente as sucessoras ao `MAPA.md`, na posição correta de dependência;
2. mova cada pendência para `em_resolucao`, com o `destino`;
3. incremente `ciclo_atual` e os contadores do frontmatter;
4. commite o estado (`chore(buildx): ciclo <n> da recursão`) e faça push normal — a árvore precisa estar limpa antes de a próxima feature começar;
5. volte ao B4.

Se não sobrou nada resolvível, ou o teto foi atingido: siga para o B6.

## Critério de saída do B5

- nenhuma pendência em `aguardando_classificacao`
- toda pendência classificada tem `classe`, `classificada_em` e `regra_aplicada`, e mora na seção do seu `estado`
- o `RECURSAO.md` tem exatamente as cinco seções do template, nenhuma a mais
- nenhuma classe `replanejamento` foi escrita
- toda `trabalho_novo` tem sucessora com slug novo, ou foi para `decisao_humana` pelo teto ou pelo detector
- toda raiz acompanha a filha, e todo `destino` `em_resolucao` existe no `MAPA.md`
- nenhuma feature `bloqueada` voltou a `pendente`
- toda pendência de feature que não integrou tem `pr_reservadas`, e nenhum desses ids foi reutilizado
- toda `decisao_humana` registra a decisão, as opções, o provisório e a reversibilidade; todo `recurso_externo` registra o que providenciar e o que destrava
- `RECURSAO.md` com frontmatter válido e os contadores certos

## Erros que esta etapa comete

- **Classificar `decisao_humana` como `trabalho_novo`.** É o erro caro: o buildx decide regra de negócio no lugar do usuário e constrói, com esmero, a coisa errada. Um `[item 7]` numa mistura é exatamente esse caso.
- **Classificar `trabalho_novo` como `decisao_humana`.** O erro preguiçoso: joga para o humano o que a máquina resolveria, e esvazia a promessa do modo autônomo.
- **Reabrir a feature velha.** Voltar a bloqueada para `pendente`, ou replanejá-la na branch antiga, é recomeçar do lado que já falhou — e a branch dela não integra mais.
- **Classificar por evidência do working tree.** Só o commitado é evidência.
- **Inventar seção.** A pendência que não cabe nas cinco é contrato faltando: pare e relate.
- **Ignorar o teto ou o detector por otimismo.** "Mais uma sucessora e sai" é como se gasta o orçamento inteiro sem entregar.
- **Reutilizar `PR-NN` de feature bloqueada.** O artefato morto continua citando aquele id.
- **Perder pendência que o portão reprovou.** Feature com `portao: bloqueado` não é feature entregue.
- **Tentar destravar reexecutando a entrega.** Rodar de novo o portão, o PR ou o pacote de QA não é recursão: é duplicar o ciclo que a F6 conduziu.
- **Deixar premissa provisória fora do relatório.** Ela é exatamente o que o humano precisa revisar.
