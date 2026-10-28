import { describe, it, expect } from 'vitest'
import { execFileSync, spawnSync } from 'node:child_process'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { PrismaBetterSqlite3 } from '@prisma/adapter-better-sqlite3'
import { PrismaClient } from '../src/gerado/prisma/client.js'
import { motivoParaNaoSemear } from '../prisma/guarda-seed.js'

// A seed cria contas com senha conhecida. Ela só roda com o argumento explícito `--demonstracao`
// na linha de comando, que nenhum .env carrega (katosmv/login#34; CodeAnt no buildx#16), e nunca
// com NODE_ENV=production.
describe('guarda da seed de demonstração', () => {
  it('sem o argumento --demonstracao, recusa — inclusive com a variável antiga no ambiente', () => {
    expect(motivoParaNaoSemear([], {})).toMatch(/--demonstracao/)
    expect(motivoParaNaoSemear([], { NODE_ENV: 'development' })).toMatch(/--demonstracao/)
    expect(motivoParaNaoSemear([], { SEED_DE_DEMONSTRACAO: 'permitida' })).toMatch(/--demonstracao/)
    expect(motivoParaNaoSemear(['--demonstracao=1'], {})).toMatch(/--demonstracao/)
  })

  it('em produção, recusa mesmo com o argumento', () => {
    expect(motivoParaNaoSemear(['--demonstracao'], { NODE_ENV: 'production' })).toMatch(/produção/)
  })

  it('com o argumento e fora de produção, semeia', () => {
    expect(motivoParaNaoSemear(['--demonstracao'], {})).toBeNull()
    expect(motivoParaNaoSemear(['--demonstracao'], { NODE_ENV: 'development' })).toBeNull()
    expect(motivoParaNaoSemear(['--demonstracao'], { NODE_ENV: 'test' })).toBeNull()
  })
})

const TEMPLATE = resolve(import.meta.dirname, '..')
const SEED = join(TEMPLATE, 'prisma', 'seed.ts')
const TSX = join(TEMPLATE, 'node_modules', '.bin', 'tsx')

/** Um banco SQLite temporário com as migrations, e um .env que traz a permissão antiga. */
function bancoComEnvLegado(): { dir: string; url: string; ambiente: NodeJS.ProcessEnv } {
  const dir = mkdtempSync(join(tmpdir(), 'seed-'))
  const url = `file:${join(dir, 'seed.db')}`
  // o .env de um servidor copiado do exemplo antigo: a permissão não pode vir por aqui
  writeFileSync(join(dir, '.env'), `DATABASE_URL="${url}"\nSEED_DE_DEMONSTRACAO="permitida"\n`)
  // sem NODE_ENV: é o caso que a guarda original deixava passar
  const ambiente: Record<string, string | undefined> = { ...process.env, DATABASE_URL: url, SEED_DE_DEMONSTRACAO: 'permitida' }
  delete ambiente.NODE_ENV
  execFileSync('npx', ['prisma', 'migrate', 'deploy'], { cwd: TEMPLATE, env: ambiente as NodeJS.ProcessEnv, stdio: 'ignore' })
  return { dir, url, ambiente: ambiente as NodeJS.ProcessEnv }
}

async function contas(url: string): Promise<number> {
  const cliente = new PrismaClient({ adapter: new PrismaBetterSqlite3({ url }) })
  const n = await cliente.usuario.count()
  await cliente.$disconnect()
  return n
}

// O processo de verdade, rodado do diretório que tem o .env: a seed carrega o ambiente, chama a
// guarda antes de gravar e, sem o argumento, sai com erro sem criar conta nenhuma.
describe('a seed como processo', () => {
  it('sem --demonstracao, falha e não grava conta — nem com a permissão antiga no .env e no ambiente', async () => {
    const { dir, url, ambiente } = bancoComEnvLegado()
    try {
      const r = spawnSync(TSX, [SEED], { cwd: dir, env: ambiente, encoding: 'utf8' })
      expect(r.status).not.toBe(0)
      expect(r.stderr).toMatch(/--demonstracao/)
      expect(await contas(url)).toBe(0)
    } finally {
      rmSync(dir, { recursive: true, force: true })
    }
  }, 120_000)

  it('com --demonstracao, semeia as duas contas de demonstração', async () => {
    const { dir, url, ambiente } = bancoComEnvLegado()
    try {
      const r = spawnSync(TSX, [SEED, '--demonstracao'], { cwd: dir, env: ambiente, encoding: 'utf8' })
      expect(r.status, r.stderr).toBe(0)
      expect(await contas(url)).toBe(2)
    } finally {
      rmSync(dir, { recursive: true, force: true })
    }
  }, 120_000)
})
