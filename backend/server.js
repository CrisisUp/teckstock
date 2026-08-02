'use strict';

/**
 * server.js — TechStock Backend API
 *
 * Ordem de inicialização das variáveis:
 *   1. dotenv carrega .env (contém TECHSTOCK_SECRET_NAME e AWS_REGION)
 *   2. loadSecrets() lê o secret do AWS Secrets Manager e popula process.env
 *   3. Pool PostgreSQL e demais configs usam process.env já populado
 */

const dotenvResult = require('dotenv').config();
require('express-async-errors');

const express    = require('express');
const { Pool }   = require('pg');
const cors       = require('cors');
const helmet     = require('helmet');
const promClient = require('prom-client');
const path       = require('path');
const os         = require('os');
const { parseId, parseNonNeg, parseStr, parseTipo, parseQty } = require('./validation');

// ── AWS Secrets Manager ───────────────────────────────────────────────────────
// Carrega variáveis sensíveis do Secrets Manager antes de qualquer uso de process.env.
// Com retry/backoff e fail-fast: se os segredos essenciais não estiverem
// disponíveis após as tentativas, aborta o boot em vez de subir quebrado.
async function loadSecrets() {
  const secretName = process.env.TECHSTOCK_SECRET_NAME;
  const region     = process.env.AWS_REGION || 'us-east-1';

  // Secrets essenciais que o app não consegue operar sem (devem vir do secret
  // OU de variáveis de ambiente já definidas no deploy).
  const CRITICAIS = ['DB_HOST', 'DB_PASSWORD'];

  // Verifica se a CHAVE existe no env (não se o valor é vazio) — no dev local
  // com pg_hba 'trust', DB_PASSWORD vazio é legítimo e não deve abortar o boot.
  const temCriticais = () => CRITICAIS.every(k => Object.prototype.hasOwnProperty.call(process.env, k));

  if (!secretName) {
    console.log('[Secrets] TECHSTOCK_SECRET_NAME não definido — usando variáveis do ambiente');
    if (!temCriticais()) {
      console.error('[Secrets] CRÍTICO: DB_HOST/DB_PASSWORD não definidos no ambiente');
      process.exit(1);
    }
    return;
  }

  const sleep = (ms) => new Promise(r => setTimeout(r, ms));
  const { SecretsManagerClient, GetSecretValueCommand } =
    require('@aws-sdk/client-secrets-manager');

  const client = new SecretsManagerClient({ region });

  // 3 tentativas com backoff (2s, 4s) — Secrets Manager pode falhar por
  // throttling/transitório no boot de várias EC2 simultâneas.
  let lastErr = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const cmd  = new GetSecretValueCommand({ SecretId: secretName });
      const resp = await client.send(cmd);
      const secret = JSON.parse(resp.SecretString);

      Object.entries(secret).forEach(([k, v]) => { process.env[k] = v; });
      console.log(`[Secrets] Carregado: ${secretName} (${Object.keys(secret).length} variáveis)`);
      return;
    } catch (err) {
      lastErr = err;
      if (attempt < 3) {
        const delay = attempt * 2000;
        console.warn(`[Secrets] Tentativa ${attempt}/3 falhou (${err.message}) — retry em ${delay}ms`);
        await sleep(delay);
      }
    }
  }

  console.error(`[Secrets] Falha após 3 tentativas: ${lastErr.message}`);

  if (!temCriticais()) {
    console.error('[Secrets] CRÍTICO: DB_HOST/DB_PASSWORD não disponíveis — abortando boot');
    process.exit(1);
  }

  console.warn('[Secrets] Usando variáveis do ambiente como fallback (DB_HOST/DB_PASSWORD presentes)');
}

// ── Bootstrap assíncrono ──────────────────────────────────────────────────────
async function bootstrap() {

  // 1. Carrega secrets antes de qualquer uso de process.env
  await loadSecrets();

  const app  = express();
  const port = process.env.PORT || 3000;

  // ── Prometheus ──────────────────────────────────────────────────────────────
  promClient.collectDefaultMetrics({ prefix: 'techstock_' });
  const httpRequests = new promClient.Counter({
    name:       'techstock_http_requests_total',
    help:       'Total de requisições HTTP',
    labelNames: ['method', 'path', 'status'],
  });

  // ── CORS ────────────────────────────────────────────────────────────────────
  const allowedOrigins = (process.env.CORS_ORIGIN || '*')
    .split(',').map(o => o.trim()).filter(Boolean);

  app.use(cors({
    origin: (origin, cb) => {
      if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
        return cb(null, true);
      }
      cb(new Error(`CORS: origem bloqueada — ${origin}`));
    },
    methods:        ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'x-api-key'],
  }));

  // ── Segurança ───────────────────────────────────────────────────────────────
  app.use(helmet({ contentSecurityPolicy: false }));

  // ── API Key (opcional) ──────────────────────────────────────────────────────
  app.use((req, res, next) => {
    const key = process.env.API_KEY;
    if (!key) return next();
    if (req.path === '/api/health' || req.path === '/metrics') return next();
    if (req.headers['x-api-key'] !== key) {
      return res.status(401).json({ error: 'Unauthorized — x-api-key inválida' });
    }
    next();
  });

  // ── Contador de requisições (Corrigido para os Dashboards) ──────────────────
  app.use((req, _res, next) => {
    _res.on('finish', () => {
      // Pega o caminho original da rota tratada pelo Express (ex: /api/produtos/:id)
      // Se não houver rota mapeada (como um 404), usa o req.path como fallback
      let routePath = req.route ? req.baseUrl + req.route.path : req.baseUrl + req.path;
      
      if (!routePath) {
        routePath = req.url;
      }

      // Registra no Prometheus apenas requisições que pertencem à sua API de dados
      if (routePath.startsWith('/api/')) {
        httpRequests.inc({ 
          method: req.method, 
          path: routePath, 
          status: _res.statusCode 
        });
      }
    });
    next();
  });
  
  // ── Pool PostgreSQL ─────────────────────────────────────────────────────────
  const pool = new Pool({
    host:     process.env.DB_HOST     || 'localhost',
    port:     Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME     || 'techstock',
    user:     process.env.DB_USER     || 'techstock_user',
    password: process.env.DB_PASSWORD || '',
    min:      Number(process.env.DB_POOL_MIN) || 1,
    max:      Number(process.env.DB_POOL_MAX) || 5,
    idleTimeoutMillis:      30000,
    connectionTimeoutMillis: 5000,
    ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: false },
  });

  pool.on('error', (err) => console.error('[Pool error]', err.message));

  async function q(sql, params = []) {
    const client = await pool.connect();
    try { return await client.query(sql, params); }
    finally { client.release(); }
  }

  // ── Middlewares ─────────────────────────────────────────────────────────────
  app.use(express.json());
  // Serve o frontend (pasta ../frontend) na MESMA origem da API.
  // Isso permite abrir http://localhost:3000/ e ver o app sem CORS, e sem
  // precisar de servidor estático separado no desenvolvimento local.
  app.use(express.static(path.join(__dirname, '..', 'frontend')));

  // ── Métricas Prometheus ─────────────────────────────────────────────────────
  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', promClient.register.contentType);
    res.end(await promClient.register.metrics());
  });

  // ── Health ──────────────────────────────────────────────────────────────────
  app.get('/api/health', async (req, res) => {
    try {
      const { rows } = await q('SELECT NOW() AS ts, version() AS ver');
      res.json({
        ok:          true,
        database:    'connected',
        db:          rows[0],
        cors_origin: req.headers.origin || 'direct',
        hostname:    os.hostname(),
        uptime_s:    Math.floor(process.uptime()),
        uptime:      Math.floor(process.uptime()),
        env:         process.env.NODE_ENV || 'production',
        secret:      process.env.TECHSTOCK_SECRET_NAME || 'não configurado',
      });
    } catch (e) {
      res.status(503).json({ ok: false, error: e.message });
    }
  });

  // ── Categorias ──────────────────────────────────────────────────────────────
  app.get('/api/categorias', async (_req, res) => {
    const { rows } = await q('SELECT * FROM categorias ORDER BY nome');
    res.json(rows);
  });

  app.post('/api/categorias', async (req, res) => {
    const { nome, cor } = req.body;
    const n = parseStr(nome, 'nome', 80);
    // cor opcional: valida formato hex curto (#RGB) ou longo (#RRGGBB)
    const c = cor ? String(cor).trim() : '#6366f1';
    if (!/^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$/.test(c)) {
      const e = new Error('cor deve estar no formato hex (#RRGGBB)');
      e.status = 400;
      throw e;
    }
    const { rows } = await q(
      'INSERT INTO categorias (nome, cor) VALUES ($1, $2) RETURNING *',
      [n, c]
    );
    res.status(201).json(rows[0]);
  });

  // ── Produtos ────────────────────────────────────────────────────────────────
  app.get('/api/produtos', async (req, res) => {
    const { busca, categoria_id, alerta } = req.query;
    const params = [];
    const where  = ['p.ativo = TRUE'];

    if (busca) {
      params.push(`%${busca}%`);
      where.push(`(p.nome ILIKE $${params.length} OR p.codigo ILIKE $${params.length})`);
    }
    if (categoria_id) {
      params.push(parseId(categoria_id, 'categoria_id'));
      where.push(`p.categoria_id = $${params.length}`);
    }
    if (alerta === '1') {
      where.push('p.quantidade <= p.qtd_minima');
    }

    const { rows } = await q(`
      SELECT p.*, c.nome AS categoria_nome, c.cor AS categoria_cor
      FROM   produtos p
      LEFT   JOIN categorias c ON c.id = p.categoria_id
      WHERE  ${where.join(' AND ')}
      ORDER  BY p.nome
    `, params);
    res.json(rows);
  });

  app.get('/api/produtos/:id', async (req, res) => {
    const id = parseId(req.params.id, 'id');
    const { rows: [prod] } = await q(
      `SELECT p.*, c.nome AS categoria_nome, c.cor AS categoria_cor
       FROM   produtos p
       LEFT   JOIN categorias c ON c.id = p.categoria_id
       WHERE  p.id = $1 AND p.ativo = TRUE`,
      [id]
    );
    if (!prod) return res.status(404).json({ error: 'Produto não encontrado' });
    res.json(prod);
  });

  app.post('/api/produtos', async (req, res) => {
    const { codigo, nome, descricao, categoria_id, unidade,
            quantidade, qtd_minima, preco_custo, localizacao } = req.body;

    const c = parseStr(codigo, 'codigo', 30);
    const n = parseStr(nome, 'nome', 120);
    const un = unidade ? parseStr(unidade, 'unidade', 20) : 'un';

    const { rows } = await q(
      `INSERT INTO produtos
         (codigo,nome,descricao,categoria_id,unidade,quantidade,qtd_minima,preco_custo,localizacao)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [c, n, descricao ? String(descricao).trim().slice(0, 2000) : null,
       categoria_id ? parseId(categoria_id, 'categoria_id') : null,
       un,
       quantidade === undefined ? 0 : parseNonNeg(quantidade, 'quantidade'),
       qtd_minima === undefined ? 5 : parseNonNeg(qtd_minima, 'qtd_minima'),
       preco_custo === undefined ? 0 : parseNonNeg(preco_custo, 'preco_custo'),
       localizacao ? String(localizacao).trim().slice(0, 60) : null]
    );
    res.status(201).json(rows[0]);
  });

  app.put('/api/produtos/:id', async (req, res) => {
    const id = parseId(req.params.id, 'id');
    const { nome, descricao, categoria_id, unidade,
            qtd_minima, preco_custo, localizacao } = req.body;

    const n = parseStr(nome, 'nome', 120);
    const un = unidade ? parseStr(unidade, 'unidade', 20) : 'un';

    const { rows } = await q(
      `UPDATE produtos SET
         nome=$1, descricao=$2, categoria_id=$3, unidade=$4,
         qtd_minima=$5, preco_custo=$6, localizacao=$7
       WHERE id=$8 AND ativo=TRUE RETURNING *`,
      [n, descricao ? String(descricao).trim().slice(0, 2000) : null,
       categoria_id ? parseId(categoria_id, 'categoria_id') : null, un,
       parseNonNeg(qtd_minima, 'qtd_minima'),
       parseNonNeg(preco_custo, 'preco_custo'),
       localizacao ? String(localizacao).trim().slice(0, 60) : null, id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Produto não encontrado' });
    res.json(rows[0]);
  });

  app.delete('/api/produtos/:id', async (req, res) => {
    await q('UPDATE produtos SET ativo=FALSE WHERE id=$1', [parseId(req.params.id, 'id')]);
    res.json({ ok: true });
  });

  // ── Movimentos ──────────────────────────────────────────────────────────────
  app.post('/api/movimentos', async (req, res) => {
    const { produto_id, tipo, quantidade, motivo, responsavel } = req.body;

    const pid = parseId(produto_id, 'produto_id');
    const tp  = parseTipo(tipo);
    const qty = parseQty(quantidade);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const { rows: [prod] } = await client.query(
        'SELECT id, quantidade FROM produtos WHERE id=$1 AND ativo=TRUE FOR UPDATE',
        [pid]
      );
      if (!prod) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Produto não encontrado' });
      }

      let nova;
      if      (tp === 'entrada') nova = prod.quantidade + qty;
      else if (tp === 'saida')   nova = prod.quantidade - qty;
      else                       nova = qty;

      if (nova < 0) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Estoque insuficiente' });
      }

      await client.query('UPDATE produtos SET quantidade=$1 WHERE id=$2', [nova, pid]);

      const { rows: [mov] } = await client.query(
        `INSERT INTO movimentos
           (produto_id,tipo,quantidade,quantidade_anterior,quantidade_nova,motivo,responsavel)
         VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
        [pid, tp, qty, prod.quantidade, nova,
         motivo ? String(motivo).trim().slice(0, 200) : null,
         responsavel ? String(responsavel).trim().slice(0, 80) : 'web']
      );

      await client.query('COMMIT');
      res.status(201).json({ movimento: mov, quantidade_atual: nova });
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  });

  // Lista movimentos com filtros opcionais (evita N+1 no frontend)
  app.get('/api/movimentos', async (req, res) => {
    const { tipo, produto_id, categoria_id } = req.query;
    const params = [];
    const where  = ['1 = 1'];

    if (tipo) {
      params.push(tipo);
      where.push(`m.tipo = $${params.length}`);
    }
    if (produto_id) {
      params.push(parseId(produto_id, 'produto_id'));
      where.push(`m.produto_id = $${params.length}`);
    }
    if (categoria_id) {
      params.push(parseId(categoria_id, 'categoria_id'));
      where.push(`p.categoria_id = $${params.length}`);
    }

    const limite = Math.min(Math.max(Number(req.query.limite) || 200, 1), 1000);

    const { rows } = await q(
      `SELECT m.*, p.nome AS produto_nome, p.codigo AS produto_codigo
       FROM   movimentos m
       JOIN   produtos p ON p.id = m.produto_id
       WHERE  ${where.join(' AND ')}
       ORDER  BY m.criado_em DESC
       LIMIT  ${limite}`,
      params
    );
    res.json(rows);
  });

  app.get('/api/movimentos/:produto_id', async (req, res) => {
    const pid = parseId(req.params.produto_id, 'produto_id');
    const { rows } = await q(
      `SELECT m.*, p.nome AS produto_nome, p.codigo AS produto_codigo
       FROM   movimentos m
       JOIN   produtos p ON p.id = m.produto_id
       WHERE  m.produto_id = $1
       ORDER  BY m.criado_em DESC LIMIT 50`,
      [pid]
    );
    res.json(rows);
  });

  // ── Stats ───────────────────────────────────────────────────────────────────
  app.get('/api/stats', async (_req, res) => {
    const [total, alertas, valor, movHoje] = await Promise.all([
      q("SELECT COUNT(*) AS n FROM produtos WHERE ativo=TRUE"),
      q("SELECT COUNT(*) AS n FROM produtos WHERE ativo=TRUE AND quantidade <= qtd_minima"),
      q("SELECT COALESCE(SUM(quantidade * preco_custo),0) AS v FROM produtos WHERE ativo=TRUE"),
      q("SELECT COUNT(*) AS n FROM movimentos WHERE criado_em >= NOW() - INTERVAL '24 hours'"),
    ]);
    res.json({
      total_produtos:  Number(total.rows[0].n),
      alertas_estoque: Number(alertas.rows[0].n),
      valor_total:     Number(valor.rows[0].v),
      movimentos_hoje: Number(movHoje.rows[0].n),
    });
  });

  // ── Error handler ───────────────────────────────────────────────────────────
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    console.error('[ERROR]', err.stack || err.message);
    res.status(err.status || 500).json({ error: err.message });
  });

  // ── Start ───────────────────────────────────────────────────────────────────
  // Só escuta se for o entry point (node server.js). Quando importado por
  // testes, retorna o app para que o teste controle o listen/close.
  if (require.main === module) {
    app.listen(port, '0.0.0.0', () => {
      console.log(`[TechStock] rodando em http://0.0.0.0:${port} | hostname: ${os.hostname()}`);
      console.log(`[TechStock] NODE_ENV=${process.env.NODE_ENV}`);
      console.log(`[TechStock] DB_HOST=${process.env.DB_HOST}`);
      console.log(`[TechStock] DB_SSL=${process.env.DB_SSL}`);
      console.log(`[TechStock] CORS_ORIGIN=${process.env.CORS_ORIGIN}`);
      console.log(`[TechStock] SECRET=${process.env.TECHSTOCK_SECRET_NAME || 'não configurado'}`);

      if (dotenvResult.error) {
        console.warn(`[TechStock] dotenv: .env não encontrado — usando ambiente/systemd`);
      } else {
        console.log('[TechStock] dotenv: .env carregado');
      }
    });
  }

  return { app, pool };
}

// Inicia o servidor (entry point)
if (require.main === module) {
  bootstrap().catch(err => {
    console.error('[FATAL] Falha na inicialização:', err.message);
    process.exit(1);
  });
}

module.exports = { bootstrap };
