#!/usr/bin/env bash
#
# Mutações de INTEGRAÇÃO da certificação P0.2 (C7-B / B1).
#
# Não repetem a suíte de mutações de cada skill — cada skill mata os próprios
# mutantes. Estas reintroduzem, uma de cada vez, o defeito que a COMPOSIÇÃO
# buildx → sprintx → mergex precisa pegar, e exigem que scripts/ci/certifica-p02.sh
# FALHE num checkpoint:
#
#   X1  a sprintx deixa de barrar o arquivo de task irmã
#   X2  a sprintx lê o plano de uma feature histórica com o mesmo id de task
#   X3  o rastro volta a escolher o trabalho por mtime
#   X4  a mergex tira o ownership do E1
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
#   X15 a extração da skill usa SHA curto
#
# As da sprintx e da mergex (X1–X7, X10) são aplicadas no SNAPSHOT extraído, pelo
# gancho C7B_POS_EXTRACAO — nunca no repositório fonte. As do buildx, numa cópia
# da árvore. Antes delas, a cópia sem mutação passa (controle). Mutação que
# sobrevive é teste que falta. Rodam em série: a certificação tem um caso de
# concorrência medido em tempo, e contenção artificial não é o que se quer provar.
#
# Uso: bash scripts/ci/mutacoes-p02.sh             # controle + todas
#      bash scripts/ci/mutacoes-p02.sh X4 X12      # controle + as nomeadas
#      C7B_SPRINTX_FONTE=... C7B_MERGEX_FONTE=... bash scripts/ci/mutacoes-p02.sh

set -uo pipefail

EU="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CERT=scripts/ci/certifica-p02.sh
PROVA_E=.claude/skills/buildx/scripts/prova-e.sh

# troca <arquivo> <trecho> — troca a ÚNICA linha que contém o trecho pelo stdin.
troca() {
  local arq="$1" marca="$2" novo n
  novo="$(mktemp)"; cat > "$novo"
  n="$(grep -cF -- "$marca" "$arq")"
  [ "$n" = 1 ] || { echo "trecho '$marca' aparece $n vez(es) em $arq" >&2; rm -f "$novo"; return 1; }
  awk -v m="$marca" -v f="$novo" 'index($0, m) { while ((getline l < f) > 0) print l; next } { print }' "$arq" > "$arq.mut" &&
    mv -f "$arq.mut" "$arq"
  rm -f "$novo"
}

# Modo gancho: chamado pela certificação, depois da extração, com os snapshots.
if [ "${1:-}" = --snapshot ]; then
  m="$2"; SXS="$3"; MXS="$4"
  ESC="$SXS/.claude/hooks/sprintx/escopo-da-task.sh"
  FECHA="$MXS/.claude/skills/mergex/scripts/fechamento-do-e1.sh"
  case "$m" in
    X1) troca "$ESC" 'if [ -n "$TASKS_IRMAS" ]; then' <<'EOF'
if false; then
EOF
      ;;
    X2) troca "$ESC" 'TASKS_CANON="$(find "$RAIZ/docs/sprintx/features/$TRABALHO"' <<'EOF'
TASKS_CANON="$(find "$RAIZ/docs/sprintx/features" -maxdepth 4 -name tasks.md -type f 2>/dev/null | LC_ALL=C sort)"
EOF
      ;;
    X3) printf '\nrastro_trabalho_da_sessao() { ls -t "$1/docs/sprintx/features" 2>/dev/null | head -1; }\n' \
          >> "$SXS/.claude/hooks/comum/rastro.sh" ;;
    X4) troca "$FECHA" '    verifica_ownership "$TASK" "$@"    # 4' <<'EOF'
    :
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
    X10) troca "$MXS/.claude/skills/mergex/scripts/persistir-metodo.sh" 'adiciona "$ENTREGA"' <<'EOF'
adiciona "$ENTREGA"
git -C "$RAIZ" -c core.quotepath=false diff --name-only >> "$TMP_LISTA"
EOF
      ;;
    *) echo "mutacao de snapshot desconhecida: $m" >&2; exit 1 ;;
  esac
  exit $?
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export C7B_SPRINTX_FONTE="${C7B_SPRINTX_FONTE:-$(cd "$REPO/../sprintx" 2>/dev/null && pwd)}"
export C7B_MERGEX_FONTE="${C7B_MERGEX_FONTE:-$(cd "$REPO/../mergex" 2>/dev/null && pwd)}"
export C7B_PRESERVAR=0

# copia <destino> — os arquivos do buildx (rastreados e novos não ignorados), com o
# conteúdo desta árvore, num repositório próprio: a certificação lê o buildx pelo Git.
copia() {
  mkdir -p "$1"
  ( cd "$REPO" && git -c safe.directory='*' ls-files -z --cached --others --exclude-standard | tar --null -T - -cf - ) |
    tar -C "$1" -xf -
  ( cd "$1" && git init -q -b main . && git config user.email t@t && git config user.name t &&
    git config core.autocrlf false && git add -A 2>/dev/null && git commit -q -m copia ) >/dev/null 2>&1
}

snapshot() { printf '#!/usr/bin/env bash\nexec bash "%s" --snapshot %s "$@"\n' "$EU" "$1" > "$TMP/$1.pos.sh"; }

# aplica <mutacao> <arvore> — o defeito, e só ele.
aplica() {
  local d="$2"
  case "$1" in
    X1|X2|X3|X4|X5|X6|X7|X10) snapshot "$1" ;;
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
    *) echo "mutacao desconhecida: $1" >&2; return 1 ;;
  esac
}

roda() { # roda <nome> <arvore>
  local pos=""
  [ -f "$TMP/$1.pos.sh" ] && pos="$TMP/$1.pos.sh"
  ( cd "$TMP" && C7B_POS_EXTRACAO="$pos" bash "$2/$CERT" > "$TMP/$1.log" 2>&1; echo $? > "$TMP/$1.rc" )
}

MUTACOES="${*:-X1 X2 X3 X4 X5 X6 X7 X8 X9 X10 X11 X12 X13 X14 X15}"

printf 'controle — a arvore sem mutacao certifica\n'
copia "$TMP/controle"
roda controle "$TMP/controle"
if [ "$(cat "$TMP/controle.rc")" != 0 ] || grep -qE 'PULO|pulad' "$TMP/controle.log"; then
  echo "  o controle nao passou limpo — mutacoes sem valor:"; grep -E 'FALHA|PULO' "$TMP/controle.log" | head -5
  exit 1
fi
tail -1 "$TMP/controle.log" | sed 's/^/  /'

FALHOU=0
for m in $MUTACOES; do
  copia "$TMP/$m"
  if ! aplica "$m" "$TMP/$m" 2> "$TMP/$m.aplica"; then
    FALHOU=1; printf '  %-4s NAO APLICADA  %s\n' "$m" "$(cat "$TMP/$m.aplica")"; continue
  fi
  if [ ! -f "$TMP/$m.pos.sh" ] && diff -r -q -x .git "$TMP/controle" "$TMP/$m" >/dev/null 2>&1; then
    FALHOU=1; printf '  %-4s NAO APLICADA  (arvore identica ao controle)\n' "$m"; continue
  fi
  roda "$m" "$TMP/$m"
  if [ "$(cat "$TMP/$m.rc")" != 0 ] && grep -q '^  FALHA' "$TMP/$m.log"; then
    printf '  %-4s morta         %s\n' "$m" "$(grep -m1 '^  FALHA' "$TMP/$m.log" | sed 's/^  FALHA *//')"
  else
    FALHOU=1; printf '  %-4s SOBREVIVEU    %s\n' "$m" "$(tail -1 "$TMP/$m.log")"
  fi
  rm -rf "${TMP:?}/$m"
done
echo
[ "$FALHOU" = 0 ] && echo "todas as mutacoes de integracao morreram" || echo "ha mutacao viva ou nao aplicada"
exit "$FALHOU"
