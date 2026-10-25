#!/usr/bin/env bash
# A buildx cita quantas verificações o `mergex-check` (E2 da mergex) roda. A fonte é a mergex:
# references/02-prontidao.md tem as verificações V1 a V12, e o comando mergex-check diz "as doze
# verificações". Desde a V11 e a V12 o texto da buildx ficou em "dez" (correção P1 do Login,
# 3a61826). Este teste prende as quatro citações conhecidas, nos dois arquivos que as fazem: cada
# arquivo tem exatamente o número esperado de "doze" e nenhum "dez" ou "onze" verificações.
set -uo pipefail
raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
refs="$raiz/.claude/skills/buildx/references"
falhou=0

# arquivo relativo a references/ e quantas citações às doze verificações ele faz
alvos=(
  "integracao/mergex.md 3"
  "05-construcao.md 1"
)

for alvo in "${alvos[@]}"; do
  arquivo="${alvo% *}"; esperado="${alvo##* }"
  caminho="$refs/$arquivo"
  if [ ! -f "$caminho" ]; then
    printf '  FALHA %s não existe\n' "$arquivo"; falhou=1; continue
  fi

  velhas="$(grep -nE '\b(dez|onze) verificaç|\bentre as (dez|onze)\b' "$caminho" || true)"
  if [ -n "$velhas" ]; then
    printf '  FALHA %s ainda cita a contagem antiga:\n%s\n' "$arquivo" "$velhas"; falhou=1
  fi

  n="$(grep -oE '\bdoze verificaç|\bentre as doze\b' "$caminho" | wc -l | tr -d ' ')"
  if [ "$n" = "$esperado" ]; then
    printf '  ok    %s: %s citação(ões) às doze verificações\n' "$arquivo" "$n"
  else
    printf '  FALHA %s: esperava %s citação(ões) às doze verificações, achou %s\n' "$arquivo" "$esperado" "$n"; falhou=1
  fi
done

[ "$falhou" = 0 ]
