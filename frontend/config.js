// config.js — TechStock
// ─────────────────────────────────────────────────────────────────────────────
// URL base da API TechStock. Em produção este arquivo é gerado pelo
// setup-frontend.sh com o DNS do ALB. Em dev local, o valor abaixo (localhost)
// é o padrão e o app funciona sem alterações.
//
// Para apontar para outro backend, edite apiUrl (sem barra no final).

window.TECHSTOCK_CONFIG = {
  apiUrl: 'http://localhost:3000',
};
