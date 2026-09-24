#!/usr/bin/env bash
#
# Certificação P0.2 (C7-B / B1) — o fluxo entre skills, ponta a ponta.
#
# O buildx é o integrador: é ele que instala as versões exatas da sprintx e da
# mergex num projeto. Por isso a fixture cross-repo canônica é dele. Este script
# extrai as duas skills por SHA COMPLETO, monta um projeto Git isolado e prova,
# com os scripts e hooks REAIS das duas, que o defeito que matou a FT-03 no piloto
# é corrigido pela própria feature — sem reabrir task concluída, sem sucessora e
# sem decisão humana:
#
#   PASSO 1   a sprintx barra `arquivo_de_task_irma` antes da edição, em modo aviso
#   PASSO 2   B-NN `defeito_de_plano`, task bloqueada, `replanejar-execucao`
#   PASSO 3   F3/F4/F5 do plano corrigido: B-NN resolvido, task de volta, congeladas intactas
#   PASSO 4   a mesma edição agora passa, e o produto muda de verdade
#   PASSO 5   o E1 real da mergex: trava, stage vazio, ownership, trailers, seq
#   PASSO 6   dois E1 concorrentes na mesma worktree
#   PASSO 7   V11, e a recuperação `--registrar-existente`
#   PASSO 8   `persistir-metodo pre-e2`
#   PASSO 9   E2, V1–V11
#   PASSO 10  E3/E4/E5 e `persistir-metodo pre-e6`
#   PASSO 11  E6/E7/E8 e o terminal persistido
#   PASSO 12  a prova E do buildx — e o desvio terminal formal, num subcaso à parte
#   PASSO 13  o buildx segue pelo contrato vigente
#
# e ainda: ids repetidos entre features (S2 + M1), o rastro por trabalho, os
# materiais locais, a portabilidade LF do buildx num clone `core.autocrlf=true`.
#
# Os SHAs são de CERTIFICAÇÃO, não de produção: os pinos finais do harness
# (`SPRINTX_SHA_FIXO`, `MERGEX_SHA_FIXO`) e o expx-lock são do B2.
#
# Uso:
#   bash scripts/ci/certifica-p02.sh
#   bash scripts/ci/certifica-p02.sh --ambiente     # só confere as ferramentas
#
#   C7B_SPRINTX_SHA / C7B_MERGEX_SHA      o candidato, 40 hexadecimais (padrão: o do C7-B)
#   C7B_SPRINTX_FONTE / C7B_MERGEX_FONTE  repositório (caminho ou URL) de onde extrair
#                                         por SHA; padrão: a irmã ao lado do buildx
#   C7B_PRESERVAR=0                       apaga os temporários também quando falha
#   C7B_POS_EXTRACAO=<script>             SÓ para as mutações de integração: roda
#                                         `<script> <sprintx> <mergex>` sobre os snapshots
#
# Sai != 0 na PRIMEIRA quebra. Nunca escreve nos repositórios fonte: lê deles só
# com `git archive <sha>`, e prova no fim que eles continuam como estavam. O
# cenário inteiro roda sobre os snapshots extraídos. Nada é pulado: ferramenta
# ausente é FALHA de ambiente, nunca pulo.

set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SLUG=feature-atual
PROJ_NOME=c7b
PROJ=buildx/$PROJ_NOME

C7B_SPRINTX_SHA="${C7B_SPRINTX_SHA:-ff809e1bf47dd1485583347de121673f1b014deb}"
C7B_MERGEX_SHA="${C7B_MERGEX_SHA:-a70c4ab15258a81f479a6b0bb89c3d5330a53197}"
C7B_SPRINTX_FONTE="${C7B_SPRINTX_FONTE:-$REPO/../sprintx}"
C7B_MERGEX_FONTE="${C7B_MERGEX_FONTE:-$REPO/../mergex}"

# ---------------------------------------------------------------------------
# Ambiente controlado: sem pulo. Falta de ferramenta é FALHA, e diz qual.
# ---------------------------------------------------------------------------
ambiente() {
  local c falta=""
  for c in git jq awk sed tar find sort cksum mktemp grep cut tr paste; do
    command -v "$c" >/dev/null 2>&1 || falta="$falta $c"
  done
  [ -z "$falta" ] || { printf 'ambiente: ferramenta ausente:%s\n' "$falta" >&2; return 1; }
  [ -n "${EPOCHREALTIME:-}" ] || { printf 'ambiente: bash sem EPOCHREALTIME (exige bash 5)\n' >&2; return 1; }
  return 0
}

if [ "${1:-}" = --ambiente ]; then
  ambiente && { printf 'ambiente=ok\n'; exit 0; }
  exit 1
fi

# As provas do buildx vêm do harness de integração, carregado como biblioteca:
# uma implementação só dos portões, da prova E e da matriz de retomada.
BUILDX_BIBLIOTECA=1
# shellcheck source=integracao.sh
. "$REPO/scripts/ci/integracao.sh"

INICIO_TOTAL="$EPOCHREALTIME"
PASSOU=0
DIAG=""

encerra() {
  local rc=$?
  cd / 2>/dev/null
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

# Tempo informativo, em milissegundos, por rótulo. Nunca decide nada.
TEMPOS=""
ms_desde() { # <inicio EPOCHREALTIME> -> ms
  awk -v a="${1/,/.}" -v b="${EPOCHREALTIME/,/.}" 'BEGIN { printf "%d", (b - a) * 1000 }'
}
anota_tempo() { TEMPOS="$TEMPOS$1	$2
"; }

ambiente || { printf '  FALHA  ambiente nao controlado\n'; quebra; }

# ---------------------------------------------------------------------------
# P0 — snapshots por SHA completo
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

extrai() { # extrai <nome> <fonte> <sha> <destino>
  local nome="$1" fonte="$2" sha="$3" dest="$4" repo ref
  sha_completo "$sha" || { DIAG="$nome: '$sha' nao e SHA completo"; return 1; }
  if [ -d "$fonte" ] && git -c safe.directory='*' -C "$fonte" rev-parse --git-dir >/dev/null 2>&1; then
    repo="$fonte"
  else
    repo="$TMP_RAIZ/fonte-$nome.git"
    git init -q --bare "$repo" && git -C "$repo" fetch -q --depth 1 "$fonte" "$sha" 2>/dev/null ||
      { DIAG="$nome: nao foi possivel obter $sha de $fonte"; return 1; }
  fi
  git -c safe.directory='*' -C "$repo" cat-file -e "$sha^{commit}" 2>/dev/null ||
    { DIAG="$nome: $sha nao existe em $fonte"; return 1; }
  ref="$sha"                                                                 # [P15]
  mkdir -p "$dest"
  git -c safe.directory='*' -C "$repo" archive --format=tar "$ref" | tar -x -C "$dest" ||
    { DIAG="$nome: git archive $ref falhou"; return 1; }
  printf '%s\n' "$ref" > "$dest/.c7b-ref"
  git -c safe.directory='*' -C "$repo" rev-parse "$ref^{commit}" > "$dest/.c7b-commit"
}

printf 'certificacao P0.2 — C7-B / B1\n'
printf '  sprintx %s  (%s)\n  mergex  %s  (%s)\n' "$C7B_SPRINTX_SHA" "$C7B_SPRINTX_FONTE" "$C7B_MERGEX_SHA" "$C7B_MERGEX_FONTE"
[ -z "${C7B_POS_EXTRACAO:-}" ] || printf '  ATENCAO: C7B_POS_EXTRACAO=%s (mutacao de integracao)\n' "$C7B_POS_EXTRACAO"

passo "P0 snapshots por SHA completo"
ck P0.1 "o SHA da sprintx e completo (40 hex)" sim "$(sn sha_completo "$C7B_SPRINTX_SHA")"
ck P0.2 "o SHA da mergex e completo (40 hex)"  sim "$(sn sha_completo "$C7B_MERGEX_SHA")"
FONTE_SX_ANTES="$(estado_fonte "$C7B_SPRINTX_FONTE")"
FONTE_MX_ANTES="$(estado_fonte "$C7B_MERGEX_FONTE")"
SX="$TMP_RAIZ/snap/sprintx"; MXR="$TMP_RAIZ/snap/mergex"
ck P0.3 "a sprintx e extraida do SHA" sim "$(sn extrai sprintx "$C7B_SPRINTX_FONTE" "$C7B_SPRINTX_SHA" "$SX")"
ck P0.4 "a mergex e extraida do SHA"  sim "$(sn extrai mergex "$C7B_MERGEX_FONTE" "$C7B_MERGEX_SHA" "$MXR")"
ck P0.5 "o git archive da sprintx usou o SHA completo, nao branch nem SHA curto" "$C7B_SPRINTX_SHA" "$(cat "$SX/.c7b-ref")"
ck P0.6 "o git archive da mergex usou o SHA completo, nao branch nem SHA curto"  "$C7B_MERGEX_SHA" "$(cat "$MXR/.c7b-ref")"
ck P0.7 "o commit extraido e o candidato (sprintx)" "$C7B_SPRINTX_SHA" "$(cat "$SX/.c7b-commit")"
ck P0.8 "o commit extraido e o candidato (mergex)"  "$C7B_MERGEX_SHA" "$(cat "$MXR/.c7b-commit")"
if [ -n "${C7B_POS_EXTRACAO:-}" ]; then
  bash "$C7B_POS_EXTRACAO" "$SX" "$MXR" || { DIAG="C7B_POS_EXTRACAO recusou"; quebra; }
fi

MX="$MXR/.claude/skills/mergex/scripts"
HK="$SX/.claude/hooks"
PLANEJAMENTO="$SX/.claude/skills/sprintx/scripts/planejamento.sh"
SPRINTX_BLOQUEIOS="$SX/.claude/skills/sprintx/scripts/bloqueios.sh"
MERGEX_CAUSA="$MX/causa-do-portao.sh"
for f in "$PLANEJAMENTO" "$SPRINTX_BLOQUEIOS" "$HK/sprintx/escopo-da-task.sh" "$HK/comum/rastro.sh" \
         "$MX/fechamento-do-e1.sh" "$MX/persistir-metodo.sh" "$MX/prova-de-commit.sh" \
         "$MX/ownership-da-task.sh" "$MX/sequencia-de-commits.sh" "$MERGEX_CAUSA" "$PROVA_E"; do
  ck P0.9 "o snapshot tem ${f#"$TMP_RAIZ"/}" sim "$(sn test -f "$f")"
done

# ---------------------------------------------------------------------------
# Instrumentos: hooks como o harness os chama, e as skills pelos scripts reais
# ---------------------------------------------------------------------------
S1="claude-code@c7b-sessao-1"
S2="claude-code@c7b-sessao-2"
HOJE="$(date +%Y-%m-%d)"

# hook <hook> <sessao> <payload> -> HOOK_RC, HOOK_SAIDA; mede o tempo
hook() {
  local ini="$EPOCHREALTIME"
  HOOK_SAIDA="$(printf '%s' "$3" | (cd "$WT" && EXPX_SESSAO="$2" bash "$HK/$1") 2>&1)"; HOOK_RC=$?
  anota_tempo "hook $1" "$(ms_desde "$ini")"
}

payload_escrita() { # <rel> <conteudo>
  jq -cn --arg cwd "$WT" --arg f "$WT/$1" --arg c "$2" \
    '{cwd:$cwd, tool_name:"Write", tool_input:{file_path:$f, content:$c}}'
}

# escreve <sessao> <rel> <conteudo> — a ferramenta Write com os hooks do settings.json
# da sprintx: PreToolUse em ordem (o primeiro bloqueio barra), grava, PostToolUse.
# ESCRITA_RC=0 gravou; 2 barrada (ESCRITA_HOOK e ESCRITA_SAIDA dizem por quem).
escreve() {
  local ses="$1" rel="$2" conteudo="$3" json h
  json="$(payload_escrita "$rel" "$conteudo")"
  ESCRITA_RC=0; ESCRITA_HOOK=""; ESCRITA_SAIDA=""
  for h in comum/segredo.sh sprintx/escopo-da-task.sh sprintx/task-so-fecha-verde.sh sprintx/task-reivindicada.sh; do
    hook "$h" "$ses" "$json"
    if [ "$HOOK_RC" != 0 ]; then ESCRITA_RC="$HOOK_RC"; ESCRITA_HOOK="$h"; ESCRITA_SAIDA="$HOOK_SAIDA"; return 0; fi
    [ -z "$HOOK_SAIDA" ] || ESCRITA_SAIDA="$ESCRITA_SAIDA$HOOK_SAIDA"
  done
  mkdir -p "$(dirname "$WT/$rel")"
  printf '%s' "$conteudo" > "$WT/$rel"
  for h in comum/rastro-post.sh sprintx/sem-placeholder-no-plano.sh sprintx/tdd-teste-antes.sh; do
    hook "$h" "$ses" "$json"
  done
}

# escreve_ok — a escrita tem de passar sem bloqueio.
escreve_ok() { escreve "$@"; [ "$ESCRITA_RC" = 0 ] || { DIAG="escrita de $2 barrada por $ESCRITA_HOOK: $ESCRITA_SAIDA"; quebra; }; }

# suite <sessao> — a suíte do projeto, com os hooks de Bash
suite() {
  local json ini
  json="$(jq -cn --arg cwd "$WT" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"bash test/suite.sh"}}')"
  hook comum/git-perigoso.sh "$1" "$json"
  hook sprintx/arvore-limpa-antes-da-suite.sh "$1" "$json"
  ini="$EPOCHREALTIME"
  SUITE_SAIDA="$(cd "$WT" && bash test/suite.sh 2>&1)"; SUITE_RC=$?
  anota_tempo "suite do projeto" "$(ms_desde "$ini")"
  hook comum/rastro-post.sh "$1" "$(jq -cn --arg cwd "$WT" --arg r "$SUITE_SAIDA" \
    '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"bash test/suite.sh"}, tool_response:$r}')"
}

# O evento que a SKILL grava (08-rastro.md), sempre no rastro do trabalho que ela
# conhece — nunca escolhido por mtime.
evento_skill() { # <trabalho> <evento> <task> <sessao>
  mkdir -p "$WT/docs/eventos"
  printf '{"ts":"%s","expx_eventos":1,"trabalho_id":"%s","ferramenta":"sprintx","origem":"skill","evento":"%s","fase":"f6","task":"%s","agente":"principal","resultado":"ok","detalhe":null,"arquivos":[],"sessao":"%s","harness":"claude-code"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" "$4" >> "$WT/docs/eventos/$1.jsonl"
}

reivindicacoes() { # <sessao> — a identidade composta que o rastro da sprintx resolve
  ( cd "$WT" && bash -c '. "$1"; rastro_reivindicacoes_da_sessao "$2" "$3"' _ "$HK/comum/rastro.sh" "$WT" "$1" ) | tr '\t' ' '
}

sx() { ( cd "$WT" && bash "$PLANEJAMENTO" "$@" ) 2>/dev/null; }
blq() { ( cd "$WT" && bash "$SPRINTX_BLOQUEIOS" "$@" ) 2>/dev/null; }

TASKS_REL="docs/sprintx/features/$SLUG/sprint-01/tasks.md"
ENT_REL="docs/entregas/$SLUG/ENTREGA.md"

# O plano da feature corrente, no formato que a sprintx, a mergex e os hooks leem.
# Cada task é uma linha de estado: id|status|suite|cria|altera|titulo.
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
# grava_plano <sessao> — o tasks.md inteiro pela ferramenta Write, com os hooks
grava_plano() { escreve_ok "$1" "$TASKS_REL" "$(plano_texto)"$'\n'; }
status_de() { status_task "$WT/$TASKS_REL" "$1"; }

# ENTREGA.md: uma chave de topo, numa linha, dentro do frontmatter
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

# e1 <task> [--verificacao <cmd>] -- <caminho>... — o fechamento real, a seção crítica inteira
e1() {
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

itens() { ( cd "$WT" && bash "$MX/sequencia-de-commits.sh" --ler "$ENT_REL" ) 2>/dev/null | tr -d '\r'; }
seqs() { itens | cut -f2 | paste -sd' ' -; }
v11() { ( cd "$WT" && bash "$MX/prova-de-commit.sh" --verificar "$ENT_REL" "$TASKS_REL" ) 2>/dev/null | tr -d '\r' | head -1; }
v11_linhas() { ( cd "$WT" && bash "$MX/prova-de-commit.sh" --verificar "$ENT_REL" "$TASKS_REL" ) 2>/dev/null | tr -d '\r' | sed 1d | cut -f1 | paste -sd' ' -; }
v11_head() { # a V11 lida do COMMIT: ENTREGA e plano do HEAD
  local d="$TMP_RAIZ/v11-head"; rm -rf "$d"; mkdir -p "$d"
  git -C "$WT" show "HEAD:$ENT_REL" > "$d/ENTREGA.md" 2>/dev/null || { echo ausente; return; }
  git -C "$WT" show "HEAD:$TASKS_REL" > "$d/tasks.md" 2>/dev/null || { echo ausente; return; }
  ( cd "$WT" && bash "$MX/prova-de-commit.sh" --verificar "$d/ENTREGA.md" "$d/tasks.md" ) 2>/dev/null | tr -d '\r' | head -1
}
commits_de() { git -C "$WT" rev-list --count HEAD; }
paths_do() { git -C "$WT" -c core.quotepath=false diff-tree --root --no-commit-id -r --name-only "$1" | LC_ALL=C sort | paste -sd' ' -; }
trailers_do() { git -C "$WT" log -1 --format=%B "$1" | git interpret-trailers --parse | tr -d '\r' | cut -d: -f1 | LC_ALL=C sort | paste -sd' ' -; }

# ---------------------------------------------------------------------------
# E2 — o portão de prontidão, composto dos scripts reais da mergex
#
# O E2 é conduzido pelo agente (references/02-prontidao.md); cada verificação
# abaixo é a regra mecânica do contrato, pelos scripts da mergex onde eles
# existem — ownership, V11, segredo, causa. Nenhuma lê prosa.
# ---------------------------------------------------------------------------
tasks_tsv_e2() { # id status suite ti tf, das tasks do frontmatter
  tr -d '\r' < "$WT/$TASKS_REL" | awk '
    NR == 1 { next } /^---/ { exit }
    /^  - id:/ { if (id != "") print id "\t" st "\t" su "\t" ti "\t" tf; id = $3; st = su = ""; ti = tf = 0; next }
    /^    status:/ { st = $2 } /^    suite:/ { su = $2 }
    /^    teste_integracao:/ { v = $0; sub(/^[^:]*:[ ]*/, "", v); ti = (v != "" && v != "null" && v !~ /\{\{|TODO/) }
    /^    teste_funcional:/  { v = $0; sub(/^[^:]*:[ ]*/, "", v); tf = (v != "" && v != "null" && v !~ /\{\{|TODO/) }
    END { if (id != "") print id "\t" st "\t" su "\t" ti "\t" tf }'
}

# V9: o produto do diff contra a UNIÃO das tasks — os artefatos de método do próprio
# trabalho não contam, e o HISTORICO global da sprintx também não (02-prontidao.md).
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
    # O classificador sai 2 quando há arquivo_de_task_irma — que a V9 (união) aceita.
    # O código não decide aqui: só a situação `desvio` reprova.
    linha="$( cd "$WT" && printf '%s\n' "$linha" | bash "$MX/ownership-da-task.sh" --classificar . sprintx "$SLUG" T-01.01 2>/dev/null )"
    case "$linha" in "") v9=SEM_PROVA ;; esac
    printf '%s\n' "$linha" | awk -F'\t' '$1 == "desvio"' | grep -q . && v9=FALHA
  fi
  jq -cn --arg cwd "$WT" --arg c "$(git -C "$WT" diff "$PROJ...HEAD")" \
    '{cwd:$cwd, tool_name:"Write", tool_input:{file_path:"e2-v10.diff", content:$c}}' |
    ( cd "$WT" && bash "$MXR/.claude/hooks/comum/sem-segredo.sh" ) >/dev/null 2>&1 || v10=FALHA
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

# ---------------------------------------------------------------------------
# P0 — o projeto: o controle do buildx, a instalação e as features históricas
# ---------------------------------------------------------------------------
passo "P0 fixture: projeto do buildx, instalacao das skills, features historicas"

C="$(novo_projeto "$PROJ_NOME" sim)"; cd "$C" || quebra
git config core.autocrlf false
TEMPLATE_IGNORE="$REPO/.claude/skills/buildx/template/.gitignore"
tr -d '\r' < "$TEMPLATE_IGNORE" | grep -xE 'docs/eventos/|\.expx/estado\.json|\.expx/memoria/' > .gitignore
ck P0.10 "o projeto ignora os tres derivados locais, pelo template do buildx" 3 "$(grep -c . .gitignore)"

# A instalação: o modo de cada hook das duas skills e o lock da versão instalada.
mkdir -p .expx
jq -s '{expx_hooks: 1, hooks: (.[0].hooks + .[1].hooks)}' "$SX/.expx/hooks.json" "$MXR/.expx/hooks.json" > .expx/hooks.json
jq -n --arg s "$C7B_SPRINTX_SHA" --arg m "$C7B_MERGEX_SHA" \
  '{expx_lock: 1, origem: "fixture-c7b", skills: {sprintx: {sha: $s}, mergex: {sha: $m}}}' > .expx/expx-lock.json
ck P0.11 "escopo-da-task instalado em modo aviso (o geral)" aviso "$(jq -r '.hooks["escopo-da-task"].modo' .expx/hooks.json)"
printf 'Testes: `*.test.sh` em test/, um por modulo de src/.\n' >> docs/stack/CONVENCOES.md

mkdir -p src test
printf '#!/usr/bin/env bash\nfor t in test/*.test.sh; do bash "$t" || { echo "FALHOU $t"; exit 1; }; done\necho "suite verde"\n' > test/suite.sh
printf 'x() { printf "x0\\n"; }\n' > src/x.sh
printf '. src/x.sh\n[ "$(x)" = x0 ]\n' > test/x.test.sh
git add -A && git commit -q -m "chore(buildx): fundacao do projeto c7b" || quebra

# feature-antiga: HISTÓRICA, entregue, com T-01.01 declarando X e evidência válida.
historica_plano() { # <slug> <status> — T-01.01 que declara src/x.sh
  mkdir -p "docs/sprintx/features/$1/sprint-01"
  printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: tasks\ntrabalho_id: %s\nsprint_id: sprint-01\natualizado_em: %s\ntasks:\n  - id: T-01.01\n    titulo: X da feature %s\n    status: %s\n    suite: verde\n    teste_integracao: a suite roda x\n    teste_funcional: x devolve o valor novo\n    arquivos:\n      cria: []\n      altera: [src/x.sh, test/x.test.sh]\n---\n\n# Sprint 01\n\n```yaml\nid: T-01.01\nstatus: %s\n```\n' \
    "$1" "$HOJE" "$1" "$2" "$2" > "docs/sprintx/features/$1/sprint-01/tasks.md"
  printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: orquestrador\ntrabalho_id: %s\n---\n\n# Orquestrador\n' "$1" > "docs/sprintx/features/$1/ORQUESTRADOR.md"
}
entrega_nova() { # <arquivo> <slug> <branch> <branch_base>
  mkdir -p "$(dirname "$1")"
  printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: entrega\ntrabalho_id: %s\nentregue_por: mergex\ntitulo: Trabalho %s\ntipo_trabalho: feature\ntipo_ocorrencia: null\nestado: aberto\nversionado: true\nbranch: %s\nbranch_base: %s\ncommits: []\nmodulo_afetado: []\narquivos_alterados: []\nfaixa_atencao: []\nraio: null\natencao:\n  olho_obrigatorio: 0\n  leitura_rapida: 0\n  dispensavel: 0\nportao: null\nfalhas_portao: []\ncausa: null\ndesvios: []\npush_feito: false\npr_url: null\npr_estado: null\ncriado_em: %s\natualizado_em: %s\nentregue_em: null\n---\n\n# Entrega\n\nRegistro da entrega de %s.\n' \
    "$2" "$2" "$3" "$4" "$HOJE" "$HOJE" "$2" > "$1"
}
historica_plano feature-antiga concluida
printf 'x() { printf "x1\\n"; }\n' > src/x.sh
printf '. src/x.sh\n[ "$(x)" = x1 ]\n' > test/x.test.sh
git add src/x.sh test/x.test.sh
git commit -q -F - <<'EOF' || quebra
feat(feature-antiga): x devolve x1

Task: T-01.01
Trabalho: feature-antiga
EOF
ANTIGA_E1="$(git rev-parse --short HEAD)"
ENT_ANTIGA=docs/entregas/feature-antiga/ENTREGA.md
entrega_nova "$ENT_ANTIGA" feature-antiga feature/feature-antiga "$PROJ"
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
ck P0.14 "o lock da instalacao e versionado" sim "$(sn git ls-files --error-unmatch .expx/expx-lock.json)"

# ---------------------------------------------------------------------------
# F1–F5 da feature corrente, pela sprintx real
# ---------------------------------------------------------------------------
passo "F1-F5 da feature corrente pela sprintx real"
feature_nasce "$SLUG" "$BASE" "$PROJ_NOME" || quebra
WT="$TMP_RAIZ/$PROJ_NOME/wt-$SLUG"
PASTA="$WT/docs/sprintx/features/$SLUG"
mkdir -p "$PASTA/base"
excl="$(git -C "$WT" rev-parse --git-path info/exclude)"; case "$excl" in /*|?:/*) ;; *) excl="$WT/$excl" ;; esac
mkdir -p "$(dirname "$excl")"; printf 'docs/eventos/\n' >> "$excl"
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

# T-01.02 — a irmã dona de X — executa e fecha primeiro.
task_executa() { # <sessao> <task> — reivindica pelo rastro e marca em_andamento
  plano_define "$2" 2 em_andamento; grava_plano "$1"
  evento_skill "$SLUG" task_iniciada "$2" "$1"
}
task_conclui() { # <sessao> <task> — só depois da suíte verde
  plano_define "$2" 2 concluida; plano_define "$2" 3 verde; grava_plano "$1"
  evento_skill "$SLUG" task_concluida "$2" "$1"
}
task_executa "$S1" T-01.02
escreve_ok "$S1" test/x.test.sh "$(printf '. src/x.sh\n[ "$(x)" = x2 ]\n')"$'\n'
suite "$S1"; ck F6.1 "TDD: a suite fica vermelha antes do produto" 1 "$SUITE_RC"
escreve_ok "$S1" src/x.sh 'x() { printf "x2\n"; }'$'\n'
suite "$S1"; ck F6.2 "a suite fica verde" 0 "$SUITE_RC"
task_conclui "$S1" T-01.02
e1 T-01.02 -- src/x.sh test/x.test.sh
ck F6.3 "o E1 da T-01.02 fecha com seq 1" "0 1" "$E1_RC $(printf '%s\n' "$E1_SAIDA" | sed -n 's/^seq=//p')"
E1_0102="$(git -C "$WT" rev-parse HEAD)"; ITEM_0102="$(itens | head -1)"

# ---------------------------------------------------------------------------
# PASSO 1 — a sprintx barra antes da edição
# ---------------------------------------------------------------------------
passo "PASSO 1 a sprintx barra arquivo de task irma antes da edicao"
task_executa "$S1" T-01.01
ck P1.1 "o rastro resolve a sessao a trabalho+task: feature-atual T-01.01" "$SLUG T-01.01 ok" "$(reivindicacoes "$S1")"
ck P1.2 "a reivindicacao esta no rastro do trabalho corrente" sim \
  "$(sn grep -q "\"evento\":\"task_iniciada\",.*\"task\":\"T-01.01\".*\"sessao\":\"$S1\"" "$WT/docs/eventos/$SLUG.jsonl")"
X_ANTES="$(git -C "$WT" hash-object src/x.sh)"
# a histórica fica sempre a mais recente no disco: mtime não pode decidir nada
touch -t 209901010000 "$WT/docs/sprintx/features/feature-antiga" "$WT/docs/sprintx/features/feature-antiga/sprint-01/tasks.md"
escreve "$S1" src/x.sh 'x() { printf "x2\n"; }; x_modo() { printf "novo\n"; }'$'\n'
ck P1.3 "escopo-da-task barra (rc 2) com o hook em modo aviso" "2 sprintx/escopo-da-task.sh" "$ESCRITA_RC $ESCRITA_HOOK"
ck P1.4 "a condicao e arquivo_de_task_irma, declarada so pela T-01.02" sim \
  "$(sn eval 'printf "%s" "$ESCRITA_SAIDA" | grep -q "arquivo_de_task_irma — o arquivo src/x.sh esta declarado so em task(s) irma(s) (T-01.02)"')"
ck P1.5 "X nao foi alterado" "$X_ANTES" "$(git -C "$WT" hash-object src/x.sh)"
ck P1.6 "a arvore de produto continua limpa" "" "$(git -C "$WT" status --porcelain --untracked-files=all -- src test)"
ck P1.7 "o bloqueio entrou no rastro da corrente, com a condicao" sim \
  "$(sn grep -q '"evento":"acao_bloqueada".*"condicao":"arquivo_de_task_irma","task_atual":"T-01.01"' "$WT/docs/eventos/$SLUG.jsonl")"
ck P1.8 "e nao no rastro da historica" nao "$(sn grep -q arquivo_de_task_irma "$WT/docs/eventos/feature-antiga.jsonl")"
RESP_ESCOPO_X="$ESCRITA_RC|$(printf '%s' "$ESCRITA_SAIDA" | head -1)"
escreve "$S1" src/atual.sh ':'$'\n'; RESP_ESCOPO_PROPRIO="$ESCRITA_RC|$ESCRITA_SAIDA"
rm -f "$WT/src/atual.sh"
ck P1.9 "o arquivo da propria task continua permitido" "0|" "$RESP_ESCOPO_PROPRIO"

# A mergex, pela outra ponta: o E1 da T-01.01 com X também para, antes do add.
own() { ( cd "$WT" && printf 'src/x.sh\n' | bash "$MX/ownership-da-task.sh" --classificar . sprintx "$SLUG" T-01.01 ) 2>/dev/null | tr -d '\r' | awk -F'\t' '$2 == "src/x.sh"' | tr '\t' ' '; }
RESP_OWN="$(own)"
ck P1.10 "ownership M1: X e da irma T-01.02, nunca da T-01.01 historica" "arquivo_de_task_irma src/x.sh T-01.02" "$RESP_OWN"
N0="$(commits_de)"; S0="$(seqs)"
e1 T-01.01 -- src/x.sh
ck P1.11 "o E1 da T-01.01 com X para em arquivo_de_task_irma (rc 8)" 8 "$E1_RC"
ck P1.12 "nenhum add, nenhum commit, nenhum seq" "|$N0|$S0" "$(git -C "$WT" diff --cached --name-only)|$(commits_de)|$(seqs)"
ck P1.13 "a trava do E1 foi liberada" nao "$(sn test -d "$( cd "$WT" && bash "$MX/trava-do-e1.sh" --caminho )")"

# Terceira histórica, no meio do caminho: as respostas da corrente não mudam.
TER="$WT/docs/sprintx/features/feature-terceira"
( cd "$WT" && historica_plano feature-terceira concluida )
touch -t 209901010000 "$TER" "$TER/sprint-01/tasks.md"
escreve "$S1" src/x.sh 'x() { :; }'$'\n'
ck P1.14 "com a terceira historica: a mesma resposta do escopo para X" "$RESP_ESCOPO_X" "$ESCRITA_RC|$(printf '%s' "$ESCRITA_SAIDA" | head -1)"
escreve "$S1" src/atual.sh ':'$'\n'; rm -f "$WT/src/atual.sh"
ck P1.15 "com a terceira historica: a mesma resposta para o arquivo proprio" "$RESP_ESCOPO_PROPRIO" "$ESCRITA_RC|$ESCRITA_SAIDA"
ck P1.16 "com a terceira historica: o mesmo ownership" "$RESP_OWN" "$(own)"

# RASTRO: duas sessões em trabalhos distintos, no mesmo instante, não se cruzam.
evento_skill feature-terceira task_iniciada T-01.01 "$S2"
ck P1.17 "a sessao 2 resolve ao proprio trabalho" "feature-terceira T-01.01 ok" "$(reivindicacoes "$S2")"
ck P1.18 "a sessao 1 continua resolvendo ao dela" "$SLUG T-01.01 ok" "$(reivindicacoes "$S1")"
hook sprintx/escopo-da-task.sh "$S2" "$(payload_escrita src/x.sh 'x() { :; }')"
ck P1.19 "o mesmo X, a mesma T-01.01: a sessao 2 (outro plano) nao e barrada" 0 "$HOOK_RC"
hook comum/rastro-post.sh "$S2" "$(payload_escrita src/terceira.sh '')"
hook comum/rastro-post.sh "$S1" "$(payload_escrita src/atual.sh '')"
ck P1.20 "o evento da sessao 2 foi para o rastro dela" sim \
  "$(sn grep -q '"evento":"arquivo_alterado".*"arquivos":\["src/terceira.sh"\]' "$WT/docs/eventos/feature-terceira.jsonl")"
ck P1.21 "o evento da sessao 1 foi para o rastro dela" sim \
  "$(sn grep -q '"evento":"arquivo_alterado".*"arquivos":\["src/atual.sh"\]' "$WT/docs/eventos/$SLUG.jsonl")"
ck P1.22 "e nenhum cruzou" "nao nao" \
  "$(sn grep -q 'src/terceira.sh' "$WT/docs/eventos/$SLUG.jsonl") $(sn grep -q 'src/atual.sh' "$WT/docs/eventos/feature-terceira.jsonl")"
evento_skill feature-terceira task_concluida T-01.01 "$S2"
rm -rf "$TER"

# ---------------------------------------------------------------------------
# PASSO 2 — o estado durável
# ---------------------------------------------------------------------------
passo "PASSO 2 B-NN defeito_de_plano, task bloqueada, replanejar-execucao"
ck P2.1 "bloqueios.sh registra o B-01 com a classe" "id=B-01 task=T-01.01 classe=defeito_de_plano" \
  "$(blq registrar "$SLUG" T-01.01 defeito_de_plano "a T-01.01 precisa alterar src/x.sh, declarado so na T-01.02" "o plano declarar src/x.sh na T-01.01" | tr -d '\r' | paste -sd' ' -)"
plano_define T-01.01 2 bloqueada; grava_plano "$S1"
evento_skill "$SLUG" task_bloqueada T-01.01 "$S1"
ck P2.2 "B-01 defeito_de_plano aberto, T-01.01 bloqueada" "B-01 T-01.01 defeito_de_plano aberto bloqueada" \
  "$(blq listar "$SLUG" | tr -d '\r' | tr '\t' ' ') $(status_de T-01.01)"
ck P2.4 "a fronteira e segura: nenhum produto sujo" sim "$(sn fronteira_limpa "$WT" "$SLUG")"
CONG_ANTES="$(git -C "$WT" show "HEAD:$TASKS_REL" 2>/dev/null | wc -c)"
SAIDA="$(sx replanejar-execucao "$SLUG"; printf 'codigo=%s\n' "$?")"
ck P2.5 "a rodada abre: iniciado, F3" "iniciado replanejar_execucao F3 0" \
  "$(chave "$SAIDA" replanejamento) $(chave "$SAIDA" estado) $(chave "$SAIDA" proxima) $(chave "$SAIDA" codigo)"
ck P2.3 "a abertura da rodada foi para o rastro da corrente, nao para o da historica" "sim nao" \
  "$(sn grep -q '"evento":"replanejamento_execucao_iniciado"' "$WT/docs/eventos/$SLUG.jsonl") $(sn grep -q replanejamento_execucao "$WT/docs/eventos/feature-antiga.jsonl")"
ck P2.6 "o orcamento da F6 e consumido: 1 de 1" "1 1" "$(chave "$SAIDA" replanejamentos_f6) $(chave "$SAIDA" max_replanejamentos_f6)"
ck P2.7 "a rodada: B-01, com a T-01.02 congelada" "B-01 T-01.02" \
  "$(chave "$SAIDA" bloqueios_replanejamento_f6) $(chave "$SAIDA" tasks_congeladas)"
ck P2.8 "num checkpoint da sprintx" "f6 replanejar_execucao" \
  "$(git -C "$WT" log -1 --format=%B | tr -d '\r' | awk -F': ' '/^Fase: / { f = $2 } /^Estado: / { e = $2 } END { print f, e }')"
ck P2.9 "nenhum trabalho concluido reaberto" "concluida $ITEM_0102" "$(status_de T-01.02) $(itens | head -1)"
ck P2.10 "o buildx le a rodada: S, na F3, sem PEND" S:continuar_f3 "$(cd "$C" && retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ")"

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
ck P3.4 "a rodada fecha" "" "$(chave "$(sx fase "$SLUG")" replanejamento_execucao)"
ck P3.5 "o B-01 foi resolvido pelo fechamento, sem mudar de classe" "B-01 T-01.01 defeito_de_plano resolvido" \
  "$(blq listar "$SLUG" | tr -d '\r' | tr '\t' ' ')"
ck P3.11 "a resolucao do B-01 foi para o rastro da corrente" sim \
  "$(sn grep -q '"evento":"bloqueio_resolvido".*"task":"T-01.01"' "$WT/docs/eventos/$SLUG.jsonl")"
ck P3.6 "a T-01.01 volta a executavel" pendente "$(status_de T-01.01)"
ck P3.7 "a T-01.02 concluida continua congelada" "concluida verde" \
  "$(status_de T-01.02) $(tr -d '\r' < "$WT/$TASKS_REL" | awk '/^  - id: T-01.02/ { d = 1 } d && /^    suite:/ { print $2; exit }')"
ck P3.8 "a execucao volta a F6 normal" F "$(cd "$C" && retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ")"
ck P3.9 "sem gastar de novo: 1 de 1, uma rodada aberta na branch" "1 1" \
  "$(chave "$(sx fase "$SLUG")" replanejamentos_f6) $(cd "$C" && rodadas_abertas "$SLUG")"
PLANO="$(printf '%s\n' "$PLANO" | sed 's/^T-01.01|bloqueada|/T-01.01|pendente|/')"
ck P3.10 "o plano no disco e o que a sprintx deixou" sim "$(sn eval 'diff <(plano_texto | sed "/^atualizado_em:/d") <(tr -d "\r" < "$WT/$TASKS_REL" | sed "/^atualizado_em:/d")')"

# ---------------------------------------------------------------------------
# PASSO 4 — agora a sprintx permite, e X muda de verdade
# ---------------------------------------------------------------------------
passo "PASSO 4 a mesma edicao agora e permitida"
task_executa "$S1" T-01.01
touch -t 209901010000 "$WT/docs/sprintx/features/feature-antiga" "$WT/docs/eventos/feature-antiga.jsonl" 2>/dev/null
escreve_ok "$S1" test/atual.test.sh "$(printf '. src/x.sh\n. src/atual.sh\n[ "$(atual)" = "novo x2" ]\n')"$'\n'
suite "$S1"; ck P4.1 "TDD: vermelho antes do produto" 1 "$SUITE_RC"
ALT_X="$(grep -c '"evento":"arquivo_alterado".*"arquivos":\["src/x.sh"\]' "$WT/docs/eventos/$SLUG.jsonl")"
escreve "$S1" src/x.sh 'x() { printf "x2\n"; }; x_modo() { printf "novo\n"; }'$'\n'
ck P4.2 "a edicao de X passa pelo escopo, em silencio" "0|" "$ESCRITA_RC|$ESCRITA_SAIDA"
ck P4.3 "X mudou de verdade" nao "$(sn test "$X_ANTES" = "$(git -C "$WT" hash-object src/x.sh)")"
ck P4.4 "o arquivo_alterado de X foi para o rastro da corrente, com a historica mais nova no disco" "$((ALT_X + 1))" \
  "$(grep -c '"evento":"arquivo_alterado".*"arquivos":\["src/x.sh"\]' "$WT/docs/eventos/$SLUG.jsonl")"
ck P4.5 "e nao para o rastro da historica" nao "$(sn grep -q '"arquivos":\["src/x.sh"\]' "$WT/docs/eventos/feature-antiga.jsonl")"
escreve_ok "$S1" src/atual.sh 'atual() { printf "%s %s\n" "$(x_modo)" "$(x)"; }'$'\n'
suite "$S1"; ck P4.6 "a suite fica verde" "0 suite verde" "$SUITE_RC $(printf '%s\n' "$SUITE_SAIDA" | tail -1)"
task_conclui "$S1" T-01.01

# ---------------------------------------------------------------------------
# PASSO 5 — o E1 da mergex
# ---------------------------------------------------------------------------
passo "PASSO 5 o E1 real fecha a T-01.01"
ck P5.1 "o stage esta vazio na entrada" "" "$(git -C "$WT" diff --cached --name-only)"
N0="$(commits_de)"
e1 T-01.01 -- src/atual.sh src/x.sh test/atual.test.sh
ck P5.2 "o E1 conclui com seq 2" "0 2" "$E1_RC $(printf '%s\n' "$E1_SAIDA" | sed -n 's/^seq=//p')"
E1_0101="$(git -C "$WT" rev-parse HEAD)"
ck P5.3 "exatamente um commit novo" "$((N0 + 1))" "$(commits_de)"
ck P5.4 "o commit leva so o produto da task, com X" "src/atual.sh src/x.sh test/atual.test.sh" "$(paths_do "$E1_0101")"
ck P5.5 "trailers validos: Task + Trabalho, nenhum Metodo" classe=e1 \
  "$(cd "$WT" && bash "$MX/contrato-de-commit.sh" --validar-e1 --trabalho "$SLUG" --task T-01.01 --commit HEAD | tr -d '\r')"
ck P5.6 "o SHA registrado em ENTREGA.commits e o do commit" "$E1_0101" \
  "$(git -C "$WT" rev-parse "$(itens | awk -F'\t' '$2 == 2 { print $4 }')")"
ck P5.7 "seq continuo e valido" "1 2 commits=2" "$(seqs) $(cd "$WT" && bash "$MX/sequencia-de-commits.sh" --validar "$ENT_REL" | tr -d '\r')"
ck P5.8 "o commit da T-01.02 continua o seq 1" "$ITEM_0102" "$(itens | head -1)"

# ---------------------------------------------------------------------------
# PASSO 6 — concorrência do E1 na mesma worktree
# ---------------------------------------------------------------------------
passo "PASSO 6 dois E1 concorrentes na mesma worktree"
task_executa "$S1" T-01.03
escreve_ok "$S1" test/c.test.sh "$(printf '. src/c.sh\n[ "$(c)" = c ]\n')"$'\n'
escreve_ok "$S1" src/c.sh 'c() { printf "c\n"; }'$'\n'
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
escreve_ok "$S1" test/d.test.sh "$(printf '. src/d.sh\n[ "$(d)" = d ]\n')"$'\n'
escreve_ok "$S1" src/d.sh 'd() { printf "d\n"; }'$'\n'
suite "$S1"; ck P7.2 "a suite fica verde" 0 "$SUITE_RC"
task_conclui "$S1" T-01.04
# Queda controlada entre o `git commit` (9) e o append (12): o commit existe, o
# registro não. É o desfecho `commit Git existe; registro E1 não foi concluído`.
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
# PASSO 8 — persistir-metodo pre-e2
# ---------------------------------------------------------------------------
passo "PASSO 8 persistir-metodo pre-e2"
{ printf -- '---\nexpx_schema: 1\nexpx_tool: sprintx\nkind: fechamento\ntrabalho_id: %s\n---\n\n# Fechamento\n\nQuatro tasks concluidas; B-01 resolvido pela rodada de replanejamento 1/1.\n' "$SLUG"; } > "$PASTA/FECHAMENTO.md"
HIST="$WT/docs/sprintx/estimativas/HISTORICO.md"
awk -v s="$SLUG" -v h="$HOJE" 'NR > 1 && /^calibracao:/ && !f { for (i = 1; i <= 4; i++) printf "  - trabalho_id: %s\n    task_id: T-01.0%d\n    real: 1\n    registrado_em: %s\n", s, i, h; f = 1 } { print }' "$HIST" > "$HIST.tmp" && mv -f "$HIST.tmp" "$HIST"
for i in 1 2 3 4; do printf '| %s | T-01.0%s | 1 |\n' "$SLUG" "$i" >> "$HIST"; done
printf '\n# rascunho local que nenhuma task commitou\n' >> "$WT/src/c.sh"
S0="$(seqs)"; PROX0="$(cd "$WT" && bash "$MX/sequencia-de-commits.sh" --proximo "$ENT_REL" | tr -d '\r')"
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
ck P8.5 "nenhum produto pegou carona" "" "$(paths_do "$PRE_E2" | tr ' ' '\n' | grep -vE "^docs/(sprintx/features/$SLUG/|entregas/$SLUG/|sprintx/estimativas/HISTORICO.md$)")"
ck P8.6 "o produto sujo continua sujo, fora do commit" " M src/c.sh" "$(git -C "$WT" status --porcelain -- src)"
git -C "$WT" checkout -q -- src/c.sh
ck P8.7 "o commit de metodo nao entra em ENTREGA.commits nem consome seq" "$S0 $PROX0" \
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
# PASSO 11 — E6, E7, E8
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
ck P11.9 "arvore inteira limpa" "" "$(git -C "$WT" status --porcelain --untracked-files=all)"
ck P11.10 "o terminal commitado: entregue/pronto" entregue "$(cd "$C" && entrega_terminal "$SLUG")"

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
ck M.3 "com os derivados presentes a arvore segue limpa" "" "$(git -C "$WT" status --porcelain --untracked-files=all)"
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

# Desvio terminal formal, num subcaso à parte: a V9 bloquearia o fluxo feliz.
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
# PASSO 13 — o buildx segue
# ---------------------------------------------------------------------------
passo "PASSO 13 o buildx segue pelo contrato vigente, sem decisao humana"
cd "$C" || quebra
ck P13.1 "a retomada le o terminal commitado: L (integrar)" L "$(retomada_decide "$SLUG" "$BASE" em_andamento "$PROJ")"
ck P13.2 "as seis provas A-F passam" sim "$(sn provas_abcdef "$BASE" "$SLUG" "$PROJ" "$WT")"
ck P13.3 "a publicacao confere com push_feito" sim "$(sn prova_publicacao "$SLUG" "$(campo_commitado "$SLUG" push_feito)")"
ck P13.4 "nenhum terminal da F6: o retorno foi 1/1 e aprovado" nao "$(terminal_f6_commitado "feature/$SLUG" "$SLUG")"
ck P13.5 "integra por fast-forward" sim "$(sn integrar "feature/$SLUG")"
ck P13.6 "o controle esta no HEAD da feature" "$(git rev-parse "feature/$SLUG")" "$(git rev-parse HEAD)"
mapa_define docs/projeto/MAPA.md FT-02 Status entregue
mapa_define docs/projeto/MAPA.md FT-02 SHA "$(git rev-parse --short HEAD)"
git add docs/projeto/MAPA.md && git commit -q -m "chore(buildx): FT-02 entregue" && git push -q origin "$PROJ" || quebra
ck P13.7 "a CONTROL publicada, local = remoto" sim "$(sn gate_local_remoto "$PROJ")"
ck P13.8 "nenhuma pendencia: sem RECURSAO.md" nao "$(sn test -e docs/projeto/RECURSAO.md)"
ck P13.9 "nenhuma sucessora: 3 features, nenhuma de recursao" "3 0" \
  "$(tr -d '\r' < docs/projeto/MAPA.md | awk '/^### FT-/ { n++ } /^\*\*Origem:\*\* recursao$/ { r++ } END { print n + 0, r + 0 }')"
ck P13.10 "todo B-NN resolvido" "" "$(blq listar "$SLUG" | tr -d '\r' | awk -F'\t' '$4 != "resolvido"')"
ck P13.11 "a task concluida antes do defeito esta integrada, no mesmo seq 1" "sim $ITEM_0102" \
  "$(sn git merge-base --is-ancestor "$E1_0102" HEAD) $(git show "HEAD:$ENT_REL" | bash "$MX/sequencia-de-commits.sh" --ler - | tr -d '\r' | head -1)"
ck P13.12 "e o E1 que corrigiu X tambem" sim "$(sn git merge-base --is-ancestor "$E1_0101" HEAD)"
ck P13.13 "a FT-03 depende da FT-02: dependencia integrada, pela arvore" sim "$(sn gate_dependencia "" "$SLUG")"
ck P13.14 "e a FT-03 esta livre para nascer" livre "$(retomada_decide feature-seguinte "$(git rev-parse HEAD)" pendente "$PROJ")"

# ---------------------------------------------------------------------------
# PORTABILIDADE — o buildx num clone core.autocrlf=true
# ---------------------------------------------------------------------------
passo "PORTABILIDADE LF do buildx"

# O fonte: os arquivos rastreados, com o conteúdo desta árvore, commitados como um
# usuário Windows commitaria (autocrlf=true normaliza CRLF -> LF no índice).
LF="$TMP_RAIZ/lf"; mkdir -p "$LF/fonte"
( cd "$REPO" && git -c safe.directory='*' ls-files -z --cached --others --exclude-standard | tar --null -T - -cf - ) | tar -C "$LF/fonte" -xf - || quebra
( cd "$LF/fonte" && git init -q -b main . && git config user.email t@t && git config user.name t &&
  git config core.autocrlf true && git add -A 2>/dev/null && git commit -q -m fonte ) || quebra
clona_crlf() { # <fonte> <destino>
  git clone -q -c core.autocrlf=true "$1" "$2" 2>/dev/null
}
clona_crlf "$LF/fonte" "$LF/clone" || quebra
ck L.2 "o clone persiste core.autocrlf=true" true "$(git -C "$LF/clone" config --get core.autocrlf)"
ck L.3 "todo .sh: indice LF, worktree LF, atributo eol=lf" "" \
  "$(git -C "$LF/clone" ls-files --eol -- '*.sh' | grep -Ev '^i/lf[[:space:]]+w/lf[[:space:]]+attr/text eol=lf[[:space:]]' || true)"
ck L.4 "nenhum .sh tem byte CR, e o shebang e literal" "" \
  "$(cd "$LF/clone" && git ls-files -- '*.sh' | while IFS= read -r f; do
       [ "$(tr -cd '\r' < "$f" | wc -c | tr -d ' ')" = 0 ] || echo "$f:CR"; IFS= read -r l < "$f"; [ "$l" = '#!/usr/bin/env bash' ] || echo "$f:shebang"; done)"
ck L.5 "todo .md: worktree LF, atributo eol=lf" "" \
  "$(git -C "$LF/clone" ls-files --eol -- '*.md' | grep -Ev '^i/lf[[:space:]]+w/lf[[:space:]]+attr/text eol=lf[[:space:]]' || true)"
ATR="$(tr -d '\r' < "$REPO/.gitattributes" 2>/dev/null | grep -v '^#' | grep . | LC_ALL=C sort | paste -sd'|' -)"
ck L.1 "a politica e minima: *.md e *.sh, LF, e nada mais" '*.md text eol=lf|*.sh text eol=lf' "$ATR"
ck L.6 "o harness B1 do clone e executavel" "0 ambiente=ok" \
  "$(for f in $(cd "$LF/clone" && git ls-files -- '*.sh'); do bash -n "$LF/clone/$f" || echo "bash -n $f"; done
     bash "$LF/clone/scripts/ci/certifica-p02.sh" --ambiente | tr -d '\r' | sed 's/^/0 /')"
mkdir -p "$LF/pe" && git -C "$LF/pe" init -q -b feature/x && git -C "$LF/pe" -c user.email=t@t -c user.name=t commit -q --allow-empty -m i
ck L.7 "a prova E do clone da o veredito" limpa "$(bash "$LF/clone/.claude/skills/buildx/scripts/prova-e.sh" "$LF/pe" x | sed -n 's/^veredito: //p')"
INI="$EPOCHREALTIME"
ck L.8 "os contratos Markdown lidos mecanicamente passam no clone (bloco desvios)" 0 \
  "$(cd "$LF" && BLOCOS=desvios bash "$LF/clone/scripts/ci/integracao.sh" > "$LF/desvios.log" 2>&1; echo $?)"
anota_tempo "integracao.sh bloco desvios (clone)" "$(ms_desde "$INI")"
# A evidência de que *.md é carga: sem a regra, os mesmos contratos caem em CRLF.
mkdir -p "$LF/sem-md"
( cd "$LF/fonte" && git archive HEAD ) | tar -C "$LF/sem-md" -xf -
grep -v '^\*\.md ' "$LF/sem-md/.gitattributes" > "$LF/sem-md/.ga" && mv -f "$LF/sem-md/.ga" "$LF/sem-md/.gitattributes"
( cd "$LF/sem-md" && git init -q -b main . && git config user.email t@t && git config user.name t &&
  git config core.autocrlf false && git add -A && git commit -q -m sem-md ) || quebra
clona_crlf "$LF/sem-md" "$LF/clone-sem-md" || quebra
ck L.9 "sem *.md eol=lf o contrato Markdown chega CRLF no clone" "" \
  "$(git -C "$LF/clone-sem-md" ls-files --eol -- '*.md' | grep -v 'w/crlf' || true)"
# A leitura mecanica dos contratos usa grep ancorado (-x). Onde o grep da plataforma
# e sensivel a CR (GNU grep: Linux, WSL, contêiner), o CRLF a quebra; o grep do Git
# Bash descarta o CR, e ali a mesma leitura passa. A quebra so e exigida onde ocorre.
if printf 'a\r\n' | grep -qx a; then GREP_CR=tolerante; else GREP_CR=sensivel; fi
printf '          grep desta plataforma: %s a CR\n' "$GREP_CR"
RC_SEM_MD="$(cd "$LF" && BLOCOS=desvios bash "$LF/clone-sem-md/scripts/ci/integracao.sh" > "$LF/sem-md.log" 2>&1; echo $?)"
if [ "$GREP_CR" = sensivel ]; then
  ck L.10 "sem a regra, a leitura mecanica do contrato falha" 1 "$RC_SEM_MD"
  ck L.11 "e a falha e de contrato Markdown, nao de script" sim "$(sn grep -q '^  FALHA C6.contrato' "$LF/sem-md.log")"
else
  ck L.10 "com grep tolerante a CR a leitura passa: a regra protege os leitores sensiveis" 0 "$RC_SEM_MD"
fi

# ---------------------------------------------------------------------------
# Fontes intocadas, tempos e fechamento
# ---------------------------------------------------------------------------
passo "FONTES intocadas"
ck F.1 "a sprintx fonte continua como estava" "$FONTE_SX_ANTES" "$(estado_fonte "$C7B_SPRINTX_FONTE")"
ck F.2 "a mergex fonte continua como estava"  "$FONTE_MX_ANTES" "$(estado_fonte "$C7B_MERGEX_FONTE")"

passo "TEMPOS (informativo; nada decide)"
printf '%s' "$TEMPOS" | awk -F'\t' 'NF == 2 { n[$1]++; s[$1] += $2; if ($2 > m[$1]) m[$1] = $2 }
  END { for (k in n) printf "  %-42s n=%-3d media=%6d ms  max=%6d ms%s\n", k, n[k], s[k] / n[k], m[k], (m[k] > 10000 ? "  ACIMA DE 10 s" : "") }' | LC_ALL=C sort
printf '  %-42s %d ms\n' "total da certificacao" "$(ms_desde "$INICIO_TOTAL")"

printf '\n%d checkpoints, 0 falhas, 0 pulos — certificacao P0.2 OK\n' "$PASSOU"
