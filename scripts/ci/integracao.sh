#!/usr/bin/env bash
#
# Harness da integração acumulativa do buildx.
#
# O B4 manda o buildx provar coisas com o versionador antes de tocar na árvore
# do projeto. Este script implementa essas provas como funções e as exercita
# em repositórios git temporários — um por cenário, isolados entre si.
#
# O que ele protege: a invariante de linearidade (entre o nascimento de uma
# feature e a integração dela, buildx/<projeto_id> não recebe commit de mais
# ninguém), os dois portões do passo 1, as quatro provas do passo 7, e o fato
# de que toda falha é PARADA, nunca troca de mecanismo.
#
# Não depende de rede, de jq, nem de nenhum dos repositórios reais.
#
# Uso: bash scripts/ci/integracao.sh

set -uo pipefail

OK=0; FALHOU=0
TMP_RAIZ="$(mktemp -d)"
trap 'rm -rf "$TMP_RAIZ"' EXIT

caso() { # caso <descricao> <esperado> <obtido>
  if [ "$2" = "$3" ]; then
    OK=$((OK+1)); printf '  ok    %s\n' "$1"
  else
    FALHOU=$((FALHOU+1)); printf '  FALHA %s (esperava %s, obteve %s)\n' "$1" "$2" "$3"
  fi
}

sim_nao() { if "$@" >/dev/null 2>&1; then echo sim; else echo nao; fi; }

# ---------------------------------------------------------------------------
# Os portões do contrato, como o B4 os descreve
# ---------------------------------------------------------------------------

# Passo 1, portão 1: local e remoto no mesmo ponto. Igualdade estrita.
gate_local_remoto() { # <branch-do-projeto>
  git rev-parse --verify --quiet "refs/remotes/origin/$1" >/dev/null || return 0  # sem remoto: n/a
  git fetch -q origin 2>/dev/null
  [ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$1")" ]
}

# Passo 1, portão 2: a dependência está integrada e alcançável.
# Sem SHA no mapa, a única rederivação permitida é a evidência na árvore.
gate_dependencia() { # <sha-do-mapa-ou-vazio> <slug>
  local sha="$1" slug="$2"
  if [ -n "$sha" ]; then
    git merge-base --is-ancestor "$sha" HEAD
    return $?
  fi
  git cat-file -e "HEAD:docs/entregas/$slug/ENTREGA.md" 2>/dev/null || return 1
  git show "HEAD:docs/entregas/$slug/ENTREGA.md" 2>/dev/null | grep -q '^estado: entregue' || return 1
  [ -n "$(git rev-list -1 HEAD -- "docs/entregas/$slug/ENTREGA.md")" ]
}

# Passo 7: as quatro provas, antes de tocar em qualquer coisa.
provas_pre_ff() { # <base_sha> <branch-da-feature> <branch-do-projeto>
  [ -z "$(git status --porcelain)" ] || return 1                       # árvore limpa
  [ "$(git rev-parse HEAD)" = "$1" ] || return 1                       # CONTROL onde a feature nasceu
  if git rev-parse --verify --quiet "refs/remotes/origin/$3" >/dev/null; then
    git fetch -q origin 2>/dev/null
    [ "$(git rev-parse "origin/$3")" = "$1" ] || return 1              # remoto no mesmo ponto
  fi
  git merge-base --is-ancestor "$1" "$2" || return 1                   # feature descende da base
}

# A única forma de integrar.
integrar() { git merge --ff-only "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Montagem de cenário
# ---------------------------------------------------------------------------

novo_projeto() { # novo_projeto <nome> <com-remoto: sim|nao> -> ecoa o caminho do controle
  local nome="$1" com_remoto="$2" p="$TMP_RAIZ/$1"
  mkdir -p "$p"
  if [ "$com_remoto" = "sim" ]; then
    git init -q --bare "$p/origin.git"
    git clone -q "$p/origin.git" "$p/ctrl" 2>/dev/null
  else
    mkdir -p "$p/ctrl"; git init -q -b main "$p/ctrl"
  fi
  cd "$p/ctrl" || return 1
  git config user.email t@t; git config user.name t
  git commit -q --allow-empty -m "inicial"
  git branch -q -M main
  [ "$com_remoto" = "sim" ] && git push -q -u origin main
  git switch -q -c "buildx/$nome"
  mkdir -p docs/projeto docs/stack
  printf 'Branch principal: main\nBranch base: buildx/%s\n' "$nome" > docs/stack/CONVENCOES.md
  printf '# Mapa\n' > docs/projeto/MAPA.md
  git add -A; git commit -q -m "chore(buildx): estado inicial"
  [ "$com_remoto" = "sim" ] && git push -q -u origin "buildx/$nome"
  printf '%s\n' "$p/ctrl"
}

# Simula a feature: nasce da base indicada, num worktree, e entrega.
feature_entrega() { # feature_entrega <slug> <base_sha> <projeto>
  # Uma atribuição por linha: o bash expande a linha inteira do `local` antes
  # de atribuir, então uma variável não enxerga a anterior na mesma linha.
  local slug="$1"
  local base="$2"
  local proj="$3"
  local wt="$TMP_RAIZ/$proj/wt-$slug"
  git worktree add -q -b "feature/$slug" "$wt" "$base" 2>/dev/null || return 1
  mkdir -p "$wt/src" "$wt/docs/entregas/$slug"
  printf 'codigo de %s\n' "$slug" > "$wt/src/$slug.ts"
  printf 'estado: entregue\nportao: pronto\n' > "$wt/docs/entregas/$slug/ENTREGA.md"
  git -C "$wt" add -A
  git -C "$wt" -c user.email=t@t -c user.name=t commit -q -m "feat: $slug"
}

# ---------------------------------------------------------------------------
# Cenários
# ---------------------------------------------------------------------------

echo
echo "integração — caminho feliz e idempotência"

C="$(novo_projeto p1 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_entrega ft-01 "$BASE" p1
caso "1. provas passam antes do ff"        sim "$(sim_nao provas_pre_ff "$BASE" feature/ft-01 buildx/p1)"
caso "1. ff-only integra"                  sim "$(sim_nao integrar feature/ft-01)"
caso "1. conteudo da feature na arvore"    sim "$(sim_nao test -f src/ft-01.ts)"
caso "2. ff repetido e no-op (idempotente)" sim "$(sim_nao integrar feature/ft-01)"
SHA_FT01="$(git rev-parse HEAD)"

echo
echo "violações da invariante — todas param, nenhuma troca de mecanismo"

C="$(novo_projeto p3 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_entrega ft-01 "$BASE" p3
git commit -q --allow-empty -m "chore(buildx): estado no meio da janela"   # violação
caso "3. CONTROL mudou na janela: provas barram" nao "$(sim_nao provas_pre_ff "$BASE" feature/ft-01 buildx/p3)"
caso "3. e o ff de fato falha"                   nao "$(sim_nao integrar feature/ft-01)"

# O caso real: o CONVENCOES.md foi alterado ou marcado PROPOSTA, a F1 caiu em
# origin/HEAD e a feature nasceu de main em vez da branch do projeto.
C="$(novo_projeto p4 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_entrega ft-01 main p4
caso "4. feature nasceu de main: provas barram" nao "$(sim_nao provas_pre_ff "$BASE" feature/ft-01 buildx/p4)"
caso "4. e o ff de fato falha"                  nao "$(sim_nao integrar feature/ft-01)"

C="$(novo_projeto p5 sim)"; cd "$C"
git commit -q --allow-empty -m "chore(buildx): local a frente"
caso "5. local != origin antes da F1: portao barra" nao "$(sim_nao gate_local_remoto buildx/p5)"

C="$(novo_projeto p6 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_entrega ft-01 "$BASE" p6
git clone -q "$TMP_RAIZ/p6/origin.git" "$TMP_RAIZ/p6/outra" 2>/dev/null
git -C "$TMP_RAIZ/p6/outra" switch -q "buildx/p6"
git -C "$TMP_RAIZ/p6/outra" -c user.email=o@o -c user.name=o commit -q --allow-empty -m "outra sessao"
git -C "$TMP_RAIZ/p6/outra" push -q origin "buildx/p6"
caso "6. remoto mudou antes do ff: provas barram" nao "$(sim_nao provas_pre_ff "$BASE" feature/ft-01 buildx/p6)"

echo
echo "push"

C="$(novo_projeto p7 sim)"; cd "$C"
ORIGIN_ANTES="$(git rev-parse origin/buildx/p7)"
git clone -q "$TMP_RAIZ/p7/origin.git" "$TMP_RAIZ/p7/outra" 2>/dev/null
git -C "$TMP_RAIZ/p7/outra" switch -q "buildx/p7"
git -C "$TMP_RAIZ/p7/outra" -c user.email=o@o -c user.name=o commit -q --allow-empty -m "outra sessao"
git -C "$TMP_RAIZ/p7/outra" push -q origin "buildx/p7"
git commit -q --allow-empty -m "chore(buildx): estado local"
caso "7. push normal e rejeitado"            nao "$(sim_nao git push -q origin buildx/p7)"
git fetch -q origin
caso "7. e nada foi forcado no remoto"       sim "$(sim_nao git merge-base --is-ancestor "$ORIGIN_ANTES" origin/buildx/p7)"

echo
echo "portão de dependência"

C="$(novo_projeto p8 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"; feature_entrega ft-01 "$BASE" p8; integrar feature/ft-01
SHA="$(git rev-parse HEAD)"
caso "8. SHA ancestral: libera"                    sim "$(sim_nao gate_dependencia "$SHA" ft-01)"
FORA="$(git -C "$TMP_RAIZ/p8/wt-ft-01" rev-parse HEAD)"
git -C "$TMP_RAIZ/p8/wt-ft-01" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "depois da integracao"
NAO_ANC="$(git -C "$TMP_RAIZ/p8/wt-ft-01" rev-parse HEAD)"
caso "9. SHA nao ancestral: barra"                 nao "$(sim_nao gate_dependencia "$NAO_ANC" ft-01)"
caso "10. sem SHA, com ENTREGA na arvore: rederiva" sim "$(sim_nao gate_dependencia "" ft-01)"
caso "11. sem SHA e sem evidencia: barra"           nao "$(sim_nao gate_dependencia "" ft-99)"

echo
echo "barreira serial"

C="$(novo_projeto p12 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
git worktree add -q -b feature/ft-01 "$TMP_RAIZ/p12/wt-ft-01" "$BASE" 2>/dev/null
# feature falhou e sera replanejada: nenhum commit de estado em CONTROL
caso "12. replanejamento preserva CONTROL em BASE_SHA" "$BASE" "$(git rev-parse HEAD)"
printf 'plano refeito\n' > "$TMP_RAIZ/p12/wt-ft-01/src.ts"
git -C "$TMP_RAIZ/p12/wt-ft-01" add -A
git -C "$TMP_RAIZ/p12/wt-ft-01" -c user.email=t@t -c user.name=t commit -q -m "feat: replanejada"
caso "12. e o ff continua possivel depois"             sim "$(sim_nao integrar feature/ft-01)"

C="$(novo_projeto p13 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
git worktree add -q -b feature/ft-01 "$TMP_RAIZ/p13/wt-ft-01" "$BASE" 2>/dev/null
git commit -q --allow-empty -m "chore(buildx): FT-01 bloqueada"        # terminal: pode avançar
caso "13. bloqueio terminal avanca CONTROL"  nao "$(sim_nao test "$BASE" = "$(git rev-parse HEAD)")"
BASE2="$(git rev-parse HEAD)"
feature_entrega ft-02 "$BASE2" p13
caso "13. proxima feature nasce do novo ponto e integra" sim "$(sim_nao integrar feature/ft-02)"

echo
echo "projeto sem remoto, B6 e retomada"

C="$(novo_projeto p14 nao)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_entrega ft-01 "$BASE" p14
caso "14. sem remoto: portao local/remoto e n/a" sim "$(sim_nao gate_local_remoto buildx/p14)"
caso "14. sem remoto: provas passam"             sim "$(sim_nao provas_pre_ff "$BASE" feature/ft-01 buildx/p14)"
caso "14. sem remoto: integra local"             sim "$(sim_nao integrar feature/ft-01)"

C="$(novo_projeto p15 sim)"; cd "$C"
PRINCIPAL="$(grep '^Branch principal:' docs/stack/CONVENCOES.md | cut -d' ' -f3)"
printf 'Branch principal: %s\nBranch base: %s\n' "$PRINCIPAL" "$PRINCIPAL" > docs/stack/CONVENCOES.md
caso "15. B6 devolve Branch base a principal" "Branch base: main" "$(grep '^Branch base:' docs/stack/CONVENCOES.md)"

C="$(novo_projeto p16 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_entrega ft-01 "$BASE" p16
integrar feature/ft-01
DEPOIS="$(git rev-parse HEAD)"
# retomada encontra a feature já integrada: o estado C da matriz não se aplica
caso "16. retomada detecta INTEGRADA"        sim "$(sim_nao git merge-base --is-ancestor feature/ft-01 HEAD)"
integrar feature/ft-01
caso "16. e integrar de novo nao move CONTROL" "$DEPOIS" "$(git rev-parse HEAD)"

echo
echo "---------------------------------------------"
printf '%d ok, %d falha(s)\n' "$OK" "$FALHOU"
[ "$FALHOU" = "0" ]
