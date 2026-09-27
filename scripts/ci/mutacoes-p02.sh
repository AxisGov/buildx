#!/usr/bin/env bash
#
# Mutações de INTEGRAÇÃO da certificação P0.2 (C7-B / B1R).
#
# Não repetem a suíte de mutações de cada skill — cada skill mata os próprios
# mutantes. Estas reintroduzem, uma de cada vez, o defeito que a COMPOSIÇÃO
# expxdev → buildx → sprintx → mergex precisa pegar, e exigem que
# scripts/ci/certifica-p02.sh FALHE — e falhe no checkpoint que prova aquilo, não
# num checkpoint qualquer: cada mutante declara onde tem de morrer.
#
# As do B1, ancoradas nos pins de produção (o freeze vigente, D-43):
#   X1  a sprintx deixa de barrar o arquivo de task irmã
#   X2  a sprintx lê o plano de uma feature histórica com o mesmo id de task
#   X3  o rastro volta a escolher o trabalho por mtime
#   X4  a mergex tira o inventário e o ownership do E1
#   X5  a mergex ignora a trava do E1
#   X6  a mergex não registra o seq
#   X7  `--registrar-existente` cria um segundo commit
#   X8  a V11 não participa do E2
#   X9  o fluxo pula o `persistir-metodo pre-e2`
#   X10 o commit de método leva produto
#   X11 o HISTORICO da sprintx vira desvio na V9
#   X12 a prova E lê a ENTREGA do worktree
#   X13 o buildx aceita artefato de método dirty
#   X14 o buildx perde a política LF
#   X15 a fonte da skill é resolvida por SHA curto
#
# As do B1R:
#   Y1  a instalação volta a ser cópia manual em vez de `expxdev init`
#   Y2  o hook da sprintx instalado some
#   Y3  o hook da mergex instalado some
#   Y4  o catalogo-de-metodo.sh instalado some
#   Y5  o runner executa a escrita de X mesmo depois do bloqueio
#   Y6  o TDD-first começa pela implementação
#   Y7  o parcial seguro é descartado depois do replanejamento
#   Y8  a sprintx não revalida o hash do parcial
#   Y9  o buildx volta a exigir árvore limpa onde a sprintx preserva o parcial
#   Y10 o E1 aceita a irmã suja depois de um bypass do hook
#   Y11 o E1 absorve produto current omitido da lista
#   Y12 o buildx cria sucessora sobre um terminal entregue
#   Y13 o buildx lê o terminal entregue como bloqueado e abre PEND
#   Y14 a instalação em ordem inversa muda o resultado
#   Y15 a certificação roda sem jq no processo dos hooks
#
# As da reivindicação (D-01 / C7-C): a prova da reivindicação não pode voltar a ser
# a linha que a bancada monta.
#   Y16 o B1R volta a fabricar a task_iniciada do runner (evento_skill com a S1)
#   Y17 o escritor da sprintx grava a reivindicação sem identidade (o modelo antigo)
#   Y18 o agente não usa o escritor público: a reivindicação vai à mão para o rastro
#   Y19 a sessão vem do roteiro (EXPX_SESSAO no processo do runner)
#   Y20 o harness vem do roteiro (EXPX_HARNESS no processo do runner)
#   Y21 a bancada reivindica pelo agente, com a sessão dele, antes de ele rodar
#
# O primeiro HISTORICO.md global da sprintx (P0.2 / D-02): a seção Q da
# certificação prova FIRST (HEAD sem base), TRACKED (recalibração) e e8 sem
# pre-e2 anterior. Estas mutações rodam sobre uma extração isolada de Q — só
# A + os instrumentos + a seção Q, pelos marcadores estáveis do próprio
# roteiro (`Q_EXTRAI`, abaixo) — porque P8, mais cedo no mesmo script, já
# exercita o caminho TRACKED da mergex sobre a HISTORICO da feature-antiga:
# sem o isolamento, uma regressão de fonte morreria ali, não em Q, e não
# provaria o que esta bateria existe para provar. X1–Y21 continuam rodando
# sobre o script inteiro; só a bateria Z usa a extração.
#   Z1  a certificação volta a pré-criar o HISTORICO antes do cenário FIRST
#   Z2  a mergex regride ao pin anterior ao D-02: FIRST volta a recusar
#   Z3  FIRST não verifica a ausência do HISTORICO em HEAD
#   Z4  o commit de método sai sem o HISTORICO (a mergex some com o `git add`
#       e o gate que compara staged×catálogo)
#   Z5  TRACKED perde a entrada histórica (a fixture não a reafirma)
#   Z6  a mergex passa a recusar toda recalibração TRACKED, mesmo válida
#   Z7  e8 sem pre-e2 anterior volta a recusar a primeira criação
#
# Z8 e Z9 (o pin retrocede; a decisão de freeze diverge do pin) são do bloco
# `pins` do harness genérico — scripts/ci/mutacoes.sh, M64/M65 — porque já
# há ali a máquina de freeze/pin (D-42/D-43/D-44) para reaproveitar; adicionar
# uma segunda aqui duplicaria a mesma verificação. O override de SHA sem modo
# de teste (Z10, para a mergex) já morre pelo M60 existente, genérico às três
# fontes: nenhuma mutação nova é precisa para essa classe.
#
# O SessionStart instalado (P0.2 / D-03): a seção S da certificação executa o
# expx-session-sync INSTALADO num PATH controlado. As W1–W2 trocam o ExpxDev; as
# W3–W10 regridem o hook instalado da S (`hook_sob_prova`, marcador [W-hook]) DEPOIS
# da prova de bytes (SI.10s/S5.10s) — a regressão que o ExpxDev pegaria na fonte, aqui
# para provar que as asserções de comportamento da S não são tautológicas: a prova
# de bytes sozinha as mataria antes e não diria nada sobre o comportamento.
#   W1  o ExpxDev volta ao do freeze D-44 (o pin e o binário executado)
#   W2  o hook instalado não corresponde ao ExpxDev do pin
#   W3  `<sha>-local` volta a auto-atualizar
#   W4  `local` exato volta a auto-atualizar
#   W5  a mistura local/remota atualiza (só congela se TODAS forem locais)
#   W6  o resume ignora o freeze
#   W7  o lock inválido alcança o update
#   W8  o cache Axis é criado no caso local
#   W9  a barreira local bloqueia também o lock remoto
#   W10 o `git status` volta a rodar antes da leitura do lock
# A decisão do freeze D-45 divergindo do pin, e o pin voltando ao do D-44, são do
# bloco `pins` do harness genérico (scripts/ci/mutacoes.sh, M66/M67), como a Z8/Z9.
#
# O valor efetivo de escalar YAML no HISTORICO tracked (P0.2 / D-04): a seção QV
# da certificação encadeia commits de método reais em que a entrada antiga muda
# só de grafia (passa) ou de valor (barra). Rodam sobre a mesma extração da Z
# (Q_EXTRAI, modo q): Q roda antes, e a V7 tem de morrer nela. Todas regridem a
# FONTE da mergex; o QV9 (a prova estrutural do candidato) vem depois do
# comportamento, de propósito, para não matar nenhuma antes dele.
#   V1  a mergex volta à do freeze D-45 (lida da tabela dela): a grafia decide
#   V2  aspas simples deixam de desdobrar '' ('d''agua' volta a barrar)
#   V3  \x20 deixa de ser decodificado ("tela\x20de cadastro" volta a barrar)
#   V4  \n entre aspas duplas volta a passar como o texto literal a\n
#   V5  a base (HEAD) é canonicalizada e a working tree não
#   V6  a working tree é canonicalizada e a base (HEAD) não
#   V7  FIRST regride no candidato: o HISTORICO untracked volta a ser recusado
# O pin voltando ao da D-45, e a decisão do freeze D-46 divergindo do pin, são do
# bloco `pins` do harness genérico (scripts/ci/mutacoes.sh, M68/M69), como a Z8/Z9.
#
# As da sprintx e da mergex (X1–X7, X10, Y8, Y10, Y11, Y17, Z2, Z4, Z6, Z7, V1–V7) são
# aplicadas na FONTE clonada no SHA, antes do `expxdev init`, pelo gancho
# C7B_POS_EXTRACAO — nunca no repositório fonte: a mutação chega ao produto
# pelo instalador, como chegaria de verdade. As do buildx e da certificação,
# numa cópia da árvore. Antes delas, a cópia sem mutação passa (controle).
# Mutação que sobrevive é teste que falta.
#
# Rodam SEM runner real (C7B_RUNNER=settings): os hooks do settings.json instalado
# são despachados como o Claude Code os despacha. A prova com o runner real — e a
# do agente da seção R — é a certificação em si, com o Claude Code (Linux/WSL em
# ext4, o ambiente canônico); o relatório diz isso. Rodam longas: só no Linux.
#
# Uso: bash scripts/ci/mutacoes-p02.sh             # controle + todas
#      bash scripts/ci/mutacoes-p02.sh X4 Y9       # controle + as nomeadas
#      C7B_EXPXDEV_BUILD=<checkout construído> bash scripts/ci/mutacoes-p02.sh
#      C7B_EXPXDEV_BUILD_D44=<checkout construído no ExpxDev da D-44>   # só a W1; sem ele, constrói

set -uo pipefail

EU="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CERT=scripts/ci/certifica-p02.sh
PROVA_E=.claude/skills/buildx/scripts/prova-e.sh
INTEG=scripts/ci/integracao.sh

# troca <arquivo> <trecho> — troca a ÚNICA linha que contém o trecho pelo stdin.
troca() {
  local arq="$1" marca="$2" novo n
  novo="$(mktemp)"; cat > "$novo"
  n="$(grep -cF -- "$marca" "$arq")"
  [ "$n" = 1 ] || { echo "trecho '$marca' aparece $n vez(es) em $arq" >&2; rm -f "$novo"; return 1; }
  awk -v m="$marca" -v f="$novo" 'index($0, m) { while ((getline l < f) > 0) print l; close(f); next } { print }' "$arq" > "$arq.mut" &&
    cat "$arq.mut" > "$arq" && rm -f "$arq.mut"
  rm -f "$novo"
}

# Modo gancho: chamado pela certificação, depois do clone, com as FONTES.
if [ "${1:-}" = --snapshot ]; then
  m="$2"; SXS="$3"; MXS="$4"
  ESC="$SXS/.claude/hooks/sprintx/escopo-da-task.sh"
  PLA="$SXS/.claude/skills/sprintx/scripts/planejamento.sh"
  ESCRITOR="$SXS/.claude/skills/sprintx/scripts/rastro.sh"
  FECHA="$MXS/.claude/skills/mergex/scripts/fechamento-do-e1.sh"
  PERSISTE="$MXS/.claude/skills/mergex/scripts/persistir-metodo.sh"
  MERGEX_FONTE_REAL="${C7B_MERGEX_FONTE:-}"
  # MERGEX_SHA_ANTES_D02 vem do ambiente (lido do harness, abaixo) — nunca literal aqui.
  case "$m" in
    X1) troca "$ESC" 'if [ "$DECL" = irma ]; then' <<'EOF'
if false; then
EOF
      ;;
    X2) troca "$ESC" '  function do_trabalho(f) {' <<'EOF'
  function do_trabalho(f) { return 1 }
  function do_trabalho_original(f) {
EOF
      ;;
    X3) printf '\nrastro_trabalho_da_sessao_em() { printf -v "$1" %%s "$(ls -t "$2/docs/sprintx/features" 2>/dev/null | head -1)"; }\n' \
          >> "$SXS/.claude/hooks/comum/rastro.sh" ;;
    X4) troca "$FECHA" '    classifica_arvore "$TASK" "$@"     # 4' <<'EOF'
    STAGING="$(printf '%s\n' "$@")"
EOF
      ;;
    X5) troca "$FECHA" '    abre_secao "$TASK"                 # 1 e 2' <<'EOF'
    :
EOF
      ;;
    X6) troca "$MXS/.claude/skills/mergex/scripts/sequencia-de-commits.sh" '      acrescentar "$2" "$3" "$4" && exit 0' <<'EOF'
      printf 'seq=%s\n' 1; exit 0
EOF
      ;;
    X7) troca "$FECHA" '  verifica_ownership "$task" "${caminhos[@]}"' <<'EOF'
  verifica_ownership "$task" "${caminhos[@]}"
  git commit -q --allow-empty -m "recupera $task" -m "Task: $task" -m "Trabalho: $trabalho_dado" >/dev/null 2>&1
EOF
      ;;
    X10) troca "$MXS/.claude/skills/mergex/scripts/persistir-metodo.sh" 'LC_ALL=C sort -u -o "$TMP_LISTA" "$TMP_LISTA"' <<'EOF'
git -C "$RAIZ" -c core.quotepath=false diff --name-only >> "$TMP_LISTA"
LC_ALL=C sort -u -o "$TMP_LISTA" "$TMP_LISTA"
EOF
      ;;
    Y8) troca "$PLA" '  D_PARC=integro; D_DET=""' <<'EOF'
  D_PARC=integro; D_DET=""; return 0
EOF
      ;;
    Y17) troca "$ESCRITOR" 'if rastro_identidade_em SESSAO HARNESS; then' <<'EOF' &&
if false; then
EOF
         troca "$ESCRITOR" 'elif [ "$EXIGE_IDENTIDADE" = 1 ]; then' <<'EOF'
elif false; then
EOF
      ;;
    Y10) troca "$FECHA" "      para 8 'PARADO — arquivo_de_task_irma: arquivo planejado em outra task da feature' \\" <<'EOF'
      : 8 'PARADO — arquivo_de_task_irma' \
EOF
      ;;
    Y11) troca "$FECHA" "  [ -z \"\$omitidos\" ] || para 11 'PARADO — produto da task atual alterado e não listado no E1' \\" <<'EOF' &&
  [ -z "$omitidos" ] || : 11 \
EOF
         troca "$FECHA" "        printf '%s\n' \"\$@\" | grep -Fxq -- \"\$caminho\" && printf '%s\n' \"\$caminho\"" <<'EOF'
        printf '%s\n' "$caminho"
EOF
      ;;
    Z2) # a mergex regride ao pin anterior ao D-02: confere_historico_inicial nunca existiu
      [ -n "$MERGEX_FONTE_REAL" ] || { echo "Z2: C7B_MERGEX_FONTE indisponivel para o snapshot" >&2; exit 1; }
      rm -rf "$MXS/.claude/skills/mergex" "$MXS/.claude/hooks/mergex" &&
        git -C "$MERGEX_FONTE_REAL" archive "$MERGEX_SHA_ANTES_D02" .claude/skills/mergex .claude/hooks/mergex | tar -x -C "$MXS"
      ;;
    Z4) # o commit de metodo leva produto junto (a mesma fonte que a X10 muda, no
        # PASSO 8): o catalogo deixa de ser fechado, e o produto que a Z4 suja no
        # certifica-p02.sh (abaixo) entra com o HISTORICO no mesmo commit
      troca "$PERSISTE" 'LC_ALL=C sort -u -o "$TMP_LISTA" "$TMP_LISTA"' <<'EOF'
git -C "$RAIZ" -c core.quotepath=false diff --name-only >> "$TMP_LISTA"
LC_ALL=C sort -u -o "$TMP_LISTA" "$TMP_LISTA"
EOF
      ;;
    Z6) # a mergex passa a recusar toda recalibracao TRACKED, mesmo valida
      troca "$PERSISTE" 'local caminho="$HISTORICO_GLOBAL" modo motivo' <<'EOF'
  local caminho="$HISTORICO_GLOBAL" modo motivo
  para 'bloqueado por mutacao (Z6): recalibracao TRACKED recusada mesmo valida'
EOF
      ;;
    Z7) # a mesma regressao da Z2, para a extracao QE-only (e8 sem pre-e2 anterior)
      [ -n "$MERGEX_FONTE_REAL" ] || { echo "Z7: C7B_MERGEX_FONTE indisponivel para o snapshot" >&2; exit 1; }
      rm -rf "$MXS/.claude/skills/mergex" "$MXS/.claude/hooks/mergex" &&
        git -C "$MERGEX_FONTE_REAL" archive "$MERGEX_SHA_ANTES_D02" .claude/skills/mergex .claude/hooks/mergex | tar -x -C "$MXS"
      ;;
    V1) # a mergex regride a do freeze D-45, anterior ao D-04: o leitor tira as aspas sem decodificar
      [ -n "$MERGEX_FONTE_REAL" ] || { echo "V1: C7B_MERGEX_FONTE indisponivel para o snapshot" >&2; exit 1; }
      rm -rf "$MXS/.claude/skills/mergex" "$MXS/.claude/hooks/mergex" &&
        git -C "$MERGEX_FONTE_REAL" archive "$MERGEX_SHA_ANTES_D04" .claude/skills/mergex .claude/hooks/mergex | tar -x -C "$MXS"
      ;;
    V2) # aspas simples deixam de desdobrar a aspa dobrada — sed, nao troca: o awk -v
        # da troca leria o \047 do trecho como a propria aspa
      sed -i 's/^\( *\)gsub("\\047\\047", "\\047", s)$/\1# (mutacao V2) a aspa dobrada fica como esta/' "$PERSISTE" &&
        [ "$(grep -cF '(mutacao V2)' "$PERSISTE")" = 1 ] || { echo "V2: trecho ausente em $PERSISTE" >&2; exit 1; }
      ;;
    V3) # \xHH deixa de ser decodificado: a barra e o x ficam como texto
      troca "$PERSISTE" 'else if (c == "x") { r = r ascii_hexa(substr(s, i + 1, 2), v); i += 2 }' <<'EOF'
        else if (c == "x") r = r "\\" c
EOF
      ;;
    V4) # \n entre aspas duplas volta a ser o texto de dois caracteres
      troca "$PERSISTE" 'index("0abtnvfreNLP", c)' <<'EOF'
        else if (c == "n") r = r "\\" c
        else if (c == "\t" || index("0abtvfreNLP", c)) erro("escape que produz controle ou quebra de linha (campos são de uma linha): " v)
EOF
      ;;
    V5) # so a base (HEAD, lida de head.md) e canonicalizada; a working tree fica crua
      troca "$PERSISTE" 'function decodifica(v,   q, s, r, i, c) {' <<'EOF'
    function decodifica(v,   q, s, r, i, c) {
      if (FILENAME !~ /\/head\.md$/) return substr(v, 2, length(v) - 2)
EOF
      ;;
    V6) # so a working tree e canonicalizada; a base (HEAD) fica crua
      troca "$PERSISTE" 'function decodifica(v,   q, s, r, i, c) {' <<'EOF'
    function decodifica(v,   q, s, r, i, c) {
      if (FILENAME ~ /\/head\.md$/) return substr(v, 2, length(v) - 2)
EOF
      ;;
    V7) # FIRST regride no candidato: todo HISTORICO untracked volta a ser recusado
      troca "$PERSISTE" '    confere_historico_inicial' <<'EOF'
    para 'HISTORICO global untracked recusado (mutacao V7)'
EOF
      ;;
    *) echo "mutacao de fonte desconhecida: $m" >&2; exit 1 ;;
  esac
  exit $?
fi

# Onde cada mutante TEM de morrer: o id do primeiro checkpoint que falha.
onde() {
  case "$1" in
    X1)  echo '^(R\.7|P1\.[0-9]+)$' ;;
    X2|X3) echo '^P1\.' ;;
    X4)  echo '^P1\.16$' ;;
    X5)  echo '^P6\.' ;;
    X6)  echo '^(P0\.13|F6\.[0-9]+|P5\.[0-9]+)$' ;;
    X7)  echo '^P7\.' ;;
    X8)  echo '^P7\.7$' ;;
    X9|X10) echo '^P8\.' ;;
    X11) echo '^P9\.' ;;
    X12|X13) echo '^P12\.' ;;
    X14) echo '^LF\.' ;;
    X15) echo '^A\.4$' ;;
    Y1)  echo '^G\.1$' ;;
    Y2|Y3|Y4) echo '^I\.' ;;
    Y5)  echo '^(R\.7|P1\.(7|9))$' ;;
    Y6)  echo '^(P1\.13|T\.[0-9])$' ;;
    Y7)  echo '^P2\.8$' ;;
    Y8)  echo '^P2\.18$' ;;
    Y9)  echo '^P2\.4$' ;;
    Y10) echo '^(P1\.16|H\.24)$' ;;
    Y11) echo '^P5\.6$' ;;
    Y12) echo '^K\.9$' ;;
    Y13) echo '^(P11\.10|K\.[0-9]+)$' ;;
    Y14) echo '^M\.1o$' ;;
    Y15) echo '^J\.1$' ;;
    Y16|Y19|Y20|Y21) echo '^G\.1$' ;;
    Y17|Y18) echo '^R\.3$' ;;
    Z1)  echo '^QF\.1$' ;;
    Z2)  echo '^QF\.4$' ;;
    Z3)  echo '^QF\.2$' ;;
    Z4)  echo '^QF\.5$' ;;
    Z5)  echo '^QT\.2$' ;;
    Z6)  echo '^QT\.2$' ;;
    Z7)  echo '^QE\.2$' ;;
    V1|V2|V5) echo '^QV1\.1$' ;;
    V3)  echo '^QV2\.1$' ;;
    V4)  echo '^QN1\.1$' ;;
    V6)  echo '^QV2\.1$' ;;
    V7)  echo '^QF\.4$' ;;
    W1)  echo '^S1\.2$' ;;
    W2)  echo '^I\.10s$' ;;
    W3)  echo '^S1\.2$' ;;
    W4)  echo '^S5\.2$' ;;
    W5)  echo '^S3\.2$' ;;
    W6)  echo '^S2\.2$' ;;
    W7)  echo '^S6a\.2$' ;;
    W8)  echo '^S1\.4$' ;;
    W9)  echo '^S7\.2$' ;;
    W10) echo '^S1\.[23]$' ;;
  esac
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export C7B_SPRINTX_FONTE="${C7B_SPRINTX_FONTE:-$(cd "$REPO/../sprintx" 2>/dev/null && pwd)}"
export C7B_MERGEX_FONTE="${C7B_MERGEX_FONTE:-$(cd "$REPO/../mergex" 2>/dev/null && pwd)}"
export C7B_EXPXDEV_FONTE="${C7B_EXPXDEV_FONTE:-$(cd "$REPO/../expxdev" 2>/dev/null && pwd)}"
export C7B_PRESERVAR=0 C7B_RUNNER=settings

# O ExpxDev do PIN de produção (a única fonte é o harness), construído uma vez para
# todas as rodadas. Override de SHA não existe aqui: a certificação o recusa.
EXPXDEV_PIN="$(sed -n 's/^EXPXDEV_SHA_FIXO=\([0-9a-f]\{40\}\)\([^0-9a-f].*\)\{0,1\}$/\1/p' "$REPO/$INTEG")"
[ -n "$EXPXDEV_PIN" ] || { echo "EXPXDEV_SHA_FIXO ausente ou incompleto em $INTEG"; exit 1; }

# A mergex de antes do D-02 (evidência do freeze D-43), para as mutações Z2/Z7
# regredirem a FONTE — nunca literal aqui, lida do harness como o EXPXDEV_PIN acima.
MERGEX_SHA_ANTES_D02="$(sed -n 's/^MERGEX_SHA_D43=\([0-9a-f]\{40\}\)\([^0-9a-f].*\)\{0,1\}$/\1/p' "$REPO/$INTEG")"
[ -n "$MERGEX_SHA_ANTES_D02" ] || { echo "MERGEX_SHA_D43 ausente ou incompleto em $INTEG"; exit 1; }
export MERGEX_SHA_ANTES_D02

# O ExpxDev do freeze D-44, anterior ao D-03, para a W1/W2 — lido da tabela da própria
# D-44 (evidência que não se reescreve), nunca literal aqui.
EXPXDEV_D44="$(tr -d '\r' < "$REPO/.claude/skills/buildx/DECISOES-DA-SKILL.md" |
  awk 'index($0, "## D-44 — ") == 1 { em = 1; next } /^## D-[0-9]+ — / { em = 0 } em' |
  sed -n 's/^| `expxdev` | `\([0-9a-f]\{40\}\)` |.*/\1/p')"
[ -n "$EXPXDEV_D44" ] || { echo "a D-44 nao registra o expxdev em 40 hex"; exit 1; }

# A mergex do freeze D-45, anterior ao D-04, para a V1 regredir a FONTE — lida da
# tabela da própria D-45 (evidência que não se reescreve), nunca literal aqui.
MERGEX_SHA_ANTES_D04="$(tr -d '\r' < "$REPO/.claude/skills/buildx/DECISOES-DA-SKILL.md" |
  awk 'index($0, "## D-45 — ") == 1 { em = 1; next } /^## D-[0-9]+ — / { em = 0 } em' |
  sed -n 's/^| `mergex` | `\([0-9a-f]\{40\}\)` |.*/\1/p')"
[ -n "$MERGEX_SHA_ANTES_D04" ] || { echo "a D-45 nao registra a mergex em 40 hex"; exit 1; }
export MERGEX_SHA_ANTES_D04
if [ -z "${C7B_EXPXDEV_BUILD:-}" ]; then
  C7B_EXPXDEV_BUILD="$TMP/expxdev"
  git -c safe.directory='*' clone -q -c core.autocrlf=false --no-checkout "$C7B_EXPXDEV_FONTE" "$C7B_EXPXDEV_BUILD" &&
    git -C "$C7B_EXPXDEV_BUILD" -c advice.detachedHead=false checkout -q --detach "$EXPXDEV_PIN" &&
    ( cd "$C7B_EXPXDEV_BUILD" && npm ci --no-audit --no-fund >/dev/null 2>&1 && npm run build:server >/dev/null 2>&1 ) ||
    { echo "nao foi possivel construir o expxdev do pin"; exit 1; }
fi
export C7B_EXPXDEV_BUILD

copia() {
  mkdir -p "$1"
  ( cd "$REPO" && git -c safe.directory='*' ls-files -z --cached --others --exclude-standard | tar --null -T - -cf - ) |
    tar -C "$1" -xf -
  ( cd "$1" && git init -q -b main . && git config user.email t@t && git config user.name t &&
    git config core.autocrlf false && git add -A 2>/dev/null && git commit -q -m copia ) >/dev/null 2>&1
}

snapshot() { printf '#!/usr/bin/env bash\nexec bash "%s" --snapshot %s "$@"\n' "$EU" "$1" > "$TMP/$1.pos.sh"; }

# muta_hook <arvore> <trecho do hook> <novo> — a regressão entra no hook INSTALADO da
# seção S, pelo `hook_sob_prova` da certificação: depois da prova de bytes, antes do
# commit da instalação. Trecho ausente ou repetido: o hook_sob_prova recusa (3).
muta_hook() {
  troca "$1/$CERT" '# [W-hook]' <<EOF
hook_sob_prova() { "\$NODE" -e 'const fs = require("fs"), [f, a, b] = process.argv.slice(1), s = fs.readFileSync(f, "utf8"); if (s.split(a).length !== 2) process.exit(3); fs.writeFileSync(f, s.replace(a, () => b));' "\$1/\$HOOK_SESSAO" $(printf '%q' "$2") $(printf '%q' "$3"); }
EOF
}

aplica() { # aplica <mutacao> <arvore> — o defeito, e só ele
  local d="$2"
  case "$1" in
    X1|X2|X3|X4|X5|X6|X7|X10|Y8|Y10|Y11|Y17|Z2|Z6|Z7|V1|V2|V3|V4|V5|V6|V7) snapshot "$1" ;;
    X8) troca "$d/$CERT" '# [P8]' <<'EOF'
  case "V11=OK" in                                                                       # [P8]
EOF
      ;;
    X9) troca "$d/$CERT" '# [P9]' <<'EOF'
:                                                                                          # [P9]
EOF
      ;;
    X11) troca "$d/$CERT" '# [P11]' <<'EOF'
      docs/sprintx/estimativas/HISTORICO.md) printf '%s\n' "$p" ;;                       # [P11]
EOF
      ;;
    X12) troca "$d/$PROVA_E" '# [M46]' <<'EOF'
if ! ENTREGA="$(cat "$WT/docs/entregas/$SLUG/ENTREGA.md" 2>/dev/null)"; then                  # [M46]
EOF
      ;;
    X13) troca "$d/$PROVA_E" '# [M51]' <<'EOF'
  elif case "${SUJOS[$i]}" in docs/*) true ;; *) declarado "${SUJOS[$i]}" ;; esac; then       # [M51]
EOF
      ;;
    X14) grep -v '^\*\.sh ' "$d/.gitattributes" > "$d/.gitattributes.mut" && mv -f "$d/.gitattributes.mut" "$d/.gitattributes" ;;
    X15) troca "$d/$CERT" '# [P15]' <<'EOF'
  ref="${sha:0:12}"                                                          # [P15]
EOF
      ;;
    Y1) troca "$d/$CERT" '# [Y1]' <<'EOF'
mkdir -p "$C/.claude" "$C/.expx" && cp -R "$SRC/sprintx/.claude/hooks" "$SRC/sprintx/.claude/skills" "$C/.claude/" &&
  cp -R "$SRC/mergex/.claude/hooks/." "$C/.claude/hooks/" && cp -R "$SRC/mergex/.claude/skills/mergex" "$C/.claude/skills/" &&
  jq -s '{expx_hooks: 1, hooks: (.[0].hooks + .[1].hooks)}' "$SRC/sprintx/.expx/hooks.json" "$SRC/mergex/.expx/hooks.json" > "$C/.expx/hooks.json"
INIT_RC=0; INIT_SAIDA="instaladas: mergex, sprintx — nao foi encontrado no PATH"
EOF
      ;;
    Y2) troca "$d/$CERT" '# [Y2]' <<'EOF'
rm -f "$C/.claude/hooks/sprintx/escopo-da-task.sh"
EOF
      ;;
    Y3) troca "$d/$CERT" '# [Y2]' <<'EOF'
rm -f "$C/.claude/hooks/mergex/git-perigoso.sh"
EOF
      ;;
    Y4) troca "$d/$CERT" '# [Y2]' <<'EOF'
rm -f "$C/.claude/skills/mergex/scripts/catalogo-de-metodo.sh"
EOF
      ;;
    Y5) troca "$d/$CERT" '# [Y5]' <<'EOF'
    [ "$DESP_RC" = 2 ] && { RUN_RC=2; RUN_SAIDA="$DESP_SAIDA"; }
EOF
      ;;
    Y6) troca "$d/$CERT" '# [Y6]' <<'EOF'
runner_write "$WT" "$S1" src/atual.sh 'atual() { echo "$(x_modo) $(x)"; }'$'\n'
EOF
      ;;
    Y7) troca "$d/$CERT" '# [Y7]' <<'EOF'
rm -f "$WT/test/atual.test.sh"
EOF
      ;;
    Y9) troca "$d/$INTEG" '# [Y9]' <<'EOF'
    disponivel) if [ -z "$(git -C "$1" status --porcelain --untracked-files=all -- src test)" ]; then echo F:replanejar_execucao; else echo PARE; fi ;;
EOF
      ;;
    Y12) troca "$d/$INTEG" 'integrar() { git merge --ff-only "$1" >/dev/null 2>&1; }' <<'EOF'
integrar() { git merge --ff-only "$1" >/dev/null 2>&1 && mapa_feature docs/projeto/MAPA.md FT-09 "${1#feature/}-v2" pendente recursao FT-02 PEND-09; }
EOF
      ;;
    Y13) troca "$d/$INTEG" '    entregue:pronto)                            echo entregue ;;' <<'EOF'
    entregue:pronto)                            echo bloqueada ;;
EOF
      ;;
    Y14) troca "$d/$CERT" '# [Y14]' <<'EOF'
rm -f "$FX/.claude/hooks/sprintx/escopo-da-task.sh"
EOF
      ;;
    Y15) troca "$d/$CERT" '# [Y15]' <<'EOF'
RUNNER_PATH="$RUNNER_DIRS"
EOF
      ;;
    Y16) troca "$d/$CERT" '# [Y16]' <<'EOF'
evento_skill "$SLUG" task_iniciada T-01.01 "$S1"
EOF
      ;;
    Y18) # a reivindicação à mão, sem identidade, com o evento e o caminho do rastro
         # disfarçados: a guarda textual não a vê — quem a mata é o escopo-da-task
      troca "$d/$CERT" 'runner_bash "$FR" "$SR" "$RUNNER_PATH" "bash $ESCRITOR task-iniciada $SLR T-01.01"' <<'EOF'
  runner_bash "$FR" "$SR" "$RUNNER_PATH" "printf '%s\n' '{\"expx_eventos\":1,\"trabalho_id\":\"ft-r\",\"origem\":\"skill\",\"evento\":\"task_'iniciada'\",\"task\":\"T-01.01\"}' >> docs/\"eve\"ntos/ft-r.jsonl"
EOF
      ;;
    Y19) troca "$d/$CERT" 'CLAUDECODE=1 CLAUDE_CODE_SESSION_ID="$u" bash -c "$cmd" 2>&1)"; RUN_RC=$?' <<'EOF'
  RUN_SAIDA="$(cd "$d" && "${SEM_CLAUDE[@]}" PATH="$p" CLAUDECODE=1 CLAUDE_CODE_SESSION_ID="$u" EXPX_SESSAO="claude-code@$u" bash -c "$cmd" 2>&1)"; RUN_RC=$?   # [harness-emulado]
EOF
      ;;
    Y20) troca "$d/$CERT" 'CLAUDECODE=1 CLAUDE_CODE_SESSION_ID="$u" bash -c "$cmd" 2>&1)"; RUN_RC=$?' <<'EOF'
  RUN_SAIDA="$(cd "$d" && "${SEM_CLAUDE[@]}" PATH="$p" CLAUDECODE=1 CLAUDE_CODE_SESSION_ID="$u" EXPX_HARNESS=claude-code bash -c "$cmd" 2>&1)"; RUN_RC=$?   # [harness-emulado]
EOF
      ;;
    Y21) troca "$d/$CERT" 'ROT_ANTES="$(git -C "$FR" hash-object --no-filters src/rotulo.sh)"' <<'EOF'
ROT_ANTES="$(git -C "$FR" hash-object --no-filters src/rotulo.sh)"
WT_SALVO="$WT"; WT="$FR"; evento_skill "$SLR" task_iniciada T-01.01 "$SR"; WT="$WT_SALVO"
EOF
      ;;
    Z1) # a certificacao volta a pre-criar o HISTORICO antes do cenario FIRST
      troca "$d/$CERT" 'BASE_Q="$(git -C "$FX" rev-parse HEAD)"' <<'EOF'
mkdir -p "$FX/docs/sprintx/estimativas"
printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: estimativa_historico\ntrabalho_id: null\natualizado_em: 2020-01-01\nunidade: h\nentradas: []\ncalibracao: []\n---\n\n# x\n' > "$FX/docs/sprintx/estimativas/HISTORICO.md"
git -C "$FX" add -A && git -C "$FX" commit -q -m "chore: pre-cria historico (mutacao Z1)"
BASE_Q="$(git -C "$FX" rev-parse HEAD)"
EOF
      ;;
    Z3) # FIRST nao verifica a ausencia do HISTORICO em HEAD pelo ls-tree: some
        # com a QF.1 (e reintroduz a pre-criacao da Z1, senao nao ha nada a pegar).
        # A QF.2 — existencia crua na working tree, depois da fundacao — ainda
        # morre por conta propria: prova que a rede de checagem nao depende so
        # da QF.1 para recusar um HISTORICO que ja chegou tracked.
      troca "$d/$CERT" 'BASE_Q="$(git -C "$FX" rev-parse HEAD)"' <<'EOF' &&
mkdir -p "$FX/docs/sprintx/estimativas"
printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: estimativa_historico\ntrabalho_id: null\natualizado_em: 2020-01-01\nunidade: h\nentradas: []\ncalibracao: []\n---\n\n# x\n' > "$FX/docs/sprintx/estimativas/HISTORICO.md"
git -C "$FX" add -A && git -C "$FX" commit -q -m "chore: pre-cria historico (mutacao Z3)"
BASE_Q="$(git -C "$FX" rev-parse HEAD)"
EOF
      troca "$d/$CERT" 'ck QF.1 "HEAD nao contem o HISTORICO global — a lacuna que o C7-C revelou" "" \' <<'EOF'
:  # [mutacao Z3: QF.1 removida]
EOF
      ;;
    Z4) # o commit de metodo leva produto junto: o catalogo perde o fechamento
        # (a mesma fonte que a X10 muda, no PASSO 8) — precisa de algo dirty
        # fora do catalogo para provar; a QF nao suja produto nenhum sozinha,
        # entao esta suja src/q1.sh logo antes do pre-e2.
      snapshot Z4
      troca "$d/$CERT" 'metodo_fx pre-e2 q1' <<'EOF'
printf '\n# suja pelo mutante Z4\n' >> "$FX/src/q1.sh"
metodo_fx pre-e2 q1
EOF
      ;;
    W1) # o pin e o binario executado voltam ao ExpxDev do freeze D-44
      sed -i "s/^EXPXDEV_SHA_FIXO=[0-9a-f]\{40\}/EXPXDEV_SHA_FIXO=$EXPXDEV_D44/" "$d/$INTEG" &&
        printf '%s\n' "$C7B_EXPXDEV_BUILD_D44" > "$TMP/$1.xd"
      ;;
    W2) # o hook instalado nao e o do pin: o do D-44 por cima, logo depois do init
      troca "$d/$CERT" '# [Y2]' <<EOF
git -c safe.directory='*' -C "\$XD" show "$EXPXDEV_D44:nucleo/hooks/expx-session-sync.mjs" > "\$C/\$HOOK_SESSAO"
EOF
      ;;
    W3) muta_hook "$d" 'return commit === "local" || commit.endsWith("-local");' 'return commit === "local";' ;;
    W4) muta_hook "$d" 'return commit === "local" || commit.endsWith("-local");' 'return commit.endsWith("-local");' ;;
    W5) muta_hook "$d" 'if (origem.locais.length > 0) {' \
          'if (origem.locais.length > 0 && origem.locais.length === Object.keys(JSON.parse(readFileSync(caminhoLock, "utf8")).skills).length) {' ;;
    W6) muta_hook "$d" 'const origem = lerOrigemDoLock(caminhoLock);' \
          'const origem = evento.source === "resume" ? { ok: true, locais: [] } : lerOrigemDoLock(caminhoLock);' ;;
    W7) muta_hook "$d" 'if (!origem.ok) {' 'if (!origem.ok) { origem.locais = []; } if (false) {' ;;
    W8) muta_hook "$d" 'if (origem.locais.length > 0) {' 'if (origem.locais.length > 0) { mkdirSync(cachePadrao(ambiente), { recursive: true });' ;;
    W9) muta_hook "$d" 'if (origem.locais.length > 0) {' 'if (true) {' ;;
    W10) muta_hook "$d" 'const origem = lerOrigemDoLock(caminhoLock);' 'arvoreSuja(projeto, executar); const origem = lerOrigemDoLock(caminhoLock);' ;;
    Z5) # TRACKED perde a entrada historica: a fixture nao a reafirma no acrescimo
      troca "$d/$CERT" 'hist_add q2 T-01.01 teste accountability 0.6 "$HOJE"' <<'EOF'
HIST_ENTRADAS=""   # [mutacao Z5: descarta a entrada de q1 antes de acrescentar]
hist_add q2 T-01.01 teste accountability 0.6 "$HOJE"
EOF
      ;;
    *) echo "mutacao desconhecida: $1" >&2; return 1 ;;
  esac
}

# Q_EXTRAI <script-fonte> <modo: q|qe> -> stdout: A + instrumentos + a seção Q
# do certifica-p02.sh, pelos marcadores estáveis do próprio roteiro — nunca por
# número de linha. modo=qe também pula a fixture fx-q inteira (FIRST + TRACKED),
# deixando só o controle e8 sem pre-e2 anterior (fx-q8): a regressão de fonte
# não pode morrer em QF antes de a QE ter a chance de provar o próprio ponto.
Q_EXTRAI() {
  awk -v modo="$2" '
    /^passo "G guarda estrutural/ { skipg = 1 }
    skipg { if (/^case "\$C7B_RUNNER" in claude\|settings\) ;;/) { skipg = 0; print }; next }
    /^passo "I instalacao real pelo ExpxDev/ { skipbody = 1 }
    /^passo "Q primeiro HISTORICO global/ { skipbody = 0; inq = 1 }
    skipbody { next }
    inq && modo == "qe" && /^fixture fx-q sprintx,mergex QI$/ { skipqf = 1 }
    skipqf && /^# --- controle: e8 sem pre-e2/ { skipqf = 0 }
    skipqf { next }
    /^passo "PORTABILIDADE LF/ { exit }
    { print }
  ' "$1"
  printf 'printf "%%s\\n" fim-extracao-q\nexit 0\n'
}

roda() { # roda <nome> <arvore>
  local pos="" xd=()
  [ -f "$TMP/$1.pos.sh" ] && pos="$TMP/$1.pos.sh"
  # W1: o ExpxDev executado é outro — o do D-44; em modo de teste, o override o acompanha
  if [ -f "$TMP/$1.xd" ]; then
    xd=(C7B_EXPXDEV_BUILD="$(cat "$TMP/$1.xd")")
    [ -z "${C7B_EXPXDEV_SHA:-}" ] || xd+=(C7B_EXPXDEV_SHA="$EXPXDEV_D44")
  fi
  ( cd "$TMP" && env "${xd[@]}" C7B_POS_EXTRACAO="$pos" bash "$2/$CERT" > "$TMP/$1.log" 2>&1; echo $? > "$TMP/$1.rc" )
}

roda_q() { # roda_q <nome> <arvore> <modo: q|qe> — só a extração de Q_EXTRAI
  local pos=""
  [ -f "$TMP/$1.pos.sh" ] && pos="$TMP/$1.pos.sh"
  Q_EXTRAI "$2/$CERT" "$3" > "$TMP/$1.qcert.sh"
  sed -i "s|^REPO=.*|REPO=\"$(cd "$2" && pwd)\"|" "$TMP/$1.qcert.sh"
  ( cd "$TMP" && C7B_POS_EXTRACAO="$pos" bash "$TMP/$1.qcert.sh" > "$TMP/$1.log" 2>&1; echo $? > "$TMP/$1.rc" )
}

MUTACOES="${*:-X1 X2 X3 X4 X5 X6 X7 X8 X9 X10 X11 X12 X13 X14 X15 Y1 Y2 Y3 Y4 Y5 Y6 Y7 Y8 Y9 Y10 Y11 Y12 Y13 Y14 Y15 Y16 Y17 Y18 Y19 Y20 Y21 Z1 Z2 Z3 Z4 Z5 Z6 Z7 W1 W2 W3 W4 W5 W6 W7 W8 W9 W10 V1 V2 V3 V4 V5 V6 V7}"

# A W1 executa o ExpxDev do D-44 inteiro: construído uma vez, e só se ela for pedida.
case " $MUTACOES " in
  *" W1 "*)
    if [ -z "${C7B_EXPXDEV_BUILD_D44:-}" ]; then
      C7B_EXPXDEV_BUILD_D44="$TMP/expxdev-d44"
      git -c safe.directory='*' clone -q -c core.autocrlf=false --no-checkout "$C7B_EXPXDEV_FONTE" "$C7B_EXPXDEV_BUILD_D44" &&
        git -C "$C7B_EXPXDEV_BUILD_D44" -c advice.detachedHead=false checkout -q --detach "$EXPXDEV_D44" &&
        ( cd "$C7B_EXPXDEV_BUILD_D44" && npm ci --no-audit --no-fund >/dev/null 2>&1 && npm run build:server >/dev/null 2>&1 ) ||
        { echo "nao foi possivel construir o expxdev do D-44"; exit 1; }
    fi
    ;;
esac

printf 'controle — a arvore sem mutacao certifica (runner settings)\n'
copia "$TMP/controle"
roda controle "$TMP/controle"
if [ "$(cat "$TMP/controle.rc")" != 0 ] || grep -qE 'PULO|pulad' "$TMP/controle.log"; then
  echo "  o controle nao passou limpo — mutacoes sem valor:"; grep -E 'FALHA|PULO|esperava|obteve' "$TMP/controle.log" | head -8
  exit 1
fi
tail -1 "$TMP/controle.log" | sed 's/^/  /'

FALHOU=0
for m in $MUTACOES; do
  copia "$TMP/$m"
  if ! aplica "$m" "$TMP/$m" 2> "$TMP/$m.aplica"; then
    FALHOU=1; printf '  %-4s NAO APLICADA  %s\n' "$m" "$(cat "$TMP/$m.aplica")"; continue
  fi
  if [ ! -f "$TMP/$m.pos.sh" ] && [ ! -f "$TMP/$m.xd" ] && diff -r -q -x .git "$TMP/controle" "$TMP/$m" >/dev/null 2>&1; then
    FALHOU=1; printf '  %-4s NAO APLICADA  (arvore identica ao controle)\n' "$m"; continue
  fi
  case "$m" in
    Z7) roda_q "$m" "$TMP/$m" qe ;;
    Z1|Z2|Z3|Z4|Z5|Z6|V1|V2|V3|V4|V5|V6|V7) roda_q "$m" "$TMP/$m" q ;;
    *) roda "$m" "$TMP/$m" ;;
  esac
  onde_morreu="$(grep -m1 '^  FALHA' "$TMP/$m.log" | awk '{ print $2 }')"
  if [ "$(cat "$TMP/$m.rc")" = 0 ] || [ -z "$onde_morreu" ]; then
    FALHOU=1; printf '  %-4s SOBREVIVEU    %s\n' "$m" "$(tail -1 "$TMP/$m.log")"
  elif printf '%s\n' "$onde_morreu" | grep -Eq "$(onde "$m")"; then
    printf '  %-4s morta         %s\n' "$m" "$(grep -m1 '^  FALHA' "$TMP/$m.log" | sed 's/^  FALHA *//')"
  else
    FALHOU=1; printf '  %-4s MORTA FORA    em %s, esperado %s: %s\n' "$m" "$onde_morreu" "$(onde "$m")" "$(grep -m1 '^  FALHA' "$TMP/$m.log" | sed 's/^  FALHA *//')"
  fi
  rm -rf "${TMP:?}/$m"
done
echo
[ "$FALHOU" = 0 ] && echo "todas as mutacoes de integracao morreram, cada uma no checkpoint que a prova" || echo "ha mutacao viva, nao aplicada ou morta fora do lugar"
exit "$FALHOU"
