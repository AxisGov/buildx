import { describe, it, expect } from 'vitest'
import { motivoParaNaoSemear } from '../prisma/guarda-seed.js'

// A seed cria contas com senha conhecida. Ela só roda com a permissão explícita do ambiente
// de demonstração, que vem no .env.example; sem ela, recusa, mesmo sem NODE_ENV (katosmv/login#34).
describe('guarda da seed de demonstração', () => {
  it('sem a permissão explícita, recusa — inclusive sem NODE_ENV', () => {
    expect(motivoParaNaoSemear({})).toMatch(/SEED_DE_DEMONSTRACAO/)
    expect(motivoParaNaoSemear({ NODE_ENV: 'development' })).toMatch(/SEED_DE_DEMONSTRACAO/)
    expect(motivoParaNaoSemear({ SEED_DE_DEMONSTRACAO: 'sim' })).toMatch(/SEED_DE_DEMONSTRACAO/)
  })

  it('em produção, recusa mesmo com a permissão', () => {
    expect(motivoParaNaoSemear({ NODE_ENV: 'production', SEED_DE_DEMONSTRACAO: 'permitida' })).toMatch(/produção/)
  })

  it('com a permissão e fora de produção, semeia', () => {
    expect(motivoParaNaoSemear({ SEED_DE_DEMONSTRACAO: 'permitida' })).toBeNull()
    expect(motivoParaNaoSemear({ NODE_ENV: 'development', SEED_DE_DEMONSTRACAO: 'permitida' })).toBeNull()
    expect(motivoParaNaoSemear({ NODE_ENV: 'test', SEED_DE_DEMONSTRACAO: 'permitida' })).toBeNull()
  })
})
