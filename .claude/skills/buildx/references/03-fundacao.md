# B2 — Fundação

Transformar um diretório vazio num projeto que se instala, sobe, testa e tem convenções escritas — **antes de uma linha de código de negócio existir**.

Entrada: `docs/projeto/PROJETO.md` e `PREMISSAS.md` do B1. Saídas: repositório inicializado, suíte Expx instalada, esqueleto testável, `docs/stack/CONVENCOES.md`.

O B2 é a etapa mais mecânica do buildx e a que mais dá errado quando pulada. A primeira sprint do sprintx (regra 13: "a primeira sprint entrega a capacidade de testar") assume que existe um projeto onde escrever teste. O B2 é quem entrega essa suposição.

## Passo 1 — Repositório e a branch do projeto

Se não houver `.git` no diretório de trabalho nem em nenhum ancestral, inicialize aqui. O `.gitignore` vem do template, no Passo 5, e já cobre segredo, `node_modules`, o arquivo do banco e o client gerado — mas ele precisa estar no lugar **antes do primeiro commit**, para que nada sensível chegue a ter estado versionado. Se for commitar antes do Passo 5, commite vazio.

Nunca versione: `.env`, `node_modules/`, o arquivo `.db` do SQLite, artefatos de build, o índice do memox.
Sempre versione: `.env.example`, `.expx/expx-lock.json`, as migrations, a seed de demonstração.

### 1.1 — Determinar e persistir a branch principal

Antes de criar qualquer coisa, descubra o **nome** da branch principal **deste** repositório:

```
git symbolic-ref --short refs/remotes/origin/HEAD    # devolve: origin/main
```

Esse comando devolve `origin/main`, não `main`. **Remova o prefixo `origin/`** e fique com o nome puro. Sem remoto, ou sem `origin/HEAD` definido:

```
git branch --show-current                            # devolve: main
```

O que é gravado é sempre o nome puro:

| Grave | Nunca grave |
|---|---|
| `Branch principal: main` | `Branch principal: origin/main` |
| | `Branch principal: refs/remotes/origin/main` |

Esse nome vai para o `CONVENCOES.md` no Passo 6, na linha `Branch principal`. **Ele é gravado, não lembrado:** o B6 vai precisar dele para abrir o PR final, possivelmente em outra sessão, e `origin/HEAD` pode não existir mais.

### 1.1.1 — O baseline da principal, e só ele

Commit inicial vazio na branch principal. É o **baseline** do projeto: o ponto de onde a branch do projeto sai e para onde o PR final vai voltar.

Havendo remoto, a principal precisa existir **no servidor** — senão o PR final do B6 não tem base:

```
git ls-remote --heads origin <principal>
```

| Resultado | O que fazer |
|---|---|
| A branch já existe no remoto | **Nada.** Não invente commit, não empurre |
| Não existe | Publique **apenas o baseline**: `git push -u origin <principal>` |

Depois disso a principal **congela**: nenhum commit de produto, nenhum push adicional, até o PR final ser mergeado por uma pessoa. Publicar o baseline não fere "a principal fica intocada durante o projeto" — ele é o nascimento do projeto, não trabalho dele.

### 1.2 — Criar a branch do projeto

```
git switch -c buildx/<projeto_id>
```

O `<projeto_id>` é o mesmo do frontmatter do `PROJETO.md` (`references/00-schema.md`), então a branch é **derivável** a qualquer momento, em qualquer sessão, sem depender de memória.

**Daqui em diante essa branch é o checkout de controle**, e o checkout de controle **nunca troca de branch** durante o B3, o B4 e o B5. É nela que vivem `docs/projeto/` e `docs/stack/`, é nela que o template é commitado, e é ela que recebe cada feature entregue — a **árvore acumulada do produto**.

**A publicação dela não acontece agora**, e sim no Passo 7, quando a fundação inteira já estiver commitada. Publicar uma branch que ainda vai receber o template, o `docs/projeto/` e o `docs/stack/` só criaria uma janela em que local e remoto divergem — e é exatamente essa divergência que o primeiro portão do B4 barra, na `FT-01`.

**Por que a branch nasce aqui, e não no B4.** A base de toda feature é ela; se ela só existisse na primeira integração, a `FT-01` nasceria da principal e o produto começaria desalinhado. E é ela que a mergex usa como base do PR de cada feature — por isso precisa estar no remoto **antes da primeira feature**, o que o Passo 7 garante.

As branches de feature vêm depois, uma por feature, **abertas pela F1 do sprintx no B4** a partir de `buildx/<projeto_id>`, junto com o worktree daquela feature (`../<repo>--<slug>`). O buildx não abre branch de feature e não invoca `mergex-abrir`.

## Passo 2 — Escolher a stack

O `PROJETO.md` manda; na omissão, valem os padrões da casa de `02-lacunas.md`:

| Eixo | Padrão | Vem de |
|---|---|---|
| Arquitetura | três camadas, fronteira explícita | P-1 |
| Framework | Next.js, TypeScript, App Router | P-2 |
| Banco | SQLite em arquivo, migrations versionadas | P-3 |
| Autenticação | JWT, e-mail e senha, hash forte | P-4 |
| Interface | design system do VS Code, Dark+ e Light+ | P-6 |
| Telas obrigatórias | painel inicial, cadastro de usuários, perfil e troca de senha | P-9 |

Cada escolha vira premissa em `PREMISSAS.md` com `origem: decisao_de_stack` — inclusive as que vieram do padrão da casa. O humano precisa poder ler, num arquivo só, tudo que foi decidido em nome dele.

**Na omissão, o template já é essa decisão inteira.** Ele materializa P-1 a P-6 de uma vez, e o Passo 5 só o copia. Registre as premissas do mesmo jeito — o que muda é que elas descrevem um código que já existe e já passa, não uma intenção.

**Se o usuário indicou stack**, a dele vence sem discussão, e a premissa registra que houve indicação explícita.

## Passo 3 — Instalar a suíte Expx

Padrão P-8. Roda **antes do esqueleto de código**: o projeto se instala antes de se construir.

```bash
npx expxdev init
```

A instalação precisa deixar, versionados: `.expx/expx-lock.json`, `.expx/marketplace/plugins/expx/`, `.claude/` e `.opencode/`. A suíte completa — `sprintx`, `runx`, `mergex`, `stackx`, `memox`, `legadox`, `prodx` e `buildx`.

| Situação | O que fazer |
|---|---|
| instalação bem-sucedida | verifique o lock, siga |
| já instalado, lock íntegro | não reinstala; segue |
| já instalado, lock divergente | não sobrescreve em silêncio: registra em `RECURSAO.md` como `decisao_humana` e segue com o que está |
| falha de rede ou de instalação | **bloqueio real do B2.** Pare, diga o que falhou e como instalar à mão. Sem a suíte não existe B4 |

Esta é a única parada do modo autônomo que não é o fim, e ela é honesta: sem sprintx e mergex o buildx não tem o que orquestrar.

## Passo 4 — Skill de frontend design

Padrão P-7, e só se o projeto tiver interface.

1. Skill de frontend design disponível na sessão → use no B4, nada a fazer aqui.
2. Não disponível → busque no repositório oficial da Anthropic e instale em `.claude/skills/` **do projeto**, nunca no ambiente global do usuário.
3. Falhou → **não é bloqueio.** Registre a premissa dizendo que o acabamento sairá sem a skill, com o P-6 aplicado à mão — os tokens e a estrutura de `08-design-system.md` bastam —, e siga.

Nunca instale nada além dessa skill, nunca de fonte que não seja o repositório oficial, nunca em laço de tentativas.

## Passo 5 — Copiar o template

O buildx **não escreve o esqueleto: ele copia.** `assets/../template/` é um
projeto de verdade, versionado nesta skill, que sobe, testa e já traz o P-9
implementado. O B2 o copia para a raiz e verifica.

```
cp -R <skill>/template/. <raiz do projeto>/
```

O que vem junto:

| Camada | Conteúdo |
|---|---|
| Configuração | `package.json` com `dev`/`build`/`test`/`lint`, TypeScript estrito, ESLint, Vitest, `.env.example` |
| Banco | SQLite via Prisma, migration inicial versionada, seed de demonstração (P-5) |
| Autenticação | e-mail e senha, hash bcrypt, sessão JWT em cookie `httpOnly`, papéis `admin` e `usuario` (P-4, L2, L3, L4) |
| Interface | tokens do VS Code nas duas variantes, layout de regiões, alternador de tema (P-6) |
| Esqueleto | as quatro telas do P-9, com a navegação montada |
| Testes | a suíte que prova tudo acima, verde |

**Por que copiar em vez de gerar.** Gerar o mesmo esqueleto a cada projeto
custa milhares de tokens e — o que importa mais — sai diferente a cada vez.
O template é determinístico: o projeto número um e o número trinta recebem
exatamente o mesmo código, já verificado. E o que ele traz não depende do
que o usuário pediu; é a moldura, idêntica em todo sistema com login.

**O TDD não é violado, e a fronteira é esta:** o template é código que já foi
provado — tem suíte verde e CI próprio. O que **depende do pedido do
usuário** continua nascendo sob TDD no B4, sem exceção. O template não traz
nenhuma entidade de domínio, nenhuma regra de negócio e nenhum item extra de
navegação, justamente para que essa fronteira não se borre.

### Adaptar ao projeto

Depois de copiar, três ajustes — e só esses:

| O quê | Onde |
|---|---|
| nome do projeto | `package.json`, e o `<title>` em `src/app/layout.tsx` |
| `JWT_SECRET` | gerado e gravado no `.env` local, **nunca** no `.env.example` nem em artefato |
| primeiro commit | o template inteiro, **em `buildx/<projeto_id>`**, antes de qualquer feature |

Não renomeie as pastas das três camadas nem as rotas do P-9: o
`CONVENCOES.md` do Passo 6 as registra, e o B6 as confere pelo caminho.

### As quatro verificações

Copiado e ajustado, o critério de saída é binário e verificável numa máquina
limpa — o mesmo de sempre:

```
instalar dependências → build passa → teste passa → lint passa → o projeto sobe
```

Se qualquer um falhar, o B2 não terminou, e a causa é uma de duas: o ajuste
acima saiu errado, ou o template regrediu. A segunda é grave — significa que
todo projeto novo nasceria quebrado —, e o lugar de corrigir é o repositório
da skill, com o CI do template, não este projeto.

Não avance para o B3 com um esqueleto que não sobe: toda feature do B4
herdaria o defeito, e o custo de descobrir isso na feature sete é sete vezes
maior.

## Passo 6 — O stackx invertido

Aqui o stackx inverte de papel, e isso é deliberado.

O stackx normal **descobre** convenção varrendo o repositório em busca de evidência, e grava cada regra com o arquivo e a linha que a provam. Num projeto que acabou de nascer não há evidência a encontrar: o código que provaria a convenção é o código que ainda não foi escrito.

Então o buildx **decide** e o stackx **registra**:

| Campo do `CONVENCOES.md` | stackx normal | B2 do buildx |
|---|---|---|
| origem da regra | `src/arquivo.ts:42` | `decidido_pelo_buildx` |
| natureza | descrição do que o código faz | prescrição do que o código deve fazer |
| quando revisar | a cada `stackx-atualizar` | **na primeira feature entregue** |

O `CONVENCOES.md` do B2 cobre, no mínimo: onde mora o teste e como se chama, como o banco é isolado entre testes, os comandos de teste/lint/build que funcionam de verdade, as três camadas e quem pode chamar quem, como erro é sinalizado, como configuração é lida.

### A seção de versionamento — o contrato que carrega a base

Além disso, e **obrigatoriamente**, a seção de versionamento declara duas linhas distintas:

```
Branch principal: <a detectada no Passo 1.1>
Branch base: buildx/<projeto_id>
```

| Linha | Para quê | Quem lê |
|---|---|---|
| `Branch principal` | o destino do PR final, e o valor para o qual o B6 devolve a base no fim | só o buildx |
| `Branch base` | **a base de onde toda feature nasce** | a F1 do sprintx (primeira precedência dela) e o E0 da mergex |

As duas entram como **convenção estabelecida, nunca marcada `PROPOSTA`** — ponto marcado como proposta, por contrato das irmãs, não governa: viraria aviso, a F1 cairia em `origin/HEAD` e toda feature nasceria da principal, que é exatamente o defeito que esta seção existe para corrigir.

**É assim que a base viaja, e não há outro transporte.** O buildx não passa argumento à sprintx, não cria campo no `ORQUESTRADOR.md` e não toca no `expx-schema`: ele escreve uma convenção que as duas irmãs **já leem hoje**, e que sobrevive à morte da sessão porque está no disco.

**Estas duas linhas são do contrato do buildx.** A revisão de convenções da primeira feature (Passo 8 do B4) e qualquer `stackx-detectar` posterior **não as alteram** — elas não descrevem o código, descrevem como o projeto é montado. Quem as muda é o B6, uma vez, ao devolver `Branch base` ao valor de `Branch principal`.

**Se o repositório já trouxer uma `Branch base` observada** — projeto que não nasceu aqui —, não sobrescreva em silêncio: registre a premissa dizendo que a base do projeto passou a ser a do buildx durante a execução, e o valor anterior, para o B6 restaurar o certo.

**A revisão da primeira feature.** Depois que a primeira feature do B4 for **integrada**, o código real existe **aqui mesmo**, no checkout de controle — o fast-forward o trouxe. É sobre ele que o `stackx-detectar` normal roda. O buildx compara com o que decidiu e converte cada regra confirmada de `decidido_pelo_buildx` para a evidência real. Regra que o código contradisse vira achado: ou o código se ajusta, ou a convenção estava errada e é corrigida. Este é o momento em que o projeto deixa de acreditar no buildx e passa a acreditar em si mesmo.

**Duas linhas ficam de fora dessa revisão, sempre:** `Branch principal` e `Branch base`.

## Passo 7 — Fechar a fundação sincronizada

O B2 não termina quando os arquivos existem: termina quando eles estão **commitados e publicados**. É a pré-condição do primeiro portão do B4, e o lugar mais barato de garantir.

1. **Commite tudo que a fundação produziu**, na branch do projeto: o template, `docs/projeto/PROJETO.md` e `PREMISSAS.md`, `docs/stack/CONVENCOES.md`, `.expx/` versionável, `.claude/` e `.opencode/`. Por caminho explícito — nunca `git add .` para varrer o que não se conferiu.
2. **Confirme a árvore limpa:**
   ```
   git status --porcelain
   ```
   Saída vazia. Sobrou algo versionável, commite; sobrou algo que não deve ser versionado, corrija o `.gitignore` antes de seguir.
3. **Havendo remoto, publique — uma vez, e agora:**
   ```
   git push -u origin buildx/<projeto_id>
   ```
4. **Prove a sincronização:**
   ```
   git rev-parse HEAD
   git rev-parse origin/buildx/<projeto_id>
   ```
   Os dois iguais. Diferentes, ou push rejeitado: **pare e relate** — sem `--force`, sem `pull`, sem reconciliar.

Sem remoto: os passos 3 e 4 são `n/a`, e a fundação fecha local. A integração do B4 continua funcionando; o que deixa de existir são os pull requests.

**Por que isto é um passo e não uma nota de rodapé.** Se a fundação ficar só no local, o primeiro portão do B4 (`HEAD == origin/buildx/<projeto_id>`) falha já na `FT-01`, e o projeto para antes da primeira feature — com a causa escondida três passos atrás.

## Critério de saída do B2

Todos verdadeiros:

- repositório inicializado, `.gitignore` correto, nada sensível versionado
- a branch principal foi detectada pelo nome puro (sem `origin/`) e **gravada** no `CONVENCOES.md`
- a principal existe no remoto — já existia, ou o baseline foi publicado — e não recebeu nada além do baseline
- `buildx/<projeto_id>` existe e é o checkout de controle
- **a fundação inteira está commitada, a árvore está limpa, e `HEAD == origin/buildx/<projeto_id>`** (ou não há remoto)
- a seção de versionamento declara `Branch principal` e `Branch base`, como convenção estabelecida
- suíte Expx instalada, lock versionado, `.claude/` e `.opencode/` presentes
- template copiado, com o nome do projeto ajustado e o `JWT_SECRET` gerado
- numa máquina limpa: dependências instalam, build passa, teste passa, lint passa, projeto sobe
- a suíte herdada do template passa inteira
- `docs/stack/CONVENCOES.md` existe, com toda regra marcada `decidido_pelo_buildx`
- toda escolha de stack registrada em `PREMISSAS.md`
- nenhuma entidade de domínio criada, nenhuma regra de negócio escrita

## Erros que esta etapa comete

- **Escrever de novo o que o template já traz.** Autenticação, painel, cadastro de usuários e perfil vêm prontos e testados. Reimplementá-los gasta tokens para produzir uma variação não verificada do que já estava verificado.
- **Acrescentar entidade de domínio ao template copiado.** "Já que estou aqui, deixo a tabela de clientes" é o erro simétrico: aquilo depende do pedido do usuário, e o que depende do pedido nasce no B4 sob TDD. O template para no `Usuario`.
- **Mexer no template do projeto para consertar um defeito do template da skill.** Se a suíte herdada falha numa máquina limpa, o defeito é da skill e afeta todo projeto futuro. Corrija lá, com o CI, e recopie.
- **Instalar a suíte depois do código.** Inverte a ordem que dá sentido ao P-8, e o memox perde o histórico da construção.
- **Aceitar esqueleto que "quase" sobe.** Quatro verificações binárias; três não bastam.
- **Gravar convenção sem marcar a origem.** Uma regra `decidido_pelo_buildx` lida como se fosse detectada faz o projeto acreditar que tem evidência onde só tem opinião.
- **Versionar `.env` ou o arquivo do banco.** Uma vez versionado, sai do histórico com muito mais trabalho do que custou não colocar.
- **Construir o projeto na branch principal.** Ela recebe o commit inicial e nada mais. Template, `docs/projeto/`, `docs/stack/` e todas as features vivem em `buildx/<projeto_id>` — é isso que mantém a principal intocada até o PR final.
- **Marcar a `Branch base` como `PROPOSTA`.** Proposta não governa: a F1 a ignora, cai em `origin/HEAD`, e as features voltam a nascer da principal sem que nada acuse o erro.
- **Esquecer de gravar a `Branch principal`.** O B6 precisa dela para o PR final, e `origin/HEAD` pode não existir na sessão que fechar o projeto.
