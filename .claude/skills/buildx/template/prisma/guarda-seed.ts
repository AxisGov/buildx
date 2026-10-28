// A guarda da seed de demonstração, separada para ser testada sem banco.
//
// A seed cria contas com senha conhecida. Recusar só `NODE_ENV=production` deixava passar o
// banco de produção acessado de um shell sem NODE_ENV (katosmv/login#34). E a permissão não pode
// morar no ambiente: o .env de um servidor copiado do .env.example a carregaria (CodeAnt no
// buildx#16). Ela é o argumento `--demonstracao`, exato, na linha de comando — intenção de quem
// roda, nunca configuração herdada. NODE_ENV=production recusa sempre, mesmo com ele.
export const ARGUMENTO_DA_SEED = '--demonstracao'

export function motivoParaNaoSemear(
  argumentos: readonly string[],
  ambiente: Record<string, string | undefined>,
): string | null {
  if (ambiente.NODE_ENV === 'production') {
    return 'A seed de demonstração não roda em produção: ela cria contas com senha conhecida.'
  }
  if (!argumentos.includes(ARGUMENTO_DA_SEED)) {
    return (
      `A seed de demonstração só roda com ${ARGUMENTO_DA_SEED}: tsx prisma/seed.ts ${ARGUMENTO_DA_SEED} ` +
      '(o npm run setup já o passa). Ela cria contas com senha conhecida; nunca a rode contra produção.'
    )
  }
  return null
}
