// @ts-check
const { defineConfig } = require('@playwright/test');

// Configuração dos testes E2E do TechStock.
// Roda contra o backend real em http://localhost:3000 (que também serve o
// frontend na mesma origem). O backend deve estar rodando: `npm start` na
// pasta backend/.
module.exports = defineConfig({
  testDir: './tests',
  timeout: 30000,
  fullyParallel: false,   // testes mexem no mesmo banco — roda em sequência
  workers: 1,
  retries: 0,
  reporter: [['list']],
  use: {
    baseURL: 'http://localhost:3000',
    headless: true,
    trace: 'on-first-retry',
  },
});
