# 🖥️ TechStock — Rodar Localmente (sem AWS)

> Guia para executar o backend + frontend na sua máquina, **sem RDS, sem Secrets
> Manager, sem EC2**. Usa o PostgreSQL local (Windows) e o frontend via arquivos
> estáticos.

---

## ✅ Pré-requisitos (já instalados na sua máquina)

| Ferramenta | Versão | Onde verificar |
|---|---|---|
| Node.js | v24.18.0 | `node --version` |
| PostgreSQL | 17 e 18 (serviços ativos) | `net start` → `postgresql-x64-17/18` |
| psql | 17/18 | `C:\Program Files\PostgreSQL\17\bin\psql.exe` |

> Docker **não** é necessário — o Postgres nativo do Windows já está rodando.

---

## 🗺️ Arquitetura local

```
Navegador (frontend/ via arquivos ou servidor estático)
    │  http://localhost:3000/api/*
    ▼
Backend Node.js (backend/server.js, porta 3000)
    │  PostgreSQL (localhost:5432)
    ▼
Banco techstock (local) — criado pelo schema.sql
```

- **Frontend**: basta abrir `frontend/index.html` no navegador (ou servir via `npx serve`)
- **Backend**: `npm start` / `npm run dev` na pasta `backend/`
- **Sem AWS**: `TECHSTOCK_SECRET_NAME` vazio → o backend usa as variáveis do `.env` local

---

## 🚀 Passo a passo

### 1. Criar o banco e o usuário no Postgres local

Abra o **psql como postgres** (senha definida na instalação do PostgreSQL):

```powershell
"C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -h localhost
```

Dentro do psql, crie o usuário e o banco:

```sql
-- 1. Usuário da aplicação (troque a senha por uma sua)
CREATE USER techstock_user WITH PASSWORD 'sua_senha_local';

-- 2. Banco de dados
CREATE DATABASE techstock OWNER techstock_user;
```

> 💡 Se preferir, pode usar o usuário `postgres` e só criar o banco. Nesse caso
> ajuste `DB_USER`/`DB_PASSWORD` no `.env`.

### 2. Criar o `.env` do backend

```powershell
cd backend
copy .env.example .env
```

Edite `.env` com os valores locais:

```env
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=techstock
DB_USER=techstock_user
DB_PASSWORD=sua_senha_local
DB_POOL_MIN=1
DB_POOL_MAX=5
DB_SSL=false          # ← IMPORTANTE: false no local (não há TLS)

# AWS — deixar VAZIO para rodar sem Secrets Manager
AWS_REGION=us-east-1
TECHSTOCK_SECRET_NAME=

API_KEY=              # vazio = sem exigência de chave
CORS_ORIGIN=http://localhost:3000
NODE_ENV=development
```

> ⚠️ `DB_SSL=false` é essencial — o backend ativa SSL por padrão (feito para o RDS).

### 3. Instalar dependências

```powershell
cd backend
npm install          # ou npm ci (usa package-lock.json)
```

### 4. Aplicar o schema no banco

```powershell
cd backend
$env:PGPASSWORD = "sua_senha_local"   # ou defina no ambiente
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" `
  -h localhost -U techstock_user -d techstock -f schema.sql
```

> O schema é **idempotente** — pode rodar quantas vezes quiser (cria tabelas,
> índices, triggers e os dados de exemplo com `ON CONFLICT DO NOTHING`).

### 5. Subir o backend

```powershell
cd backend
npm run dev          # modo dev (auto-reload) — ou npm start
```

Verifique:

```powershell
curl http://localhost:3000/api/health
# → {"ok":true,"database":"connected", ...}
```

### 6. Abrir o frontend

Opção A — direto (mais simples): abra `frontend/index.html` no navegador.
Como a URL padrão de dev já é `http://localhost:3000`, **funciona sem config**.

Opção B — servidor estático (opcional, mais realista):

```powershell
cd frontend
npx serve .          # → http://localhost:3001
```

> Se usar a opção B, acesse `http://localhost:3001` e, se a API não aparecer,
> clique em **⚙ Configurar** e informe `http://localhost:3000`.

---

## 🧪 Rodar os testes

```powershell
cd backend
npm test             # 27 testes (validação + integração com mock de pg)
```

> Os testes **não precisam de banco** — usam um mock de `pg`. Rodam em segundos.

---

## 🔍 Troubleshooting local

| Sintoma | Causa | Fix |
|---|---|---|
| `/api/health` retorna `503` | Banco não criado ou credenciais erradas | Rever passos 1–2; testar conexão no psql |
| `ECONNREFUSED :5432` | Serviço Postgres parado | `net start postgresql-x64-17` |
| `password authentication failed` | Senha do usuário errada | Corrigir `DB_PASSWORD` no `.env` |
| `FATAL: database "techstock" does not exist` | Banco não criado | Passo 1: `CREATE DATABASE techstock` |
| Backend sai com `CRÍTICO: DB_HOST/DB_PASSWORD` | `.env` não criado ou incompleto | Copiar `.env.example` → `.env` e preencher |
| Frontend sem dados (JSON parse error) | `config.js` com URL errada | Apagar `config.js` (usa default localhost) ou corrigir via ⚙ |

---

## 📌 Resumo dos arquivos que importam para o local

| Arquivo | Papel no local |
|---|---|
| `backend/.env` | Configuração local (criado do `.env.example`) |
| `backend/schema.sql` | Cria tabelas + dados de exemplo |
| `backend/server.js` | API (porta 3000) |
| `frontend/index.html` | Interface (abrir no navegador) |
| `frontend/config.js.example` | Referência do `config.js` (opcional localmente) |
