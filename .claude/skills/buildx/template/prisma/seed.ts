import 'dotenv/config'
import { PrismaBetterSqlite3 } from '@prisma/adapter-better-sqlite3'
import { PrismaClient } from '../src/gerado/prisma/client.js'
import { hashDeSenha } from '../src/lib/senha.js'
import { motivoParaNaoSemear } from './guarda-seed.js'

const url = process.env.DATABASE_URL
if (!url) throw new Error('DATABASE_URL ausente. Veja o .env.example.')

const prisma = new PrismaClient({ adapter: new PrismaBetterSqlite3({ url }) })

// Credenciais fictícias, para uso local. A seed nunca roda em produção:
// a guarda (prisma/guarda-seed.ts) exige o argumento --demonstracao na linha
// de comando e recusa NODE_ENV=production. A senha tem nome: no uso ela é
// referência, e a varredura de segredo da mergex não a confunde com credencial.
const SENHA_DE_DEMONSTRACAO = 'demo1234'

const DEMONSTRACAO = [
  {
    nome: 'Administradora de demonstração',
    email: 'admin@exemplo.local',
    senha: SENHA_DE_DEMONSTRACAO,
    papel: 'admin',
  },
  {
    nome: 'Usuário de demonstração',
    email: 'usuario@exemplo.local',
    senha: SENHA_DE_DEMONSTRACAO,
    papel: 'usuario',
  },
]

async function semear() {
  const recusa = motivoParaNaoSemear(process.argv.slice(2), process.env)
  if (recusa !== null) throw new Error(recusa)

  for (const conta of DEMONSTRACAO) {
    await prisma.usuario.upsert({
      where: { email: conta.email },
      update: {},
      create: {
        nome: conta.nome,
        email: conta.email,
        senhaHash: await hashDeSenha(conta.senha),
        papel: conta.papel,
      },
    })
  }

  console.log('Seed de demonstração aplicada:')
  for (const conta of DEMONSTRACAO) {
    console.log(`  ${conta.papel.padEnd(8)} ${conta.email}  senha: ${conta.senha}`)
  }
}

semear()
  .then(() => prisma.$disconnect())
  .catch(async (erro) => {
    console.error(erro)
    await prisma.$disconnect()
    process.exit(1)
  })
