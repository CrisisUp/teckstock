'use strict';

// ══════════════════════════════════════════════════════════════════════════════
// service-ui.js — Badges Grafana/Prometheus + Config de serviços
// ══════════════════════════════════════════════════════════════════════════════
// Extraído do <script> inline do index.html (F10).
// Carregado DEPOIS de app.js (depende de openConfig/saveConfig/abrirNovaMovimentacao).

// ── Constantes de localStorage ───────────────────────────────────────────────
const LS_GRAF = 'techstock_grafana_url';
const LS_PROM = 'techstock_prometheus_url';

function getGrafUrl() { return localStorage.getItem(LS_GRAF) || ''; }
function getPromUrl() { return localStorage.getItem(LS_PROM) || ''; }
function setGrafUrl(u) { localStorage.setItem(LS_GRAF, u.replace(/\/$/, '')); }
function setPromUrl(u) { localStorage.setItem(LS_PROM, u.replace(/\/$/, '')); }

function openService(svc) {
  const url = svc === 'graf' ? getGrafUrl() : getPromUrl();
  if (!url) { openConfig(); return; }
  window.open(url, '_blank', 'noopener,noreferrer');
}

async function checkService(url, badgeId) {
  const el = document.getElementById(badgeId);
  if (!el) return;
  const label = badgeId === 'graf-badge' ? 'Grafana' : 'Prometheus';
  if (!url) {
    el.className = el.className.replace(/\b(ok|fail|busy)\b/g, '').trim() + ' fail';
    el.textContent = '⬤ ' + label; return;
  }
  el.className = el.className.replace(/\b(ok|fail|busy)\b/g, '').trim() + ' busy';
  try {
    await pingUrl(url);
    el.className = el.className.replace(/\b(ok|fail|busy)\b/g, '').trim() + ' ok';
  } catch {
    el.className = el.className.replace(/\b(ok|fail|busy)\b/g, '').trim() + ' fail';
  }
  el.textContent = '⬤ ' + label;
}

async function testService(svc) {
  const isGraf = svc === 'graf';
  const urlEl  = document.getElementById(isGraf ? 'cfg-graf-url' : 'cfg-prom-url');
  const resEl  = document.getElementById(isGraf ? 'cfg-graf-res' : 'cfg-prom-res');
  const url    = urlEl.value.trim().replace(/\/$/, '');
  if (!url) { resEl.className = 'tr-res fail'; resEl.textContent = '❌ Informe a URL'; return; }
  resEl.className = 'tr-res busy'; resEl.textContent = '🔌 Testando...';
  try {
    await pingUrl(url);
    resEl.className = 'tr-res ok'; resEl.textContent = '✅ Acessível em ' + url;
  } catch (e) {
    resEl.className = 'tr-res fail'; resEl.textContent = '❌ ' + e.message;
  }
}

// Verifica se uma URL responde SEM sofrer bloqueio de CORS.
// fetch no-cors resolve quando a conexão HTTP funciona (o navegador recebe
// resposta, mesmo 4xx) e rejeita quando o servidor está fora do ar/inalcançável.
// O status exato fica oculto (opaque), mas para "o serviço está de pé?" basta.
// O motivo de usar no-cors: Grafana/Prometheus não enviam Access-Control-Allow-Origin,
// e um fetch normal seria bloqueado pelo CORS mesmo com o serviço no ar.
function pingUrl(url, timeoutMs = 6000) {
  return fetch(url, { method: 'HEAD', signal: AbortSignal.timeout(timeoutMs), mode: 'no-cors' })
    .then(() => undefined)             // servidor respondeu
    .catch(() => { throw new Error('Sem resposta — verifique se o serviço está no ar'); });
}

async function testAllServices() {
  // Dispara os três em paralelo; cada um escreve no seu campo de resultado.
  // O await garante que o botão fica ativo até todos terminarem (e erros não
  // viram unhandled rejection).
  await Promise.all([
    testApi(),
    testService('graf'),
    testService('prom'),
  ]);
}

// ── Hooks de extensão (em vez de monkey-patches) ─────────────────────────────
// O app.js chama window.__extX() se estiverem definidos. Aqui registramos
// as extensões — sem sobrescrever funções (mais robusto que o padrão antigo).

// Ao abrir o modal de config, preenche os campos de Grafana/Prometheus
window.__extOpenConfig = () => {
  document.getElementById('cfg-graf-url').value         = getGrafUrl();
  document.getElementById('cfg-graf-atual').textContent = getGrafUrl() || '(não configurado)';
  document.getElementById('cfg-graf-res').textContent   = '';
  document.getElementById('cfg-graf-res').className     = 'tr-res';
  document.getElementById('cfg-prom-url').value         = getPromUrl();
  document.getElementById('cfg-prom-atual').textContent = getPromUrl() || '(não configurado)';
  document.getElementById('cfg-prom-res').textContent   = '';
  document.getElementById('cfg-prom-res').className     = 'tr-res';
};

// Ao salvar a config, persiste as URLs de Grafana/Prometheus
window.__extSaveConfig = () => {
  const grafUrl = document.getElementById('cfg-graf-url').value.trim().replace(/\/$/, '');
  const promUrl = document.getElementById('cfg-prom-url').value.trim().replace(/\/$/, '');
  if (grafUrl) setGrafUrl(grafUrl);
  if (promUrl) setPromUrl(promUrl);
};

// Popula o select de produtos no modal "Nova Movimentação"
async function _populateMovNovoProdSel() {
  const sel = document.getElementById('mn-mov-psel');
  if (!sel || sel.dataset.loaded) return;
  try {
    const prods = await api('/api/produtos');
    sel.innerHTML = '<option value="">Selecione o produto...</option>' +
      prods.map(p => `<option value="${p.id}">${esc(p.nome)}</option>`).join('');
    sel.dataset.loaded = '1';
  } catch { /* silencioso */ }
}
window.__extAbrirMovNovo = () => { _populateMovNovoProdSel(); };

// ── Checks periódicos dos badges ─────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  setTimeout(() => {
    checkService(getGrafUrl(), 'graf-badge');
    checkService(getPromUrl(), 'prom-badge');
  }, 800);
  setInterval(() => {
    checkService(getGrafUrl(), 'graf-badge');
    checkService(getPromUrl(), 'prom-badge');
  }, 60000);
});
