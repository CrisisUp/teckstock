'use strict';

// ── Validação de inputs — TechStock ─────────────────────────────────────────
// Helpers centralizados: evitam 500s de erro de cast do Postgres quando o
// cliente envia tipo/valor inválido (devolvem 400 limpo).
// Extraídos de server.js para permitir testes unitários (node:test).

/** Valida um ID inteiro positivo. Retorna o número ou lança erro com status 400. */
function parseId(v, label = 'id') {
  const n = Number(v);
  if (!Number.isInteger(n) || n <= 0) {
    const err = new Error(`${label} inválido`);
    err.status = 400;
    throw err;
  }
  return n;
}

/** Valida um número maior ou igual a zero. Retorna o número ou lança erro 400. */
function parseNonNeg(v, label) {
  // Number('') é 0 — string vazia NÃO deve passar como zero silenciosamente.
  if (v === '' || v === null || v === undefined) {
    const err = new Error(`${label} deve ser um número maior ou igual a zero`);
    err.status = 400;
    throw err;
  }
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0) {
    const err = new Error(`${label} deve ser um número maior ou igual a zero`);
    err.status = 400;
    throw err;
  }
  return n;
}

/** Valida uma string obrigatória com limite de tamanho. Retorna trim ou lança erro 400. */
function parseStr(v, label, max = 200) {
  const s = String(v ?? '').trim();
  if (!s) {
    const err = new Error(`${label} é obrigatório`);
    err.status = 400;
    throw err;
  }
  if (s.length > max) {
    const err = new Error(`${label} deve ter no máximo ${max} caracteres`);
    err.status = 400;
    throw err;
  }
  return s;
}

/** Valida o tipo de movimento. Retorna o tipo ou lança erro 400. */
function parseTipo(v) {
  if (v !== 'entrada' && v !== 'saida' && v !== 'ajuste') {
    const err = new Error('tipo deve ser entrada, saida ou ajuste');
    err.status = 400;
    throw err;
  }
  return v;
}

/** Valida a quantidade de um movimento (inteiro positivo). Retorna ou lança erro 400. */
function parseQty(v) {
  const n = Number(v);
  if (!Number.isInteger(n) || n <= 0) {
    const err = new Error('quantidade deve ser um inteiro maior que zero');
    err.status = 400;
    throw err;
  }
  return n;
}

module.exports = { parseId, parseNonNeg, parseStr, parseTipo, parseQty };
