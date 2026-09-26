#!/usr/bin/env bash
#
# Certificação P0.2 (C7-B / B1R) — o fluxo entre skills, ponta a ponta, sobre um
# produto INSTALADO PELO EXPXDEV e dirigido pelo RUNNER REAL do Claude Code.
#
# O B1 anterior montava a fixture à mão: extraía as skills, juntava o
# `.expx/hooks.json` com jq, escrevia o lock e chamava cada hook direto pelo shell,
# numa ordem em que o teste da task só nascia depois do replanejamento. Esta
# recertificação troca as três coisas:
#
#   INSTALAÇÃO  um produto Git novo chega ao estado operacional SÓ pelo
#               `expxdev init` do pin — hooks, settings, manifesto de modos,
#               catálogo de método e lock são dele, e o doctor os declara íntegros.
#   RUNNER      as escritas que definem a fronteira de segurança passam pelo
#               `claude -p` real (2.1.x), com os hooks que o settings.json
#               instalado registra. O bloqueio é o do Claude Code: a ferramenta
#               não executa, e a evidência é o `tool_result` dele.
#   TDD-FIRST   TESTE → RED → BLOQUEIO → REPLANEJAMENTO → IMPLEMENTAÇÃO → GREEN:
#               o teste escrito antes do defeito vira o parcial seguro da sprintx
#               (`parciais_replanejamento_f6`, DS-156), atravessa a rodada byte a
#               byte e entra no E1 da task reaberta.
#
#   I   instalação real e a prova dela (hooks, ids, settings, timeouts, modos,
#       catálogo, núcleo, lock, doctor) — e jq visível NO PROCESSO dos hooks
#   P1  o runner escreve o teste (permitido), a suíte fica vermelha, o runner
#       tenta X da irmã e o `escopo-da-task` instalado barra: X intacto, sem
#       `arquivo_alterado`
#   P2  B-NN `defeito_de_plano`, o buildx manda o passo 3 sem pré-julgar a árvore
#       (D-40), `replanejar-execucao` preserva o teste; a divergência para
#   P3  F3/F4/F5 do plano corrigido; o parcial continua o mesmo
#   P4  o runner edita X e implementa; verde; a ordem é provada pelo rastro
#   P5  E1 real instalado: inventário da árvore inteira, lista fechada, omissão
#   P6–P11  concorrência, V11, pre-e2, E2, E3–E5, pre-e6, E6–E8: ENTREGA terminal
#   P12 prova E; P13 o buildx segue pela entrega commitada, sem PEND nem sucessora
#   H/M backstop do E1 numa fixture recém-instalada, e a ordem inversa da instalação
#   L   os terminais da F6 e as causas, pelas bancadas determinísticas do harness,
#       nos pins de produção
#
# Os SHAs são os PINS DE PRODUÇÃO (B2): a certificação os lê do harness
# (`integracao.sh`, a única fonte de execução) e não os repete. Um SHA diferente do
# pin só entra com C7B_MODO_TESTE=1, declarado — e então o resultado NÃO é a
# certificação final. O expx-lock não é a fonte da proveniência Git: D-42.
#
# Uso:
#   bash scripts/ci/certifica-p02.sh
#   bash scripts/ci/certifica-p02.sh --ambiente     # só confere as ferramentas
#   bash scripts/ci/certifica-p02.sh --pins         # só resolve e imprime os pins
#
#   C7B_MODO_TESTE=1       declara o modo de teste: sem ele, override de SHA FALHA
#   C7B_SPRINTX_SHA / C7B_MERGEX_SHA / C7B_EXPXDEV_SHA   SÓ com o modo de teste; 40 hex
#   C7B_SPRINTX_FONTE / C7B_MERGEX_FONTE / C7B_EXPXDEV_FONTE
#                          repositório de onde clonar no SHA; padrão: a irmã ao lado
#   C7B_EXPXDEV_BUILD      checkout do expxdev JÁ construído no SHA (dist/); sem ele,
#                          o expxdev do pin é clonado e construído aqui (npm ci + build)
#   C7B_RUNNER=claude      padrão: o `claude -p` real dirige as escritas críticas
#   C7B_RUNNER=settings    SEM runner real: os hooks do settings.json instalado são
#                          despachados como o Claude Code os despacha. É o modo das
#                          mutações e do Linux sem Claude Code — e o relatório diz qual
#   C7B_RUNNER_MODELO      modelo do runner real (padrão: haiku)
#   C7B_EVIDENCIA=<dir>    copia para lá os logs do runner e das instalações
#   C7B_PRESERVAR=0        apaga os temporários também quando falha
#   C7B_POS_EXTRACAO=<script>  SÓ para as mutações: `<script> <sprintx> <mergex>`
#                          roda sobre as fontes clonadas, antes do `expxdev init`
#
# Sai != 0 na PRIMEIRA quebra. Nunca escreve nos repositórios fonte e prova no fim
# que eles continuam como estavam. Nada é pulado: ferramenta ausente é FALHA.

set -uo pipefail

EU="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SLUG=feature-atual
PROJ_NOME=c7b
PROJ=buildx/$PROJ_NOME

C7B_SPRINTX_FONTE="${C7B_SPRINTX_FONTE:-$REPO/../sprintx}"
C7B_MERGEX_FONTE="${C7B_MERGEX_FONTE:-$REPO/../mergex}"
C7B_EXPXDEV_FONTE="${C7B_EXPXDEV_FONTE:-$REPO/../expxdev}"
C7B_RUNNER="${C7B_RUNNER:-claude}"
C7B_RUNNER_MODELO="${C7B_RUNNER_MODELO:-haiku}"

case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1 ;; *) WIN=0 ;; esac
nativo() { if [ "$WIN" = 1 ]; then cygpath -m "$1"; else printf '%s\n' "$1"; fi; }

# ---------------------------------------------------------------------------
# Ambiente controlado: sem pulo. Falta de ferramenta é FALHA, e diz qual.
# ---------------------------------------------------------------------------
ambiente() {
  local c falta=""
  for c in git jq awk sed tar find sort cksum mktemp grep cut tr paste node sha256sum; do
    type -P "$c" >/dev/null 2>&1 || falta="$falta $c"
  done
  [ -z "$falta" ] || { printf 'ambiente: ferramenta ausente:%s\n' "$falta" >&2; return 1; }
  [ -n "${EPOCHREALTIME:-}" ] || { printf 'ambiente: bash sem EPOCHREALTIME (exige bash 5)\n' >&2; return 1; }
  return 0
}

if [ "${1:-}" = --ambiente ]; then
  ambiente && { printf 'ambiente=ok\n'; exit 0; }
  exit 1
fi

# ---------------------------------------------------------------------------
# A guarda estrutural (B1R-O): este script não pode voltar ao modelo da fixture
# manual. Ela lê o próprio texto antes de qualquer coisa e falha se ele copiar
# hooks ou skills, escrever settings.json, .expx/hooks.json ou o catálogo, chamar
# install.sh — ou chamar hook direto dentro de um caso marcado como runner-real.
# As linhas desta função carregam a marca [guarda] e são as únicas isentas.
# ---------------------------------------------------------------------------
guarda_estrutural() { # <script> -> uma linha por violação, "<regra>:<linha>"   # [guarda]
  tr -d '\r' < "$1" | awk '                                                     # [guarda]
    /\[guarda\]/ { next }                                                       # [guarda]
    /^[[:space:]]*# >>> runner-real/ { if (em) print "G6-regiao-aninhada:" NR; em = 1; ab = NR; n++; next }   # [guarda]
    /^[[:space:]]*# <<< runner-real/ { if (!em) print "G6-regiao-sem-abertura:" NR; em = 0; next }            # [guarda]
    /^[[:space:]]*#/ { next }                                                   # [guarda]
    /(^|[;&|({[:space:]])(cp|rsync|ln|install|tar)[[:space:]][^#]*\.claude(\/|"|[[:space:]]|$)/ { print "G1-copia-de-.claude:" NR }   # [guarda]
    /settings(\.local)?\.json/ && /(>|tee[[:space:]]|sed[[:space:]]+-i|mv[[:space:]]|cp[[:space:]])/ { print "G2-escreve-settings:" NR }   # [guarda]
    /hooks\.json/ && /(>|tee[[:space:]]|sed[[:space:]]+-i|mv[[:space:]]|cp[[:space:]])/ { print "G3-escreve-hooks.json:" NR }   # [guarda]
    /expx-lock\.json/ && /(>|tee[[:space:]]|sed[[:space:]]+-i|mv[[:space:]]|cp[[:space:]])/ { print "G3-escreve-lock:" NR }   # [guarda]
    /catalogo-de-metodo/ && /(^|[;&|({[:space:]])(cp|rsync|ln|install|mv|tar)[[:space:]]/ { print "G4-copia-catalogo:" NR }   # [guarda]
    /(^|[;&|({[:space:]])(bash|sh|source|exec|\.)[[:space:]]+[^#;|&]*install\.sh/ { print "G5-install.sh:" NR }   # [guarda]
    /(^|[;&|({[:space:]])[^[:space:]]*\/install\.sh([[:space:]]|$)/ { print "G5-install.sh:" NR }   # [guarda]
    em && /(\.claude\/hooks|despacha|escreve|[[:space:]]hook[[:space:]])/ { print "G6-hook-direto-em-runner-real:" NR }   # [guarda]
    !em && /(^|[;&|({[:space:]])runner_(write|edit|bash)[[:space:]]/ && !/\(\)[[:space:]]*\{/ { print "G7-runner-fora-da-regiao:" NR }   # [guarda]
    END { if (em) print "G6-regiao-aberta:" ab; print "REGIOES " n + 0 }        # [guarda]
  '                                                                             # [guarda]
}                                                                               # [guarda]

# As provas do buildx vêm do harness de integração, carregado como biblioteca:
# uma implementação só dos portões, da prova E e da matriz de retomada.
BUILDX_BIBLIOTECA=1
# shellcheck source=integracao.sh
. "$REPO/scripts/ci/integracao.sh"

# O jq do Windows escreve CRLF; o código de saída continua o dele (pipefail).
jq() { command jq "$@" | tr -d '\r'; }

# Os pins de produção vêm do harness: SPRINTX_SHA_FIXO, MERGEX_SHA_FIXO e
# EXPXDEV_SHA_FIXO, 40 hex. Nenhum SHA é escrito aqui. Override é exceção declarada.
PINS_MODO=producao; PINS_DIVERGENTES=""
for pin_n in SPRINTX MERGEX EXPXDEV; do
  pin_f="${pin_n}_SHA_FIXO"; pin_v="C7B_${pin_n}_SHA"
  printf '%s\n' "${!pin_f}" | grep -Eq '^[0-9a-f]{40}$' ||
    { printf 'pins: %s nao e SHA completo (40 hex): %s\n' "$pin_f" "${!pin_f}" >&2; exit 1; }
  [ "${!pin_v:-${!pin_f}}" = "${!pin_f}" ] || PINS_DIVERGENTES="$PINS_DIVERGENTES $pin_v"
  printf -v "$pin_v" %s "${!pin_v:-${!pin_f}}"
done
if [ -n "$PINS_DIVERGENTES" ]; then
  if [ "${C7B_MODO_TESTE:-0}" = 1 ]; then
    PINS_MODO=teste
  else
    printf 'pins: override de SHA sem modo de teste declarado:%s (o pin de producao e o do harness; C7B_MODO_TESTE=1 declara o teste)\n' \
      "$PINS_DIVERGENTES" >&2
    exit 1
  fi
fi
if [ "${1:-}" = --pins ]; then
  printf 'pins: modo=%s\nsprintx=%s\nmergex=%s\nexpxdev=%s\n' "$PINS_MODO" "$C7B_SPRINTX_SHA" "$C7B_MERGEX_SHA" "$C7B_EXPXDEV_SHA"
  [ "$PINS_MODO" = producao ] || printf 'MODO DE TESTE (override:%s): NAO e a certificacao final\n' "$PINS_DIVERGENTES"
  exit 0
fi

INICIO_TOTAL="$EPOCHREALTIME"
PASSOU=0
DIAG=""
EVID="$TMP_RAIZ/evidencia"; mkdir -p "$EVID"
: > "$EVID/sessoes"

encerra() {
  local rc=$? s
  cd / 2>/dev/null
  [ -z "${C7B_EVIDENCIA:-}" ] || { mkdir -p "$C7B_EVIDENCIA" && cp -R "$EVID/." "$C7B_EVIDENCIA/" 2>/dev/null; }
  # As sessões que o runner real abriu são deste script: os transcritos delas saem
  # do ~/.claude, e só eles — casados pelo id exato que este script gerou.
  if [ -s "$EVID/sessoes" ] && [ -d "$HOME/.claude/projects" ]; then
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      find "$HOME/.claude/projects" -maxdepth 2 -name "$s.jsonl" -type f 2>/dev/null | while IFS= read -r t; do
        rm -f "$t"; rmdir "$(dirname "$t")/memory" "$(dirname "$t")" 2>/dev/null   # só se ficaram vazias
      done
    done < "$EVID/sessoes"
    # O Claude Code também abre pasta de projeto para o checkout de controle de uma
    # worktree: as que nasceram de caminhos DESTA rodada saem, e só se vazias.
    for s in "$HOME/.claude/projects/$(nativo "$TMP_RAIZ" | sed 's/[^A-Za-z0-9]/-/g')"-*; do
      [ -d "$s" ] && rmdir "$s/memory" "$s" 2>/dev/null
    done
  fi
  if [ "$rc" = 0 ] || [ "${C7B_PRESERVAR:-1}" = 0 ]; then
    rm -rf "$TMP_RAIZ"
  else
    printf '\ndiagnostico preservado em %s\n' "$TMP_RAIZ"
  fi
  exit "$rc"
}
trap encerra EXIT

quebra() {
  printf '\nCERTIFICACAO QUEBROU (%d checkpoints passaram antes)\n' "$PASSOU"
  [ -z "$DIAG" ] || printf '%s\n' "$DIAG" | sed 's/^/  | /'
  exit 1
}

ck() { # ck <id> <descricao> <esperado> <obtido>
  if [ "$3" = "$4" ]; then
    PASSOU=$((PASSOU + 1)); printf '  ok    %-7s %s\n' "$1" "$2"
  else
    printf '  FALHA %-7s %s\n          esperava: %s\n          obteve:   %s\n' "$1" "$2" "$3" "$4"
    quebra
  fi
}

passo() { printf '\n== %s\n' "$*"; }
sn() { if "$@" >/dev/null 2>&1; then echo sim; else echo nao; fi; }
evidencia() { printf '          %s\n' "$@"; }

TEMPOS=""
ms_desde() { awk -v a="${1/,/.}" -v b="${EPOCHREALTIME/,/.}" 'BEGIN { printf "%d", (b - a) * 1000 }'; }
anota_tempo() { TEMPOS="$TEMPOS$1	$2
"; }

printf 'certificacao P0.2 — C7-B / B1R (instalacao real, runner %s)\n' "$C7B_RUNNER"
printf '  sprintx %s  (%s)\n  mergex  %s  (%s)\n  expxdev %s  (%s)\n' \
  "$C7B_SPRINTX_SHA" "$C7B_SPRINTX_FONTE" "$C7B_MERGEX_SHA" "$C7B_MERGEX_FONTE" "$C7B_EXPXDEV_SHA" "$C7B_EXPXDEV_FONTE"
if [ "$PINS_MODO" = producao ]; then
  printf '  pins: os de producao, sem override\n'
else
  printf '  ATENCAO: MODO DE TESTE, override de SHA (%s ): NAO e a certificacao final\n' "${PINS_DIVERGENTES# }"
fi
[ -z "${C7B_POS_EXTRACAO:-}" ] || printf '  ATENCAO: C7B_POS_EXTRACAO=%s (mutacao de integracao)\n' "$C7B_POS_EXTRACAO"

passo "G guarda estrutural: nenhuma instalacao manual, nenhum hook direto no runner real"
GUARDA="$(guarda_estrutural "$EU")"
ck G.1 "o script nao copia hooks/skills, nao escreve settings, hooks.json, lock nem catalogo, nao chama install.sh" "" \
  "$(printf '%s\n' "$GUARDA" | grep -v '^REGIOES ' | paste -sd' ' -)"
ck G.2 "os casos runner-real estao marcados (J x2, P1 teste e X, P4 X e impl, H/M x3)" "REGIOES 9" "$(printf '%s\n' "$GUARDA" | grep '^REGIOES ')"
ambiente || { printf '  FALHA  ambiente nao controlado\n'; quebra; }
case "$C7B_RUNNER" in claude|settings) ;; *) DIAG="C7B_RUNNER=$C7B_RUNNER"; quebra ;; esac

# ---------------------------------------------------------------------------
# A — fontes por SHA completo, e o ExpxDev dos pins de produção
# ---------------------------------------------------------------------------
sha_completo() { printf '%s\n' "$1" | grep -Eq '^[0-9a-f]{40}$'; }

estado_fonte() { # <fonte> — o que "não modificar" quer dizer, de forma comparável
  if [ -d "$1" ]; then
    git -c safe.directory='*' -C "$1" rev-parse HEAD 2>/dev/null
    git -c safe.directory='*' -C "$1" for-each-ref --format='%(refname) %(objectname)' 2>/dev/null
    git -c safe.directory='*' -C "$1" --no-optional-locks status --porcelain --untracked-files=all 2>/dev/null
  else
    printf 'url %s\n' "$1"
  fi
}

# clona <nome> <fonte> <sha> <destino> — clone sem checkout, LF, e o checkout
# DESTACADO no SHA. É daqui que o `expxdev init` copia a skill (EXPX_SKILLS_LOCAIS).
clona() {
  local nome="$1" fonte="$2" sha="$3" dest="$4" ref
  sha_completo "$sha" || { DIAG="$nome: '$sha' nao e SHA completo"; return 1; }
  git -c safe.directory='*' clone -q -c core.autocrlf=false --no-checkout "$fonte" "$dest" 2>/dev/null ||
    { DIAG="$nome: nao foi possivel clonar $fonte"; return 1; }
  git -C "$dest" cat-file -e "$sha^{commit}" 2>/dev/null || { DIAG="$nome: $sha nao existe em $fonte"; return 1; }
  ref="$sha"                                                                 # [P15]
  git -C "$dest" -c advice.detachedHead=false checkout -q --detach "$ref" || { DIAG="$nome: checkout $ref falhou"; return 1; }
  printf '%s\n' "$ref" > "$TMP_RAIZ/ref-$nome"
}

passo "A fontes por SHA completo e o ExpxDev dos pins de producao"
if [ "$PINS_MODO" = producao ]; then
  ck A.0 "os SHAs desta certificacao sao os pins de producao do harness, sem override" \
    "$SPRINTX_SHA_FIXO $MERGEX_SHA_FIXO $EXPXDEV_SHA_FIXO" "$C7B_SPRINTX_SHA $C7B_MERGEX_SHA $C7B_EXPXDEV_SHA"
else
  printf '          A.0 pulado de proposito: modo de teste declarado (override:%s)\n' "$PINS_DIVERGENTES"
fi
for s in "$C7B_SPRINTX_SHA" "$C7B_MERGEX_SHA" "$C7B_EXPXDEV_SHA"; do
  ck A.1 "o SHA $s e completo (40 hex)" sim "$(sn sha_completo "$s")"
done
FONTE_SX_ANTES="$(estado_fonte "$C7B_SPRINTX_FONTE")"
FONTE_MX_ANTES="$(estado_fonte "$C7B_MERGEX_FONTE")"
FONTE_XD_ANTES="$(estado_fonte "$C7B_EXPXDEV_FONTE")"
SRC="$TMP_RAIZ/fontes"; mkdir -p "$SRC"
ck A.2 "a sprintx e clonada no SHA" sim "$(sn clona sprintx "$C7B_SPRINTX_FONTE" "$C7B_SPRINTX_SHA" "$SRC/sprintx")"
ck A.3 "a mergex e clonada no SHA"  sim "$(sn clona mergex "$C7B_MERGEX_FONTE" "$C7B_MERGEX_SHA" "$SRC/mergex")"
ck A.4 "o checkout da sprintx usou o SHA completo, nao branch nem SHA curto" "$C7B_SPRINTX_SHA" "$(cat "$TMP_RAIZ/ref-sprintx")"
ck A.5 "o checkout da mergex usou o SHA completo, nao branch nem SHA curto"  "$C7B_MERGEX_SHA" "$(cat "$TMP_RAIZ/ref-mergex")"
ck A.6 "a fonte da sprintx esta no pin" "$C7B_SPRINTX_SHA" "$(git -C "$SRC/sprintx" rev-parse HEAD)"
ck A.7 "a fonte da mergex esta no pin"  "$C7B_MERGEX_SHA" "$(git -C "$SRC/mergex" rev-parse HEAD)"
if [ -n "${C7B_POS_EXTRACAO:-}" ]; then
  bash "$C7B_POS_EXTRACAO" "$SRC/sprintx" "$SRC/mergex" || { DIAG="C7B_POS_EXTRACAO recusou"; quebra; }
else
  ck A.8 "as fontes sao exatamente o commit: nenhum byte fora dele" " " \
    "$(git -C "$SRC/sprintx" status --porcelain --untracked-files=all) $(git -C "$SRC/mergex" status --porcelain --untracked-files=all)"
fi

if [ -n "${C7B_EXPXDEV_BUILD:-}" ]; then
  XD="$C7B_EXPXDEV_BUILD"
else
  XD="$TMP_RAIZ/expxdev"
  ck A.9 "o expxdev e clonado no SHA" sim "$(sn clona expxdev "$C7B_EXPXDEV_FONTE" "$C7B_EXPXDEV_SHA" "$XD")"
  ( cd "$XD" && npm ci --no-audit --no-fund > "$EVID/expxdev-build.log" 2>&1 && npm run build:server >> "$EVID/expxdev-build.log" 2>&1 ) ||
    { DIAG="npm ci / build do expxdev falhou: $(tail -5 "$EVID/expxdev-build.log")"; quebra; }
fi
ck A.10 "o expxdev usado esta no pin" "$C7B_EXPXDEV_SHA" "$(git -c safe.directory='*' -C "$XD" rev-parse HEAD 2>/dev/null)"
ck A.11 "e sem mudanca rastreada: o dist e do proprio SHA" "" "$(git -c safe.directory='*' -C "$XD" status --porcelain --untracked-files=no 2>/dev/null)"
ck A.12 "o binario oficial existe: dist/cli/expx-bin.js" sim "$(sn test -f "$XD/dist/cli/expx-bin.js")"
NODE="$(command -v node)"
XBIN="$(nativo "$XD/dist/cli/expx-bin.js")"

# Os PATHs: o do `init` nunca tem `claude` (o init registraria o plugin no ~/.claude
# do usuário); o do runner tem o jq numa pasta só dele, e a prova negativa tira só
# essa pasta.
JQ_DIR="$TMP_RAIZ/bin-jq"; mkdir -p "$JQ_DIR"
JQ_ORIGEM="$(type -P jq)"; [ -f "$JQ_ORIGEM.exe" ] && JQ_ORIGEM="$JQ_ORIGEM.exe"
ln -s "$JQ_ORIGEM" "$JQ_DIR/$(basename "$JQ_ORIGEM")" || { DIAG="nao foi possivel expor o jq em $JQ_DIR"; quebra; }
if [ "$WIN" = 1 ]; then BASE_PATH="/mingw64/bin:/usr/bin:/bin"; else BASE_PATH="/usr/bin:/bin"; fi
INIT_PATH="$BASE_PATH:$JQ_DIR"
RUNNER_DIRS="$BASE_PATH"
if [ "$C7B_RUNNER" = claude ]; then
  CLAUDE_BIN="$(command -v claude 2>/dev/null)"
  [ -n "$CLAUDE_BIN" ] || { DIAG="C7B_RUNNER=claude sem o binario claude no PATH"; quebra; }
  if [ "$WIN" = 1 ]; then RUNNER_DIRS="$(dirname "$CLAUDE_BIN"):$(dirname "$NODE"):$BASE_PATH"
  else mkdir -p "$TMP_RAIZ/bin-runner"; ln -s "$CLAUDE_BIN" "$TMP_RAIZ/bin-runner/claude"; ln -s "$NODE" "$TMP_RAIZ/bin-runner/node"
       RUNNER_DIRS="$TMP_RAIZ/bin-runner:$BASE_PATH"; fi
  CLAUDE_VERSAO="$("$CLAUDE_BIN" --version 2>/dev/null | tr -d '\r' | head -1)"
  ck A.13 "o runner real e o Claude Code 2.1.x" sim "$(sn eval 'printf "%s" "$CLAUDE_VERSAO" | grep -Eq "^2\.1\.[0-9]+ \(Claude Code\)"')"
  evidencia "runner: $CLAUDE_VERSAO ($CLAUDE_BIN), modelo $C7B_RUNNER_MODELO"
fi
RUNNER_PATH="$RUNNER_DIRS:$JQ_DIR"                                           # [Y15]
RUNNER_PATH_SEM_JQ="$RUNNER_DIRS"
ck A.14 "o PATH do init nao alcanca o claude" "" "$(PATH="$INIT_PATH" type -P claude)"
ck A.15 "o PATH sem jq nao alcanca jq nenhum" "" "$(PATH="$RUNNER_PATH_SEM_JQ" type -P jq)"

# O runner nasce sem a identidade desta sessão: nenhuma variável CLAUDE* do
# processo pai chega a ele, nem aos hooks que ele dispara.
SEM_CLAUDE=(env)
while IFS= read -r v; do
  case "$v" in CLAUDE_CONFIG_DIR|CLAUDE_CODE_GIT_BASH_PATH) ;; *) SEM_CLAUDE+=(-u "$v") ;; esac
done < <(compgen -e | grep -E '^(CLAUDE|CLAUDECODE)')

uuid() { "$NODE" -e 'console.log(require("crypto").randomUUID())' | tr -d '\r'; }
expx_no_claude_global() { # as entradas do expx no registro global de plugins do usuário
  ( cd "$HOME/.claude/plugins" 2>/dev/null &&
      { jq -r 'keys[]' known_marketplaces.json 2>/dev/null; jq -r '.plugins // {} | keys[]' installed_plugins.json 2>/dev/null; } ) |
    grep -i 'expx' | LC_ALL=C sort | paste -sd' ' -
}
PLUGINS_ANTES="$(expx_no_claude_global)"

# ---------------------------------------------------------------------------
# A instalação real e a prova dela
# ---------------------------------------------------------------------------
instala() { # <produto> <ordem> — só o binário oficial do pin
  local log="$EVID/init-$(basename "$1").log"
  ( cd "$1" && "${SEM_CLAUDE[@]}" PATH="$INIT_PATH" EXPX_SKILLS_LOCAIS="$(nativo "$SRC")" \
      "$NODE" "$XBIN" init --skills "$2" --yes ) > "$log" 2>&1
  INIT_RC=$?
  INIT_SAIDA="$(tr -d '\r' < "$log")"
}
doctor() { ( cd "$1" && PATH="$INIT_PATH" "$NODE" "$XBIN" doctor ) 2>&1 | tr -d '\r'; }
sha_de() { sha256sum < "$1" | cut -d' ' -f1; }

# As tuplas (evento, matcher, comando, timeout) de um settings.json.
tuplas() {
  tr -d '\r' < "$1" | jq -c '[.hooks // {} | to_entries[] | .key as $e | .value[] | (.matcher // "") as $m
    | .hooks[] | [$e, $m, .command, (.timeout // null)]] | sort | .[]'
}
# Os arquivos que cada skill publica e o init copia: hooks e a pasta da skill.
publicados() { # <fonte> <skill>
  ( cd "$1" && git ls-files -- .claude/hooks ".claude/skills/$2" ) | grep -v '^\.claude/hooks/hooks\.json$'
}

prova_instalacao() { # <produto> <prefixo>
  local p="$1" x="$2" f s d
  ck "$x.1" ".claude/hooks/sprintx/ existe" sim "$(sn test -d "$p/.claude/hooks/sprintx")"
  ck "$x.2" ".claude/hooks/mergex/ existe" sim "$(sn test -d "$p/.claude/hooks/mergex")"
  ck "$x.3" "os dois git-perigoso existem" "sim sim" \
    "$(sn test -f "$p/.claude/hooks/sprintx/git-perigoso.sh") $(sn test -f "$p/.claude/hooks/mergex/git-perigoso.sh")"
  ck "$x.4" "ids distintos, cada arquivo com o seu, e os dois arquivos diferem" "sim sim sim sim" \
    "$(sn jq -e '.hooks["sprintx/git-perigoso"] and .hooks["mergex/git-perigoso"]' "$p/.expx/hooks.json") \
$(sn grep -q 'sprintx/git-perigoso' "$p/.claude/hooks/sprintx/git-perigoso.sh") \
$(sn grep -q 'mergex/git-perigoso' "$p/.claude/hooks/mergex/git-perigoso.sh") \
$(sn test "$(sha_de "$p/.claude/hooks/sprintx/git-perigoso.sh")" != "$(sha_de "$p/.claude/hooks/mergex/git-perigoso.sh")")"
  ck "$x.5" "o settings registra os dois git-perigoso em PreToolUse/Bash, uma vez cada" "1 1" \
    "$(tuplas "$p/.claude/settings.json" | grep -c '^\["PreToolUse","Bash",[^,]*hooks/sprintx/git-perigoso\.sh') \
$(tuplas "$p/.claude/settings.json" | grep -c '^\["PreToolUse","Bash",[^,]*hooks/mergex/git-perigoso\.sh')"
  ck "$x.6" "timeouts criticos: git-perigoso x2, escopo-da-task e segredo em 30 s" "30 30 30 30" \
    "$(for h in sprintx/git-perigoso mergex/git-perigoso sprintx/escopo-da-task comum/segredo; do
         tuplas "$p/.claude/settings.json" | grep -F "hooks/$h.sh" | head -1 | jq -r '.[3]'; done | paste -sd' ' -)"
  for s in sprintx mergex; do
    ck "$x.6$s" "toda entrada de hook do settings da $s, com o timeout dela, esta instalada" "" \
      "$(tuplas "$SRC/$s/.claude/settings.json" | grep -vxF -f <(tuplas "$p/.claude/settings.json") || true)"
    ck "$x.7$s" "todo id de modo da $s esta no .expx/hooks.json, com o modo publicado" "" \
      "$(tr -d '\r' < "$SRC/$s/.expx/hooks.json" | jq -c '.hooks | to_entries[] | [.key, .value.modo]' |
         grep -vxF -f <(tr -d '\r' < "$p/.expx/hooks.json" | jq -c '.hooks | to_entries[] | [.key, .value.modo]') || true)"
    d="$(publicados "$SRC/$s" "$s" | while IFS= read -r f; do
           [ -f "$p/$f" ] && [ "$(sha_de "$p/$f")" = "$(sha_de "$SRC/$s/$f")" ] || echo "$f"; done)"
    ck "$x.8$s" "hooks e skill da $s instalados byte a byte ($(publicados "$SRC/$s" "$s" | wc -l | tr -d ' ') arquivos)" "" "$d"
  done
  f=.claude/skills/mergex/scripts/catalogo-de-metodo.sh
  ck "$x.9" "catalogo-de-metodo.sh instalado, identico ao do pin" sim \
    "$(sn test "$(sha_de "$p/$f" 2>/dev/null)" = "$(sha_de "$SRC/mergex/$f")")"
  ck "$x.10" "nucleo do ExpxDev: expx-session-sync (SessionStart) e expx-lembrete (UserPromptSubmit)" "sim sim 1 1" \
    "$(sn test -f "$p/.claude/hooks/expx-session-sync.mjs") $(sn test -f "$p/.claude/hooks/expx-lembrete.sh") \
$(tr -d '\r' < "$p/.claude/settings.json" | jq '[.hooks.SessionStart[]?.hooks[]? | select((.args // []) | join(" ") | test("expx-session-sync\\.mjs"))] | length') \
$(tr -d '\r' < "$p/.claude/settings.json" | jq '[.hooks.UserPromptSubmit[]?.hooks[]? | select(.command | test("expx-lembrete\\.sh"))] | length')"
  ck "$x.11" "o lock trava as duas skills no identificador local do commit (informativo: a proveniencia e o SHA completo, D-42)" "${C7B_MERGEX_SHA:0:12}-local ${C7B_SPRINTX_SHA:0:12}-local" \
    "$(tr -d '\r' < "$p/.expx/expx-lock.json" | jq -r '.skills.mergex.commit + " " + .skills.sprintx.commit')"
  ck "$x.12" "todo arquivo do lock confere com o disco" "" \
    "$(tr -d '\r' < "$p/.expx/expx-lock.json" | jq -r '.instalacao.arquivos | to_entries[] | .key + "\t" + .value' |
       while IFS='	' read -r f s; do [ "$(sha_de "$p/$f" 2>/dev/null)" = "$s" ] || echo "$f"; done)"
  DOCTOR="$(doctor "$p")"; DOCTOR_RC=$?
  ck "$x.13" "doctor: instalacao integra (nenhum [erro], so o aviso de versao sem tag)" "0 0" \
    "$(cd "$p" && PATH="$INIT_PATH" "$NODE" "$XBIN" doctor >/dev/null 2>&1; echo $?) $(printf '%s\n' "$DOCTOR" | grep -c '^\[erro\]')"
  ck "$x.14" "o init nao chamou install.sh de skill nenhuma, e nao ha install.sh no produto" "" \
    "$(find "$p/.claude" "$p/.expx" -name install.sh 2>/dev/null)"
}

# ---------------------------------------------------------------------------
# Runner: o Claude Code real, ou o despacho do settings.json instalado
# ---------------------------------------------------------------------------
# despacha <dir> <uuid> <evento> <ferramenta> <payload> [PATH] -> DESP_RC, DESP_SAIDA
# Os comandos do settings.json INSTALADO para o evento e a ferramenta, na ordem
# dele, com o payload no stdin e a identidade que o Claude Code dá ao hook
# (CLAUDECODE, CLAUDE_CODE_SESSION_ID, CLAUDE_PROJECT_DIR). Código 2 bloqueia.
despacha() {
  local d="$1" u="$2" ev="$3" fer="$4" json="$5" p="${6:-$RUNNER_PATH}" cmd saida rc ini
  DESP_RC=0; DESP_SAIDA=""
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    ini="$EPOCHREALTIME"
    saida="$(printf '%s' "$json" | (cd "$d" && "${SEM_CLAUDE[@]}" PATH="$p" CLAUDE_PROJECT_DIR="$d" CLAUDECODE=1 \
      CLAUDE_CODE_SESSION_ID="$u" bash -c "$cmd") 2>&1)"; rc=$?
    anota_tempo "hook ${cmd##*/hooks/}" "$(ms_desde "$ini")"
    [ "$rc" = 2 ] && { DESP_RC=2; DESP_SAIDA="$DESP_SAIDA$saida"; }
  done <<EOF
$(tr -d '\r' < "$d/.claude/settings.json" | jq -r --arg ev "$ev" --arg f "$fer" '.hooks[$ev] // [] | .[]
  | select((.matcher // "") as $m | $m == "" or ($f | test("^(" + $m + ")$"))) | .hooks[]
  | select(.type == "command" and ((.args // []) | length) == 0) | .command')
EOF
}

payload_escrita() { # <dir> <rel> <conteudo>
  jq -cn --arg cwd "$1" --arg f "$1/$2" --arg c "$3" '{cwd:$cwd, tool_name:"Write", tool_input:{file_path:$f, content:$c}}'
}

claude_roda() { # <dir> <uuid> <PATH> <ferramentas> <prompt> -> RUN_LOG
  local d="$1" u="$2" p="$3" t="$4" pr="$5" ini sessao
  RUNNER_N=$((${RUNNER_N:-0} + 1)); RUN_LOG="$EVID/runner-$(printf %02d "$RUNNER_N").jsonl"
  if grep -qx "$u" "$EVID/sessoes"; then sessao=(--resume "$u"); else sessao=(--session-id "$u"); printf '%s\n' "$u" >> "$EVID/sessoes"; fi
  ini="$EPOCHREALTIME"
  ( cd "$d" && "${SEM_CLAUDE[@]}" PATH="$p" "$CLAUDE_BIN" -p "$pr" "${sessao[@]}" --model "$C7B_RUNNER_MODELO" \
      --tools "$t" --allowedTools "$t" --permission-mode acceptEdits \
      --settings '{"enabledPlugins":{"expx@expx-local":false}}' \
      --output-format stream-json --verbose --max-turns 4 < /dev/null > "$RUN_LOG" 2> "$RUN_LOG.err" )
  anota_tempo "runner claude -p" "$(ms_desde "$ini")"
  RUN_SID="$(tr -d '\r' < "$RUN_LOG" | jq -r 'select(.type == "system" and .subtype == "init") | .session_id' 2>/dev/null | head -1)"
}

# runner_le <ferramenta> <alvo> — o tool_use daquela ferramenta sobre aquele alvo, e
# o tool_result dele: 0 executou, 2 bloqueado por hook PreToolUse, 9 outra coisa.
runner_le() {
  local j
  j="$(tr -d '\r' < "$RUN_LOG" | jq -rs --arg t "$1" --arg a "$2" '
    ([.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == $t)
      | select(((.input.file_path // .input.command // "") | gsub("\\\\"; "/")) | (. == $a or endswith("/" + $a)))] | last) as $u
    | if $u == null then "nao\t9\t" else
        ([.[] | select(.type == "user") | .message.content[]? | select(.type == "tool_result" and .tool_use_id == $u.id)] | last) as $r
        | (($r.content // "") | if type == "array" then map(.text // "") | join("") else tostring end) as $c
        | if $r == null then "sim\t9\t"
          elif ($c | test("PreToolUse:" + $u.name + " hook error")) then "sim\t2\t" + $c
          elif ($r.is_error // false) then "sim\t9\t" + $c
          else "sim\t0\t" + $c end
      end' 2>/dev/null)"
  RUN_TENTOU="${j%%	*}"; j="${j#*	}"; RUN_RC="${j%%	*}"; RUN_SAIDA="${j#*	}"
  [ -n "$RUN_RC" ] || RUN_RC=9
  evidencia "runner real: sessao $RUN_SID, $1 $2 -> $(case "$RUN_RC" in 0) echo executou ;; 2) echo 'bloqueado pelo hook' ;; *) echo "falha ($RUN_TENTOU)" ;; esac) [$(basename "$RUN_LOG")]"
}

FIM_DE_TEXTO='Use no other tool. If the tool call is blocked or fails, do not retry and do not try anything else: just reply BLOQUEADO.'

runner_write() { # <dir> <uuid> <rel> <conteudo>
  local d="$1" u="$2" rel="$3" c="$4" json
  RUN_RC=9; RUN_SAIDA=""; RUN_TENTOU=nao
  if [ "$C7B_RUNNER" = claude ]; then
    claude_roda "$d" "$u" "$RUNNER_PATH" Write "Use the Write tool exactly once to create the file $(nativo "$d")/$rel. Its content must be exactly the lines between BEGIN and END below (not the marker lines themselves), ending with one newline.
BEGIN
${c}END
$FIM_DE_TEXTO"
    runner_le Write "$rel"
  else
    json="$(payload_escrita "$d" "$rel" "$c")"; RUN_TENTOU=sim
    despacha "$d" "$u" PreToolUse Write "$json"
    if [ "$DESP_RC" = 2 ]; then RUN_RC=2; RUN_SAIDA="$DESP_SAIDA"; return 0; fi
    mkdir -p "$(dirname "$d/$rel")"; printf '%s' "$c" > "$d/$rel"
    despacha "$d" "$u" PostToolUse Write "$json"; RUN_RC=0
  fi
}

runner_edit() { # <dir> <uuid> <rel> <antigo> <novo>
  local d="$1" u="$2" rel="$3" a="$4" n="$5" json atual
  RUN_RC=9; RUN_SAIDA=""; RUN_TENTOU=nao
  if [ "$C7B_RUNNER" = claude ]; then
    claude_roda "$d" "$u" "$RUNNER_PATH" Read,Edit "First use the Read tool on $(nativo "$d")/$rel. Then use the Edit tool exactly once on that file, replacing the exact text
OLD: $a
with the exact text
NEW: $n
(the text after 'OLD: ' and 'NEW: ', up to the end of each line). $FIM_DE_TEXTO"
    runner_le Edit "$rel"
  else
    json="$(jq -cn --arg cwd "$d" --arg f "$d/$rel" --arg a "$a" --arg n "$n" \
      '{cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f, old_string:$a, new_string:$n}}')"; RUN_TENTOU=sim
    despacha "$d" "$u" PreToolUse Edit "$json"
    [ "$DESP_RC" = 2 ] && { RUN_RC=2; RUN_SAIDA="$DESP_SAIDA"; return 0; }                   # [Y5]
    atual="$(cat "$d/$rel"; printf x)"; atual="${atual%x}"
    printf '%s' "${atual/"$a"/"$n"}" > "$d/$rel"
    despacha "$d" "$u" PostToolUse Edit "$json"; RUN_RC=0
  fi
}

runner_bash() { # <dir> <uuid> <PATH> <comando>
  local d="$1" u="$2" p="$3" cmd="$4" json
  RUN_RC=9; RUN_SAIDA=""; RUN_TENTOU=nao
  if [ "$C7B_RUNNER" = claude ]; then
    claude_roda "$d" "$u" "$p" Bash "Use the Bash tool exactly once to run this exact command: $cmd
Run nothing else. $FIM_DE_TEXTO"
    runner_le Bash "$cmd"
  else
    json="$(jq -cn --arg cwd "$d" --arg c "$cmd" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:$c}}')"; RUN_TENTOU=sim
    despacha "$d" "$u" PreToolUse Bash "$json" "$p"
    [ "$DESP_RC" = 2 ] && { RUN_RC=2; RUN_SAIDA="$DESP_SAIDA"; return 0; }
    RUN_SAIDA="$(cd "$d" && PATH="$p" bash -c "$cmd" 2>&1)"; RUN_RC=0
    despacha "$d" "$u" PostToolUse Bash "$json" "$p"
  fi
}

# ---------------------------------------------------------------------------
# Instrumentos do fluxo — escrita de método, suíte, eventos, E1, persistir-metodo
# ---------------------------------------------------------------------------
HOJE="$(date +%Y-%m-%d)"
S0="$(uuid)"; S1="$(uuid)"; S2="$(uuid)"     # S1 é a sessão do runner real

# escreve <uuid> <rel> <conteudo> — escrita de MÉTODO (plano, eventos da skill) pela
# ferramenta Write, com os hooks do settings instalado. ESCRITA_RC=0 gravou; 2 barrou.
escreve() {
  local json; json="$(payload_escrita "$WT" "$2" "$3")"
  ESCRITA_RC=0; ESCRITA_SAIDA=""
  despacha "$WT" "$1" PreToolUse Write "$json"
  [ "$DESP_RC" = 2 ] && { ESCRITA_RC=2; ESCRITA_SAIDA="$DESP_SAIDA"; return 0; }
  mkdir -p "$(dirname "$WT/$2")"; printf '%s' "$3" > "$WT/$2"
  despacha "$WT" "$1" PostToolUse Write "$json"
}
escreve_ok() { escreve "$@"; [ "$ESCRITA_RC" = 0 ] || { DIAG="escrita de $2 barrada: $ESCRITA_SAIDA"; quebra; }; }

# suite <uuid> — a suíte do projeto, com os hooks de Bash do settings instalado
suite() {
  local json ini
  json="$(jq -cn --arg cwd "$WT" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"bash test/suite.sh"}}')"
  despacha "$WT" "$1" PreToolUse Bash "$json"
  [ "$DESP_RC" = 0 ] || { DIAG="a suite foi barrada: $DESP_SAIDA"; quebra; }
  ini="$EPOCHREALTIME"
  SUITE_SAIDA="$(cd "$WT" && bash test/suite.sh 2>&1)"; SUITE_RC=$?
  anota_tempo "suite do projeto" "$(ms_desde "$ini")"
  despacha "$WT" "$1" PostToolUse Bash "$(jq -cn --arg cwd "$WT" --arg r "$SUITE_SAIDA" \
    '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"bash test/suite.sh"}, tool_response:$r}')"
}

# O evento que a SKILL grava (08-rastro.md), no rastro do trabalho que ela conhece,
# com a sessão como o hook a resolve: `claude-code@<id da sessão>`.
evento_skill() { # <trabalho> <evento> <task> <uuid>
  mkdir -p "$WT/docs/eventos"
  printf '{"ts":"%s","expx_eventos":1,"trabalho_id":"%s","ferramenta":"sprintx","origem":"skill","evento":"%s","fase":"f6","task":"%s","agente":"principal","resultado":"ok","detalhe":null,"arquivos":[],"sessao":"claude-code@%s","harness":"claude-code"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" "$4" >> "$WT/docs/eventos/$1.jsonl"
}

reivindicacoes() { # <uuid> — a identidade composta que o rastro instalado resolve
  ( cd "$WT" && bash -c '. "$1"; rastro_reivindicacoes_da_sessao "$2" "$3"' _ "$WT/.claude/hooks/comum/rastro.sh" "$WT" "claude-code@$1" ) | tr '\t' ' '
}

sx() { ( cd "$WT" && bash "$PLANEJAMENTO" "$@" ) 2>/dev/null; }
blq() { ( cd "$WT" && bash "$SPRINTX_BLOQUEIOS" "$@" ) 2>/dev/null; }

TASKS_REL="docs/sprintx/features/$SLUG/sprint-01/tasks.md"
ENT_REL="docs/entregas/$SLUG/ENTREGA.md"

PLANO=""
plano_define() { # <id> <campo 2..6> <valor>
  PLANO="$(printf '%s\n' "$PLANO" | awk -F'|' -v OFS='|' -v id="$1" -v c="$2" -v v="$3" '$1 == id { $c = v } { print }')"
}
plano_texto() {
  printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: tasks\ntrabalho_id: %s\nsprint_id: sprint-01\natualizado_em: %s\ntasks:\n' "$SLUG" "$HOJE"
  printf '%s\n' "$PLANO" | awk -F'|' 'NF {
    printf "  - id: %s\n    titulo: %s\n    status: %s\n    suite: %s\n", $1, $6, $2, $3
    printf "    teste_integracao: a suite do projeto roda os testes da task %s\n", $1
    printf "    teste_funcional: os testes de %s passam com o produto real\n", $1
    printf "    arquivos:\n      cria: [%s]\n      altera: [%s]\n", $4, $5 }'
  printf -- '---\n\n# Sprint 01\n'
  printf '%s\n' "$PLANO" | awk -F'|' 'NF { printf "\n```yaml\nid: %s\nstatus: %s\n```\n", $1, $2 }'
}
grava_plano() { escreve_ok "$1" "$TASKS_REL" "$(plano_texto)"$'\n'; }
status_de() { status_task "$WT/$TASKS_REL" "$1"; }

fm_set() { # <arquivo> <chave> <valor>
  awk -v k="$2" -v v="$3" 'NR == 1 { print; fm = 1; next } fm && /^---/ { fm = 0 }
    fm && index($0, k ":") == 1 { print k ": " v; next } { print }' "$1" > "$1.tmp" && mv -f "$1.tmp" "$1"
}
fm_get() { tr -d '\r' < "$1" | awk -v k="$2: " 'NR > 1 && /^---/ { exit } index($0, k) == 1 { print substr($0, length(k) + 1); exit }'; }
mensagem_e1() { # <task> -> caminho do arquivo da mensagem
  local m="$TMP_RAIZ/msg-$1.txt"
  printf 'feat(%s): fecha %s\n\nFechamento da task pelo E1 da mergex.\n\nTask: %s\nTrabalho: %s\n' "$SLUG" "$1" "$1" "$SLUG" > "$m"
  printf '%s\n' "$m"
}

e1() { # e1 <task> [--verificacao <cmd>] -- <caminho>...
  local task="$1" ini; shift
  ini="$EPOCHREALTIME"
  E1_SAIDA="$(cd "$WT" && bash "$MX/fechamento-do-e1.sh" --fechar --entrega "$ENT_REL" --task "$task" \
    --mensagem "$(mensagem_e1 "$task")" "$@" 2>&1)"; E1_RC=$?
  anota_tempo "E1 fechamento-do-e1" "$(ms_desde "$ini")"
}

metodo() { # <persistir|verificar> <checkpoint>
  local ini="$EPOCHREALTIME"
  METODO_SAIDA="$(cd "$WT" && bash "$MX/persistir-metodo.sh" "--$1" --entrega "$ENT_REL" \
    --origem sprintx --trabalho "$SLUG" --checkpoint "$2" 2>&1)"; METODO_RC=$?
  anota_tempo "persistir-metodo $1 $2" "$(ms_desde "$ini")"
}

catalogo() { # <checkpoint> — o catálogo de método INSTALADO, carregado como a mergex o carrega
  ( cd "$WT" && bash -c '. "$1"; catalogo_metodo "$2" sprintx "$3" "docs/sprintx/features/$3" "$4"' \
      _ "$MX/catalogo-de-metodo.sh" "$WT" "$SLUG" "$1" ) | tr -d '\r' | LC_ALL=C sort -u
}

itens() { ( cd "$WT" && bash "$MX/sequencia-de-commits.sh" --ler "$ENT_REL" ) 2>/dev/null | tr -d '\r'; }
seqs() { itens | cut -f2 | paste -sd' ' -; }
v11() { ( cd "$WT" && bash "$MX/prova-de-commit.sh" --verificar "$ENT_REL" "$TASKS_REL" ) 2>/dev/null | tr -d '\r' | head -1; }
v11_linhas() { ( cd "$WT" && bash "$MX/prova-de-commit.sh" --verificar "$ENT_REL" "$TASKS_REL" ) 2>/dev/null | tr -d '\r' | sed 1d | cut -f1 | paste -sd' ' -; }
v11_head() {
  local d="$TMP_RAIZ/v11-head"; rm -rf "$d"; mkdir -p "$d"
  git -C "$WT" show "HEAD:$ENT_REL" > "$d/ENTREGA.md" 2>/dev/null || { echo ausente; return; }
  git -C "$WT" show "HEAD:$TASKS_REL" > "$d/tasks.md" 2>/dev/null || { echo ausente; return; }
  ( cd "$WT" && bash "$MX/prova-de-commit.sh" --verificar "$d/ENTREGA.md" "$d/tasks.md" ) 2>/dev/null | tr -d '\r' | head -1
}
commits_de() { git -C "$WT" rev-list --count HEAD; }
paths_do() { git -C "$WT" -c core.quotepath=false diff-tree --root --no-commit-id -r --name-only "$1" | LC_ALL=C sort | paste -sd' ' -; }
trailers_do() { git -C "$WT" log -1 --format=%B "$1" | git interpret-trailers --parse | tr -d '\r' | cut -d: -f1 | LC_ALL=C sort | paste -sd' ' -; }
blob() { git -C "$WT" hash-object --no-filters -- "$1"; }
sujos() { git -C "$WT" -c core.quotepath=false status --porcelain --untracked-files=all | tr -d '\r'; }

# O parcial seguro, lido do 00-PLANEJAMENTO.md COMMITADO: path|task|estado|hash.
parciais_commitados() {
  git -C "$WT" show "HEAD:docs/sprintx/features/$SLUG/00-PLANEJAMENTO.md" 2>/dev/null | tr -d '\r' | awk '
    /^parciais_replanejamento_f6:/ { d = 1; next }
    d && /^[^ ]/ { d = 0 }
    d && /^  - path:/ { p = $0; sub(/^  - path:[ ]*/, "", p); gsub(/"/, "", p) }
    d && /^    task:/ { t = $2 } d && /^    estado:/ { e = $2 }
    d && /^    hash:/ { print p "|" t "|" e "|" $2 }'
}

# ---------------------------------------------------------------------------
# E2 — o portão de prontidão, composto dos scripts reais da mergex INSTALADA
# ---------------------------------------------------------------------------
tasks_tsv_e2() {
  tr -d '\r' < "$WT/$TASKS_REL" | awk '
    NR == 1 { next } /^---/ { exit }
    /^  - id:/ { if (id != "") print id "\t" st "\t" su "\t" ti "\t" tf; id = $3; st = su = ""; ti = tf = 0; next }
    /^    status:/ { st = $2 } /^    suite:/ { su = $2 }
    /^    teste_integracao:/ { v = $0; sub(/^[^:]*:[ ]*/, "", v); ti = (v != "" && v != "null" && v !~ /\{\{|TODO/) }
    /^    teste_funcional:/  { v = $0; sub(/^[^:]*:[ ]*/, "", v); tf = (v != "" && v != "null" && v !~ /\{\{|TODO/) }
    END { if (id != "") print id "\t" st "\t" su "\t" ti "\t" tf }'
}

v9_produto() {
  git -C "$WT" -c core.quotepath=false diff --name-only "$PROJ...HEAD" | while IFS= read -r p; do
    case "$p" in
      "docs/sprintx/features/$SLUG/"*|"docs/entregas/$SLUG/"*) ;;
      docs/sprintx/estimativas/HISTORICO.md) ;;                                          # [P11]
      *) printf '%s\n' "$p" ;;
    esac
  done
}

e2() { # e2 <gravar|consultar> -> E2_RESULTADO, E2_FALHAS, E2_TABELA
  local modo="$1" t v1=OK v2=OK v3=OK v6=OK v7=OK v9=OK v10=OK v11=OK falhas="" linha ini
  E2_RESULTADO=""; E2_FALHAS=""; E2_TABELA=""
  ini="$EPOCHREALTIME"
  metodo verificar pre-e2
  if [ "$METODO_RC" != 0 ]; then E2_RESULTADO=nao_iniciou; E2_TABELA="$METODO_SAIDA"; return 0; fi
  t="$(tasks_tsv_e2)"
  printf '%s\n' "$t" | awk -F'\t' '$2 != "concluida"' | grep -q . && v1=FALHA
  printf '%s\n' "$t" | awk -F'\t' '$2 == "concluida" && $3 != "verde" && $3 != "parcial"' | grep -q . && v2=FALHA
  printf '%s\n' "$t" | awk -F'\t' '$4 != 1 || $5 != 1' | grep -q . && v3=FALHA
  if ! sx valida-auditoria "$SLUG" >/dev/null ||
     ! tr -d '\r' < "$WT/docs/sprintx/features/$SLUG/00-AUDITORIA.md" | grep -E '^VEREDITO: ' | tail -1 | grep -q '^VEREDITO: SIM'; then v6=FALHA; fi
  blq listar "$SLUG" | tr -d '\r' | awk -F'\t' '$4 == "aberto"' | grep -q . && v7=FALHA
  linha="$(v9_produto)"
  if [ -n "$linha" ]; then
    linha="$( cd "$WT" && printf '%s\n' "$linha" | bash "$MX/ownership-da-task.sh" --classificar . sprintx "$SLUG" T-01.01 2>/dev/null )"
    case "$linha" in "") v9=SEM_PROVA ;; esac
    printf '%s\n' "$linha" | awk -F'\t' '$1 == "desvio"' | grep -q . && v9=FALHA
  fi
  jq -cn --arg cwd "$WT" --arg c "$(git -C "$WT" diff "$PROJ...HEAD")" \
    '{cwd:$cwd, tool_name:"Write", tool_input:{file_path:"e2-v10.diff", content:$c}}' |
    ( cd "$WT" && PATH="$RUNNER_PATH" bash .claude/hooks/comum/sem-segredo.sh ) >/dev/null 2>&1 || v10=FALHA
  case "$(v11)" in                                                                       # [P8]
    V11=OK) ;; V11=FALHA) v11=FALHA ;; *) v11=SEM_PROVA ;;
  esac
  for linha in "V1 $v1" "V2 $v2" "V3 $v3" "V4 n/a" "V5 n/a" "V6 $v6" "V7 $v7" "V8 n/a" "V9 $v9" "V10 $v10" "V11 $v11"; do
    E2_TABELA="$E2_TABELA| ${linha% *} | ${linha#* } |
"
    case "${linha#* }" in
      FALHA) falhas="$falhas $(printf '%s' "${linha% *}" | tr 'V' 'v')" ;;
      SEM_PROVA) falhas="$falhas $(printf '%s' "${linha% *}" | tr 'V' 'v')_sem_prova" ;;
    esac
  done
  if [ -z "$falhas" ]; then E2_RESULTADO=PRONTO; E2_FALHAS="[]"
  else E2_RESULTADO=BLOQUEADO; E2_FALHAS="$(bash "$MERGEX_CAUSA" --lista $falhas | tr -d '\r')"
  fi
  anota_tempo "E2 portao" "$(ms_desde "$ini")"
  if [ "$modo" = gravar ]; then
    if [ "$E2_RESULTADO" = PRONTO ]; then fm_set "$WT/$ENT_REL" portao pronto; else fm_set "$WT/$ENT_REL" portao bloqueado; fi
    fm_set "$WT/$ENT_REL" falhas_portao "$E2_FALHAS"
    fm_set "$WT/$ENT_REL" atualizado_em "$HOJE"
  fi
}

# O E0: o ENTREGA.md no formato do TEMPLATE instalado da mergex, campo a campo.
entrega_nova() { # <arquivo> <slug> <branch> <branch_base>
  mkdir -p "$(dirname "$1")"
  printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: entrega\ntrabalho_id: %s\nentregue_por: mergex\ntitulo: Trabalho %s\ntipo_trabalho: feature\ntipo_ocorrencia: null\nestado: aberto\nversionado: true\nbranch: %s\nbranch_base: %s\ncommits: []\nmodulo_afetado: []\narquivos_alterados: []\nfaixa_atencao: []\nraio: null\natencao:\n  olho_obrigatorio: 0\n  leitura_rapida: 0\n  dispensavel: 0\nportao: null\nfalhas_portao: []\ncausa: null\ndesvios: []\npush_feito: false\npr_url: null\npr_estado: null\ncriado_em: %s\natualizado_em: %s\nentregue_em: null\n---\n\n# Entrega\n\nRegistro da entrega de %s.\n' \
    "$2" "$2" "$3" "$4" "$HOJE" "$HOJE" "$2" > "$1"
}
chaves_fm() { # <arquivo> — as chaves de topo do frontmatter que começa em expx_schema
  tr -d '\r' < "$1" | awk '/^---$/ { if (d) exit; getline l; if (l ~ /^expx_schema:/) { d = 1; print "expx_schema" }; next }
    d && /^[a-z_]+:/ { sub(/:.*/, ""); print }' | LC_ALL=C sort | paste -sd' ' -
}

# ---------------------------------------------------------------------------
# P0 — o projeto: o controle do buildx nasce sem skill nenhuma; o ExpxDev instala
# ---------------------------------------------------------------------------
passo "I instalacao real pelo ExpxDev do pin (sprintx, mergex)"
C="$(novo_projeto "$PROJ_NOME" sim)"; cd "$C" || quebra
git config core.autocrlf false
ck I.0 "o produto nasce sem .claude e sem .expx" "nao nao" "$(sn test -e .claude) $(sn test -e .expx)"
instala "$C" sprintx,mergex                                                  # [Y1]
ck I.00 "expxdev init: rc 0, as duas instaladas, plugin NAO registrado no ~/.claude" "0 sim sim" \
  "$INIT_RC $(sn eval 'printf "%s" "$INIT_SAIDA" | grep -q "instaladas: mergex, sprintx"') $(sn eval 'printf "%s" "$INIT_SAIDA" | grep -q "nao foi encontrado no PATH"')"
:                                                                            # [Y2]
prova_instalacao "$C" I
printf '%s\n' "$DOCTOR" | sed 's/^/          doctor: /'

TEMPLATE_IGNORE="$REPO/.claude/skills/buildx/template/.gitignore"
tr -d '\r' < "$TEMPLATE_IGNORE" | grep -xE 'docs/eventos/|\.expx/estado\.json|\.expx/memoria/' > .gitignore
ck P0.10 "o projeto ignora os tres derivados locais, pelo template do buildx" 3 "$(grep -c . .gitignore)"
git add -A && git commit -q -m "chore(buildx): instala sprintx e mergex pelo expxdev" || quebra
INSTALACAO="$(git rev-parse HEAD)"
ck P0.11 "escopo-da-task instalado em modo aviso (o geral)" aviso "$(tr -d '\r' < .expx/hooks.json | jq -r '.hooks["escopo-da-task"].modo')"
PLANEJAMENTO="$C/.claude/skills/sprintx/scripts/planejamento.sh"
SPRINTX_BLOQUEIOS="$C/.claude/skills/sprintx/scripts/bloqueios.sh"
MX="$C/.claude/skills/mergex/scripts"
MERGEX_CAUSA="$MX/causa-do-portao.sh"
printf 'Testes: `*.test.sh` em test/, um por modulo de src/.\n' >> docs/stack/CONVENCOES.md

mkdir -p src test
printf '#!/usr/bin/env bash\nfor t in test/*.test.sh; do bash "$t" || { echo "FALHOU $t"; exit 1; }; done\necho "suite verde"\n' > test/suite.sh
printf 'x() { echo x0; }\n' > src/x.sh
printf '. src/x.sh\ntest "$(x)" = x0\n' > test/x.test.sh
git add -A && git commit -q -m "chore(buildx): fundacao do projeto c7b" || quebra

historica_plano() { # <slug> <status> — T-01.01 que declara src/x.sh
  mkdir -p "docs/sprintx/features/$1/sprint-01"
  printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: tasks\ntrabalho_id: %s\nsprint_id: sprint-01\natualizado_em: %s\ntasks:\n  - id: T-01.01\n    titulo: X da feature %s\n    status: %s\n    suite: verde\n    teste_integracao: a suite roda x\n    teste_funcional: x devolve o valor novo\n    arquivos:\n      cria: []\n      altera: [src/x.sh, test/x.test.sh]\n---\n\n# Sprint 01\n\n```yaml\nid: T-01.01\nstatus: %s\n```\n' \
    "$1" "$HOJE" "$1" "$2" "$2" > "docs/sprintx/features/$1/sprint-01/tasks.md"
  printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: orquestrador\ntrabalho_id: %s\n---\n\n# Orquestrador\n' "$1" > "docs/sprintx/features/$1/ORQUESTRADOR.md"
}
historica_plano feature-antiga concluida
printf 'x() { echo x1; }\n' > src/x.sh
printf '. src/x.sh\ntest "$(x)" = x1\n' > test/x.test.sh
git add src/x.sh test/x.test.sh
git commit -q -F - <<'EOF' || quebra
feat(feature-antiga): x devolve x1

Task: T-01.01
Trabalho: feature-antiga
EOF
ANTIGA_E1="$(git rev-parse --short HEAD)"
ENT_ANTIGA=docs/entregas/feature-antiga/ENTREGA.md
entrega_nova "$ENT_ANTIGA" feature-antiga feature/feature-antiga "$PROJ"
ck P0.9 "o E0 segue o template instalado da mergex, chave a chave" \
  "$(chaves_fm "$C/.claude/skills/mergex/assets/TEMPLATE-ENTREGA.md")" "$(chaves_fm "$ENT_ANTIGA")"
bash "$MX/sequencia-de-commits.sh" --acrescentar "$ENT_ANTIGA" T-01.01 "$ANTIGA_E1" >/dev/null || quebra
fm_set "$ENT_ANTIGA" estado entregue; fm_set "$ENT_ANTIGA" portao pronto; fm_set "$ENT_ANTIGA" entregue_em "$HOJE"
mkdir -p docs/sprintx/estimativas
printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: estimativa_historico\ntrabalho_id: null\natualizado_em: %s\nunidade: h\nentradas:\n  - trabalho_id: feature-antiga\n    task_id: T-01.01\n    real: 1\n    registrado_em: %s\ncalibracao: []\n---\n\n# Historico de esforco\n\n| Trabalho | Task | Real |\n|---|---|---|\n| feature-antiga | T-01.01 | 1 |\n' \
  "$HOJE" "$HOJE" > docs/sprintx/estimativas/HISTORICO.md
git add -A && git commit -q -F - <<'EOF' || quebra
chore(mergex): persiste metodo e8

Trabalho: feature-antiga
Metodo: e8
EOF
ck P0.12 "a historica tem evidencia valida: o E1 dela passa no contrato" classe=e1 \
  "$(bash "$MX/contrato-de-commit.sh" --validar-e1 --trabalho feature-antiga --task T-01.01 --commit "$ANTIGA_E1" | tr -d '\r')"
ck P0.13 "a historica tem evidencia valida: V11 OK" V11=OK \
  "$(bash "$MX/prova-de-commit.sh" --verificar "$ENT_ANTIGA" docs/sprintx/features/feature-antiga/sprint-01/tasks.md | tr -d '\r' | head -1)"

mapa_feature docs/projeto/MAPA.md FT-01 feature-antiga entregue descricao
mapa_feature docs/projeto/MAPA.md FT-02 "$SLUG" em_andamento descricao
mapa_feature docs/projeto/MAPA.md FT-03 feature-seguinte pendente descricao
mapa_define docs/projeto/MAPA.md FT-02 'Depende de' FT-01
mapa_define docs/projeto/MAPA.md FT-03 'Depende de' FT-02
git add -A && git commit -q -m "chore(buildx): FT-02 em andamento" && git push -q origin "$PROJ" || quebra
BASE="$(git rev-parse HEAD)"
ck P0.14 "o lock e o settings da instalacao sao versionados" "sim sim" \
  "$(sn git ls-files --error-unmatch .expx/expx-lock.json) $(sn git ls-files --error-unmatch .claude/settings.json)"

# ---------------------------------------------------------------------------
# F1–F5 da feature corrente, pela sprintx INSTALADA na worktree
# ---------------------------------------------------------------------------
passo "F1-F5 da feature corrente pela sprintx instalada"
feature_nasce "$SLUG" "$BASE" "$PROJ_NOME" || quebra
WT="$TMP_RAIZ/$PROJ_NOME/wt-$SLUG"
PLANEJAMENTO="$WT/.claude/skills/sprintx/scripts/planejamento.sh"
SPRINTX_BLOQUEIOS="$WT/.claude/skills/sprintx/scripts/bloqueios.sh"
MX="$WT/.claude/skills/mergex/scripts"
MERGEX_CAUSA="$MX/causa-do-portao.sh"
ck F1.0 "a worktree tem a instalacao versionada, byte a byte" "" "$(git -C "$WT" diff --name-only "$INSTALACAO" -- .claude .expx)"
PASTA="$WT/docs/sprintx/features/$SLUG"
mkdir -p "$PASTA/base"
printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: base_indice\ntrabalho_id: %s\n---\n\n# Base\n' "$SLUG" > "$PASTA/base/00-INDICE.md"
ck F1.1 "a F1 cria o planejamento com o teto do buildx: 3 buildx 1" planejamento=criado \
  "$(sx criar "$SLUG" "$ORCAMENTO_F5_MAX" "$ORCAMENTO_F5_POR" "$ORCAMENTO_F6_MAX" | tr -d '\r' | head -1)"
printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: decisoes\ntrabalho_id: %s\ndecisoes: []\n---\n\n# Decisoes\n' "$SLUG" > "$PASTA/00-DECISOES.md"
sx avanca "$SLUG" f2 >/dev/null || quebra
ck F1.2 "o orcamento commitado confere com o briefing" sim "$(sn orcamento_confere "$SLUG")"
PLANO="T-01.02|pendente|nao_executada||src/x.sh, test/x.test.sh|X devolve x2
T-01.01|pendente|nao_executada|src/atual.sh, test/atual.test.sh||Atual usa o modo novo de X
T-01.03|pendente|nao_executada|src/c.sh, test/c.test.sh||Modulo c
T-01.04|pendente|nao_executada|src/d.sh, test/d.test.sh||Modulo d"
mkdir -p "$PASTA/sprint-01"; plano_texto > "$WT/$TASKS_REL"
sx avanca "$SLUG" f3 >/dev/null || quebra
printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: orquestrador\ntrabalho_id: %s\n---\n\n# Orquestrador\n\nOrdem: T-01.02, T-01.01, T-01.03, T-01.04.\n' "$SLUG" > "$PASTA/ORQUESTRADOR.md"
sx avanca "$SLUG" f4 >/dev/null || quebra
auditoria "$PASTA/00-AUDITORIA.md" sim
ck F1.3 "a F5 aprova: F6" aprovado "$(chave "$(sx avanca "$SLUG" f5)" estado)"
ck F1.4 "o buildx le a sprintx: f6" f6 "$(buildx_acao "$WT" "$SLUG")"
ck F1.5 "ate a F6, a branch so tem checkpoints na pasta da feature" sim "$(sn sem_produto_pre_f6 "$BASE" "$SLUG")"
entrega_nova "$WT/$ENT_REL" "$SLUG" "feature/$SLUG" "$PROJ"                 # E0

task_executa() { # <uuid> <task> — reivindica pelo rastro e marca em_andamento
  plano_define "$2" 2 em_andamento; grava_plano "$1"
  evento_skill "$SLUG" task_iniciada "$2" "$1"
}
task_conclui() { # <uuid> <task> — só depois da suíte verde
  plano_define "$2" 2 concluida; plano_define "$2" 3 verde; grava_plano "$1"
  evento_skill "$SLUG" task_concluida "$2" "$1"
}
# T-01.02 — a irmã dona de X — executa e fecha primeiro, noutra sessão.
task_executa "$S0" T-01.02
escreve_ok "$S0" test/x.test.sh "$(printf '. src/x.sh\ntest "$(x)" = x2\n')"$'\n'
suite "$S0"; ck F6.1 "TDD: a suite fica vermelha antes do produto" 1 "$SUITE_RC"
escreve_ok "$S0" src/x.sh 'x() { echo x2; }'$'\n'
suite "$S0"; ck F6.2 "a suite fica verde" 0 "$SUITE_RC"
task_conclui "$S0" T-01.02
e1 T-01.02 -- src/x.sh test/x.test.sh
ck F6.3 "o E1 da T-01.02 fecha com seq 1" "0 1" "$E1_RC $(printf '%s\n' "$E1_SAIDA" | sed -n 's/^seq=//p')"
E1_0102="$(git -C "$WT" rev-parse HEAD)"; ITEM_0102="$(itens | head -1)"

# ---------------------------------------------------------------------------
# J — jq visível NO PROCESSO que executa os hooks (não no shell interativo)
# ---------------------------------------------------------------------------
passo "J jq no processo dos hooks, pelo runner ($C7B_RUNNER)"
# O mergex/git-perigoso instalado barra qualquer comando git quando não acha jq
# (DM-171). Então: com o PATH do runner o git passa, e sem a pasta do jq, o MESMO
# hook, pelo MESMO runner, barra dizendo jq — o jq que o hook usou é o do processo.
# >>> runner-real
runner_bash "$WT" "$S1" "$RUNNER_PATH" "git status --short"
# <<< runner-real
ck J.1 "com o PATH do runner, o git passa pelos hooks de Bash" "sim 0" "$RUN_TENTOU $RUN_RC"
[ "$C7B_RUNNER" != claude ] || ck J.1s "a sessao do runner real e a S1" "$S1" "$RUN_SID"
# >>> runner-real
runner_bash "$WT" "$S1" "$RUNNER_PATH_SEM_JQ" "git status --short"
# <<< runner-real
ck J.2 "sem jq no processo, o mesmo comando e barrado pelo hook" "sim 2" "$RUN_TENTOU $RUN_RC"
ck J.3 "e quem barra e o mergex/git-perigoso, pela dependencia jq" sim \
  "$(sn eval 'printf "%s" "$RUN_SAIDA" | grep -q "mergex/git-perigoso — dependência ausente: jq"')"

# ---------------------------------------------------------------------------
# PASSO 1 — TDD-first: o teste, o vermelho, e o bloqueio real de X
# ---------------------------------------------------------------------------
passo "PASSO 1 o runner escreve o teste, a suite fica vermelha, X da irma e barrado"
ORDEM=""
task_executa "$S1" T-01.01
ck P1.1 "o rastro resolve a sessao do runner a trabalho+task: feature-atual T-01.01" "$SLUG T-01.01 ok" "$(reivindicacoes "$S1")"
ALT_X0="$(grep -c '"evento":"arquivo_alterado".*"arquivos":\["src/x.sh"\]' "$WT/docs/eventos/$SLUG.jsonl")"
TESTE_ATUAL="$(printf '. src/x.sh\n. src/atual.sh\ntest "$(atual)" = "novo x2"\n')"$'\n'
# >>> runner-real
:                                                                            # [Y6]
runner_write "$WT" "$S1" test/atual.test.sh "$TESTE_ATUAL"
# <<< runner-real
ck P1.2 "o runner escreve o teste da propria task: permitido" "sim 0" "$RUN_TENTOU $RUN_RC"
ck P1.3 "o teste e exatamente o pedido" sim "$(sn test "$(cat "$WT/test/atual.test.sh" 2>/dev/null; printf x)" = "${TESTE_ATUAL}x")"
ck P1.4 "o PostToolUse do runner gravou o arquivo_alterado do teste no rastro da corrente" 1 \
  "$(grep -c '"evento":"arquivo_alterado".*"arquivos":\["test/atual.test.sh"\]' "$WT/docs/eventos/$SLUG.jsonl")"
ORDEM="$ORDEM TESTE"
suite "$S1"; ck P1.5 "a suite fica vermelha: o teste existe, o produto nao" 1 "$SUITE_RC"
ORDEM="$ORDEM RED"

X_ANTES="$(blob "$WT/src/x.sh")"
# a histórica fica sempre a mais recente no disco: mtime não pode decidir nada
touch -t 209901010000 "$WT/docs/sprintx/features/feature-antiga" "$WT/docs/sprintx/features/feature-antiga/sprint-01/tasks.md"
X_ANTIGO='echo x2; }'; X_NOVO='echo x2; }; x_modo() { echo novo; }'
# >>> runner-real
runner_edit "$WT" "$S1" src/x.sh "$X_ANTIGO" "$X_NOVO"
# <<< runner-real
ck P1.6 "o runner tenta editar X" sim "$RUN_TENTOU"
ck P1.7 "o PreToolUse barra: a ferramenta nao executa" 2 "$RUN_RC"
ck P1.8 "quem barra e o escopo-da-task instalado, por arquivo_de_task_irma, declarado so pela T-01.02" "sim sim" \
  "$(sn eval 'printf "%s" "$RUN_SAIDA" | grep -q "escopo-da-task"') $(sn eval 'printf "%s" "$RUN_SAIDA" | grep -q "arquivo_de_task_irma — o arquivo src/x.sh esta declarado so em task(s) irma(s) (T-01.02)"')"
ck P1.9 "os bytes de X estao intactos" "$X_ANTES" "$(blob "$WT/src/x.sh")"
ck P1.10 "nenhum arquivo_alterado de X no rastro" "$ALT_X0" \
  "$(grep -c '"evento":"arquivo_alterado".*"arquivos":\["src/x.sh"\]' "$WT/docs/eventos/$SLUG.jsonl")"
ck P1.11 "o bloqueio entrou no rastro da corrente, com a condicao" sim \
  "$(sn grep -q '"evento":"acao_bloqueada".*"condicao":"arquivo_de_task_irma","task_atual":"T-01.01"' "$WT/docs/eventos/$SLUG.jsonl")"
ck P1.12 "e nao no rastro da historica" nao "$(sn grep -q arquivo_de_task_irma "$WT/docs/eventos/feature-antiga.jsonl")"
ck P1.13 "a arvore de produto: so o teste, nada de X" "?? test/atual.test.sh" "$(sujos | grep -E ' (src|test)/' | paste -sd'|' -)"
ORDEM="$ORDEM BLOQUEIO"
irma_msg() { printf '%s' "$1" | grep -o 'arquivo_de_task_irma — o arquivo [^ ]* esta declarado so em task(s) irma(s) ([^)]*)' | head -1; }
RESP_ESCOPO_X="2|$(irma_msg "$RUN_SAIDA")"

# A mesma pergunta pelo despacho do settings, sem gravar: o arquivo próprio passa.
despacha "$WT" "$S1" PreToolUse Write "$(payload_escrita "$WT" src/atual.sh ':')"
RESP_ESCOPO_PROPRIO="$DESP_RC|$DESP_SAIDA"
ck P1.14 "o arquivo da propria task continua permitido" "0|" "$RESP_ESCOPO_PROPRIO"

# A mergex, pela outra ponta: o E1 da T-01.01 com X também para, antes do add.
own() { ( cd "$WT" && printf 'src/x.sh\n' | bash "$MX/ownership-da-task.sh" --classificar . sprintx "$SLUG" T-01.01 ) 2>/dev/null | tr -d '\r' | awk -F'\t' '$2 == "src/x.sh"' | tr '\t' ' '; }
RESP_OWN="$(own)"
ck P1.15 "ownership M1: X e da irma T-01.02, nunca da T-01.01 historica" "arquivo_de_task_irma src/x.sh T-01.02" "$RESP_OWN"
N0="$(commits_de)"; SQ0="$(seqs)"
e1 T-01.01 -- src/x.sh
ck P1.16 "o E1 da T-01.01 com X para em arquivo_de_task_irma (rc 8)" 8 "$E1_RC"
ck P1.17 "nenhum add, nenhum commit, nenhum seq" "|$N0|$SQ0" "$(git -C "$WT" diff --cached --name-only)|$(commits_de)|$(seqs)"
ck P1.18 "a trava do E1 foi liberada" nao "$(sn test -d "$( cd "$WT" && bash "$MX/trava-do-e1.sh" --caminho )")"

# Terceira histórica, no meio do caminho: as respostas da corrente não mudam.
TER="$WT/docs/sprintx/features/feature-terceira"
( cd "$WT" && historica_plano feature-terceira concluida )
touch -t 209901010000 "$TER" "$TER/sprint-01/tasks.md"
despacha "$WT" "$S1" PreToolUse Edit "$(jq -cn --arg cwd "$WT" --arg f "$WT/src/x.sh" '{cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f, old_string:"a", new_string:"b"}}')"
ck P1.19 "com a terceira historica: a mesma resposta do escopo para X" "$RESP_ESCOPO_X" \
  "$DESP_RC|$(irma_msg "$DESP_SAIDA")"
despacha "$WT" "$S1" PreToolUse Write "$(payload_escrita "$WT" src/atual.sh ':')"
ck P1.20 "com a terceira historica: a mesma resposta para o arquivo proprio" "$RESP_ESCOPO_PROPRIO" "$DESP_RC|$DESP_SAIDA"
ck P1.21 "com a terceira historica: o mesmo ownership" "$RESP_OWN" "$(own)"

# RASTRO: duas sessões em trabalhos distintos, no mesmo instante, não se cruzam.
evento_skill feature-terceira task_iniciada T-01.01 "$S2"
ck P1.22 "a sessao 2 resolve ao proprio trabalho" "feature-terceira T-01.01 ok" "$(reivindicacoes "$S2")"
ck P1.23 "a sessao do runner continua resolvendo a dela" "$SLUG T-01.01 ok" "$(reivindicacoes "$S1")"
despacha "$WT" "$S2" PreToolUse Write "$(payload_escrita "$WT" src/x.sh 'x() { :; }')"
ck P1.24 "o mesmo X, a mesma T-01.01: a sessao 2 (outro plano) nao e barrada" 0 "$DESP_RC"
despacha "$WT" "$S2" PostToolUse Write "$(payload_escrita "$WT" src/terceira.sh '')"
despacha "$WT" "$S1" PostToolUse Write "$(payload_escrita "$WT" src/rota-s1.sh '')"
ck P1.25 "o evento da sessao 2 foi para o rastro dela" sim \
  "$(sn grep -q '"evento":"arquivo_alterado".*"arquivos":\["src/terceira.sh"\]' "$WT/docs/eventos/feature-terceira.jsonl")"
ck P1.26 "o evento da sessao do runner foi para o rastro dela" sim \
  "$(sn grep -q '"evento":"arquivo_alterado".*"arquivos":\["src/rota-s1.sh"\]' "$WT/docs/eventos/$SLUG.jsonl")"
ck P1.27 "e nenhum cruzou" "nao nao" \
  "$(sn grep -q 'src/terceira.sh' "$WT/docs/eventos/$SLUG.jsonl") $(sn grep -q 'src/rota-s1.sh' "$WT/docs/eventos/feature-terceira.jsonl")"
evento_skill feature-terceira task_concluida T-01.01 "$S2"
rm -rf "$TER"

# ---------------------------------------------------------------------------
# PASSO 2 — B-NN, o buildx não pré-julga a árvore, e o parcial seguro
# ---------------------------------------------------------------------------
passo "PASSO 2 B-NN defeito_de_plano, replanejar-execucao preserva o teste"
ck P2.1 "bloqueios.sh registra o B-01 com a classe" "id=B-01 task=T-01.01 classe=defeito_de_plano" \
  "$(blq registrar "$SLUG" T-01.01 defeito_de_plano "a T-01.01 precisa alterar src/x.sh, declarado so na T-01.02" "o plano declarar src/x.sh na T-01.01" | tr -d '\r' | paste -sd' ' -)"
plano_define T-01.01 2 bloqueada; grava_plano "$S1"
evento_skill "$SLUG" task_bloqueada T-01.01 "$S1"
ck P2.2 "B-01 defeito_de_plano aberto, T-01.01 bloqueada" "B-01 T-01.01 defeito_de_plano aberto bloqueada" \
  "$(blq listar "$SLUG" | tr -d '\r' | tr '\t' ' ') $(status_de T-01.01)"
PARCIAL="$(blob "$WT/test/atual.test.sh")"
ck P2.3 "o teste legitimo esta sujo, fora do stage: o trabalho parcial da task bloqueada" "?? test/atual.test.sh|" \
  "$(sujos | grep -E ' (src|test)/' | paste -sd'|' -)|$(git -C "$WT" diff --cached --name-only)"
ck P2.4 "o buildx nao pre-julga a fronteira: manda o passo 3 da F6 (D-40)" F:replanejar_execucao \
  "$(cd "$C" && retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ")"
REFLOG0="$(git -C "$WT" reflog --format=%gs HEAD | wc -l | tr -d ' ')"
reflog_novo() { local n; n="$(git -C "$WT" reflog --format=%gs HEAD | wc -l | tr -d ' ')"; git -C "$WT" reflog --format=%gs HEAD | head -n "$((n - REFLOG0))"; }
SAIDA="$(sx replanejar-execucao "$SLUG"; printf 'codigo=%s\n' "$?")"
ck P2.5 "a rodada abre: iniciado, F3" "iniciado replanejar_execucao F3 0" \
  "$(chave "$SAIDA" replanejamento) $(chave "$SAIDA" estado) $(chave "$SAIDA" proxima) $(chave "$SAIDA" codigo)"
ck P2.6 "o teste escrito aparece em parciais_replanejamento_f6" test/atual.test.sh "$(chave "$SAIDA" parciais_replanejamento_f6)"
ck P2.7 "no checkpoint: path, task, estado e hash do parcial" "test/atual.test.sh|T-01.01|novo|$PARCIAL" "$(parciais_commitados)"
:                                                                            # [Y7]
ck P2.8 "o parcial continua na arvore, sujo, byte a byte" "?? test/atual.test.sh $PARCIAL" \
  "$(sujos | grep ' test/atual.test.sh$') $(blob "$WT/test/atual.test.sh" 2>/dev/null)"
ck P2.9 "nenhum stash, nenhum reset nem checkout: o reflog so ganhou o checkpoint" "0 1 commit" \
  "$(git -C "$WT" stash list | wc -l | tr -d ' ') $(reflog_novo | wc -l | tr -d ' ') $(reflog_novo | cut -d: -f1 | paste -sd' ' -)"
ck P2.10 "o checkpoint leva so a pasta da feature" "docs/sprintx/features/$SLUG" \
  "$(git -C "$WT" diff-tree --no-commit-id -r --name-only HEAD | sed 's#/[^/]*$##; s#/sprint-01$##' | LC_ALL=C sort -u | paste -sd' ' -)"
ck P2.11 "a abertura da rodada foi para o rastro da corrente, nao para o da historica" "sim nao" \
  "$(sn grep -q '"evento":"replanejamento_execucao_iniciado"' "$WT/docs/eventos/$SLUG.jsonl") $(sn grep -q replanejamento_execucao "$WT/docs/eventos/feature-antiga.jsonl")"
ck P2.12 "o orcamento da F6 e consumido: 1 de 1" "1 1" "$(chave "$SAIDA" replanejamentos_f6) $(chave "$SAIDA" max_replanejamentos_f6)"
ck P2.13 "a rodada: B-01, com a T-01.02 congelada" "B-01 T-01.02" \
  "$(chave "$SAIDA" bloqueios_replanejamento_f6) $(chave "$SAIDA" tasks_congeladas)"
ck P2.14 "num checkpoint da sprintx" "f6 replanejar_execucao" \
  "$(git -C "$WT" log -1 --format=%B | tr -d '\r' | awk -F': ' '/^Fase: / { f = $2 } /^Estado: / { e = $2 } END { print f, e }')"
ck P2.15 "nenhum trabalho concluido reaberto" "concluida $ITEM_0102" "$(status_de T-01.02) $(itens | head -1)"
ck P2.16 "o buildx le a rodada com o parcial sujo: S, na F3, sem PEND" S:continuar_f3 \
  "$(cd "$C" && retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ")"
ck P2.17 "a sprintx revalida o parcial: fase lista o parcial" test/atual.test.sh "$(chave "$(sx fase "$SLUG")" parciais_replanejamento_f6)"
# Falha fechada: o parcial muda um byte durante a rodada. A chave continua no
# checkpoint — e não basta: quem diz se ele ainda é o mesmo é a sprintx.
cp "$WT/test/atual.test.sh" "$TMP_RAIZ/parcial.guardado"
printf '# divergencia\n' >> "$WT/test/atual.test.sh"
SAIDA="$(sx fase "$SLUG"; printf 'codigo=%s\n' "$?")"
ck P2.18 "parcial divergente: a sprintx para (PARAR, parcial_divergente, 2)" "PARAR divergente parcial_divergente 2" \
  "$(chave "$SAIDA" fase) $(chave "$SAIDA" trabalho_parcial) $(chave "$SAIDA" motivo) $(chave "$SAIDA" codigo)"
ck P2.19 "a chave continua la, e o buildx para mesmo assim" "test/atual.test.sh PARE" \
  "$(parciais_commitados | cut -d'|' -f1) $(cd "$C" && retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ")"
cp "$TMP_RAIZ/parcial.guardado" "$WT/test/atual.test.sh"
ck P2.20 "os mesmos bytes de volta: a rodada segue (S), sem gravar nada" "$PARCIAL S:continuar_f3" \
  "$(blob "$WT/test/atual.test.sh") $(cd "$C" && retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ")"
ORDEM="$ORDEM REPLANEJAMENTO"

# ---------------------------------------------------------------------------
# PASSO 3 — o plano corrigido, pela F3/F4/F5 real
# ---------------------------------------------------------------------------
passo "PASSO 3 F3/F4/F5 do plano corrigido"
plano_define T-01.01 5 "src/x.sh"; grava_plano "$S1"                   # F3: a T-01.01 declara X
ck P3.1 "F3 da rodada: aguardando_f4" aguardando_f4 "$(chave "$(sx avanca "$SLUG" f3)" estado)"
printf '\nReplanejamento: a T-01.01 passa a alterar src/x.sh (B-01).\n' >> "$PASTA/ORQUESTRADOR.md"
ck P3.2 "F4: aguardando_f5" aguardando_f5 "$(chave "$(sx avanca "$SLUG" f4)" estado)"
auditoria "$PASTA/00-AUDITORIA.md" sim
SAIDA="$(sx avanca "$SLUG" f5; printf 'codigo=%s\n' "$?")"
ck P3.3 "F5 aprova o plano corrigido: F6" "aprovado F6 0" "$(chave "$SAIDA" estado) $(chave "$SAIDA" proxima) $(chave "$SAIDA" codigo)"
ck P3.4 "a rodada fecha, e a lista de parciais volta a vazia" " " \
  "$(chave "$(sx fase "$SLUG")" replanejamento_execucao) $(parciais_commitados)"
ck P3.5 "o B-01 foi resolvido pelo fechamento, sem mudar de classe" "B-01 T-01.01 defeito_de_plano resolvido" \
  "$(blq listar "$SLUG" | tr -d '\r' | tr '\t' ' ')"
ck P3.6 "a resolucao do B-01 foi para o rastro da corrente" sim \
  "$(sn grep -q '"evento":"bloqueio_resolvido".*"task":"T-01.01"' "$WT/docs/eventos/$SLUG.jsonl")"
ck P3.7 "a T-01.01 volta a executavel" pendente "$(status_de T-01.01)"
ck P3.8 "a T-01.02 concluida continua congelada" "concluida verde" \
  "$(status_de T-01.02) $(tr -d '\r' < "$WT/$TASKS_REL" | awk '/^  - id: T-01.02/ { d = 1 } d && /^    suite:/ { print $2; exit }')"
ck P3.9 "o parcial atravessou a rodada: mesmo hash, ainda sujo" "?? test/atual.test.sh $PARCIAL" \
  "$(sujos | grep ' test/atual.test.sh$') $(blob "$WT/test/atual.test.sh")"
ck P3.10 "a execucao volta a F6 normal, com o parcial sujo" F "$(cd "$C" && retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ")"
ck P3.11 "sem gastar de novo: 1 de 1, uma rodada aberta na branch" "1 1" \
  "$(chave "$(sx fase "$SLUG")" replanejamentos_f6) $(cd "$C" && rodadas_abertas "$SLUG")"
PLANO="$(printf '%s\n' "$PLANO" | sed 's/^T-01.01|bloqueada|/T-01.01|pendente|/')"
ck P3.12 "o plano no disco e o que a sprintx deixou" sim "$(sn eval 'diff <(plano_texto | sed "/^atualizado_em:/d") <(tr -d "\r" < "$WT/$TASKS_REL" | sed "/^atualizado_em:/d")')"

# ---------------------------------------------------------------------------
# PASSO 4 — agora X é da task, e a implementação vem depois do replanejamento
# ---------------------------------------------------------------------------
passo "PASSO 4 o runner edita X e implementa; verde"
task_executa "$S1" T-01.01
touch -t 209901010000 "$WT/docs/sprintx/features/feature-antiga" "$WT/docs/eventos/feature-antiga.jsonl" 2>/dev/null
# >>> runner-real
runner_edit "$WT" "$S1" src/x.sh "$X_ANTIGO" "$X_NOVO"
# <<< runner-real
ck P4.1 "o runner edita X: agora permitido" "sim 0" "$RUN_TENTOU $RUN_RC"
ck P4.2 "X mudou de verdade, para o pedido" 'x() { echo x2; }; x_modo() { echo novo; }' "$(cat "$WT/src/x.sh")"
ck P4.3 "o arquivo_alterado de X foi para o rastro da corrente, com a historica mais nova no disco" "$((ALT_X0 + 1))" \
  "$(grep -c '"evento":"arquivo_alterado".*"arquivos":\["src/x.sh"\]' "$WT/docs/eventos/$SLUG.jsonl")"
ck P4.4 "e nao para o rastro da historica" nao "$(sn grep -q '"arquivos":\["src/x.sh"\]' "$WT/docs/eventos/feature-antiga.jsonl")"
IMPL='atual() { echo "$(x_modo) $(x)"; }'$'\n'
# >>> runner-real
runner_write "$WT" "$S1" src/atual.sh "$IMPL"
# <<< runner-real
ck P4.5 "o runner escreve a implementacao" "sim 0 sim" "$RUN_TENTOU $RUN_RC $(sn test "$(cat "$WT/src/atual.sh"; printf x)" = "${IMPL}x")"
ORDEM="$ORDEM IMPLEMENTACAO"
suite "$S1"; ck P4.6 "a suite fica verde" "0 suite verde" "$SUITE_RC $(printf '%s\n' "$SUITE_SAIDA" | tail -1)"
ORDEM="$ORDEM GREEN"
ck P4.7 "o teste preservado continua igual ao parcial registrado" "$PARCIAL" "$(blob "$WT/test/atual.test.sh")"
task_conclui "$S1" T-01.01

passo "T a ordem foi TDD-first, pelo rastro"
RT="$WT/docs/eventos/$SLUG.jsonl"
linha_ev() { R="$1" awk -v d="${2:-0}" 'NR > d && $0 ~ ENVIRON["R"] { print NR; exit }' "$RT"; }
L_CLAIM="$(linha_ev "\"evento\":\"task_iniciada\".*\"task\":\"T-01.01\".*\"sessao\":\"claude-code@$S1\"")"
L_TESTE="$(linha_ev '"evento":"arquivo_alterado".*"arquivos":\["test/atual.test.sh"\]')"
L_BLOQ="$(linha_ev '"evento":"acao_bloqueada".*"condicao":"arquivo_de_task_irma","task_atual":"T-01.01"')"
L_INI="$(linha_ev '"evento":"replanejamento_execucao_iniciado"')"
L_APROV="$(linha_ev '"evento":"replanejamento_execucao_aprovado"')"
L_X="$(linha_ev '"evento":"arquivo_alterado".*"arquivos":\["src/x.sh"\]' "$L_CLAIM")"
L_IMPL="$(linha_ev '"evento":"arquivo_alterado".*"arquivos":\["src/atual.sh"\]')"
evidencia "rastro: reivindica $L_CLAIM, teste $L_TESTE, bloqueio $L_BLOQ, rodada $L_INI..$L_APROV, X $L_X, impl $L_IMPL"
ck T.1 "a ordem do fluxo" "TESTE RED BLOQUEIO REPLANEJAMENTO IMPLEMENTACAO GREEN" "${ORDEM# }"
ck T.2 "o rastro concorda: reivindica < teste < bloqueio < rodada aberta < rodada aprovada" sim \
  "$(sn test "${L_CLAIM:-0}" -gt 0 -a "${L_TESTE:-0}" -gt "${L_CLAIM:-0}" -a "${L_BLOQ:-0}" -gt "${L_TESTE:-0}" -a "${L_INI:-0}" -gt "${L_BLOQ:-0}" -a "${L_APROV:-0}" -gt "${L_INI:-0}")"
ck T.3 "nenhum produto antes do teste, nem implementacao antes da rodada aprovada" sim \
  "$(sn test "${L_X:-0}" -gt "${L_APROV:-0}" -a "${L_IMPL:-0}" -gt "${L_APROV:-0}")"

# ---------------------------------------------------------------------------
# PASSO 5 — o E1 real, instalado
# ---------------------------------------------------------------------------
passo "PASSO 5 o E1 da mergex instalada fecha a T-01.01"
CAT_E8="$(catalogo e8)"
PRODUTO="$(sujos | cut -c4- | grep -vxF -f <(printf '%s\n' "$CAT_E8") | LC_ALL=C sort | paste -sd' ' -)"
ck P5.1 "inventario da arvore inteira: o produto sujo e exatamente o da task" "src/atual.sh src/x.sh test/atual.test.sh" "$PRODUTO"
ck P5.2 "com o estado de cada um" "?? src/atual.sh| M src/x.sh|?? test/atual.test.sh" \
  "$(sujos | grep -E ' (src|test)/' | awk '{ print substr($0, 4) "\t" $0 }' | LC_ALL=C sort | cut -f2 | paste -sd'|' -)"
ck P5.3 "o resto e metodo legitimo: tudo no catalogo instalado" sim \
  "$(sn test -n "$(sujos | cut -c4- | grep -xF -f <(printf '%s\n' "$CAT_E8"))")"
ck P5.4 "ownership: os tres sao da task atual, nenhum da irma, nenhum desvio" "na_task_atual na_task_atual na_task_atual" \
  "$( cd "$WT" && printf '%s\n' src/atual.sh src/x.sh test/atual.test.sh | bash "$MX/ownership-da-task.sh" --classificar . sprintx "$SLUG" T-01.01 2>/dev/null | tr -d '\r' | cut -f1 | paste -sd' ' -)"
ck P5.5 "o stage esta vazio na entrada" "" "$(git -C "$WT" diff --cached --name-only)"
N0="$(commits_de)"; SQ0="$(seqs)"
e1 T-01.01 -- src/atual.sh src/x.sh
ck P5.6 "o E1 que omite o teste current para (rc 11): nao absorve produto fora da lista" 11 "$E1_RC"
ck P5.7 "nenhum add, nenhum commit, nenhum seq" "|$N0|$SQ0" "$(git -C "$WT" diff --cached --name-only)|$(commits_de)|$(seqs)"
e1 T-01.01 -- src/atual.sh src/x.sh test/atual.test.sh
ck P5.8 "a lista fechada completa: o E1 conclui com seq 2" "0 2" "$E1_RC $(printf '%s\n' "$E1_SAIDA" | sed -n 's/^seq=//p')"
E1_0101="$(git -C "$WT" rev-parse HEAD)"
ck P5.9 "exatamente um commit novo" "$((N0 + 1))" "$(commits_de)"
ck P5.10 "o commit leva exatamente o produto declarado, e nenhum metodo" "src/atual.sh src/x.sh test/atual.test.sh" "$(paths_do "$E1_0101")"
ck P5.11 "o teste commitado e o parcial registrado, byte a byte" "$PARCIAL" "$(git -C "$WT" rev-parse "$E1_0101:test/atual.test.sh")"
ck P5.12 "o metodo continua sujo, para o checkpoint" sim "$(sn eval 'sujos | grep -q " $TASKS_REL$"')"
ck P5.13 "trailers validos: Task + Trabalho, nenhum Metodo" classe=e1 \
  "$(cd "$WT" && bash "$MX/contrato-de-commit.sh" --validar-e1 --trabalho "$SLUG" --task T-01.01 --commit HEAD | tr -d '\r')"
ck P5.14 "o SHA registrado em ENTREGA.commits e o do commit" "$E1_0101" \
  "$(git -C "$WT" rev-parse "$(itens | awk -F'\t' '$2 == 2 { print $4 }')")"
ck P5.15 "seq continuo e valido" "1 2 commits=2" "$(seqs) $(cd "$WT" && bash "$MX/sequencia-de-commits.sh" --validar "$ENT_REL" | tr -d '\r')"
ck P5.16 "o commit da T-01.02 continua o seq 1" "$ITEM_0102" "$(itens | head -1)"

# ---------------------------------------------------------------------------
# PASSO 6 — concorrência do E1 na mesma worktree
# ---------------------------------------------------------------------------
passo "PASSO 6 dois E1 concorrentes na mesma worktree"
task_executa "$S1" T-01.03
escreve_ok "$S1" test/c.test.sh "$(printf '. src/c.sh\ntest "$(c)" = c\n')"$'\n'
escreve_ok "$S1" src/c.sh 'c() { echo c; }'$'\n'
suite "$S1"; ck P6.1 "a suite fica verde" 0 "$SUITE_RC"
task_conclui "$S1" T-01.03
TRAVA="$(cd "$WT" && bash "$MX/trava-do-e1.sh" --caminho)"
N0="$(commits_de)"
( cd "$WT" && bash "$MX/fechamento-do-e1.sh" --fechar --entrega "$ENT_REL" --task T-01.03 --mensagem "$(mensagem_e1 T-01.03)" \
    --verificacao 'sleep 3' -- src/c.sh test/c.test.sh > "$TMP_RAIZ/e1-a.out" 2>&1; printf '%s\n' "$?" > "$TMP_RAIZ/e1-a.rc" ) &
i=0; while [ ! -d "$TRAVA" ] && [ "$i" -lt 150 ]; do sleep 0.1; i=$((i + 1)); done
ck P6.2 "a primeira execucao tem a trava" sim "$(sn test -d "$TRAVA")"
e1 T-01.03 -- src/c.sh test/c.test.sh
E1_B_RC="$E1_RC"; E1_B_SAIDA="$E1_SAIDA"
wait
ck P6.3 "a segunda para em E1 OCUPADO (rc 2), sem tocar no indice" 2 "$E1_B_RC"
ck P6.4 "a mensagem nomeia a trava" sim "$(sn eval 'printf "%s" "$E1_B_SAIDA" | grep -q "OCUPADO"')"
ck P6.5 "a primeira conclui com seq 3" "0 3" "$(cat "$TMP_RAIZ/e1-a.rc") $(sed -n 's/^seq=//p' "$TMP_RAIZ/e1-a.out" | tr -d '\r')"
ck P6.6 "um commit so" "$((N0 + 1))" "$(commits_de)"
ck P6.7 "nenhum seq duplicado" "1 2 3" "$(seqs)"
ck P6.8 "nenhuma trava sobrou, stage vazio" "nao " "$(sn test -d "$TRAVA") $(git -C "$WT" diff --cached --name-only)"

# ---------------------------------------------------------------------------
# PASSO 7 — V11, e a recuperação
# ---------------------------------------------------------------------------
passo "PASSO 7 V11 e --registrar-existente"
ck P7.1 "V11 OK depois dos E1 corretos" V11=OK "$(v11)"
task_executa "$S1" T-01.04
escreve_ok "$S1" test/d.test.sh "$(printf '. src/d.sh\ntest "$(d)" = d\n')"$'\n'
escreve_ok "$S1" src/d.sh 'd() { echo d; }'$'\n'
suite "$S1"; ck P7.2 "a suite fica verde" 0 "$SUITE_RC"
task_conclui "$S1" T-01.04
PREP="$(cd "$WT" && bash "$MX/fechamento-do-e1.sh" --preparar --entrega "$ENT_REL" --task T-01.04 \
  --mensagem "$(mensagem_e1 T-01.04)" -- src/d.sh test/d.test.sh 2>&1)"
TOKEN="$(printf '%s\n' "$PREP" | tr -d '\r' | sed -n 's/^token=//p')"
ck P7.3 "o --preparar montou o stage sob a trava" "src/d.sh test/d.test.sh" "$(git -C "$WT" diff --cached --name-only | LC_ALL=C sort | paste -sd' ' -)"
git -C "$WT" commit -q -F "$(mensagem_e1 T-01.04)" || quebra
( cd "$WT" && bash "$MX/trava-do-e1.sh" --liberar "$TOKEN" ) >/dev/null 2>&1
E1_0104="$(git -C "$WT" rev-parse HEAD)"
ck P7.4 "o commit existe e o registro nao" "1 2 3" "$(seqs)"
ck P7.5 "V11 FALHA, nomeando a T-01.04" "V11=FALHA T-01.04" "$(v11) $(v11_linhas)"
metodo persistir pre-e2
ck P7.6 "pre-e2 persiste o metodo antes do E2" 0 "$METODO_RC"
ck P7.6b "esse pre-e2 leva o plano e a ENTREGA, nenhum produto" "docs/entregas/$SLUG/ENTREGA.md docs/sprintx/features/$SLUG/sprint-01/tasks.md" "$(paths_do HEAD)"
e2 consultar
ck P7.7 "o E2 barra so pela V11" "BLOQUEADO [v11]" "$E2_RESULTADO $E2_FALHAS"
N0="$(commits_de)"; H0="$(git -C "$WT" rev-parse HEAD)"
REC="$(cd "$WT" && bash "$MX/fechamento-do-e1.sh" --registrar-existente --entrega "$ENT_REL" --origem sprintx \
  --trabalho "$SLUG" --task T-01.04 --sha "$E1_0104" 2>&1)"; REC_RC=$?
ck P7.8 "--registrar-existente registra no proximo seq" "0 seq=4" "$REC_RC $(printf '%s\n' "$REC" | tr -d '\r' | grep '^seq=')"
ck P7.9 "sem commit novo de produto" "$N0 $H0" "$(commits_de) $(git -C "$WT" rev-parse HEAD)"
ck P7.10 "o item 4 aponta o commit existente" "$E1_0104" "$(git -C "$WT" rev-parse "$(itens | awk -F'\t' '$2 == 4 { print $4 }')")"
ck P7.11 "V11 OK na worktree" V11=OK "$(v11)"
ck P7.12 "no HEAD ainda falta a prova duravel" V11=FALHA "$(v11_head)"
REC2="$(cd "$WT" && bash "$MX/fechamento-do-e1.sh" --registrar-existente --entrega "$ENT_REL" --origem sprintx \
  --trabalho "$SLUG" --task T-01.04 --sha "$E1_0104" 2>&1)"
ck P7.13 "repetir a recuperacao e no-op" "noop=true 1 2 3 4" "$(printf '%s\n' "$REC2" | tr -d '\r' | head -1) $(seqs)"

# ---------------------------------------------------------------------------
# PASSO 8 — persistir-metodo pre-e2, pelo catálogo instalado
# ---------------------------------------------------------------------------
passo "PASSO 8 persistir-metodo pre-e2"
{ printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: fechamento\ntrabalho_id: %s\n---\n\n# Fechamento\n\nQuatro tasks concluidas; B-01 resolvido pela rodada de replanejamento 1/1.\n' "$SLUG"; } > "$PASTA/FECHAMENTO.md"
HIST="$WT/docs/sprintx/estimativas/HISTORICO.md"
awk -v s="$SLUG" -v h="$HOJE" 'NR > 1 && /^calibracao:/ && !f { for (i = 1; i <= 4; i++) printf "  - trabalho_id: %s\n    task_id: T-01.0%d\n    real: 1\n    registrado_em: %s\n", s, i, h; f = 1 } { print }' "$HIST" > "$HIST.tmp" && mv -f "$HIST.tmp" "$HIST"
for i in 1 2 3 4; do printf '| %s | T-01.0%s | 1 |\n' "$SLUG" "$i" >> "$HIST"; done
printf '\n# rascunho local que nenhuma task commitou\n' >> "$WT/src/c.sh"
SQ0="$(seqs)"; PROX0="$(cd "$WT" && bash "$MX/sequencia-de-commits.sh" --proximo "$ENT_REL" | tr -d '\r')"
ESPERADO_PRE_E2="$(sujos | cut -c4- | grep -xF -f <(catalogo pre-e2) | LC_ALL=C sort | paste -sd' ' -)"
METODO_RC=nao_rodou
metodo persistir pre-e2                                                                    # [P9]
ck P8.1 "pre-e2 commita" 0 "$METODO_RC"
PRE_E2="$(git -C "$WT" rev-parse HEAD)"
ck P8.2 "commit de metodo: Trabalho + Metodo, sem Task" "Metodo Trabalho" "$(trailers_do "$PRE_E2")"
ck P8.3 "o contrato de metodo o aceita" "classe=metodo checkpoint=pre-e2" \
  "$(cd "$WT" && bash "$MX/contrato-de-commit.sh" --validar-metodo --trabalho "$SLUG" --checkpoint pre-e2 --commit HEAD | tr -d '\r' | paste -sd' ' -)"
ck P8.4 "os artefatos previstos que estavam sujos entraram, e so eles" \
  "docs/entregas/$SLUG/ENTREGA.md docs/sprintx/estimativas/HISTORICO.md docs/sprintx/features/$SLUG/FECHAMENTO.md" \
  "$(paths_do "$PRE_E2")"
ck P8.4c "e sao exatamente o que o catalogo-de-metodo.sh INSTALADO lista entre os sujos" "$ESPERADO_PRE_E2" "$(paths_do "$PRE_E2")"
ck P8.5 "nenhum produto pegou carona" "" "$(paths_do "$PRE_E2" | tr ' ' '\n' | grep -vE "^docs/(sprintx/features/$SLUG/|entregas/$SLUG/|sprintx/estimativas/HISTORICO.md$)")"
ck P8.6 "o produto sujo continua sujo, fora do commit" " M src/c.sh" "$(git -C "$WT" status --porcelain -- src | tr -d '\r')"
git -C "$WT" checkout -q -- src/c.sh
ck P8.7 "o commit de metodo nao entra em ENTREGA.commits nem consome seq" "$SQ0 $PROX0" \
  "$(seqs) $(cd "$WT" && bash "$MX/sequencia-de-commits.sh" --proximo "$ENT_REL" | tr -d '\r')"
ck P8.8 "nenhum item aponta o commit de metodo" "" \
  "$(itens | cut -f4 | while read -r c; do [ "$(git -C "$WT" rev-parse "$c")" = "$PRE_E2" ] && echo "$c"; done)"
ck P8.9 "tasks, ORQUESTRADOR, planejamento, bloqueios, FECHAMENTO e HISTORICO versionados e limpos" "" \
  "$(git -C "$WT" status --porcelain -- "docs/sprintx/features/$SLUG" docs/sprintx/estimativas "docs/entregas/$SLUG")"
for a in sprint-01/tasks.md ORQUESTRADOR.md 00-PLANEJAMENTO.md 00-BLOQUEIOS.md FECHAMENTO.md; do
  ck P8.10 "no HEAD: $a" sim "$(sn git -C "$WT" cat-file -e "HEAD:docs/sprintx/features/$SLUG/$a")"
done
ck P8.11 "a barreira pre-e2 passa" "0 ok=true" "$(metodo verificar pre-e2; printf '%s %s' "$METODO_RC" "$METODO_SAIDA" | tr -d '\r')"
ck P8.12 "V11 OK tambem no HEAD, prova duravel" V11=OK "$(v11_head)"

# ---------------------------------------------------------------------------
# PASSO 9 — E2
# ---------------------------------------------------------------------------
passo "PASSO 9 E2 — V1..V11"
e2 gravar
printf '%s' "$E2_TABELA" | sed 's/^/          /'
ck P9.1 "RESULTADO: PRONTO, falhas_portao []" "PRONTO []" "$E2_RESULTADO $E2_FALHAS"
ck P9.2 "V1..V11: OK, e n/a so onde o contrato manda (V4, V5 runx; V8 legado)" \
  "| V1 | OK || V2 | OK || V3 | OK || V4 | n/a || V5 | n/a || V6 | OK || V7 | OK || V8 | n/a || V9 | OK || V10 | OK || V11 | OK |" \
  "$(printf '%s' "$E2_TABELA" | tr -d '\n')"
ck P9.3 "o portao foi gravado na ENTREGA" "pronto []" "$(fm_get "$WT/$ENT_REL" portao) $(fm_get "$WT/$ENT_REL" falhas_portao)"

# ---------------------------------------------------------------------------
# PASSO 10 — E3/E4/E5 e pre-e6
# ---------------------------------------------------------------------------
passo "PASSO 10 E3/E4/E5 e persistir-metodo pre-e6"
DIFF_ARQS="$(git -C "$WT" -c core.quotepath=false diff --name-only "$PROJ...HEAD")"
ATENCAO="$(cd "$WT" && printf '%s\n' "$DIFF_ARQS" | bash "$MX/classificar-atencao.sh" --base "$PROJ" 2>/dev/null | tr -d '\r')"
ck P10.1 "o E3 classifica cada arquivo do diff" "$(printf '%s\n' "$DIFF_ARQS" | grep -c .)" "$(printf '%s\n' "$ATENCAO" | grep -c .)"
{ printf '# Onde gastar atencao — %s\n\n| Arquivo | Faixa | Por que |\n|---|---|---|\n' "$SLUG"
  printf '%s\n' "$ATENCAO" | awk -F'\t' '{ printf "| `%s` | %s | %s |\n", $1, $2, $3 }'; } > "$WT/docs/entregas/$SLUG/ATENCAO.md"
printf 'X ganha o modo novo, e atual o usa.\n\n## Arquivos alterados\n\n%s\n' "$(git -C "$WT" diff --name-status "$PROJ...HEAD")" > "$WT/docs/entregas/$SLUG/PR.md"
printf '# Pacote de QA\n\n## 1. O que mudou\n\nO modulo novo usa o modo novo.\n\n## 2. Roteiro de teste\n\n### Caso 1 — modo novo\n\nRodar a suite e ver verde.\n' > "$WT/docs/entregas/$SLUG/QA-PACOTE.md"
fm_set "$WT/$ENT_REL" arquivos_alterados "[$(v9_produto | paste -sd, - | sed 's/,/, /g')]"
fm_set "$WT/$ENT_REL" atualizado_em "$HOJE"
metodo persistir pre-e6
ck P10.2 "pre-e6 commita" 0 "$METODO_RC"
PRE_E6="$(git -C "$WT" rev-parse HEAD)"
ck P10.3 "pre-e6: metodo, sem Task" "Metodo Trabalho" "$(trailers_do "$PRE_E6")"
ck P10.4 "pre-e6 leva os documentos E3-E5 e a ENTREGA, nenhum produto" \
  "docs/entregas/$SLUG/ATENCAO.md docs/entregas/$SLUG/ENTREGA.md docs/entregas/$SLUG/PR.md docs/entregas/$SLUG/QA-PACOTE.md" "$(paths_do "$PRE_E6")"
ck P10.5 "arvore coerente: nada de metodo pendente" "0 ok=true" "$(metodo verificar pre-e6; printf '%s %s' "$METODO_RC" "$METODO_SAIDA" | tr -d '\r')"

# ---------------------------------------------------------------------------
# PASSO 11 — E6, E7, E8: a ENTREGA terminal do fluxo real
# ---------------------------------------------------------------------------
passo "PASSO 11 E6/E7/E8: o terminal entregue"
ck P11.1 "E6: a branch e a da ENTREGA, nunca a principal" "feature/$SLUG" "$(git -C "$WT" branch --show-current)"
git -C "$WT" fetch -q origin 2>/dev/null
ck P11.2 "E6: o remoto nao tem a branch (primeiro push)" nao "$(sn git -C "$WT" rev-parse --verify -q "refs/remotes/origin/feature/$SLUG")"
git -C "$WT" push -q -u origin "feature/$SLUG" 2>/dev/null || quebra
fm_set "$WT/$ENT_REL" push_feito true
# E7: sem ferramenta de PR no ambiente da fixture — pr_url fica null, e isso não é falha.
fm_set "$WT/$ENT_REL" estado entregue
fm_set "$WT/$ENT_REL" entregue_em "$HOJE"
fm_set "$WT/$ENT_REL" atualizado_em "$HOJE"
ck P11.3 "a ENTREGA terminal valida no contrato da causa" causa=null \
  "$(cd "$WT" && bash "$MERGEX_CAUSA" --validar "$ENT_REL" | tr -d '\r')"
metodo persistir e8
ck P11.4 "E8 persiste o terminal" 0 "$METODO_RC"
E8="$(git -C "$WT" rev-parse HEAD)"
ck P11.5 "e8: metodo, sem Task, so a ENTREGA" "Metodo Trabalho docs/entregas/$SLUG/ENTREGA.md" "$(trailers_do "$E8") $(paths_do "$E8")"
git -C "$WT" fetch -q origin "feature/$SLUG" 2>/dev/null
ck P11.6 "o remoto esta contido no local" 0 "$(git -C "$WT" rev-list --count "HEAD..origin/feature/$SLUG")"
git -C "$WT" push -q origin "feature/$SLUG" 2>/dev/null || quebra
ck P11.7 "a publicacao final: HEAD = origin" "$(git -C "$WT" rev-parse HEAD)" "$(git -C "$WT" rev-parse "origin/feature/$SLUG")"
ck P11.8 "nenhum artefato de metodo dirty" "0 ok=true" "$(metodo verificar e8; printf '%s %s' "$METODO_RC" "$METODO_SAIDA" | tr -d '\r')"
ck P11.9 "arvore inteira limpa" "" "$(sujos)"
ck P11.10 "o terminal commitado: entregue/pronto" entregue "$(cd "$C" && entrega_terminal "$SLUG")"
ENT_HEAD="$(git -C "$WT" show "HEAD:$ENT_REL" | tr -d '\r')"
ck P11.11 "a ENTREGA commitada tem os campos vivos do contrato" "estado portao commits falhas_portao causa desvios" \
  "$(for k in estado portao commits falhas_portao causa desvios; do printf '%s\n' "$ENT_HEAD" | grep -q "^$k:" && printf '%s ' "$k"; done | sed 's/ $//')"
ck P11.12 "entregue, pronto, falhas [], causa null, desvios []" "entregue pronto [] null []" \
  "$(for k in estado portao falhas_portao causa desvios; do printf '%s\n' "$ENT_HEAD" | campo_registro "$k"; done | paste -sd' ' -)"
ck P11.13 "commits com seq 1..4, valido pela mergex no commit" "1 2 3 4 commits=4" \
  "$(printf '%s\n' "$ENT_HEAD" | bash "$MX/sequencia-de-commits.sh" --ler - | tr -d '\r' | cut -f2 | paste -sd' ' -) $(cd "$WT" && bash "$MX/sequencia-de-commits.sh" --validar "$ENT_REL" | tr -d '\r')"
ck P11.14 "a instalacao nao foi tocada por ninguem no fluxo" "" "$(git -C "$WT" diff --name-only "$INSTALACAO" HEAD -- .claude .expx)"

# ---------------------------------------------------------------------------
# MATERIAIS LOCAIS
# ---------------------------------------------------------------------------
passo "MATERIAIS locais: ignorados, e nenhum decide terminal"
mkdir -p "$WT/.expx/memoria"
printf '{"task":"T-01.04","fase":"f6"}\n' > "$WT/.expx/estado.json"
printf '{}\n' > "$WT/.expx/memoria/indice.json"
for p in "docs/eventos/$SLUG.jsonl" .expx/estado.json .expx/memoria/indice.json; do
  ck M.1 "ignorado: $p" sim "$(sn git -C "$WT" check-ignore -q "$p")"
done
ck M.2 "versionado: .expx/expx-lock.json" sim "$(sn git -C "$WT" cat-file -e "HEAD:.expx/expx-lock.json")"
ck M.3 "com os derivados presentes a arvore segue limpa" "" "$(sujos)"
ck M.4 "rastro e runtime: nenhum docs/eventos em commit" "" "$(git -C "$WT" log --format= --name-only "$BASE..HEAD" | grep '^docs/eventos/' || true)"
DEC_ANTES="$(cd "$C" && retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ") $(cd "$C" && entrega_terminal "$SLUG")"
mv "$WT/docs/eventos" "$TMP_RAIZ/eventos-guardados"
printf '{"estado":"bloqueado","portao":"bloqueado","task":"T-01.01"}\n' > "$WT/.expx/estado.json"
ck M.5 "sem rastro e com cache mentindo: a mesma decisao terminal" "$DEC_ANTES" \
  "$(cd "$C" && retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ") $(cd "$C" && entrega_terminal "$SLUG")"
mv "$TMP_RAIZ/eventos-guardados" "$WT/docs/eventos"

# ---------------------------------------------------------------------------
# PASSO 12 — a prova E real
# ---------------------------------------------------------------------------
passo "PASSO 12 a prova E do buildx"
ck P12.1 "caminho normal: arvore limpa" limpa "$(prova_e "$WT" "$SLUG")"
ck P12.2 "e limpa tambem no modo estrito" limpa "$(prova_e "$WT" "$SLUG" --estrito)"
printf '\nnota solta\n' >> "$WT/$TASKS_REL"
ck P12.3 "artefato de metodo dirty sem desvio: PARE" suja "$(prova_e "$WT" "$SLUG")"
git -C "$WT" checkout -q -- "$TASKS_REL"

DES=feature-desvio; WD="$TMP_RAIZ/$PROJ_NOME/wt-$DES"
( cd "$C" && feature_nasce "$DES" "$BASE" "$PROJ_NOME" ) || quebra
entrega_nova "$WD/docs/entregas/$DES/ENTREGA.md" "$DES" "feature/$DES" "$PROJ"
fm_set "$WD/docs/entregas/$DES/ENTREGA.md" estado entregue
fm_set "$WD/docs/entregas/$DES/ENTREGA.md" portao pronto
fm_set "$WD/docs/entregas/$DES/ENTREGA.md" desvios '[src/fora.sh]'
git -C "$WD" add -A && git -C "$WD" commit -q -m "chore(mergex): persiste metodo e8" -m "Trabalho: $DES" -m "Metodo: e8" || quebra
limpa_wd() { git -C "$WD" reset -q; git -C "$WD" checkout -q -- .; git -C "$WD" clean -qfd; }
printf 'fora\n' > "$WD/src/fora.sh"
ck P12.4 "desvio: so a sujeira exatamente declarada passa" autorizada "$(prova_e "$WD" "$DES")"
printf 'outra\n' > "$WD/src/outra.sh"
ck P12.5 "desvio: sujeira alem do declarado para" suja "$(prova_e "$WD" "$DES")"
limpa_wd; printf 'fora\n' > "$WD/src/fora.sh"; git -C "$WD" add src/fora.sh
ck P12.6 "desvio: stage nunca passa, mesmo declarado" stage_nao_autorizado "$(prova_e "$WD" "$DES")"
limpa_wd; printf 'outra\n' > "$WD/src/outra.sh"
fm_set "$WD/docs/entregas/$DES/ENTREGA.md" desvios "[src/fora.sh, src/outra.sh, docs/entregas/$DES/ENTREGA.md]"
ck P12.7 "desvio: a ENTREGA da worktree nao se autoautoriza" suja "$(prova_e "$WD" "$DES")"
limpa_wd; mkdir -p "$WD/docs/sprintx/features/$DES"; printf 'rascunho\n' > "$WD/docs/sprintx/features/$DES/rascunho.md"
ck P12.8 "desvio: artefato de metodo dirty nao declarado para" suja "$(prova_e "$WD" "$DES")"
limpa_wd
( cd "$C" && git worktree remove --force "$WD" && git branch -q -D "feature/$DES" ) || quebra

# ---------------------------------------------------------------------------
# PASSO 13 — o buildx segue pela entrega commitada
# ---------------------------------------------------------------------------
passo "PASSO 13 o buildx segue pelo contrato vigente, sem decisao humana"
cd "$C" || quebra
# O buildx executa a linha que a matriz devolve — e só ela.
buildx_segue() { # <slug> <FT> -> BUILDX_LETRA
  BUILDX_LETRA="$(retomada_decide "$1" "$BASE" em_andamento "$PROJ")"
  case "$BUILDX_LETRA" in
    L) provas_abcdef "$BASE" "$1" "$PROJ" "$WT" && prova_publicacao "$1" "$(campo_commitado "$1" push_feito)" &&
         integrar "feature/$1" && mapa_define docs/projeto/MAPA.md "$2" Status entregue &&
         mapa_define docs/projeto/MAPA.md "$2" SHA "$(git rev-parse --short HEAD)" &&
         git add docs/projeto/MAPA.md && git commit -q -m "chore(buildx): $2 entregue" && git push -q origin "$PROJ" ;;
    R:*) registra_entrega_bloqueada "$BASE" "$1" "$2" "$PROJ" &&
           b5_classifica docs/projeto/RECURSAO.md PEND-01 docs/projeto/MAPA.md FT-04 "$1-v2" &&
           git add -A && git commit -q -m "chore(buildx): B5" && git push -q origin "$PROJ" ;;
    T) registra_terminal_f6 "$BASE" "$1" "$2" "$PROJ" "$WT" &&
         b5_classifica docs/projeto/RECURSAO.md PEND-01 docs/projeto/MAPA.md FT-04 "$1-v2" &&
         git add -A && git commit -q -m "chore(buildx): B5" && git push -q origin "$PROJ" ;;
    *) return 1 ;;
  esac
}
mv "$WT" "$WT.longe"
ck K.1 "sem a worktree, a decisao sai do terminal commitado: L (D-35)" L "$(retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ")"
mv "$WT.longe" "$WT"
ck K.2 "com ela, a mesma: L" L "$(retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ")"
ck K.3 "nenhum terminal da F6: o retorno foi 1/1 e aprovado" nao "$(terminal_f6_commitado "feature/$SLUG" "$SLUG")"
ck K.4 "a prova E passa sobre a entrega commitada" limpa "$(prova_e "$WT" "$SLUG")"
BUILDX_LETRA=""
if buildx_segue "$SLUG" FT-02 >/dev/null 2>&1; then BS=sim; else BS=nao; fi
ck K.5 "o buildx segue a linha L: provas A-F, publicacao, fast-forward" "sim L" "$BS $BUILDX_LETRA"
ck K.6 "o controle esta no HEAD da feature" "$(git rev-parse "feature/$SLUG")" "$(git rev-parse HEAD~1)"
ck K.7 "a CONTROL publicada, local = remoto" sim "$(sn gate_local_remoto "$PROJ")"
ck K.8 "nenhuma PEND: sem RECURSAO.md" nao "$(sn test -e docs/projeto/RECURSAO.md)"
ck K.9 "nenhuma sucessora: 3 features, nenhuma de recursao" "3 0" \
  "$(tr -d '\r' < docs/projeto/MAPA.md | awk '/^### FT-/ { n++ } /^\*\*Origem:\*\* recursao$/ { r++ } END { print n + 0, r + 0 }')"
ck K.10 "nenhuma decisao_humana gerada" "" "$(grep -rl decisao_humana docs/projeto 2>/dev/null)"
ck K.11 "a FT-02 entregue no MAPA" entregue "$(mapa_valor docs/projeto/MAPA.md FT-02 Status)"
ck K.12 "todo B-NN resolvido" "" "$(blq listar "$SLUG" | tr -d '\r' | awk -F'\t' '$4 != "resolvido"')"
ck K.13 "a task concluida antes do defeito esta integrada, no mesmo seq 1" "sim $ITEM_0102" \
  "$(sn git merge-base --is-ancestor "$E1_0102" HEAD) $(git show "HEAD:$ENT_REL" | bash "$MX/sequencia-de-commits.sh" --ler - | tr -d '\r' | head -1)"
ck K.14 "e o E1 que trouxe o teste preservado e X tambem" "sim $PARCIAL" \
  "$(sn git merge-base --is-ancestor "$E1_0101" HEAD) $(git rev-parse HEAD:test/atual.test.sh)"
ck K.15 "a FT-03 esta livre para nascer" livre "$(retomada_decide feature-seguinte "$(git rev-parse HEAD)" pendente "$PROJ")"

# ---------------------------------------------------------------------------
# H e M — o backstop do E1 numa fixture recém-instalada, e a ordem inversa
# ---------------------------------------------------------------------------
# fixture <nome> <ordem> — um produto novo, instalado pelo ExpxDev, com uma feature
# em que a T-01.01 é a corrente e a T-01.02 é a dona de X.
fixture() {
  FX="$TMP_RAIZ/$1"; mkdir -p "$FX"
  git -C "$FX" init -q -b main && git -C "$FX" config user.email t@t && git -C "$FX" config user.name t &&
    git -C "$FX" config core.autocrlf false && git -C "$FX" commit -q --allow-empty -m inicial || quebra
  ck "$3.0" "o produto nasce sem .claude e sem .expx" "nao nao" "$(sn test -e "$FX/.claude") $(sn test -e "$FX/.expx")"
  instala "$FX" "$2"
  ck "$3.00" "expxdev init --skills $2: rc 0" "0 sim" "$INIT_RC $(sn eval 'printf "%s" "$INIT_SAIDA" | grep -q "instaladas: mergex, sprintx"')"
}
fixture_feature() { # a feature ft-h, na branch dela
  local p="$FX/docs/sprintx/features/ft-h/sprint-01"
  mkdir -p "$p" "$FX/src" "$FX/docs/entregas/ft-h"
  printf 'x() { echo x0; }\n' > "$FX/src/x.sh"
  printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: tasks\ntrabalho_id: ft-h\nsprint_id: sprint-01\natualizado_em: %s\ntasks:\n  - id: T-01.02\n    titulo: X\n    status: concluida\n    suite: verde\n    teste_integracao: a\n    teste_funcional: b\n    arquivos:\n      cria: []\n      altera: [src/x.sh]\n  - id: T-01.01\n    titulo: Atual\n    status: em_andamento\n    suite: nao_executada\n    teste_integracao: a\n    teste_funcional: b\n    arquivos:\n      cria: [src/atual.sh]\n      altera: []\n---\n\n# Sprint 01\n' "$HOJE" > "$p/tasks.md"
  printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: orquestrador\ntrabalho_id: ft-h\n---\n\n# Orquestrador\n' > "$FX/docs/sprintx/features/ft-h/ORQUESTRADOR.md"
  printf 'docs/eventos/\n' > "$FX/.gitignore"
  git -C "$FX" switch -q -c feature/ft-h
  entrega_nova "$FX/docs/entregas/ft-h/ENTREGA.md" ft-h feature/ft-h main
  git -C "$FX" add -A && git -C "$FX" commit -q -m "chore: fundacao ft-h" || quebra
}

# mini <prefixo> — doctor, os dois git-perigoso e o escopo pelo runner, o backstop
# do E1 e o catálogo em uso. MINI diz o comportamento, para comparar as ordens.
mini() {
  local x="$1" u n0 xa
  u="$(uuid)"
  ck "$x.20" "doctor: instalacao integra" "0 0" "$(cd "$FX" && PATH="$INIT_PATH" "$NODE" "$XBIN" doctor >/dev/null 2>&1; echo $?) $(doctor "$FX" | grep -c '^\[erro\]')"
  n0="$(git -C "$FX" rev-list --count HEAD)"
  # >>> runner-real
  runner_bash "$FX" "$u" "$RUNNER_PATH" "git branch -D c7b-inexistente"
  # <<< runner-real
  ck "$x.21" "sprintx/git-perigoso barra, pelo runner" "sim 2 sim" \
    "$RUN_TENTOU $RUN_RC $(sn eval 'printf "%s" "$RUN_SAIDA" | grep -q "sprintx/git-perigoso: comando barrado"')"
  MINI="gp-sprintx=$RUN_RC"
  # >>> runner-real
  runner_bash "$FX" "$u" "$RUNNER_PATH" "git commit --allow-empty -m c7b-sonda"
  # <<< runner-real
  ck "$x.22" "mergex/git-perigoso barra o commit na principal, pelo runner; nenhum commit" "sim 2 sim $n0" \
    "$RUN_TENTOU $RUN_RC $(sn eval 'printf "%s" "$RUN_SAIDA" | grep -q "mergex/git-perigoso — commit direto na branch principal"') $(git -C "$FX" rev-list --count HEAD)"
  MINI="$MINI gp-mergex=$RUN_RC"
  fixture_feature
  WT_SALVO="$WT"; WT="$FX"; evento_skill ft-h task_iniciada T-01.01 "$u"; WT="$WT_SALVO"
  xa="$(git -C "$FX" hash-object --no-filters src/x.sh)"
  # >>> runner-real
  runner_edit "$FX" "$u" src/x.sh 'echo x0; }' 'echo x9; }'
  # <<< runner-real
  ck "$x.23" "escopo-da-task barra X da irma, pelo runner; X intacto" "sim 2 sim $xa" \
    "$RUN_TENTOU $RUN_RC $(sn eval 'printf "%s" "$RUN_SAIDA" | grep -q "arquivo_de_task_irma"') $(git -C "$FX" hash-object --no-filters src/x.sh)"
  MINI="$MINI escopo=$RUN_RC"
  # Backstop: nenhum hook roda — a sujeira da irmã chega direto ao disco.
  printf 'atual() { :; }\n' > "$FX/src/atual.sh"
  printf 'x() { echo contornado; }\n' > "$FX/src/x.sh"
  n0="$(git -C "$FX" rev-list --count HEAD)"
  printf 'feat(ft-h): fecha T-01.01\n\nTask: T-01.01\nTrabalho: ft-h\n' > "$TMP_RAIZ/msg-ft-h.txt"
  E1_SAIDA="$(cd "$FX" && bash .claude/skills/mergex/scripts/fechamento-do-e1.sh --fechar --entrega docs/entregas/ft-h/ENTREGA.md \
    --task T-01.01 --mensagem "$TMP_RAIZ/msg-ft-h.txt" -- src/atual.sh 2>&1)"; E1_RC=$?
  ck "$x.24" "E1 instalado com a irma suja por fora do hook: barra (rc 8), arquivo_de_task_irma" "8 sim" \
    "$E1_RC $(sn eval 'printf "%s" "$E1_SAIDA" | grep -q "arquivo_de_task_irma"')"
  ck "$x.25" "nada no stage, nenhum commit, nenhum seq, e a sujeira fica onde estava" "|$n0|| M src/x.sh" \
    "$(git -C "$FX" diff --cached --name-only)|$(git -C "$FX" rev-list --count HEAD)|$(cd "$FX" && bash .claude/skills/mergex/scripts/sequencia-de-commits.sh --ler docs/entregas/ft-h/ENTREGA.md 2>/dev/null | tr -d '\r')|$(git -C "$FX" status --porcelain -- src/x.sh | tr -d '\r')"
  MINI="$MINI e1-backstop=$E1_RC"
  # O catálogo instalado é o que o E1 usa: sem ele, o E1 não decide (rc 9).
  rm -f "$FX/.claude/skills/mergex/scripts/catalogo-de-metodo.sh"
  E1_SAIDA="$(cd "$FX" && bash .claude/skills/mergex/scripts/fechamento-do-e1.sh --fechar --entrega docs/entregas/ft-h/ENTREGA.md \
    --task T-01.01 --mensagem "$TMP_RAIZ/msg-ft-h.txt" -- src/atual.sh 2>&1)"; E1_RC=$?
  ck "$x.26" "sem o catalogo-de-metodo.sh instalado o E1 para (rc 9), e o doctor acusa" "9 1" \
    "$E1_RC $(cd "$FX" && PATH="$INIT_PATH" "$NODE" "$XBIN" doctor >/dev/null 2>&1; echo $?)"
  git -C "$FX" checkout -q -- .claude/skills/mergex/scripts/catalogo-de-metodo.sh
  ck "$x.27" "o catalogo versionado de volta: doctor integro" 0 "$(cd "$FX" && PATH="$INIT_PATH" "$NODE" "$XBIN" doctor >/dev/null 2>&1; echo $?)"
  MINI="$MINI sem-catalogo=$E1_RC"
}

passo "H backstop fail-closed numa fixture recem-instalada (sprintx,mergex)"
fixture fx-h sprintx,mergex H
prova_instalacao "$FX" H
git -C "$FX" add -A && git -C "$FX" commit -q -m "chore: instala pelo expxdev" || quebra
FX_H="$FX"
arvore() { # <produto> — cada arquivo de .claude e .expx com o sha dele; o caminho do produto fora do settings
  ( cd "$1" && find .claude .expx -type f | LC_ALL=C sort | while IFS= read -r f; do
      case "$f" in
        .claude/settings.json) printf '%s %s\n' "$(tr -d '\r' < "$f" | jq -S 'del(.extraKnownMarketplaces["expx-local"].source.path)' | sha256sum | cut -d' ' -f1)" "$f" ;;
        *) printf '%s %s\n' "$(sha_de "$f")" "$f" ;;
      esac
    done )
}
ARVORE_H="$(arvore "$FX_H")"
mini H
MINI_H="$MINI"
evidencia "comportamento: $MINI_H"

passo "M segunda instalacao limpa, ordem inversa (mergex,sprintx)"
fixture fx-m mergex,sprintx M
:                                                                            # [Y14]
ck M.1o "as duas ordens instalam os mesmos bytes (so o caminho do produto no settings difere)" "" \
  "$(diff <(printf '%s\n' "$ARVORE_H" | grep -v ' \.expx/marketplace/') <(arvore "$FX" | grep -v ' \.expx/marketplace/') | grep '^[<>]' || true)"
ck M.2o "e o mesmo marketplace" "" "$(diff <(printf '%s\n' "$ARVORE_H" | grep ' \.expx/marketplace/') <(arvore "$FX" | grep ' \.expx/marketplace/') | grep '^[<>]' || true)"
prova_instalacao "$FX" M
git -C "$FX" add -A && git -C "$FX" commit -q -m "chore: instala pelo expxdev" || quebra
mini M
evidencia "comportamento: $MINI"
ck M.3o "a ordem inversa produz o mesmo comportamento" "$MINI_H" "$MINI"

# ---------------------------------------------------------------------------
# L — terminais da F6 e causas, nas bancadas determinísticas, nos pins de produção
# ---------------------------------------------------------------------------
passo "L terminais da F6 e causas: bancadas do harness, nos pins de producao"
# As causas da mergex candidata, uma a uma, pela classe que o buildx dá.
for c in $(bash "$MERGEX_CAUSA" --causas | tr -d '\r' | cut -d'|' -f2); do
  case "$c" in
    bloqueio_aberto) r="pelo B-NN (D-36)" ;;
    *) r="$(classe_da_causa "$c" 2>/dev/null)" || r="SEM CLASSE: para (falha fechada)" ;;
  esac
  CAUSAS="${CAUSAS:-}$c -> $r
"
done
printf '%s' "$CAUSAS" | sed 's/^/          causa: /'
ck L.1 "toda causa da mergex candidata tem classe no buildx (a V11 pela D-41)" "" \
  "$(printf '%s' "$CAUSAS" | grep 'SEM CLASSE' | cut -d' ' -f1 | paste -sd' ' -)"
if [ "$PINS_MODO" = producao ]; then
  # O caminho final: o proprio harness do repositorio, sem copia e sem troca de pin.
  IC="$REPO"
  ck L.2 "a bancada roda o harness do repositorio nos pins de producao: as fontes clonadas sao esses SHAs, sem copia" \
    "$SPRINTX_SHA_FIXO $MERGEX_SHA_FIXO" "$(git -C "$SRC/sprintx" rev-parse HEAD) $(git -C "$SRC/mergex" rev-parse HEAD)"
else
  # SO no modo de teste declarado: uma copia com os pins trocados pelo override.
  IC="$TMP_RAIZ/integ"; mkdir -p "$IC"
  ( cd "$REPO" && git -c safe.directory='*' ls-files -z --cached --others --exclude-standard | tar --null -T - -cf - ) | tar -C "$IC" -xf - || quebra
  sed -i -e "s/^SPRINTX_SHA_FIXO=$SPRINTX_SHA_FIXO/SPRINTX_SHA_FIXO=$C7B_SPRINTX_SHA/" -e "s/^MERGEX_SHA_FIXO=$MERGEX_SHA_FIXO/MERGEX_SHA_FIXO=$C7B_MERGEX_SHA/" "$IC/scripts/ci/integracao.sh"
  ck L.2 "MODO DE TESTE: a copia usa os SHAs do override, e o repositorio continua nos pins de producao" "2 2" \
    "$(grep -c -e "^SPRINTX_SHA_FIXO=$C7B_SPRINTX_SHA" -e "^MERGEX_SHA_FIXO=$C7B_MERGEX_SHA" "$IC/scripts/ci/integracao.sh") \
$(grep -c -e "^SPRINTX_SHA_FIXO=$SPRINTX_SHA_FIXO" -e "^MERGEX_SHA_FIXO=$MERGEX_SHA_FIXO" "$REPO/scripts/ci/integracao.sh")"
fi
INI="$EPOCHREALTIME"
( cd "$TMP_RAIZ" && SPRINTX_REPO="$SRC/sprintx" MERGEX_REPO="$SRC/mergex" BLOCOS="causa f6 f6d" \
    bash "$IC/scripts/ci/integracao.sh" > "$EVID/terminais-f6.log" 2>&1; echo $? > "$EVID/terminais-f6.rc" )
anota_tempo "integracao.sh causa f6 f6d ($PINS_MODO)" "$(ms_desde "$INI")"
RESUMO="$(tail -1 "$EVID/terminais-f6.log" | tr -d '\r')"
evidencia "bancada: $RESUMO"
grep -E '^  (FALHA|PULO)' "$EVID/terminais-f6.log" | head -5 | sed 's/^/          /'
ck L.3 "causa, f6, f6d nos pins ($PINS_MODO): 0 falhas, 0 pulos" "0 0 0" \
  "$(cat "$EVID/terminais-f6.rc") $(printf '%s' "$RESUMO" | sed -n 's/^[0-9]* ok, \([0-9]*\) falha(s), \([0-9]*\) pulo(s)$/\1 \2/p')"
for k in "X2D o B5 classifica e persiste" "Q2 mas o esgotamento commitado no mesmo HEAD vence" \
         "S.fronteira a sprintx recusa: fronteira_insegura" "S.fronteira o buildx nao pre-julga" \
         "P02.matriz v11 commit_nao_registrado -> trabalho_novo (D-41)"; do
  ck L.4 "a bancada exercitou: $k" sim "$(sn grep -qF "  ok    $k" "$EVID/terminais-f6.log")"
done
ck L.5 "recusa duravel, F5 esgotada na rodada e sem sucessora: casos presentes e verdes" "sim sim sim" \
  "$(sn grep -qE '^  ok .*recusa' "$EVID/terminais-f6.log") $(sn grep -qE '^  ok .*(F5|f5).*rodada' "$EVID/terminais-f6.log") $(sn grep -qE '^  ok .*nenhuma sucessora' "$EVID/terminais-f6.log")"

# ---------------------------------------------------------------------------
# PORTABILIDADE — o buildx num clone core.autocrlf=true
# ---------------------------------------------------------------------------
passo "PORTABILIDADE LF do buildx"
LF="$TMP_RAIZ/lf"; mkdir -p "$LF/fonte"
( cd "$REPO" && git -c safe.directory='*' ls-files -z --cached --others --exclude-standard | tar --null -T - -cf - ) | tar -C "$LF/fonte" -xf - || quebra
( cd "$LF/fonte" && git init -q -b main . && git config user.email t@t && git config user.name t &&
  git config core.autocrlf true && git add -A 2>/dev/null && git commit -q -m fonte ) || quebra
clona_crlf() { git clone -q -c core.autocrlf=true "$1" "$2" 2>/dev/null; }
clona_crlf "$LF/fonte" "$LF/clone" || quebra
ck LF.2 "o clone persiste core.autocrlf=true" true "$(git -C "$LF/clone" config --get core.autocrlf)"
ck LF.3 "todo .sh: indice LF, worktree LF, atributo eol=lf" "" \
  "$(git -C "$LF/clone" ls-files --eol -- '*.sh' | grep -Ev '^i/lf[[:space:]]+w/lf[[:space:]]+attr/text eol=lf[[:space:]]' || true)"
ck LF.4 "nenhum .sh tem byte CR, e o shebang e literal" "" \
  "$(cd "$LF/clone" && git ls-files -- '*.sh' | while IFS= read -r f; do
       [ "$(tr -cd '\r' < "$f" | wc -c | tr -d ' ')" = 0 ] || echo "$f:CR"; IFS= read -r l < "$f"; [ "$l" = '#!/usr/bin/env bash' ] || echo "$f:shebang"; done)"
ck LF.5 "todo .md: worktree LF, atributo eol=lf" "" \
  "$(git -C "$LF/clone" ls-files --eol -- '*.md' | grep -Ev '^i/lf[[:space:]]+w/lf[[:space:]]+attr/text eol=lf[[:space:]]' || true)"
ATR="$(tr -d '\r' < "$REPO/.gitattributes" 2>/dev/null | grep -v '^#' | grep . | LC_ALL=C sort | paste -sd'|' -)"
ck LF.1 "a politica e minima: *.md e *.sh, LF, e nada mais" '*.md text eol=lf|*.sh text eol=lf' "$ATR"
ck LF.6 "o harness do clone e executavel" "0 ambiente=ok" \
  "$(for f in $(cd "$LF/clone" && git ls-files -- '*.sh'); do bash -n "$LF/clone/$f" || echo "bash -n $f"; done
     bash "$LF/clone/scripts/ci/certifica-p02.sh" --ambiente | tr -d '\r' | sed 's/^/0 /')"
mkdir -p "$LF/pe" && git -C "$LF/pe" init -q -b feature/x && git -C "$LF/pe" -c user.email=t@t -c user.name=t commit -q --allow-empty -m i
ck LF.7 "a prova E do clone da o veredito" limpa "$(bash "$LF/clone/.claude/skills/buildx/scripts/prova-e.sh" "$LF/pe" x | sed -n 's/^veredito: //p')"
INI="$EPOCHREALTIME"
ck LF.8 "os contratos Markdown lidos mecanicamente passam no clone (bloco desvios)" 0 \
  "$(cd "$LF" && BLOCOS=desvios bash "$LF/clone/scripts/ci/integracao.sh" > "$LF/desvios.log" 2>&1; echo $?)"
anota_tempo "integracao.sh bloco desvios (clone)" "$(ms_desde "$INI")"
mkdir -p "$LF/sem-md"
( cd "$LF/fonte" && git archive HEAD ) | tar -C "$LF/sem-md" -xf -
grep -v '^\*\.md ' "$LF/sem-md/.gitattributes" > "$LF/sem-md/.ga" && mv -f "$LF/sem-md/.ga" "$LF/sem-md/.gitattributes"
( cd "$LF/sem-md" && git init -q -b main . && git config user.email t@t && git config user.name t &&
  git config core.autocrlf false && git add -A && git commit -q -m sem-md ) || quebra
clona_crlf "$LF/sem-md" "$LF/clone-sem-md" || quebra
ck LF.9 "sem *.md eol=lf o contrato Markdown chega CRLF no clone" "" \
  "$(git -C "$LF/clone-sem-md" ls-files --eol -- '*.md' | grep -v 'w/crlf' || true)"
if printf 'a\r\n' | grep -qx a; then GREP_CR=tolerante; else GREP_CR=sensivel; fi
printf '          grep desta plataforma: %s a CR\n' "$GREP_CR"
RC_SEM_MD="$(cd "$LF" && BLOCOS=desvios bash "$LF/clone-sem-md/scripts/ci/integracao.sh" > "$LF/sem-md.log" 2>&1; echo $?)"
if [ "$GREP_CR" = sensivel ]; then
  ck LF.10 "sem a regra, a leitura mecanica do contrato falha" 1 "$RC_SEM_MD"
  ck LF.11 "e a falha e de contrato Markdown, nao de script" sim "$(sn grep -q '^  FALHA C6.contrato' "$LF/sem-md.log")"
else
  ck LF.10 "com grep tolerante a CR a leitura passa: a regra protege os leitores sensiveis" 0 "$RC_SEM_MD"
fi

# ---------------------------------------------------------------------------
# Fontes intocadas, estado global do usuário, tempos e fechamento
# ---------------------------------------------------------------------------
passo "FONTES intocadas, ~/.claude intocado"
ck F.1 "a sprintx fonte continua como estava" "$FONTE_SX_ANTES" "$(estado_fonte "$C7B_SPRINTX_FONTE")"
ck F.2 "a mergex fonte continua como estava"  "$FONTE_MX_ANTES" "$(estado_fonte "$C7B_MERGEX_FONTE")"
ck F.3 "o expxdev fonte continua como estava" "$FONTE_XD_ANTES" "$(estado_fonte "$C7B_EXPXDEV_FONTE")"
# O arquivo inteiro não serve de prova: o marketplace oficial se atualiza sozinho
# (lastUpdated) a cada sessão do Claude Code na máquina. O que não pode aparecer é
# o expx — nem o marketplace local do produto, nem o plugin dele.
ck F.4 "o ~/.claude nao ganhou marketplace nem plugin do expx (o init nao registrou, o runner nao instalou)" "$PLUGINS_ANTES" \
  "$(expx_no_claude_global)"

passo "TEMPOS (informativo; nada decide)"
printf '%s' "$TEMPOS" | awk -F'\t' 'NF == 2 { n[$1]++; s[$1] += $2; if ($2 > m[$1]) m[$1] = $2 }
  END { for (k in n) printf "  %-46s n=%-3d media=%6d ms  max=%6d ms%s\n", k, n[k], s[k] / n[k], m[k], (m[k] > 10000 ? "  ACIMA DE 10 s" : "") }' | LC_ALL=C sort
printf '  %-46s %d ms\n' "total da certificacao" "$(ms_desde "$INICIO_TOTAL")"

if [ "$PINS_MODO" = producao ]; then
  printf '\n%d checkpoints, 0 falhas, 0 pulos — certificacao P0.2 OK nos pins de producao, sem override (runner %s%s)\n' "$PASSOU" "$C7B_RUNNER" \
    "$([ "$C7B_RUNNER" = claude ] && printf ', %s' "$CLAUDE_VERSAO")"
else
  printf '\n%d checkpoints, 0 falhas, 0 pulos — MODO DE TESTE (override:%s): NAO e a certificacao final (runner %s%s)\n' "$PASSOU" "$PINS_DIVERGENTES" "$C7B_RUNNER" \
    "$([ "$C7B_RUNNER" = claude ] && printf ', %s' "$CLAUDE_VERSAO")"
fi
