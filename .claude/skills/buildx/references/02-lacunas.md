# O catálogo de lacunas e os padrões da casa

Consultado no B1, passo 4. Este arquivo é a diferença entre "o buildx montou o que foi pedido" e "o buildx montou um sistema que não é irresponsável".

Duas partes:

- **Parte I — os padrões da casa.** O que o buildx assume quando o usuário não diz nada. Não é opinião: é a decisão já tomada, registrada uma vez aqui em vez de reinventada a cada projeto.
- **Parte II — o catálogo.** Os eixos não-funcionais a percorrer, com o padrão sensato de cada um.

Regra que governa as duas: **o buildx decide como o sistema se protege, não o que o sistema faz.** Requisito não-funcional é dele. Regra de negócio não declarada nunca vira premissa — vira pergunta no modo briefing, ou pendência `decisao_humana` no modo autônomo.

---

# Parte I — Os padrões da casa

Aplicados **sempre que o usuário não disser nada em contrário**, no modo autônomo e no briefing. Cada um vira premissa em `PREMISSAS.md` com `origem: catalogo_lacunas`, exatamente como as outras — o humano audita depois e vê o que foi assumido.

Se o usuário disser algo que contraria um padrão, **o usuário ganha, sempre.** O padrão é piso, não teto, e nunca discussão.

## P-1 — Arquitetura: três camadas

**Decisão:** apresentação, aplicação e dados separados, com fronteira explícita entre elas. A camada de apresentação nunca fala com o banco; a de dados nunca conhece HTTP.

**Por quê:** é o desenho que o `stackx` sabe verificar, que o `sprintx` sabe recortar em tasks e que sobrevive à troca de qualquer uma das três. Também é o que torna o teste funcional escrevível sem subir a interface.

**O que invalida:** o usuário pedir explicitamente outra arquitetura (hexagonal, event-driven, monolito sem camadas), ou o projeto ser uma ferramenta de linha de comando sem interface.

## P-2 — Stack: Next.js

**Decisão:** Next.js com TypeScript, App Router, React.

**Por quê:** cobre as três camadas num único projeto e num único deploy, o que reduz a superfície de coisa que pode dar errado numa execução autônoma. Padrão da casa.

**O que invalida:** o usuário pedir outra linguagem ou framework; o projeto não ter interface web; a casa já ter um repositório com stack decidida (aí o `stackx` detecta em vez de o buildx decidir).

## P-3 — Banco: SQLite local

**Decisão:** SQLite em arquivo, no repositório, com migrations versionadas.

**Por quê:** **dependência mínima é requisito de execução autônoma.** Um banco que exige serviço externo, credencial e rede é um ponto onde o laço do B4 trava esperando algo que o buildx não pode resolver sozinho. Com SQLite o projeto sobe, testa e roda numa máquina limpa sem nada instalado além do runtime.

O acesso ao banco fica atrás da camada de dados (P-1), de modo que trocar por Postgres depois seja uma feature, não uma reescrita.

**O que invalida:** o usuário pedir outro banco; o sistema precisar de escrita concorrente de múltiplos processos; volume declarado que o SQLite não atende; requisito de réplica ou alta disponibilidade.

## P-4 — Autenticação: JWT com usuário e senha

**Decisão:** autenticação própria por e-mail e senha, sessão por JWT, senha com hash forte (bcrypt ou argon2), token com expiração e refresh.

**Por quê:** não depende de provedor externo nem de credencial que o buildx não tem. Um sistema sem autenticação não é entregável, e esperar o usuário decidir o provedor é esperar uma pergunta que o modo autônomo proíbe.

**O que invalida:** o usuário pedir SSO, OAuth social, magic link ou provedor gerenciado; o sistema ser público sem área restrita.

## P-5 — Usuário de demonstração

**Decisão:** toda entrega traz um usuário de demonstração criado por seed, com credenciais documentadas no `RELATORIO.md`, e dados de exemplo suficientes para que todas as telas tenham o que mostrar.

**Por quê:** um sistema que sobe numa tela de login vazia, sem conta e sem dado, é indistinguível de um sistema quebrado. O usuário de demonstração é o que torna a entrega **verificável em trinta segundos** — e é o que o pacote de QA da mergex usa como ambiente.

Regra dura: a seed de demonstração **nunca roda em produção** e é claramente separada das migrations. Credencial de demonstração é fictícia e documentada; nunca é segredo real.

**O que invalida:** nada. Este padrão não tem exceção — se o sistema tem login, tem usuário de demonstração.

## P-6 — Design system: o do VS Code

**Decisão:** quando o usuário não indicar design system, a aplicação inteira adota o **design system do Visual Studio Code** — os tokens de cor dos temas Dark+ e Light+, a tipografia, o espaçamento, e a estrutura de layout (barra de atividade, barra lateral, área do editor, painel, barra de status).

Não é "inspirado em": são os tokens nomeados do VS Code, com os mesmos nomes, nos mesmos papéis, nas duas variantes.

**Por quê:** quatro razões, e a segunda é a que decide.

1. **É um design system completo e público**, com par claro/escuro coerente já resolvido — o problema mais caro de acertar à mão, e onde o acabamento improvisado costuma falhar.
2. **É um sistema de tokens semânticos, não uma paleta.** `--vscode-button-background` diz o papel, não a cor. Isso é o que permite trocar o tema inteiro sem tocar em componente — e é o que faz uma decisão de aparência tomada pela máquina permanecer revisável depois.
3. **É o ambiente em que o usuário desta casa trabalha o dia inteiro.** A aplicação entregue parece pertencer ao lugar de onde saiu.
4. **Tem estrutura de layout definida**, não só cores. Onde vai a navegação, onde vai o conteúdo, onde vai o estado — decidido, e não reinventado por feature.

**O que invalida:** o usuário indicar um design system (o da casa dele, Material, shadcn, Tailwind puro, uma marca existente), pedir outra identidade visual, ou o projeto não ter interface. Também não se aplica a site institucional ou página de marketing, onde a estética de ferramenta é a errada.

Detalhe completo — tokens das duas variantes, tipografia, espaçamento, layout e componentes: `references/08-design-system.md`.

## P-7 — Design: usar a skill de frontend design quando houver

**Decisão:** a parte visual e de UX é conduzida pela skill de **frontend design da Anthropic** quando ela estiver disponível — trabalhando **dentro** do design system do P-6, não escolhendo outro.

A divisão entre os dois padrões é clara: o P-6 fixa o vocabulário (tokens, tipografia, espaçamento, layout); o P-7 decide o que fazer com ele em cada tela — hierarquia, densidade, o que merece destaque, como o fluxo se organiza. Uma skill de design que escolhesse a própria paleta contrariaria o P-6, e é o P-6 que ganha.

Ordem de tentativa, no B2:

1. **Skill disponível na sessão** → use. É o caminho normal.
2. **Não disponível** → o buildx pode buscar a skill no GitHub oficial da Anthropic e instalá-la no projeto, em `.claude/skills/`, e usá-la a partir dali.
3. **Instalação falhou** (sem rede, repositório mudou, licença) → não é bloqueio. Siga com o P-6 aplicado à mão — os tokens e a estrutura de `references/08-design-system.md` bastam para uma interface consistente — e registre uma premissa dizendo que o acabamento saiu sem a skill.

Regras da instalação, sem exceção:

- instala **no projeto** (`.claude/skills/`), nunca no ambiente global do usuário
- registra a instalação como premissa em `PREMISSAS.md`, com a origem de onde veio
- nunca instala nada além dessa skill, e nunca de fonte que não seja o repositório oficial da Anthropic
- falha de rede é registrada e seguida, nunca uma tentativa em laço

**Por quê:** a competência de design mora numa skill feita para isso. O buildx aplicar regra visual à mão é reimplementar mal o que já existe pronto — o mesmo argumento que o faz não reimplementar o sprintx.

**O que invalida:** o projeto não ter interface; o usuário pedir para não instalar nada; a casa já ter um design system próprio declarado.

## P-8 — O projeto nasce com a suíte Expx instalada

**Decisão:** todo projeto criado pelo buildx já vem com o método Expx instalado e os dois harnesses configurados — Claude Code e OpenCode — antes da primeira feature.

Instalado por `npx expxdev init`, com a suíte completa: `sprintx`, `runx`, `mergex`, `stackx`, `memox`, `legadox`, `prodx` e o próprio `buildx`. Os comandos ficam com namespace no Claude Code (`/expx:sprintx-sprints`) e sem namespace no OpenCode (`/sprintx-sprints`).

O que fica no projeto, versionado:

| Caminho | Conteúdo |
|---|---|
| `.expx/expx-lock.json` | o lock da instalação — quem clonar recebe exatamente as mesmas skills |
| `.expx/marketplace/plugins/expx/` | o plugin local com as skills selecionadas |
| `.claude/` | harness do Claude Code: skills, comandos, hooks, `settings.json` |
| `.opencode/` | harness do OpenCode: comandos equivalentes, `opencode.json` |
| `AGENTS.md` | orientação do agente para o projeto, na raiz |
| `CLAUDE.md` | as convenções do projeto que o agente lê a cada sessão |

**Por quê:** três razões, e a terceira é a que fecha o argumento.

1. **O buildx precisa da suíte para trabalhar.** O B4 invoca sprintx e mergex feature a feature. Instalar depois seria construir o projeto com as ferramentas de fora dele.
2. **O projeto entregue continua vivo.** Quem receber o sistema vai corrigir defeito (`runx`), acrescentar feature (`sprintx`) e entregar (`mergex`) — com o método já configurado, não com um repositório cru que alguém precisa preparar.
3. **O `memox` só vale se estiver lá desde o primeiro commit.** Ele indexa o que as camadas gravam; instalado no mês seis, começa vazio e perde justamente o histórico da construção, que é quando mais se decidiu coisa.

**Regras da instalação:**

- roda no **B2, antes de qualquer código de negócio** — o projeto se instala antes de se construir
- o lock é **versionado**, nunca ignorado: é ele que garante que o time inteiro use as mesmas skills
- falha de rede na instalação **é bloqueio real do B2**, não pendência a seguir. Sem a suíte não há B4.
- se a suíte já estiver instalada no diretório (projeto retomado), **não reinstala**: verifica o lock e segue

**O que invalida:** o usuário pedir explicitamente um projeto sem o método instalado; o diretório já ser um projeto com Expx instalado e lock íntegro.

---

# Parte II — O catálogo

Percorrido item a item no B1. Para cada um, uma de três saídas: **pedido** (a descrição mencionou), **descoberto** (virou premissa), **descartado** (não se aplica, com o porquê registrado).

Nenhum item é pulado por parecer óbvio. A saída "descartado" é uma resposta legítima e o B6 a confere; a ausência do item não é.

## Segurança e acesso

| # | Eixo | Padrão sensato quando não declarado |
|---|---|---|
| L1 | Autenticação | P-4 |
| L2 | Autorização | papéis explícitos desde a primeira feature, mínimo `admin` e `usuario`; verificação no servidor, nunca só na interface |
| L3 | Senha | hash forte com sal, mínimo de tamanho, sem regra de complexidade teatral, sem expiração forçada |
| L4 | Sessão | expiração curta com refresh; logout invalida de fato; token nunca em `localStorage` quando cookie `httpOnly` resolver |
| L5 | Injeção e entrada | toda entrada validada no servidor por esquema; consulta parametrizada sempre |
| L6 | Segredo | variável de ambiente, `.env` fora do versionador, `.env.example` versionado. **Segredo real nunca entra em artefato nem em commit** |
| L7 | Transporte | HTTPS assumido em produção; cookie `secure` e `sameSite` |
| L8 | Rate limit | limite por IP e por conta nas rotas de autenticação, no mínimo |
| L9 | Dependência | versões fixadas; auditoria de vulnerabilidade no fluxo de verificação |

## Dado e conformidade

| # | Eixo | Padrão sensato quando não declarado |
|---|---|---|
| L10 | Dado pessoal | mapeado explicitamente: quais campos, por quê, por quanto tempo |
| L11 | LGPD | base legal declarada; exclusão de conta que apaga de fato; exportação dos dados do titular |
| L12 | Auditoria | trilha de quem fez o quê e quando nas ações que alteram dado de outro usuário ou permissão |
| L13 | Retenção | prazo declarado para log e para dado descartável; nada guardado para sempre por omissão |
| L14 | Backup | rotina declarada, e — o que quase todo projeto esquece — **um procedimento de restauração testado** |
| L15 | Migração de esquema | migrations versionadas, aplicáveis para frente, com caminho de reversão |

## Operação

| # | Eixo | Padrão sensato quando não declarado |
|---|---|---|
| L16 | Log | estruturado, com nível, sem dado pessoal e sem segredo no corpo |
| L17 | Erro | tratamento que não vaza rastro de pilha ao usuário; identificador de correlação para achar no log |
| L18 | Saúde | rota de verificação de saúde que checa banco e dependências |
| L19 | Observabilidade | mínimo: erro visível e log consultável. Métrica e rastreamento distribuído só se o porte pedir |
| L20 | Configuração | por ambiente, sem valor fixo no código; ausência de variável obrigatória falha no start, não em produção |
| L21 | Deploy | processo declarado e reprodutível; um comando sobe o projeto numa máquina limpa |

## Qualidade

| # | Eixo | Padrão sensato quando não declarado |
|---|---|---|
| L22 | Teste | TDD do sprintx: integração e funcional por task. Não é negociável nem no modo autônomo |
| L23 | Lint e formatação | configurados no B2, rodando na verificação |
| L24 | Verificação automatizada | pipeline que roda teste, lint e build a cada mudança |
| L25 | Semente de dados | P-5 |

## Interface

| # | Eixo | Padrão sensato quando não declarado |
|---|---|---|
| L26 | Acabamento visual | P-6: o design system do VS Code, tokens e estrutura |
| L27 | Tema | Dark+ e Light+ completos, preferência do sistema respeitada, alternância persistida na barra de status (P-6) |
| L28 | Responsividade | abaixo de 768px a barra lateral vira gaveta; alvos de toque a 44px (P-6) |
| L29 | Acessibilidade | contraste 4.5:1 nas duas variantes, foco visível com borda, rótulo em todo ícone sozinho |
| L30 | Estados da tela | vazio, carregando e erro tratados em toda tela que busca dado |
| L31 | Internacionalização | **descartado por padrão.** Um idioma, textos centralizados para facilitar depois. Só entra se o usuário indicar público fora de um idioma |

---

## Como registrar

Cada item que virar **descoberto** gera uma premissa em `PREMISSAS.md`:

```markdown
### PR-07 — Autorização por papéis

**Assunto:** L2 — autorização
**Decisão:** papéis `admin` e `usuario` desde a primeira feature, verificados no servidor.
**Por quê:** o sistema tem dado de mais de um usuário; sem papel, qualquer conta
alcança o dado de qualquer outra, e acrescentar papel depois exige revisar toda
rota já escrita.
**O que invalida:** se todo usuário tiver exatamente o mesmo acesso a exatamente
os mesmos dados, e isso for verdade de forma permanente.
**Origem:** catalogo_lacunas
**Etapa:** b1
```

O campo **o que invalida** é o que torna o arquivo auditável em vez de decorativo. Tem que ser um fato verificável — "se houver usuário fora do Brasil", "se o volume passar de mil requisições por minuto" — nunca uma generalidade como "se os requisitos mudarem".

## Erros que este catálogo evita, e os que ele comete

**Evita:** entregar um sistema sem autenticação; descobrir na validação que não há como restaurar um backup; construir onze features e só então perceber que nenhuma verifica permissão; entregar uma tela de login vazia sem conta para entrar.

**Comete, se aplicado sem juízo:** inchar um projeto pequeno com trilha de auditoria, métrica e rate limit que ninguém pediu. O antídoto é a **proporcionalidade** — a mesma regra do prodx. O catálogo é percorrido inteiro sempre; a profundidade de cada item é proporcional ao porte do sistema. Uma ferramenta interna de cinco usuários registra L12 como "descartado: trilha de auditoria desproporcional ao porte, sem dado de terceiro envolvido" — e isso é uma resposta correta, registrada, auditável.
