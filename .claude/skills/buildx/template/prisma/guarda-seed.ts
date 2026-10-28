// A guarda da seed de demonstração, separada para ser testada sem banco.
//
// A seed cria contas com senha conhecida. Recusar só `NODE_ENV=production` deixava passar o
// banco de produção acessado de um shell sem NODE_ENV (katosmv/login#34). Agora ela exige a
// permissão explícita do ambiente de demonstração, que vem no .env.example e, portanto, no
// .env local; o ambiente de produção, configurado à parte, não a tem. E continua recusando
// NODE_ENV=production, mesmo com a permissão.
export const PERMISSAO_DA_SEED = 'permitida'

export function motivoParaNaoSemear(ambiente: Record<string, string | undefined>): string | null {
  if (ambiente.NODE_ENV === 'production') {
    return 'A seed de demonstração não roda em produção: ela cria contas com senha conhecida.'
  }
  if (ambiente.SEED_DE_DEMONSTRACAO !== PERMISSAO_DA_SEED) {
    return (
      `A seed de demonstração exige SEED_DE_DEMONSTRACAO="${PERMISSAO_DA_SEED}" no ambiente ` +
      '(vem no .env.example). Ela cria contas com senha conhecida: nunca a defina em produção.'
    )
  }
  return null
}
