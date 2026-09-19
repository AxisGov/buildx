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
# Desde o P0.1 ele também protege o consumo do planejamento durável da sprintx:
# o orçamento da F5 declarado pelo buildx e contado pela sprintx, o CHECKPOINT
# pendente que nada decide, o portão terminal pré-F6 que só move a CONTROL com
# evidência commitada, a máquina de pendências do RECURSAO.md, a feature
# sucessora, a reserva de PR-NN e a retomada sobre checkpoints.
#
# Não depende de rede, de jq, nem de nenhum dos repositórios reais do produto.
# Os cenários da sprintx usam a skill REAL, no SHA fixado abaixo, extraída com
# `git archive` para o diretório temporário — a irmã nunca é alterada. Sem o
# repositório da sprintx, esses cenários são PULADOS e contados como pulo.
#
# Uso: bash scripts/ci/integracao.sh
#      BLOCOS="p0 x1" bash scripts/ci/integracao.sh   # só os blocos nomeados
#      SPRINTX_REPO=/caminho/da/sprintx bash scripts/ci/integracao.sh

set -uo pipefail

OK=0; FALHOU=0; PULOS=0
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

# bloco <nome> — sem BLOCOS, todos rodam; com BLOCOS, só os nomeados.
bloco() {
  [ -z "${BLOCOS:-}" ] && return 0
  case " $BLOCOS " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

pulo() { PULOS=$((PULOS+1)); printf '  PULO  %s\n' "$1"; }

# ---------------------------------------------------------------------------
# A sprintx real, no SHA fixo do contrato P0.1
# ---------------------------------------------------------------------------

SPRINTX_SHA_FIXO=a4f5495ad8454c548a2e5aa6b07c6006a9e1d7df
SPRINTX_REPO="${SPRINTX_REPO:-$REPO/../sprintx}"
PLANEJAMENTO=""
if git -c safe.directory='*' -C "$SPRINTX_REPO" cat-file -e "$SPRINTX_SHA_FIXO^{commit}" 2>/dev/null; then
  mkdir -p "$TMP_RAIZ/sprintx"
  if git -c safe.directory='*' -C "$SPRINTX_REPO" archive "$SPRINTX_SHA_FIXO" .claude/skills/sprintx |
       tar -x -C "$TMP_RAIZ/sprintx" 2>/dev/null; then
    PLANEJAMENTO="$TMP_RAIZ/sprintx/.claude/skills/sprintx/scripts/planejamento.sh"
    [ -f "$PLANEJAMENTO" ] || PLANEJAMENTO=""
  fi
fi

com_sprintx() { # com_sprintx <cenario> — pula, e conta o pulo, sem a sprintx real
  [ -n "$PLANEJAMENTO" ] && return 0
  pulo "$1: sprintx $SPRINTX_SHA_FIXO indisponivel em $SPRINTX_REPO"
  return 1
}

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

# O valor de uma chave `campo: valor` de um registro, lido do stdin.
campo_registro() { tr -d '\r' | grep "^$1: " | head -1 | cut -d' ' -f2; }

# O que o buildx lê: o commitado, nunca a worktree.
campo_commitado() { # <slug> <campo>
  git show "feature/$1:docs/entregas/$1/ENTREGA.md" 2>/dev/null | campo_registro "$2"
}

# A entrega terminal da feature, pelo ENTREGA.md COMMITADO no HEAD dela (D-35).
# Terminais são as duas combinações que o E8 da mergex grava ao fechar; `aberto`
# é entrega em curso. Qualquer outra coisa é inconsistência — ninguém infere
# bloqueio de um registro que não o declara inteiro.
entrega_terminal() { # <slug> -> ausente | aberta | entregue | bloqueada | invalida
  local e k
  e="$(git show "feature/$1:docs/entregas/$1/ENTREGA.md" 2>/dev/null)" || { echo ausente; return; }   # [M18]
  for k in estado portao; do
    [ "$(printf '%s\n' "$e" | tr -d '\r' | grep -c "^$k: ")" = 1 ] || { echo invalida; return; }
  done
  case "$(printf '%s\n' "$e" | campo_registro estado):$(printf '%s\n' "$e" | campo_registro portao)" in
    entregue:pronto)                            echo entregue ;;
    bloqueado:bloqueado)                        echo bloqueada ;;
    aberto:pronto|aberto:bloqueado|aberto:null) echo aberta ;;
    *)                                          echo invalida ;;             # [M19]
  esac
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
# P0.1 — o planejamento durável da sprintx, consumido pelo buildx
# ---------------------------------------------------------------------------

# O orçamento que o briefing de toda feature declara. A F1 da sprintx o repassa
# a `planejamento.sh criar <slug> 3 buildx`; dali em diante a contagem é dela.
ORCAMENTO_F5_MAX=3
ORCAMENTO_F5_POR=buildx

briefing_orcamento() {
  printf 'max_reprovacoes_f5: %s\norcamento_declarado_por: %s\n' "$ORCAMENTO_F5_MAX" "$ORCAMENTO_F5_POR"
}

# sprintx <worktree> <args...> — o script real, rodado de dentro da área de trabalho.
sprintx() {
  local wt="$1"; shift
  ( cd "$wt" && bash "$PLANEJAMENTO" "$@" ) 2>/dev/null
}

chave() { # chave <saida chave=valor> <chave>
  printf '%s\n' "$1" | tr -d '\r' | awk -v k="$2" 'index($0, k "=") == 1 { print substr($0, length(k) + 2); exit }'
}

# O orçamento que a F1 persistiu, lido do COMMITADO: é a prova de que a sprintx
# recebeu o teto do buildx, e não um teto inventado ou nenhum.
orcamento_confere() { # <slug>
  local p="docs/sprintx/features/$1/00-PLANEJAMENTO.md" arq
  arq="$(git show "feature/$1:$p" 2>/dev/null | tr -d '\r')" || return 1
  printf '%s\n' "$arq" | grep -qx "max_reprovacoes_f5: $ORCAMENTO_F5_MAX" || return 1
  printf '%s\n' "$arq" | grep -qx "orcamento_declarado_por: $ORCAMENTO_F5_POR"
}

# O que o buildx faz com a resposta de `planejamento.sh fase`. Ele não abre o
# 00-PLANEJAMENTO.md para decidir, não conta rodada e não lê prosa: a sprintx é
# a dona da interpretação, e a saída dela é a única entrada desta decisão.
buildx_acao() { # <worktree> <slug> -> acao
  local saida fase estado fonte persist
  saida="$(sprintx "$1" fase "$2")"                                       # [M10]
  fase="$(chave "$saida" fase)"; estado="$(chave "$saida" estado)"
  fonte="$(chave "$saida" fonte)"; persist="$(chave "$saida" persistencia)"
  case "$fase" in
    CHECKPOINT) echo completar_checkpoint; return ;;                      # [M1]
    F1|F2) [ "$estado" = null ] && { echo "continuar_$(printf '%s' "$fase" | tr F f)"; return; } ;;
  esac
  [ "$fonte" = planejamento ] && [ "$persist" = duravel ] || { echo parar; return; }
  case "$fase:$estado" in
    F3:aguardando_f3|F3:replanejar) echo continuar_f3 ;;
    F4:aguardando_f4)               echo continuar_f4 ;;
    F5:aguardando_f5)               echo continuar_f5 ;;
    F6:aprovado)                    echo f6 ;;
    PARAR:orcamento_esgotado)       echo terminal_pre_f6 ;;
    *)                              echo parar ;;
  esac
}

# Até a F6, tudo que a branch da feature carrega à frente de BASE_SHA são
# checkpoints da sprintx: commits com o trailer `Planejamento: checkpoint` e
# paths só dentro da pasta da feature. Qualquer outra coisa é produto — ou
# trabalho que ninguém auditou — antes da hora.
sem_produto_pre_f6() { # <base_sha> <slug>
  local p c
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in "docs/sprintx/features/$2/"*) ;; *) return 1 ;; esac      # [M3]
  done <<EOF
$(git -c core.quotepath=false log --format= --name-only "$1..feature/$2")
EOF
  for c in $(git rev-list "$1..feature/$2"); do
    git log -1 --format=%B "$c" | tr -d '\r' | grep -qx 'Planejamento: checkpoint' || return 1
  done
}

# Portão terminal pré-F6, prova F: o terminal está no HEAD da feature.
prova_f_terminal_commitado() { # <slug>
  git show "feature/$1:docs/sprintx/features/$1/00-PLANEJAMENTO.md" 2>/dev/null |   # [M2]
    tr -d '\r' | grep -qx 'estado: orcamento_esgotado'
}

# Prova G: a sprintx confirma o terminal, durável — nunca CHECKPOINT.
prova_g_sprintx_terminal() { # <worktree> <slug>
  local saida; saida="$(sprintx "$1" fase "$2")"
  [ "$(chave "$saida" fase)" = PARAR ] &&
    [ "$(chave "$saida" estado)" = orcamento_esgotado ] &&
    [ "$(chave "$saida" persistencia)" = duravel ]
}

# Prova I: a auditoria da rodada terminal está no commit que registrou o terminal
# e não mudou depois dele, e é uma reprovação.
prova_i_auditoria_commitada() { # <slug>
  local pasta="docs/sprintx/features/$1" terminal
  terminal="$(git log -1 --format=%H "feature/$1" -- "$pasta/00-PLANEJAMENTO.md")"
  [ -n "$terminal" ] || return 1
  git show "$terminal:$pasta/00-PLANEJAMENTO.md" | tr -d '\r' | grep -qx 'estado: orcamento_esgotado' || return 1
  git cat-file -e "$terminal:$pasta/00-AUDITORIA.md" 2>/dev/null || return 1
  [ "$(git rev-parse "$terminal:$pasta/00-AUDITORIA.md")" = \
    "$(git rev-parse "feature/$1:$pasta/00-AUDITORIA.md" 2>/dev/null)" ] || return 1
  git show "$terminal:$pasta/00-AUDITORIA.md" | tr -d '\r' | grep -E '^VEREDITO: ' | tail -1 | grep -q '^VEREDITO: NÃO'
}

# O portão inteiro, A a I. Falhou qualquer uma: nada de escrita na CONTROL.
gate_terminal_pre_f6() { # <base_sha> <slug> <branch-do-projeto> <worktree>
  provas_pre_ff "$1" "feature/$2" "$3" || return 1             # A B C D
  [ -z "$(git -C "$4" status --porcelain)" ] || return 1       # E
  prova_f_terminal_commitado "$2" || return 1                  # F
  prova_g_sprintx_terminal "$4" "$2" || return 1               # G
  sem_produto_pre_f6 "$1" "$2" || return 1                     # H
  prova_i_auditoria_commitada "$2"                             # I
}

worktree_da_branch() { # <slug> -> caminho do worktree, se existir de fato no disco
  local caminho
  caminho="$(git worktree list --porcelain | tr -d '\r' | awk -v b="branch refs/heads/feature/$1" '
    /^worktree / { w = substr($0, 10) } $0 == b { print w; exit }')"
  [ -n "$caminho" ] && [ -d "$caminho" ] && printf '%s\n' "$caminho"
}

# Worktree perdido: reabre SOBRE A MESMA BRANCH. O `prune` só apaga o registro
# de worktree cujo diretório já não existe; nada de branch, nada de commit.
reabre_worktree() { # <slug> <caminho>
  git worktree prune
  git rev-parse --verify --quiet "refs/heads/feature/$1" >/dev/null || return 1
  git worktree add -q "$2" "feature/$1" 2>/dev/null
}

# A matriz do /buildx-retomar para uma feature, a partir do Git e da sprintx.
# A entrega terminal commitada é lida antes de qualquer linha que dependa do
# worktree ou da sprintx: um planejamento que ficou F6/aprovado não a apaga.
retomada_decide() { # <slug> <base_sha> <status-no-mapa> <branch-do-projeto> -> letra[:acao]
  local slug="$1" base="$2" status="$3" proj="$4" wt tip acao
  if git rev-parse --verify --quiet "refs/remotes/origin/$proj" >/dev/null; then
    git fetch -q origin 2>/dev/null
    [ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$proj")" ] || { echo K; return; }
  fi
  wt="$(worktree_da_branch "$slug")"
  if [ "$status" = pendente ]; then
    if git rev-parse --verify --quiet "refs/heads/feature/$slug" >/dev/null || [ -n "$wt" ]; then
      echo A; else echo livre; fi
    return
  fi
  git rev-parse --verify --quiet "refs/heads/feature/$slug" >/dev/null || { echo B:f1_nascimento; return; }
  tip="$(git rev-parse "feature/$slug")"
  if [ "$tip" != "$base" ] && git merge-base --is-ancestor "$tip" HEAD; then echo J; return; fi
  git merge-base --is-ancestor "$base" "feature/$slug" || { echo PARE; return; }
  case "$(entrega_terminal "$slug")" in                                    # [M17]
    entregue)  echo L; return ;;
    bloqueada) echo R:entrega_bloqueada; return ;;
    invalida)  echo PARE; return ;;
  esac
  if [ -z "$wt" ]; then
    if [ "$tip" = "$base" ]; then echo I; else echo H; fi
    return
  fi
  acao="$(buildx_acao "$wt" "$slug")"
  case "$acao" in
    completar_checkpoint) echo D ;;
    terminal_pre_f6)      echo G ;;
    f6)                   echo F ;;
    continuar_*)
      if [ "$tip" = "$base" ]; then echo "B:$acao"
      elif sem_produto_pre_f6 "$base" "$slug"; then echo "C:$acao"
      else echo PARE; fi ;;
    *) echo PARE ;;
  esac
}

# ---------------------------------------------------------------------------
# P0.1 — RECURSAO.md: a máquina de pendências
# ---------------------------------------------------------------------------

SECAO_AGUARDANDO='## Aguardando classificação do B5'
SECAO_RESOLUCAO='## Em resolução pela máquina'
SECAO_HUMANA='## Aberto — decisão humana'
SECAO_EXTERNO='## Aberto — recurso externo'
SECAO_RESOLVIDO='## Resolvido nos ciclos'

secoes_canonicas() {
  printf '%s\n' "$SECAO_AGUARDANDO" "$SECAO_RESOLUCAO" "$SECAO_HUMANA" "$SECAO_EXTERNO" "$SECAO_RESOLVIDO"
}

ESTADOS_PEND="aguardando_classificacao em_resolucao decisao_humana recurso_externo resolvida"
CLASSES_B5="trabalho_novo decisao_humana recurso_externo"                   # [M4]
CAMPOS_PEND="id estado gatilho classe origem ciclo evidencia causa clausula_central raiz detectada_em classificada_em regra_aplicada destino pr_reservadas resolvida_em nota"

secao_do_estado() {
  case "$1" in
    aguardando_classificacao) echo "$SECAO_AGUARDANDO" ;;
    em_resolucao)             echo "$SECAO_RESOLUCAO" ;;
    decisao_humana)           echo "$SECAO_HUMANA" ;;
    recurso_externo)          echo "$SECAO_EXTERNO" ;;
    resolvida)                echo "$SECAO_RESOLVIDO" ;;
    *) return 1 ;;
  esac
}

# As seções `## ` de um arquivo, fora de comentário HTML.
secoes_de() {
  tr -d '\r' < "$1" | awk '/^<!--/ { c = 1 } c { if (/-->/) c = 0; next } /^## / { print }'
}

# Compatibilidade: arquivo antigo pode trazer `replanejamento`. É lido, nunca escrito.
classe_lida() { case "$1" in replanejamento) echo trabalho_novo ;; *) echo "$1" ;; esac; }

# Classe de um bloco no formato antigo (`**Classe:** `x``), já traduzida.
classe_legada() { # <arquivo> <PEND-NN>
  classe_lida "$(tr -d '\r' < "$1" | awk -v id="$2" '
    /^### / { dentro = (index($0, "### " id " ") == 1) }
    dentro && /^\*\*Classe:\*\*/ { v = $0; gsub(/^\*\*Classe:\*\* *`?|`.*$/, "", v); print v; exit }')"
}

pend_campo() { # <arquivo> <PEND-NN> <campo>
  tr -d '\r' < "$1" | awk -v id="$2" -v k="- $3: " '
    /^## / || /^<!--/ { dentro = 0 }
    /^### / { dentro = (index($0, "### " id " ") == 1) }
    dentro && index($0, k) == 1 { print substr($0, length(k) + 1); exit }'
}

# pend_define — reescreve (ou acrescenta ao fim do bloco) um campo. A classe só
# aceita as três do B5, ou null: `replanejamento` não se escreve mais.
pend_define() { # <arquivo> <PEND-NN> <campo> <valor>
  if [ "$3" = classe ] && [ "$4" != null ]; then
    case " $CLASSES_B5 " in *" $4 "*) ;; *) return 1 ;; esac
  fi
  if [ "$3" = estado ]; then case " $ESTADOS_PEND " in *" $4 "*) ;; *) return 1 ;; esac; fi
  local tmp="$1.tmp"
  tr -d '\r' < "$1" | awk -v id="$2" -v k="- $3: " -v v="$4" '
    function fecha() { if (dentro && !feito) { print k v; feito = 1 } dentro = 0 }
    /^## / || /^<!--/ { fecha() }
    /^### / { fecha(); if (index($0, "### " id " ") == 1) { dentro = 1; feito = 0; visto = 0 } print; next }
    dentro && index($0, k) == 1 { print k v; feito = 1; next }
    dentro && /^- / { visto = 1 }
    dentro && visto && !feito && !NF { print k v; feito = 1 }
    { print }
    END { fecha() }' > "$tmp" && mv -f "$tmp" "$1"
}

proximo_id() { # <prefixo PEND|PR> <ids...> -> PREFIXO-NN
  local p="$1" max=0 n i; shift
  for i in "$@"; do
    n="${i#"$p"-}"; n="$(printf '%s' "$n" | sed 's/^0*//')"; n="${n:-0}"
    [ "$n" -gt "$max" ] && max="$n"
  done
  printf '%s-%02d\n' "$p" $((max + 1))
}

pend_ids() { tr -d '\r' < "$1" | awk '/^<!--/ { c = 1 } c { if (/-->/) c = 0; next } /^### PEND-/ { print $2 }'; }

# Reescreve o arquivo com as cinco seções canônicas, na ordem, e cada bloco na
# seção do seu estado. Estado desconhecido: nada é gravado.
recursao_reordena() { # <arquivo>
  local tmp="$1.tmp"
  tr -d '\r' < "$1" | awk -v s1="$SECAO_AGUARDANDO" -v s2="$SECAO_RESOLUCAO" -v s3="$SECAO_HUMANA" \
                          -v s4="$SECAO_EXTERNO" -v s5="$SECAO_RESOLVIDO" '
    function fecha() {
      if (bloco != "") {
        if (!(est in pos)) { erro = 1 }
        blocos[est] = blocos[est] bloco "\n"
      }
      bloco = ""; est = ""
    }
    BEGIN { pos["aguardando_classificacao"] = s1; pos["em_resolucao"] = s2; pos["decisao_humana"] = s3
            pos["recurso_externo"] = s4; pos["resolvida"] = s5 }
    /^<!--/ { fecha(); c = 1 }
    c { if (/-->/) c = 0; next }
    !inicio && /^## / { inicio = 1 }
    !inicio { cab = cab $0 "\n"; next }
    /^## / { fecha(); next }
    /^### PEND-/ { fecha(); bloco = $0 "\n\n"; next }
    bloco != "" && NF { if (index($0, "- estado: ") == 1) est = substr($0, 11); bloco = bloco $0 "\n"; next }
    END {
      fecha()
      if (erro) exit 1
      printf "%s", cab
      split("aguardando_classificacao em_resolucao decisao_humana recurso_externo resolvida", E, " ")
      for (i = 1; i <= 5; i++) { print pos[E[i]]; print ""; printf "%s", blocos[E[i]] }
    }' > "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$1"
}

# Um RECURSAO.md válido: as cinco seções, exatamente; todo bloco na seção do seu
# estado; classe null só aguardando; nenhuma classe fora das três; campos inteiros.
recursao_valida() { # <arquivo>
  [ "$(secoes_de "$1")" = "$(secoes_canonicas)" ] || return 1
  local linha secao id estado classe campo
  while IFS="$(printf '\t')" read -r secao id; do
    [ -n "$id" ] || continue
    estado="$(pend_campo "$1" "$id" estado)"; classe="$(pend_campo "$1" "$id" classe)"
    [ "$secao" = "$(secao_do_estado "$estado")" ] || return 1
    if [ "$estado" = aguardando_classificacao ]; then [ "$classe" = null ] || return 1
    else case " $CLASSES_B5 " in *" $classe "*) ;; *) return 1 ;; esac; fi
    for campo in $CAMPOS_PEND; do
      tr -d '\r' < "$1" | awk -v id="$id" -v k="- $campo: " '
        /^## / { d = 0 } /^### / { d = (index($0, "### " id " ") == 1) } d && index($0, k) == 1 { achou = 1 }
        END { exit !achou }' || return 1
    done
  done <<EOF
$(tr -d '\r' < "$1" | awk '/^<!--/ { c = 1 } c { if (/-->/) c = 0; next } /^## / { s = $0 } /^### PEND-/ { print s "\t" $2 }')
EOF
}

recursao_nova() { # <arquivo> <projeto_id> — a partir do template, já sem instruções
  mkdir -p "$(dirname "$1")"
  tr -d '\r' < "$REPO/.claude/skills/buildx/assets/TEMPLATE-RECURSAO.md" |
    sed -e "s/<slug-do-projeto>/$2/" -e "s/<AAAA-MM-DD>/$(date +%Y-%m-%d)/" -e 's/<titulo>/Projeto/' |
    awk '/^## / { print; next } /^<[^!]/ { next } { print }' > "$1"
  recursao_reordena "$1"
}

fm() { tr -d '\r' < "$1" | awk -v k="$2: " 'NR > 1 && /^---$/ { exit } index($0, k) == 1 { print substr($0, length(k) + 1); exit }'; }
fm_define() { # <arquivo> <chave> <valor>
  local tmp="$1.tmp"
  tr -d '\r' < "$1" | awk -v k="$2: " -v v="$3" 'NR > 1 && /^---$/ { fim = 1 } !fim && index($0, k) == 1 { print k v; next } { print }' > "$tmp" &&
    mv -f "$tmp" "$1"
}
fm_incrementa() { fm_define "$1" "$2" $(( $(fm "$1" "$2") + 1 )); }

pend_nova() { # <arquivo> <assunto> <gatilho> <origem> <evidencia> <clausula> <pr_reservadas> <raiz> <causa> -> PEND-NN
  local arq="$1" id campo hoje
  id="$(proximo_id PEND $(pend_ids "$arq"))"; hoje="$(date +%Y-%m-%d)"
  {
    printf '\n### %s — %s\n\n' "$id" "$2"
    printf -- '- id: %s\n- estado: aguardando_classificacao\n- gatilho: %s\n- classe: null\n- origem: %s\n' "$id" "$3" "$4"
    printf -- '- ciclo: %s\n- evidencia: %s\n- causa: %s\n- clausula_central: %s\n- raiz: %s\n' "$(fm "$arq" ciclo_atual)" "$5" "$9" "$6" "$8"
    printf -- '- detectada_em: %s\n- classificada_em: null\n- regra_aplicada: null\n- destino: null\n' "$hoje"
    printf -- '- pr_reservadas: %s\n- resolvida_em: null\n- nota: null\n' "$7"
  } >> "$arq"
  recursao_reordena "$arq" || return 1
  fm_incrementa "$arq" pendencias_abertas
  printf '%s\n' "$id"
}

# --- MAPA.md e PROJETO.md, só no que o P0.1 toca ---

mapa_feature() { # <mapa> <FT> <slug> <status> <origem> [sucede] [pendencia]
  {
    printf '\n### %s — %s\n\n**Slug:** `%s`\n**Origem:** %s\n**Status:** %s\n' "$2" "$3" "$3" "$5" "$4"
    [ -n "${6:-}" ] && printf '**Sucede:** %s\n' "$6"
    [ -n "${7:-}" ] && printf '**Pendência:** %s\n' "$7"
  } >> "$1"
}

mapa_valor() { # <mapa> <FT> <rotulo>
  tr -d '\r' < "$1" | awk -v ft="$2" -v k="**$3:** " '
    /^### / { d = (index($0, "### " ft " ") == 1) } d && index($0, k) == 1 { v = substr($0, length(k) + 1); gsub(/`/, "", v); print v; exit }'
}

mapa_define() { # <mapa> <FT> <rotulo> <valor>
  local tmp="$1.tmp"
  tr -d '\r' < "$1" | awk -v ft="$2" -v k="**$3:** " -v v="$4" '
    function fecha() { if (d && !feito) { print k v; feito = 1 } d = 0 }
    /^### / { fecha(); if (index($0, "### " ft " ") == 1) { d = 1; feito = 0; visto = 0 } print; next }
    d && /^\*\*/ { visto = 1 }
    d && visto && !feito && !NF { print k v; feito = 1 }
    d && index($0, k) == 1 { print k v; feito = 1; next }
    { print }
    END { fecha() }' > "$tmp" && mv -f "$tmp" "$1"
}

# --- PR-NN: ocupado é ocupado, inclusive o de feature que não integrou ---

pr_ids_commitados() { # <slug> -> [PR-NN, ...]
  local ids
  ids="$(git show "feature/$1:docs/sprintx/features/$1/BUILDX-PREMISSAS.md" 2>/dev/null | tr -d '\r' |
    awk '/^### PR-/ { print $2 }' | paste -sd, - | sed 's/,/, /g')"
  printf '[%s]\n' "$ids"
}

pr_reservados() { # <RECURSAO.md> -> um PR-NN por linha
  [ -f "$1" ] || return 0
  tr -d '\r' < "$1" | awk '/^- pr_reservadas: / { sub(/^- pr_reservadas: \[/, ""); sub(/\]$/, ""); n = split($0, a, /, */); for (i = 1; i <= n; i++) if (a[i] != "") print a[i] }'
}

pr_ocupados() { # <PREMISSAS.md> <RECURSAO.md> <BUILDX-PREMISSAS.md da feature>
  {
    tr -d '\r' < "$1" 2>/dev/null | awk '/^### PR-/ { print $2 }'
    pr_reservados "$2"                                                      # [M7]
    [ -f "$3" ] && premissa_ids "$3"
  } | sort -u
}

proximo_pr() { proximo_id PR $(pr_ocupados "$@"); }

# --- o registro terminal: só depois do portão, num commit só ---

clausula_central_auditoria() { # stdin: 00-AUDITORIA.md -> prefixos ALTA distintos, em ordem
  altas_prefixos | awk '!visto[$0]++' | paste -sd, -
}

altas_prefixos() { # stdin: 00-AUDITORIA.md
  tr -d '\r' | awk -F'|' '/^\|/ {
    s = $2; gsub(/^[ \t]+|[ \t]+$/, "", s); if (s != "ALTA") next
    p = $4; sub(/^[ \t]+/, "", p)
    if (match(p, /^\[item [0-9]+\](\[fraco:[a-z]+\])?/)) print substr(p, RSTART, RLENGTH)
  }'
}

registra_terminal_pre_f6() { # <base> <slug> <FT> <branch-do-projeto> <worktree> [raiz]
  local base="$1" slug="$2" ft="$3" proj="$4" wt="$5" raiz="${6:-null}"
  local pasta="docs/sprintx/features/$2" rec=docs/projeto/RECURSAO.md head prs clausula id
  gate_terminal_pre_f6 "$base" "$slug" "$proj" "$wt" || return 1
  head="$(git rev-parse "feature/$slug")"
  [ -f "$rec" ] || recursao_nova "$rec" "${proj#buildx/}"
  prs="$(pr_ids_commitados "$slug")"                                        # [M8]
  clausula="$(git show "$head:$pasta/00-AUDITORIA.md" | clausula_central_auditoria)"
  id="$(pend_nova "$rec" "$ft esgotou o orcamento da F5" orcamento_f5_esgotado "$ft" \
        "feature/$slug@$head:$pasta/00-PLANEJAMENTO.md ; feature/$slug@$head:$pasta/00-AUDITORIA.md" \
        "$clausula" "$prs" "$raiz" null)" || return 1
  mapa_define docs/projeto/MAPA.md "$ft" Status bloqueada
  mapa_define docs/projeto/MAPA.md "$ft" "Bloqueada por" orcamento_f5_esgotado
  mapa_define docs/projeto/MAPA.md "$ft" "Pendência" "$id"
  fm_incrementa docs/projeto/PROJETO.md features_bloqueadas
  git add docs/projeto && git commit -q -m "chore(buildx): $ft bloqueada" || return 1
  if git rev-parse --verify --quiet "refs/remotes/origin/$proj" >/dev/null; then git push -q origin "$proj" || return 1; fi
}

# --- B5: a tabela gatilho -> classe, determinística ---

classe_orcamento() { # stdin: a 00-AUDITORIA.md terminal -> "classe regra"
  local p item classe regra
  p="$(altas_prefixos)"
  [ -n "$p" ] || return 1
  for regra in "7 decisao_humana" "8 recurso_externo"; do                  # [M9]
    item="${regra% *}"; classe="${regra#* }"
    if printf '%s\n' "$p" | grep -q "^\[item $item\]"; then
      echo "$classe orcamento_f5_esgotado/alta_item_$item"; return 0
    fi
  done
  echo "trabalho_novo orcamento_f5_esgotado/alta_qualidade_plano"
}

GATILHOS_DIRETOS="regra_de_negocio_nao_declarada recurso_externo_ausente incompatibilidade_de_versao violacao_de_convencao"

classe_da_tabela() { # <gatilho> <argumento: ref da auditoria | causa | classe da raiz> -> "classe regra"
  local g="$1" a="${2:-}" r
  case "$g" in
    orcamento_f5_esgotado)          git show "$a" 2>/dev/null | classe_orcamento ;;
    regra_de_negocio_nao_declarada) echo "decisao_humana $g" ;;
    recurso_externo_ausente)        echo "recurso_externo $g" ;;
    incompatibilidade_de_versao)    echo "decisao_humana $g" ;;
    violacao_de_convencao)          echo "trabalho_novo $g" ;;
    dependencia_nao_integrada)
      case " $CLASSES_B5 " in
        *" $a "*) [ -n "$a" ] && { echo "$a $g/segue_raiz"; return; } ;;
      esac
      echo "decisao_humana $g/raiz_ambigua" ;;
    entrega_bloqueada) classe_da_entrega "$a" ;;
    entrega_interrompida)
      case " $GATILHOS_DIRETOS " in
        *" $a "*) [ -n "$a" ] && { r="$(classe_da_tabela "$a")"; echo "${r% *} $g/causa_$a"; return; } ;;
      esac
      echo "trabalho_novo $g/resolvivel_sem_decisao" ;;
    *) return 1 ;;
  esac
}

# --- entrega_bloqueada: a causa enumerada da mergex, e o B-NN tipado (D-36) ---
#
# Nada aqui lê prosa: nem a narrativa do ENTREGA.md, nem a `descricao` do B-NN.
# Quem lê cada registro é o dono dele — a mergex (`causa-do-portao.sh
# --validar-historico`) e a sprintx (`bloqueios.sh listar`) —, sobre o conteúdo
# COMMITADO no HEAD da feature. O buildx só traduz o valor tipado.

# A causa MergeX (DM-111) na classe do B5. `bloqueio_aberto` não tem classe
# sozinha: depende dos B-NN abertos. Ausente (ENTREGA anterior às chaves) e
# `indeterminada` são causa não commitada. Fora do enum: não classifica.
classe_da_causa() { # <causa> -> "classe regra"
  local r=entrega_bloqueada
  case "$1" in
    suite_reprovada|teste_nao_declarado|arquivo_fora_do_plano) echo "trabalho_novo $r/causa_$1" ;;
    segredo_no_diff|auditoria_reprovada|legado_incompleto|tarefa_nao_concluida|regressao_nao_declarada|qa_nao_aprovado)
      echo "decisao_humana $r/causa_$1" ;;
    ausente|indeterminada) echo "decisao_humana $r/causa_nao_commitada" ;;   # [M24]
    *) return 1 ;;
  esac
}

# A classe do B-NN da sprintx (DS-139) na classe do B5: a que uma regra vigente
# sustenta sem ambiguidade; sem regra inequívoca, decisao_humana.
classe_do_bloqueio() { # <classe sprintx> -> classe do B5
  case "$1" in
    defeito_de_plano|suite_vermelha)     echo trabalho_novo ;;
    prerequisito_ausente)                echo recurso_externo ;;
    lacuna_de_decisao|task_reivindicada) echo decisao_humana ;;
    *) return 1 ;;
  esac
}

# A V7 diz que existe ao menos um B-NN aberto. Só os abertos contam, e só pela
# classe gravada. Nenhum aberto: inconsistência. Algum legado, ou classes
# diferentes: decisão humana — sem ler a descrição, sem precedência entre classes.
classe_dos_abertos() { # stdin: a saída de bloqueios.sh listar -> "classe regra"
  local abertas c r=entrega_bloqueada/causa_bloqueio_aberto
  abertas="$(tr -d '\r' | awk -F'\t' '$4 == "aberto" { print $3 }')"
  [ -n "$abertas" ] || return 1                                             # [M25]
  if printf '%s\n' "$abertas" | grep -qx legado; then                       # [M23]
    echo "decisao_humana $r/bloqueio_legado"; return 0
  fi
  if [ "$(printf '%s\n' "$abertas" | sort -u | wc -l | tr -d ' ')" != 1 ]; then   # [M22]
    echo "decisao_humana $r/classes_divergentes"; return 0
  fi
  abertas="$(printf '%s\n' "$abertas" | sort -u)"
  c="$(classe_do_bloqueio "$abertas")" || return 1
  echo "$c $r/classe_$abertas"
}

# A causa do ENTREGA.md commitado na ref, pela leitura histórica da mergex. Só um
# registro bloqueado/bloqueado tem causa a ler; o que a mergex recusa — causa fora
# do enum, uma chave sem a outra, causa que não é a derivada de falhas_portao — é
# inconsistência.
causa_commitada() { # <sha>:docs/entregas/<slug>/ENTREGA.md -> causa | ausente
  local e s k
  [ -n "${MERGEX_CAUSA:-}" ] || return 1
  e="$(git show "$1" 2>/dev/null)" || return 1
  for k in estado portao; do
    [ "$(printf '%s\n' "$e" | tr -d '\r' | grep -c "^$k: ")" = 1 ] || return 1
  done
  [ "$(printf '%s\n' "$e" | campo_registro estado):$(printf '%s\n' "$e" | campo_registro portao)" = bloqueado:bloqueado ] || return 1
  s="$(printf '%s\n' "$e" | bash "$MERGEX_CAUSA" --validar-historico - 2>/dev/null)" || return 1
  case "$s" in causa=null|causa=) return 1 ;; causa=*) echo "${s#causa=}" ;; *) return 1 ;; esac
}

# Os B-NN do 00-BLOQUEIOS.md commitado no MESMO sha, pela leitura da sprintx:
# id, task, classe gravada ou `legado`, aberto|resolvido. Arquivo ausente ou
# recusado pela sprintx (malformado, classe fora do enum): inconsistência.
bloqueios_commitados() { # <sha> <slug>
  local raiz pasta="docs/sprintx/features/$2" saida rc=1
  [ -n "${SPRINTX_BLOQUEIOS:-}" ] || return 1
  raiz="$(mktemp -d)"; mkdir -p "$raiz/$pasta"
  if git show "$1:$pasta/00-BLOQUEIOS.md" > "$raiz/$pasta/00-BLOQUEIOS.md" 2>/dev/null; then   # [M26]
    saida="$(SPRINTX_RAIZ="$raiz" bash "$SPRINTX_BLOQUEIOS" listar "$2" 2>/dev/null)"; rc=$?
  fi
  rm -rf "$raiz"
  [ "$rc" = 0 ] && printf '%s\n' "$saida"
}

classe_da_entrega() { # <sha>:docs/entregas/<slug>/ENTREGA.md -> "classe regra"
  local ref="$1" causa sha slug lista
  causa="$(causa_commitada "$ref")" || return 1
  [ "$causa" = bloqueio_aberto ] || { classe_da_causa "$causa"; return; }
  sha="${ref%%:*}"; slug="${ref#*:docs/entregas/}"; slug="${slug%/ENTREGA.md}"
  [ "$ref" = "$sha:docs/entregas/$slug/ENTREGA.md" ] || return 1
  lista="$(bloqueios_commitados "$sha" "$slug")" || return 1                # [M21]
  printf '%s\n' "$lista" | classe_dos_abertos
}

# A causa como a pendência a grava: a da mergex, e `null` quando não commitada.
causa_da_pendencia() { case "$1" in ausente) echo null ;; *) echo "$1" ;; esac; }

# Triagem terminal da entrega bloqueada (D-35, D-36). A evidência é o ENTREGA.md
# commitado no HEAD da feature — e, com bloqueio_aberto, o 00-BLOQUEIOS.md do
# mesmo HEAD. Registro que não se deixa classificar não move a CONTROL.
registra_entrega_bloqueada() { # <base> <slug> <FT> <branch-do-projeto> [raiz]
  local base="$1" slug="$2" ft="$3" proj="$4" raiz="${5:-null}" rec=docs/projeto/RECURSAO.md head ref causa ev id
  [ "$(entrega_terminal "$slug")" = bloqueada ] || return 1
  provas_pre_ff "$base" "feature/$slug" "$proj" || return 1
  head="$(git rev-parse "feature/$slug")"; ref="$head:docs/entregas/$slug/ENTREGA.md"
  classe_da_entrega "$ref" >/dev/null || return 1
  causa="$(causa_da_pendencia "$(causa_commitada "$ref")")"
  ev="feature/$slug@$ref"
  [ "$causa" = bloqueio_aberto ] && ev="$ev ; feature/$slug@$head:docs/sprintx/features/$slug/00-BLOQUEIOS.md"
  [ -f "$rec" ] || recursao_nova "$rec" "${proj#buildx/}"
  id="$(pend_nova "$rec" "$ft entrega bloqueada" entrega_bloqueada "$ft" "$ev" "$causa" \
        "$(pr_ids_commitados "$slug")" "$raiz" "$causa")" || return 1
  mapa_define docs/projeto/MAPA.md "$ft" Status bloqueada
  mapa_define docs/projeto/MAPA.md "$ft" "Bloqueada por" entrega_bloqueada
  mapa_define docs/projeto/MAPA.md "$ft" "Pendência" "$id"
  fm_incrementa docs/projeto/PROJETO.md features_bloqueadas
  git add docs/projeto && git commit -q -m "chore(buildx): $ft bloqueada" || return 1
  if git rev-parse --verify --quiet "refs/remotes/origin/$proj" >/dev/null; then git push -q origin "$proj" || return 1; fi
}

# A referência `feature/<slug>@<sha>:<caminho>` da evidência, como `<sha>:<caminho>`.
ref_da_evidencia() { # <evidencia> <nome-do-arquivo>
  printf '%s\n' "$1" | tr ';' '\n' | sed 's/^ *//; s/ *$//' | grep "/$2\$" | head -1 | sed 's/^[^@]*@//'
}

pend_classifica() { # <RECURSAO.md> <PEND-NN> <classe> <regra> [nota]
  pend_define "$1" "$2" estado "$3" && pend_define "$1" "$2" classe "$3" &&
    pend_define "$1" "$2" regra_aplicada "$4" && pend_define "$1" "$2" classificada_em "$(date +%Y-%m-%d)" &&
    { [ -z "${5:-}" ] || pend_define "$1" "$2" nota "$5"; }
}

# Mesmo gatilho e mesma cláusula central da raiz: trabalho novo não resolve.
eh_laco() { # <RECURSAO.md> <PEND-NN>
  local raiz; raiz="$(pend_campo "$1" "$2" raiz)"
  [ -n "$raiz" ] && [ "$raiz" != null ] || return 1
  [ "$(pend_campo "$1" "$2" gatilho)" = "$(pend_campo "$1" "$raiz" gatilho)" ] || return 1
  [ "$(pend_campo "$1" "$2" clausula_central)" = "$(pend_campo "$1" "$raiz" clausula_central)" ]   # [M13]
}

detector_laco() { # <RECURSAO.md> <PEND-NN>
  local raiz
  eh_laco "$1" "$2" || return 1
  raiz="$(pend_campo "$1" "$2" raiz)"
  pend_classifica "$1" "$raiz" decisao_humana laco_detectado laco_detectado &&
    pend_classifica "$1" "$2" decisao_humana laco_detectado "laco_detectado: segue $raiz" &&
    raiz_acompanha "$1" "$raiz"
}

# A raiz acompanha a filha (passo 4). Sobe a cadeia `raiz` enquanto o ancestral
# está em_resolucao: filha em_resolucao leva o destino novo; decisao_humana ou
# recurso_externo levam estado, classe e regra, com `nota: segue <filha>`. O que
# já saiu de em_resolucao não é tocado. Raiz ausente do arquivo: parada.
raiz_acompanha() { # <RECURSAO.md> <PEND-filha>
  local rec="$1" filha="$2" estado raiz
  estado="$(pend_campo "$rec" "$filha" estado)"
  raiz="$(pend_campo "$rec" "$filha" raiz)"
  while [ -n "$raiz" ] && [ "$raiz" != null ]; do
    [ -n "$(pend_campo "$rec" "$raiz" id)" ] || return 1
    [ "$(pend_campo "$rec" "$raiz" estado)" = em_resolucao ] || break
    case "$estado" in
      em_resolucao) pend_define "$rec" "$raiz" destino "$(pend_campo "$rec" "$filha" destino)" || return 1 ;;
      decisao_humana|recurso_externo)
        pend_classifica "$rec" "$raiz" "$estado" "$(pend_campo "$rec" "$filha" regra_aplicada)" "segue $filha" || return 1 ;;
      *) return 1 ;;
    esac
    raiz="$(pend_campo "$rec" "$raiz" raiz)"
  done
  recursao_reordena "$rec"
}

# Ciclo inteiro sem conversão (passo 5), só pelo MAPA e pelo RECURSAO persistidos.
# O ciclo n ≥ 2 rodou as sucessoras (`Origem: recursao`) que integraram com a
# `Pendência` do ciclo n-1 que as criou, e as que bloquearam registrando a filha
# no ciclo n. Converteu se alguma delas está `entregue` com a pendência `resolvida`.
# O ciclo 1 não roda sucessora: nao_se_aplica. Sucessora do ciclo ainda aberta, ou
# entregue sem a pendência resolvida, é estado inconsistente: parada.
ciclo_converteu() { # <RECURSAO.md> <MAPA.md> -> sim | nao | nao_se_aplica
  local rec="$1" mapa="$2" n ft p c rodou=0 conv=0
  n="$(fm "$rec" ciclo_atual)"
  [ "$n" -ge 2 ] || { echo nao_se_aplica; return 0; }
  for ft in $(tr -d '\r' < "$mapa" | awk '/^### FT-/ { print $2 }'); do
    [ "$(mapa_valor "$mapa" "$ft" Origem)" = recursao ] || continue
    p="$(mapa_valor "$mapa" "$ft" Pendência)"; c="$(pend_campo "$rec" "$p" ciclo)"
    case "$(mapa_valor "$mapa" "$ft" Status)" in
      entregue)
        [ "$c" = $((n - 1)) ] || continue
        rodou=1
        [ "$(pend_campo "$rec" "$p" estado)" = resolvida ] || return 1
        conv=1 ;;                                                           # [M15]
      bloqueada) [ "$c" = "$n" ] && rodou=1 ;;
      *) [ "$c" = $((n - 1)) ] && return 1 ;;
    esac
  done
  if [ "$rodou" = 0 ]; then echo nao_se_aplica
  elif [ "$conv" = 1 ]; then echo sim
  else echo nao; fi
}

# Sucessora: FT e slug novos, origem recursao. A bloqueada não volta.
cria_sucessora() { # <RECURSAO.md> <PEND-NN> <MAPA.md> <FT-novo> <slug-novo> <regra>
  local rec="$1" id="$2" mapa="$3" ft_novo="$4" slug_novo="$5" ft_velha slug_velho
  ft_velha="$(pend_campo "$rec" "$id" origem)"; slug_velho="$(mapa_valor "$mapa" "$ft_velha" Slug)"
  [ "$slug_novo" != "$slug_velho" ] || return 1                            # [M5]
  [ -z "$(mapa_valor "$mapa" "$ft_novo" Status)" ] || return 1
  tr -d '\r' < "$mapa" | grep -qx "\*\*Slug:\*\* \`$slug_novo\`" && return 1
  git rev-parse --verify --quiet "refs/heads/feature/$slug_novo" >/dev/null && return 1
  mapa_feature "$mapa" "$ft_novo" "$slug_novo" pendente recursao "$ft_velha" "$id"
  pend_define "$rec" "$id" estado em_resolucao && pend_define "$rec" "$id" classe trabalho_novo &&
    pend_define "$rec" "$id" regra_aplicada "$6" && pend_define "$rec" "$id" classificada_em "$(date +%Y-%m-%d)" &&
    pend_define "$rec" "$id" destino "$ft_novo" &&
    pend_define "$rec" "$id" sucede "$ft_velha" && pend_define "$rec" "$id" slug_sucessora "$slug_novo"
}

b5_classifica() { # <RECURSAO.md> <PEND-NN> <MAPA.md> [FT-sucessora slug-sucessora] — sem commit
  local rec="$1" id="$2" mapa="$3" g arg classe regra conv causa
  [ "$(pend_campo "$rec" "$id" estado)" = aguardando_classificacao ] || return 1
  if detector_laco "$rec" "$id"; then recursao_reordena "$rec"; return; fi
  g="$(pend_campo "$rec" "$id" gatilho)"
  case "$g" in
    orcamento_f5_esgotado) arg="$(ref_da_evidencia "$(pend_campo "$rec" "$id" evidencia)" 00-AUDITORIA.md)" ;;
    dependencia_nao_integrada) arg="$(pend_campo "$rec" "$(pend_campo "$rec" "$id" raiz)" classe 2>/dev/null)" ;;
    entrega_bloqueada)
      # A evidência commitada decide; a `causa` gravada na pendência tem de ser a dela.
      arg="$(ref_da_evidencia "$(pend_campo "$rec" "$id" evidencia)" ENTREGA.md)"
      causa="$(causa_commitada "$arg")" || return 1
      [ "$(pend_campo "$rec" "$id" causa)" = "$(causa_da_pendencia "$causa")" ] || return 1 ;;
    *) arg="$(pend_campo "$rec" "$id" causa)" ;;
  esac
  read -r classe regra <<EOF
$(classe_da_tabela "$g" "$arg")
EOF
  [ -n "$classe" ] || return 1
  if [ "$classe" = trabalho_novo ]; then
    if [ "$(fm "$rec" ciclo_atual)" -ge "$(fm "$rec" teto_ciclos)" ]; then
      pend_classifica "$rec" "$id" decisao_humana teto_de_ciclos_atingido teto_de_ciclos_atingido || return 1
    else
      conv="$(ciclo_converteu "$rec" "$mapa")" || return 1
      if [ "$conv" = nao ]; then                                            # [M14]
        pend_classifica "$rec" "$id" decisao_humana laco_detectado/ciclo_sem_conversao laco_detectado || return 1
      else
        cria_sucessora "$rec" "$id" "$mapa" "$4" "$5" "$regra" || return 1
      fi
    fi
  else
    pend_classifica "$rec" "$id" "$classe" "$regra" || return 1
  fi
  raiz_acompanha "$rec" "$id"
}

# A sucessora integrou. Resolve as pendências em_resolucao com `destino` nela —
# a filha e as raízes que a acompanham —, que precisam formar UMA cadeia `raiz`:
# duas cadeias no mesmo destino é inconsistência, e nada é gravado.
resolve_por_entrega() { # <RECURSAO.md> <FT>
  local rec="$1" id p membros=" " base="" n=0 visto=0 hoje
  for id in $(pend_ids "$rec"); do
    [ "$(pend_campo "$rec" "$id" destino)" = "$2" ] && [ "$(pend_campo "$rec" "$id" estado)" = em_resolucao ] || continue
    membros="$membros$id "; n=$((n + 1))
  done
  for id in $membros; do
    for p in $membros; do [ "$(pend_campo "$rec" "$p" raiz)" = "$id" ] && continue 2; done
    [ -z "$base" ] || return 1
    base="$id"
  done
  p="$base"
  while [ -n "$p" ] && [ "$visto" -le "$n" ] && case "$membros" in *" $p "*) true ;; *) false ;; esac; do
    visto=$((visto + 1)); p="$(pend_campo "$rec" "$p" raiz)"
  done
  [ "$visto" = "$n" ] || return 1
  hoje="$(date +%Y-%m-%d)"
  for id in $membros; do
    pend_define "$rec" "$id" estado resolvida || return 1                   # [M11]
    pend_define "$rec" "$id" resolvida_em "$hoje" || return 1
    fm_define "$rec" pendencias_abertas $(( $(fm "$rec" pendencias_abertas) - 1 ))
    fm_incrementa "$rec" pendencias_resolvidas
  done
  recursao_reordena "$rec"
}

# O MAPA manda, o RECURSAO acompanha: toda pendência em_resolucao lê o status do
# seu `destino`. Entregue resolve; pendente, em_andamento ou bloqueada mantém.
# Destino fora do MAPA é inconsistência: parada antes de qualquer escrita.
recursao_acompanha() { # <RECURSAO.md> <MAPA.md>
  local rec="$1" mapa="$2" id ft status entregues=""
  for id in $(pend_ids "$rec"); do
    [ "$(pend_campo "$rec" "$id" estado)" = em_resolucao ] || continue
    ft="$(pend_campo "$rec" "$id" destino)"; status="$(mapa_valor "$mapa" "$ft" Status)"
    case "$status" in
      "") return 1 ;;                                                       # [M16]
      entregue) case " $entregues " in *" $ft "*) ;; *) entregues="$entregues $ft" ;; esac ;;
      pendente|em_andamento|bloqueada) ;;                                   # [M12]
      *) return 1 ;;
    esac
  done
  cp "$rec" "$rec.acompanha"
  for ft in $entregues; do resolve_por_entrega "$rec.acompanha" "$ft" || { rm -f "$rec.acompanha"; return 1; }; done
  recursao_reordena "$rec.acompanha" && mv -f "$rec.acompanha" "$rec"
}

# O projeto de um cenário P0.1: mapa com features, PROJETO e PREMISSAS globais.
projeto_p01() { # <nome> <PR-NN globais...> -> ecoa o caminho do controle
  local nome="$1" c id; shift
  c="$(novo_projeto "$nome" sim)" || return 1
  (
    cd "$c" || exit 1
    printf -- '---\nkind: projeto\nfeatures_bloqueadas: 0\n---\n' > docs/projeto/PROJETO.md
    printf '# Premissas\n' > docs/projeto/PREMISSAS.md
    for id in "$@"; do printf '\n### %s — premissa global\n\n- decisao: d\n' "$id" >> docs/projeto/PREMISSAS.md; done
    mapa_feature docs/projeto/MAPA.md FT-01 ft-01 em_andamento descricao
    mapa_feature docs/projeto/MAPA.md FT-02 ft-02 pendente descricao
    git add -A && git commit -q -m "chore(buildx): FT-01 em andamento" && git push -q origin "buildx/$nome"
  ) >/dev/null 2>&1 || return 1
  printf '%s\n' "$c"
}

# --- a sprintx F1–F5 simulada NOS ARTEFATOS, mas com o script de estado REAL ---

# F1: exclui o rastro localmente (como a F1 real faz) e cria o planejamento com
# o orçamento que veio do briefing. A F1 não faz checkpoint.
sx_f1() { # <wt> <slug>
  local excl
  excl="$(git -C "$1" rev-parse --git-path info/exclude)"
  case "$excl" in /*|?:/*) ;; *) excl="$1/$excl" ;; esac
  mkdir -p "$(dirname "$excl")"
  grep -qx 'docs/eventos/' "$excl" 2>/dev/null || printf 'docs/eventos/\n' >> "$excl"
  mkdir -p "$1/docs/sprintx/features/$2/base"
  printf '# Indice\n' > "$1/docs/sprintx/features/$2/base/00-INDICE.md"
  sprintx "$1" criar "$2" $(briefing_orcamento | cut -d' ' -f2) >/dev/null
}

sx_f2() { printf -- '---\nkind: decisoes\n---\n' > "$1/docs/sprintx/features/$2/00-DECISOES.md"; sprintx "$1" avanca "$2" f2 >/dev/null; }
sx_f3() {
  mkdir -p "$1/docs/sprintx/features/$2/sprint-01"
  PLANO_V=$((${PLANO_V:-0} + 1))
  printf 'plano versao %s\n' "$PLANO_V" > "$1/docs/sprintx/features/$2/sprint-01/tasks.md"
  sprintx "$1" avanca "$2" f3 >/dev/null
}
sx_f4() { printf '# Orquestrador\n' > "$1/docs/sprintx/features/$2/ORQUESTRADOR.md"; sprintx "$1" avanca "$2" f4 >/dev/null; }

# auditoria <arquivo> <sim|nao> [itens ALTA...] — no formato que o script valida.
auditoria() {
  local arq="$1" v="$2" i; shift 2
  {
    printf '# Auditoria\n\n'
    if [ "$v" = sim ]; then
      printf 'Nenhum achado.\n\nVEREDITO: SIM — o plano está pronto para execução autônoma.\n'
    else
      printf '| severidade | arquivo | problema | correção sugerida |\n|---|---|---|---|\n'
      for i in "$@"; do
        case "$i" in
          2) printf '| ALTA | sprint-01/tasks.md | [item 2][fraco:criterio] T-01.01 — cláusula: - — passaria com: retorno fixo | endurecer |\n' ;;
          *) printf '| ALTA | sprint-01/tasks.md | [item %s] achado da classe %s | corrigir |\n' "$i" "$i" ;;
        esac
      done
      printf '\nVEREDITO: NÃO — o plano não está pronto para execução autônoma.\n'
    fi
  } > "$arq"
}

sx_f5() { # <wt> <slug> <sim|nao> [itens ALTA...] -> a saida do avanca; codigo do script
  local wt="$1" slug="$2"; shift 2
  auditoria "$wt/docs/sprintx/features/$slug/00-AUDITORIA.md" "$@"
  sprintx "$wt" avanca "$slug" f5
}

# Um ciclo F3 → F4 → F5 reprovado, na mesma branch e no mesmo worktree.
sx_rodada_nao() { # <wt> <slug> [itens ALTA...]
  local wt="$1" slug="$2"; shift 2
  [ $# -gt 0 ] || set -- 9
  sx_f3 "$wt" "$slug"; sx_f4 "$wt" "$slug"; sx_f5 "$wt" "$slug" nao "$@" >/dev/null
}

# Hook do projeto que recusa commit enquanto a marca existir: é o que faz o
# checkpoint da sprintx cair em persistencia_falhou.
hook_recusa() { # <liga|desliga>
  local comum; comum="$(git rev-parse --git-common-dir)"
  mkdir -p "$comum/hooks"
  printf '#!/bin/sh\n[ -f "$(git rev-parse --git-common-dir)/recusar-commit" ] && { echo recusado >&2; exit 1; }\nexit 0\n' \
    > "$comum/hooks/pre-commit"
  chmod +x "$comum/hooks/pre-commit"
  if [ "$1" = liga ]; then : > "$comum/recusar-commit"; else rm -f "$comum/recusar-commit"; fi
}

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

if bloco p0; then

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
fi  # p0

SX_REF="$REPO/.claude/skills/buildx/references/integracao/sprintx.md"
B4_REF="$REPO/.claude/skills/buildx/references/05-construcao.md"

if bloco orcamento; then
echo
echo "P0.1 — o briefing declara o orçamento, a sprintx persiste e conta"

caso "P01.1 briefing declara max_reprovacoes_f5: 3" sim \
  "$(sim_nao grep -qx 'max_reprovacoes_f5: 3' <(briefing_orcamento))"
caso "P01.1 e orcamento_declarado_por: buildx"      sim \
  "$(sim_nao grep -qx 'orcamento_declarado_por: buildx' <(briefing_orcamento))"
for doc in "$SX_REF" "$B4_REF"; do
  caso "P01.1 o contrato $(basename "$doc") declara o teto 3"   sim "$(sim_nao grep -qx 'max_reprovacoes_f5: 3' <(tr -d '\r' < "$doc"))"
  caso "P01.1 o contrato $(basename "$doc") declara o dono"     sim "$(sim_nao grep -qx 'orcamento_declarado_por: buildx' <(tr -d '\r' < "$doc"))"
done
caso "P01.1 e aponta a interface real da F1: criar <slug> 3 buildx" sim \
  "$(sim_nao grep -q 'planejamento.sh criar <slug> 3 buildx' "$SX_REF")"

if com_sprintx "P01.1 orcamento persistido"; then
  C="$(novo_projeto o1 sim)"; cd "$C"
  BASE="$(git rev-parse HEAD)"
  feature_nasce ft-01 "$BASE" o1; WT="$TMP_RAIZ/o1/wt-ft-01"
  sx_f1 "$WT" ft-01
  caso "P01.1 a F1 grava o teto do briefing"          "max_reprovacoes_f5: 3" \
    "$(grep '^max_reprovacoes_f5:' "$WT/docs/sprintx/features/ft-01/00-PLANEJAMENTO.md")"
  caso "P01.1 a F1 nao commita: branch ainda em BASE_SHA" "$BASE" "$(git rev-parse feature/ft-01)"
  sx_f2 "$WT" ft-01
  caso "P01.1 depois do checkpoint da F2, o orcamento esta commitado" sim "$(sim_nao orcamento_confere ft-01)"
  caso "P01.1 orcamento diferente numa retomada: a sprintx recusa" nao \
    "$(sim_nao sprintx "$WT" criar ft-01 5 buildx)"
  caso "P01.1 e o teto commitado nao muda"            sim "$(sim_nao orcamento_confere ft-01)"
fi
fi  # orcamento

if bloco checkpoint; then
echo
echo "P0.1 — checkpoint da sprintx é estado legítimo da feature, não E1"

if com_sprintx "P01.2 checkpoints"; then
  C="$(novo_projeto k1 sim)"; cd "$C"
  BASE="$(git rev-parse HEAD)"
  feature_nasce ft-01 "$BASE" k1; WT="$TMP_RAIZ/k1/wt-ft-01"
  caso "P01.2 caminho A: nasce exatamente em BASE_SHA" "$BASE" "$(git rev-parse feature/ft-01)"
  sx_f1 "$WT" ft-01; sx_f2 "$WT" ft-01; sx_f3 "$WT" ft-01; sx_f4 "$WT" ft-01
  caso "P01.2 checkpoints deixam a feature a frente de BASE_SHA" nao \
    "$(sim_nao test "$BASE" = "$(git rev-parse feature/ft-01)")"
  caso "P01.2 e ela continua descendendo da base"   sim "$(sim_nao git merge-base --is-ancestor "$BASE" feature/ft-01)"
  caso "P01.2 os commits a frente sao so checkpoints, sem produto" sim "$(sim_nao sem_produto_pre_f6 "$BASE" ft-01)"
  caso "P01.2 nenhum deles e commit de task (E1)"   "" \
    "$(git log --format=%B "$BASE..feature/ft-01" | grep '^Task:' || true)"
  caso "P01.2 a CONTROL nao se moveu na janela"     "$BASE" "$(git rev-parse HEAD)"
  caso "P01.2 e segue limpa"                        sim "$(sim_nao test -z "$(git status --porcelain)")"
  caso "P01.2 a worktree da feature termina limpa (rastro excluido localmente)" sim \
    "$(sim_nao test -z "$(git -C "$WT" status --porcelain)")"

  caso "P01.28 retomada so com checkpoints: legitima, na fase da sprintx" "C:continuar_f5" \
    "$(retomada_decide ft-01 "$BASE" em_andamento buildx/k1)"

  # F5 reprova uma vez: a sprintx manda replanejar, o buildx continua na F3.
  sx_f5 "$WT" ft-01 nao 9 >/dev/null
  caso "P01.fase replanejar: o buildx continua a sprintx na F3" continuar_f3 "$(buildx_acao "$WT" ft-01)"
  caso "P01.fase e a CONTROL continua em BASE_SHA"             "$BASE" "$(git rev-parse HEAD)"

  # A sessão morre e leva o worktree. A branch, com os checkpoints, fica.
  TIP="$(git rev-parse feature/ft-01)"
  rm -rf "$WT"
  caso "P01.29 worktree perdido, branch checkpointada"      H "$(retomada_decide ft-01 "$BASE" em_andamento buildx/k1)"
  caso "P01.29 recriar a branch existente e recusado"        nao "$(sim_nao git branch feature/ft-01 "$BASE")"
  caso "P01.29 reabre o worktree sobre a mesma branch"       sim "$(sim_nao reabre_worktree ft-01 "$WT")"
  caso "P01.29 a branch nao mudou"                           "$TIP" "$(git rev-parse feature/ft-01)"
  caso "P01.29 e o planejamento voltou do commit"            continuar_f3 "$(buildx_acao "$WT" ft-01)"

  C="$(novo_projeto k2 sim)"; cd "$C"
  BASE="$(git rev-parse HEAD)"
  feature_nasce ft-01 "$BASE" k2; WT="$TMP_RAIZ/k2/wt-ft-01"
  sx_f1 "$WT" ft-01
  caso "P01.30 so a F1 rodou: retomada em BASE_SHA segue a sprintx" "B:continuar_f2" \
    "$(retomada_decide ft-01 "$BASE" em_andamento buildx/k2)"
  git worktree remove --force "$WT"
  caso "P01.30 worktree perdido, branch == BASE_SHA"  I "$(retomada_decide ft-01 "$BASE" em_andamento buildx/k2)"
  caso "P01.30 reabre sobre a mesma branch"           sim "$(sim_nao reabre_worktree ft-01 "$WT")"
  caso "P01.30 e a sprintx retoma da F1 (nada era duravel)" "B:continuar_f1" \
    "$(retomada_decide ft-01 "$BASE" em_andamento buildx/k2)"
  caso "P01.30 a branch nao foi recriada"             "$BASE" "$(git rev-parse feature/ft-01)"
fi

# A contagem é da sprintx. Prosa com "rodada 3" e várias linhas VEREDITO não
# termina a tentativa: só o estado que o script devolve decide.
if com_sprintx "P01.M10 prosa"; then
  C="$(novo_projeto k3 sim)"; cd "$C"
  BASE="$(git rev-parse HEAD)"
  feature_nasce ft-01 "$BASE" k3; WT="$TMP_RAIZ/k3/wt-ft-01"
  sx_f1 "$WT" ft-01; sx_f2 "$WT" ft-01; sx_rodada_nao "$WT" ft-01 9
  sx_f3 "$WT" ft-01; sx_f4 "$WT" ft-01
  AUD="$WT/docs/sprintx/features/ft-01/00-AUDITORIA.md"
  auditoria "$AUD" nao 9
  printf '\nRodada 3 de 3. Historico: VEREDITO: NÃO\nVEREDITO: NÃO\nVEREDITO: NÃO — terceira rodada.\n' >> "$AUD"
  sprintx "$WT" avanca ft-01 f5 >/dev/null
  caso "P01.M10 tres linhas VEREDITO e 'rodada 3' na prosa: a sprintx diz 2 reprovacoes" "reprovacoes: 2" \
    "$(git show feature/ft-01:docs/sprintx/features/ft-01/00-PLANEJAMENTO.md | grep '^reprovacoes:')"
  caso "P01.M10 e o buildx segue replanejando, sem contar texto" continuar_f3 "$(buildx_acao "$WT" ft-01)"
fi
fi  # checkpoint

if bloco x2; then
echo
echo "P0.1 — X2: CHECKPOINT pendente não decide nada; depois dele, ff-only"

if com_sprintx "X2"; then
  C="$(novo_projeto x2 sim)"; cd "$C"
  BASE="$(git rev-parse HEAD)"
  feature_nasce ft-01 "$BASE" x2; WT="$TMP_RAIZ/x2/wt-ft-01"
  sx_f1 "$WT" ft-01; sx_f2 "$WT" ft-01; sx_rodada_nao "$WT" ft-01 9
  sx_f3 "$WT" ft-01; sx_f4 "$WT" ft-01
  ANTES="$(git rev-parse feature/ft-01)"

  hook_recusa liga
  SAIDA="$(sx_f5 "$WT" ft-01 nao 9; printf 'codigo=%s\n' "$?")"
  caso "X2 o hook recusa o checkpoint: persistencia_falhou" persistencia_falhou "$(chave "$SAIDA" checkpoint)"
  caso "X2 com codigo 3"                                   3 "$(chave "$SAIDA" codigo)"
  caso "X2 a branch nao recebeu a rodada"                  "$ANTES" "$(git rev-parse feature/ft-01)"
  caso "P01.3 sprintx responde CHECKPOINT"                 CHECKPOINT "$(chave "$(sprintx "$WT" fase ft-01)" fase)"
  caso "P01.3 o buildx so completa o checkpoint"           completar_checkpoint "$(buildx_acao "$WT" ft-01)"
  caso "P01.27 retomada em CHECKPOINT"                     D "$(retomada_decide ft-01 "$BASE" em_andamento buildx/x2)"
  caso "P01.3 nao avanca a sprintx por cima"               nao "$(sim_nao sprintx "$WT" avanca ft-01 f3)"
  caso "P01.3 e a CONTROL nao se move"                     "$BASE" "$(git rev-parse HEAD)"
  caso "P01.3 nem o remoto"                                "$BASE" "$(git rev-parse origin/buildx/x2)"
  caso "P01.3 o buildx nao commitou por conta propria"    "$ANTES" "$(git rev-parse feature/ft-01)"

  # A retomada cai de novo em CHECKPOINT até a sprintx persistir.
  caso "X2 ainda recusado: continua CHECKPOINT"            nao "$(sim_nao sprintx "$WT" checkpoint ft-01)"
  caso "X2 e a retomada continua em D"                     D "$(retomada_decide ft-01 "$BASE" em_andamento buildx/x2)"
  hook_recusa desliga
  caso "X2 a sprintx completa o checkpoint"                commitado "$(chave "$(sprintx "$WT" checkpoint ft-01)" checkpoint)"
  caso "X2 e o estado volta a governar: replanejar"        continuar_f3 "$(buildx_acao "$WT" ft-01)"

  # A F5 aprova antes do teto: F6.
  sx_f3 "$WT" ft-01; sx_f4 "$WT" ft-01; sx_f5 "$WT" ft-01 sim >/dev/null
  caso "P01.fase aprovado: F6"                               f6 "$(buildx_acao "$WT" ft-01)"
  caso "P01.fase e a retomada tambem"                        F "$(retomada_decide ft-01 "$BASE" em_andamento buildx/x2)"

  # F6 simulada: E1 com produto e o registro do E8, commitados e publicados.
  mkdir -p "$WT/src" "$WT/docs/entregas/ft-01"
  printf 'codigo\n' > "$WT/src/ft-01.ts"
  git -C "$WT" add -A; git -C "$WT" commit -q -m "feat: T-01.01" -m "Task: T-01.01"
  printf 'estado: entregue\nportao: pronto\npush_feito: true\n' > "$WT/docs/entregas/ft-01/ENTREGA.md"
  git -C "$WT" add -A; git -C "$WT" commit -q -m "chore(mergex): E8"
  mergex_publica ft-01
  caso "P01.31 depois da F6 ha produto: nao e mais so checkpoint" nao "$(sim_nao sem_produto_pre_f6 "$BASE" ft-01)"
  caso "P01.31 a branch com checkpoints e E1 descende da base"   sim "$(sim_nao git merge-base --is-ancestor "$BASE" feature/ft-01)"
  caso "P01.31 as seis provas passam"                             sim "$(sim_nao provas_abcdef "$BASE" ft-01 buildx/x2 "$WT")"
  caso "P01.31 publicada"                                         sim "$(sim_nao prova_publicacao ft-01 true)"
  caso "P01.31 ff-only integra, com os checkpoints anteriores"    sim "$(sim_nao integrar feature/ft-01)"
  caso "P01.31 e os checkpoints entram na arvore do projeto"      sim \
    "$(sim_nao git cat-file -e HEAD:docs/sprintx/features/ft-01/00-PLANEJAMENTO.md)"
fi
fi  # x2

if bloco terminal; then
echo
echo "P0.1 — portão terminal pré-F6: só o commitado move a CONTROL"

# Checkpoint de planejamento sintético, no formato da sprintx — para montar
# estados que a sprintx real nunca produziria sozinha.
commit_checkpoint() { # <wt> <mensagem>
  git -C "$1" add -A
  git -C "$1" commit -q -m "$2" -m "Planejamento: checkpoint"
}

C="$(novo_projeto t1 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_nasce ft-01 "$BASE" t1; WT="$TMP_RAIZ/t1/wt-ft-01"
P="$WT/docs/sprintx/features/ft-01"; mkdir -p "$P"
printf 'estado: replanejar\n' > "$P/00-PLANEJAMENTO.md"
auditoria "$P/00-AUDITORIA.md" nao 9
commit_checkpoint "$WT" "chore(sprintx): checkpoint de planejamento ft-01 — f5 rodada 2"
caso "P01.7 so checkpoints na pasta da feature: sem produto"  sim "$(sim_nao sem_produto_pre_f6 "$BASE" ft-01)"
printf 'estado: orcamento_esgotado\n' > "$P/00-PLANEJAMENTO.md"
git -C "$WT" add -A; git -C "$WT" commit -q -m "chore(sprintx): checkpoint de planejamento ft-01 — f5 rodada 3" -m "Planejamento: checkpoint"
caso "P01.5 terminal commitado: prova F passa"               sim "$(sim_nao prova_f_terminal_commitado ft-01)"
caso "P01.6 auditoria da rodada terminal no mesmo commit: prova I passa" sim "$(sim_nao prova_i_auditoria_commitada ft-01)"
auditoria "$P/00-AUDITORIA.md" nao 7
caso "P01.6 auditoria reescrita depois do terminal, no worktree: o portao barra" nao \
  "$(sim_nao gate_terminal_pre_f6 "$BASE" ft-01 buildx/t1 "$WT")"
git -C "$WT" checkout -q -- docs/sprintx/features/ft-01/00-AUDITORIA.md

mkdir -p "$WT/src"; printf 'produto\n' > "$WT/src/antes-da-f6.ts"
commit_checkpoint "$WT" "chore(sprintx): checkpoint de planejamento ft-01 — f5 rodada 3"
caso "P01.7 produto commitado pre-F6, mesmo com trailer: barra" nao "$(sim_nao sem_produto_pre_f6 "$BASE" ft-01)"

C="$(novo_projeto t2 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_nasce ft-01 "$BASE" t2; WT="$TMP_RAIZ/t2/wt-ft-01"
P="$WT/docs/sprintx/features/ft-01"; mkdir -p "$P"
printf 'estado: orcamento_esgotado\n' > "$P/00-PLANEJAMENTO.md"
git -C "$WT" add -A; git -C "$WT" commit -q -m "chore(buildx): escrito por quem nao e a sprintx"
caso "P01.7 commit sem o trailer de checkpoint: barra" nao "$(sim_nao sem_produto_pre_f6 "$BASE" ft-01)"

C="$(novo_projeto t3 sim)"; cd "$C"
BASE="$(git rev-parse HEAD)"
feature_nasce ft-01 "$BASE" t3; WT="$TMP_RAIZ/t3/wt-ft-01"
P="$WT/docs/sprintx/features/ft-01"; mkdir -p "$P"
printf 'estado: orcamento_esgotado\n' > "$P/00-PLANEJAMENTO.md"
commit_checkpoint "$WT" "chore(sprintx): checkpoint de planejamento ft-01 — f5 rodada 3"
auditoria "$P/00-AUDITORIA.md" nao 9
caso "P01.6 00-AUDITORIA so no worktree: prova I barra" nao "$(sim_nao prova_i_auditoria_commitada ft-01)"
caso "P01.6 e o portao inteiro barra"                   nao "$(sim_nao gate_terminal_pre_f6 "$BASE" ft-01 buildx/t3 "$WT")"
caso "P01.6 com a CONTROL parada"                       "$BASE" "$(git rev-parse HEAD)"
fi  # terminal

if bloco x1; then
echo
echo "P0.1 — X1: terminal pré-F6 sobrevive à morte da sessão"

if com_sprintx "X1"; then
  C="$(projeto_p01 x1 PR-01 PR-02 PR-03 PR-04 PR-05 PR-06 PR-07 PR-08)"; cd "$C"
  BASE="$(git rev-parse HEAD)"
  feature_nasce ft-01 "$BASE" x1; WT="$TMP_RAIZ/x1/wt-ft-01"
  PASTA="docs/sprintx/features/ft-01"
  caso "X1 feature nasce exatamente em BASE_SHA"      "$BASE" "$(git rev-parse feature/ft-01)"
  sx_f1 "$WT" ft-01
  # A F2 autônoma cria uma premissa feature-local; o checkpoint da sprintx a leva junto.
  caso "P01.25 a premissa da F2 pula so os ocupados globais" PR-09 \
    "$(proximo_pr docs/projeto/PREMISSAS.md docs/projeto/RECURSAO.md "$WT/$PASTA/BUILDX-PREMISSAS.md")"
  escreve_premissa "$WT/$PASTA/BUILDX-PREMISSAS.md" PR-09 "Sessao expira apos 8 horas"
  sx_f2 "$WT" ft-01
  caso "X1 o checkpoint da sprintx levou o BUILDX-PREMISSAS" sim \
    "$(sim_nao git cat-file -e "feature/ft-01:$PASTA/BUILDX-PREMISSAS.md")"
  sx_rodada_nao "$WT" ft-01 9
  caso "X1 primeira reprovacao: replanejar"            continuar_f3 "$(buildx_acao "$WT" ft-01)"
  sx_rodada_nao "$WT" ft-01 2 9
  caso "X1 segunda reprovacao: replanejar de novo"     continuar_f3 "$(buildx_acao "$WT" ft-01)"
  sx_f3 "$WT" ft-01; sx_f4 "$WT" ft-01

  # Terceira F5 NÃO com o checkpoint recusado: o terminal existe só no disco.
  hook_recusa liga
  sx_f5 "$WT" ft-01 nao 2 9 >/dev/null
  caso "P01.4 orcamento_esgotado no working tree"      sim "$(sim_nao grep -qx 'estado: orcamento_esgotado' "$WT/$PASTA/00-PLANEJAMENTO.md")"
  caso "P01.4 mas nao no HEAD: prova F barra"          nao "$(sim_nao prova_f_terminal_commitado ft-01)"
  caso "P01.4 a sprintx responde CHECKPOINT: prova G barra" nao "$(sim_nao prova_g_sprintx_terminal "$WT" ft-01)"
  caso "P01.4 o portao inteiro barra"                  nao "$(sim_nao gate_terminal_pre_f6 "$BASE" ft-01 buildx/x1 "$WT")"
  caso "P01.9 a CONTROL nao se move sem evidencia duravel" "$BASE" "$(git rev-parse HEAD)"
  caso "P01.9 nem o remoto"                            "$BASE" "$(git rev-parse origin/buildx/x1)"
  caso "P01.10 nada de RECURSAO na janela"             nao "$(sim_nao test -e docs/projeto/RECURSAO.md)"
  hook_recusa desliga
  caso "X1 a sprintx completa o checkpoint terminal"   commitado "$(chave "$(sprintx "$WT" checkpoint ft-01)" checkpoint)"

  caso "P01.5 terminal duravel: o buildx vai ao portao" terminal_pre_f6 "$(buildx_acao "$WT" ft-01)"
  caso "P01.5 orcamento_esgotado commitado + worktree limpa: portao passa" sim \
    "$(sim_nao gate_terminal_pre_f6 "$BASE" ft-01 buildx/x1 "$WT")"
  caso "X1 as tres reprovacoes contadas pela sprintx"  "reprovacoes: 3" \
    "$(git show "feature/ft-01:$PASTA/00-PLANEJAMENTO.md" | grep '^reprovacoes:')"
  caso "X1 teto declarado pelo buildx"                 sim "$(sim_nao orcamento_confere ft-01)"
  caso "X1 a sprintx nao avanca mais"                  nao "$(sim_nao sprintx "$WT" avanca ft-01 f3)"
  TIP="$(git rev-parse feature/ft-01)"

  # Morte da sessão: o worktree some.
  git worktree remove "$WT"
  caso "X1 sem worktree, o git ainda devolve o PLANEJAMENTO" sim \
    "$(sim_nao git cat-file -e "feature/ft-01:$PASTA/00-PLANEJAMENTO.md")"
  caso "X1 e a AUDITORIA terminal"                     sim "$(sim_nao git show "feature/ft-01:$PASTA/00-AUDITORIA.md")"
  caso "X1 retomada: worktree perdido, branch checkpointada" H \
    "$(retomada_decide ft-01 "$BASE" em_andamento buildx/x1)"
  reabre_worktree ft-01 "$WT"
  caso "X1 reaberto sobre a mesma branch"              "$TIP" "$(git -C "$WT" rev-parse HEAD)"
  caso "X1 retomada reconhece o terminal"              G "$(retomada_decide ft-01 "$BASE" em_andamento buildx/x1)"
  caso "X1 e o portao passa de novo, sem nada refeito" sim "$(sim_nao gate_terminal_pre_f6 "$BASE" ft-01 buildx/x1 "$WT")"
  caso "X1 a CONTROL ainda em BASE_SHA ate o registro" "$BASE" "$(git rev-parse HEAD)"

  # Um portão que falha não escreve nada: a CONTROL suja barra o registro.
  printf 'rascunho\n' > docs/projeto/RASCUNHO.md
  caso "P01.9 com a prova D falhando, o registro terminal recusa" nao \
    "$(sim_nao registra_terminal_pre_f6 "$BASE" ft-01 FT-01 buildx/x1 "$WT")"
  caso "P01.9 e a CONTROL nao se moveu"               "$BASE" "$(git rev-parse HEAD)"
  caso "P01.9 nem o mapa foi tocado"                  em_andamento "$(mapa_valor docs/projeto/MAPA.md FT-01 Status)"
  rm -f docs/projeto/RASCUNHO.md

  caso "P01.8 terminal valido: registro e commit de estado" sim \
    "$(sim_nao registra_terminal_pre_f6 "$BASE" ft-01 FT-01 buildx/x1 "$WT")"
  REC=docs/projeto/RECURSAO.md
  caso "P01.8 a CONTROL avancou exatamente um commit" "$BASE" "$(git rev-parse HEAD~1)"
  caso "P01.8 com a mensagem do bloqueio"             "chore(buildx): FT-01 bloqueada" "$(git log -1 --format=%s)"
  caso "P01.8 e publicada com push normal"            "$(git rev-parse HEAD)" "$(git rev-parse origin/buildx/x1)"
  caso "P01.8 MAPA: FT-01 bloqueada"                  bloqueada "$(mapa_valor docs/projeto/MAPA.md FT-01 Status)"
  caso "P01.8 MAPA: pelo gatilho do orcamento"        orcamento_f5_esgotado "$(mapa_valor docs/projeto/MAPA.md FT-01 'Bloqueada por')"
  caso "P01.8 PROJETO: features_bloqueadas"           1 "$(fm docs/projeto/PROJETO.md features_bloqueadas)"
  caso "P01.8 RECURSAO: PEND-01 aguardando_classificacao" aguardando_classificacao "$(pend_campo "$REC" PEND-01 estado)"
  caso "P01.8 classe null enquanto aguarda"           null "$(pend_campo "$REC" PEND-01 classe)"
  caso "P01.8 gatilho orcamento_f5_esgotado"          orcamento_f5_esgotado "$(pend_campo "$REC" PEND-01 gatilho)"
  caso "P01.8 na secao canonica"                      "$SECAO_AGUARDANDO" \
    "$(tr -d '\r' < "$REC" | awk '/^## / { s = $0 } /^### PEND-01 / { print s }')"
  caso "P01.8 o arquivo e valido"                     sim "$(sim_nao recursao_valida "$REC")"
  caso "P01.8 tudo commitado: CONTROL limpa"          sim "$(sim_nao test -z "$(git status --porcelain)")"
  EVID="$(pend_campo "$REC" PEND-01 evidencia)"
  caso "P01.8 a evidencia aponta o HEAD da feature"   sim \
    "$(sim_nao grep -q "feature/ft-01@$TIP:$PASTA/00-PLANEJAMENTO.md" <<< "$EVID")"
  caso "P01.8 e resolve pelo git o PLANEJAMENTO"      sim \
    "$(sim_nao git show "$(ref_da_evidencia "$EVID" 00-PLANEJAMENTO.md)")"
  caso "P01.8 e a AUDITORIA terminal"                 sim \
    "$(sim_nao git show "$(ref_da_evidencia "$EVID" 00-AUDITORIA.md)")"
  caso "P01.8 a branch da feature nao foi publicada"  nao \
    "$(sim_nao git rev-parse --verify --quiet refs/remotes/origin/feature/ft-01)"
  caso "P01.8 nem mexida"                             "$TIP" "$(git rev-parse feature/ft-01)"
  caso "P01.24 PR-NN da feature bloqueada reservado"  "[PR-09]" "$(pend_campo "$REC" PEND-01 pr_reservadas)"
  caso "P01.26 a premissa da bloqueada nao foi promovida" nao "$(sim_nao grep -q '^### PR-09 ' docs/projeto/PREMISSAS.md)"
  caso "P01.26 e o commit do bloqueio nao tocou o PREMISSAS" "" \
    "$(git show --format= --name-only HEAD -- docs/projeto/PREMISSAS.md)"

  # B5: qualidade de plano -> trabalho_novo -> sucessora.
  caso "P01.13 B5: ALTA de qualidade classifica trabalho_novo" sim \
    "$(sim_nao b5_classifica "$REC" PEND-01 docs/projeto/MAPA.md FT-03 ft-01-sessao-v2)"
  caso "P01.13 com a regra registrada"                orcamento_f5_esgotado/alta_qualidade_plano "$(pend_campo "$REC" PEND-01 regra_aplicada)"
  caso "P01.pend pendencia em_resolucao"               em_resolucao "$(pend_campo "$REC" PEND-01 estado)"
  caso "P01.pend com destino na sucessora"             FT-03 "$(pend_campo "$REC" PEND-01 destino)"
  caso "P01.15 sucessora com slug novo"               ft-01-sessao-v2 "$(mapa_valor docs/projeto/MAPA.md FT-03 Slug)"
  caso "P01.15 origem recursao"                       recursao "$(mapa_valor docs/projeto/MAPA.md FT-03 Origem)"
  caso "P01.15 sucede FT-01"                          FT-01 "$(mapa_valor docs/projeto/MAPA.md FT-03 Sucede)"
  caso "P01.15 nasce pendente"                        pendente "$(mapa_valor docs/projeto/MAPA.md FT-03 Status)"
  caso "P01.16 a feature velha continua bloqueada"    bloqueada "$(mapa_valor docs/projeto/MAPA.md FT-01 Status)"
  caso "P01.16 reusar o slug velho e recusado"        nao \
    "$(sim_nao cria_sucessora "$REC" PEND-01 docs/projeto/MAPA.md FT-04 ft-01 x)"
  caso "P01.20 nenhuma classe replanejamento escrita" "" "$(grep -r 'classe: replanejamento' docs/projeto || true)"
  caso "P01.8 o RECURSAO segue valido depois do B5"   sim "$(sim_nao recursao_valida "$REC")"
  fm_incrementa "$REC" ciclo_atual
  git add -A; git commit -q -m "chore(buildx): ciclo 2 da recursão"; git push -q origin buildx/x1

  # B4 da sucessora: nasce do HEAD atual, não da base antiga.
  mapa_define docs/projeto/MAPA.md FT-03 Status em_andamento
  git add -A; git commit -q -m "chore(buildx): FT-03 em andamento"; git push -q origin buildx/x1
  BASE2="$(git rev-parse HEAD)"
  caso "P01.17 caminho A da sucessora: a branch nova nao existe" sim "$(sim_nao caminho_a_livre ft-01-sessao-v2)"
  feature_nasce ft-01-sessao-v2 "$BASE2" x1; WT2="$TMP_RAIZ/x1/wt-ft-01-sessao-v2"
  caso "P01.17 sucessora nasce exatamente no HEAD atual da CONTROL" "$BASE2" "$(git rev-parse feature/ft-01-sessao-v2)"
  caso "P01.17 que ja contem o bloqueio registrado"   sim "$(sim_nao git merge-base --is-ancestor "$BASE" feature/ft-01-sessao-v2)"
  caso "P01.17 e nao carrega os checkpoints da velha" nao "$(sim_nao git merge-base --is-ancestor feature/ft-01 feature/ft-01-sessao-v2)"
  caso "P01.25 premissa nova da sucessora pula o PR-09 reservado" PR-10 \
    "$(proximo_pr docs/projeto/PREMISSAS.md "$REC" "$WT2/docs/sprintx/features/ft-01-sessao-v2/BUILDX-PREMISSAS.md")"

  # A sucessora entrega: F1-F5 real, F6 simulada, ff-only.
  sx_f1 "$WT2" ft-01-sessao-v2
  escreve_premissa "$WT2/docs/sprintx/features/ft-01-sessao-v2/BUILDX-PREMISSAS.md" PR-10 "Sessao expira apos 4 horas"
  sx_f2 "$WT2" ft-01-sessao-v2; sx_f3 "$WT2" ft-01-sessao-v2; sx_f4 "$WT2" ft-01-sessao-v2
  sx_f5 "$WT2" ft-01-sessao-v2 sim >/dev/null
  caso "X1 sucessora aprovada: F6"                    f6 "$(buildx_acao "$WT2" ft-01-sessao-v2)"
  mkdir -p "$WT2/src" "$WT2/docs/entregas/ft-01-sessao-v2"
  printf 'codigo\n' > "$WT2/src/sessao.ts"
  printf 'estado: entregue\nportao: pronto\npush_feito: true\n' > "$WT2/docs/entregas/ft-01-sessao-v2/ENTREGA.md"
  git -C "$WT2" add -A; git -C "$WT2" commit -q -m "feat: T-01.01" -m "Task: T-01.01"
  mergex_publica ft-01-sessao-v2
  caso "X1 sucessora passa nas seis provas"           sim "$(sim_nao provas_abcdef "$BASE2" ft-01-sessao-v2 buildx/x1 "$WT2")"
  caso "X1 e integra por ff-only"                     sim "$(sim_nao integrar feature/ft-01-sessao-v2)"
  promover_premissas "docs/sprintx/features/ft-01-sessao-v2/BUILDX-PREMISSAS.md" docs/projeto/PREMISSAS.md
  mapa_define docs/projeto/MAPA.md FT-03 Status entregue
  resolve_por_entrega "$REC" FT-03
  git add -A; git commit -q -m "chore(buildx): FT-03 entregue"
  caso "P01.pend a sucessora entregue resolve a pendencia" resolvida "$(pend_campo "$REC" PEND-01 estado)"
  caso "P01.pend na secao Resolvido nos ciclos"        "$SECAO_RESOLVIDO" \
    "$(tr -d '\r' < "$REC" | awk '/^## / { s = $0 } /^### PEND-01 / { print s }')"
  caso "P01.26 a premissa da sucessora foi promovida" sim "$(sim_nao grep -q '^### PR-10 ' docs/projeto/PREMISSAS.md)"
  caso "P01.26 e a da bloqueada continua fora"        nao "$(sim_nao grep -q '^### PR-09 ' docs/projeto/PREMISSAS.md)"
  caso "P01.16 FT-01 continua bloqueada para sempre"  bloqueada "$(mapa_valor docs/projeto/MAPA.md FT-01 Status)"
  caso "P01.16 e sua branch nunca foi integrada"      nao "$(sim_nao git merge-base --is-ancestor feature/ft-01 HEAD)"
  caso "X1 o RECURSAO final e valido"                 sim "$(sim_nao recursao_valida "$REC")"
fi
fi  # x1

if bloco recursao; then
echo
echo "P0.1 — B5: tabela gatilho → classe, laço, teto, seções e PR-NN"

AUDS="$TMP_RAIZ/auditorias"; mkdir -p "$AUDS"
auditoria "$AUDS/7.md" nao 7 9;   auditoria "$AUDS/8.md" nao 8 2
auditoria "$AUDS/q.md" nao 2 9 3; auditoria "$AUDS/78.md" nao 8 9 7
caso "P01.11 ALTA [item 7] -> decisao_humana"         "decisao_humana orcamento_f5_esgotado/alta_item_7" "$(classe_orcamento < "$AUDS/7.md")"
caso "P01.12 ALTA [item 8] -> recurso_externo"        "recurso_externo orcamento_f5_esgotado/alta_item_8" "$(classe_orcamento < "$AUDS/8.md")"
caso "P01.13 ALTA de qualidade de plano -> trabalho_novo" "trabalho_novo orcamento_f5_esgotado/alta_qualidade_plano" "$(classe_orcamento < "$AUDS/q.md")"
caso "P01.14 mistura item 7 + item 8 -> decisao_humana" "decisao_humana orcamento_f5_esgotado/alta_item_7" "$(classe_orcamento < "$AUDS/78.md")"
auditoria "$AUDS/sim.md" sim
caso "P01.11 auditoria sem ALTA nao classifica: parada" nao "$(sim_nao classe_orcamento < "$AUDS/sim.md")"
caso "P01.11 a clausula central sai dos prefixos"     "[item 2][fraco:criterio],[item 9],[item 3]" "$(clausula_central_auditoria < "$AUDS/q.md")"

caso "P01.tabela regra de negocio -> decisao_humana"     "decisao_humana regra_de_negocio_nao_declarada" "$(classe_da_tabela regra_de_negocio_nao_declarada)"
caso "P01.tabela recurso externo -> recurso_externo"     "recurso_externo recurso_externo_ausente" "$(classe_da_tabela recurso_externo_ausente)"
caso "P01.tabela incompatibilidade -> decisao_humana"    "decisao_humana incompatibilidade_de_versao" "$(classe_da_tabela incompatibilidade_de_versao)"
caso "P01.tabela dependencia segue a raiz"               "recurso_externo dependencia_nao_integrada/segue_raiz" "$(classe_da_tabela dependencia_nao_integrada recurso_externo)"
caso "P01.tabela dependencia sem raiz -> decisao_humana" "decisao_humana dependencia_nao_integrada/raiz_ambigua" "$(classe_da_tabela dependencia_nao_integrada '')"
caso "P01.tabela entrega bloqueada pela causa enumerada"  "trabalho_novo entrega_bloqueada/causa_suite_reprovada" "$(classe_da_causa suite_reprovada)"
caso "P01.tabela falha_tecnica nao e causa: nao classifica" nao "$(sim_nao classe_da_causa falha_tecnica)"
caso "P01.tabela entrega bloqueada sem causa commitada"  "decisao_humana entrega_bloqueada/causa_nao_commitada" "$(classe_da_causa ausente)"
caso "P01.tabela entrega interrompida resolvivel"        "trabalho_novo entrega_interrompida/resolvivel_sem_decisao" "$(classe_da_tabela entrega_interrompida null)"
caso "P01.tabela entrega interrompida pela causa"        "decisao_humana entrega_interrompida/causa_regra_de_negocio_nao_declarada" "$(classe_da_tabela entrega_interrompida regra_de_negocio_nao_declarada)"
caso "P01.tabela gatilho desconhecido nao classifica"    nao "$(sim_nao classe_da_tabela palpite)"

TPL="$REPO/.claude/skills/buildx/assets/TEMPLATE-RECURSAO.md"
caso "P01.22 o template tem exatamente as cinco secoes, na ordem" "$(secoes_canonicas)" "$(secoes_de "$TPL")"
caso "P01.22 a secao Aguardando classificacao existe"  sim "$(sim_nao grep -qx "$SECAO_AGUARDANDO" <(tr -d '\r' < "$TPL"))"

RC="$TMP_RAIZ/rec-unit"; mkdir -p "$RC"; cd "$RC"; git init -q . 2>/dev/null
R="$RC/RECURSAO.md"; M="$RC/MAPA.md"
recursao_nova "$R" unit
printf '# Mapa\n' > "$M"
mapa_feature "$M" FT-01 cadastro bloqueada descricao
caso "P01.22 RECURSAO novo nasce valido, com as cinco secoes" sim "$(sim_nao recursao_valida "$R")"
P1="$(pend_nova "$R" "cadastro esgotou" orcamento_f5_esgotado FT-01 'feature/cadastro@abc:x/00-AUDITORIA.md' '[item 2][fraco:criterio],[item 9]' '[PR-09]' null null)"
caso "P01.20 classe replanejamento nao se escreve"    nao "$(sim_nao pend_define "$R" "$P1" classe replanejamento)"
caso "P01.20 e o arquivo continua com classe null"    null "$(pend_campo "$R" "$P1" classe)"
cp "$R" "$RC/invent.md"; printf '\n## Aberto — aguardando classificação do B5\n' >> "$RC/invent.md"
caso "P01.23 secao inventada num arquivo: rejeitada"  nao "$(sim_nao recursao_valida "$RC/invent.md")"
sed "s/^- estado: aguardando_classificacao$/- estado: decisao_humana/" "$R" > "$RC/fora.md"
caso "P01.23 bloco fora da secao do seu estado: rejeitado" nao "$(sim_nao recursao_valida "$RC/fora.md")"

# O caso do Conselho: a seção que a execução real precisou inventar.
cat > "$RC/conselho.md" <<'FIM'
---
kind: recursao
---

## Aberto — aguardando classificação do B5

### PEND-01 — FT-02 bloqueada

- estado: aguardando_classificacao
FIM
caso "P01.23 o RECURSAO do piloto real e rejeitado"   nao "$(sim_nao recursao_valida "$RC/conselho.md")"

cat > "$RC/legado.md" <<'FIM'
## Aberto — o que exige decisão humana

### PEND-04 — relatorio

**Classe:** `replanejamento`
**Origem:** FT-04
FIM
caso "P01.21 RECURSAO antigo: replanejamento e lido como trabalho_novo" trabalho_novo "$(classe_legada "$RC/legado.md" PEND-04)"
caso "P01.21 classe_lida traduz so o legado"           decisao_humana "$(classe_lida decisao_humana)"

# Detector de laço: a sucessora bloqueia pelo mesmo gatilho e pela mesma cláusula.
pend_define "$R" "$P1" estado em_resolucao; pend_define "$R" "$P1" classe trabalho_novo
pend_define "$R" "$P1" regra_aplicada orcamento_f5_esgotado/alta_qualidade_plano; pend_define "$R" "$P1" destino FT-03
recursao_reordena "$R"
P2="$(pend_nova "$R" "sucessora esgotou" orcamento_f5_esgotado FT-03 'feature/cadastro-v2@def:x/00-AUDITORIA.md' '[item 2][fraco:criterio],[item 9]' '[]' "$P1" null)"
caso "P01.18 mesmo gatilho e clausula: detector dispara" sim "$(sim_nao b5_classifica "$R" "$P2" "$M" FT-05 cadastro-v3)"
caso "P01.18 a raiz vai para decisao_humana"           decisao_humana "$(pend_campo "$R" "$P1" estado)"
caso "P01.18 com a regra do laco"                      laco_detectado "$(pend_campo "$R" "$P1" regra_aplicada)"
caso "P01.18 e nenhuma sucessora nova nasce"           "" "$(mapa_valor "$M" FT-05 Status)"
caso "P01.18 a filha segue a raiz"                     decisao_humana "$(pend_campo "$R" "$P2" estado)"
caso "P01.18 o arquivo continua valido"                sim "$(sim_nao recursao_valida "$R")"

P3="$(pend_nova "$R" "outra sucessora" orcamento_f5_esgotado FT-06 'feature/x@1:x/00-AUDITORIA.md' '[item 4]' '[]' "$P1" null)"
caso "P01.18 clausula diferente: detector nao dispara"  nao "$(sim_nao detector_laco "$R" "$P3")"

# Teto: no ciclo 3, o resolvível vira decisão humana.
git -C "$RC" init -q 2>/dev/null
mkdir -p "$RC/x"; auditoria "$RC/x/00-AUDITORIA.md" nao 2 9; git -C "$RC" add x/00-AUDITORIA.md; git -C "$RC" -c user.email=t@t -c user.name=t commit -q -m aud
SHA_Q="$(git -C "$RC" rev-parse HEAD)"
P4="$(pend_nova "$R" "no teto" orcamento_f5_esgotado FT-01 "feature/cadastro@$SHA_Q:x/00-AUDITORIA.md" '[item 2]' '[]' null null)"
fm_define "$R" ciclo_atual 3
caso "P01.19 teto de 3 ciclos: trabalho_novo vira decisao_humana" sim "$(sim_nao b5_classifica "$R" "$P4" "$M" FT-07 cadastro-v4)"
caso "P01.19 estado decisao_humana"                    decisao_humana "$(pend_campo "$R" "$P4" estado)"
caso "P01.19 nota teto_de_ciclos_atingido"             teto_de_ciclos_atingido "$(pend_campo "$R" "$P4" nota)"
caso "P01.19 e nenhuma sucessora nasce"                "" "$(mapa_valor "$M" FT-07 Status)"
fm_define "$R" ciclo_atual 2
P5="$(pend_nova "$R" "antes do teto" orcamento_f5_esgotado FT-01 "feature/cadastro@$SHA_Q:x/00-AUDITORIA.md" '[item 2]' '[]' null null)"
caso "P01.19 antes do teto a mesma evidencia gera sucessora" sim "$(sim_nao b5_classifica "$R" "$P5" "$M" FT-08 cadastro-v5)"
caso "P01.19 em_resolucao"                             em_resolucao "$(pend_campo "$R" "$P5" estado)"

# PR-NN: ocupado é ocupado.
printf '# Premissas\n\n### PR-01 — a\n\n### PR-08 — b\n' > "$RC/PREMISSAS.md"
caso "P01.25 sem reserva, o proximo seria PR-09"       PR-09 "$(proximo_pr "$RC/PREMISSAS.md" /dev/null /dev/null)"
caso "P01.25 com PR-09 reservado no RECURSAO, pula para PR-10" PR-10 "$(proximo_pr "$RC/PREMISSAS.md" "$R" /dev/null)"
escreve_premissa "$RC/feat.md" PR-10 "ja nesta feature"
caso "P01.25 e o que ja existe na feature tambem conta" PR-11 "$(proximo_pr "$RC/PREMISSAS.md" "$R" "$RC/feat.md")"
caso "P01.24 nenhum artefato morto foi renumerado"    "[PR-09]" "$(pend_campo "$R" "$P1" pr_reservadas)"
cd "$REPO"
fi  # recursao

if bloco convergencia; then
echo
echo "P0.1 — B5: a raiz acompanha a sucessora, e ciclo sem conversão não repete"

# Auditorias terminais commitadas: a evidência que a tabela lê pelo git.
CV="$TMP_RAIZ/convergencia"; mkdir -p "$CV"; cd "$CV"; git init -q . 2>/dev/null
for a in "q 2 9" "r 3" "s 4" "h 7"; do
  set -- $a; mkdir -p "$CV/aud/$1"; auditoria "$CV/aud/$1/00-AUDITORIA.md" nao "${@:2}"
done
git -c core.autocrlf=false add aud; git -c user.email=t@t -c user.name=t commit -q -m auditorias
CV_SHA="$(git rev-parse HEAD)"

# cv_ev <slug> <auditoria> — a evidência no formato do registro terminal.
cv_ev() { printf 'feature/%s@%s:aud/%s/00-PLANEJAMENTO.md ; feature/%s@%s:aud/%s/00-AUDITORIA.md\n' "$1" "$CV_SHA" "$2" "$1" "$CV_SHA" "$2"; }

# cv_bloqueia <dir> <FT> <slug> <auditoria> <raiz> — o commit do bloqueio no B4, sem o git.
cv_bloqueia() {
  local id
  id="$(pend_nova "$1/RECURSAO.md" "$2 esgotou" orcamento_f5_esgotado "$2" "$(cv_ev "$3" "$4")" \
        "$(clausula_central_auditoria < "$CV/aud/$4/00-AUDITORIA.md")" '[]' "$5" null)" || return 1
  mapa_define "$1/MAPA.md" "$2" Status bloqueada
  mapa_define "$1/MAPA.md" "$2" "Pendência" "$id"
  printf '%s\n' "$id"
}

# cv_ciclo2 <nome> [n-raizes: 1|2] — ciclo 1 inteiro: FT-01 (e FT-02) esgotaram por
# qualidade de plano, o B5 criou FT-03 (e FT-04), e o ciclo 2 começou.
cv_ciclo2() {
  local d="$CV/$1"; mkdir -p "$d"
  recursao_nova "$d/RECURSAO.md" conv
  printf '# Mapa\n' > "$d/MAPA.md"
  mapa_feature "$d/MAPA.md" FT-01 cadastro em_andamento descricao
  cv_bloqueia "$d" FT-01 cadastro q null >/dev/null
  b5_classifica "$d/RECURSAO.md" PEND-01 "$d/MAPA.md" FT-03 cadastro-v2 || return 1
  if [ "${2:-1}" = 2 ]; then
    mapa_feature "$d/MAPA.md" FT-02 relatorio em_andamento descricao
    cv_bloqueia "$d" FT-02 relatorio q null >/dev/null
    b5_classifica "$d/RECURSAO.md" PEND-02 "$d/MAPA.md" FT-04 relatorio-v2 || return 1
  fi
  fm_incrementa "$d/RECURSAO.md" ciclo_atual
}

# cv_entrega <dir> <FT> — o commit "FT-NN entregue" do passo 7.
cv_entrega() { mapa_define "$1/MAPA.md" "$2" Status entregue && recursao_acompanha "$1/RECURSAO.md" "$1/MAPA.md"; }

secao_de() { tr -d '\r' < "$1" | awk -v id="$2" '/^## / { s = $0 } index($0, "### " id " ") == 1 { print s }'; }

# --- Regra A: a raiz acompanha a sucessora ---

cv_ciclo2 a; D="$CV/a"; R="$D/RECURSAO.md"
caso "A0 PEND-01 em_resolucao com destino na sucessora" "em_resolucao FT-03" \
  "$(pend_campo "$R" PEND-01 estado) $(pend_campo "$R" PEND-01 destino)"
caso "A1 sucessora pendente: acompanhar nao falha"    sim "$(sim_nao recursao_acompanha "$R" "$D/MAPA.md")"
caso "A1 sucessora pendente: raiz continua em_resolucao" em_resolucao "$(pend_campo "$R" PEND-01 estado)"
caso "A1 e sem resolvida_em"                          null "$(pend_campo "$R" PEND-01 resolvida_em)"
mapa_define "$D/MAPA.md" FT-03 Status em_andamento
caso "A2 sucessora em_andamento: acompanhar nao falha" sim "$(sim_nao recursao_acompanha "$R" "$D/MAPA.md")"
caso "A2 sucessora em_andamento: raiz continua em_resolucao" em_resolucao "$(pend_campo "$R" PEND-01 estado)"
caso "A2 na secao Em resolucao"                       "$SECAO_RESOLUCAO" "$(secao_de "$R" PEND-01)"
caso "A3 sucessora entregue: o commit de estado acompanha" sim "$(sim_nao cv_entrega "$D" FT-03)"
caso "A3 raiz resolvida"                              resolvida "$(pend_campo "$R" PEND-01 estado)"
caso "A3 resolvida_em e uma data"                     sim "$(sim_nao grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' <<< "$(pend_campo "$R" PEND-01 resolvida_em)")"
caso "A3 o destino continua dizendo por qual FT"      FT-03 "$(pend_campo "$R" PEND-01 destino)"
caso "A3 na secao Resolvido nos ciclos"               "$SECAO_RESOLVIDO" "$(secao_de "$R" PEND-01)"
caso "A3 contadores: 0 abertas, 1 resolvida"          "0 1" "$(fm "$R" pendencias_abertas) $(fm "$R" pendencias_resolvidas)"
caso "A3 o RECURSAO continua valido"                  sim "$(sim_nao recursao_valida "$R")"
cp "$R" "$D/antes.md"; recursao_acompanha "$R" "$D/MAPA.md"
caso "A3 acompanhar de novo nao muda nada"            sim "$(sim_nao cmp -s "$R" "$D/antes.md")"
caso "B1 ciclo com sucessora entregue: converteu"     sim "$(ciclo_converteu "$R" "$D/MAPA.md")"
caso "B2 e a pendencia que ela resolvia esta resolvida" resolvida "$(pend_campo "$R" "$(mapa_valor "$D/MAPA.md" FT-03 Pendência)" estado)"

cv_ciclo2 b2; D="$CV/b2"; R="$D/RECURSAO.md"
mapa_define "$D/MAPA.md" FT-03 Status entregue
caso "B2 entregue sem a pendencia resolvida nao conta como conversao: parada" nao \
  "$(sim_nao ciclo_converteu "$R" "$D/MAPA.md")"

cv_ciclo2 a4; D="$CV/a4"; R="$D/RECURSAO.md"
P="$(cv_bloqueia "$D" FT-03 cadastro-v2 q PEND-01)"
caso "A4 a sucessora bloqueada registra a filha com raiz" "PEND-02 PEND-01" "$P $(pend_campo "$R" "$P" raiz)"
caso "A4 mesmo gatilho e mesma clausula: o B5 classifica" sim "$(sim_nao b5_classifica "$R" "$P" "$D/MAPA.md" FT-05 cadastro-v3)"
caso "A4 raiz decisao_humana"                         decisao_humana "$(pend_campo "$R" PEND-01 estado)"
caso "A4 regra laco_detectado"                        laco_detectado "$(pend_campo "$R" PEND-01 regra_aplicada)"
caso "A4 nota laco_detectado"                         laco_detectado "$(pend_campo "$R" PEND-01 nota)"
caso "A4 a raiz nao foi resolvida"                    null "$(pend_campo "$R" PEND-01 resolvida_em)"
caso "A4 nenhuma sucessora nova"                      "" "$(mapa_valor "$D/MAPA.md" FT-05 Status)"
caso "A4 o RECURSAO continua valido"                  sim "$(sim_nao recursao_valida "$R")"

cv_ciclo2 a5; D="$CV/a5"; R="$D/RECURSAO.md"
P="$(cv_bloqueia "$D" FT-03 cadastro-v2 h PEND-01)"
caso "A5 clausula diferente: nao e laco"              nao "$(sim_nao eh_laco "$R" "$P")"
caso "A5 a filha classifica pela tabela"              sim "$(sim_nao b5_classifica "$R" "$P" "$D/MAPA.md" FT-05 cadastro-v3)"
caso "A5 filha decisao_humana pelo [item 7]"          "decisao_humana orcamento_f5_esgotado/alta_item_7" \
  "$(pend_campo "$R" "$P" estado) $(pend_campo "$R" "$P" regra_aplicada)"
caso "A5 a raiz NAO foi marcada resolvida"            decisao_humana "$(pend_campo "$R" PEND-01 estado)"
caso "A5 a raiz segue a filha, com a regra dela"      "orcamento_f5_esgotado/alta_item_7 segue $P" \
  "$(pend_campo "$R" PEND-01 regra_aplicada) $(pend_campo "$R" PEND-01 nota)"
caso "A5 sem resolvida_em e nos contadores abertas"   "null 2 0" \
  "$(pend_campo "$R" PEND-01 resolvida_em) $(fm "$R" pendencias_abertas) $(fm "$R" pendencias_resolvidas)"
caso "A5 o RECURSAO continua valido"                  sim "$(sim_nao recursao_valida "$R")"

cv_ciclo2 a5g; D="$CV/a5g"; R="$D/RECURSAO.md"
P="$(pend_nova "$R" "FT-03 sem credencial" recurso_externo_ausente FT-03 "feature/cadastro-v2@$CV_SHA:aud/h/00-AUDITORIA.md" PR-NN '[]' PEND-01 null)"
mapa_define "$D/MAPA.md" FT-03 Status bloqueada; mapa_define "$D/MAPA.md" FT-03 "Pendência" "$P"
caso "A5 gatilho diferente: a filha classifica"       sim "$(sim_nao b5_classifica "$R" "$P" "$D/MAPA.md" FT-05 cadastro-v3)"
caso "A5 gatilho diferente: raiz recurso_externo, nunca resolvida" "recurso_externo null" \
  "$(pend_campo "$R" PEND-01 estado) $(pend_campo "$R" PEND-01 resolvida_em)"
caso "A5 gatilho diferente: na secao do recurso externo" "$SECAO_EXTERNO" "$(secao_de "$R" PEND-01)"

cv_ciclo2 a6; D="$CV/a6"; R="$D/RECURSAO.md"
pend_define "$R" PEND-01 destino FT-99; mapa_define "$D/MAPA.md" FT-03 Status entregue
cp "$R" "$D/antes.md"
caso "A6 destino fora do MAPA: inconsistencia explicita" nao "$(sim_nao recursao_acompanha "$R" "$D/MAPA.md")"
caso "A6 e nada foi gravado"                          sim "$(sim_nao cmp -s "$R" "$D/antes.md")"
caso "A6 a raiz nao inventou estado"                  "em_resolucao null" \
  "$(pend_campo "$R" PEND-01 estado) $(pend_campo "$R" PEND-01 resolvida_em)"

# --- Duas raízes no mesmo ciclo: uma converte, a outra não ---

cv_ciclo2 dup 2; D="$CV/dup"; R="$D/RECURSAO.md"
P="$(cv_bloqueia "$D" FT-03 cadastro-v2 r PEND-01)"
cv_entrega "$D" FT-04
caso "B5 FT-04 entregou: PEND-02 resolvida"           resolvida "$(pend_campo "$R" PEND-02 estado)"
caso "B5 e FT-03 bloqueou: PEND-01 ainda em_resolucao" em_resolucao "$(pend_campo "$R" PEND-01 estado)"
caso "B5 o ciclo, inteiro, converteu"                 sim "$(ciclo_converteu "$R" "$D/MAPA.md")"
caso "B5 a filha resolvivel ganha sucessora"          sim "$(sim_nao b5_classifica "$R" "$P" "$D/MAPA.md" FT-05 cadastro-v3)"
caso "B5 filha em_resolucao em FT-05"                 "em_resolucao FT-05" "$(pend_campo "$R" "$P" estado) $(pend_campo "$R" "$P" destino)"
caso "A5 clausula diferente e trabalho_novo: a raiz acompanha o destino novo" "em_resolucao FT-05" \
  "$(pend_campo "$R" PEND-01 estado) $(pend_campo "$R" PEND-01 destino)"
RESOLVIDA_EM="$(pend_campo "$R" PEND-02 resolvida_em)"
fm_incrementa "$R" ciclo_atual
mapa_define "$D/MAPA.md" FT-05 Status em_andamento
cp "$R" "$D/pre.md"; cp "$D/MAPA.md" "$D/pre-mapa.md"

# A7: a entrega de FT-05 resolve a cadeia dela, e só ela.
caso "A7 FT-05 entregue: o commit de estado acompanha" sim "$(sim_nao cv_entrega "$D" FT-05)"
caso "A7 filha e raiz dela resolvidas"                "resolvida resolvida" "$(pend_campo "$R" "$P" estado) $(pend_campo "$R" PEND-01 estado)"
caso "A7 a outra raiz nao foi tocada"                 "resolvida $RESOLVIDA_EM FT-04" \
  "$(pend_campo "$R" PEND-02 estado) $(pend_campo "$R" PEND-02 resolvida_em) $(pend_campo "$R" PEND-02 destino)"
caso "A7 contadores: 0 abertas, 3 resolvidas"         "0 3" "$(fm "$R" pendencias_abertas) $(fm "$R" pendencias_resolvidas)"
caso "A7 o RECURSAO final e valido"                   sim "$(sim_nao recursao_valida "$R")"
cp "$D/pre.md" "$R"; cp "$D/pre-mapa.md" "$D/MAPA.md"
mapa_feature "$D/MAPA.md" FT-06 outra-raiz em_andamento descricao
P9="$(pend_nova "$R" "outra raiz" violacao_de_convencao FT-06 "feature/outra@$CV_SHA:aud/s/00-AUDITORIA.md" B-01 '[]' null null)"
# O acidente: outra raiz, sem parentesco com a filha, gravada com o mesmo destino.
pend_classifica "$R" "$P9" trabalho_novo violacao_de_convencao; pend_define "$R" "$P9" estado em_resolucao
pend_define "$R" "$P9" destino FT-05; recursao_reordena "$R"
caso "A7 o acidente montado: duas raizes em_resolucao em FT-05" "em_resolucao em_resolucao" \
  "$(pend_campo "$R" "$P9" estado) $(pend_campo "$R" PEND-01 estado)"
mapa_define "$D/MAPA.md" FT-05 Status entregue; cp "$R" "$D/antes.md"
caso "A7 duas raizes diferentes no mesmo destino: parada" nao "$(sim_nao recursao_acompanha "$R" "$D/MAPA.md")"
caso "A7 e nenhuma das duas foi resolvida por acidente" sim "$(sim_nao cmp -s "$R" "$D/antes.md")"

# --- Regra B: ciclo inteiro sem conversão ---

cv_ciclo2 c1; D="$CV/c1"; R="$D/RECURSAO.md"
caso "B.ciclo 1 nao roda sucessora: o detector nao se aplica" nao_se_aplica \
  "$(fm "$R" ciclo_atual >/dev/null; fm_define "$R" ciclo_atual 1; ciclo_converteu "$R" "$D/MAPA.md"; fm_define "$R" ciclo_atual 2)"
caso "B.sucessora do ciclo ainda pendente: o ciclo nao terminou, parada" nao "$(sim_nao ciclo_converteu "$R" "$D/MAPA.md")"

cv_ciclo2 b3 2; D="$CV/b3"; R="$D/RECURSAO.md"
mapa_feature "$D/MAPA.md" FT-06 integracao em_andamento descricao
fm_define "$R" ciclo_atual 1
PX="$(pend_nova "$R" "FT-06 sem chave" recurso_externo_ausente FT-06 "feature/integracao@$CV_SHA:aud/h/00-AUDITORIA.md" chave '[]' null null)"
b5_classifica "$R" "$PX" "$D/MAPA.md" >/dev/null
fm_define "$R" ciclo_atual 2
P3="$(cv_bloqueia "$D" FT-03 cadastro-v2 r PEND-01)"
P4="$(cv_bloqueia "$D" FT-04 relatorio-v2 s PEND-02)"
caso "B3 nenhuma entrega e nenhuma resolucao: nao converteu" nao "$(ciclo_converteu "$R" "$D/MAPA.md")"
caso "B3 a filha resolvivel e classificada"           sim "$(sim_nao b5_classifica "$R" "$P3" "$D/MAPA.md" FT-07 cadastro-v3)"
caso "B3 detector dispara: decisao_humana"            decisao_humana "$(pend_campo "$R" "$P3" estado)"
caso "B3 regra laco_detectado/ciclo_sem_conversao"    laco_detectado/ciclo_sem_conversao "$(pend_campo "$R" "$P3" regra_aplicada)"
caso "B3 nota laco_detectado"                         laco_detectado "$(pend_campo "$R" "$P3" nota)"
caso "B3 nenhuma sucessora nasce"                     "" "$(mapa_valor "$D/MAPA.md" FT-07 Status)"
caso "B3 a raiz acompanha"                            "decisao_humana segue $P3" "$(pend_campo "$R" PEND-01 estado) $(pend_campo "$R" PEND-01 nota)"
caso "B3 a outra filha, no mesmo ciclo, tambem"       sim "$(sim_nao b5_classifica "$R" "$P4" "$D/MAPA.md" FT-08 relatorio-v3)"
caso "B3 e sem sucessora"                             "decisao_humana laco_detectado/ciclo_sem_conversao " \
  "$(pend_campo "$R" "$P4" estado) $(pend_campo "$R" "$P4" regra_aplicada) $(mapa_valor "$D/MAPA.md" FT-08 Status)"
caso "B3 recurso_externo anterior intocado"           "recurso_externo recurso_externo_ausente null" \
  "$(pend_campo "$R" "$PX" estado) $(pend_campo "$R" "$PX" regra_aplicada) $(pend_campo "$R" "$PX" nota)"
caso "B3 o RECURSAO continua valido"                  sim "$(sim_nao recursao_valida "$R")"
caso "B6 disparou no ciclo 2, abaixo do teto 3, sem regra de teto" "2 3 0" \
  "$(fm "$R" ciclo_atual) $(fm "$R" teto_ciclos) $(grep -c 'teto_de_ciclos_atingido' "$R")"

cp "$R" "$D/antes.md"; cp "$D/MAPA.md" "$D/antes-mapa.md"
caso "B7 reclassificar a mesma pendencia e recusado"  nao "$(sim_nao b5_classifica "$R" "$P3" "$D/MAPA.md" FT-07 cadastro-v3)"
raiz_acompanha "$R" "$P3"; raiz_acompanha "$R" "$P4"; recursao_acompanha "$R" "$D/MAPA.md"
caso "B7 detector, raiz e acompanhamento repetidos: RECURSAO identico" sim "$(sim_nao cmp -s "$R" "$D/antes.md")"
caso "B7 e MAPA identico"                             sim "$(sim_nao cmp -s "$D/MAPA.md" "$D/antes-mapa.md")"
caso "B7 a mesma resposta do detector"                nao "$(ciclo_converteu "$R" "$D/MAPA.md")"

cv_ciclo2 b4; D="$CV/b4"; R="$D/RECURSAO.md"
P="$(cv_bloqueia "$D" FT-03 cadastro-v2 r PEND-01)"
caso "B4 a sucessora bloqueou no mesmo ramo, clausula nova: nao e laco" nao "$(sim_nao eh_laco "$R" "$P")"
caso "B4 a tabela ainda diria trabalho_novo"          trabalho_novo "$(classe_da_tabela orcamento_f5_esgotado "$CV_SHA:aud/r/00-AUDITORIA.md" | cut -d' ' -f1)"
caso "B4 mas nada entregou: detector dispara"         sim "$(sim_nao b5_classifica "$R" "$P" "$D/MAPA.md" FT-05 cadastro-v3)"
caso "B4 decisao_humana, sem outra sucessora"         "decisao_humana laco_detectado/ciclo_sem_conversao " \
  "$(pend_campo "$R" "$P" estado) $(pend_campo "$R" "$P" regra_aplicada) $(mapa_valor "$D/MAPA.md" FT-05 Status)"
caso "B4 a raiz acompanha, sem resolvida_em"          "decisao_humana null" "$(pend_campo "$R" PEND-01 estado) $(pend_campo "$R" PEND-01 resolvida_em)"

cv_ciclo2 teto; D="$CV/teto"; R="$D/RECURSAO.md"
fm_define "$R" teto_ciclos 2
P="$(cv_bloqueia "$D" FT-03 cadastro-v2 r PEND-01)"
b5_classifica "$R" "$P" "$D/MAPA.md" FT-05 cadastro-v3 >/dev/null
caso "B6 no teto, sem conversao: o teto tem precedencia" teto_de_ciclos_atingido "$(pend_campo "$R" "$P" regra_aplicada)"

REF_B5="$REPO/.claude/skills/buildx/references/06-recursao.md"
caso "contrato: destino fora do MAPA e parada, no reference" sim \
  "$(sim_nao grep -qF '`destino` que não existe no `MAPA.md` é inconsistência: pare e relate' "$REF_B5")"
caso "contrato: a entrega resolve uma cadeia, e so uma"       sim "$(sim_nao grep -qF '**A entrega resolve uma cadeia, e só uma.**' "$REF_B5")"
caso "contrato: a regra do ciclo sem conversao, literal"     sim "$(sim_nao grep -qF '`regra_aplicada: laco_detectado/ciclo_sem_conversao`' "$REF_B5")"
caso "contrato: o detector nao se aplica ao ciclo 1"         sim "$(sim_nao grep -qF '**Só vale do ciclo 2 em diante.**' "$REF_B5")"
cd "$REPO"
fi  # convergencia

if bloco vivos; then
echo
echo "P0.1 — o contrato vivo não contradiz a máquina nova"

VIVOS2="$REPO/.claude/skills/buildx/SKILL.md $REPO/.claude/skills/buildx/references $REPO/.claude/skills/buildx/assets $REPO/.claude/commands $REPO/.opencode/commands $REPO/AGENTS.md $REPO/README.md"
vivo() { grep -rniE "$1" $VIVOS2 2>/dev/null | grep -v '/template/' ; }
caso "P01.40 nenhum texto vivo reabre a feature velha na F3" "" \
  "$(vivo 'feature volta (para|à) (a )?F3|volta para a F3 do sprintx|pela porta da F3|devolve a feature à F3')"
caso "P01.40 replanejamento nao e classe escrita pelo B5" "" \
  "$(vivo '\| *`?replanejamento`? *\||· `replanejamento`|\\\| replanejamento|classifica como `replanejamento`|pend[eê]ncia `replanejamento`|replanejamento +→|### `replanejamento`|resolvível por replanejamento')"
caso "P01.40 o buildx nao apaga nem regenera o plano da sprintx" "" \
  "$(vivo 'apagando o plano|apag(ue|ar|a) o plano|buildx (regera|regenera) o plano')"
caso "P01.40 RECURSAO nao e escrita dentro da janela" "" \
  "$(vivo '00-BLOQUEIOS\.md.{0,80}RECURSAO\.md|registre a pendência no .RECURSAO\.md. dizendo')"
caso "P01.40 commit a frente nao e necessariamente E1" "" \
  "$(vivo 'commits à frente são do E1|são os commits que o E1')"
caso "P01.40 o buildx nao conta a terceira reprovacao" "" \
  "$(vivo 'reprovad[oa] tr[eê]s vezes|terceira reprova[çc][aã]o do mesmo plano|Teto: dois replanejamentos|Limite: duas voltas|o replanejamento é reprovado')"
caso "P01.40 nada bloqueia sem terminal commitado" "" \
  "$(vivo 'marque .bloqueada., e deixe para o B5')"
caso "P01.40 o B5 declara as tres classes e o compat" sim \
  "$(sim_nao grep -q 'pode trazer a classe `replanejamento`. Ela é \*\*lida\*\* como `trabalho_novo`' "$REPO/.claude/skills/buildx/references/06-recursao.md")"
STATUS="$REPO/.claude/commands/buildx-status.md"
caso "P01.32 status mostra feature em planejamento" sim "$(sim_nao grep -q 'planejamento: <estado> · reprovações <n> de <teto>' "$STATUS")"
caso "P01.32 status mostra CHECKPOINT pendente"      sim "$(sim_nao grep -q 'CHECKPOINT pendente' "$STATUS")"
caso "P01.32 status mostra bloqueada aguardando classificacao" sim "$(sim_nao grep -q 'PEND-NN aguardando classificação' "$STATUS")"
caso "P01.32 status mostra pendencia em resolucao por sucessora" sim "$(sim_nao grep -q 'sucede FT-XX · resolve PEND-NN' "$STATUS")"
caso "P01.32 e o MAPA nao ganhou estado novo"        sim \
  "$(sim_nao grep -q '^| `status` (feature) | `pendente` · `em_andamento` · `entregue` · `bloqueada` |' "$REPO/.claude/skills/buildx/references/00-schema.md")"
caso "P01.40 o enum vivo de classe tem so as tres" sim \
  "$(sim_nao grep -q '^| `classe` (pendência) | `trabalho_novo` · `decisao_humana` · `recurso_externo` ' "$REPO/.claude/skills/buildx/references/00-schema.md")"
fi  # vivos

if bloco entrega; then
echo
echo "P0.2 — a entrega terminal commitada precede a matriz da sprintx"

# entrega_md <arquivo> <estado> <portao> — o registro no formato do kind: entrega.
entrega_md() {
  mkdir -p "$(dirname "$1")"
  printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: entrega\ntrabalho_id: %s\nentregue_por: mergex\nestado: %s\nportao: %s\npush_feito: false\npr_url: null\npr_estado: null\nentregue_em: null\n---\n\n# Entrega\n\n- Portao de prontidao: %s\n' \
    "$(basename "$(dirname "$1")")" "$2" "$3" "$3" > "$1"
}
commita() { git -C "$1" add -A && git -C "$1" commit -q "${@:2}"; }

# O E0 da mergex sobre um registro que já existe: retoma, e o devolve a `aberto`
# (mergex 00-abertura, CASO 2). É a primeira coisa que a F6 faz.
e0_simulado() { # <wt> <slug>
  sed -i 's/^estado: .*/estado: aberto/; s/^portao: .*/portao: null/; s/^push_feito: .*/push_feito: false/' \
    "$1/docs/entregas/$2/ENTREGA.md"
  commita "$1" -m "chore(mergex): E0 retomado"
}

# O que a retomada faz com a decisão: F devolve a feature à F6 — e a F6 começa
# pelo E0 —; R vai à triagem terminal sem tocar na feature.
retomada_segue() { # <slug> <base> <branch-do-projeto> <wt> -> o que foi feito
  local d; d="$(retomada_decide "$1" "$2" em_andamento "$3")"
  case "$d" in
    F) e0_simulado "$4" "$1"; echo f6_com_e0 ;;
    R:entrega_bloqueada) echo triagem_entrega_bloqueada ;;
    *) echo "$d" ;;
  esac
}

RETOMAR="$REPO/.claude/commands/buildx-retomar.md"
caso "P02.contrato a matriz tem a linha R, pela triagem entrega_bloqueada" sim \
  "$(sim_nao grep -qE '^\| \*\*R\*\* \| .*estado: bloqueado.*portao: bloqueado.*gatilho `entrega_bloqueada`' "$RETOMAR")"
caso "P02.contrato a linha R proibe F6, E0 e reabertura" sim \
  "$(sim_nao grep -qE '^\| \*\*R\*\* \| .*\*\*Não\*\* volte à F6, \*\*não\*\* deixe o E0 rodar, \*\*não\*\* reabra o `ENTREGA.md`' "$RETOMAR")"
caso "P02.contrato a linha F exige ENTREGA nao terminal" sim \
  "$(sim_nao grep -qE '^\| \*\*F\*\* \| .*\*\*sem\*\* `ENTREGA` terminal' "$RETOMAR")"
caso "P02.contrato a ENTREGA terminal vem antes da SPRINTX e do worktree" sim \
  "$(sim_nao grep -qF 'A `ENTREGA` terminal vem **antes** de qualquer linha que dependa da `SPRINTX` ou do worktree' "$RETOMAR")"
caso "P02.contrato a linha D so vale sem ENTREGA terminal" sim \
  "$(sim_nao grep -qE '^\| \*\*D\*\* \| .*\*\*sem\*\* `ENTREGA` terminal.*a linha é L ou R, nunca D' "$RETOMAR")"
caso "P02.contrato a D-35 refina a D-27: checkpoint so sem ENTREGA terminal" sim \
  "$(sim_nao grep -qF 'vale **somente quando não existe `ENTREGA` terminal commitada**' "$REPO/.claude/skills/buildx/DECISOES-DA-SKILL.md")"
caso "P02.contrato o B4 declara a precedencia" sim \
  "$(sim_nao grep -qxF '### A entrega terminal commitada precede a sprintx' <(tr -d '\r' < "$B4_REF"))"
caso "P02.contrato a D-35 esta registrada" sim \
  "$(sim_nao grep -qF '## D-35 — ENTREGA terminal commitada precede a matriz da sprintx' "$REPO/.claude/skills/buildx/DECISOES-DA-SKILL.md")"

if com_sprintx "P02 entrega terminal"; then
  C="$(novo_projeto e1 sim)"; cd "$C"
  BASE="$(git rev-parse HEAD)"
  feature_nasce ft-01 "$BASE" e1; WT="$TMP_RAIZ/e1/wt-ft-01"
  E="$WT/docs/entregas/ft-01/ENTREGA.md"
  sx_f1 "$WT" ft-01; sx_f2 "$WT" ft-01; sx_f3 "$WT" ft-01; sx_f4 "$WT" ft-01
  sx_f5 "$WT" ft-01 sim >/dev/null

  caso "P02.neg1 sem ENTREGA: nada terminal"                ausente "$(entrega_terminal ft-01)"
  caso "P02.neg1 e F6/aprovado continua levando a F6"       F "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e1)"

  entrega_md "$E" aberto null; commita "$WT" -m "chore(mergex): E0"
  caso "P02.neg3 ENTREGA aberta commitada: nao e terminal"  aberta "$(entrega_terminal ft-01)"
  caso "P02.neg3 e a F6 continua"                           F "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e1)"
  mkdir -p "$WT/src"; printf 'codigo\n' > "$WT/src/ft-01.ts"
  commita "$WT" -m "feat: T-01.01" -m "Task: T-01.01"
  entrega_md "$E" aberto bloqueado; commita "$WT" -m "chore(mergex): E2 gravou o portao"
  caso "P02.neg3 aberto com portao bloqueado, E8 sem fechar: nao e terminal" aberta "$(entrega_terminal ft-01)"
  caso "P02.neg3 e nao vira bloqueio"                       F "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e1)"

  entrega_md "$E" bloqueado bloqueado
  caso "P02.neg2 bloqueio so no working tree: nao e terminal" aberta "$(entrega_terminal ft-01)"
  caso "P02.neg2 e a retomada nao o aceita"                 F "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e1)"

  # O E8 fecha bloqueado e commita; a sprintx segue F6/aprovado. É o piloto.
  commita "$WT" -m "chore(mergex): registro do bloqueio"
  TIP="$(git rev-parse feature/ft-01)"
  caso "P02.1 a sprintx continua respondendo F6/aprovado"   f6 "$(buildx_acao "$WT" ft-01)"
  caso "P02.1 ENTREGA commitada bloqueado/bloqueado: terminal" bloqueada "$(entrega_terminal ft-01)"
  caso "P02.1 a retomada NAO devolve F: reconhece o terminal" R:entrega_bloqueada \
    "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e1)"
  caso "P02.1 segue direto para a triagem entrega_bloqueada" triagem_entrega_bloqueada \
    "$(retomada_segue ft-01 "$BASE" buildx/e1 "$WT")"
  caso "P02.1 o E0 nao rodou: a feature nao recebeu commit" "$TIP" "$(git rev-parse feature/ft-01)"
  caso "P02.1 nenhum E0 retomado no historico"              "" \
    "$(git log --format=%s "$BASE..feature/ft-01" | grep 'E0 retomado' || true)"
  caso "P02.1 a ENTREGA commitada nao foi reaberta"         "bloqueado bloqueado false null" \
    "$(campo_commitado ft-01 estado) $(campo_commitado ft-01 portao) $(campo_commitado ft-01 push_feito) $(campo_commitado ft-01 pr_url)"
  caso "P02.1 nem a da worktree"                            sim "$(sim_nao worktree_concorda ft-01 "$WT")"
  caso "P02.1 a branch da feature nao foi publicada"        nao \
    "$(sim_nao git rev-parse --verify --quiet refs/remotes/origin/feature/ft-01)"
  caso "P02.1 a CONTROL continua em BASE_SHA ate a triagem" "$BASE" "$(git rev-parse HEAD)"
  caso "P02.1 decidir de novo da o mesmo terminal"          R:entrega_bloqueada \
    "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e1)"

  git worktree remove "$WT"
  caso "P02.1 worktree perdido: continua terminal, nao H"   R:entrega_bloqueada \
    "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e1)"
  reabre_worktree ft-01 "$WT"
  caso "P02.1 reaberto sobre a mesma branch, sem commit novo" "$TIP" "$(git rev-parse feature/ft-01)"

  # Registro inconsistente: falha fechada, nunca bloqueio inferido, nunca F6.
  for v in "bloqueado null" "bloqueado pronto" "entregue bloqueado" "entregue null" "concluido pronto" "bloqueado BLOQUEADO"; do
    set -- $v
    entrega_md "$E" "$1" "$2"; commita "$WT" -m "fixture: $1/$2"
    caso "P02.neg5 $1/$2 e inconsistente"                  invalida "$(entrega_terminal ft-01)"
    caso "P02.neg5 $1/$2: pare, sem inferir bloqueio"      PARE "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e1)"
  done
  entrega_md "$E" bloqueado bloqueado; sed -i '/^portao: /d' "$E"; commita "$WT" -m "fixture: sem portao"
  caso "P02.neg5 portao ausente: inconsistente"            invalida "$(entrega_terminal ft-01)"
  caso "P02.neg5 portao ausente: pare"                     PARE "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e1)"
  entrega_md "$E" bloqueado bloqueado; sed -i 's/^portao: bloqueado$/portao: bloqueado\nestado: aberto/' "$E"
  commita "$WT" -m "fixture: estado repetido"
  caso "P02.neg5 estado repetido: inconsistente"           invalida "$(entrega_terminal ft-01)"
  caso "P02.neg5 estado repetido: pare"                    PARE "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e1)"
  caso "P02.neg5 a CONTROL nao se moveu"                   "$BASE" "$(git rev-parse HEAD)"

  # CHECKPOINT pendente com ENTREGA terminal commitada: a linha D casaria, e a
  # entrega terminal vence mesmo assim (D-35). O checkpoint fica como está.
  C="$(novo_projeto e5 sim)"; cd "$C"
  BASE="$(git rev-parse HEAD)"
  feature_nasce ft-01 "$BASE" e5; WT="$TMP_RAIZ/e5/wt-ft-01"
  PL="docs/sprintx/features/ft-01/00-PLANEJAMENTO.md"
  sx_f1 "$WT" ft-01; sx_f2 "$WT" ft-01; sx_f3 "$WT" ft-01; sx_f4 "$WT" ft-01
  hook_recusa liga
  SAIDA="$(sx_f5 "$WT" ft-01 sim)"
  hook_recusa desliga
  FASE="$(sprintx "$WT" fase ft-01)"
  caso "P02.ck a F5 aprovada nao persistiu: persistencia_falhou" persistencia_falhou "$(chave "$SAIDA" checkpoint)"
  caso "P02.ck a sprintx responde CHECKPOINT pendente"  "CHECKPOINT pendente" \
    "$(chave "$FASE" fase) $(chave "$FASE" persistencia)"
  caso "P02.ck sem ENTREGA: a retomada casa com a linha D" D "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e5)"
  PLAN_HEAD="$(git rev-parse "feature/ft-01:$PL")"
  entrega_md "$WT/docs/entregas/ft-01/ENTREGA.md" bloqueado bloqueado
  # O checkpoint recusado deixou o planejamento no índice: o commit leva só a entrega.
  git -C "$WT" add docs/entregas && git -C "$WT" commit -q -m "chore(mergex): registro do bloqueio" -- docs/entregas
  TIP="$(git rev-parse feature/ft-01)"
  caso "P02.ck o planejamento pendente ficou fora do commit" sim \
    "$(sim_nao test -n "$(git -C "$WT" status --porcelain -- "$PL")")"
  caso "P02.ck a sprintx continua em CHECKPOINT: a linha D casaria" completar_checkpoint "$(buildx_acao "$WT" ft-01)"
  caso "P02.ck ENTREGA commitada bloqueado/bloqueado: terminal" bloqueada "$(entrega_terminal ft-01)"
  caso "P02.ck a retomada devolve R, nunca D"           R:entrega_bloqueada \
    "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e5)"
  caso "P02.ck segue a triagem entrega_bloqueada"       triagem_entrega_bloqueada \
    "$(retomada_segue ft-01 "$BASE" buildx/e5 "$WT")"
  caso "P02.ck o buildx nao completou o checkpoint"     "$PLAN_HEAD" "$(git rev-parse "feature/ft-01:$PL")"
  caso "P02.ck nem commitou nada na feature"            "$TIP" "$(git rev-parse feature/ft-01)"
  caso "P02.ck a sprintx continua em CHECKPOINT"        CHECKPOINT "$(chave "$(sprintx "$WT" fase ft-01)" fase)"
  caso "P02.ck a ENTREGA commitada nao foi reaberta"    "bloqueado bloqueado" \
    "$(campo_commitado ft-01 estado) $(campo_commitado ft-01 portao)"
  caso "P02.ck a CONTROL continua em BASE_SHA"          "$BASE" "$(git rev-parse HEAD)"

  # Entregue/pronto: o caminho terminal de sempre, e só ele.
  C="$(novo_projeto e4 sim)"; cd "$C"
  BASE="$(git rev-parse HEAD)"
  feature_nasce ft-01 "$BASE" e4; WT="$TMP_RAIZ/e4/wt-ft-01"
  sx_f1 "$WT" ft-01; sx_f2 "$WT" ft-01; sx_f3 "$WT" ft-01; sx_f4 "$WT" ft-01
  sx_f5 "$WT" ft-01 sim >/dev/null
  mkdir -p "$WT/src"; printf 'codigo\n' > "$WT/src/ft-01.ts"
  commita "$WT" -m "feat: T-01.01" -m "Task: T-01.01"
  entrega_md "$WT/docs/entregas/ft-01/ENTREGA.md" entregue pronto
  sed -i 's/^push_feito: false$/push_feito: true/' "$WT/docs/entregas/ft-01/ENTREGA.md"
  commita "$WT" -m "chore(mergex): E8"
  mergex_publica ft-01
  caso "P02.neg4 entregue/pronto commitado: terminal"      entregue "$(entrega_terminal ft-01)"
  caso "P02.neg4 com a sprintx em F6/aprovado"             f6 "$(buildx_acao "$WT" ft-01)"
  caso "P02.neg4 a retomada vai a L, nao a F"              L "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e4)"
  git worktree remove "$WT"
  caso "P02.neg4 worktree perdido: continua L"             L "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e4)"
  reabre_worktree ft-01 "$WT"
  caso "P02.neg4 as seis provas passam"                    sim "$(sim_nao provas_abcdef "$BASE" ft-01 buildx/e4 "$WT")"
  caso "P02.neg4 publicada"                                sim "$(sim_nao prova_publicacao ft-01 true)"
  caso "P02.neg4 ff-only integra"                          sim "$(sim_nao integrar feature/ft-01)"
  git push -q origin buildx/e4
  caso "P02.neg4 integrada: J continua vencendo"          J "$(retomada_decide ft-01 "$BASE" em_andamento buildx/e4)"
fi
cd "$REPO"
fi  # entrega

if bloco decisoes; then
echo
echo "P0.1 — decisões append-only, D-26 em diante"

DEC_SKILL="$REPO/.claude/skills/buildx/DECISOES-DA-SKILL.md"
IDS="$(tr -d '\r' < "$DEC_SKILL" | sed -n 's/^## \(D-[0-9][0-9]*\) — .*/\1/p')"
caso "P01.36 nenhum D-NN repetido" "$(printf '%s\n' "$IDS" | wc -l | tr -d ' ')" "$(printf '%s\n' "$IDS" | sort -u | wc -l | tr -d ' ')"
FALTA=""
for n in $(seq 1 36); do
  printf '%s\n' "$IDS" | grep -qx "$(printf 'D-%02d' "$n")" || FALTA="$FALTA D-$n"
done
caso "P01.36 D-01 a D-36 presentes" "" "$FALTA"
caso "P01.36 as decisoes P0.1 vem depois da D-25, em ordem" "D-25 D-26 D-27 D-28 D-29 D-30 D-31 D-32 D-33 D-34 D-35 D-36" \
  "$(printf '%s\n' "$IDS" | tail -12 | tr '\n' ' ' | sed 's/ $//')"
for t in 'O orçamento da F5 é do caller; a contagem é da sprintx' \
         'Checkpoint da sprintx é estado legítimo da feature' \
         'Terminal pré-F6 só move a CONTROL com evidência commitada' \
         'Replanejamento sai do B5' \
         'Trabalho resolvível depois de um bloqueio vira feature sucessora' \
         'A pendência tem estado' \
         'PR-NN de feature que não integrou continuam reservados' \
         'O buildx nunca comita artefato da sprintx'; do
  caso "P01.36 decisao registrada: $t" sim "$(sim_nao grep -qF "$t" "$DEC_SKILL")"
done
fi  # decisoes

if bloco contrato; then
echo
echo "P0.1 — o contrato vivo diz o que o harness prova"

RETOMAR="$REPO/.claude/commands/buildx-retomar.md"
caso "P01.espelho commands do Claude e do OpenCode identicos" sim \
  "$(sim_nao diff -r "$REPO/.claude/commands" "$REPO/.opencode/commands")"
for l in A B C D E F G H I J K; do
  caso "P01.retomar a matriz tem a linha $l" sim "$(sim_nao grep -q "^| \*\*$l\*\* |" "$RETOMAR")"
done
caso "P01.retomar CHECKPOINT antes de qualquer decisao" sim \
  "$(sim_nao grep -qE '^\| \*\*D\*\* \| .*fase=CHECKPOINT.*complete o checkpoint antes de qualquer decis' "$RETOMAR")"
caso "P01.retomar worktree perdido reabre sobre a mesma branch" sim \
  "$(sim_nao grep -qE '^\| \*\*H\*\* \| .*sobre a mesma branch' "$RETOMAR")"
caso "P01.13 persistencia_falhou nao vira conclusao metodologica" sim \
  "$(sim_nao grep -q 'Não é conclusão metodológica: \*\*não\*\* vira `orcamento_esgotado`, \*\*não\*\* vira `bloqueada`' "$SX_REF")"
caso "P01.33 checkpoint nao e entrega, no contrato" sim \
  "$(sim_nao grep -q 'não é task concluída, não é commit E1, não é entrega, não é push e não é PR' "$SX_REF")"
fi  # contrato


echo "---------------------------------------------"
printf '%d ok, %d falha(s), %d pulo(s)\n' "$OK" "$FALHOU" "$PULOS"
[ "$FALHOU" = "0" ]
