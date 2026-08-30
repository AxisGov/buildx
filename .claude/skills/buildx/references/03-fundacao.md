# B2 — Fundação

Transformar um diretório vazio num projeto que se instala, sobe, testa e tem convenções escritas — **antes de uma linha de código de negócio existir**.

Entrada: `docs/projeto/PROJETO.md` e `PREMISSAS.md` do B1. Saídas: repositório inicializado, suíte Expx instalada, esqueleto testável, `docs/stack/CONVENCOES.md`.

O B2 é a etapa mais mecânica do buildx e a que mais dá errado quando pulada. A primeira sprint do sprintx (regra 13: "a primeira sprint entrega a capacidade de testar") assume que existe um projeto onde escrever teste. O B2 é quem entrega essa suposição.

## Passo 1 — Repositório

Se não houver `.git` no diretório de trabalho nem em nenhum ancestral, inicialize aqui. Um `.gitignore` adequado à stack entra agora — antes do primeiro commit, para que segredo, `node_modules` e o arquivo do banco nunca tenham estado versionados.

Nunca versione: `.env`, `node_modules/`, o arquivo `.db` do SQLite, artefatos de build, o índice do memox.
Sempre versione: `.env.example`, `.expx/expx-lock.json`, as migrations, a seed de demonstração.

Commit inicial vazio ou com o esqueleto, na branch padrão. As branches de feature vêm depois, uma por feature, abertas pela `mergex-abrir` no B4.

## Passo 2 — Escolher a stack

O `PROJETO.md` manda; na omissão, valem os padrões da casa de `02-lacunas.md`:

| Eixo | Padrão | Vem de |
|---|---|---|
| Arquitetura | três camadas, fronteira explícita | P-1 |
| Framework | Next.js, TypeScript, App Router | P-2 |
| Banco | SQLite em arquivo, migrations versionadas | P-3 |
| Autenticação | JWT, e-mail e senha, hash forte | P-4 |
| Interface | design system do VS Code, Dark+ e Light+ | P-6 |

Cada escolha vira premissa em `PREMISSAS.md` com `origem: decisao_de_stack` — inclusive as que vieram do padrão da casa. O humano precisa poder ler, num arquivo só, tudo que foi decidido em nome dele.

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

## Passo 5 — O esqueleto testável

O mínimo para a primeira sprint do sprintx ter onde se apoiar. Nada de negócio entra aqui — nem uma tela, nem uma tabela de domínio.

Obrigatório:

| Item | Critério de pronto |
|---|---|
| Gerenciador de pacote | `package.json` com scripts `dev`, `build`, `test`, `lint` |
| Runner de teste | configurado, e **um teste que passa** |
| Lint e formatação | configurados, e rodando limpo |
| Tipos | TypeScript em modo estrito |
| Migrations | mecanismo instalado, com a migration inicial vazia ou de esquema base |
| Configuração | leitura por ambiente; variável obrigatória ausente **falha no start**, não em produção (L20) |
| `.env.example` | versionado, com toda variável, sem nenhum valor real |
| Estrutura de pastas | as três camadas de P-1, com uma pasta por camada, ainda vazias |

O critério de saída do esqueleto é binário e verificável numa máquina limpa:

```
instalar dependências → build passa → teste passa → lint passa → o projeto sobe
```

Se qualquer um desses quatro falhar, o B2 não terminou. Não avance para o B3 com um esqueleto que não sobe: toda feature do B4 herdaria o defeito, e o custo de descobrir isso na feature sete é sete vezes maior.

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

**A revisão da primeira feature.** Depois que a primeira feature do B4 for entregue, o código existe e o `stackx-detectar` normal pode rodar. O buildx roda, compara com o que decidiu, e converte cada regra confirmada de `decidido_pelo_buildx` para a evidência real. Regra que o código contradisse vira achado: ou o código se ajusta, ou a convenção estava errada e é corrigida. Este é o momento em que o projeto deixa de acreditar no buildx e passa a acreditar em si mesmo.

## Critério de saída do B2

Todos verdadeiros:

- repositório inicializado, `.gitignore` correto, nada sensível versionado
- suíte Expx instalada, lock versionado, `.claude/` e `.opencode/` presentes
- numa máquina limpa: dependências instalam, build passa, teste passa, lint passa, projeto sobe
- `docs/stack/CONVENCOES.md` existe, com toda regra marcada `decidido_pelo_buildx`
- toda escolha de stack registrada em `PREMISSAS.md`
- nenhuma linha de código de negócio escrita

## Erros que esta etapa comete

- **Escrever feature no esqueleto.** A tentação de "já deixar o login pronto, que é padrão" é forte e errada: autenticação é a primeira feature do B3, planejada e testada pelo sprintx como qualquer outra.
- **Instalar a suíte depois do código.** Inverte a ordem que dá sentido ao P-8, e o memox perde o histórico da construção.
- **Aceitar esqueleto que "quase" sobe.** Quatro verificações binárias; três não bastam.
- **Gravar convenção sem marcar a origem.** Uma regra `decidido_pelo_buildx` lida como se fosse detectada faz o projeto acreditar que tem evidência onde só tem opinião.
- **Versionar `.env` ou o arquivo do banco.** Uma vez versionado, sai do histórico com muito mais trabalho do que custou não colocar.
