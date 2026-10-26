#!/usr/bin/env bash
# references/04-decomposicao.md tem a tabela dos campos de cada feature do MAPA.md, e o critério
# de saída cita quantos são. Com `modulo_disponivel` e `fatias_candidatas` a tabela foi a dez
# campos e o critério ficou em "oito" (achado do CodeRabbit no katosmv/login#29). Este teste conta
# as linhas de dados da tabela (sem cabeçalho nem separador) e exige o mesmo número, por extenso,
# no critério de saída.
set -uo pipefail
raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
doc="$raiz/.claude/skills/buildx/references/04-decomposicao.md"
falhou=0

n="$(awk '/^\| Campo \| Conteúdo \| Regra \|$/ { dentro = 1; next }
         dentro && /^\|---/ { next }
         dentro && /^\| `/ { n++; next }
         dentro { exit }
         END { print n + 0 }' "$doc")"
if [ "$n" = 10 ]; then
  printf '  ok    a tabela de campos da feature tem 10 linhas de dados\n'
else
  printf '  FALHA esperava 10 linhas de dados na tabela de campos, achou %s\n' "$n"; falhou=1
fi

if grep -q 'toda feature com os dez campos' "$doc" && ! grep -qE '\b(oito|nove) campos\b' "$doc"; then
  printf '  ok    o critério de saída exige os dez campos\n'
else
  printf '  FALHA o critério de saída não diz "dez campos": %s\n' "$(grep -nE 'campos' "$doc" | tr '\n' '|')"; falhou=1
fi

[ "$falhou" = 0 ]
