<div align="center">

<strong>build^x</strong> — a camada de orquestração do método <a href="https://github.com/bittencourtthulio/expxdev">Expx</a><br>
uma descrição entra, um sistema sai.

</div>

```
/buildx "quero um sistema para gestão de contratos, com upload de PDF,
         alerta de vencimento e relatório mensal por cliente"
```

O buildx faz **uma única pergunta** — autônomo ou briefing — e depois conduz `prodx`, `stackx`, `sprintx` e `mergex` até o sistema estar construído, testado e validado. Nenhuma outra pergunta chega a você.

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
| **B4** | Construção | o laço: por feature, branch → plano → auditoria → execução TDD → PR | `sprintx`, `mergex` |
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
| **Visual** | o design system do **VS Code** — tokens Dark+ e Light+, tipografia do sistema, grade de 4px, e a estrutura de barra de atividade, barra lateral e barra de status |
| **Design** | a skill de frontend design da Anthropic, trabalhando dentro desses tokens |
| **Método** | o projeto **nasce com a suíte Expx instalada**, Claude Code e OpenCode configurados |

## A fronteira que ele não atravessa

**O buildx decide como o sistema se protege, não o que o sistema faz.**

Requisito não-funcional tem padrão defensável por classe de sistema — um sistema sem rate limit tem um defeito conhecido. Regra de negócio não tem padrão: ela é o negócio. Um sistema com a regra de cálculo errada **funciona e está errado**, que é o pior resultado possível, porque parece pronto e ninguém procura o defeito.

Regra de negócio que você não declarou nunca é chutada. Ela vira pendência, o buildx segue com a decisão mais reversível possível, e o relatório final **abre** com ela.

## E o merge é seu

O buildx entrega PRs abertos, verdes e descritos — com o pacote de teste manual de cada feature, executável por quem não programa.

Ele não faz merge, não oferece, não sugere que faria. Todas as outras coisas que ele faz sozinho são reversíveis: uma premissa errada se corrige, um plano ruim se replaneja. Merge é onde o trabalho vira o sistema, e é a última rede antes de produção.

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

O buildx **depende** de `prodx`, `sprintx` e `mergex` — sem elas não roda, e diz o que falta. O `stackx` e o `memox` são opcionais e degradam com aviso. O `legadox` não participa: projeto novo não tem legado.

## Documentação

| Arquivo | Conteúdo |
|---|---|
| [`AGENTS.md`](AGENTS.md) | orientação do agente, e o mapa da skill |
| [`.claude/skills/buildx/SKILL.md`](.claude/skills/buildx/SKILL.md) | a skill: máquina de estados, contratos, as 12 regras |
| [`references/02-lacunas.md`](.claude/skills/buildx/references/02-lacunas.md) | os padrões da casa e o catálogo de 31 eixos |
| [`references/04-decomposicao.md`](.claude/skills/buildx/references/04-decomposicao.md) | como recortar um projeto em features |
| [`DECISOES-DA-SKILL.md`](.claude/skills/buildx/DECISOES-DA-SKILL.md) | as ambiguidades resolvidas, com o que as invalida |
| [`exemplos/`](exemplos/) | um projeto completo, do parágrafo ao relatório |

---

<div align="center">
<sub>parte do método <strong>Expx</strong> · prodx · buildx · sprintx · runx · mergex · stackx · legadox · memox</sub>
</div>
