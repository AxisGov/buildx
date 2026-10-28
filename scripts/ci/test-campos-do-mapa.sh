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
# Onze desde a D-24: `premissas_realizadas` entra no contrato (o template já o renderizava, e o
# B6 e o briefing do B4 dependem dele; CodeRabbit no katosmv/login#30).
if [ "$n" = 11 ]; then
  printf '  ok    a tabela de campos da feature tem 11 linhas de dados\n'
else
  printf '  FALHA esperava 11 linhas de dados na tabela de campos, achou %s\n' "$n"; falhou=1
fi

if grep -q 'toda feature com os onze campos' "$doc" && ! grep -qE '\b(oito|nove|dez) campos\b' "$doc"; then
  printf '  ok    o critério de saída exige os onze campos\n'
else
  printf '  FALHA o critério de saída não diz "onze campos": %s\n' "$(grep -nE 'campos' "$doc" | tr '\n' '|')"; falhou=1
fi

# A lista canônica é a da tabela do 04; o SKILL.md e o 00-schema.md nomeiam os mesmos campos, na
# mesma ordem (CodeAnt no AxisGov/buildx#14: eles tinham ficado nos oito antigos).
canon="$(awk '/^\| Campo \| Conteúdo \| Regra \|$/ { dentro = 1; next }
         dentro && /^\|---/ { next }
         dentro && /^\| `/ { c = $0; sub(/^\| `/, "", c); sub(/`.*/, "", c); print c; next }
         dentro { exit }' "$doc" | tr '\n' ' ')"
skill_md="$raiz/.claude/skills/buildx/SKILL.md"
sk="$(awk '/^Contrato da feature/ { a = 1 } a && /^\| `/ { c = $0; sub(/^\| `/, "", c); sub(/`.*/, "", c); print c }
           a && /^$/ && n++ > 1 { exit }' "$skill_md" | tr '\n' ' ')"
if [ "$sk" = "$canon" ]; then
  printf '  ok    o SKILL.md nomeia os campos do contrato na ordem canonica\n'
else
  printf '  FALHA SKILL.md [%s] difere do contrato [%s]\n' "$sk" "$canon"; falhou=1
fi
sch="$(grep -m1 'contrato completo do B3' "$raiz/.claude/skills/buildx/references/00-schema.md" \
       | grep -oE '`[a-z_]+`' | tr -d '`' | tr '\n' ' ')"
if [ "$sch" = "$canon" ]; then
  printf '  ok    o 00-schema.md nomeia os campos do contrato na ordem canonica\n'
else
  printf '  FALHA 00-schema.md [%s] difere do contrato [%s]\n' "$sch" "$canon"; falhou=1
fi
# O enum de `origem` e um so: a FT-01 nasce `template`.
for f in "$doc" "$skill_md" "$raiz/.claude/skills/buildx/assets/TEMPLATE-MAPA.md"; do
  # o conjunto EXATO de valores: na tabela, as palavras entre crases da linha (menos o nome do
  # campo); no template, as opções entre < e >. Nem falta nem sobra.
  linha_origem="$(grep -m1 -E '^(\| `origem` \||\*\*Origem:\*\*)' "$f")"
  case "$linha_origem" in
    '**Origem:**'*) valores="$(printf '%s' "$linha_origem" | sed 's/.*<\(.*\)>.*/\1/' | tr '|' '\n' | tr -d ' ')" ;;
    *) valores="$(printf '%s' "$linha_origem" | grep -oE '`[a-z_]+`' | tr -d '`' | grep -vx origem)" ;;
  esac
  if [ "$(printf '%s\n' "$valores" | grep -v '^$' | sort -u | tr '\n' ' ')" = "descricao premissa recursao template " ]; then
    printf '  ok    enum de origem completo em %s\n' "${f#$raiz/}"
  else
    printf '  FALHA enum de origem difere de descricao|premissa|recursao|template em %s\n' "${f#$raiz/}"; falhou=1
  fi
done
# O briefing do B4 leva os candidatos a F2/F3, onde o fornecedor e escolhido (CodeAnt no buildx#14).
for f in references/05-construcao.md references/integracao/sprintx.md; do
  if grep -qF 'modulos_candidatos' "$raiz/.claude/skills/buildx/$f" && grep -qF 'fatias_candidatas' "$raiz/.claude/skills/buildx/$f"; then
    printf '  ok    o briefing em %s repassa os candidatos\n' "$f"
  else
    printf '  FALHA o briefing em %s nao repassa modulos_candidatos e fatias_candidatas\n' "$f"; falhou=1
  fi
done
# A relação premissa -> feature é o `premissas_realizadas`, não o `origem` (revisão do Codex).
if grep -qF 'O campo `premissas_realizadas` é o que o B6 usa para conferir' "$doc" \
   && ! grep -qF 'O campo `origem` é o que o B6 usa' "$doc"; then
  printf '  ok    o 04 confere premissas por premissas_realizadas, nao por origem\n'
else
  printf '  FALHA o 04 ainda confere premissas pelo campo origem\n'; falhou=1
fi
# O B6 cruza cada premissa com `premissas_realizadas`.
if grep -qF 'premissas_realizadas' "$raiz/.claude/skills/buildx/references/07-validacao.md"; then
  printf '  ok    o B6 cruza as premissas com premissas_realizadas\n'
else
  printf '  FALHA o B6 nao cita premissas_realizadas\n'; falhou=1
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

# katosmv/login#34: o B4 normaliza o mapa anterior à D-23 antes do briefing; a premissa da F2 entra
# no premissas_realizadas da feature; e a consulta indisponível não vira candidata a extração.
refs="$raiz/.claude/skills/buildx/references"
confere_doc() { # <descrição> <comando>
  if eval "$2"; then printf '  ok    %s\n' "$1"; else printf '  FALHA %s\n' "$1"; falhou=1; fi
}
confere_doc 'o briefing do B4 normaliza o mapa anterior a D-23' \
  "grep -q 'Compatibilidade com o \`MAPA.md\` anterior' '$refs/05-construcao.md'"
confere_doc 'a premissa nova da F2 entra no premissas_realizadas da feature' \
  "awk '/Nenhum dos três responde/' '$refs/05-construcao.md' | grep -q 'premissas_realizadas'"
confere_doc 'o B3 registra a consulta ao catalogo (concluida ou indisponivel)' \
  "grep -q 'consulta_modulex: indisponivel' '$refs/04-decomposicao.md' && grep -q 'consulta_modulex' '$raiz/.claude/skills/buildx/assets/TEMPLATE-MAPA.md'"
confere_doc 'o B6 so oferece extracao com a consulta concluida' \
  "awk '/Candidatas a módulo novo/,/Compatibilidade com o/' '$refs/07-validacao.md' | grep -q 'consulta_modulex: concluida'"

[ "$falhou" = 0 ]
