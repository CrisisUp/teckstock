# 📦 TechStock — Controle de Estoque

Sistema de gestão de estoque com **backend Node.js**, **PostgreSQL** e **frontend vanilla**, implantável na **AWS** (RDS + EC2 + ALB) e rodando localmente sem nuvem.

![CI](https://github.com/CrisisUp/teckstock/actions/workflows/ci.yml/badge.svg)

---

## ✨ Funcionalidades

- **Dashboard** com cards de resumo, alertas de estoque e **gráficos** (Chart.js)
  - Estoque por categoria (donut) · Movimentos dos últimos 7 dias (barras)
- **Produtos**: CRUD completo, código auto-gerado, busca por **nome/código/localização**, filtro por categoria, **paginação**
- **Movimentações**: entrada/saída/ajuste com transação e validação de estoque (anti-corrida via `SELECT ... FOR UPDATE`), histórico por produto
- **Alertas**: produtos abaixo do mínimo com reposição rápida
- **Exportação CSV** das listas filtradas (formato `;` + BOM, compatível com Excel pt-BR)
- **Observabilidade**: métricas Prometheus (`/metrics`), dashboards Grafana, logs CloudWatch

---

## 🏗️ Stack

| Camada | Tecnologia |
|---|---|
| Backend | Node.js + Express + `pg` |
| Banco | PostgreSQL (RDS na AWS / local) |
| Frontend | HTML + CSS + JS puro (SPA leve, sem framework) |
| Gráficos | Chart.js (CDN) |
| Infra | Terraform (AWS: VPC, EC2, RDS, ALB, S3) |
| Observabilidade | Prometheus + Grafana + Node Exporter + CloudWatch Agent |
| CI/CD | GitHub Actions |
| Testes | `node:test` (backend) + Playwright (E2E) |

---

## 🚀 Rodar localmente (sem AWS)

Pré-requisitos: **Node.js 20+**, **PostgreSQL** (local ou Docker).

```bash
# 1. Banco: crie o usuário e o banco
psql -U postgres -c "CREATE USER techstock_user WITH PASSWORD 'sua_senha';"
psql -U postgres -c "CREATE DATABASE techstock OWNER techstock_user;"

# 2. Backend: configure e instale
cd backend
cp .env.example .env        # edite DB_USER/DB_PASSWORD (deixe DB_SSL=false no local)
npm install
psql -h localhost -U techstock_user -d techstock -f schema.sql

# 3. Rode o backend (serve o frontend na mesma origem)
npm run dev                 # http://localhost:3000

# 4. Testes
npm test                    # 27 testes (backend)
cd .. && npm run test:e2e   # 16 testes E2E (requer backend no ar)
```

> Detalhes e troubleshooting: **[guia-rodar-localmente.md](guia-rodar-localmente.md)**

---

## ☁️ Deploy AWS

Ordem de implantação e passos manuais do console: **[guia-implantacao-completo.md](guia-implantacao-completo.md)**

Stack provisionada por Terraform em `terraform/`:
- VPC com subnets públicas/privadas + NAT
- EC2: Backend (Node :3000), Frontend (Nginx :80), Monitoring (Grafana/Prometheus)
- RDS PostgreSQL (privado, senha via variável `db_password`)
- ALB com rotas `/api*`, `/grafana*`, `/prometheus*`
- S3 para o frontend estático (endurecido contra escrita anônima)

Setup dos servidores via scripts Bash idempotentes (`setup-backend-v4-fullsecrets.sh`, etc.) que gravam configuração no **Secrets Manager**.

> Monitoring: **[guia-monitoring-stack.md](guia-monitoring-stack.md)** · Multi-cloud: **[multicloud-aluno.md](multicloud-aluno.md)**

---

## 🧪 Testes

| Suíte | Como rodar | Cobertura |
|---|---|---|
| Backend (27) | `cd backend && npm test` | Validação de inputs, transação, rotas (mock de pg) |
| E2E (16) | `npm run test:e2e` | UI real (Playwright + Chromium) contra backend + Postgres |

O **CI (GitHub Actions)** roda as duas suítes a cada push/PR na `main`:
- `backend-tests`: `npm ci` + `npm test`
- `e2e-tests`: Postgres 16 real (service container) + schema + Chromium + 16 testes

---

## 🗂️ Estrutura

```
backend/          API Node.js (server.js, validation.js, schema.sql) + testes
frontend/         SPA (index.html, app.js, service-ui.js, style.css, config.js)
e2e/              Testes Playwright (config + spec)
terraform/        IaC AWS (VPC, EC2, RDS, ALB, S3, remote state)
monitoring/       Dashboards Grafana (JSON)
.github/workflows/  CI (GitHub Actions)
setup-*.sh        Scripts de provisionamento dos servidores
```

---

## 🔒 Segurança

- Segredos no **Secrets Manager** (nunca em código) — `.env` local apenas para dev
- Validação de inputs no backend (400s limpos, sem erros de cast)
- Escape XSS no frontend + validação de cores vindas da API
- CORS com allowlist, API Key opcional, `helmet`
- S3 bloqueado contra escrita anônima; RDS isolado em subnet privada

---

## 📄 Licença

Projeto didático (contexto SENAI). Sem licença formal definida.
