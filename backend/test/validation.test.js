'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { parseId, parseNonNeg, parseStr, parseTipo, parseQty } = require('../validation');

// ── parseId ──────────────────────────────────────────────────────────────────
test('parseId aceita inteiro positivo', () => {
  assert.equal(parseId('5'), 5);
  assert.equal(parseId(7), 7);
});

test('parseId rejeita valores não inteiros ou não positivos', () => {
  for (const v of ['abc', '0', '-3', '2.5', '', 'NaN', 'Infinity']) {
    assert.throws(() => parseId(v), (e) => e.status === 400, `deveria rejeitar ${JSON.stringify(v)}`);
  }
});

test('parseId usa label na mensagem de erro', () => {
  assert.throws(() => parseId('x', 'produto_id'), /produto_id inválido/);
});

// ── parseNonNeg ──────────────────────────────────────────────────────────────
test('parseNonNeg aceita zero e decimais', () => {
  assert.equal(parseNonNeg(0, 'qtd'), 0);
  assert.equal(parseNonNeg('12.50', 'preco'), 12.5);
});

test('parseNonNeg rejeita negativos e NaN', () => {
  for (const v of ['-1', 'abc', '', 'Infinity']) {
    assert.throws(() => parseNonNeg(v, 'qtd'), (e) => e.status === 400, `deveria rejeitar ${JSON.stringify(v)}`);
  }
});

// ── parseStr ─────────────────────────────────────────────────────────────────
test('parseStr faz trim e aceita no limite', () => {
  assert.equal(parseStr('  olá  ', 'nome'), 'olá');
  assert.equal(parseStr('x'.repeat(200), 'nome', 200), 'x'.repeat(200));
});

test('parseStr rejeita vazio/undefined e overflow', () => {
  for (const v of ['', '   ', undefined, null]) {
    assert.throws(() => parseStr(v, 'nome'), (e) => e.status === 400, `deveria rejeitar ${JSON.stringify(v)}`);
  }
  assert.throws(() => parseStr('x'.repeat(201), 'nome', 200), (e) => e.status === 400);
});

// ── parseTipo ────────────────────────────────────────────────────────────────
test('parseTipo aceita entrada/saida/ajuste', () => {
  for (const t of ['entrada', 'saida', 'ajuste']) assert.equal(parseTipo(t), t);
});

test('parseTipo rejeita tipos inválidos', () => {
  for (const t of ['', 'x', 'ENTRADA', 123, undefined]) {
    assert.throws(() => parseTipo(t), (e) => e.status === 400, `deveria rejeitar ${JSON.stringify(t)}`);
  }
});

// ── parseQty ─────────────────────────────────────────────────────────────────
test('parseQty aceita inteiro positivo', () => {
  assert.equal(parseQty('3'), 3);
  assert.equal(parseQty(1), 1);
});

test('parseQty rejeita zero, negativo e decimal', () => {
  for (const v of ['0', '-1', '2.5', 'abc', '', undefined]) {
    assert.throws(() => parseQty(v), (e) => e.status === 400, `deveria rejeitar ${JSON.stringify(v)}`);
  }
});
