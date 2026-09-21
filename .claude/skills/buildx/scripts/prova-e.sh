#!/usr/bin/env bash
#
# A prova E do buildx — a árvore da feature está limpa, exceto pelos caminhos
# que a ENTREGA terminal COMMITADA da própria feature declara em `desvios`.
#
# Ela responde UMA pergunta: "esta sujeira está explicada por um desvio
# commitado?". Não responde "esta sujeira é segura" — nenhum outro portão
# (segredo, contrato, integridade, prova independente) é afrouxado por ela.
#
# A fonte da autorização é SEMPRE o `ENTREGA.md` do `HEAD` da branch da
# feature, lido por `git show`. O arquivo da árvore de trabalho nunca autoriza
# coisa alguma — nem a si próprio.
#
# Uso:
#   prova-e.sh <worktree> <slug> [--ref <ref>] [--estrito]
#
#   --ref      a ref de onde ler a ENTREGA; o padrão é `feature/<slug>`
#   --estrito  limpeza estrita: nenhum desvio autoriza sujeira. É o modo dos
#              pontos do fluxo ANTERIORES a uma ENTREGA terminal commitada
#
# Saída (stdout), uma chave por linha:
#   veredito: <limpa|autorizada|suja|entrega_ausente|entrega_aberta|
#              entrega_invalida|desvios_ausente|desvios_invalidos|
#              stage_nao_autorizado|sem_worktree>
#   entrega:  <ausente|aberta|entregue|bloqueada|invalida>   (quando lida)
#   sujo: <XY><TAB><caminho>       um por caminho sujo, sempre que houver
#   autorizado_por: <caminho>      um por caminho que um desvio commitado explica
#   nao_autorizado: <caminho>      um por caminho que nenhum desvio explica
#
# Código de saída: 0 passou (limpa | autorizada) · 1 PARE · 2 sem worktree
# (a prova não se aplica — e ninguém reabre worktree para decidir).

set -uo pipefail

ESTRITO=0
REF=""
WT=""
SLUG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --estrito) ESTRITO=1; shift ;;
    --ref)     REF="${2:-}"; shift 2 ;;
    --ref=*)   REF="${1#--ref=}"; shift ;;
    -*)        printf 'opcao desconhecida: %s\n' "$1" >&2; exit 64 ;;
    *)         if   [ -z "$WT" ];   then WT="$1"
               elif [ -z "$SLUG" ]; then SLUG="$1"
               else printf 'argumento extra: %s\n' "$1" >&2; exit 64
               fi; shift ;;
  esac
done

if [ -z "$WT" ] || [ -z "$SLUG" ]; then
  printf 'uso: prova-e.sh <worktree> <slug> [--ref <ref>] [--estrito]\n' >&2
  exit 64
fi
[ -n "$REF" ] || REF="feature/$SLUG"

veredito() { printf 'veredito: %s\n' "$1"; }

# ---------------------------------------------------------------------------
# 1. Sem worktree, a prova não afirma nada sobre sujeira
# ---------------------------------------------------------------------------
# Árvore perdida não é árvore limpa. Quem chama decide o que fazer com o 2 — o
# contrato diz que a prova não se aplica, e que não se reabre worktree para
# decidir.
if [ ! -d "$WT" ] || ! git -C "$WT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  veredito sem_worktree
  exit 2
fi

# ---------------------------------------------------------------------------
# 2. DIRTY_PATHS, pelo Git, em forma NUL-safe
# ---------------------------------------------------------------------------
# `--porcelain -z` não cita, não escapa e não quebra em caminho com espaço,
# acento ou aspas. Renomeado traz DOIS caminhos — o novo e o de origem —, e os
# dois são sujeira. Ignorado pelo `.gitignore` não aparece aqui, e é assim que
# derivado local (`docs/eventos/`, `.expx/estado.json`) fica de fora sem que a
# prova precise de exceção nenhuma para ele.
SUJOS=()      # os caminhos
STATUS=()     # o XY de cada um
STAGED=()     # 1 quando o índice daquele caminho difere do HEAD

while IFS= read -r -d '' REG; do
  [ -n "$REG" ] || continue
  XY="${REG:0:2}"
  CAMINHO="${REG:3}"
  X="${XY:0:1}"
  EM_STAGE=0
  case "$X" in ' '|'?'|'!') ;; *) EM_STAGE=1 ;; esac
  SUJOS+=("$CAMINHO"); STATUS+=("$XY"); STAGED+=("$EM_STAGE")
  # Renomeado/copiado: o registro seguinte é o caminho de ORIGEM.
  case "$XY" in
    R?|C?|?R|?C)
      IFS= read -r -d '' ORIGEM || break
      SUJOS+=("$ORIGEM"); STATUS+=("$XY"); STAGED+=("$EM_STAGE")
      ;;
  esac
done < <(git -C "$WT" status --porcelain -z --untracked-files=all 2>/dev/null)

TOTAL="${#SUJOS[@]}"

i=0
while [ "$i" -lt "$TOTAL" ]; do
  printf 'sujo: %s\t%s\n' "${STATUS[$i]}" "${SUJOS[$i]}"
  i=$((i + 1))
done

# ---------------------------------------------------------------------------
# 3. Árvore limpa passa sem consultar autorização nenhuma
# ---------------------------------------------------------------------------
if [ "$TOTAL" = 0 ]; then
  veredito limpa
  exit 0
fi

nao_autorizados_todos() { local c; for c in "${SUJOS[@]}"; do printf 'nao_autorizado: %s\n' "$c"; done; }

# ---------------------------------------------------------------------------
# 4. Modo estrito: antes de uma ENTREGA terminal commitada, sujeira é sujeira
# ---------------------------------------------------------------------------
if [ "$ESTRITO" = 1 ]; then
  nao_autorizados_todos
  veredito suja
  exit 1
fi

# ---------------------------------------------------------------------------
# 5. A ENTREGA COMMITADA — a única fonte da autorização
# ---------------------------------------------------------------------------
if ! ENTREGA="$(git -C "$WT" show "$REF:docs/entregas/$SLUG/ENTREGA.md" 2>/dev/null)"; then   # [M46]
  printf 'entrega: ausente\n'
  nao_autorizados_todos
  veredito entrega_ausente                                                                    # [M49]
  exit 1
fi
ENTREGA="$(printf '%s\n' "$ENTREGA" | tr -d '\r')"

chave_unica() { # <chave> -> o valor; falha se a chave não aparece exatamente uma vez
  local n
  n="$(printf '%s\n' "$ENTREGA" | grep -c "^$1: ")"
  [ "$n" = 1 ] || return 1
  printf '%s\n' "$ENTREGA" | grep "^$1: " | head -1 | cut -d' ' -f2-
}

ESTADO="$(chave_unica estado)" || ESTADO="__ausente_ou_repetida__"
PORTAO="$(chave_unica portao)" || PORTAO="__ausente_ou_repetida__"

case "$ESTADO:$PORTAO" in
  entregue:pronto)                            TERMINAL=entregue ;;
  bloqueado:bloqueado)                        TERMINAL=bloqueada ;;
  aberto:pronto|aberto:bloqueado|aberto:null) TERMINAL=aberta ;;
  *)                                          TERMINAL=invalida ;;
esac
printf 'entrega: %s\n' "$TERMINAL"

case "$TERMINAL" in
  entregue|bloqueada) ;;
  aberta)  # entrega em curso não é terminal: nada nela autoriza sujeira
    nao_autorizados_todos; veredito entrega_aberta; exit 1 ;;                                 # [M50]
  *)
    nao_autorizados_todos; veredito entrega_invalida; exit 1 ;;
esac

# ---------------------------------------------------------------------------
# 6. `desvios` — lista de fluxo numa linha só, como a mergex a grava
# ---------------------------------------------------------------------------
if ! DESVIOS_CRU="$(chave_unica desvios)"; then
  nao_autorizados_todos; veredito desvios_ausente; exit 1
fi

DECLARADOS=()
case "$DESVIOS_CRU" in
  \[*\]) ;;
  *) nao_autorizados_todos; veredito desvios_invalidos; exit 1 ;;
esac
MIOLO="${DESVIOS_CRU#\[}"; MIOLO="${MIOLO%\]}"
if [ -n "$(printf '%s' "$MIOLO" | tr -d ' \t')" ]; then
  # O separador é a vírgula e só ela: espaço DENTRO do caminho é parte do caminho.
  while IFS= read -r -d '' ITEM; do
    if [ -z "$ITEM" ]; then
      nao_autorizados_todos; veredito desvios_invalidos; exit 1
    fi
    DECLARADOS+=("$ITEM")
  done < <(printf '%s' "$MIOLO" | awk -F, '{
      for (i = 1; i <= NF; i++) { s = $i
        sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s)
        printf "%s%c", s, 0 } }')
fi

# ---------------------------------------------------------------------------
# 7. A prova: DIRTY_PATHS ⊆ DECLARADOS, com casamento EXATO de caminho
# ---------------------------------------------------------------------------
# Exato: nada de prefixo, nada de substring, nada de `grep` frouxo. `src/foo`
# não autoriza `src/foo/bar.ts`, e `src/foo.ts` não autoriza `src/foo.ts.bak`.
declarado() { # <caminho>
  local d                                                                                     # [M54]
  for d in ${DECLARADOS+"${DECLARADOS[@]}"}; do                                               # [M53]
    [ "$d" = "$1" ] && return 0                                                               # [M47]
  done
  return 1                                                                                    # [M45]
}

# Stage não é assunto de desvio. A mergex deixa o desvio NA ÁRVORE e nunca o põe
# no índice (DM-13), e o E1 exige índice vazio na entrada. Caminho declarado em
# `desvios` não compra autorização para conteúdo em stage.
PARA=0
i=0
while [ "$i" -lt "$TOTAL" ]; do                                                               # [M48]
  if [ "${STAGED[$i]}" = 1 ]; then                                                            # [M52]
    printf 'nao_autorizado: %s\n' "${SUJOS[$i]}"
    PARA=2
  elif declarado "${SUJOS[$i]}"; then                                                         # [M51]
    printf 'autorizado_por: %s\n' "${SUJOS[$i]}"
  else
    printf 'nao_autorizado: %s\n' "${SUJOS[$i]}"
    [ "$PARA" = 2 ] || PARA=1
  fi
  i=$((i + 1))
done

case "$PARA" in
  0) veredito autorizada;           exit 0 ;;
  2) veredito stage_nao_autorizado; exit 1 ;;
  *) veredito suja;                 exit 1 ;;
esac
