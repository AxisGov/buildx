import { describe, it, expect } from 'vitest'
import { execFileSync, spawnSync } from 'node:child_process'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { PrismaBetterSqlite3 } from '@prisma/adapter-better-sqlite3'
import { PrismaClient } from '../src/gerado/prisma/client.js'
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

// O processo de verdade: a seed carrega o ambiente, chama a guarda antes de gravar e, sem a
// permissão, sai com erro sem criar conta nenhuma (revisão do Codex).
describe('a seed como processo', () => {
  it('sem a permissão, falha e não grava a conta de demonstração', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'seed-'))
    const banco = join(dir, 'seed.db')
    // sem NODE_ENV: é o caso que a guarda antiga deixava passar
    const ambiente: Record<string, string | undefined> = { ...process.env, DATABASE_URL: `file:${banco}`, SEED_DE_DEMONSTRACAO: '' }
    delete ambiente.NODE_ENV
    try {
      execFileSync('npx', ['prisma', 'migrate', 'deploy'], { env: ambiente as NodeJS.ProcessEnv, stdio: 'ignore' })
      const r = spawnSync('npx', ['tsx', 'prisma/seed.ts'], { env: ambiente as NodeJS.ProcessEnv, encoding: 'utf8' })
      expect(r.status).not.toBe(0)
      expect(r.stderr).toMatch(/SEED_DE_DEMONSTRACAO/)
      const cliente = new PrismaClient({ adapter: new PrismaBetterSqlite3({ url: `file:${banco}` }) })
      const n = await cliente.usuario.count()
      await cliente.$disconnect()
      expect(n).toBe(0)
    } finally {
      rmSync(dir, { recursive: true, force: true })
    }
  }, 120_000)
})
