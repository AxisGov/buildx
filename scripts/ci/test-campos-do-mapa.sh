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

# Os candidatos a módulo são coleção (D-23): `modulos_candidatos` (lista JSON de ids) e
# `fatias_candidatas` (objeto JSON id -> lista de fatias), no contrato, no template e no B6. O
# nome antigo `modulo_disponivel` só aparece na seção de compatibilidade do leitor.
skill="$raiz/.claude/skills/buildx"
tpl="$skill/assets/TEMPLATE-MAPA.md"
val="$skill/references/07-validacao.md"
if grep -qF '| `modulos_candidatos` |' "$doc" && grep -qF '| `fatias_candidatas` |' "$doc"; then
  printf '  ok    a tabela traz modulos_candidatos e fatias_candidatas\n'
else
  printf '  FALHA a tabela de campos nao traz modulos_candidatos e fatias_candidatas\n'; falhou=1
fi
if grep -qF '**Módulos candidatos:**' "$tpl" && grep -qF '**Fatias candidatas:**' "$tpl" && ! grep -qF '**Módulo disponível:**' "$tpl"; then
  printf '  ok    o TEMPLATE-MAPA.md grava os candidatos como colecao\n'
else
  printf '  FALHA o TEMPLATE-MAPA.md ainda grava o modulo como valor unico\n'; falhou=1
fi
if grep -qF 'modulos_candidatos: []' "$val"; then
  printf '  ok    o B6 testa a lista vazia\n'
else
  printf '  FALHA o Passo 4.a do B6 nao testa modulos_candidatos: []\n'; falhou=1
fi
# fora da secao de compatibilidade, o nome antigo nao aparece em lugar nenhum da skill (o log de
# decisoes, append-only, conta a historia e fica de fora)
fora="$(awk -v arq="" 'FNR == 1 { arq = FILENAME; dentro = 0 }
  /^#+ .*[Cc]ompatibilidade/ { dentro = 1; next }
  /^#+ / { dentro = 0 }
  !dentro && /modulo_disponivel/ { print arq ":" FNR }' $(grep -rlF --exclude=DECISOES-DA-SKILL.md modulo_disponivel "$skill" 2>/dev/null) /dev/null)"
if [ -z "$fora" ]; then
  printf '  ok    modulo_disponivel so na secao de compatibilidade\n'
else
  printf '  FALHA modulo_disponivel fora da secao de compatibilidade: %s\n' "$(printf '%s' "$fora" | tr '\n' ' ')"; falhou=1
fi

[ "$falhou" = 0 ]
