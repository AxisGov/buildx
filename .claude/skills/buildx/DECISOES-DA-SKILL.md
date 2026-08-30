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

## D-11 — `expx_tool: buildx` é extensão do contrato

**Decisão:** o buildx grava `expx_tool: buildx`, valor que o `CONTRATO-expx-schema-v1.md` ainda não declara.

**Alternativa descartada:** reusar `sprintx` para não quebrar o contrato.

**Por quê:** reusar mentiria sobre a origem do artefato e quebraria a rastreabilidade que o contrato existe para dar. A extensão é de uma linha e o painel já trata chave inesperada como violação visível, não como rejeição (R6) — então nada quebra enquanto o contrato não for atualizado.

O prodx tem a mesma pendência para os kinds dele. Tratar as duas juntas é o caminho mais barato.

**O que invalida:** nada; é dívida a pagar no repositório do painel.

---

## D-12 — Só o stackx é opcional

**Decisão:** sem prodx, sprintx ou mergex o buildx para e diz como instalar. Sem stackx, degrada e segue. Sem memox, segue. O legadox não participa.

**Alternativa descartada:** implementar um caminho degradado para cada ausência.

**Por quê:** o buildx é 90% orquestração. Rodar sem sprintx significaria reimplementar planejamento, TDD e execução — quatro skills mal, dentro de uma quinta. A dependência dura é a arquitetura, não uma falta de educação.

O stackx é diferente: o que ele faz no B2 é gravar um arquivo que o buildx já decidiu. Perde-se a revisão automática da primeira feature, que é real mas não é estrutural.

**O que invalida:** nada para as três duras. Para o stackx, se a revisão da primeira feature se mostrar decisiva na prática.
