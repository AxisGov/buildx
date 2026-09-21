#!/usr/bin/env bash
#
# Mutações dirigidas do harness de integração do buildx (P0.1 a P0.2-B).
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
# ignorar a V7 sem B-NN aberto e ler os B-NN do working tree — e, no P0.2-B,
# criar o planejamento sem o teto da F6, inventar teto para o legado, deixar
# `defeito_de_plano -> trabalho_novo` vencer o esgotamento, criar sucessora depois
# de 1/1, retomar a F6 com a rodada aberta, gastar a rodada de novo na retomada,
# abrir task depois da recusa, tratar contrato como pendência e passar o teto da F6
# a um legado na retomada da F1 — e, no fechamento do P0.2-B, ignorar o estado
# durável e voltar a ler o worktree, transformar `classes_mistas` em trabalho novo,
# inventar a causa pelo B-NN, aceitar motivo fora do enum, dar à F5 esgotada dentro
# da rodada o gatilho e a classe do caso normal, exigir worktree no portão terminal
# da F6 e aceitar a sprintx anterior ao estado durável — e, no P0.2-C6, os dez defeitos
# que a prova E dos desvios fecha: qualquer `desvios` não vazio liberando qualquer
# sujeira, ler a ENTREGA do worktree, prefixo de diretório, prefixo cru, olhar só o
# primeiro caminho sujo, ENTREGA ausente ou aberta autorizando, allowlist de artefato
# de método, stage passando por desvio e `desvios: []` valendo por "nada a restringir"
# — e exige que o harness FALHE.
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
PROVA_E=.claude/skills/buildx/scripts/prova-e.sh

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
    M27) # criar o planejamento novo sem o quarto argumento `1`
      troca "$d/$HARNESS" '# [M27]' <<'EOF'
  printf '%s %s\n' "$ORCAMENTO_F5_MAX" "$ORCAMENTO_F5_POR"                   # [M27]
EOF
      ;;
    M28) # inventar orçamento 1 para o planejamento legado
      troca "$d/$HARNESS" '# [M28]' <<'EOF'
  [ "$(chave "$saida" orcamento_f6)" = legado ] && saida="$(printf '%s\nmax_replanejamentos_f6=1\nreplanejamentos_f6=0\n' "$saida")"   # [M28]
EOF
      ;;
    M29) # deixar defeito_de_plano -> trabalho_novo vencer o retorno esgotado ou recusado
      troca "$d/$HARNESS" '# [M29]' <<'EOF'
    "nunca")   # [M29]
EOF
      ;;
    M30) # criar sucessora depois da rodada 1/1
      troca "$d/$HARNESS" '# [M30]' <<'EOF'
    replanejamento_execucao_esgotado) echo "trabalho_novo replanejamento_execucao_esgotado" ;;   # [M30]
EOF
      ;;
    M31) # retomar a F6 normal com o estado em replanejar_execucao
      troca "$d/$HARNESS" '# [M31]' <<'EOF'
    F3:replanejar_execucao)         echo f6 ;;   # [M31]
EOF
      ;;
    M32) # a retomada refaz o passo da F6 que abriu a rodada, e a gasta de novo
      troca "$d/$HARNESS" '# [M32]' <<'EOF'
    S:continuar_*) sx_bloqueia "$4" "$1" "$(SPRINTX_RAIZ="$4" bash "$SPRINTX_BLOQUEIOS" listar "$1" | tr -d '\r' | awk -F'\t' '$3 == "defeito_de_plano" { print $2; exit }')" defeito_de_plano
                   sprintx "$4" replanejar-execucao "$1" >/dev/null; echo "sprintx_${d#S:continuar_}" ;;   # [M32]
EOF
      ;;
    M33) # continuar abrindo task quando o retorno foi recusado
      troca "$d/$HARNESS" '# [M33]' <<'EOF'
    *) echo F ;;   # [M33]
EOF
      ;;
    M34) # tratar contradição, fronteira ou contrato como pendência normal
      troca "$d/$HARNESS" '# [M34]' <<'EOF'
  echo "decisao_humana replanejamento_execucao_recusado/${1#recusado:}"   # [M34]
EOF
      ;;
    M35) # passar o teto da F6 a um planejamento legado na retomada da F1
      troca "$d/$HARNESS" '# [M35]' <<'EOF'
    printf '%s %s %s\n' "$ORCAMENTO_F5_MAX" "$ORCAMENTO_F5_POR" "$ORCAMENTO_F6_MAX"   # [M35]
EOF
      ;;
    M36) # ignorar o estado durável e voltar a decidir pela leitura do worktree
      troca "$d/$HARNESS" '# [M36]' <<'EOF'
  case "$(if [ -n "$wt" ] && [ -d "$wt" ]; then terminal_f6_em "$wt" "$slug"; else echo nao; fi)" in   # [M36]
EOF
      ;;
    M37) # transformar a recusa por classes mistas em trabalho novo
      troca "$d/$HARNESS" '# [M37]' <<'EOF'
                  { case "$1" in
                      recusado:classes_mistas) echo "trabalho_novo replanejamento_execucao_recusado/classes_mistas" ;;
                      *) echo "decisao_humana replanejamento_execucao_recusado/${1#recusado:}" ;;
                    esac; return 0; } ;;   # [M37]
EOF
      ;;
    M38) # inventar o motivo pela classe dos B-NN, em vez de ler a chave commitada
      troca "$d/$HARNESS" '# [M38]' <<'EOF'
      m="$(printf '%s
' "$lista" | tr -d '
' | awk -F'	' '$4 == "aberto" && !v[$3]++ { n++ } END { print (n > 1 ? "classes_mistas" : "orcamento_f6_nao_declarado") }')"   # [M38]
EOF
      ;;
    M39) # aceitar qualquer motivo como recusa durável
      troca "$d/$HARNESS" '# [M39]' <<'EOF'
motivo_duravel() { [ -n "${1:-}" ]; }   # [M39]
EOF
      ;;
    M40) # dar à F5 esgotada dentro da rodada o gatilho do caso normal
      troca "$d/$HARNESS" '# [M40]' <<'EOF'
    f5_esgotado_na_rodada) echo orcamento_f5_esgotado ;;   # [M40]
EOF
      ;;
    M41) # criar sucessora no esgotamento da F5 durante o replanejamento
      troca "$d/$HARNESS" '# [M41]' <<'EOF'
      echo "trabalho_novo orcamento_f5_esgotado_durante_replanejamento_execucao"; return 0 ;;   # [M41]
EOF
      ;;
    M42) # exigir worktree no portão terminal da F6
      troca "$d/$HARNESS" '# [M42]' <<'EOF'
  [ -n "$wt" ] && [ -d "$wt" ] || return 1   # [M42]
  if [ -n "$wt" ]; then
EOF
      ;;
    M43) # aceitar a sprintx anterior ao estado durável como equivalente
      troca "$d/$HARNESS" '# [M43]' <<'EOF'
SPRINTX_SHA_FIXO=5cdde90dabae86fd6f5c0238a90ffd83454495f8                   # [M43]
EOF
      ;;
    M44) # usar a regra normal do orçamento da F5 dentro da rodada da F6
      troca "$d/$HARNESS" '# [M44]' <<'EOF'
      if false; then echo terminal_f6   # [M44]
EOF
      ;;
    M45) # qualquer `desvios` não vazio libera qualquer sujeira
      troca "$d/$PROVA_E" '# [M45]' <<'EOF'
  [ "${#DECLARADOS[@]}" -gt 0 ] && return 0                                                   # [M45]
  return 1
EOF
      ;;
    M46) # ler a ENTREGA da árvore de trabalho — a cópia que se autoautoriza
      troca "$d/$PROVA_E" '# [M46]' <<'EOF'
if ! ENTREGA="$(cat "$WT/docs/entregas/$SLUG/ENTREGA.md" 2>/dev/null)"; then                  # [M46]
EOF
      ;;
    M47) # prefixo de diretório: `src/foo` passa a autorizar `src/foo/bar.ts`
      troca "$d/$PROVA_E" '# [M47]' <<'EOF'
    case "$1" in "$d"|"$d"/*) return 0 ;; esac                                                # [M47]
EOF
      ;;
    M48) # olhar só o primeiro caminho sujo, e ignorar o segundo não declarado
      troca "$d/$PROVA_E" '# [M48]' <<'EOF'
while [ "$i" -lt 1 ] && [ "$i" -lt "$TOTAL" ]; do                                             # [M48]
EOF
      ;;
    M49) # ENTREGA ausente passa a permitir sujeira
      troca "$d/$PROVA_E" '# [M49]' <<'EOF'
  veredito limpa; exit 0                                                                      # [M49]
EOF
      ;;
    M50) # ENTREGA aberta passa a autorizar os `desvios` dela
      troca "$d/$PROVA_E" '# [M50]' <<'EOF'
    ;;                                                                                        # [M50]
EOF
      ;;
    M51) # allowlist genérica de artefato de método
      troca "$d/$PROVA_E" '# [M51]' <<'EOF'
  elif case "${SUJOS[$i]}" in docs/*) true ;; *) declarado "${SUJOS[$i]}" ;; esac; then       # [M51]
EOF
      ;;
    M52) # stage de caminho declarado passa a ser autorizado pelo desvio
      troca "$d/$PROVA_E" '# [M52]' <<'EOF'
  if false; then                                                                              # [M52]
EOF
      ;;
    M53) # casamento por prefixo cru: `src/foo.ts` passa a autorizar `src/foo.ts.bak`
      troca "$d/$PROVA_E" '# [M53]' <<'EOF'
  for d in ${DECLARADOS+"${DECLARADOS[@]}"}; do case "$1" in "$d"*) return 0 ;; esac          # [M53]
EOF
      ;;
    M54) # `desvios: []` passa a significar "nada a restringir"
      troca "$d/$PROVA_E" '# [M54]' <<'EOF'
  local d; [ "${#DECLARADOS[@]}" = 0 ] && return 0                                            # [M54]
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
    M27) echo "orcamento f6" ;;
    M29|M30|M31|M32|M34) echo "f6" ;;
    M28|M33|M35|M36|M37|M38|M39|M40|M41|M42|M43|M44) echo "f6d" ;;
    M45|M46|M47|M48|M49|M50|M51|M52|M53|M54) echo "desvios" ;;
  esac
}

roda() { # roda <nome> <arvore> <blocos> -> grava <nome>.log e <nome>.rc
  ( cd "$TMP" && BLOCOS="$3" bash "$2/$HARNESS" > "$TMP/$1.log" 2>&1; echo $? > "$TMP/$1.rc" )
}

MUTACOES="${*:-M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13 M14 M15 M16 M17 M18 M19 M20 M21 M22 M23 M24 M25 M26 M27 M28 M29 M30 M31 M32 M33 M34 M35 M36 M37 M38 M39 M40 M41 M42 M43 M44 M45 M46 M47 M48 M49 M50 M51 M52 M53 M54}"
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
