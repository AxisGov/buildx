<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/banner-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/banner-light.svg">
  <img alt="buildx — a camada de orquestracao do metodo Expx" src="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/banner-light.svg" width="100%">
</picture>

<p>
  <img alt="harness: Claude Code" src="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/badge-claude.svg">
  <img alt="harness: OpenCode" src="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/badge-opencode.svg">
  <img alt="camada: orquestracao" src="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/badge-camada.svg">
  <img alt="perguntas ao usuario: 1" src="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/badge-perguntas.svg">
  <img alt="merge: humano" src="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/badge-merge.svg">
  <img alt="design system: VS Code" src="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/badge-design.svg">
  <img alt="schema expx v1" src="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/badge-schema.svg">
  <img alt="docs pt-BR" src="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/badge-lang.svg">
  <img alt="licenca MIT" src="https://raw.githubusercontent.com/bittencourtthulio/buildx/main/.github/assets/badge-license.svg">
</p>

<p>
  <a href="https://bittencourtthulio.github.io/expxdev/"><strong>📘 Documentação do método</strong></a>
  &nbsp;·&nbsp;
  <a href="https://bittencourtthulio.github.io/expxdev/#ecossistema">O ecossistema</a>
  &nbsp;·&nbsp;
  <a href="https://bittencourtthulio.github.io/expxdev/#instalacao">Instalação</a>
  &nbsp;·&nbsp;
  <a href="https://bittencourtthulio.github.io/expxdev/#schema">Contratos</a>
</p>

<strong>A camada de orquestração do método Expx</strong> — uma descrição entra,<br>
um sistema sai, para <a href="https://claude.com/claude-code">Claude Code</a> e <a href="https://opencode.ai">OpenCode</a>.

</div>

```
/buildx "quero um sistema para gestão de contratos, com upload de PDF,
         alerta de vencimento e relatório mensal por cliente"
```

O buildx faz **uma única pergunta** — autônomo ou briefing — e depois conduz `prodx`, `stackx`, `sprintx` e `mergex` até o sistema estar construído, testado e validado. Nenhuma outra pergunta chega a você.

> **Ele não implementa nada, não planeja nada e não escreve teste nenhum.**
> Toda a competência mora nas camadas irmãs. A única coisa que o buildx faz e nenhuma outra faz é quebrar um projeto em features — o vão entre "quero um sistema de gestão de contratos" e "planejar a feature de upload de PDF".

---

## O ecossistema Expx

O método Expx é um conjunto de skills que se compõem, instaladas e mantidas pelo CLI [`expxdev`](https://github.com/bittencourtthulio/expxdev).

| Peça | Papel | Relação com o `buildx` |
|---|---|---|
| **[expxdev](https://github.com/bittencourtthulio/expxdev)** | o CLI: instala, atualiza e diagnostica o ecossistema | é quem instala esta skill (`npx expxdev init`) |
| **[prodx](https://github.com/bittencourtthulio/prodx)** | **camada** de produto: decide **se** há trabalho | abre o projeto no B1 (modo greenfield) e o valida no B6 — **obrigatório** |
| **[sprintx](https://github.com/bittencourtthulio/sprintx)** | **Build** — feature nova, F1…F6 | planeja e executa cada feature do mapa, no B4 — **obrigatório** |
| **[mergex](https://github.com/bittencourtthulio/mergex)** | entrega: branch, commit por task, PR e pacote de QA | **obrigatória**, e acionada pela F6 do `sprintx` — não pelo buildx: E0 no início, E1 a cada task, E2→E8 ao fechamento. O buildx lê o resultado e atualiza o mapa |
| **[stackx](https://github.com/bittencourtthulio/stackx)** | **camada** de convenções do repositório | grava o `CONVENCOES.md` no B2, invertido: decide em vez de detectar |
| **[memox](https://github.com/bittencourtthulio/MemoX)** | **camada** de memória do projeto | consultado no B5, para não repetir uma tentativa que já falhou |
| **[runx](https://github.com/bittencourtthulio/runx)** | **Run** — ocorrência em produção, E1…E5 | não participa: o buildx constrói, não corrige |
| **[legadox](https://github.com/bittencourtthulio/legadox)** | **camada** de segurança para código legado | não participa: projeto novo não tem legado |
| **buildx** *(este repositório)* | orquestra um projeto inteiro | — |

O buildx é a única peça do método que **depende** de outras: sem `prodx`, `sprintx` e `mergex` ele não roda, e diz o que falta. Não é falta de educação, é a arquitetura — rodar sem elas significaria reimplementar quatro skills mal, dentro de uma quinta.

Detalhes do ecossistema inteiro no [README do expxdev](https://github.com/bittencourtthulio/expxdev).

---

## O problema

O ecossistema Expx tem uma camada para cada etapa. O `prodx` decide se um pedido vale virar trabalho. O `sprintx` planeja e executa **uma** feature com rigor. A `mergex` entrega. O `stackx` formaliza as convenções. O `memox` lembra.

Falta a pergunta que nenhuma delas responde: **quais são as features?**

Entre "quero um sistema de gestão de contratos" e "planejar a feature de upload de PDF" existe um trabalho que ninguém fazia — recortar um sistema inteiro em fatias do tamanho que o sprintx sabe planejar, na ordem certa, sem esquecer o que ninguém pediu e todo sistema precisa ter.

É esse vão que o buildx preenche. Tudo mais ele delega.

## As seis etapas

```
B1 CONCEPÇÃO → B2 FUNDAÇÃO → B3 DECOMPOSIÇÃO → B4 CONSTRUÇÃO → B5 RECURSÃO → B6 VALIDAÇÃO
                                                      ↑                │
                                                      └────────────────┘
```

| | Etapa | O que acontece | Quem trabalha |
|---|---|---|---|
| **B1** | Concepção | mapeia o escopo e **varre o que você não pediu** — autenticação, LGPD, auditoria, backup, observabilidade. Cada lacuna vira premissa registrada | `prodx` |
| **B2** | Fundação | escolhe a stack, instala a suíte Expx, monta o esqueleto que instala, sobe e testa | `stackx` |
| **B3** | Decomposição | **quebra o projeto em features**, com ordem de dependência | só o buildx |
| **B4** | Construção | o laço: por feature, área de trabalho própria → plano → auditoria → execução TDD → entrega → **integração na árvore do projeto** | `sprintx`, `mergex` |
| **B5** | Recursão | classifica o que ficou pelo caminho e devolve ao laço o que a máquina resolve | buildx |
| **B6** | Validação | confere o construído contra o mapa, item a item, e relata | `prodx` |

## O que ele descobre que você não pediu

A varredura de lacunas é a razão de o buildx existir em vez de você falar direto com o sprintx. Trinta e um eixos, percorridos sempre:

**Segurança** — autenticação, autorização por papéis, hash de senha, sessão, validação de entrada, segredos, transporte, rate limit, dependências vulneráveis.

**Dado e conformidade** — mapeamento de dado pessoal, LGPD com exclusão e exportação reais, trilha de auditoria, retenção, backup **com restauração testada**, migrations reversíveis.

**Operação** — log estruturado sem dado pessoal, erro que não vaza rastro, rota de saúde, configuração que falha no start e não em produção, deploy reprodutível.

**Qualidade** — TDD, lint, pipeline, semente de dados.

**Interface** — o design system do VS Code nas duas variantes, responsividade, acessibilidade, estados de vazio, carregando e erro.

Cada uma tem três destinos possíveis: virou requisito, foi descartada com o porquê registrado, ou já estava no que você pediu. Nenhuma é pulada em silêncio — e o B6 confere a lista dos três.

## Tudo que foi decidido por você fica auditável

Cada decisão tomada em seu nome vira uma premissa com cinco campos, e o quinto é o que importa:

```
PR-07 — Autorização por papéis

Decisão:  papéis admin e usuario desde a primeira feature,
          verificados no servidor.
Por quê:  o sistema tem dado de mais de um usuário; sem papel,
          qualquer conta alcança o dado de qualquer outra.
O que
invalida: se todo usuário tiver exatamente o mesmo acesso aos
          mesmos dados, de forma permanente.
```

**Como revisar vinte e três decisões em cinco minutos:** leia só o campo *o que invalida*. Se aquilo é verdade no seu caso, a premissa merece atenção. Se não é, siga.

## Os padrões da casa

O que o buildx assume quando você não diz nada. Você sempre ganha do padrão.

| | |
|---|---|
| **Arquitetura** | três camadas, fronteira explícita |
| **Stack** | Next.js, TypeScript, App Router |
| **Banco** | SQLite local — dependência mínima é requisito de execução autônoma |
| **Autenticação** | própria, JWT, hash forte |
| **Demonstração** | usuário e dados de exemplo, sempre — um sistema que sobe numa tela de login vazia é indistinguível de um sistema quebrado |
| **Esqueleto** | painel inicial, cadastro de usuários em Configurações, perfil e troca de senha — **em toda entrega**, porque ninguém pede e todo sistema com login precisa |
| **Ponto de partida** | um **template real**, com código e 61 testes verdes, copiado para a raiz. O buildx não gera o esqueleto: ele parte de um que já passa no CI |
| **Visual** | o design system do **VS Code** — tokens Dark+ e Light+, tipografia do sistema, grade de 4px, e a estrutura de barra de atividade, barra lateral e barra de status |
| **Design** | a skill de frontend design da Anthropic, trabalhando dentro desses tokens |
| **Método** | o projeto **nasce com a suíte Expx instalada**, Claude Code e OpenCode configurados |

## A fronteira que ele não atravessa

**O buildx decide como o sistema se protege, não o que o sistema faz.**

Requisito não-funcional tem padrão defensável por classe de sistema — um sistema sem rate limit tem um defeito conhecido. Regra de negócio não tem padrão: ela é o negócio. Um sistema com a regra de cálculo errada **funciona e está errado**, que é o pior resultado possível, porque parece pronto e ninguém procura o defeito.

Regra de negócio que você não declarou nunca é chutada. Ela vira pendência, o buildx segue com a decisão mais reversível possível, e o relatório final **abre** com ela.

## E o merge é seu

Cada feature entregue entra numa branch de montagem, `buildx/<projeto_id>`, para que a seguinte nasça enxergando a anterior — e é essa árvore acumulada que vira **um único pull request** para a sua branch principal, com o pacote de teste manual de cada feature, executável por quem não programa. Os PRs por feature ficam no histórico, apontando para a branch de montagem, para quem quiser revisar em pedaços.

Ele não faz merge na sua principal, não oferece, não sugere que faria. Todas as outras coisas que ele faz sozinho são reversíveis: uma premissa errada se corrige, um plano ruim se replaneja, e a branch de montagem só recebe trabalho que já passou pelo portão. Merge na principal é onde o trabalho vira o sistema, e é a última rede antes de produção.

Um buildx que faz merge sozinho não é mais autônomo — é irreversível. São coisas diferentes.

## O que você lê no fim

```
1. O QUE VOCÊ PRECISA DECIDIR       as regras de negócio que não foram declaradas
2. O QUE VOCÊ PRECISA PROVIDENCIAR  credenciais, acessos, contas
3. O QUE FOI DECIDIDO POR VOCÊ      as premissas, com o que invalida cada uma
4. O QUE FICOU PRONTO               features entregues, com os PRs
5. O QUE NÃO FICOU                  pendências, com o porquê
6. COMO RODAR                       instalar, subir, entrar com o usuário demo
7. O QUE FAZER AGORA                revisar os PRs e fazer merge
```

A ordem é deliberada: **o que exige ação vem antes do que foi feito.** Um relatório que abre com onze features entregues e esconde na página três que a regra de cálculo foi chutada é desonesto na estrutura, mesmo dizendo tudo.

## Comandos

| Comando | Função |
|---|---|
| `/buildx <descrição>` | o comando único |
| `/buildx` | roteador: em que etapa o projeto está |
| `/buildx-mapa` | mostra ou regera a decomposição em features |
| `/buildx-retomar` | retoma um projeto interrompido, pelo estado em disco |
| `/buildx-status` | painel: features, ciclos, pendências, premissas |

## Instalação

```bash
npx expxdev init
```

Selecione `buildx` junto de `prodx`, `sprintx` e `mergex` — as três são obrigatórias. O `init` busca as skills nos repositórios oficiais, empacota as selecionadas como um plugin local e configura os dois harnesses: os comandos ficam com namespace no Claude Code (`/expx:buildx`) e sem namespace no OpenCode (`/buildx`).

O `stackx` e o `memox` são opcionais e degradam com aviso. O `legadox` não participa.

**A instalação é travada por lock.** Quem clonar o projeto recebe exatamente as mesmas skills que o time está usando, sem rede e sem rodar nada.

E há uma simetria que vale notar: todo projeto que o buildx cria **já nasce com a suíte instalada** (padrão P-8). Quem receber o sistema entregue corrige defeito com `runx`, acrescenta feature com `sprintx` e entrega com `mergex`, sem precisar preparar nada.

## Documentação

| Arquivo | Conteúdo |
|---|---|
| [`AGENTS.md`](AGENTS.md) | orientação do agente, e o mapa da skill |
| [`.claude/skills/buildx/SKILL.md`](.claude/skills/buildx/SKILL.md) | a skill: máquina de estados, contratos, as 12 regras |
| [`references/02-lacunas.md`](.claude/skills/buildx/references/02-lacunas.md) | os padrões da casa e o catálogo de 34 eixos |
| [`template/`](.claude/skills/buildx/template/) | o esqueleto real que todo projeto recebe — Next.js, SQLite, autenticação, o esqueleto de telas e a suíte |
| [`references/04-decomposicao.md`](.claude/skills/buildx/references/04-decomposicao.md) | como recortar um projeto em features |
| [`references/08-design-system.md`](.claude/skills/buildx/references/08-design-system.md) | o design system padrão: tokens do VS Code nas duas variantes |
| [`DECISOES-DA-SKILL.md`](.claude/skills/buildx/DECISOES-DA-SKILL.md) | as ambiguidades resolvidas, com o que as invalida |
| [`exemplos/`](exemplos/) | um projeto completo, do parágrafo ao relatório |

---

## Como contribuir

Abra uma issue descrevendo o caso concreto — a descrição que você passou, o que o buildx decidiu e o que deveria ter decidido — antes de abrir um PR grande.

Contribuição mais útil, em ordem:

1. **Lacuna que faltou no catálogo** — um requisito não-funcional que todo sistema daquele tipo precisa ter e que o `references/02-lacunas.md` não percorre. É o que torna a varredura do B1 melhor para todo mundo.
2. **Recorte errado no B3** — um projeto em que a decomposição em features produziu fatias que o sprintx não soube planejar. Traga o `MAPA.md` gerado: o recorte é a decisão mais difícil do método.
3. **Premissa que se mostrou errada na prática** — uma decisão do catálogo cujo `o_que_invalida` deveria ter disparado e não disparou.

A fronteira do D-05 não se flexibiliza sem um caso de uso que a justifique: **o buildx decide como o sistema se protege, não o que o sistema faz.** Um sistema com a regra de negócio chutada funciona e está errado, que é o pior resultado possível — parece pronto, e ninguém procura o defeito.

O mesmo vale para o merge (D-03). O buildx entrega PRs abertos e verdes; integrar é decisão humana, e essa é a última rede antes de produção.

---

<div align="center">
<sub>Parte do método <strong>Expx</strong> ·
<a href="https://github.com/bittencourtthulio/expxdev">expxdev</a> ·
<a href="https://github.com/bittencourtthulio/prodx">prodx</a> ·
buildx ·
<a href="https://github.com/bittencourtthulio/sprintx">sprintx</a> ·
<a href="https://github.com/bittencourtthulio/runx">runx</a> ·
<a href="https://github.com/bittencourtthulio/mergex">mergex</a> ·
<a href="https://github.com/bittencourtthulio/stackx">stackx</a> ·
<a href="https://github.com/bittencourtthulio/legadox">legadox</a> ·
<a href="https://github.com/bittencourtthulio/MemoX">memox</a></sub>
</div>
