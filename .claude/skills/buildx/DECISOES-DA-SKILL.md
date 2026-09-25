# Decisões da skill buildx

Decisões tomadas na ausência de informação, com a alternativa descartada e o que as invalidaria. Registrar aqui é o mesmo movimento que o `PREMISSAS.md` faz num projeto: quem revisar depois lê o que derrubaria a decisão e só pensa nas que se aplicam.

---

## D-01 — O buildx é camada nova, não um modo do prodx

**Decisão:** skill própria, acima de todas, dona do laço e da recursão.

**Alternativa descartada:** um `/prodx-projeto` que montasse o mapa e chamasse o sprintx, deixando a cadeia se encadear sozinha.

**Por quê:** o encadeamento entre skills irmãs não tem dono. Ninguém contaria ciclos de recursão, ninguém decidiria o que fazer com uma feature bloqueada, ninguém validaria no fim. O laço B4 → B5 precisa de alguém que o segure, e nenhuma camada existente tem esse papel — todas são especialistas em uma etapa.

**O que invalida:** se as camadas ganharem um protocolo de encadeamento com estado próprio, o buildx vira um roteador fino sobre ele.

---

## D-02 — A pergunta única, e só ela

**Decisão:** exatamente uma pergunta, sempre a primeira: autônomo ou briefing. No modo autônomo, nenhuma outra chega ao usuário, de nenhuma camada.

**Alternativa descartada:** perguntar nos pontos de decisão importantes — stack, autenticação, modelo de dados.

**Por quê:** pedido explícito do usuário, e o desenho inteiro depende disso. Uma execução que interrompe cinco vezes não é "fechar os olhos": é uma conversa com pausas longas, que é pior do que uma conversa. A escolha real não é entre perguntar e não perguntar — é entre **perguntar e registrar premissa auditável**. A segunda entrega o mesmo controle, deslocado para depois.

**O que invalida:** se as premissas se mostrarem sistematicamente erradas na revisão dos primeiros projetos, o custo de decidir sem perguntar passa a superar o de interromper.

---

## D-03 — Merge continua humano

**Decisão:** o buildx nunca invoca `mergex-revisar`, nunca oferece, nunca sugere.

**Alternativa descartada:** fechar o ciclo até o merge, entregando `main` com tudo integrado.

**Por quê:** todas as outras violações do buildx são reversíveis — premissa errada se corrige, plano ruim se replaneja, feature mal recortada se refaz. Merge é onde o trabalho vira o sistema. Um buildx que faz merge sozinho não é mais autônomo: é irreversível, e o usuário pediu a primeira coisa.

A própria mergex já declara `mergex-revisar` ação manual que não deve ser encadeada a partir de nenhum fluxo. Respeitar isso custa um clique e compra a última rede.

**O que invalida:** o usuário pedir explicitamente, e mesmo aí valeria só com proteção de branch e verificação obrigatória configuradas.

---

## D-04 — O teto de recursão é 3

**Decisão:** o ciclo B4 → B5 repete no máximo três vezes.

**Alternativa descartada:** repetir enquanto houver pendência resolvível.

**Por quê:** o ciclo 2 resolve o que o B3 recortou mal — é o mais produtivo. O ciclo 3 resolve o que o 2 criou. Do quarto em diante, o que sobra normalmente não é falta de trabalho, é falta de decisão, e continuar gasta muito para resolver pouco.

O número é arbitrário dentro de uma faixa defensável (2 a 4) e está no frontmatter do `RECURSAO.md` justamente para ser ajustado com evidência.

**O que invalida:** dados dos primeiros projetos mostrando que o ciclo 4 ainda converte pendência em entrega.

---

## D-05 — O buildx decide requisito não-funcional, nunca regra de negócio

**Decisão:** a varredura de lacunas decide como o sistema se protege. O que o sistema faz, se não foi declarado, vira pendência `decisao_humana`.

**Alternativa descartada:** decidir também a regra de negócio pelo padrão mais comum do domínio.

**Por quê:** um sistema sem rate limit é um sistema com um defeito conhecido. Um sistema com a regra de cálculo errada é um sistema que **funciona e está errado** — o pior resultado possível, porque parece pronto e ninguém procura o defeito.

Requisito não-funcional tem padrão defensável por classe de sistema. Regra de negócio não tem: ela é o negócio.

**O que invalida:** nada que eu consiga imaginar. Esta é a fronteira que sustenta a confiança no modo autônomo.

---

## D-06 — Um `MAPA.md`, não uma pasta por feature no buildx

**Decisão:** todas as features num arquivo só, `docs/projeto/MAPA.md`. O detalhe mora em `docs/<slug>/`, do sprintx.

**Alternativa descartada:** uma pasta por feature no espaço do buildx, espelhando o prodx.

**Por quê:** o que o buildx precisa saber de uma feature cabe em oito campos. O detalhe já tem dono e já tem lugar. Duplicar criaria duas fontes que divergem no primeiro replanejamento.

**O que invalida:** se o contrato da feature crescer além de uns quinze campos, o arquivo único fica ilegível.

---

## D-07 — A F2 é respondida em quatro degraus, nunca por invenção

**Decisão:** `PROJETO.md` → `PREMISSAS.md` → `CONVENCOES.md` → criar premissa nova e responder com ela.

**Alternativa descartada:** responder com julgamento direto, registrando depois.

**Por quê:** "registrar depois" é registrar às vezes. Forçar a premissa a existir **antes** da resposta é o que garante que toda decisão da F2 autônoma esteja auditável — e o `00-DECISOES.md` cita a fonte de cada uma, então uma resposta sem premissa correspondente fica visível.

**O que invalida:** nada. Este é o mecanismo que torna a violação da regra 10 do sprintx aceitável em vez de arbitrária.

---

## D-08 — Os padrões da casa moram no catálogo, não no SKILL.md

**Decisão:** Next.js, SQLite, JWT, usuário demo, tema claro/escuro, azul, skill de frontend design e suíte Expx instalada ficam em `references/02-lacunas.md`, Parte I.

**Alternativa descartada:** no `SKILL.md`, que é lido sempre.

**Por quê:** o `SKILL.md` diz *como o método funciona*; o catálogo diz *o que esta casa assume*. A distinção importa porque os padrões vão mudar — outra casa, outro projeto, outra stack — e o método não. Um arquivo que muda com frequência não pertence ao documento que define a estrutura.

**O que invalida:** se os padrões passarem a variar por projeto, viram configuração, não reference.

---

## D-09 — SQLite como padrão, e o argumento é a execução autônoma

**Decisão:** SQLite em arquivo, atrás da camada de dados.

**Alternativa descartada:** Postgres, que é o que a maioria dos projetos acaba usando.

**Por quê:** o argumento não é técnico, é de modo de operação. Um banco que exige serviço, credencial e rede é um ponto onde o laço do B4 trava esperando algo que o buildx não pode resolver sozinho — e no modo autônomo travar é caro, porque ninguém está olhando.

A camada de dados (P-1) existe em parte para tornar a troca por Postgres uma feature, não uma reescrita.

**O que invalida:** escrita concorrente de múltiplos processos, volume declarado que o SQLite não atende, requisito de réplica.

---

## D-10 — A suíte Expx é instalada no B2, antes do código

**Decisão:** `npx expxdev init` roda antes da primeira linha de negócio, e falhar ali é bloqueio real.

**Alternativa descartada:** instalar no fim, como acabamento da entrega.

**Por quê:** três razões, e a terceira decide. O B4 precisa de sprintx e mergex para existir. O projeto entregue continua vivo e quem o receber vai usar o método. E o `memox` só vale se estiver lá desde o primeiro commit — instalado no mês seis, começa vazio e perde justamente o histórico da construção, que é quando mais se decidiu coisa.

**O que invalida:** o usuário pedir um projeto sem o método instalado.

---

## D-11 — `expx_tool: buildx` e um segundo nível de estado no contrato

**Decisão:** o buildx grava `expx_tool: buildx`, com estágios próprios (`b1`..`b6`) e seis kinds que usam `projeto_id` em vez de `trabalho_id`. Contrato e parser foram estendidos para conhecê-los.

**Alternativa descartada:** reusar `sprintx` e `trabalho_id`, para não tocar no contrato.

**Por quê:** reusar mentiria sobre a origem do artefato e apagaria a relação que o buildx existe para manter — um projeto tem N trabalhos, e tratar os dois níveis como a mesma chave perde exatamente isso.

Havia uma suposição errada no caminho, que vale registrar: eu supus que kind desconhecido viraria violação visível (R6) e que a extensão do contrato podia esperar. Não é o caso — `rejeicao.ts` **rejeita** kind desconhecido, e o arquivo não é lido. Sem os seis kinds registrados, todo artefato de projeto seria descartado em silêncio pelo painel.

`estagioCoerenteCom` também precisou mudar de ternário para mapa explícito: com três ferramentas, `tool === "sprintx" ? ... : ...` mandaria a buildx para os estágios da runx e acusaria estágio incoerente num arquivo correto.

**O que invalida:** nada. Está feito e coberto por teste.

---

## D-13 — O `veredito` da validação tem três valores, não dois

**Decisão:** enum próprio `VereditoBuildx` — `aprovado`, `aprovado_com_pendencia`, `reprovado` — em vez do `Veredito` de dois valores que o contrato já tinha.

**Alternativa descartada:** reusar o enum existente e registrar a pendência em prosa no corpo do arquivo.

**Por quê:** a diferença entre entrega íntegra e entrega com pendência declarada é exatamente o que o relatório final existe para mostrar, e o painel precisa distingui-las sem ler prosa. Um enum de dois valores forçaria a escolha entre marcar `aprovado` (mentira por omissão) ou `reprovado` (que faria o usuário descartar uma entrega utilizável).

**O que invalida:** se o painel passar a ler o `RECURSAO.md` junto, o terceiro valor vira redundante.

---

## D-14 — A buildx entra no catálogo do `init` como skill, não como camada

**Decisão:** `camada: false` no `CATALOGO`, ao lado de sprintx, runx e mergex.

**Alternativa descartada:** `camada: true`, junto de legadox, stackx, memox e prodx.

**Por quê:** camada, no vocabulário do CLI, é skill que *modifica o comportamento* da sprintx ou da runx e sozinha não faz nada. O buildx não modifica nenhuma delas — ele as **invoca**. É um nível acima, não um modificador.

O efeito colateral é que o `init` não avisa que o buildx precisa de sprintx e mergex para rodar. Criar o conceito de dependência entre skills por causa de uma única aresta custaria mais do que a skill avisar em tempo de execução, que é o que ela já faz.

**O que invalida:** se outra skill do ecossistema passar a ter dependência dura, aí vale modelar de verdade.

---

## D-12 — Só o stackx é opcional

**Decisão:** sem prodx, sprintx ou mergex o buildx para e diz como instalar. Sem stackx, degrada e segue. Sem memox, segue. O legadox não participa.

**Alternativa descartada:** implementar um caminho degradado para cada ausência.

**Por quê:** o buildx é 90% orquestração. Rodar sem sprintx significaria reimplementar planejamento, TDD e execução — quatro skills mal, dentro de uma quinta. A dependência dura é a arquitetura, não uma falta de educação.

O stackx é diferente: o que ele faz no B2 é gravar um arquivo que o buildx já decidiu. Perde-se a revisão automática da primeira feature, que é real mas não é estrutural.

**O que invalida:** nada para as três duras. Para o stackx, se a revisão da primeira feature se mostrar decisiva na prática.

---

## D-15 — O design system padrão é o do VS Code

**Decisão:** sem indicação do usuário, a aplicação adota os tokens, a tipografia, o espaçamento e a estrutura de layout do VS Code — Dark+ e Light+, com os nomes semânticos preservados.

**Alternativa descartada:** "SaaS moderno, tema claro e escuro, destaque azul", que era o P-6 original.

**Por quê:** o P-6 original não era um design system — era um adjetivo. "SaaS moderno" não diz qual cinza, qual altura de linha, onde vai a navegação, e por isso produziria uma aplicação diferente a cada projeto e, pior, incoerente entre features do mesmo projeto: a `FT-03` escolheria um cinza, a `FT-07` outro, e ninguém notaria até o B6.

O VS Code resolve exatamente o que é caro decidir sozinho: um par claro/escuro coerente, tokens semânticos em vez de paleta (`button-background`, não `#0078d4`), e uma estrutura de layout definida. E é o ambiente em que esta casa trabalha — a aplicação entregue parece pertencer ao lugar de onde saiu.

O ganho concreto para o modo autônomo: uma regra verificável no `CONVENCOES.md` — *nenhuma cor literal em componente* — que o `stackx-check` cobra sozinho. "Faça bonito" não é verificável; "todo valor de cor vem de um token" é.

**O que invalida:** o usuário indicar um design system; o projeto ser site institucional, página de marketing ou produto de consumo, onde a estética de ferramenta é a errada.

---

## D-16 — Os tokens ficam no reference, não no SKILL.md

**Decisão:** `references/08-design-system.md` carrega os tokens completos das duas variantes, e o `SKILL.md` só aponta.

**Alternativa descartada:** um resumo do design system no `SKILL.md`, que é lido sempre.

**Por quê:** o mesmo argumento do D-08. O `SKILL.md` diz como o método funciona; os tokens dizem o que esta casa assume, e vão mudar quando o usuário indicar outro design system ou o VS Code mudar de tema padrão.

Há um segundo motivo, prático: são ~90 linhas de CSS. Carregá-las em toda invocação do buildx, inclusive nas que não tocam interface, é custo puro — e o `SKILL.md` já diz para ler o reference da etapa apenas quando a etapa chega.

**O que invalida:** nada. É a mesma regra que já governa os padrões da casa.
---

## D-17 — O esqueleto de aplicação é padrão da casa, e mora dentro da FT-01

**Decisão:** toda entrega do buildx traz painel inicial, cadastro de usuários sob Configurações, perfil do usuário logado e troca de senha, com a navegação já montada na barra lateral. É o P-9, e ele é construído dentro da `FT-01`, nunca como feature separada.

**Alternativas descartadas:** duas.

**A primeira — deixar que o usuário peça.** Ninguém pede. "Quero um sistema de gestão de contratos" não menciona troca de senha porque quem descreve um sistema descreve o que ele faz, não a moldura que todo sistema com login tem. O resultado de esperar o pedido é uma entrega em que o segundo usuário só nasce por `INSERT` e ninguém troca a própria senha — tecnicamente conforme ao pedido, e inútil para quem não é o desenvolvedor.

**A segunda — uma feature própria, tipo `FT-02 — Administração`.** Parece mais limpo e é pior. Cadastro de usuários e perfil mexem no mesmo modelo de usuário e nas mesmas verificações de papel da autenticação: separá-los cria duas features que sempre tocam os mesmos arquivos — o sintoma de "corte errado" que o próprio B3 manda corrigir. E uma feature que parece de negócio é uma feature que se adia; recortada como `FT-08`, chega depois de sete features que já leem usuário, e cada uma precisa ser revisada.

**Por quê a fronteira ficou onde ficou.** O P-9 entrega a moldura, não o escopo. Ele decide **como o sistema é operado** — quem entra, quem administra, como cada um cuida da própria conta —, que é exatamente o território dos padrões da casa. Não decide o que o sistema faz: nenhuma tela de negócio nasce dele, e o painel inicial vem deliberadamente vazio, com título e subtítulo, para que as features do B4 o preencham.

Isso também é o que separa o P-9 do P-5. O usuário de demonstração torna a entrega **demonstrável** — há conta para entrar. O esqueleto torna a entrega **operável** — há aonde chegar depois de entrar, e como criar a segunda conta. As duas coisas são necessárias, e nenhuma substitui a outra.

**O que invalida:** o sistema não ter área restrita (sem login não há perfil nem cadastro de quem entra); a gestão de usuários ser delegada a um provedor externo por pedido do usuário (sai o E-2, ficam E-1, E-3 e E-4); o projeto ser de usuário único e local (sai o E-2). Nenhuma invalidação derruba o painel inicial: toda entrega tem tela inicial.

---

## D-18 — O esqueleto é um template real, copiado, não gerado

**Decisão:** a skill carrega `template/` — um projeto Next.js de verdade, com dependências fixadas, banco, autenticação, o P-9 implementado, 61 testes verdes e CI próprio. O B2 copia essa pasta para a raiz do projeto novo, ajusta o nome e o segredo, e verifica. Nada disso é gerado.

**Alternativa descartada:** o B2 escrever o esqueleto a cada projeto, guiado pelos padrões da casa — que era o desenho original.

**Por quê a alternativa perde.** O custo em tokens é o argumento óbvio e o menos importante. O que decide é o **determinismo**: código gerado sai diferente a cada vez. O projeto de janeiro trata erro de um jeito, o de março de outro, e os dois são "corretos" segundo o mesmo reference. Isso corrói justamente o que o `stackx` existe para sustentar — um dialeto único, verificável. Com template, o projeto número trinta recebe byte a byte o mesmo esqueleto do número um, e é um esqueleto que já passou no CI.

Há um terceiro efeito, mais silencioso: um esqueleto gerado tem, no melhor caso, os testes que o gerador escreveu naquela hora, sobre o código que ele mesmo acabou de escrever. Um template tem uma suíte que já sobreviveu a mudanças de dependência.

**A objeção que eu levantei e que o usuário derrubou.** Argumentei que copiar código implementado violaria o TDD do sprintx, que a SKILL.md lista como inviolável. O argumento estava errado, e vale registrar por quê: **o TDD existe para garantir que o código foi provado, não para garantir que o teste foi escrito num instante específico.** Um template com suíte verde e CI é código provado — provado uma vez, com cuidado, em vez de re-provado a cada projeto por uma máquina que varia. Fazer o F6 reimplementar login e troca de senha em todo projeto novo não é rigor: é desperdício com risco de variação.

**A fronteira real, que substitui a que eu tinha proposto.** Não é "código vs. testes". É **o que não depende do pedido do usuário vs. o que depende**. O template traz a moldura — o modelo para no `Usuario`, sem nenhuma entidade de domínio, nenhuma regra de negócio, nenhum item extra de navegação. Tudo que depende do pedido nasce no B4 sob TDD, sem exceção. Enquanto essa linha for respeitada, o TDD segue intacto onde ele importa.

**O que a decisão obriga.** Um template distribuído a todo projeto novo é uma dívida distribuída se ninguém o mantiver. Daí o `.github/workflows/template.yml`: instala, migra, semeia, linta, checa tipos, builda, testa e audita dependências a cada mudança e toda segunda-feira, falhando em vulnerabilidade `high` ou acima. Defeito no template se corrige na skill, com o CI, e se recopia — nunca só no projeto que o encontrou.

**O que invalida:** o usuário pedir stack que o template não atende (outra linguagem, outro framework, outro banco) — aí o B2 volta a montar o esqueleto à mão e registra a premissa; o projeto não ter interface web.

---

## D-19 — A área de trabalho da feature é do sprintx, e o buildx trabalha dentro dela

*(Atualiza o caminho citado na D-06: onde ela diz `docs/<slug>/`, hoje é `docs/sprintx/features/<slug>/`. A decisão da D-06 — um `MAPA.md` só, em vez de uma pasta por feature no buildx — continua valendo integralmente.)*

**Decisão:** o buildx **não abre branch e não abre worktree**, e não invoca `mergex-abrir`. Quem cria ou retoma a árvore de trabalho de cada feature é a **F1 do sprintx** (regra 21 dele: uma feature por árvore de trabalho), em `../<repo>--<slug>`, na branch `feature/<slug>`. O buildx marca a feature `em_andamento` no `MAPA.md`, chama a F1, entra na árvore que ela abriu, conduz F2 → F6 e as três chamadas da mergex de lá, e volta ao checkout de controle para atualizar o mapa. A mergex entra pelo E0, acionado **pela própria F6**, para adotar a branch que já existe.

**Alternativa descartada:** manter `mergex-abrir → sprintx F1`, o fluxo original, em que o buildx abria a branch antes de chamar o sprintx.

**Por quê a alternativa perde.** Ela deixou de funcionar quando as skills irmãs evoluíram, e não por preferência: hoje a F1 abre o worktree **antes do scaffold**, então a branch criada pelo buildx seria uma segunda área de trabalho para a mesma feature — ou a F1 falharia, porque o git recusa duas árvores na mesma branch. Somam-se dois desencontros de contrato: os artefatos do sprintx passaram a viver em `docs/sprintx/features/<slug>/`, não em `docs/<slug>/`; e o E0 da mergex passou a ser acionado pela F6, quando o `ORQUESTRADOR.md` já existe, para adotar a branch em vez de criar.

**O que isso torna explícito, e que antes ficava implícito:** existem **duas árvores**. O checkout de controle guarda o estado do projeto (`docs/projeto/`, `docs/stack/`); cada feature guarda o plano e o código na própria árvore. Como o buildx não faz merge (D-03), o conteúdo de uma feature **não** está visível no checkout de controle — e nenhuma etapa pode concluir que um artefato não existe só porque não o encontrou lá. O B5 e o B6 passam a localizar a árvore da feature (`git worktree list --porcelain`) ou a ler da branch (`git show feature/<slug>:<caminho>`), e o replanejamento acontece no worktree original, nunca numa árvore nova.

**O que não muda:** nenhuma das 12 regras invioláveis. O buildx continua orquestrando sem implementar; a F2 continua respondida em quatro degraus; o TDD do sprintx continua intocado; o merge continua humano e `mergex-revisar` continua nunca sendo invocado; o teto de recursão, o P-9 e o contrato com o stackx seguem iguais.

**O que esta decisão NÃO resolve:** features dependentes continuam nascendo de árvores que não contêm as dependências já entregues, porque não há integração entre elas. Isso é problema declarado e tratado em frente própria (`fix/p0-buildx-integration`), não aqui.

**O que invalida:** o sprintx deixar de abrir worktree na F1 (aí o buildx volta a precisar de alguém que abra a branch antes da execução); o projeto não usar git, caso em que a F1 já trabalha na árvore atual e a distinção entre as duas árvores desaparece.

---

## D-20 — A F6 do sprintx é dona do ciclo da mergex; o buildx lê o resultado

*(Refina a D-19, que estabeleceu a posse da área de trabalho. Aqui a questão é outra: quem conduz a entrega.)*

**Decisão:** a **F6 do sprintx** aciona a mergex de ponta a ponta — **E0** no início, **E1** a cada task concluída e, depois de gravar o `FECHAMENTO.md`, **E2 a E8** (portão, atenção, descrição do PR, pacote de QA, push, abertura do PR e registro). Quando a F6 devolve o controle, a entrega da feature **já aconteceu**. O buildx não invoca nenhuma etapa da mergex: ele **lê** `docs/entregas/<slug>/ENTREGA.md` e `docs/sprintx/features/<slug>/FECHAMENTO.md` e atualiza o `MAPA.md`.

**Alternativa descartada:** manter o buildx chamando `mergex-check`, `mergex-pr` e `mergex-qa` depois da F6 — o fluxo anterior, escrito quando a F6 terminava com o código escrito e nada mais.

**Por quê a alternativa perde.** Ela deixou de ser uma escolha e passou a ser duplicação: a sprintx atual conduz E2 a E8 antes de devolver o controle, então o buildx rodaria de novo o que acabou de acontecer. O custo não é só de tokens — é de correção. O portão seria avaliado duas vezes sobre estados diferentes (a segunda vez já com os artefatos da primeira na árvore), o `mergex-pr` tentaria abrir um segundo pull request para a mesma branch, e o `ENTREGA.md` seria reescrito por um segundo dono. Um ciclo de entrega com dois donos não falha alto: ele produz resultado plausível e errado.

**Como o buildx decide, e com que campos.** Só os que os contratos das duas skills declaram — nenhum inventado:

| Sinal | Destino no `MAPA.md` |
|---|---|
| `estado: entregue` e `portao: pronto` no `ENTREGA.md` | `entregue`, com o `pr_url` quando houver e os `testes_adicionados` do `FECHAMENTO.md` |
| `portao: bloqueado` | `bloqueada`, com o motivo que o portão registrou e os `desvios` |
| `estado: aberto` depois de a F6 devolver o controle | `bloqueada`: a entrega parou no meio |
| `ENTREGA.md` ausente, com a mergex instalada | `bloqueada` por **incompatibilidade de versão** da sprintx |

`pr_url: null` **não reprova**: o contrato da mergex declara que PR não aberto não é falha, e a descrição fica em `PR.md`. Quem decide é o `portao`.

**Sem fallback, de propósito.** O buildx não completa à mão o que não encontrou. Executar as etapas que faltaram recriaria os dois donos que esta decisão existe para eliminar — e o faria justamente no caso em que o contrato instalado já está fora de sincronia, que é quando o dano é mais difícil de enxergar. Falha explícita de versão é melhor que execução dupla.

**O que não muda:** nenhuma das 12 regras invioláveis. A F1 continua dona da branch e do worktree (D-19); o buildx continua orquestrando sem implementar; a F2 autônoma continua em quatro degraus; o TDD continua intocado; `mergex-revisar` continua nunca sendo invocado nem encadeado — nem pelo buildx, nem pela F6 — e o merge continua humano.

**O que esta decisão NÃO resolve:** a integração acumulativa entre features, a árvore `buildx/<projeto_id>`, a base dinâmica e o PR final único seguem reservados à frente `fix/p0-buildx-integration`.

**O que invalida:** a sprintx deixar de acionar E2→E8 na F6 — aí o buildx voltaria a precisar conduzir a entrega, e esta decisão teria de ser revista junto com o contrato dela.

---

## D-21 — Integração interna não é o merge que a D-03 protege

**Decisão:** avançar `buildx/<projeto_id>` com `git merge --ff-only feature/<slug>`, para uma feature já entregue e com `portao: pronto`, é **integração interna** e é permitida. O merge que a D-03 protege — o de `buildx/<projeto_id>` para a branch principal — continua exclusivamente humano, e `mergex-revisar` continua nunca sendo invocado nem encadeado.

**Alternativa descartada:** ler a D-03 como proibição de qualquer avanço automático de branch, o que obrigaria o humano a integrar feature por feature à mão antes que a próxima pudesse nascer da árvore certa — e faria o modo autônomo parar a cada feature.

**Por quê a distinção é real, e não uma flexibilização:**

- **a branch principal não é tocada** — nem por commit, nem por push, e os hooks de segurança da mergex barram as duas coisas;
- **nada consome `buildx/<projeto_id>`**: não há deploy, release, tag ou publicação a partir dela. Ela é a montagem do que o humano vai revisar como um pull request;
- **correção se faz para a frente**: qualquer ajuste antes do PR final entra como commit novo — feature nova ou replanejamento —, nunca reescrevendo o que já entrou;
- **nenhuma reescrita de histórico remoto é necessária em nenhum momento do fluxo.** Uma vez publicada, `buildx/<projeto_id>` não é repontada, forçada nem reescrita; se algo precisar ser desfeito, é por commit de reversão, como em qualquer branch compartilhada.

O fast-forward é, aliás, a operação de integração mais conservadora que existe: não cria commit, não resolve conflito, não pode trazer conteúdo que não esteja na feature, e falha em vez de adivinhar quando a árvore divergiu.

**O que invalida:** alguém passar a consumir `buildx/<projeto_id>` como entrega — deploy, release, tag de produção. Aí ela deixa de ser interna, e a D-03 volta a valer inteira sobre ela.

---

## D-22 — O buildx versiona o próprio estado, fora da janela da feature

**Decisão:** o buildx commita `docs/projeto/**` e `docs/stack/**` em `buildx/<projeto_id>`, e **só isso**. Por feature, em no máximo dois momentos:

1. **antes da F1** — `MAPA.md` com a feature `em_andamento`. O `HEAD` resultante é o `BASE_SHA` de que a feature nasce;
2. **depois do fast-forward** — `entregue` e o SHA integrado.

**Entre esses dois momentos, `buildx/<projeto_id>` não recebe commit nenhum.** Premissa nova da F2 é gravada no arquivo na hora, mas o commit dela espera o fechamento da feature. É essa janela fechada que torna o fast-forward possível.

Dois casos particulares, e os dois importam:

- **feature com replanejamento pendente não gera commit de estado.** O mapa fica `em_andamento` e a árvore fica em `BASE_SHA`. Commitar ali moveria `CONTROL` para `BASE_SHA+1`, e a integração depois seria impossível;
- **feature com bloqueio terminal gera o commit de `bloqueada`**, porque aquela branch nunca será integrada e a árvore pode avançar sem risco.

**Alternativa descartada:** deixar `docs/projeto/` fora do versionamento, como estado solto na árvore. Ela quebra três coisas: o PR final não conteria o mapa, as premissas nem a validação; a árvore de controle viveria suja, e árvore suja bloqueia integração; e a retomada perderia a única fonte durável de estado.

**Por quê não viola a regra 3.** "O buildx não implementa, não planeja e não testa" é sobre o **produto**: código, plano e teste continuam sendo das irmãs. Commitar o próprio registro de orquestração é escrituração, não implementação — o mesmo movimento que a mergex formalizou para os artefatos de método dela. O buildx nunca commita código de produto nem artefato interno de feature: esses chegam por fast-forward.

**O que invalida:** o estado do projeto passar a viver fora do repositório (um painel externo, um serviço) — aí não haveria o que commitar, e a janela fechada deixaria de ser necessária.

---

## D-23 — Premissa autônoma nasce na feature e só vira global depois da integração

**Decisão:** a premissa que o buildx cria para responder à F2 (ou à R11 da F3) é gravada **primeiro no artefato feature-local** — a seção "Premissas pendentes do BuildX" do `docs/sprintx/features/<slug>/00-DECISOES.md`, com `status: pendente_promocao` e o `PR-NN` já reservado — e **promovida ao `docs/projeto/PREMISSAS.md` somente depois do fast-forward**, no mesmo commit que marca a feature como entregue.

**Alternativa descartada:** editar `docs/projeto/PREMISSAS.md` da `CONTROL` durante a F2, que era o que o contrato mandava até aqui.

**Por quê a alternativa perde.** Ela quebra a janela fechada. Entre a F1 e a integração, a árvore de controle precisa estar em `BASE_SHA` **e limpa** — é isso que o fast-forward exige e que a prova D do passo 7 verifica. Escrever no `PREMISSAS.md` da `CONTROL` no meio da F2 suja a árvore, e o portão pré-ff barra justamente a feature que a premissa existe para servir. O defeito não aparece na hora: aparece no fim, depois do trabalho todo feito.

**A alternativa simétrica também perde:** gravar no `docs/projeto/PREMISSAS.md` **dentro da branch da feature**. Para a mergex, esse arquivo não está na lista `arquivos` de nenhuma task — é arquivo de produto fora do plano, vira desvio de escopo e reprova o portão (V9). O `00-DECISOES.md`, não: ele é artefato de método do próprio trabalho, que a mergex commita e isenta por contrato.

**A regra "escrever antes de usar" continua inteira.** Só muda o endereço: reserva o `PR-NN` lendo o `PREMISSAS.md` da `CONTROL` congelada, grava a premissa pendente, e só então responde com ela. Como há uma feature por vez e `CONTROL` não se move dentro da janela, o número reservado é estável.

**A promoção é idempotente pelo próprio `PR-NN`**, sem marcação de volta no artefato da sprintx: mesmo id com mesmo conteúdo é no-op; mesmo id com conteúdo diferente é inconsistência e para. Isso evita editar, depois da integração, um artefato que pertence a outra skill só para registrar que ele já foi lido.

**Só feature integrada promove.** Replanejamento pendente mantém as premissas na feature, para a nova tentativa reutilizar; bloqueio terminal também não promove — a premissa global representa decisão **incorporada ao produto**, não plano abandonado. Promover a premissa de uma feature que nunca entrou faria o `PREMISSAS.md` documentar uma proteção que nenhum código realiza.

**O que invalida:** o fim da janela fechada — se um dia a integração deixar de exigir `CONTROL` parada e limpa, a premissa pode voltar a nascer no estado global.

---

## D-24 — A premissa feature-local do BuildX tem arquivo próprio

*(Refina a D-23, que continua valendo inteira no que decidiu: a premissa nasce na feature e só vira global depois do fast-forward. Muda apenas **onde** ela nasce.)*

**Decisão:** a premissa pendente é gravada em `docs/sprintx/features/<slug>/BUILDX-PREMISSAS.md`, arquivo **do buildx**, dentro da pasta canônica da feature. Sem frontmatter, sem `expx-schema`, sem schema novo. O `00-DECISOES.md` volta a ter um dono só — a sprintx — e recebe do buildx apenas o que a integração sempre exigiu: a decisão da F2, `respondido_por: buildx`, e a fonte, que no degrau 4 é `BUILDX-PREMISSAS.md#PR-NN`.

**Por quê a D-23 precisava deste refinamento.** Ela guardava a premissa numa seção "Premissas pendentes do BuildX" dentro do `00-DECISOES.md`. O contrato da sprintx para aquele arquivo cobre o frontmatter `kind: decisoes` e as linhas `D-NN` e `PENDENTE-NN` — e a F2 reexecutada para resolver PENDENTEs pode regerá-lo. Nada ali promete preservar prosa estrangeira. O desenho só se sustentava com o buildx conferindo e **reparando** a seção depois de cada reexecução de F2 ou F3: dois donos para o mesmo arquivo, e uma regra de reparo que existe só para compensar a ausência de um contrato.

**Alternativas descartadas:**

1. **Obrigar a sprintx a preservar seção desconhecida.** Resolveria, mas mudando a skill irmã para servir ao buildx — e criando, no contrato dela, uma promessa sobre conteúdo que ela não entende.
2. **Continuar reparando a seção depois de cada F2/F3.** É o desenho da D-23. Funciona enquanto o reparo é lembrado; a falha, quando vier, é silenciosa — a premissa some, a decisão que ela sustentava fica órfã, e nada acusa.
3. **Gravar direto no `PREMISSAS.md` global durante a janela fechada.** Já descartada na D-23, e pelo mesmo motivo: suja a `CONTROL` e barra o fast-forward da própria feature que a premissa serve.

**Por que o endereço novo é seguro.** A mergex trata `docs/sprintx/features/<trabalho_id>/` inteira como pasta de artefatos de método do próprio trabalho — ela commita e isenta a pasta, não um arquivo específico. Um arquivo novo lá dentro não é arquivo de produto fora do plano, não vira desvio de escopo e não reprova o V9. **Nenhuma mudança é necessária na sprintx ou na mergex.**

**O que o arquivo próprio compra.** A F2 e a F3 podem rodar de novo, e o `00-DECISOES.md` pode ser regerado do zero: a premissa sobrevive porque não está lá. O replanejamento preserva o arquivo e reutiliza o mesmo `PR-NN`. A feature bloqueada o mantém como evidência histórica, legível pelo B5 e pelo relatório final. E a regra do reparo deixa de existir.

**O que não muda:** "escrever antes de usar"; a reserva do `PR-NN` lendo o `PREMISSAS.md` da `CONTROL` em `BASE_SHA`; a promoção apenas depois do fast-forward, idempotente pelo próprio `PR-NN` — id ausente promove, id com mesmo conteúdo é no-op, id com conteúdo diferente para; e o fato de que só feature integrada promove. Nada é escrito de volta no `BUILDX-PREMISSAS.md` para marcar a promoção: a existência idêntica no `PREMISSAS.md` global é a prova.

**O que invalida:** a sprintx passar a declarar, em contrato, que preserva conteúdo estrangeiro no `00-DECISOES.md` — aí os dois arquivos poderiam voltar a ser um. Ou a mergex deixar de tratar a pasta da feature como artefato de método, caso em que o endereço precisa mudar de novo.

---

## D-25 — O buildx não estende o `kind: decisoes` da sprintx

*(Corrige um ponto da D-24, que continua valendo no que decidiu — a premissa em arquivo próprio, o `00-DECISOES.md` com um dono só. Onde ela diz `respondido_por: buildx`, leia "a proveniência no `motivo`". Nenhuma instrução viva manda gravar aquele campo.)*

**Decisão:** o buildx grava a decisão da F2 no `00-DECISOES.md` **no schema da sprintx, sem acrescentar chave nenhuma**. A proveniência — quem fechou, com base em quê — vai no campo `motivo`, que já existe, em uma linha de texto que nomeia a fonte. O marcador `(HIPOTESE)` segue a semântica da sprintx: ela declara que decisão **sem** o marcador é lida como confirmada pelo usuário, em qualquer modo.

**De onde veio.** O primeiro E2E real BuildX → SprintX → MergeX. A F2 da FT-01 escreveu as decisões seguindo o contrato do buildx, que mandava registrar `respondido_por: buildx` por decisão. O item de decisão do `kind: decisoes` aceita seis chaves — `id`, `decisao`, `alternativa_descartada`, `motivo`, `status`, `bloqueante` — e aquela não é uma delas. A validação apontou a extensão fora de contrato. Não foi a causa do bloqueio no E2, e é exatamente por isso que merece registro: passou despercebida em revisão de contrato e só apareceu quando a cadeia rodou de ponta a ponta.

**Alternativa descartada:** acrescentar `respondido_por` ao `kind: decisoes` da sprintx.

**Por quê ela perde.** Criaria acoplamento de schema entre as duas skills para uma informação que já cabe num campo existente. O `motivo` foi feito para isto — a própria sprintx o usa para carregar `(HIPOTESE)` e a evidência quando a F2 fecha uma decisão por pesquisa. Um campo novo obrigaria toda instalação da sprintx a conhecer o buildx para validar o arquivo, e a cadeia inteira a subir de versão junto.

**Os três casos de proveniência**, porque a classificação é onde se erra:

| | origem | marcador |
|---|---|---|
| **A** | declaração direta do usuário, no pedido ou no briefing | **sem** `(HIPOTESE)` — houve confirmação humana |
| **B** | premissa assumida pelo buildx, no `BUILDX-PREMISSAS.md` ou no `PREMISSAS.md` | **com** `(HIPOTESE)`, citando o `PR-NN` |
| **C** | convenção do `CONVENCOES.md` | **com** `(HIPOTESE)` quando foi o buildx ou o stackx que a escolheu; **sem**, quando o usuário a confirmou |

"Estabelecida no arquivo" não é "confirmada pelo usuário": num projeto novo a maior parte do `CONVENCOES.md` nasce marcada `decidido_pelo_buildx`, e uma decisão derivada dela sem o marcador afirmaria uma confirmação humana que nunca houve.

**`origem_buildx` e `feature_id` não são afetadas.** Elas não estendem o `kind: decisoes`: são a ponte entre o nível do projeto e o nível do trabalho, declarada no `references/00-schema.md` como chaves que a cadeia acrescenta ao frontmatter de **todo** artefato da feature. Continuam obrigatórias.

**O que não muda:** o `BUILDX-PREMISSAS.md` e tudo que a D-24 decidiu; a reserva do `PR-NN`; a promoção pós-ff, idempotente pelo `PR-NN`; e a regra de escrever antes de usar. Muda só a representação da decisão dentro do arquivo da sprintx.

**O que invalida:** a sprintx acrescentar, por conta dela, um campo de proveniência ao `kind: decisoes` — aí o buildx passa a usá-lo, em vez de carregar tudo no `motivo`.

---

## D-26 — O orçamento da F5 é do caller; a contagem é da sprintx

*(Contexto das D-26 a D-33: o piloto brownfield real do Conselho Municipal. A F1 foi correta, a feature nasceu exatamente em `BASE_SHA`, F2/F3/F4 foram corretas, a F5 reprovou três vezes, o buildx aplicou o teto e a F6 nunca começou — mas os artefatos da sprintx existiam só no worktree, o B4 marcou a feature `bloqueada` sem evidência commitada, e a execução precisou inventar uma seção "Aberto — aguardando classificação do B5" que o `TEMPLATE-RECURSAO.md` não previa. A sprintx P0.1 (`a4f5495`) fechou o lado dela: planejamento durável, checkpoints, orçamento declarado pelo caller, `orcamento_esgotado`, `CHECKPOINT` pendente. Estas decisões fazem o buildx consumir esse contrato. Nenhuma decisão anterior foi reescrita.)*

**Decisão:** o briefing de toda feature declara `max_reprovacoes_f5: 3` e `orcamento_declarado_por: buildx`. A F1 da sprintx os repassa a `planejamento.sh criar <slug> 3 buildx`, que os grava no `00-PLANEJAMENTO.md`. Dali em diante **a sprintx é a única dona da contagem**: o buildx não incrementa contador, não interpreta "rodada 1/2/3" de prosa, não soma linhas `VEREDITO:`, não sobe o teto e não o reinicia numa retomada. Ele decide só pela saída de `planejamento.sh fase`, e confere o orçamento no `00-PLANEJAMENTO.md` **commitado** depois do primeiro checkpoint.

**Alternativa descartada:** o buildx continuar contando as voltas F3 ↔ F5 — "duas voltas; a terceira reprovação bloqueia" — pela própria sessão.

**Por quê:** a contagem pela sessão morre com a sessão. Uma retomada sem a transcrição recomeçava o laço, ou parava por um número que ninguém conseguia provar. O `historico` do `00-PLANEJAMENTO.md` é append-only, gravado por script e checkpointado: qualquer sessão, de qualquer harness, chega à mesma contagem. O limite continua sendo o do buildx — três reprovações —, porque quem declara o orçamento é quem sabe o custo de girar; só a contagem muda de dono. E a forma de passagem é a que a sprintx já oferece (`criar <slug> [max] [por]`): nenhum campo novo em artefato cujo schema não o aceita.

**O que invalida:** a sprintx deixar de aceitar orçamento do caller, ou passar a recebê-lo por outro canal — aí o briefing muda de forma, e a posse da contagem continua dela.

---

## D-27 — Checkpoint da sprintx é estado legítimo da feature, e não é entrega

*(Refina a D-22, que continua valendo: a `CONTROL` não recebe commit dentro da janela. Muda a leitura do que acontece na branch da feature.)*

**Decisão:** a `feature/<slug>` pode avançar dentro da janela por **checkpoints de planejamento da sprintx** (trailer `Planejamento: checkpoint`, só `docs/sprintx/features/<slug>/**`), por commits E1 e por commits de entrega. Nada disso quebra a janela. Na F1 o tip continua **exatamente** `BASE_SHA` — o primeiro checkpoint só vem no fim da F2. Na retomada vale a ancestralidade, nunca a igualdade, e nunca se recria a branch: worktree perdido se reabre sobre a mesma branch. `fase=CHECKPOINT` com `persistencia=pendente` **não decide nada**: o buildx não bloqueia, não avança o mapa, não roda B5 e não começa outra feature; pede à sprintx o checkpoint. Checkpoint não é task concluída, não é E1, não é entrega, não é push e não é PR.

**Alternativa descartada:** manter a leitura antiga — "os commits à frente de `BASE_SHA` são do E1" — e tratar qualquer commit antes da F6 como anomalia.

**Por quê:** com a sprintx P0.1, uma feature em F3 já tem commits: tratá-los como anomalia pararia toda retomada legítima; tratá-los como E1 faria o buildx acreditar que houve execução. E o estado gravado no disco e ainda não persistido é exatamente o caso do piloto: parecia durável e não era. Deixar esse estado decidir um bloqueio, ou uma F6, seria repetir o defeito do outro lado da fronteira.

**O que invalida:** a sprintx deixar de checkpointar o planejamento, ou passar a checkpointar fora da pasta da feature — aí a prova de "só checkpoints" precisa mudar junto.

---

## D-28 — Terminal pré-F6 só move a CONTROL com evidência commitada

**Decisão:** `orcamento_esgotado` só é terminal com `fase=PARAR`, `estado=orcamento_esgotado` e `persistencia=duravel`, e mesmo assim a `CONTROL` só avança depois do **portão terminal pré-F6**, A a I: `CONTROL` e remoto em `BASE_SHA`, feature descendendo da base, as duas árvores limpas, o `00-PLANEJAMENTO.md` com `orcamento_esgotado` **no `HEAD`** da feature, a sprintx fora de `CHECKPOINT`, **nenhum produto** no histórico `BASE_SHA..feature/<slug>` (todo path na pasta da feature e todo commit com o trailer de checkpoint), e o `00-AUDITORIA.md` da rodada terminal commitado no commit que registrou o terminal. Falhou qualquer prova: pare e relate, nada é escrito. A mesma regra vale para todo bloqueio: `ENTREGA.md` commitado para portão bloqueado ou entrega interrompida, ausência comprovada para incompatibilidade. `persistencia_falhou` para a orquestração da feature e **não** vira `orcamento_esgotado`, `bloqueada` nem `decisao_humana`.

**Alternativa descartada:** marcar `bloqueada` a partir do relato da sessão ("a F5 reprovou três vezes"), que foi o que o piloto fez.

**Por quê:** o bloqueio é o único commit de estado que a `CONTROL` recebe sem fast-forward — e é irreversível na prática, porque a feature nunca volta. Sem a evidência no Git, um checkpoint recusado, uma auditoria sobrescrita no worktree ou um arquivo de produto commitado antes da hora ficariam escondidos atrás de "plano esgotado". Falha de persistência não é conclusão sobre o plano: confundi-las transformaria um hook recusando commit num veredito metodológico.

**O que invalida:** o terminal passar a ser publicado fora do Git (um serviço de estado), caso em que a prova muda de fonte, não de exigência.

---

## D-29 — Replanejamento sai do B5

*(Supera a classe `replanejamento` do `06-recursao.md` e do `TEMPLATE-RECURSAO.md` anteriores. O texto antigo já dizia que ela "quase nunca chega aqui"; agora não chega.)*

**Decisão:** as classes do B5 são três — `trabalho_novo`, `decisao_humana`, `recurso_externo` — e `resolvida` é estado, não classe. Replanejar a mesma feature existe **só** no B4, pela sprintx (`estado: replanejar`), enquanto o orçamento da F5 não acabou. Um `RECURSAO.md` antigo com a classe antiga de replanejamento é **lido** como `trabalho_novo` e nunca reescrito com ela.

**Alternativa descartada:** manter a classe de replanejamento no B5, com teto próprio.

**Por quê:** quando uma pendência chega ao B5, a tentativa acabou: o orçamento se esgotou, ou o portão bloqueou, e a `CONTROL` já avançou. Voltar à F3 na branch antiga produziria uma branch que não descende mais da árvore — o fast-forward seria impossível, e o único jeito de integrá-la seria `rebase` ou `merge`, que o contrato proíbe. Uma classe cujo único destino correto é outra classe só existe para ser classificada errado.

**O que invalida:** o buildx passar a permitir integração por outro mecanismo que não o fast-forward — o que a D-21 e a invariante da janela proíbem hoje.

---

## D-30 — Trabalho resolvível depois de um bloqueio vira feature sucessora

**Decisão:** pendência classificada `trabalho_novo` cria uma **feature sucessora** — `FT-NN` novo, **slug novo**, `origem: recursao`, `**Sucede:** FT-XX` —, que nasce do `HEAD` atual da `CONTROL`, com F1 nova, worktree novo e branch nova. A feature bloqueada fica `bloqueada` para sempre. A pendência vai a `em_resolucao` com `destino: FT-NN`, e a `resolvida` quando a sucessora integra. Sucessora que bloqueia pelo **mesmo gatilho e pela mesma cláusula central** da raiz manda a raiz para `decisao_humana` (`laco_detectado`). O ciclo é B4 → B5 → sucessoras → B4, com teto de 3; atingido o teto, o que seria resolvível vai para `decisao_humana` com `teto_de_ciclos_atingido`. A classificação é uma tabela gatilho → classe; para `orcamento_f5_esgotado`, lê a última `00-AUDITORIA.md` commitada: qualquer `ALTA` `[item 7]` → `decisao_humana`; senão qualquer `ALTA` `[item 8]` → `recurso_externo`; senão → `trabalho_novo`.

**Alternativas descartadas:** (1) voltar a feature bloqueada a `pendente` e rodá-la de novo; (2) reaproveitar o slug da bloqueada numa branch nova; (3) classificar por julgamento do modelo sobre "vale tentar de novo".

**Por quê:** (1) a branch antiga não integra mais, e o plano dela esgotou o orçamento — é recomeçar pelo lado que falhou. (2) o slug nomeia a pasta, a branch e o worktree; reaproveitá-lo colide com a branch preservada e mistura dois históricos no mesmo endereço. (3) o piloto mostrou que o mesmo texto recebe juízos diferentes em rodadas diferentes; os prefixos `[item N]` da sprintx P0.1 tornam a causa verificável, e o `[item 7]` vence a mistura porque nenhuma sucessora produz uma decisão humana. O detector compara gatilho e cláusula, não prosa: a mesma classe de defeito voltando é o sinal de que trabalho novo não resolve.

**O que invalida:** a sprintx mudar a numeração dos itens da F5 ou deixar de prefixar os achados — aí a tabela precisa acompanhar.

---

## D-31 — A pendência tem estado, e o RECURSAO.md tem cinco seções fixas

**Decisão:** toda pendência é um bloco `### PEND-NN` com campos fixos (`id`, `estado`, `gatilho`, `classe`, `origem`, `ciclo`, `evidencia`, `causa`, `clausula_central`, `raiz`, `detectada_em`, `classificada_em`, `regra_aplicada`, `destino`, `pr_reservadas`, `resolvida_em`, `nota`) e vive numa máquina de cinco estados, cada um com a sua seção: `aguardando_classificacao` → "Aguardando classificação do B5" (`classe: null`), `em_resolucao` → "Em resolução pela máquina", `decisao_humana` → "Aberto — decisão humana", `recurso_externo` → "Aberto — recurso externo", `resolvida` → "Resolvido nos ciclos". O template tem exatamente essas cinco seções e nenhuma execução inventa outra. A pendência nasce `aguardando_classificacao` no commit que **encerra** a tentativa; o `RECURSAO.md` nunca é escrito dentro da janela — durante F2 a F6 o registro fica na feature.

**Alternativa descartada:** manter as seções por classe ("Aberto — o que exige decisão humana", "Aberto — o que exige recurso externo", "Resolvido") e registrar a pendência já classificada no momento do bloqueio.

**Por quê:** o bloqueio e a classificação são momentos diferentes — o primeiro é do B4, com a janela acabando de fechar; o segundo é do B5, com a visão do ciclo inteiro. O piloto precisou de um lugar para "bloqueada e ainda não classificada", não tinha, e inventou uma seção. Seção inventada é estado que o contrato não conhece: nenhum leitor seguinte sabe tratá-la. E escrever o `RECURSAO.md` dentro da janela suja a `CONTROL`, que é exatamente o que mata o fast-forward (D-22, D-23).

**O que invalida:** um estado de pendência que não caiba nos cinco aparecer em execução real — aí o contrato ganha o estado e a seção, por decisão, nunca por improviso.

---

## D-32 — PR-NN de feature que não integrou continuam reservados

*(Complementa a D-23 e a D-24, que continuam valendo: só feature integrada promove.)*

**Decisão:** ao registrar a pendência de uma feature que termina sem integrar, o buildx lê o `BUILDX-PREMISSAS.md` **commitado** dela e grava os ids em `pr_reservadas`. Toda alocação de premissa nova considera ocupados os `PR-NN` do `PREMISSAS.md`, todos os `pr_reservadas` do `RECURSAO.md` e os que já existem na própria feature. Artefato morto nunca é renumerado, e premissa de feature bloqueada nunca é promovida; a sucessora que precisar da mesma decisão a registra com id novo.

**Alternativa descartada:** calcular o próximo `PR-NN` só pelo `PREMISSAS.md` global, como antes.

**Por quê:** a premissa da feature bloqueada nunca chega ao global, então o id dela parecia livre — e a sucessora o reutilizaria com outro texto. A partir daí o mesmo `PR-NN` teria duas versões: uma no artefato preservado da bloqueada, que o relatório final cita, e outra no `PREMISSAS.md`. A promoção idempotente pelo id (D-23) deixaria de provar alguma coisa, e o leitor que seguisse `BUILDX-PREMISSAS.md#PR-09` chegaria a uma decisão que não é a que o produto realiza.

**O que invalida:** as premissas ganharem identificador por feature (`FT-NN/PR-NN`), caso em que a colisão deixa de existir por construção.

---

## D-33 — O buildx nunca comita artefato da sprintx

*(Reafirma, para o planejamento durável, a fronteira da D-20: cada ciclo tem um dono.)*

**Decisão:** o checkpoint de planejamento é da sprintx (DS-131). O buildx não faz `git add` nem `git commit` da pasta da feature, não usa `--no-verify` para contornar hook, não completa checkpoint por conta própria e não cria, edita, apaga ou regera `00-PLANEJAMENTO.md`, `00-AUDITORIA.md` ou plano nenhum. O único arquivo do buildx dentro da pasta da feature é o `BUILDX-PREMISSAS.md` — e ele é persistido pelos commits da sprintx e da mergex, como todo artefato de método da pasta. A mergex continua entrando só na F6.

**Alternativa descartada:** o buildx commitar a pasta da feature quando o checkpoint da sprintx falha, "para não perder o plano".

**Por quê:** o commit do buildx esconderia a causa (`persistencia_falhou` é um hook do projeto recusando), criaria dois donos para o mesmo estado, e produziria um checkpoint sem as garantias do script — prova de paths, trailer, estado coerente com o `historico`. A sprintx P0.1 declarou que seu contrato se invalida se "a `buildx` passar a commitar a pasta da feature por conta própria". Parar e relatar preserva tudo: nada foi limpo, e a retomada cai de novo em `CHECKPOINT`.

**O que invalida:** a sprintx delegar explicitamente o checkpoint ao caller — o que inverteria a DS-131.

---

## D-34 — Conversão de ciclo exige entrega

*(Refina a D-30 e o detector de ciclo sem conversão do `06-recursao.md`, que continuam valendo. Não muda a máquina: explicita o que ela já faz, para que ninguém a "corrija" depois.)*

**Decisão:** para a regra `ciclo_sem_conversao`, um ciclo só **converteu** quando ao menos uma sucessora dele está `entregue` **e** a pendência correspondente está `resolvida`. Mudar a classificação de uma pendência para `decisao_humana`, para `recurso_externo` ou para qualquer outra condição de bloqueio ou interrupção **não é conversão** — nem quando a mudança vem de evidência nova, e nem quando a própria sucessora a produz. Um ciclo cujas sucessoras só bloquearam de novo terminou sem conversão, por mais pendências que tenha reclassificado, e o detector se aplica a ele como a qualquer outro.

**Alternativa descartada:** contar como conversão a pendência que saiu de `trabalho_novo` para `decisao_humana` ou `recurso_externo` por evidência nova, sob o argumento de que o ciclo "produziu conhecimento" e, portanto, não girou em falso.

**Por quê:** a recursão existe para transformar trabalho recursivo em **entrega**. Reclassificar interrompe ou redireciona o fluxo — às vezes é exatamente a coisa certa a fazer —, mas não entrega nada: a `CONTROL` não recebeu feature, o `MAPA.md` não ganhou `entregue`, e o produto é o mesmo do começo do ciclo. Aceitar reclassificação como conversão abriria o caminho que o detector existe para fechar: cada ciclo descobre um motivo novo para não entregar, e o teto vira o único freio. Também quebraria a leitura pelo disco — "converteu" deixaria de ser uma prova sobre `entregue` e `resolvida`, que o `MAPA.md` e o `RECURSAO.md` carregam, e passaria a depender de julgar se a evidência era "nova o bastante". E o disparo não custa nada a quem já foi reclassificado: pendência em `decisao_humana` ou `recurso_externo` não é tocada pelo detector; ele só impede que outra sucessora nasça naquele ciclo.

**O que invalida:** a recursão ganhar uma finalidade além da entrega — por exemplo, um ciclo dedicado a levantar decisões para o humano —, caso em que esse ciclo precisa de regra e contador próprios, nunca de uma conversão mais frouxa.

---

## D-35 — ENTREGA terminal commitada precede a matriz da sprintx

*(Refina a D-20, a D-26, a D-27 e a D-28 para o que acontece depois do E8. Não muda o enum da mergex nem a máquina da sprintx: fixa qual das duas respostas decide quando elas coexistem.)*

**Decisão:** antes de seguir a linha `F6` / `aprovado` / `duravel` do `planejamento.sh fase` — numa retomada ou no caminho contínuo —, o buildx lê o `docs/entregas/<slug>/ENTREGA.md` **commitado** no `HEAD` da `feature/<slug>` (`git show feature/<slug>:…`; o arquivo da árvore de trabalho não conta). Terminais são **exatamente** as duas combinações que o E8 da mergex grava ao fechar: `estado: entregue` com `portao: pronto`, e `estado: bloqueado` com `portao: bloqueado`. Entregue: o buildx segue o caminho terminal que já existia — provas, publicação e fast-forward, sem reexecutar portão, PR ou QA. Bloqueado: vai direto à triagem terminal com o gatilho `entrega_bloqueada`, e **não** reentra na F6, **não** deixa o E0 rodar, **não** reabre o `ENTREGA.md`, **não** reexecuta E2 a E8 e **não** publica a branch. `ENTREGA.md` ausente no `HEAD`, ou `estado: aberto`, não é terminal: a sprintx decide como antes. Qualquer outra coisa — `estado` ou `portao` ausente ou repetido, valor fora do enum, `entregue` sem `pronto`, `bloqueado` sem `bloqueado` — é inconsistência: pare e relate, sem inferir bloqueio e sem seguir para a F6. Na retomada, a leitura vem depois de K, A, J e da prova de ancestralidade, e **antes** de qualquer linha que dependa da `SPRINTX` ou do worktree: com o worktree perdido, a feature continua terminal. **Isso inclui `CHECKPOINT` pendente:** a regra da D-27 — completar o checkpoint antes de qualquer decisão da matriz — vale **somente quando não existe `ENTREGA` terminal commitada**. Existindo, a entrega terminal vence, o buildx não completa nem pede o checkpoint para decidir, e a transição pendente da sprintx fica como está, na branch preservada.

**Alternativa descartada:** deixar a linha F decidir e confiar no E0 idempotente para "retomar" a entrega.

**Por quê:** as duas fontes descrevem coisas diferentes, e ambas são verdadeiras ao mesmo tempo. O `planejamento.sh` descreve a máquina da sprintx, que termina em `aprovado` e ali permanece durante e depois da F6; o `ENTREGA.md` terminal descreve o resultado da execução e da entrega. Consultar só a primeira devolve à F6 uma feature cuja entrega já fechou — e a primeira coisa que a F6 faz é o E0, que retoma o registro existente e o devolve a `aberto`, com `portao: null` e `push_feito: false`. Foi o que o piloto P0 expôs: planejamento `F6`/`aprovado`, `ENTREGA.md` `bloqueado` commitado, e a retomada escolheu a F6, rodou o E0 e reabriu a entrega, perdendo o terminal histórico e reexecutando o que já tinha terminado. Um planejamento que permaneceu `aprovado` não apaga um terminal commitado. E vencer o `CHECKPOINT` pendente não fere a D-27: o que ela protege é não decidir por estado de planejamento ainda não durável, e aqui quem decide é outro estado, já durável no `HEAD` — a entrega fechada —, que nenhuma transição pendente do planejamento consegue desfazer. Ler o commitado, e não a árvore, é a mesma exigência da D-28: working tree não decide terminal. E não inferir bloqueio de um registro inconsistente é a mesma regra: ou o terminal está provado, ou a feature não é terminal.

**O que invalida:** a sprintx passar a registrar, no próprio planejamento, um estado pós-E8 que torne a resposta de `fase` terminal por si — caso em que as duas fontes precisam concordar, e divergir vira parada —; ou a mergex mudar as combinações que o E8 grava ao fechar.

---

## D-36 — A causa da entrega bloqueada é enumerada, e o B-NN é lido pela classe

*(Refina a linha `entrega_bloqueada` da tabela do B5 (D-30) sobre a D-35. Consome a mergex P0.2-A4 (`b51ba94`, DM-111 a DM-116) e a sprintx P0.2-A5 (`7300e47`, DS-139). Não muda nenhum enum do buildx: as classes continuam três.)*

**Decisão:** a classe de uma pendência `entrega_bloqueada` sai **só** de campos tipados, commitados no `HEAD` da feature citado na `evidencia`: a `causa` do `ENTREGA.md`, lida pela leitura histórica da própria mergex (`causa-do-portao.sh --validar-historico`), e — quando a causa é `bloqueio_aberto` — a `classe` dos `B-NN` com `resolvido_em: null` do `00-BLOQUEIOS.md` do **mesmo** `HEAD`, lida pelo `bloqueios.sh listar` da própria sprintx. A tradução é a tabela de `references/06-recursao.md`: `suite_reprovada`, `teste_nao_declarado` e `arquivo_fora_do_plano` → `trabalho_novo` (a regra vigente "suíte, cobertura ou escopo"); as demais causas → `decisao_humana`; `defeito_de_plano` e `suite_vermelha` → `trabalho_novo`, `prerequisito_ausente` → `recurso_externo`, `lacuna_de_decisao` e `task_reivindicada` → `decisao_humana`. Com `bloqueio_aberto`: nenhum aberto é inconsistência (parar); algum aberto legado → `decisao_humana` (`bloqueio_legado`); classes diferentes → `decisao_humana` (`classes_divergentes`), sem precedência entre elas; uma classe só → a dela (`classe_<classe>`). Causa ausente (registro anterior às chaves) ou `indeterminada` → `decisao_humana` (`causa_nao_commitada`). Registro que a mergex ou a sprintx recusam, causa fora do enum, arquivo de bloqueios ausente e `causa` da pendência diferente da commitada são inconsistência: nada é classificado nem gravado, e a triagem não move a `CONTROL`. A regra `entrega_bloqueada/falha_tecnica` deixa de existir.

**Alternativas descartadas:** (1) continuar derivando `falha_tecnica` da narrativa do bloqueio; (2) escolher um `B-NN` — o primeiro, o mais antigo, o da task da V1 — quando há vários abertos; (3) criar precedência entre classes de bloqueio; (4) reimplementar no buildx a derivação da causa e o parser do `00-BLOQUEIOS.md`; (5) dar classe ao `B-NN` legado pela descrição.

**Por quê:** (1) no piloto, o mesmo B-01 admitia duas leituras e o buildx precisou ler a prosa para chamá-lo de `falha_tecnica` — classificação que nenhum artefato sustentava; a mergex e a sprintx agora gravam o fato tipado, e ler texto de novo desfaria as duas. (2) a V7 afirma que existe **algum** bloqueio aberto, não qual deles barrou: escolher um seria inventar a causa. (3) as classes da sprintx são fatos distintos com remédios distintos (DS-139); ordená-las seria juízo de gravidade que nenhum contrato declara, e o erro caro do B5 é justamente mandar para a máquina o que exige decisão. (4) a mesma evidência precisa dar a mesma leitura em todas as camadas; um segundo parser pode divergir do dono em silêncio. (5) é exatamente o que a DS-139 e a DM-116 proíbem. Onde nenhuma regra vigente do buildx sustenta a tradução sem ambiguidade — `segredo_no_diff`, `auditoria_reprovada`, `legado_incompleto`, `tarefa_nao_concluida`, as duas da runx, `task_reivindicada` — a classe é `decisao_humana`: falhar fechado custa uma pergunta; falhar aberto constrói a coisa errada.

**O que invalida:** uma verificação nova no portão da mergex, ou uma classe nova de bloqueio na sprintx — ganham linha na tabela, por decisão, nunca por semelhança de nome —; a mergex passar a refinar ela mesma o `bloqueio_aberto`; ou a runx adotar a `classe`, caso em que o arquivo dela deixa de ser lido como legado.

---

## D-37 — O retorno da F6 ao planejamento é da sprintx; recusado ou esgotado, é decisão humana

*(Consome a sprintx P0.2-B (`5cdde90`, DS-140 a DS-146). Refina a D-26 — o briefing declara um segundo teto —, a D-35 e a D-36 — a linha `defeito_de_plano` → `trabalho_novo` ganha precedência. Não muda nenhum enum de classe: continuam três. Acrescenta o gatilho `replanejamento_execucao_esgotado`.)*

**Decisão:** o briefing de toda feature nova declara, além do teto da F5, `max_replanejamentos_f6: 1`, e a F1 o repassa como quarto argumento — `planejamento.sh criar <slug> 3 buildx 1`. Planejamento que já existe e é legado (sem as cinco chaves do eixo da F6) continua legado: nenhum `1` é acrescentado, nem na retomada da F1. Daí em diante o buildx lê o retorno da F6 só pelos leitores da sprintx: (1) **rodada ativa** — `replanejar_execucao`, ou `F3`/`F4`/`F5` com `replanejamento_execucao=ativo` — é feature **em execução**: nenhuma pendência, nenhuma feature, a `CONTROL` parada; a retomada segue a sprintx na fase devolvida (linha **S**), provando que a branch só tem checkpoints desde o que abriu a rodada e que `replanejamentos_f6` é o número de rodadas abertas. (2) **`replanejamento_execucao_esgotado`** — a única rodada já consumida e nova necessidade — é terminal próprio da F6: portão terminal da F6, gatilho `replanejamento_execucao_esgotado`, classe `decisao_humana`, regra `replanejamento_execucao_esgotado`, nenhuma rodada nova e nenhuma sucessora (linha **T**). (3) **recusa** — os `motivo=` que `replanejar-execucao` devolve, em duas famílias: operacional (`classes_mistas`, `orcamento_f6_legado`, `orcamento_f6_nao_declarado`, `planejamento_legado`) → `decisao_humana`; contrato (`estado`, `sem_bloqueio_aberto`, `sem_defeito_de_plano`, `fronteira_insegura`) → pare e relate, sem pendência. Com a recusa, a F6 não abre task nova: só o fechamento que materializa a entrega bloqueada. (4) **Precedência sobre a D-36**: `bloqueio_aberto` com todos os abertos `defeito_de_plano` só é `trabalho_novo` quando a pasta da feature commitada no mesmo `HEAD` diz que o retorno ainda abriria; esgotado → `entrega_bloqueada/causa_bloqueio_aberto/replanejamento_execucao_esgotado`, recusado por orçamento → `.../replanejamento_execucao_recusado/<motivo>`, ambos `decisao_humana`; rodada ativa ou planejamento que a sprintx recusa → pare.

**Alternativas descartadas:** (1) reutilizar `orcamento_f5_esgotado` para o esgotamento da F6; (2) deixar a sprintx assumir `1` quando o quarto argumento falta; (3) manter `defeito_de_plano` → `trabalho_novo` incondicional; (4) tratar a rodada ativa como bloqueio, ou retomá-la pela F6; (5) ler o `00-PLANEJAMENTO.md` com um parser do buildx, ou executar a transição da sprintx para descobrir a resposta; (6) transformar recusa de contrato em pendência.

**Por quê:** (1) os dois terminais dizem orçamentos diferentes, com remédios diferentes — reprovar três planos antes de executar não é o mesmo que precisar mudar duas vezes um plano aprovado —, e a tabela `[item N]` do orçamento da F5 não tem o que dizer sobre o segundo. (2) o `1` é decisão de quem aciona a sprintx; escondido no script, uma sprintx standalone ganharia um retorno que ninguém declarou (DS-141). (3) a sucessora seria outra feature com orçamento novo: o jeito exato de contornar o teto de replanejamento da própria feature. Com orçamento restante e nada recusado, a regra da D-36 continua a mesma. (4) durante a rodada a feature está sendo corrigida pela dona dela; bloqueá-la mataria o trabalho concluído que o retorno existe para preservar, e retomá-la pela F6 executaria sobre o plano que já se sabe errado. (5) a mesma evidência precisa dar a mesma leitura nas duas camadas (D-36): o buildx usa `bloqueios.sh listar` e `planejamento.sh fase` — leitores — na ordem que o `replanejar-execucao` declara, e o harness prova, estado por estado, que a resposta dele e a da sprintx real coincidem. (6) um erro de contrato não é o produto pedindo decisão: vira pendência e o humano recebe uma pergunta que a camada errou ao fazer.

**Risco assumido:** a recusa não grava nada no Git; até o fechamento, só o `00-BLOQUEIOS.md` do worktree mostra o defeito aberto. A restrição da linha **F** o lê de lá — e só restringe, nunca move a `CONTROL`. A fronteira segura é verificada pelo buildx com a mesma regra da DS-145, sobre o worktree vivo.

**O que invalida:** a sprintx gravar a recusa em estado durável — aí ele decide, e a leitura do worktree sai —; um motivo novo de recusa, que ganha família por decisão, nunca por semelhança de nome; ou o buildx passar a declarar mais de uma rodada.

---

## D-38 — A recusa do retorno da F6 é estado durável da sprintx, e o buildx a lê do commit

*(Consome a sprintx P0.2-B fechada (`c8bf65f`, DS-147 e DS-148). É o que a D-37 declarou como invalidante dela — "a sprintx gravar a recusa em estado durável — aí ele decide, e a leitura do worktree sai": a D-37 continua registrada, com tudo que decidiu; o **Risco assumido** dela é o único ponto superado, e esta decisão o substitui. Acrescenta os gatilhos `replanejamento_execucao_recusado` e `orcamento_f5_esgotado_durante_replanejamento_execucao`. Não muda nenhum enum de classe: continuam três.)*

**Decisão:** a recusa **operacional** do `replanejar-execucao` não é mais uma resposta de sessão: a sprintx grava o estado terminal `replanejamento_execucao_recusado`, com o motivo em `recusa_replanejamento_f6`, e faz o checkpoint. O buildx passa a consumi-la **do estado commitado**, e só de lá:

1. **Um leitor só, sobre o commit.** O terminal da F6 é lido pela sprintx sobre a pasta da feature **commitada** no `HEAD` dela, extraída numa raiz sem Git (`planejamento.sh fase` + `bloqueios.sh listar`). Não depende de worktree, de rastro (`docs/eventos/`), de sessão, nem de reexecutar `replanejar-execucao`. A leitura vale para os três terminais da F6: `replanejamento_execucao_esgotado`, `replanejamento_execucao_recusado` e `orcamento_esgotado` **com rodada aberta**.
2. **Matriz estado/motivo → classe.** `replanejamento_execucao_recusado` com `recusa_replanejamento_f6` ∈ {`classes_mistas`, `orcamento_f6_legado`, `orcamento_f6_nao_declarado`, `planejamento_legado`} → gatilho `replanejamento_execucao_recusado`, classe `decisao_humana`, regra `replanejamento_execucao_recusado/<motivo>`, `causa: <motivo>`, **nenhuma sucessora**. O enum é o da sprintx, conferido contra o contrato dela; valor fora dele **falha fechada** — nunca vira `decisao_humana` "normal", nunca é adivinhado pelo `B-NN`, nunca sai da prosa dos bloqueios.
3. **Precedência.** Um terminal da F6 commitado no mesmo `HEAD` vence **toda** regra da entrega bloqueada, inclusive `bloqueio_aberto` + `defeito_de_plano` → `trabalho_novo` (D-36) e qualquer outra `causa`: a regra fica `entrega_bloqueada/causa_<causa>/replanejamento_execucao_recusado/<motivo>`, `decisao_humana`. Uma recusa durável não gera FT nova para contornar a política da sprintx sobre a própria feature.
4. **`orcamento_esgotado` dentro de uma rodada da F6** — a F5 consumiu o orçamento restante enquanto o plano voltava à revisão — é terminal **próprio**: gatilho `orcamento_f5_esgotado_durante_replanejamento_execucao`, `decisao_humana`, nenhuma sucessora, branch e commits válidos preservados. A evidência de que a rodada existia é `bloqueios_replanejamento_f6` preenchido no mesmo commit (`replanejamento_execucao=ativo` na saída da sprintx), nunca memória de sessão. Sem rodada aberta, `orcamento_esgotado` continua sendo o caso normal do P0.1: portão terminal pré-F6, gatilho `orcamento_f5_esgotado`, tabela `[item N]`, `alta_qualidade_plano` → `trabalho_novo`, intacto.
5. **A linha F.** Com `defeito_de_plano` aberto, o único passo da F6 é o `replanejar-execucao` do passo 3 dela — que agora **grava** o resultado, qualquer que seja ele. `F:so_fechamento` deixa de existir: o buildx não precisa mais que a mergex feche a entrega para poder classificar a recusa.
6. **O portão terminal da F6 dispensa o worktree.** As provas A–D, H6 e J6 continuam; **E** e a confirmação viva pela sprintx só se aplicam quando existe worktree — e aí ele tem de estar limpo e concordar. Worktree perdido, ou retomada só com a branch, não apaga o terminal: a matriz lê o commit **antes** das linhas H e I.
7. **Erro de contrato continua fora.** `estado`, `sem_bloqueio_aberto`, `sem_defeito_de_plano`, `fronteira_insegura`, registro/schema inválido, evidência contraditória e task concluída alterada não são gravados pela sprintx e **nunca** são inferidos como recusa pelo buildx: **PARE E RELATE**, nenhuma PEND, nenhum commit na `CONTROL`.

**Alternativas descartadas:** (1) manter a leitura do `00-BLOQUEIOS.md` do worktree como fonte da recusa, agora com o estado durável ao lado; (2) reexecutar `replanejar-execucao` na retomada para descobrir o motivo; (3) manter o `orcamento_esgotado` dentro da rodada no caminho genérico do P0.1 (`orcamento_f5_esgotado` → possivelmente `trabalho_novo`); (4) usar `orcamento_f5_esgotado` com uma variante na `regra_aplicada`, sem gatilho próprio; (5) manter a lista de motivos apenas na sprintx, aceitando no buildx qualquer valor que ela devolva; (6) reaproveitar o gatilho `replanejamento_execucao_esgotado` para a recusa, distinguindo pelo motivo.

**Por quê:** (1) duas fontes para o mesmo fato é a receita de divergirem; o worktree é o lugar onde a evidência morre com o diretório, e o commitado é o único que sobrevive a clone, sessão nova e máquina nova. (2) reexecutar uma transição para *descobrir* um estado é efeito colateral como leitura — e a sprintx agora responde a mesma coisa sem gravar nada, então a pergunta não precisa mais ser feita. (3) a regra normal criaria uma feature sucessora a partir da `CONTROL`, jogando fora as tasks concluídas e os commits válidos da branch: exatamente o trabalho que o retorno da F6 existe para preservar. (4) gatilho é o que o `MAPA.md` mostra e o que o B5 indexa; esconder um terminal diferente dentro da regra de outro faz o painel mentir. (5) enum divergente em silêncio é como um valor novo da irmã vira classe errada aqui; conferir a lista contra o contrato fixado transforma isso em falha de teste, não em decisão inventada. (6) são perguntas diferentes para o humano — "o orçamento acabou" e "o retorno não pôde abrir, por este motivo" —, e a `causa` do segundo é o motivo.

**Risco assumido:** o buildx mantém uma cópia do enum de `recusa_replanejamento_f6` (quatro motivos, a família operacional). Ela é conferida contra o `references/00-schema.md` da sprintx fixada a cada rodada do harness: motivo novo lá quebra o pin aqui, e ganha família por decisão — nunca por semelhança de nome. Com `defeito_de_plano` aberto e o retorno ainda não chamado, a escolha do passo da F6 viva continua lendo o `00-BLOQUEIOS.md` do worktree; essa leitura **só restringe** (nunca abre task, nunca move a `CONTROL`) e não classifica nada.

**O que invalida:** a sprintx passar a gravar também a recusa de contrato (aí a família contrato deixaria de ser "nada gravado" e precisaria de decisão própria); um motivo novo de recusa; o buildx passar a declarar mais de uma rodada de replanejamento da execução; ou a sprintx deixar de manter `bloqueios_replanejamento_f6` preenchido no `orcamento_esgotado` de dentro da rodada — que é a evidência durável do item 4.

---

## D-39 — A prova E admite exclusivamente sujeira explicada por desvio terminal commitado

*(Reconcilia o contrato do buildx com o da mergex fixada — DM-13 e `references/01-commits.md`. Não altera a mergex, não altera a sprintx, não toca nenhum enum de classe, nenhum gatilho e nenhuma decisão anterior.)*

**Decisão:** **a prova E admite exclusivamente sujeira explicada por desvio terminal commitado; a cópia de trabalho da `ENTREGA.md` nunca concede autorização.**

1. **A regra.** A árvore da feature está limpa, **exceto** pelos caminhos registrados em `desvios` na `ENTREGA.md` **terminal e commitada** da própria feature. Sujeira fora desse conjunto: **pare**.
2. **A fonte.** `git show feature/<slug>:docs/entregas/<slug>/ENTREGA.md` — o mesmo endereço do passo 6. O arquivo da árvore de trabalho não autoriza nada, **nem a si próprio**: commit com `desvios: []`, cópia local editada para declarar `src/x.ts` e `src/x.ts` sujo é **pare**.
3. **Quando a exceção existe.** Só sobre um terminal do E8 — `entregue` · `pronto` ou `bloqueado` · `bloqueado` (D-35). Entrega ausente ou `aberto`: limpeza **estrita**. Registro terminal inválido com árvore suja: pare por contrato.
4. **Subconjunto, não igualdade.** `DIRTY ⊆ DESVIOS`. Desvio declarado que já não está sujo não é erro: a mergex preserva `desvios` "enquanto continuarem verdadeiros", e a filtragem é do E0 de uma retomada, que pode ser muito anterior a esta leitura.
5. **Casamento exato**, byte a byte, sobre `git status --porcelain -z --untracked-files=all`. Sem prefixo, sem substring, sem diretório implícito. Renomeado traz os dois caminhos, e os dois precisam estar declarados.
6. **Stage não é autorizado por desvio**, nunca. O desvio da mergex fica na árvore e jamais entra no índice; a regra do índice continua vencendo.
7. **Desvio não é bypass.** A prova responde "esta sujeira está explicada?", não "esta sujeira é segura". Nenhum outro gate é afrouxado.
8. **Nenhuma allowlist de artefato de método.** Artefato de método sujo sem desvio formal é pare.
9. **Sem worktree, a prova não se aplica** (código 2), como já vale no portão terminal da F6 (D-38). Árvore perdida não é árvore limpa; A–D e F, todas sobre commits, continuam sendo o que autoriza o fast-forward.
10. **Duas das três ocorrências continuam estritas por construção** — o portão terminal pré-F6 (o E0 nunca rodou) e o portão terminal da F6 (a prova H6 exige entrega ausente ou `aberto`). A substituição não é textual: a semântica é do ponto do fluxo.

**Alternativas descartadas:** (1) manter "qualquer sujeira é contradição" e deixar a feature com desvio parar no passo 7; (2) aceitar `git status` sujo genericamente depois de uma entrega terminal; (3) ler a lista da `ENTREGA.md` da árvore de trabalho, que é a cópia que está ali do lado; (4) exigir igualdade `DIRTY == DESVIOS`; (5) resolver o caso com uma allowlist de `docs/**` e artefatos de método; (6) criar exceção na prova para `.expx/` e `docs/eventos/`.

**Por quê:** (1) a mergex **manda** deixar o arquivo na árvore e registrá-lo (DM-13) — apagar descartaria trabalho de alguém e commitar violaria a regra 4 dela. Parar ali faria o buildx barrar exatamente o caso que a irmã construiu para não perder trabalho, e o contrato do buildx estaria afirmando que um estado legítimo do ecossistema é contradição. (2) apagaria a única coisa que a prova E existe para pegar: trabalho fora do plano que ninguém registrou. A exceção precisa ser **nominal** — este caminho, declarado neste commit —, não categórica. (3) é a falha central: uma edição local que se autoriza não é evidência, e o que o fast-forward carrega são commits, não o disco. (4) puniria a direção segura — uma árvore mais limpa que a declarada —, e o schema da mergex não promete presença física no instante da leitura. (5) esconderia divergência real em vez de descobri-la, e é justamente sobre artefato de método que o C7 vai provar quem commita e quando. (6) o contrato já declara esses caminhos derivados e não versionados: o lugar da correção é o `.gitignore` do template, não uma exceção na prova — exceção na prova valeria também para um `docs/eventos/` que alguém versionou de propósito.

**Risco assumido:** a prova E passa a depender de um leitor executável do buildx (`scripts/prova-e.sh`, o primeiro da skill) e de uma cópia do formato de `desvios` — lista de fluxo numa linha, como a mergex a grava. Formato novo lá quebra o leitor aqui e vira falha de teste, não autorização silenciosa: qualquer forma que não seja `[...]` numa linha responde `desvios_invalidos` e **para**. Caminho que contenha vírgula é indistinguível de dois caminhos nesse formato — limitação herdada do kind `entrega`, que **falha fechada** (nada casa, a prova para).

**O que invalida:** a mergex mudar a semântica de `desvios` para "todo desvio já ocorrido", inclusive os resolvidos (aí subconjunto deixaria de ser a leitura certa e a assimetria precisaria de decisão nova); `desvios` deixar de ser lista de caminhos exatos, ou ganhar entrada de diretório; a mergex passar a deixar desvio em stage; ou o buildx passar a ter um ponto do fluxo em que a prova E roda **depois** de uma entrega terminal sem que o passo 7 a cubra.

---

## D-40 — A fronteira segura do retorno da F6 é da sprintx, e o parcial seguro não é parada

*(Consome a sprintx `253b592` — DS-156, `parciais_replanejamento_f6`. Supera, na D-37, só a última frase do **Risco assumido** — "a fronteira segura é verificada pelo buildx com a mesma regra da DS-145" — e, na linha **F** do `/buildx-retomar`, só o "produto sujo no worktree: pare e relate". Não muda enum de classe, gatilho, motivo de recusa, nem a família de `fronteira_insegura`, que continua **contrato**.)*

**Decisão:** o buildx **não** pré-julga a fronteira do `replanejar-execucao`. Com `defeito_de_plano` aberto e o retorno `disponivel`, a linha **F** manda o passo 3 da F6 com ou sem produto sujo; a sprintx decide:

1. **Parcial seguro.** O que a task bloqueada já escreveu — declarado só nela, sem stage, sem segredo, `??`/` M`/` D` — a sprintx preserva: grava `path`, `task`, `estado` e `hash` em `parciais_replanejamento_f6` no checkpoint que abre a rodada, e o arquivo fica sujo na árvore. A rodada é a de sempre (linha **S**); fechada pela F5, a lista volta a `[]` e o arquivo segue sujo até o E1 da task reaberta, que o commita como produto dela.
2. **O resto é recusa de contrato.** Sujeira de irmã, de task concluída, compartilhada, em stage ou com segredo: `fronteira_insegura` (`nao_preservaveis=` diz qual e por quê), código `2` — **pare e relate**, sem PEND, sem commit na `CONTROL`, nada limpo.
3. **A integridade do parcial também é dela.** O buildx não lê `parciais_replanejamento_f6` para decidir nada — presença da chave não prova coisa alguma. Quem revalida é a sprintx (`fase`, `avanca`, fechamento da rodada): `perdido` ou `divergente` é `PARAR`, e na retomada a linha **S** vira **pare e relate**. O buildx nunca reconstrói, restaura, stasha, reseta, nem transforma o parcial em commit intermediário.

**Alternativas descartadas:** (1) manter a regra da DS-145 no buildx — nenhum produto sujo antes do passo 3; (2) copiar para o buildx a regra de preservação da DS-156 (donos, estado mecânico, segredo) e decidir antes da sprintx; (3) aceitar o parcial pela presença de `parciais_replanejamento_f6` no `00-PLANEJAMENTO.md`, sem a revalidação da sprintx.

**Por quê:** (1) o fluxo TDD real escreve o teste da task **antes** de descobrir o defeito de plano: com a regra antiga o buildx pararia exatamente o estado que a sprintx passou a declarar retomável, e a única saída seria apagar o teste ou commitá-lo fora do E1 — as duas proibidas. (2) duas implementações da mesma fronteira divergem na primeira mudança de uma delas; foi assim que a DS-145 ficou viva aqui depois de morta lá. (3) a chave é o registro do que foi preservado, não a prova de que continua igual: hash, estado e dono só a sprintx confere, contra a árvore, a cada transição.

**Risco assumido:** a retomada da linha **F** manda o `replanejar-execucao` sem antecipar a recusa; a recusa de contrato só aparece na resposta dele. Como ela não grava nada (DS-148), o custo é uma chamada que devolve `fronteira_insegura` e para — o mesmo desfecho de antes, com a decisão no dono.

**O que invalida:** a sprintx devolver a verificação da fronteira a quem a chama; `fronteira_insegura` virar recusa durável (aí ganha família por decisão nova, D-38); ou a sprintx passar a mover, limpar ou commitar o parcial por conta própria.
