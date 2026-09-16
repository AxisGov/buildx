# B5 — Recursão

Varrer tudo que ficou pelo caminho no B4, classificar cada pendência, e devolver ao laço o que a máquina ainda consegue resolver.

Entrada: `MAPA.md`, os `00-BLOQUEIOS.md` de todas as features, os achados da F5 e o portão que a mergex registrou no `ENTREGA.md` de cada feature. Saída: `docs/projeto/RECURSAO.md` atualizado no checkout de controle, e possivelmente features novas no `MAPA.md`.

**Feature integrada já está aqui.** O que entrou em `buildx/<projeto_id>` pelo fast-forward veio inteiro — código e artefatos —, então o `00-BLOQUEIOS.md`, o `00-AUDITORIA.md` e o `FECHAMENTO.md` de cada feature entregue são lidos direto no checkout de controle.

**Feature bloqueada, não.** Ela nunca foi integrada: os artefatos dela existem só na árvore e na branch dela. Localize com `git worktree list --porcelain`; sem worktree, leia da branch sem trocar de árvore (`git show feature/<slug>:docs/sprintx/features/<slug>/00-BLOQUEIOS.md`).

**Artefato que não aparece no checkout de controle não é artefato inexistente** — quando a feature não foi integrada, ele está noutro lugar. Concluir "a feature não registrou bloqueio" porque o arquivo não está aqui é o erro que faz o B5 fechar um ciclo cego.

O B5 é o que separa "rodou até o fim" de "entregou". Sem ele o buildx produziria um repositório com nove features prontas e três bloqueadas, e chamaria isso de terminado.

## Passo 1 — A varredura

Colete de todas as fontes, sem filtrar nada ainda:

| Fonte | O que colher |
|---|---|
| `MAPA.md` | toda feature `bloqueada`, com o motivo |
| `docs/sprintx/features/<slug>/00-BLOQUEIOS.md` | toda dúvida que a F6 registrou e pulou — **no worktree/branch daquela feature** |
| `docs/sprintx/features/<slug>/00-AUDITORIA.md` | todo achado alto que mandou voltar à F3 — idem |
| `docs/entregas/<slug>/ENTREGA.md` | `portao: bloqueado` e o que ele apontou, mais os `desvios`. Feature integrada: aqui mesmo. Feature bloqueada: **commitado na branch dela** (`git show feature/<slug>:…`), porque o E8 persiste o bloqueio |
| `PREMISSAS.md` | toda premissa marcada provisória |
| `RECURSAO.md` do ciclo anterior | toda pendência que continua aberta |

Consulte o `memox`, se instalado: uma pendência que já apareceu em ciclo anterior e voltou não é a mesma pendência — é sinal de que a tentativa anterior não resolveu, e repetir a mesma correção vai falhar igual.

## Passo 2 — A classificação

Cada pendência recebe exatamente uma classe. É a classificação que decide o destino, e ela é a única decisão real do B5.

### `trabalho_novo` — vira feature

A pendência descreve algo que ninguém construiu e que a máquina sabe construir.

Exemplos: a exclusão de conta pela LGPD não coube em nenhuma feature; a rota de saúde ficou de fora; uma tela não tratou o estado de erro.

**Destino:** feature nova no `MAPA.md`, com `origem: recursao`, e volta ao B4 — nascendo do `HEAD` atual de `buildx/<projeto_id>`, como qualquer outra.

### `replanejamento` — e por que ele quase nunca chega aqui

Replanejar uma feature é trabalho do **B4**, na triagem imediata, no momento em que ela falha: ali a árvore ainda está em `BASE_SHA`, a branch daquela feature ainda descende dela, e voltar à F3 no mesmo worktree é seguro (`references/05-construcao.md`, "a triagem imediata"). Teto de dois replanejamentos, como sempre.

**No B5, esse caminho já se fechou.** Quando o laço chega aqui, `buildx/<projeto_id>` avançou com as features seguintes, e a branch antiga não descende mais da árvore atual — um fast-forward depois seria impossível. Por isso:

**Uma pendência que só se resolve com trabalho novo vira feature nova**, com `origem: recursao`, slug novo, branch nova e worktree novo, nascendo do `HEAD` atual de `buildx/<projeto_id>`. Não é burocracia: é o que garante que o trabalho novo enxergue tudo que foi entregue desde então.

**Nunca reabra uma branch antiga para forçá-la na árvore.** Sem `rebase`, sem `cherry-pick`, sem `merge --no-ff`, sem `--force`. A branch antiga continua existindo com o PR dela; o que continua a partir daqui é uma feature nova.

### `decisao_humana` — fica para o relatório

A pendência exige alguém decidir algo que o buildx não pode decidir: regra de negócio não declarada, escolha com consequência comercial, premissa provisória que precisa de confirmação, conflito entre o que o usuário pediu e o que a premissa assumiu.

**Destino:** `RECURSAO.md`, e daí para o relatório final. **Nunca vira feature**, nunca é resolvida por chute.

Cada uma registra: qual é a decisão, quais são as opções, o que o buildx fez provisoriamente enquanto isso, e o que muda em cada opção.

### `recurso_externo` — fica para o relatório

Falta algo que não está na máquina: credencial de um serviço, acesso a um sistema, chave de API, domínio, conta em nuvem.

**Destino:** `RECURSAO.md` e relatório final, com **o que exatamente é preciso providenciar** e o que passa a funcionar quando providenciado.

O buildx nunca inventa credencial, nunca põe valor de exemplo em lugar de segredo, e nunca marca como pronto o que depende de algo que não tem.

## Passo 3 — O teto de ciclos

O ciclo B4 → B5 repete enquanto houver pendência `trabalho_novo` ou `replanejamento`. Sem teto, isso é um laço infinito com custo real.

**Teto padrão: 3 ciclos.** Declarado no frontmatter do `RECURSAO.md` desde o primeiro.

O ciclo 1 é o B4 original. Cada retorno ao B4 incrementa. Atingido o teto:

- toda pendência ainda aberta é reclassificada como `decisao_humana`, com a nota de que atingiu o teto
- o buildx segue para o B6 com o que existe
- o relatório final declara tudo, sem eufemismo

**Por que 3.** O ciclo 2 resolve o que o B3 recortou mal — é o mais produtivo. O ciclo 3 resolve o que o ciclo 2 criou. Do quarto em diante, o que sobra normalmente não é falta de trabalho, é falta de decisão: continuar gasta muito e resolve pouco.

### O detector de laço em falso

Independente do teto, pare uma linha de trabalho quando:

- a mesma pendência, com a mesma descrição, aparece em **dois ciclos seguidos**
- uma feature entra em `bloqueada` **duas vezes** pelo mesmo motivo
- o ciclo inteiro não converteu nenhuma pendência em entrega

Nos três casos, reclassifique para `decisao_humana` imediatamente, sem esperar o teto. Repetir o que não funcionou é a forma mais cara de não resolver nada.

## Passo 4 — Devolver ao laço

Se sobrou pendência `trabalho_novo` ou `replanejamento` e o teto não foi atingido:

1. acrescente as features novas ao `MAPA.md`, na posição correta de dependência — feature de recursão respeita a ordenação do B3 como qualquer outra
2. incremente `ciclo_atual` no `RECURSAO.md`
3. commite o estado (`chore(buildx): ciclo <n> da recursão`) e faça push normal — a árvore precisa estar limpa antes de a próxima feature começar
4. volte ao B4

Features que ficaram `bloqueada` **não voltam a `pendente`**: o que volta ao laço é feature nova. A branch e o worktree da bloqueada permanecem como estão, para o relatório final apontar.

Se não sobrou nada resolvível, ou o teto foi atingido: siga para o B6.

## Critério de saída do B5

- toda pendência coletada tem exatamente uma classe
- nenhuma pendência `trabalho_novo` ou `replanejamento` continua aberta, ou o teto foi atingido
- toda `decisao_humana` registra: a decisão, as opções, o provisório adotado, o efeito de cada opção
- todo `recurso_externo` registra o que providenciar e o que destrava
- `RECURSAO.md` com frontmatter válido e os contadores certos

## Erros que esta etapa comete

- **Classificar `decisao_humana` como `trabalho_novo`.** É o erro caro: o buildx decide regra de negócio no lugar do usuário e constrói, com esmero, a coisa errada.
- **Classificar `trabalho_novo` como `decisao_humana`.** O erro preguiçoso: joga para o humano o que a máquina resolveria, e esvazia a promessa do modo autônomo.
- **Ignorar o teto por otimismo.** "Mais um ciclo e sai" é como se gasta o orçamento inteiro sem entregar.
- **Perder pendência que o portão reprovou.** A verificação bloqueada é pendência como qualquer outra; feature com `portao: bloqueado` não é feature entregue.
- **Tentar destravar reexecutando a entrega.** Rodar de novo o portão, o PR ou o pacote de QA não é recursão: é duplicar o ciclo que a F6 conduziu. O que volta ao B4 é a feature, pela porta da F3 ou como feature nova.
- **Deixar premissa provisória fora do relatório.** Ela é exatamente o que o humano precisa revisar, e é a mais fácil de esquecer porque não quebrou nada.
