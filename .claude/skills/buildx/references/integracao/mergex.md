# Integração — mergex

A mergex leva o trabalho implementado até o repositório e até o revisor humano. **O buildx não a invoca.** Quem conduz a mergex é a **F6 do sprintx**, de dentro do worktree da feature; o buildx entra depois, para ler o que ela registrou.

## Quem aciona o quê

| Etapa | Quando | Quem aciona | O que faz |
|---|---|---|---|
| **E0** abertura | início da F6 | sprintx | adota a branch `feature/<slug>` e o worktree que a F1 abriu, e cria `docs/entregas/<slug>/ENTREGA.md` |
| **E1** commit por task | a cada task que fecha | sprintx | um commit por task, com os artefatos de método do trabalho junto |
| **E2 → E8** | depois do `FECHAMENTO.md`, ao fim da F6 | sprintx | portão de prontidão, classificação da atenção, descrição do PR, pacote de QA, push, abertura do PR e registro da entrega |
| **E9** `mergex-revisar` | **nunca** | — | integrar código é decisão humana |

O buildx **não aparece nesta tabela**, e isso é o contrato: ele orquestra a feature, não micro-orquestra a entrega dentro dela.

**O que o buildx não faz mais:** `mergex-abrir`, `mergex-check`, `mergex-pr` e `mergex-qa` não são chamados pelo buildx em nenhum ponto do caminho feliz. Eles correspondem a etapas que a F6 já conduziu — E0, E2, E4/E6/E7 e E5 —, e repeti-las depois significa dois donos para o mesmo ciclo: portão avaliado duas vezes sobre estados diferentes, ou um segundo PR para a mesma branch.

A `mergex-atencao` (E3) também não é chamada à parte: ela roda dentro da sequência E2 → E8 da F6.

## O que o buildx lê depois da F6

Dois artefatos, na árvore da feature. Só o que os contratos das duas skills declaram — nada inventado:

| Arquivo | Campos que decidem |
|---|---|
| `docs/entregas/<slug>/ENTREGA.md` (mergex, E8) | `estado` (`aberto` \| `entregue` \| `bloqueado`), `portao` (`pronto` \| `bloqueado` \| `null`), `pr_url`, `pr_estado`, `push_feito`, `desvios`, `entregue_em` |
| `docs/sprintx/features/<slug>/FECHAMENTO.md` (sprintx, fim da F6) | `fechado_em`, `resumo`, `risco_residual`, `testes_adicionados` |

Regra, no B4 (`references/05-construcao.md`, passo 6):

- `estado: entregue` com `portao: pronto` → feature `entregue` no `MAPA.md`;
- `portao: bloqueado` → feature `bloqueada`, com o motivo do portão;
- `ENTREGA.md` ausente, ou ainda `aberto` depois de a F6 devolver o controle → **incompatibilidade de versão da sprintx**: feature `bloqueada`, pendência registrada, e o laço segue.

**`pr_url: null` não é falha.** O contrato da mergex diz isso literalmente: sem a ferramenta do serviço, a descrição fica em `docs/entregas/<slug>/PR.md` e a entrega continua válida. Quem decide é o `portao`.

## Nunca complete o ciclo à mão

Se os artefatos não aparecerem, **não rode as etapas que faltaram**. Uma entrega conduzida pela metade por cada lado produz commit sem portão, PR sem pacote de QA, ou entrega registrada duas vezes — e nenhuma dessas falhas aparece até alguém abrir o repositório.

Falha explícita de versão é melhor que execução dupla: registre a incompatibilidade, bloqueie a feature, siga. O B5 classifica depois.

## O merge é humano, e isso não é negociável

A própria mergex diz: *"integrar código é decisão humana"* — e o `mergex-revisar` é declarado ação manual, que não deve ser oferecida ao fim de um trabalho nem encadeada a partir de nenhum fluxo.

O buildx **respeita isso integralmente**. Não invoca, não oferece, não sugere que poderia. O relatório final termina dizendo que as entregas estão prontas e descritas, e que o merge é do usuário.

**Por que esta é a única fronteira que o modo autônomo não atravessa.** Todas as outras violações do buildx são reversíveis: uma premissa errada se corrige, um plano ruim se replaneja, uma feature mal recortada se refaz. Merge em branch principal é o ponto onde o trabalho vira o sistema — e é a última rede antes de produção.

Um buildx que faz merge sozinho não é mais autônomo: é irreversível. São coisas diferentes, e a segunda o usuário não pediu.

## O portão de prontidão no modo autônomo

As dez verificações do E2 são o que impede o laço do B4 de produzir onze entregas que parecem prontas. Elas rodam dentro da F6, e o buildx lê o veredito em `portao`.

Devolveu **bloqueado**: o buildx **não força e não repete**. Marca a feature `bloqueada` no `MAPA.md` com o motivo registrado, anota a pendência, e segue para a próxima feature. O B5 classifica depois.

A tentação de "só rodar o check de novo" é maior no modo autônomo — não há ninguém olhando, e o portão "quase" passa. Ceder é o que transforma a promessa de "sistema pronto" numa pilha de entregas que ninguém consegue revisar.

Duas verificações merecem nota:

- **segredos no diff** — no modo autônomo é a última barreira antes de um segredo real ir para o repositório. Bloqueio absoluto, sem discussão, sem exceção.
- **arquivos fora do escopo** — pega feature que invadiu o território de outra, que costuma ser sintoma de recorte errado no B3. Vale como sinal para o B5, e aparece em `desvios`.

## O pacote de QA

O E5 gera um documento executável por quem não programa, dentro da F6. Vale a pena no modo autônomo por uma razão específica: **é a única forma de o usuário validar a entrega sem ler código.**

O usuário de demonstração (P-5) é o ambiente desse roteiro. Foi para isso que ele existe — o pacote de QA diz "entre com estas credenciais e faça isto", e funciona.

No pacote de QA da `FT-01`, o roteiro cobre o esqueleto de aplicação (P-9) inteiro: entrar, cair no painel, cadastrar um segundo usuário pela área de Configurações, entrar com ele, editar o próprio perfil e trocar a própria senha. É um roteiro que quem não programa executa sem ajuda, e é o que prova que o sistema é operável, não apenas demonstrável.

O relatório final aponta para os pacotes de QA de cada feature — que vivem na árvore daquela feature, em `docs/entregas/<slug>/QA-PACOTE.md`. É o caminho de quem quer conferir sem abrir o editor.

## O modo legado não se aplica

O E2 verifica modo legado entre as dez. Num projeto do buildx não há legado: todo código nasceu neste projeto. A verificação passa por vacuidade, e isso é correto — não a desative.

Se um projeto do buildx um dia acumular legado, o legadox entra normalmente, e aí o buildx já não é a camada em uso: o projeto virou manutenção, que é sprintx e runx.

## Comportamento sem mergex

O buildx **não roda**. A branch por feature continua existindo sem ela — quem a abre é a F1 do sprintx —, mas sem o E1 nenhuma task vira commit, sem o E2 não há portão, e sem E4→E7 a entrega não chega a lugar nenhum: o laço do B4 produziria árvores cheias de trabalho não versionado.

Diga que falta e como instalar (`npx expxdev init`), e pare.
