# Integração — mergex

A mergex leva o trabalho implementado até o repositório e até o revisor humano. O buildx a invoca três vezes por feature, dentro do laço do B4 — e há uma quarta etapa que ele **nunca** invoca.

## Onde a mergex entra no laço

| Etapa | Quando | Quem aciona | O que faz |
|---|---|---|---|
| E0 abertura | início da F6 | **a própria sprintx**, não o buildx | adota a branch `feature/<slug>` que a F1 abriu e registra a entrega |
| E1 commit por task | a cada task que fecha | **a própria sprintx** | um commit por task |
| `mergex-check` (E2) | depois da F6 | buildx | portão de prontidão, dez verificações |
| `mergex-pr` (E4/E6/E7) | com o portão PRONTO | buildx | descrição, push, PR aberto |
| `mergex-qa` (E5) | depois do PR | buildx | pacote de teste manual |
| `mergex-revisar` | **nunca** | — | integrar código é decisão humana |

**O buildx não invoca `mergex-abrir`.** A área de trabalho da feature é da F1 do sprintx (worktree + branch `feature/<slug>`), e o E0 entra depois, por dentro da F6, para adotar e registrar o que já existe. Chamar `mergex-abrir` antes da F1 é o fluxo antigo: hoje ele tentaria abrir uma segunda área de trabalho para a mesma feature.

As três chamadas do buildx rodam **de dentro do worktree da feature** — é lá que estão os commits, o plano e `docs/entregas/<slug>/`.

Exceção estreita: se a versão do sprintx instalada não acionar o E0, a `mergex-check` acusa a falta do registro da entrega. Aí rode `/mergex-abrir` **de dentro do worktree**, onde o E0 adota a branch existente sem criar outra. Nunca antes da F1, e nunca para retomar uma feature.

`mergex-atencao` (E3) é opcional no modo autônomo: ela classifica o diff em faixas de atenção humana, e é útil no relatório final quando o projeto é grande. Rode se for barata.

## O merge é humano, e isso não é negociável

A própria mergex diz: *"integrar código é decisão humana"* — e o `mergex-revisar` é declarado ação manual, que não deve ser oferecida ao fim de um trabalho nem encadeada a partir de nenhum fluxo.

O buildx **respeita isso integralmente**. Não invoca, não oferece, não sugere que poderia. O relatório final termina dizendo que os PRs estão abertos, verdes e descritos, e que o merge é do usuário.

**Por que esta é a única fronteira que o modo autônomo não atravessa.** Todas as outras violações do buildx são reversíveis: uma premissa errada se corrige, um plano ruim se replaneja, uma feature mal recortada se refaz. Merge em branch principal é o ponto onde o trabalho vira o sistema — e é a última rede antes de produção.

Um buildx que faz merge sozinho não é mais autônomo: é irreversível. São coisas diferentes, e a segunda o usuário não pediu.

## O portão de prontidão no modo autônomo

As dez verificações da `mergex-check` são o que impede o laço do B4 de produzir onze PRs que parecem prontos.

Devolveu **BLOQUEADO**: o buildx **não força**. Marca a feature `bloqueada` no `MAPA.md` com o motivo que a mergex deu, registra a pendência, e segue para a próxima feature. O B5 classifica depois.

A tentação de seguir mesmo assim é maior no modo autônomo — não há ninguém olhando, e o PR "quase" passa. Ceder é o que transforma a promessa de "sistema pronto" numa pilha de PRs que ninguém consegue revisar.

Duas verificações merecem nota:

- **segredos no diff** — no modo autônomo é a última barreira antes de um segredo real ir para o repositório. Bloqueio absoluto, sem discussão, sem exceção.
- **arquivos fora do escopo** — pega feature que invadiu o território de outra, que costuma ser sintoma de recorte errado no B3. Vale como sinal para o B5.

## O pacote de QA

`mergex-qa` gera um documento executável por quem não programa. Vale a pena no modo autônomo, e por uma razão específica: **é a única forma de o usuário validar a entrega sem ler código.**

O usuário de demonstração (P-5) é o ambiente desse roteiro. Foi para isso que ele existe — o pacote de QA diz "entre com estas credenciais e faça isto", e funciona.

No pacote de QA da `FT-01`, o roteiro cobre o esqueleto de aplicação (P-9) inteiro: entrar, cair no painel, cadastrar um segundo usuário pela área de Configurações, entrar com ele, editar o próprio perfil e trocar a própria senha. É um roteiro que quem não programa executa sem ajuda, e é o que prova que o sistema é operável, não apenas demonstrável.

O relatório final aponta para os pacotes de QA de cada feature. É o caminho de quem quer conferir sem abrir o editor.

## O modo legado não se aplica

A `mergex-check` verifica modo legado entre as dez. Num projeto do buildx não há legado: todo código nasceu neste projeto. A verificação passa por vacuidade, e isso é correto — não a desative.

Se um projeto do buildx um dia acumular legado, o legadox entra normalmente, e aí o buildx já não é a camada em uso: o projeto virou manutenção, que é sprintx e runx.

## Comportamento sem mergex

O buildx **não roda**. A branch por feature continua existindo sem a mergex — quem a abre é a F1 do sprintx —, mas sem `mergex-check` não há portão, sem `mergex-pr` a entrega não chega a lugar nenhum, e sem o E1 nenhuma task vira commit: o laço do B4 produziria árvores cheias de trabalho não versionado.

Diga que falta e como instalar (`npx expxdev init`), e pare.
