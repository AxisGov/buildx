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

*Nota posterior:* o "oito" é o contrato de quando esta decisão foi tomada. Ele passou a onze campos com a D-23 (`modulos_candidatos`, `fatias_candidatas`) e a D-24 (`premissas_realizadas`), ainda bem abaixo do limite de quinze que esta decisão dá como invalidador.

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

## D-19 — Feature dependente se encadeia na branch da predecessora

**Decisão:** a feature cuja predecessora ainda não foi integrada nasce da branch dela — o briefing da F1 leva `base: feature/<predecessora>`, a sprintx abre o worktree ali e repassa a base ao E0 da mergex, e o PR sai empilhado no da predecessora. Predecessoras em cadeias separadas, nenhuma contendo a outra, bloqueiam a feature como `decisao_humana`. O stackx e o B6 leem uma integração local descartável: um worktree da base comum com as branches entregues mergeadas na ordem do `MAPA.md`, sem push.

**Alternativa descartada:** uma branch de integração do projeto, mantida pelo buildx, onde cada feature entregue seria integrada e de onde as novas nasceriam.

**Por quê:** o merge é humano (D-03) e os PRs ficam abertos, então a base comum nunca tem o código das features entregues; uma feature dependente nascida dali constrói sobre o que não existe. Encadear resolve sem que o buildx integre nada: cada PR mostra só o próprio diff, e a ordem de merge é a do mapa. A branch de integração faria o buildx fazer merge — exatamente a fronteira que ele não atravessa — e ainda deixaria ao humano uma segunda integração no fim. Escolha do usuário, a partir do achado do CodeRabbit na AxisGov/login#2.

**O que invalida:** o humano integrar cada PR antes da feature seguinte começar — aí nenhuma predecessora fica pendente, e a base comum basta.

---

## D-20 — A F2 autônoma responde dos três arquivos, conferida contra a `base/` da F1

**Decisão:** as fontes das respostas continuam sendo o `PROJETO.md`, o `PREMISSAS.md` e o `CONVENCOES.md`, e o degrau 4 continua criando premissa. Antes dos degraus, o buildx relê a `base/` que a F1 gravou: cada lacuna de `base/00-LACUNAS.md` vira pergunta, a justificativa cita o arquivo da base que a resposta respeita, e resposta que contradiz a base não vale — a contradição vai para `00-BLOQUEIOS.md` e a pergunta desce como não derivável.

**Alternativa descartada:** acrescentar a `base/` como quarto degrau, uma fonte de respostas ao lado dos três arquivos.

**Por quê:** a `base/` registra o que existe no repositório, não o que o usuário quis; usá-la como fonte de decisão faria o código existente decidir pelo usuário. Ignorá-la, como a regra fazia, deixava a F2 decidir contra fatos já ingeridos — e o próprio sprintx manda a F2 reler a base, transformar lacunas em perguntas e apontar resposta que a contradiz. Achado do CodeAnt na AxisGov/conselhos-municipais#204 (SKILL.md:133).

**O que invalida:** a F1 passar a gravar decisões, e não só fatos, na `base/`.

---

## D-21 — PR não aberto pelo E7 não é entrega

**Decisão:** a feature só fica `entregue` com `pr_url` preenchido no `ENTREGA.md`. Quando o E7 termina sem PR, a feature fica `bloqueada` com o motivo literal do E7: sem ferramenta, sem autenticação ou serviço não suportado é `recurso_externo` (abrir o PR à mão com o `PR.md`, ou autenticar e rodar o `mergex-pr` de novo); PR acima do limite do fatiamento é `decisao_humana` — replanejar dentro do mesmo recorte daria o mesmo PR, e dividir código pronto em PRs ou declarar a exceção mecânica é do desenvolvedor; PR não medido o B5 classifica pelo erro.

**Alternativa descartada:** aceitar o desfecho como a mergex o declara — sucesso — e marcar `entregue`, deixando o "abra à mão" para o relatório final.

**Por quê:** para a mergex, PR não aberto é sucesso porque há um desenvolvedor lendo o relato e abrindo o PR. No modo autônomo ninguém lê até o fim, e o buildx promete PRs abertos, verdes e descritos; uma feature `entregue` sem PR passaria pelo B6 como pronta, e as dependentes se empilhariam numa branch que revisor nenhum vê. Achado do CodeAnt na AxisGov/conselhos-municipais#204 (integracao/mergex.md:11).

**O que invalida:** a mergex passar a tratar PR não aberto como falha, ou o buildx ganhar outro caminho de entrega que não seja PR.

---

## D-22 — A base comum entra pela raiz da cadeia e se propaga

**Decisão:** quando a feature se empilha numa cadeia de predecessoras entregues e outra predecessora já foi integrada, a base comum é mergeada só na raiz da cadeia — a feature cujo PR aponta para a base comum —, e cada branch seguinte, da raiz até a última, recebe merge da anterior, que é a base do PR dela, com push de cada uma. A base de cada PR vem de `gh pr view --json baseRefName`; sem o serviço, do `depende_de` do `MAPA.md`. Conflito em qualquer passo desfaz o merge e bloqueia a feature como `decisao_humana`; cadeia sem PR apontando para a base comum também, porque falta um reapontamento que é do humano.

**Alternativa descartada:** mergear a base comum direto na última predecessora da cadeia, como a regra fazia.

**Por quê:** quando a última predecessora é ela própria empilhada sobre outra feature não integrada, o PR dela compara com a branch dessa outra, não com a base comum; a base mergeada nela entra no diff do PR como mudança dela, e o PR deixa de mostrar só o próprio diff — o que a D-19 promete. Pela raiz, cada merge só traz para a branch a base do próprio PR, e nenhum diff muda. Achado do CodeAnt na AxisGov/buildx#8 (05-construcao.md:32).

**O que invalida:** o serviço passar a atualizar PRs empilhados sozinho, ou o buildx deixar de empilhar (D-19).

---

## D-23 — Os candidatos a módulo são coleção

**Decisão:** a feature registra `modulos_candidatos`, lista JSON dos ids de módulos do catálogo alternativos para o mesmo terceiro (`[]` quando não há), e `fatias_candidatas`, objeto JSON com as fatias de cada candidato (`"<id>": []` quando o candidato não tem fatia que cubra a feature). O B6 oferece a extração quando a lista é vazia. Dois terceiros na mesma feature continuam sendo corte grosso, quebrado pela regra do "e" da entrega.

**Alternativa descartada:** manter o valor único (`modulo_disponivel: <id> | -`) e tratar dois módulos como corte grosso.

**Por quê:** o próprio recorte manda registrar os dois quando há dois módulos para o mesmo problema ("Dois módulos para o mesmo problema"), sem o buildx escolher o fornecedor; o valor único não guardava o segundo, e a regra do corte grosso quebraria uma feature que não deve ser quebrada. Achado do CodeRabbit no katosmv/login#29, decidido pelo dono.

**O que invalida:** o buildx passar a escolher o fornecedor na decomposição, ou o catálogo passar a devolver um módulo só por terceiro.

---

## D-24 — `premissas_realizadas` é campo do contrato da feature

**Decisão:** toda feature do `MAPA.md` declara `premissas_realizadas` (`[PR-NN, ...]` ou `[]`), logo depois de `origem`. O contrato vai a onze campos, na mesma ordem no `04-decomposicao.md`, no `SKILL.md` e no `00-schema.md`, e o `test-campos-do-mapa.sh` confere a ordem nos três. O enum de `origem` fica `descricao | premissa | recursao | template` em todo lugar.

**Alternativa descartada:** deixar a linha "Premissas que realiza" só no `TEMPLATE-MAPA.md`, como texto.

**Por quê:** o template já a renderizava, o briefing do B4 repassa "as `PR-NN` que esta feature realiza" e o B6 cruza toda premissa com ela; fora do contrato, o B3 podia omiti-la e o B6 conferiria contra nada (CodeRabbit no katosmv/login#30, trazido pela sessão do Login; CodeAnt no AxisGov/buildx#14). O `template` faltava no enum do `SKILL.md` e do template, embora a FT-01 nasça com ele.

**O que invalida:** um B6 que deixe de cruzar premissa por feature, ou um mapa que registre as premissas em outro artefato.

---

## D-25 — A seed fecha por padrão, e o mapa registra a consulta ao catálogo

**Decisão:** quatro achados do CodeAnt e do CodeRabbit no katosmv/login#34 (0.12.6 instalada):

- A seed de demonstração exige `SEED_DE_DEMONSTRACAO="permitida"`, que vem no `.env.example` e no ambiente do CI do template, e continua recusando `NODE_ENV=production`. A guarda mora em `prisma/guarda-seed.ts`, testada sem banco, e a seed carrega o `.env`.
- O briefing do B4 normaliza o mapa anterior à D-23 pela mesma regra de compatibilidade do B6.
- A premissa criada no degrau 4 da F2 entra no `premissas_realizadas` da feature que a realiza, antes de a resposta ser gravada.
- Cada feature registra a consulta ao catálogo dela (`consulta_modulex: concluida | indisponivel | nao_aplicavel`; o último na feature que não integra terceiro, em que não há consulta), o 12º campo do contrato, na mesma ordem no `04-decomposicao.md`, no `SKILL.md` e no `00-schema.md`. O B6 só oferece extração quando a consulta daquela feature foi concluída; feature sem o campo (mapa anterior) segue a regra de antes.

**Alternativa descartada:** recusar só `NODE_ENV=production`, como antes. E, para a consulta, um estado único no mapa: a consulta é por feature, e com uma concluída e outra fora do ar qualquer valor global erra uma das duas (revisão do Codex).

**Por quê:** a seed rodada de um shell sem `NODE_ENV` contra o banco de produção criava um administrador com senha pública; fechar por padrão troca isso por uma permissão que só o ambiente local tem. Sem a normalização, o mapa antigo chegava à F1 sem o módulo que o catálogo já tinha indicado. Sem o vínculo, a premissa da F2 aparecia órfã no B6. E a lista vazia não distinguia "o catálogo não tem o módulo" de "o catálogo não respondeu", e uma indisponibilidade virava candidatura a extração.

**O que invalida:** um ambiente de produção que precise da seed de demonstração, ou o catálogo passar a responder por feature, e não pelo mapa.
