# Integração — mergex

A mergex leva o trabalho implementado até o repositório e até o revisor humano. O buildx a invoca três vezes por feature, dentro do laço do B4; o E0 roda pelo sprintx, e há uma etapa que ninguém invoca.

## Onde a mergex entra no laço

| Etapa | Quando | O que faz |
|---|---|---|
| `mergex-abrir` (E0) | início da F6, **acionado pelo sprintx** — o buildx não invoca | adota a `feature/<slug>` que a F1 abriu; exige o `ORQUESTRADOR.md` da F4, então antes dela não abre nada |
| `mergex-check` (E2) | depois da F6 | portão de prontidão, dez verificações |
| `mergex-pr` (E4/E6/E7) | com o portão PRONTO | descrição, push, PR aberto — ou "PR não aberto", que não é entrega (abaixo) |
| `mergex-qa` (E5) | depois do PR | pacote de teste manual |
| `mergex-revisar` | **nunca** | integrar código é decisão humana |

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

## Quando o E7 não abre o PR

O E7 tem dois desfechos, e para a mergex os dois são sucesso. Sem `gh`/`glab`, sem autenticação ou com serviço sem ferramenta conhecida, ele empurra a branch, deixa o `PR.md` pronto e relata `mergex E7 — pull request não aberto automaticamente`, com o `Motivo:`; o `ENTREGA.md` fica com `pr_url: null` e `pr_estado: null`. Pela medição do `expx-fatiamento` (PR acima do limite ou não medido) ele também não abre, e o `pr_url` fica vazio do mesmo jeito.

Para o buildx, **sem PR não há entrega**. O critério é o `ENTREGA.md`: `pr_url` preenchido é PR aberto; `pr_url` vazio ou `null` é PR não aberto, qualquer que seja o motivo — nunca `entregue` no `MAPA.md`, por mais verde que esteja a suíte. A feature fica `bloqueada`, com o motivo literal do E7, e a pendência vai para o `RECURSAO.md`:

- **ferramenta ausente, não autenticada ou serviço não suportado** → `recurso_externo`. O que providenciar: abrir à mão o PR da branch para a base que o E7 indicou, colando o `PR.md`, ou instalar e autenticar a ferramenta e rodar o `mergex-pr` de novo. O que destrava: a feature passa a `entregue` quando o `ENTREGA.md` tiver `pr_url`. O buildx nunca roda `gh auth login` nem pede credencial;
- **PR acima do limite** → `decisao_humana`, nunca `replanejamento`: o B5 preserva o recorte da feature, e um plano novo dentro dele produziria o mesmo PR grande. O código já existe; dividir a branch em PRs empilhados ou declarar a exceção de movimento mecânico (que só o desenvolvedor declara) é do humano. O relatório leva as violações e a divisão que o E7 sugeriu, e a feature vale como sinal de recorte errado no B3;
- **PR não medido** → o B5 classifica pelo erro literal registrado.

Feature que depende dela segue a regra da predecessora não entregue (`references/05-construcao.md`, passo 1): fica `bloqueada`, e não se empilha sobre uma branch que nenhum PR mostra ao revisor.

## O pacote de QA

`mergex-qa` gera um documento executável por quem não programa. Vale a pena no modo autônomo, e por uma razão específica: **é a única forma de o usuário validar a entrega sem ler código.**

O usuário de demonstração (P-5) é o ambiente desse roteiro. Foi para isso que ele existe — o pacote de QA diz "entre com estas credenciais e faça isto", e funciona.

No pacote de QA da `FT-01`, o roteiro cobre o esqueleto de aplicação (P-9) inteiro: entrar, cair no painel, cadastrar um segundo usuário pela área de Configurações, entrar com ele, editar o próprio perfil e trocar a própria senha. É um roteiro que quem não programa executa sem ajuda, e é o que prova que o sistema é operável, não apenas demonstrável.

O relatório final aponta para os pacotes de QA de cada feature. É o caminho de quem quer conferir sem abrir o editor.

## O modo legado não se aplica

A `mergex-check` verifica modo legado entre as dez. Num projeto do buildx não há legado: todo código nasceu neste projeto. A verificação passa por vacuidade, e isso é correto — não a desative.

Se um projeto do buildx um dia acumular legado, o legadox entra normalmente, e aí o buildx já não é a camada em uso: o projeto virou manutenção, que é sprintx e runx.

## Comportamento sem mergex

O buildx **não roda**. Sem `mergex-check` não há portão, e sem `mergex-pr` a entrega não chega a lugar nenhum: o laço do B4 deixaria uma branch por feature (a F1 do sprintx as abre de qualquer jeito) que nunca vira PR.

Diga que falta e como instalar (`npx expxdev init`), e pare.
