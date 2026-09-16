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
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
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

# A premissa pendente mora em arquivo do buildx, dentro da pasta canônica da
# feature: docs/sprintx/features/<slug>/BUILDX-PREMISSAS.md. O 00-DECISOES.md é
# da sprintx e pode ser regerado por ela — por isso a premissa não mora lá.
escreve_premissa() { # <arquivo> <PR-NN> <decisao>
  mkdir -p "$(dirname "$1")"
  [ -f "$1" ] || printf '# Premissas pendentes do BuildX\n' > "$1"
  cat >> "$1" <<EOF

### $2 — Politica de expiracao da sessao

- origem: f2_autonoma
- decisao: $3
- justificativa: PR-02 e CONVENCOES.md estabelecem sessao stateless
- o_que_invalida: requisito explicito de sessao permanente
- status: pendente_promocao
EOF
}

premissa_ids() { awk '{ sub(/\r$/, "") } /^### PR-/ { print $2 }' "$1" 2>/dev/null; }

premissa_bloco() { # <arquivo> <PR-NN>
  awk -v id="$2" '{ sub(/\r$/, "") } /^### / { dentro = ($2 == id) } dentro && NF { print }' "$1"
}

# O `status` é marca de feature, não conteúdo da premissa: a comparação de
# idempotência é sobre o que a premissa afirma.
premissa_corpo() { premissa_bloco "$1" "$2" | grep -v '^- status: '; }

# §9: promoção depois do ff, idempotente pelo PR-NN. Mesmo id com conteúdo
# diferente não é escolha: é parada.
promover_premissas() { # <BUILDX-PREMISSAS.md da feature> <PREMISSAS.md global>
  local origem="$1"
  local destino="$2"
  [ -f "$origem" ] || return 0
  local id corpo
  for id in $(premissa_ids "$origem"); do
    premissa_bloco "$origem" "$id" | grep -q '^- status: pendente_promocao$' || continue
    corpo="$(premissa_corpo "$origem" "$id")"
    if grep -q "^### $id " "$destino" 2>/dev/null; then
      [ "$(premissa_corpo "$destino" "$id")" = "$corpo" ] || return 1
    else
      printf '\n%s\n' "$corpo" >> "$destino"
    fi
  done
}

# Na retomada: o arquivo existente vale inteiro.
premissa_estado() { # <arquivo> <PR-NN> <arquivo-com-o-bloco-desejado> -> ausente|reusar|conflito
  if ! grep -q "^### $2 " "$1" 2>/dev/null; then
    echo ausente
  elif [ "$(premissa_corpo "$1" "$2")" = "$(premissa_corpo "$3" "$2")" ]; then
    echo reusar
  else
    echo conflito
  fi
}

# O item de decisão do `kind: decisoes` da sprintx aceita seis chaves, e só.
# O buildx responde no formato que ela já entende: proveniência em `motivo`.
CHAVES_DECISAO="id decisao alternativa_descartada motivo status bloqueante"

chaves_do_item() { # <00-DECISOES.md> -> chaves usadas nos itens, sem repetir
  awk '{ sub(/\r$/, "") }
       /^decisoes:/ { dentro = 1; next }
       dentro && /^[^ ]/ { dentro = 0 }
       dentro {
         linha = $0
         sub(/^ *- /, "", linha); sub(/^ +/, "", linha)
         if (match(linha, /^[a-z_]+:/)) print substr(linha, 1, RLENGTH - 1)
       }' "$1" | sort -u
}

chave_extra() { # <00-DECISOES.md> -> chaves fora do contrato da sprintx
  local k
  for k in $(chaves_do_item "$1"); do
    case " $CHAVES_DECISAO " in *" $k "*) ;; *) printf '%s\n' "$k" ;; esac
  done
}

motivo_yaml() { # <00-DECISOES.md> <D-NN>
  awk -v id="$2" '{ sub(/\r$/, "") }
       $0 ~ ("^ *- id: " id "$") { achou = 1; next }
       achou && /^ *- id:/ { achou = 0 }
       achou && /^ *motivo: / { sub(/^ *motivo: /, ""); print; achou = 0 }' "$1"
}

motivo_prosa() { # <00-DECISOES.md> <D-NN>
  awk -F' \\| ' -v id="$2" '{ sub(/\r$/, "") } $1 == id { print $4 }' "$1"
}

# A sprintx declara: decisão SEM o marcador é lida como confirmada pelo usuário.
eh_hipotese() { case "$1" in "(HIPOTESE)"*) return 0 ;; *) return 1 ;; esac; }

# Para a mergex, a pasta da feature inteira é artefato de método; o
# PREMISSAS.md do projeto seria arquivo de produto fora do plano (V9).
artefato_de_metodo() { # <caminho> <slug>
  case "$1" in "docs/sprintx/features/$2/"*) return 0 ;; *) return 1 ;; esac
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
echo "premissas do buildx — arquivo próprio, feature-local, promovido depois do ff"

C="$(novo_projeto p39 sim)"; cd "$C"
printf '# Premissas\n' > docs/projeto/PREMISSAS.md
git add -A; git commit -q -m "chore(buildx): premissas do B1"; git push -q origin buildx/p39
BASE="$(git rev-parse HEAD)"
feature_nasce ft-01 "$BASE" p39
WT="$TMP_RAIZ/p39/wt-ft-01"
REL="docs/sprintx/features/ft-01/BUILDX-PREMISSAS.md"
escreve_premissa "$WT/$REL" PR-07 "Sessao expira apos 8 horas"
# A decisão resultante vai para o arquivo da sprintx, citando a fonte.
mkdir -p "$WT/docs/sprintx/features/ft-01" "$WT/docs/entregas/ft-01" "$WT/src"
printf -- '---\nkind: decisoes\n---\n\nD-01 | sessao de 8h | sessao permanente | (HIPOTESE) fonte: BUILDX-PREMISSAS.md#PR-07\n' \
  > "$WT/docs/sprintx/features/ft-01/00-DECISOES.md"
printf 'codigo\n' > "$WT/src/ft-01.ts"
printf 'estado: entregue\nportao: pronto\n' > "$WT/docs/entregas/ft-01/ENTREGA.md"
git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m "feat: ft-01"

caso "39. a premissa nasce no arquivo do buildx" sim "$(sim_nao test -f "$WT/$REL")"
caso "39. e nao no arquivo da sprintx"           nao \
  "$(sim_nao grep -q '^### PR-07 ' "$WT/docs/sprintx/features/ft-01/00-DECISOES.md")"
caso "39. o global nao e tocado na janela"       nao "$(sim_nao grep -q 'PR-07' docs/projeto/PREMISSAS.md)"
caso "39. e o CONTROL segue limpo"               sim "$(sim_nao test -z "$(git status --porcelain)")"

# A sprintx regera o 00-DECISOES.md quando a F2 roda de novo. A premissa
# sobrevive exatamente por não morar lá.
printf -- '---\nkind: decisoes\n---\n\nD-01 | regerado do zero pela F2 | - | -\n' \
  > "$WT/docs/sprintx/features/ft-01/00-DECISOES.md"
caso "40. 00-DECISOES regerado do zero: a premissa sobrevive" sim "$(sim_nao test -f "$WT/$REL")"
caso "40. com o mesmo PR-NN e o mesmo conteudo" "reusar" \
  "$(premissa_estado "$WT/$REL" PR-07 "$WT/$REL")"

# Retomada: o desejado é idêntico ao gravado -> reusa; divergente -> para.
escreve_premissa "$TMP_RAIZ/p39/desejado.md" PR-07 "Sessao expira apos 8 horas"
caso "41. retomada reutiliza o mesmo PR-NN"  "reusar" \
  "$(premissa_estado "$WT/$REL" PR-07 "$TMP_RAIZ/p39/desejado.md")"
escreve_premissa "$TMP_RAIZ/p39/divergente.md" PR-07 "Sessao expira apos 30 minutos"
caso "42. mesmo PR-NN divergente: conflito"  "conflito" \
  "$(premissa_estado "$WT/$REL" PR-07 "$TMP_RAIZ/p39/divergente.md")"

# Replanejamento: CONTROL não se mexe e o arquivo permanece.
git -C "$WT" add -A
git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m "docs: F2 reexecutada"
caso "43. replanejamento preserva o arquivo"    sim "$(sim_nao test -f "$WT/$REL")"
caso "43. e o PR-NN continua o mesmo"           "PR-07" "$(premissa_ids "$WT/$REL")"
caso "43. com CONTROL parada em BASE_SHA"       "$BASE" "$(git rev-parse HEAD)"

integrar feature/ft-01
caso "44. o ff leva o arquivo para o CONTROL"   sim "$(sim_nao test -f "$C/$REL")"
caso "45. promocao depois do ff"                sim "$(sim_nao promover_premissas "$C/$REL" docs/projeto/PREMISSAS.md)"
caso "45. a premissa chegou ao global"          sim "$(sim_nao grep -q '^### PR-07 ' docs/projeto/PREMISSAS.md)"
caso "45. sem o status, que e marca de feature" nao \
  "$(sim_nao grep -q 'pendente_promocao' docs/projeto/PREMISSAS.md)"
caso "45. promover de novo e no-op"             sim "$(sim_nao promover_premissas "$C/$REL" docs/projeto/PREMISSAS.md)"
caso "45. sem duplicar o PR-NN"                 "1" "$(grep -c '^### PR-07 ' docs/projeto/PREMISSAS.md)"
caso "45. nada e escrito de volta na feature"   sim \
  "$(sim_nao grep -q '^- status: pendente_promocao$' "$C/$REL")"
caso "45. divergente no global: barra"          nao \
  "$(sim_nao promover_premissas "$TMP_RAIZ/p39/divergente.md" docs/projeto/PREMISSAS.md)"
caso "45. e nao escolhe uma das versoes"        "1" "$(grep -c '^### PR-07 ' docs/projeto/PREMISSAS.md)"

C="$(novo_projeto p46 sim)"; cd "$C"
printf '# Premissas\n' > docs/projeto/PREMISSAS.md
git add -A; git commit -q -m "chore(buildx): premissas do B1"; git push -q origin buildx/p46
BASE="$(git rev-parse HEAD)"
feature_bloqueada ft-01 "$BASE" p46
WT="$TMP_RAIZ/p46/wt-ft-01"
escreve_premissa "$WT/$REL" PR-09 "Premissa de feature bloqueada"
git -C "$WT" add -A; git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m "docs: premissa pendente"
# Nada no mecanismo impediria o fast-forward desta branch — ela descende da base
# como qualquer outra. Quem a barra é a prova F, e é por isso que ela existe.
caso "46. bloqueada: a prova F barra"        nao \
  "$(sim_nao provas_abcdef "$BASE" ft-01 buildx/p46 "$WT")"
caso "46. logo ela nao e integrada"          nao "$(sim_nao git merge-base --is-ancestor feature/ft-01 HEAD)"
caso "46. e a premissa dela nao e promovida" nao "$(sim_nao grep -q 'PR-09' docs/projeto/PREMISSAS.md)"
caso "46. mas fica legivel como evidencia"   "PR-09" \
  "$(git show "feature/ft-01:$REL" | awk '/^### PR-/ { print $2 }')"

caso "47. o arquivo e artefato de metodo"    sim "$(sim_nao artefato_de_metodo "$REL" ft-01)"
caso "47. o PREMISSAS global seria produto"  nao \
  "$(sim_nao artefato_de_metodo docs/projeto/PREMISSAS.md ft-01)"

echo
echo "B6 — ciclo não-final e fechamento definitivo"

C="$(novo_projeto p48 sim)"; cd "$C"
mkdir -p docs/projeto
printf 'veredito: reprovado\n' > docs/projeto/VALIDACAO.md
git add -A; git commit -q -m "chore(buildx): validacao do ciclo 1"
caso "48. ciclo nao-final: Branch base continua a do projeto" \
  "Branch base: buildx/p48" "$(grep '^Branch base:' docs/stack/CONVENCOES.md)"
caso "48. e nao ha PR-FINAL num ciclo que continua" nao \
  "$(sim_nao test -f docs/projeto/PR-FINAL.md)"

# Fechamento final: o PR-FINAL.md é escrito **antes** do commit que o inclui.
printf 'veredito: aprovado\n' > docs/projeto/VALIDACAO.md
printf '# Relatorio\n' > docs/projeto/RELATORIO.md
printf '# PR final\n' > docs/projeto/PR-FINAL.md
PRINCIPAL="$(detectar_principal)"
printf 'Branch principal: %s\nBranch base: %s\n' "$PRINCIPAL" "$PRINCIPAL" > docs/stack/CONVENCOES.md
git add -A; git commit -q -m "chore(buildx): fechamento do projeto"
caso "49. o PR-FINAL esta no commit do fechamento" sim \
  "$(sim_nao git cat-file -e HEAD:docs/projeto/PR-FINAL.md)"
caso "49. a Branch base restaurada tambem"  "Branch base: main" \
  "$(git show HEAD:docs/stack/CONVENCOES.md | grep '^Branch base:')"
git push -q origin buildx/p48
caso "49. e o fechamento termina sincronizado" sim "$(sim_nao b2_fechada buildx/p48)"

echo
echo "o contrato vivo não pede nada às skills irmãs"

VIVOS="$REPO/.claude/skills/buildx/SKILL.md $REPO/.claude/skills/buildx/references $REPO/.claude/commands $REPO/.opencode/commands $REPO/AGENTS.md $REPO/README.md"
caso "50. nenhuma regra viva guarda estado do buildx no 00-DECISOES" nao \
  "$(sim_nao grep -rqE '00-DECISOES[^|]*pendente_promocao|pendente_promocao[^|]*00-DECISOES' $VIVOS)"
caso "50. nem manda reparar secao que a sprintx apagou" nao \
  "$(sim_nao grep -rqiE 'reescreva.{0,80}(secao|seção)|(secao|seção).{0,40}sumiu' $VIVOS)"
caso "51. nenhuma regra viva exige mudar a sprintx ou a mergex" nao \
  "$(sim_nao grep -rqiE '(altere|mude|ajuste|modifique) (a |o )?(sprintx|mergex)' $VIVOS)"
caso "52. nenhuma regra viva manda gravar respondido_por" nao \
  "$(sim_nao grep -rqi 'respondido_por' $VIVOS)"

echo
echo 'proveniência da decisão — no campo motivo, dentro do schema da sprintx'

DEC="$TMP_RAIZ/00-DECISOES.md"
cat > "$DEC" <<'FIM'
---
expx_schema: 1
expx_tool: sprintx
kind: decisoes
trabalho_id: ft-01
origem_buildx: loja-online
feature_id: FT-01
decisoes:
  - id: D-01
    decisao: Sessao expira apos 8 horas
    alternativa_descartada: Sessao permanente
    motivo: (HIPOTESE) fonte: BUILDX-PREMISSAS.md#PR-07 — convencao escolhida pelo BuildX para manter a execucao reversivel
    status: fechada
    bloqueante: false
  - id: D-02
    decisao: Prefixo do pedido e SEQ-
    alternativa_descartada: Prefixo ID-
    motivo: Fonte: PROJETO.md#descricao-original — declarado pelo usuario no briefing BuildX
    status: fechada
    bloqueante: false
  - id: D-03
    decisao: Camada de servico entre rota e repositorio
    alternativa_descartada: Rota chamando o repositorio
    motivo: (HIPOTESE) fonte: CONVENCOES.md#camadas — decidido_pelo_buildx no B2
    status: fechada
    bloqueante: false
  - id: D-04
    decisao: Sessao guardada em cookie httpOnly
    alternativa_descartada: localStorage
    motivo: (HIPOTESE) fonte: docs/projeto/PREMISSAS.md#PR-03 — premissa tecnica registrada no B1
    status: fechada
    bloqueante: false
---

D-01 | Sessao expira apos 8 horas | Sessao permanente | (HIPOTESE) fonte: BUILDX-PREMISSAS.md#PR-07 — convencao escolhida pelo BuildX para manter a execucao reversivel
D-02 | Prefixo do pedido e SEQ- | Prefixo ID- | Fonte: PROJETO.md#descricao-original — declarado pelo usuario no briefing BuildX
D-03 | Camada de servico entre rota e repositorio | Rota chamando o repositorio | (HIPOTESE) fonte: CONVENCOES.md#camadas — decidido_pelo_buildx no B2
D-04 | Sessao guardada em cookie httpOnly | localStorage | (HIPOTESE) fonte: docs/projeto/PREMISSAS.md#PR-03 — premissa tecnica registrada no B1
FIM

caso "53. a decisao do buildx cabe no schema, sem chave extra" "" "$(chave_extra "$DEC")"
caso "53. e usa as seis chaves do contrato" \
  "alternativa_descartada bloqueante decisao id motivo status" "$(chaves_do_item "$DEC" | tr '\n' ' ' | sed 's/ $//')"
caso "53. respondido_por nao aparece"        nao "$(sim_nao grep -q 'respondido_por' "$DEC")"

# CASO B — premissa assumida pelo buildx, feature-local e global.
caso "54. premissa feature-local: cita o PR-NN"  sim \
  "$(sim_nao grep -q 'BUILDX-PREMISSAS.md#PR-07' <<< "$(motivo_yaml "$DEC" D-01)")"
caso "54. e e hipotese"                          sim "$(sim_nao eh_hipotese "$(motivo_yaml "$DEC" D-01)")"
caso "55. premissa global: cita o PR-NN"         sim \
  "$(sim_nao grep -q 'PREMISSAS.md#PR-03' <<< "$(motivo_yaml "$DEC" D-04)")"
caso "55. e e hipotese"                          sim "$(sim_nao eh_hipotese "$(motivo_yaml "$DEC" D-04)")"

# CASO A — declaração direta do usuário: houve confirmação humana.
caso "56. declaracao do usuario nao e hipotese"  nao "$(sim_nao eh_hipotese "$(motivo_yaml "$DEC" D-02)")"
caso "56. mas cita a fonte nominalmente"         sim \
  "$(sim_nao grep -q 'PROJETO.md#descricao-original' <<< "$(motivo_yaml "$DEC" D-02)")"

# CASO C — convenção que o próprio buildx decidiu no B2.
caso "57. convencao decidida pelo buildx e hipotese" sim "$(sim_nao eh_hipotese "$(motivo_yaml "$DEC" D-03)")"
caso "57. e cita a regra do CONVENCOES"              sim \
  "$(sim_nao grep -q 'CONVENCOES.md#camadas' <<< "$(motivo_yaml "$DEC" D-03)")"

for d in D-01 D-02 D-03 D-04; do
  caso "58. YAML e prosa dizem o mesmo motivo em $d" \
    "$(motivo_yaml "$DEC" "$d")" "$(motivo_prosa "$DEC" "$d")"
done

caso "59. a ponte origem_buildx continua no frontmatter" sim "$(sim_nao grep -q '^origem_buildx: ' "$DEC")"
caso "59. e feature_id tambem"                           sim "$(sim_nao grep -q '^feature_id: ' "$DEC")"

# Replanejamento: a sprintx regera o arquivo e o buildx o reescreve no mesmo
# formato. Nenhum campo estrangeiro reaparece.
sed -i 's/^    decisao: Sessao expira apos 8 horas$/    decisao: Sessao expira apos 4 horas/' "$DEC"
caso "60. arquivo regerado nao reintroduz respondido_por" nao "$(sim_nao grep -q 'respondido_por' "$DEC")"
caso "60. nem qualquer outra chave extra"                 ""  "$(chave_extra "$DEC")"
caso "60. e a fonte continua citada"                      sim \
  "$(sim_nao grep -q 'BUILDX-PREMISSAS.md#PR-07' <<< "$(motivo_yaml "$DEC" D-01)")"

echo
echo "---------------------------------------------"
printf '%d ok, %d falha(s)\n' "$OK" "$FALHOU"
[ "$FALHOU" = "0" ]
