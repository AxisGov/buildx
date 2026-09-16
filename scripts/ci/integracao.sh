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
# ninguém), os três portões do passo 1, as seis provas do passo 7 mais a prova
# de publicação, o contrato do E8 da mergex (o buildx lê o commitado, e entrega
# bloqueada não é publicada), o nascimento exato da feature, a promoção
# idempotente das premissas da F2, a fundação sincronizada do B2 e a separação
# entre ciclo não-final e fechamento definitivo no B6 — e o fato de que toda
# falha é PARADA, nunca troca de mecanismo.
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

# Passo 7, provas A–D: árvore de controle limpa, `CONTROL` em `BASE_SHA`, remoto
# no mesmo ponto, e a feature descendendo daquela base.
provas_pre_ff() { # <base_sha> <branch-da-feature> <branch-do-projeto>
  [ -z "$(git status --porcelain)" ] || return 1                       # árvore limpa
  [ "$(git rev-parse HEAD)" = "$1" ] || return 1                       # CONTROL onde a feature nasceu
  if git rev-parse --verify --quiet "refs/remotes/origin/$3" >/dev/null; then
    git fetch -q origin 2>/dev/null
    [ "$(git rev-parse "origin/$3")" = "$1" ] || return 1              # remoto no mesmo ponto
  fi
  git merge-base --is-ancestor "$1" "$2" || return 1                   # feature descende da base
}

# Passo 7, as seis provas nomeadas. A `provas_pre_ff` acima cobre A–D e é o que
# os cenários antigos exercitam; esta acrescenta E (árvore da feature limpa) e
# F (o estado final está no HEAD da feature, não na worktree).
provas_abcdef() { # <base_sha> <slug> <branch-do-projeto> <worktree>
  local base="$1"
  local slug="$2"
  local proj="$3"
  local wt="$4"
  provas_pre_ff "$base" "feature/$slug" "$proj" || return 1        # A, B, C, D
  [ -z "$(git -C "$wt" status --porcelain)" ] || return 1          # E
  local entrega
  entrega="$(git show "feature/$slug:docs/entregas/$slug/ENTREGA.md" 2>/dev/null)" || return 1
  printf '%s\n' "$entrega" | grep -q '^estado: entregue' || return 1
  printf '%s\n' "$entrega" | grep -q '^portao: pronto'   || return 1   # F
}

# Passo 7, prova de publicação. O buildx confere, nunca republica.
prova_publicacao() { # <slug> <push_feito: true|false>
  git remote get-url origin >/dev/null 2>&1 || { [ "$2" = false ]; return; }
  git fetch -q origin 2>/dev/null
  [ "$2" = true ] || return 1
  git rev-parse --verify --quiet "refs/remotes/origin/feature/$1" >/dev/null || return 1
  [ "$(git rev-parse "feature/$1")" = "$(git rev-parse "origin/feature/$1")" ]
}

# O que o buildx lê: o commitado, nunca a worktree.
campo_commitado() { # <slug> <campo>
  git show "feature/$1:docs/entregas/$1/ENTREGA.md" 2>/dev/null |
    grep "^$2: " | head -1 | cut -d' ' -f2
}

# A worktree contradizendo o commitado é parada, não escolha.
worktree_concorda() { # <slug> <worktree>
  local commitado
  commitado="$(git show "feature/$1:docs/entregas/$1/ENTREGA.md" 2>/dev/null)" || return 1
  [ "$commitado" = "$(cat "$2/docs/entregas/$1/ENTREGA.md" 2>/dev/null)" ]
}

# §5: detecção da branch principal. Devolve o nome nu, nunca `origin/main`.
detectar_principal() {
  local ref
  ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" ||
    { git remote set-head -a origin >/dev/null 2>&1 &&
      ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"; } ||
    return 1
  printf '%s\n' "${ref#origin/}"
}

# §3: o B2 termina sincronizado — árvore limpa e HEAD igual ao remoto.
b2_fechada() { # <branch-do-projeto>
  [ -z "$(git status --porcelain)" ] || return 1
  git rev-parse --verify --quiet "refs/remotes/origin/$1" >/dev/null || return 0
  git fetch -q origin 2>/dev/null
  [ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$1")" ]
}

# §6, caminho A: a branch não pode existir quando o mapa diz `pendente`.
caminho_a_livre() { # <slug>
  ! git rev-parse --verify --quiet "refs/heads/feature/$1" >/dev/null
}

# §9: promoção de premissa, idempotente pelo PR-NN. Mesmo id com conteúdo
# diferente não é escolha: é parada.
promover_premissas() { # <arquivo-feature-local> <PREMISSAS.md global>
  local origem="$1"
  local destino="$2"
  [ -f "$origem" ] || return 0
  local linha id existente achou
  while IFS= read -r linha || [ -n "$linha" ]; do
    linha="${linha%$'\r'}"                     # comparação não depende do fim de linha
    case "$linha" in PR-*) ;; *) continue ;; esac
    id="${linha%%:*}"
    achou=nao
    while IFS= read -r existente || [ -n "$existente" ]; do
      existente="${existente%$'\r'}"
      case "$existente" in
        "$id":*) [ "$existente" = "$linha" ] || return 1; achou=sim ;;
      esac
    done < "$destino"
    [ "$achou" = sim ] || printf '%s\n' "$linha" >> "$destino"
  done < "$origem"
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
  if [ "$com_remoto" = "sim" ]; then
    git push -q -u origin main
    # O remoto de um projeto real tem HEAD apontando para a principal; é dele
    # que a detecção do §5 tira o nome.
    git -C "$p/origin.git" symbolic-ref HEAD refs/heads/main
    git remote set-head -a origin >/dev/null 2>&1
  fi
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

# A F1 abre a branch e o worktree, e nada mais: o nascimento tem de ser exato.
feature_nasce() { # feature_nasce <slug> <base_sha> <projeto>
  local slug="$1"
  local base="$2"
  local proj="$3"
  git worktree add -q -b "feature/$slug" "$TMP_RAIZ/$proj/wt-$slug" "$base" 2>/dev/null
}

# E2 BLOQUEADO: o E8 commita o registro do bloqueio e **não** publica a branch.
feature_bloqueada() { # feature_bloqueada <slug> <base_sha> <projeto>
  local slug="$1"
  local base="$2"
  local proj="$3"
  local wt="$TMP_RAIZ/$proj/wt-$slug"
  git worktree add -q -b "feature/$slug" "$wt" "$base" 2>/dev/null || return 1
  mkdir -p "$wt/docs/entregas/$slug"
  printf 'estado: bloqueado\nportao: bloqueado\npush_feito: false\n' \
    > "$wt/docs/entregas/$slug/ENTREGA.md"
  git -C "$wt" add -A
  git -C "$wt" -c user.email=t@t -c user.name=t commit -q -m "chore(mergex): registro do bloqueio"
}

# Quem publica a branch da feature é a mergex, no E6/E8. Aqui só a simulamos.
mergex_publica() { git push -q origin "feature/$1" 2>/dev/null; }

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
echo "o E8 persiste — o buildx lê o commitado, nunca a worktree"

C="$(novo_projeto p17 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_entrega ft-01 "$BASE" p17
caso "17. estado vem do commit"              "entregue" "$(campo_commitado ft-01 estado)"
caso "17. portao vem do commit"              "pronto"   "$(campo_commitado ft-01 portao)"
printf 'estado: aberto\nportao: null\n' > "$TMP_RAIZ/p17/wt-ft-01/docs/entregas/ft-01/ENTREGA.md"
caso "18. worktree contradiz o commitado: detecta" nao "$(sim_nao worktree_concorda ft-01 "$TMP_RAIZ/p17/wt-ft-01")"
caso "18. e o commitado nao muda por isso"   "entregue" "$(campo_commitado ft-01 estado)"

# E0 idempotente: a feature replanejada roda a F6 de novo e o registro é
# retomado — `criado_em` e `commits` sobrevivem.
C="$(novo_projeto p19 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_nasce ft-01 "$BASE" p19
WT="$TMP_RAIZ/p19/wt-ft-01"; mkdir -p "$WT/docs/entregas/ft-01"
printf 'estado: aberto\ncriado_em: 2026-01-01\ncommits:\n  - aaa1111\n' > "$WT/docs/entregas/ft-01/ENTREGA.md"
git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m "chore(mergex): E0"
printf 'estado: aberto\ncriado_em: 2026-01-01\ncommits:\n  - aaa1111\n  - bbb2222\n' > "$WT/docs/entregas/ft-01/ENTREGA.md"
git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m "chore(mergex): E0 retomado"
caso "19. E0 retomado preserva criado_em" "2026-01-01" "$(campo_commitado ft-01 criado_em)"
caso "19. e acumula commits, o que nao e defeito" "2" \
  "$(git show feature/ft-01:docs/entregas/ft-01/ENTREGA.md | grep -c '^  - ')"

echo
echo "E2 bloqueado — o registro existe, a publicação não"

C="$(novo_projeto p20 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_bloqueada ft-01 "$BASE" p20
caso "20. bloqueio commitado na branch"      "bloqueado" "$(campo_commitado ft-01 portao)"
git fetch -q origin 2>/dev/null
caso "20. branch nao publicada, e isso e o correto" nao \
  "$(sim_nao git rev-parse --verify --quiet refs/remotes/origin/feature/ft-01)"
caso "21. feature bloqueada nao passa nas seis provas" nao \
  "$(sim_nao provas_abcdef "$BASE" ft-01 buildx/p20 "$TMP_RAIZ/p20/wt-ft-01")"
caso "21. e o buildx nao republica para consertar"    nao "$(sim_nao prova_publicacao ft-01 false)"

echo
echo "prova de publicação — push_feito afirma o HEAD final"

C="$(novo_projeto p22 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_entrega ft-01 "$BASE" p22
mergex_publica ft-01
caso "22. push_feito com SHAs iguais: libera" sim "$(sim_nao prova_publicacao ft-01 true)"
git -C "$TMP_RAIZ/p22/wt-ft-01" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "chore(mergex): E8"
caso "23. remoto atras do HEAD final: barra"  nao "$(sim_nao prova_publicacao ft-01 true)"
mergex_publica ft-01
caso "23. publicado o final: volta a liberar" sim "$(sim_nao prova_publicacao ft-01 true)"

C="$(novo_projeto p24 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"; feature_entrega ft-01 "$BASE" p24
caso "24. push_feito false com remoto: barra" nao "$(sim_nao prova_publicacao ft-01 false)"

C="$(novo_projeto p25 nao)"; cd "$C"
BASE="$(git rev-parse HEAD)"; feature_entrega ft-01 "$BASE" p25
caso "25. sem remoto: prova de publicacao e n/a" sim "$(sim_nao prova_publicacao ft-01 false)"

echo
echo "as seis provas"

C="$(novo_projeto p26 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_entrega ft-01 "$BASE" p26
WT="$TMP_RAIZ/p26/wt-ft-01"
caso "26. caminho feliz: A a F passam" sim "$(sim_nao provas_abcdef "$BASE" ft-01 buildx/p26 "$WT")"
printf 'sobra fora do plano\n' > "$WT/src/sobra.ts"
caso "27. prova E, arvore da feature suja: barra" nao "$(sim_nao provas_abcdef "$BASE" ft-01 buildx/p26 "$WT")"
rm -f "$WT/src/sobra.ts"
printf 'sujeira\n' > "$C/rascunho.md"
caso "28. prova D, arvore de controle suja: barra" nao "$(sim_nao provas_abcdef "$BASE" ft-01 buildx/p26 "$WT")"
rm -f "$C/rascunho.md"

echo
echo "B2 termina sincronizado, e a principal remota existe"

C="$(novo_projeto p29 sim)"; cd "$C"
caso "29. B2 fechada: arvore limpa e HEAD == origin" sim "$(sim_nao b2_fechada buildx/p29)"
printf 'artefato da fundacao esquecido\n' > docs/projeto/RASCUNHO.md
caso "30. fundacao com artefato nao commitado: nao fechou" nao "$(sim_nao b2_fechada buildx/p29)"
git add -A; git commit -q -m "chore(buildx): fundacao"
caso "30. commitado mas nao empurrado: ainda nao fechou"   nao "$(sim_nao b2_fechada buildx/p29)"
git push -q origin buildx/p29
caso "30. um unico push fecha a fundacao"                  sim "$(sim_nao b2_fechada buildx/p29)"

caso "31. a principal existe no remoto" sim \
  "$(sim_nao git rev-parse --verify --quiet refs/remotes/origin/main)"
caso "32. deteccao devolve o nome nu"   "main" "$(detectar_principal)"
ORIGIN_MAIN="$(git rev-parse origin/main)"
# baseline só é publicada se `git ls-remote --heads origin <principal>` vier vazia
caso "33. principal ja existe: nada a publicar" nao \
  "$(sim_nao test -z "$(git ls-remote --heads origin main)")"
git fetch -q origin
caso "33. e a principal remota permanece congelada" "$ORIGIN_MAIN" "$(git rev-parse origin/main)"

echo
echo "caminho A — feature nova — e caminho B — retomada"

C="$(novo_projeto p34 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
caso "34. mapa pendente e branch inexistente: segue" sim "$(sim_nao caminho_a_livre ft-01)"
feature_nasce ft-01 "$BASE" p34
caso "35. mapa pendente com branch existente: inconsistencia" nao "$(sim_nao caminho_a_livre ft-01)"
caso "36. nascimento exato: tip == BASE_SHA" "$BASE" "$(git rev-parse feature/ft-01)"
printf 'codigo\n' > "$TMP_RAIZ/p34/wt-ft-01/src.ts"
git -C "$TMP_RAIZ/p34/wt-ft-01" add -A
git -C "$TMP_RAIZ/p34/wt-ft-01" -c user.email=t@t -c user.name=t commit -q -m "feat: E1"
caso "37. retomada: ancestralidade vale" sim "$(sim_nao git merge-base --is-ancestor "$BASE" feature/ft-01)"
caso "37. e igualdade de tip nao e exigida" nao "$(sim_nao test "$BASE" = "$(git rev-parse feature/ft-01)")"
caso "38. recriar a branch existente falha" nao "$(sim_nao git branch feature/ft-01 "$BASE")"

echo
echo "premissas da F2 — nascem na feature, são promovidas depois do ff"

C="$(novo_projeto p39 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
printf '# Premissas\n' > docs/projeto/PREMISSAS.md
git add -A; git commit -q -m "chore(buildx): premissas do B1"; git push -q origin buildx/p39
BASE="$(git rev-parse HEAD)"
feature_nasce ft-01 "$BASE" p39
WT="$TMP_RAIZ/p39/wt-ft-01"
mkdir -p "$WT/docs/sprintx/features/ft-01" "$WT/docs/entregas/ft-01" "$WT/src"
printf 'status: pendente_promocao\nPR-07: sessao expira em 30 minutos\n' \
  > "$WT/docs/sprintx/features/ft-01/00-DECISOES.md"
printf 'codigo\n' > "$WT/src/ft-01.ts"
printf 'estado: entregue\nportao: pronto\n' > "$WT/docs/entregas/ft-01/ENTREGA.md"
git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m "feat: ft-01"
caso "39. premissa da F2 nao suja o CONTROL antes do ff" nao \
  "$(sim_nao grep -q 'PR-07' docs/projeto/PREMISSAS.md)"
caso "39. CONTROL segue limpo na janela"                 sim "$(sim_nao test -z "$(git status --porcelain)")"
integrar feature/ft-01
PREM="$C/docs/sprintx/features/ft-01/00-DECISOES.md"
caso "40. promocao depois do ff"          sim "$(sim_nao promover_premissas "$PREM" docs/projeto/PREMISSAS.md)"
caso "40. e a premissa chegou ao global"  sim "$(sim_nao grep -q '^PR-07:' docs/projeto/PREMISSAS.md)"
caso "41. promover de novo e no-op"       sim "$(sim_nao promover_premissas "$PREM" docs/projeto/PREMISSAS.md)"
caso "41. sem duplicar o PR-NN"           "1" "$(grep -c '^PR-07:' docs/projeto/PREMISSAS.md)"
printf 'PR-07: sessao expira em 8 horas\n' > "$TMP_RAIZ/p39/divergente.md"
caso "42. mesmo PR-NN com conteudo diferente: barra" nao \
  "$(sim_nao promover_premissas "$TMP_RAIZ/p39/divergente.md" docs/projeto/PREMISSAS.md)"
caso "42. e nao escolhe uma das versoes"             "1" "$(grep -c '^PR-07:' docs/projeto/PREMISSAS.md)"

C="$(novo_projeto p43 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
printf '# Premissas\n' > docs/projeto/PREMISSAS.md
git add -A; git commit -q -m "chore(buildx): premissas do B1"; git push -q origin buildx/p43
BASE="$(git rev-parse HEAD)"
feature_bloqueada ft-01 "$BASE" p43
WT="$TMP_RAIZ/p43/wt-ft-01"
mkdir -p "$WT/docs/sprintx/features/ft-01"
printf 'status: pendente_promocao\nPR-09: premissa de feature bloqueada\n' \
  > "$WT/docs/sprintx/features/ft-01/00-DECISOES.md"
git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m "docs: decisoes"
# Nada no mecanismo impediria o fast-forward desta branch — ela descende da base
# como qualquer outra. Quem a barra é a prova F, e é por isso que ela existe.
caso "43. bloqueada: a prova F barra"        nao \
  "$(sim_nao provas_abcdef "$BASE" ft-01 buildx/p43 "$WT")"
caso "43. logo ela nao e integrada"          nao "$(sim_nao git merge-base --is-ancestor feature/ft-01 HEAD)"
caso "43. e a premissa dela nao e promovida" nao "$(sim_nao grep -q 'PR-09' docs/projeto/PREMISSAS.md)"

echo
echo "B6 — ciclo não-final e fechamento definitivo"

C="$(novo_projeto p44 sim)"; cd "$C"
mkdir -p docs/projeto
printf 'veredito: reprovado\n' > docs/projeto/VALIDACAO.md
git add -A; git commit -q -m "chore(buildx): validacao do ciclo 1"
caso "44. ciclo nao-final: Branch base continua a do projeto" \
  "Branch base: buildx/p44" "$(grep '^Branch base:' docs/stack/CONVENCOES.md)"
caso "44. e nao ha PR-FINAL num ciclo que continua" nao \
  "$(sim_nao test -f docs/projeto/PR-FINAL.md)"

# Fechamento final: o PR-FINAL.md é escrito **antes** do commit que o inclui.
printf 'veredito: aprovado\n' > docs/projeto/VALIDACAO.md
printf '# Relatorio\n' > docs/projeto/RELATORIO.md
printf '# PR final\n' > docs/projeto/PR-FINAL.md
PRINCIPAL="$(detectar_principal)"
printf 'Branch principal: %s\nBranch base: %s\n' "$PRINCIPAL" "$PRINCIPAL" > docs/stack/CONVENCOES.md
git add -A; git commit -q -m "chore(buildx): fechamento do projeto"
caso "45. o PR-FINAL esta no commit do fechamento" sim \
  "$(sim_nao git cat-file -e HEAD:docs/projeto/PR-FINAL.md)"
caso "45. a Branch base restaurada tambem"  "Branch base: main" \
  "$(git show HEAD:docs/stack/CONVENCOES.md | grep '^Branch base:')"
git push -q origin buildx/p44
caso "45. e o fechamento termina sincronizado" sim "$(sim_nao b2_fechada buildx/p44)"

echo
echo "---------------------------------------------"
printf '%d ok, %d falha(s)\n' "$OK" "$FALHOU"
[ "$FALHOU" = "0" ]
