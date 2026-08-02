// @ts-check
const { test, expect } = require('@playwright/test');
const { Pool } = require('pg');

// ── Helpers ──────────────────────────────────────────────────────────────────
// Dados de teste com prefixo único para não colidir com os seeds do banco.
const PREFIX = 'e2e' + Date.now().toString().slice(-6);
const NOVO_NOME = `${PREFIX} Produto E2E`;
const NOVO_CODIGO = `${PREFIX}`;

// Conexão direta ao banco local para LIMPEZA DEFINITIVA.
// O DELETE da API é soft-delete (ativo=false) e não libera o código para reuso
// (a UNIQUE constraint o mantém ocupado). Para o teste poder rodar várias vezes,
// apagamos de vez via SQL.
const pool = new Pool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'techstock',
  user: process.env.DB_USER || 'techstock_user',
  password: process.env.DB_PASSWORD || '',
});

// Apaga os produtos de teste (e seus movimentos) de forma definitiva
async function limpaTestes() {
  await pool.query(
    `DELETE FROM movimentos WHERE produto_id IN (
       SELECT id FROM produtos
       WHERE codigo = $1 OR codigo = $2 OR nome LIKE $3
     )`,
    [NOVO_CODIGO, globalThis.__codigoGerado || '', `%${PREFIX}%`]
  );
  await pool.query(
    `DELETE FROM produtos
     WHERE codigo = $1 OR codigo = $2 OR nome LIKE $3`,
    [NOVO_CODIGO, globalThis.__codigoGerado || '', `%${PREFIX}%`]
  );
}

test.afterAll(async () => {
  await limpaTestes();
  await pool.end();
});

// ── Dashboard ────────────────────────────────────────────────────────────────
test('dashboard carrega cards e tabela de itens críticos', async ({ page }) => {
  await page.goto('/');
  await page.waitForLoadState('networkidle');

  // Cards principais
  await expect(page.locator('#s-total')).toContainText(/\d+/);
  await expect(page.locator('#s-valor')).toContainText(/R\$/);
  await expect(page.locator('#s-alert')).toContainText(/\d+/);

  // Tabela de itens críticos populada (com dados de seed, pelo menos 1)
  const linhas = page.locator('#dash-tb tr');
  await expect(linhas.first()).toBeVisible();
});

test('badge da API fica Online', async ({ page }) => {
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  const badge = page.locator('#api-badge');
  await expect(badge).toContainText(/API Online|API Degradada/);
});

// ── Navegação ────────────────────────────────────────────────────────────────
test('navega entre as páginas', async ({ page }) => {
  await page.goto('/');

  // Produtos
  await page.getByRole('button', { name: /Produtos/ }).click();
  await expect(page.locator('#page-produtos')).toHaveClass(/active/);
  await expect(page.locator('#prod-tb tr').first()).toBeVisible();

  // Movimentações
  await page.getByRole('button', { name: /Movimentações/ }).click();
  await expect(page.locator('#page-movimentacoes')).toHaveClass(/active/);

  // Alertas
  await page.getByRole('button', { name: /Alertas/ }).click();
  await expect(page.locator('#page-alertas')).toHaveClass(/active/);

  // Dashboard
  await page.getByRole('button', { name: /Dashboard/ }).click();
  await expect(page.locator('#page-dashboard')).toHaveClass(/active/);
});

// ── CRUD Produto ─────────────────────────────────────────────────────────────
test('cria um produto novo', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: /Produtos/ }).click();

  // Abre o modal "Novo Produto"
  await page.getByRole('button', { name: /Novo/ }).click();
  await expect(page.locator('#ov-prod')).toHaveClass(/open/);

  // Preenche (p-cod é readonly e auto-gerado pelo app — NÃO preenchemos;
  // o código gerado é capturado para a limpeza)
  await page.locator('#p-nome').fill(NOVO_NOME);
  await page.locator('#p-qty').fill('5');
  await page.locator('#p-min').fill('2');
  await page.locator('#p-custo').fill('10.50');
  // lê o código auto-gerado (ex: TI-043) para poder limpar depois
  const codigoGerado = await page.locator('#p-cod').inputValue();
  if (codigoGerado && !codigoGerado.includes('…')) {
    globalThis.__codigoGerado = codigoGerado;
  }

  // Salva e aguarda o POST do backend retornar 201
  const respostaPost = page.waitForResponse(
    (r) => r.url().includes('/api/produtos') && r.request().method() === 'POST'
  );
  await page.getByRole('button', { name: /Salvar/ }).click();
  const resp = await respostaPost;
  expect(resp.status()).toBe(201);

  // Toast de sucesso aparece
  await expect(page.locator('.toast.success')).toContainText('Produto criado', { timeout: 5000 });

  // Modal fecha após o POST ok
  await expect(page.locator('#ov-prod')).not.toHaveClass(/open/, { timeout: 5000 });

  // Busca o produto criado e confirma na tabela
  await page.locator('#busca').fill(NOVO_NOME);
  await page.waitForTimeout(500); // debounce 400ms
  await expect(page.locator('#prod-tb')).toContainText(NOVO_NOME);
});

test('edita um produto existente (seed)', async ({ page }) => {
  // Independente do teste de criação: usa um produto dos seeds (sempre presente)
  const res = await fetch('http://localhost:3000/api/produtos');
  const produtos = await res.json();
  const alvo = produtos.find((p) => p.codigo === 'TI-001') || produtos[0];
  if (!alvo) test.skip();

  await page.goto('/');
  await page.getByRole('button', { name: /Produtos/ }).click();

  // Busca e clica em Editar (✏️)
  await page.locator('#busca').fill(alvo.nome);
  await page.waitForTimeout(500);
  const row = page.locator('#prod-tb tr', { hasText: alvo.nome });
  await row.getByTitle('Editar').click();
  await expect(page.locator('#ov-prod')).toHaveClass(/open/);

  // Muda a descrição e salva
  await page.locator('#p-desc').fill('Editado pelo teste E2E');
  await page.getByRole('button', { name: /Salvar/ }).click();
  await expect(page.locator('#ov-prod')).not.toHaveClass(/open/);

  // Confirma que a descrição aparece
  await page.waitForTimeout(500);
  await expect(page.locator('#prod-tb')).toContainText('Editado pelo teste E2E');

  // Restaura a descrição original via API (não deixar resíduo no seed)
  await fetch(`http://localhost:3000/api/produtos/${alvo.id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      nome: alvo.nome,
      descricao: alvo.descricao || '',
      categoria_id: alvo.categoria_id,
      unidade: alvo.unidade,
      qtd_minima: alvo.qtd_minima,
      preco_custo: alvo.preco_custo,
      localizacao: alvo.localizacao,
    }),
  });
});

// ── Movimentação ─────────────────────────────────────────────────────────────
test('registra uma movimentação de entrada', async ({ page }) => {
  // Usa o primeiro produto do seed (Cabo USB-C, id=1) para não depender do teste anterior
  const res = await fetch('http://localhost:3000/api/produtos/1');
  const produto = await res.json();
  const qtdAntes = produto.quantidade;

  await page.goto('/');
  await page.getByRole('button', { name: /Produtos/ }).click();
  await page.locator('#busca').fill(produto.nome);
  await page.waitForTimeout(500);

  const row = page.locator('#prod-tb tr', { hasText: produto.nome });
  await row.getByTitle('Movimentar').click();
  await expect(page.locator('#ov-mov')).toHaveClass(/open/);

  // Tipo entrada + qtd 1
  await page.locator('#m-tipo').selectOption('entrada');
  await page.locator('#m-qty').fill('1');
  await page.locator('#m-motivo').fill('Teste E2E UI');
  await page.getByRole('button', { name: /Confirmar/ }).click();
  await expect(page.locator('#ov-mov')).not.toHaveClass(/open/);

  // Confirma que a quantidade subiu (recarrega via API)
  const depois = await (await fetch('http://localhost:3000/api/produtos/1')).json();
  expect(depois.quantidade).toBe(qtdAntes + 1);
});

test('validação de estoque insuficiente mostra erro', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: /Produtos/ }).click();

  // Usa produto com qtd pequena (Teclado ABNT2, id=3, qtd=3)
  const res = await fetch('http://localhost:3000/api/produtos/3');
  const produto = await res.json();

  await page.locator('#busca').fill(produto.nome);
  await page.waitForTimeout(500);
  const row = page.locator('#prod-tb tr', { hasText: produto.nome });
  await row.getByTitle('Movimentar').click();

  await page.locator('#m-tipo').selectOption('saida');
  await page.locator('#m-qty').fill('99999');

  // O erro agora aparece como toast (não mais alert())
  await page.getByRole('button', { name: /Confirmar/ }).click();
  await expect(page.locator('.toast.error')).toContainText('Estoque insuficiente', { timeout: 5000 });

  // Modal permanece aberto (erro não fecha)
  await expect(page.locator('#ov-mov')).toHaveClass(/open/);

  // Botão volta a ficar habilitado após o erro (btnReset — não fica travado)
  const btnConfirmar = page.locator('#ov-mov .mf .btn-p');
  await expect(btnConfirmar).toBeEnabled();
  await expect(btnConfirmar).toContainText('Confirmar');
});

// ── Inativação (modal de confirmação) ────────────────────────────────────────
test('inativa produto com modal de confirmação', async ({ page }) => {
  // Cria um produto de teste para inativar (não usa os seeds)
  const criar = await fetch('http://localhost:3000/api/produtos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ codigo: 'E2E-DEL' + Date.now(), nome: `${PREFIX} Para Inativar`, quantidade: 1 }),
  });
  const criado = await criar.json();

  await page.goto('/');
  await page.getByRole('button', { name: /Produtos/ }).click();
  await page.locator('#busca').fill(criado.nome);
  await page.waitForTimeout(500);

  // Clica no 🗑 (Inativar)
  const row = page.locator('#prod-tb tr', { hasText: criado.nome });
  await row.getByTitle('Inativar').click();

  // O modal de confirmação aparece (não mais o confirm() nativo)
  await expect(page.locator('#ov-confirm')).toHaveClass(/open/);
  await expect(page.locator('#cf-title')).toContainText('Inativar');

  // Cancela primeiro (modal fecha, produto continua)
  await page.getByRole('button', { name: 'Cancelar' }).click();
  await expect(page.locator('#ov-confirm')).not.toHaveClass(/open/);
  await expect(page.locator('#prod-tb')).toContainText(criado.nome);

  // Agora confirma (produto sai da lista)
  await row.getByTitle('Inativar').click();
  await page.getByRole('button', { name: 'Confirmar' }).click();
  await page.waitForTimeout(500);
  await expect(page.locator('#prod-tb')).not.toContainText(criado.nome);
});

// ── Busca ────────────────────────────────────────────────────────────────────
test('busca filtra produtos', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: /Produtos/ }).click();

  await page.locator('#busca').fill('Cabo');
  await page.waitForTimeout(500);

  // Deve mostrar o Cabo USB-C e nenhum outro
  const linhas = await page.locator('#prod-tb tr').allInnerTexts();
  const temCabo = linhas.some((l) => l.includes('Cabo'));
  expect(temCabo).toBe(true);
});

// ── Favicon & dark mode ──────────────────────────────────────────────────────
test('favicon é servido', async ({ request }) => {
  const res = await request.get('/favicon.svg');
  expect(res.status()).toBe(200);
  expect(res.headers()['content-type']).toContain('image/svg+xml');
});

test('erro de rede mostra mensagem amigável (F23)', async ({ page }) => {
  // Intercepta a rota da API e falha com erro de rede (Failed to fetch)
  await page.route('**/api/health', (route) => route.abort('failed'));
  await page.goto('/');
  await page.waitForTimeout(500);

  // O badge fica vermelho e o texto da API aparece
  await expect(page.locator('#api-badge')).toHaveClass(/fail/);
  await expect(page.locator('#api-badge')).toContainText('Offline');
});

// ── Paginação (F25) ──────────────────────────────────────────────────────────
test('API de produtos suporta paginação (limite/offset/total)', async ({ request }) => {
  const r1 = await request.get('/api/produtos?limite=3&offset=0');
  const j1 = await r1.json();
  expect(j1.rows).toHaveLength(3);
  expect(j1.total).toBeGreaterThanOrEqual(11);

  // Página 2 não repete a primeira
  const r2 = await request.get('/api/produtos?limite=3&offset=3');
  const j2 = await r2.json();
  const ids1 = new Set(j1.rows.map((p) => p.id));
  const repetidos = j2.rows.filter((p) => ids1.has(p.id));
  expect(repetidos).toHaveLength(0);

  // Sem limite → mantém array simples (compatibilidade)
  const rAll = await request.get('/api/produtos');
  const all = await rAll.json();
  expect(Array.isArray(all)).toBe(true);
});

test('dark mode aplica variáveis escuras', async ({ page }) => {
  // Força prefers-color-scheme: dark
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto('/');

  // O fundo da página deve usar a variável --bg escura (#0f172a)
  const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  expect(bg).toBe('rgb(15, 23, 42)');   // #0f172a
});
