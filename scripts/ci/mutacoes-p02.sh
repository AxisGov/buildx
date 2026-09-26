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
# As do B1, ancoradas nos pins de produção (D-42):
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
# As da sprintx e da mergex (X1–X7, X10, Y8, Y10, Y11, Y17) são aplicadas na FONTE
# clonada no SHA, antes do `expxdev init`, pelo gancho C7B_POS_EXTRACAO — nunca no
# repositório fonte: a mutação chega ao produto pelo instalador, como chegaria de
# verdade. As do buildx e da certificação, numa cópia da árvore. Antes delas, a
# cópia sem mutação passa (controle). Mutação que sobrevive é teste que falta.
#
# Rodam SEM runner real (C7B_RUNNER=settings): os hooks do settings.json instalado
# são despachados como o Claude Code os despacha. A prova com o runner real — e a
# do agente da seção R — é a certificação em si, com o Claude Code (Linux/WSL em
# ext4, o ambiente canônico); o relatório diz isso. Rodam longas: só no Linux.
#
# Uso: bash scripts/ci/mutacoes-p02.sh             # controle + todas
#      bash scripts/ci/mutacoes-p02.sh X4 Y9       # controle + as nomeadas
#      C7B_EXPXDEV_BUILD=<checkout construído> bash scripts/ci/mutacoes-p02.sh

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

aplica() { # aplica <mutacao> <arvore> — o defeito, e só ele
  local d="$2"
  case "$1" in
    X1|X2|X3|X4|X5|X6|X7|X10|Y8|Y10|Y11|Y17) snapshot "$1" ;;
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
    *) echo "mutacao desconhecida: $1" >&2; return 1 ;;
  esac
}

roda() { # roda <nome> <arvore>
  local pos=""
  [ -f "$TMP/$1.pos.sh" ] && pos="$TMP/$1.pos.sh"
  ( cd "$TMP" && C7B_POS_EXTRACAO="$pos" bash "$2/$CERT" > "$TMP/$1.log" 2>&1; echo $? > "$TMP/$1.rc" )
}

MUTACOES="${*:-X1 X2 X3 X4 X5 X6 X7 X8 X9 X10 X11 X12 X13 X14 X15 Y1 Y2 Y3 Y4 Y5 Y6 Y7 Y8 Y9 Y10 Y11 Y12 Y13 Y14 Y15 Y16 Y17 Y18 Y19 Y20 Y21}"

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
  if [ ! -f "$TMP/$m.pos.sh" ] && diff -r -q -x .git "$TMP/controle" "$TMP/$m" >/dev/null 2>&1; then
    FALHOU=1; printf '  %-4s NAO APLICADA  (arvore identica ao controle)\n' "$m"; continue
  fi
  roda "$m" "$TMP/$m"
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
