#!/usr/bin/env bash
#
# Mutações dirigidas do harness de integração do buildx (P0.1).
#
# Um teste que nunca falha não prova nada. Cada mutação abaixo reintroduz, numa
# CÓPIA da árvore, exatamente um dos defeitos que o P0.1 fechou — ignorar o
# CHECKPOINT, aceitar terminal só no working tree, deixar passar produto antes
# da F6, voltar a escrever `replanejamento`, reabrir a feature velha, apagar a
# seção de aguardando classificação, reutilizar PR-NN morto, não reservar PR-NN,
# deixar o item 8 vencer o item 7, contar reprovação por texto, deixar a raiz de
# fora da entrega da sucessora ou resolvê-la cedo, ignorar o laço de mesma
# cláusula, repetir ciclo sem conversão, disparar o detector com entrega, e
# resolver destino que o MAPA não tem — e, desde o P0.2, deixar o planejamento
# F6 vencer a ENTREGA terminal commitada, aceitar ENTREGA só no working tree e
# inferir bloqueio de registro inconsistente, e deixar o CHECKPOINT pendente
# vencer a ENTREGA terminal — e, no P0.2-A7, voltar a inferir `falha_tecnica` da
# descrição do B-NN, escolher a primeira classe quando há classes diferentes,
# tratar B-NN legado como tipado, aceitar `indeterminada` como causa conhecida,
# ignorar a V7 sem B-NN aberto e ler os B-NN do working tree — e exige que o
# harness FALHE.
# Mutação que sobrevive é teste que falta.
#
# O repositório real nunca é alterado: a cópia vive num diretório temporário e é
# apagada no fim. Antes das mutações, a mesma cópia sem mutação precisa passar.
#
# Uso: bash scripts/ci/mutacoes.sh              # todas, em paralelo
#      bash scripts/ci/mutacoes.sh M1 M4        # só as nomeadas
#      SPRINTX_REPO=/caminho/da/sprintx MERGEX_REPO=/caminho/da/mergex bash scripts/ci/mutacoes.sh

set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export SPRINTX_REPO="${SPRINTX_REPO:-$REPO/../sprintx}"
export MERGEX_REPO="${MERGEX_REPO:-$REPO/../mergex}"

HARNESS=scripts/ci/integracao.sh
RECURSAO_REF=.claude/skills/buildx/references/06-recursao.md
TEMPLATE_RECURSAO=.claude/skills/buildx/assets/TEMPLATE-RECURSAO.md

# copia <destino> — os arquivos rastreados, com o conteúdo do working tree.
copia() {
  mkdir -p "$1"
  git -C "$REPO" ls-files -z | tar -C "$REPO" --null -T - -cf - | tar -C "$1" -xf -
}

# troca <arquivo> <marcador> — troca a ÚNICA linha que contém o marcador pelo
# texto que chega no stdin. Zero ou mais de uma linha: a mutação não se aplica.
troca() {
  local arq="$1" marca="$2" novo="$TMP/linha.$$.$RANDOM" n
  cat > "$novo"
  n="$(grep -cF "$marca" "$arq")"
  [ "$n" = 1 ] || { echo "marcador '$marca' aparece $n vez(es) em $arq" >&2; return 1; }
  awk -v m="$marca" -v f="$novo" 'index($0, m) { while ((getline l < f) > 0) print l; next } { print }' "$arq" > "$arq.mut" &&
    mv -f "$arq.mut" "$arq"
}

# apaga_linha <arquivo> <linha exata>
apaga_linha() {
  local n; n="$(tr -d '\r' < "$1" | grep -cxF "$2")"
  [ "$n" = 1 ] || { echo "linha '$2' aparece $n vez(es) em $1" >&2; return 1; }
  tr -d '\r' < "$1" | grep -vxF "$2" > "$1.mut" && mv -f "$1.mut" "$1"
}

# aplica <mutacao> <arvore> — cada mutação é um defeito, e só um.
aplica() {
  local d="$2"
  case "$1" in
    M1) # ignorar o CHECKPOINT: tratar o estado do disco como durável
      troca "$d/$HARNESS" '# [M1]' <<'EOF'
    CHECKPOINT) persist=duravel; fonte=planejamento
      case "$estado" in aguardando_f3|replanejar) fase=F3 ;; aguardando_f4) fase=F4 ;; aguardando_f5) fase=F5 ;;
        aprovado) fase=F6 ;; orcamento_esgotado) fase=PARAR ;; esac ;;                      # [M1]
EOF
      ;;
    M2) # aceitar orcamento_esgotado só no working tree
      troca "$d/$HARNESS" '# [M2]' <<'EOF'
  cat "$(worktree_da_branch "$1")/docs/sprintx/features/$1/00-PLANEJAMENTO.md" 2>/dev/null |   # [M2]
EOF
      ;;
    M3) # permitir produto commitado antes da F6
      troca "$d/$HARNESS" '# [M3]' <<'EOF'
    :                                                                        # [M3]
EOF
      ;;
    M4) # reintroduzir replanejamento como classe do B5 — no enum e no contrato vivo
      troca "$d/$HARNESS" '# [M4]' <<'EOF'
CLASSES_B5="trabalho_novo replanejamento decisao_humana recurso_externo"    # [M4]
EOF
      printf '\n| `replanejamento` | a feature volta para a F3 do sprintx |\n' >> "$d/$RECURSAO_REF"
      ;;
    M5) # reabrir a feature velha no lugar de criar sucessora
      troca "$d/$HARNESS" '# [M5]' <<'EOF'
  slug_novo="$slug_velho"; mapa_define "$mapa" "$ft_velha" Status pendente   # [M5]
EOF
      ;;
    M6) # remover a seção de aguardando classificação do template
      apaga_linha "$d/$TEMPLATE_RECURSAO" '## Aguardando classificação do B5'
      ;;
    M7) # reutilizar PR-NN morto: a reserva do RECURSAO deixa de contar como ocupada
      troca "$d/$HARNESS" '# [M7]' <<'EOF'
    :                                                                       # [M7]
EOF
      ;;
    M8) # não reservar o PR-NN da feature bloqueada
      troca "$d/$HARNESS" '# [M8]' <<'EOF'
  prs="[]"                                                                  # [M8]
EOF
      ;;
    M9) # o item 8 vence a mistura
      troca "$d/$HARNESS" '# [M9]' <<'EOF'
  for regra in "8 recurso_externo" "7 decisao_humana"; do                  # [M9]
EOF
      ;;
    M10) # o buildx volta a contar reprovação por texto
      troca "$d/$HARNESS" '# [M10]' <<'EOF'
  saida="$(sprintx "$1" fase "$2")"                                       # [M10]
  [ "$(tr -d '\r' < "$1/docs/sprintx/features/$2/00-AUDITORIA.md" 2>/dev/null | grep -c '^VEREDITO: NÃO')" -ge 3 ] &&
    saida="$(printf 'fase=PARAR\nestado=orcamento_esgotado\nfonte=planejamento\npersistencia=duravel\n')"
EOF
      ;;
    M11) # a sucessora entregue não resolve a raiz
      troca "$d/$HARNESS" '# [M11]' <<'EOF'
    :                                                                       # [M11]
EOF
      ;;
    M12) # a sucessora pendente resolve a raiz cedo demais
      troca "$d/$HARNESS" '# [M12]' <<'EOF'
      pendente|em_andamento|bloqueada) entregues="$entregues $ft" ;;        # [M12]
EOF
      ;;
    M13) # ignorar mesmo gatilho e mesma cláusula da sucessora bloqueada
      troca "$d/$HARNESS" '# [M13]' <<'EOF'
  false                                                                     # [M13]
EOF
      ;;
    M14) # ciclo sem conversão inicia outro ciclo
      troca "$d/$HARNESS" '# [M14]' <<'EOF'
      if false; then                                                        # [M14]
EOF
      ;;
    M15) # o detector dispara mesmo havendo entrega
      troca "$d/$HARNESS" '# [M15]' <<'EOF'
        ;;                                                                  # [M15]
EOF
      ;;
    M16) # resolver a raiz com destino fora do MAPA
      troca "$d/$HARNESS" '# [M16]' <<'EOF'
      "") entregues="$entregues $ft" ;;                                     # [M16]
EOF
      ;;
    M17) # o planejamento F6/aprovado vence a ENTREGA terminal commitada
      troca "$d/$HARNESS" '# [M17]' <<'EOF'
  case "" in                                                               # [M17]
EOF
      ;;
    M18) # aceitar a ENTREGA do working tree como terminal
      troca "$d/$HARNESS" '# [M18]' <<'EOF'
  e="$(cat "$(worktree_da_branch "$1")/docs/entregas/$1/ENTREGA.md" 2>/dev/null)" || { echo ausente; return; }   # [M18]
EOF
      ;;
    M19) # inferir bloqueio de um registro inconsistente
      troca "$d/$HARNESS" '# [M19]' <<'EOF'
    *bloqueado*)                                echo bloqueada ;;            # [M19]
    *)                                          echo invalida ;;
EOF
      ;;
    M20) # o CHECKPOINT pendente (linha D) vence a ENTREGA terminal commitada
      troca "$d/$HARNESS" '# [M17]' <<'EOF'
  [ -n "$wt" ] && [ "$(buildx_acao "$wt" "$slug")" = completar_checkpoint ] && { echo D; return; }
  case "$(entrega_terminal "$slug")" in                                    # [M17]
EOF
      ;;
    M21) # voltar a inferir falha_tecnica da descrição do B-NN
      troca "$d/$HARNESS" '# [M21]' <<'EOF'
  git show "$sha:docs/sprintx/features/$slug/00-BLOQUEIOS.md" 2>/dev/null | grep -qiE '^    descricao: .*(arquivo|teste|suite)' &&
    { echo "trabalho_novo entrega_bloqueada/falha_tecnica"; return 0; }
  lista="$(bloqueios_commitados "$sha" "$slug")" || return 1                # [M21]
EOF
      ;;
    M22) # escolher a primeira classe quando há abertos de classes diferentes
      troca "$d/$HARNESS" '# [M22]' <<'EOF'
  abertas="$(printf '%s\n' "$abertas" | head -1)"; if false; then           # [M22]
EOF
      ;;
    M23) # tratar o B-NN legado como se tivesse classe
      troca "$d/$HARNESS" '# [M23]' <<'EOF'
  abertas="$(printf '%s\n' "$abertas" | sed 's/^legado$/defeito_de_plano/')"; if false; then   # [M23]
EOF
      ;;
    M24) # aceitar `indeterminada` como causa conhecida
      troca "$d/$HARNESS" '# [M24]' <<'EOF'
    ausente) echo "decisao_humana $r/causa_nao_commitada" ;;                # [M24]
    indeterminada) echo "trabalho_novo $r/causa_indeterminada" ;;
EOF
      ;;
    M25) # ignorar a V7 sem nenhum B-NN aberto
      troca "$d/$HARNESS" '# [M25]' <<'EOF'
  [ -n "$abertas" ] || abertas=defeito_de_plano                             # [M25]
EOF
      ;;
    M26) # ler os B-NN do working tree, e não do mesmo HEAD da ENTREGA
      troca "$d/$HARNESS" '# [M26]' <<'EOF'
  if cat "$(worktree_da_branch "$2")/$pasta/00-BLOQUEIOS.md" > "$raiz/$pasta/00-BLOQUEIOS.md" 2>/dev/null; then   # [M26]
EOF
      ;;
    *) echo "mutacao desconhecida: $1" >&2; return 1 ;;
  esac
}

# Os blocos do harness que precisam matar cada mutação.
blocos() {
  case "$1" in
    M1) echo "x2 x1" ;;
    M2) echo "x1" ;;
    M3) echo "terminal" ;;
    M4) echo "recursao vivos" ;;
    M5) echo "x1 recursao" ;;
    M6) echo "recursao" ;;
    M7) echo "x1 recursao" ;;
    M8) echo "x1" ;;
    M9) echo "recursao" ;;
    M10) echo "checkpoint" ;;
    M11|M12|M14|M15|M16) echo "convergencia" ;;
    M13) echo "recursao convergencia" ;;
    M17|M18|M19|M20) echo "entrega" ;;
    M21|M22|M23|M24|M25|M26) echo "causa" ;;
  esac
}

roda() { # roda <nome> <arvore> <blocos> -> grava <nome>.log e <nome>.rc
  ( cd "$TMP" && BLOCOS="$3" bash "$2/$HARNESS" > "$TMP/$1.log" 2>&1; echo $? > "$TMP/$1.rc" )
}

MUTACOES="${*:-M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13 M14 M15 M16 M17 M18 M19 M20 M21 M22 M23 M24 M25 M26}"
TODOS_BLOCOS="$(for m in $MUTACOES; do blocos "$m"; done | tr ' ' '\n' | sort -u | tr '\n' ' ')"

echo "controle — a árvore sem mutação passa nos blocos: $TODOS_BLOCOS"
copia "$TMP/controle"
roda controle "$TMP/controle" "$TODOS_BLOCOS"
if [ "$(cat "$TMP/controle.rc")" != 0 ] || grep -q '^  PULO' "$TMP/controle.log"; then
  echo "  o controle nao passou limpo — mutacoes sem valor:"; grep -E '^  (FALHA|PULO)' "$TMP/controle.log"
  exit 1
fi
tail -1 "$TMP/controle.log" | sed 's/^/  /'

for m in $MUTACOES; do
  copia "$TMP/$m"
  if ! aplica "$m" "$TMP/$m" 2> "$TMP/$m.aplica"; then
    echo "NAO_APLICADA" > "$TMP/$m.estado"; continue
  fi
  if git -C "$REPO" diff --no-index --quiet "$TMP/controle" "$TMP/$m" 2>/dev/null; then
    echo "NAO_APLICADA" > "$TMP/$m.estado"; continue
  fi
  roda "$m" "$TMP/$m" "$(blocos "$m")" &
done
wait

echo
FALHOU=0
for m in $MUTACOES; do
  if [ -f "$TMP/$m.estado" ]; then
    FALHOU=1; printf '  %-4s NAO APLICADA  %s\n' "$m" "$(cat "$TMP/$m.aplica" 2>/dev/null)"
  elif grep -q '^  PULO' "$TMP/$m.log"; then
    FALHOU=1; printf '  %-4s SEM PROVA     (cenario pulado)\n' "$m"
  elif [ "$(cat "$TMP/$m.rc")" != 0 ] && grep -q '^  FALHA' "$TMP/$m.log"; then
    printf '  %-4s morta         %s\n' "$m" "$(grep -m1 '^  FALHA' "$TMP/$m.log" | sed 's/^  FALHA //')"
  else
    FALHOU=1; printf '  %-4s SOBREVIVEU    %s\n' "$m" "$(tail -1 "$TMP/$m.log")"
  fi
done
echo
[ "$FALHOU" = 0 ] && echo "todas as mutacoes morreram" || echo "ha mutacao viva ou sem prova"
exit "$FALHOU"
