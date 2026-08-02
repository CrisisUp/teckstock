'use strict';

// Teste de integração das rotas da API usando um mock de `pg`.
// Valida que inputs inválidos retornam 400 (e não 500 de erro de cast) e que
// requisições válidas fluem (201/200) mesmo sem um Postgres real.
//
// O server.js exporta bootstrap() (que retorna { app, pool }) e só escuta em
// uma porta quando é o entry point — aqui controlamos o listen/close.

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const path = require('path');
const fs = require('fs');

// ── Mock de pg ───────────────────────────────────────────────────────────────
// Simula um pool cujas queries retornam 1 linha com valores nulos — suficiente
// para as validações de input (que rodam ANTES de tocar no banco) e para que
// os endpoints respondam 200/201 sem um Postgres real.
function installPgMock() {
  const Module = require('module');
  const mockPath = path.join(__dirname, '_mock_pg.js');
  fs.writeFileSync(mockPath,
    'module.exports = { Pool: function(){ return {\n' +
    '  connect: async () => ({ query: async () => ({ rows: [{ n: 0 }] }), release: () => {}, on: () => {} }),\n' +
    '  query: async () => ({ rows: [{ n: 0 }] }), on: () => {} }; } };');
  const origResolve = Module._resolveFilename;
  Module._resolveFilename = function (request, ...args) {
    if (request === 'pg') return mockPath;
    return origResolve.call(this, request, ...args);
  };
  return () => { Module._resolveFilename = origResolve; fs.unlinkSync(mockPath); };
}

let server;
let base;

// suprime logs do servidor no console do teste
const origError = console.error;
const origLog = console.log;

before(async () => {
  console.error = () => {};
  console.log = () => {};

  const restorePg = installPgMock();
  process.env.PORT = '0';                 // porta efêmera
  process.env.CORS_ORIGIN = '*';
  process.env.TECHSTOCK_SECRET_NAME = ''; // sem secret → usa env (precisa das críticas)
  process.env.DB_HOST = 'localhost';      // críticas presentes → não aborta o boot
  process.env.DB_PASSWORD = 'teste';

  const { bootstrap } = require('../server.js');
  const { app } = await bootstrap();

  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  base = `http://127.0.0.1:${server.address().port}`;

  console.error = origError;
  console.log = origLog;
  restorePg();
});

after(async () => {
  if (server) await new Promise((r) => server.close(r));
});

function request(method, p, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : '';
    const req = http.request(`${base}${p}`, {
      method,
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) },
    }, (res) => {
      let raw = '';
      res.on('data', (c) => raw += c);
      res.on('end', () => resolve({ status: res.statusCode, body: raw ? JSON.parse(raw) : {} }));
    });
    req.on('error', reject);
    req.end(data);
  });
}

// ── Casos ────────────────────────────────────────────────────────────────────
test('validação de inputs retorna 400 (não 500)', async (t) => {
  const invalidos = [
    ['POST', '/api/produtos', { codigo: 'X', nome: 'Y', quantidade: -5 }],
    ['POST', '/api/produtos', { codigo: 'X', nome: 'Y', preco_custo: 'abc' }],
    ['POST', '/api/produtos', { codigo: 'X' }],                                   // sem nome
    ['POST', '/api/produtos', { codigo: 'X', nome: 'Y', quantidade: '' }],        // string vazia
    ['PUT', '/api/produtos/abc', { nome: 'Z' }],                                  // id inválido
    ['PUT', '/api/produtos/1', { nome: 'Z', qtd_minima: -1 }],
    ['DELETE', '/api/produtos/abc'],
    ['POST', '/api/movimentos', { produto_id: 1, tipo: 'x', quantidade: 1 }],     // tipo inválido
    ['POST', '/api/movimentos', { produto_id: 1, tipo: 'entrada', quantidade: 2.5 }],
    ['POST', '/api/movimentos', { produto_id: 1, tipo: 'entrada', quantidade: 0 }],
    ['GET', '/api/movimentos/abc'],
    ['GET', '/api/produtos?categoria_id=abc'],
    ['GET', '/api/movimentos?produto_id=0'],
    ['POST', '/api/categorias', { nome: 'C', cor: 'vermelho' }],                  // cor não hex
  ];

  for (const [method, p, body] of invalidos) {
    await t.test(`${method} ${p} → 400`, async () => {
      const res = await request(method, p, body);
      assert.equal(res.status, 400, `esperado 400, obteve ${res.status}: ${JSON.stringify(res.body)}`);
      assert.ok(res.body.error, 'deveria ter campo error');
    });
  }
});

test('requisições válidas fluem (201/200)', async () => {
  const okCases = [
    ['POST', '/api/categorias', { nome: 'CategoriaTeste', cor: '#fff' }, 201],
    ['POST', '/api/produtos', { codigo: 'OK-1', nome: 'Valido', quantidade: 10 }, 201],
    ['GET', '/api/movimentos', undefined, 200],
    ['GET', '/api/movimentos?tipo=entrada', undefined, 200],
    ['GET', '/api/movimentos?produto_id=1&categoria_id=2', undefined, 200],
    ['GET', '/api/stats', undefined, 200],
    ['GET', '/api/health', undefined, 200],
  ];

  for (const [method, p, body, expected] of okCases) {
    const res = await request(method, p, body);
    assert.equal(res.status, expected, `esperado ${expected}, obteve ${res.status} para ${method} ${p}`);
  }
});
