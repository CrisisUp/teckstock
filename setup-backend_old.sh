#!/bin/bash
# =============================================================================
# setup-backend.sh — Configuração do EC2 Backend TechStock
# Node.js :3000 | PostgreSQL (RDS) | Secrets Manager | Node Exporter | CloudWatch
# Execução via SSM Session Manager
#
# SECRETS MANAGER:
#   Todas as variáveis sensíveis (DB_HOST, DB_PASSWORD, CORS_ORIGIN) são
#   armazenadas em um secret JSON no AWS Secrets Manager.
#   O server.js lê o secret na inicialização via SDK AWS.
#   O .env local é gerado como fallback para desenvolvimento.
# =============================================================================

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 1 — VARIÁVEIS FIXAS
# ══════════════════════════════════════════════════════════════════════════════
DB_NAME="techstock"
DB_USER="techstock_user"
DB_PORT="5432"
DB_SSL="true"
NODE_EXPORTER_VERSION="1.7.0"
APP_DIR="/opt/techstock"
SECRET_NAME="techstock/backend"

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 2 — ENTRADA INTERATIVA DE DADOS
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "============================================"
echo " TechStock — Setup Backend"
echo " $(date)"
echo "============================================"
echo ""

# Região AWS
echo "Região AWS (ex: us-east-1, us-west-2, sa-east-1):"
read -p "  → " AWS_REGION_INPUT
AWS_REGION_INPUT="${AWS_REGION_INPUT// /}"
if [[ -z "$AWS_REGION_INPUT" ]]; then
  echo "  ✗ Obrigatório. Use o formato: us-east-1"
  read -p "  → " AWS_REGION_INPUT
  AWS_REGION_INPUT="${AWS_REGION_INPUT// /}"
fi
AWS_REGION="$AWS_REGION_INPUT"
echo "  ✓ AWS_REGION: $AWS_REGION"
echo ""

# RDS Endpoint
while true; do
  echo "Endpoint do RDS (sem porta):"
  echo "  Exemplo: techstock-db.xxxx.us-east-1.rds.amazonaws.com"
  echo "  Console AWS → RDS → Databases → techstock → Endpoint"
  read -p "  → " DB_HOST
  DB_HOST="${DB_HOST// /}"
  [[ -n "$DB_HOST" ]] && break
  echo "  ✗ Obrigatório. Tente novamente."
  echo ""
done
echo "  ✓ DB_HOST: $DB_HOST"
echo ""

# Senha do RDS
while true; do
  echo "Senha do banco (DB_PASSWORD):"
  read -s -p "  → " DB_PASSWORD
  echo ""
  [[ -n "$DB_PASSWORD" ]] && break
  echo "  ✗ Obrigatório. Tente novamente."
  echo ""
done
echo "  ✓ DB_PASSWORD: (definida)"
echo ""

# ALB DNS para CORS
while true; do
  echo "DNS do ALB (sem http://) para configurar CORS:"
  echo "  Exemplo: techstock-alb-105375070.us-east-1.elb.amazonaws.com"
  read -p "  → " ALB_INPUT
  ALB_INPUT="${ALB_INPUT// /}"
  ALB_INPUT="${ALB_INPUT#http://}"
  ALB_INPUT="${ALB_INPUT#https://}"
  ALB_INPUT="${ALB_INPUT%/}"
  [[ -n "$ALB_INPUT" ]] && break
  echo "  ✗ Obrigatório. Tente novamente."
  echo ""
done
CORS_ORIGIN="http://${ALB_INPUT}"
echo "  ✓ CORS_ORIGIN: $CORS_ORIGIN"
echo ""

# Nome do secret (opcional — usa padrão)
echo "Nome do secret no Secrets Manager (Enter para usar padrão: techstock/backend):"
read -p "  → " SECRET_INPUT
SECRET_INPUT="${SECRET_INPUT// /}"
[[ -n "$SECRET_INPUT" ]] && SECRET_NAME="$SECRET_INPUT"
echo "  ✓ SECRET_NAME: $SECRET_NAME"
echo ""

# GitHub
echo "URL base do repositório GitHub (raw):"
echo "  Exemplo: https://raw.githubusercontent.com/SEU_USER/SEU_REPO/main"
echo "  Como obter: GitHub → arquivo → botão Raw → copie a URL até /main"
read -p "  → " GITHUB_RAW
GITHUB_RAW="${GITHUB_RAW// /}"
GITHUB_RAW="${GITHUB_RAW%/}"
if [[ -n "$GITHUB_RAW" ]]; then
  echo "  ✓ GITHUB_RAW: $GITHUB_RAW"
  echo "  Subdiretório do backend no repo (Enter se raiz):"
  echo "  Exemplo: backend  ou  src/backend"
  read -p "  → " GITHUB_SUBDIR
  GITHUB_SUBDIR="${GITHUB_SUBDIR// /}"
  GITHUB_SUBDIR="${GITHUB_SUBDIR%/}"
  [[ -n "$GITHUB_SUBDIR" ]] && GITHUB_BASE="${GITHUB_RAW}/${GITHUB_SUBDIR}" || GITHUB_BASE="$GITHUB_RAW"
  echo "  ✓ URL arquivos: $GITHUB_BASE"
else
  GITHUB_BASE=""
  echo "  ⚠ Pulado — faça upload manual dos arquivos"
fi
echo ""

# Confirmação
echo "--------------------------------------------"
echo " Resumo da configuração:"
echo "   AWS_REGION  = $AWS_REGION"
echo "   DB_HOST     = $DB_HOST"
echo "   DB_NAME     = $DB_NAME"
echo "   DB_USER     = $DB_USER"
echo "   DB_PASSWORD = (definida)"
echo "   DB_SSL      = $DB_SSL"
echo "   CORS_ORIGIN = $CORS_ORIGIN"
echo "   SECRET_NAME = $SECRET_NAME"
echo "   GITHUB_BASE = ${GITHUB_BASE:-'(upload manual)'}"
echo "--------------------------------------------"
echo ""
read -p "Confirma e inicia a instalação? (s/N): " CONFIRM
[[ "$CONFIRM" =~ ^[Ss]$ ]] || { echo "Cancelado."; exit 0; }

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 3 — Sistema
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [1/8] Atualizando sistema ---"
dnf update -y
dnf install -y nodejs npm postgresql15 git wget
echo "Node.js: $(node --version) | npm: $(npm --version)"

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 4 — Usuário e diretório
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [2/8] Criando usuário e diretório ---"
useradd -r -m -d $APP_DIR -s /bin/bash techstock 2>/dev/null \
  && echo "Usuário techstock: criado" \
  || echo "Usuário techstock: já existe (ok)"
mkdir -p $APP_DIR/public

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 5 — AWS Secrets Manager
# Cria ou atualiza o secret com todas as variáveis sensíveis em JSON.
# O server.js lê este secret na inicialização usando o SDK AWS.
# Vantagens:
#   - Credenciais nunca ficam em arquivos de texto plano no disco
#   - Rotação de senha sem redeploy (atualiza o secret, reinicia o serviço)
#   - Auditoria via CloudTrail de quem acessou o secret
#   - LabInstanceProfile já tem permissão secretsmanager:GetSecretValue
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [3/8] Criando secret no AWS Secrets Manager ---"

SECRET_JSON=$(python3 -c "
import json
print(json.dumps({
  'DB_HOST':     '${DB_HOST}',
  'DB_PORT':     '${DB_PORT}',
  'DB_NAME':     '${DB_NAME}',
  'DB_USER':     '${DB_USER}',
  'DB_PASSWORD': '${DB_PASSWORD}',
  'DB_SSL':      '${DB_SSL}',
  'PORT':        '3000',
  'NODE_ENV':    'production',
  'CORS_ORIGIN': '${CORS_ORIGIN}',
  'AWS_REGION':  '${AWS_REGION}'
}))
")

# Verifica se o secret já existe
if aws secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" &>/dev/null; then

  echo "  Secret já existe — atualizando valor..."
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$SECRET_JSON" \
    --region "$AWS_REGION" \
    && echo "  ✓ Secret atualizado: $SECRET_NAME" \
    || { echo "  ✗ Erro ao atualizar secret"; exit 1; }
else
  echo "  Criando novo secret..."
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "TechStock Backend — variáveis de ambiente" \
    --secret-string "$SECRET_JSON" \
    --region "$AWS_REGION" \
    && echo "  ✓ Secret criado: $SECRET_NAME" \
    || { echo "  ✗ Erro ao criar secret — verifique permissões do LabRole"; exit 1; }
fi

echo ""
echo "  Conteúdo do secret (sem senha):"
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for k, v in d.items():
    print(f'    {k} = {\"(oculto)\" if \"PASSWORD\" in k or \"SECRET\" in k else v}')
"

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 6 — Arquivos da aplicação
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [4/8] Copiando arquivos da aplicação ---"

if [[ -n "$GITHUB_BASE" ]]; then
  echo "Baixando arquivos do GitHub: $GITHUB_BASE"
  mkdir -p $APP_DIR
  for f in server.js package.json schema.sql; do
    echo "  baixando $f..."
    if wget -q -O $APP_DIR/$f "$GITHUB_BASE/$f"; then
      echo "  ✓ $f"
    else
      echo "  ✗ $f — não encontrado em $GITHUB_BASE/$f"
    fi
  done
  for f in package-lock.json; do
    wget -q -O $APP_DIR/$f "$GITHUB_BASE/$f" 2>/dev/null && echo "  ✓ $f" || true
  done
  echo ""
  echo "Arquivos baixados:"
  ls -la $APP_DIR/
else
  echo ""
  echo "Copie os arquivos manualmente para $APP_DIR/:"
  echo "  GitHub (raw):"
  echo "    BASE=https://raw.githubusercontent.com/USER/REPO/main"
  echo "    for f in server.js package.json schema.sql; do"
  echo "      wget -O $APP_DIR/\$f \$BASE/\$f"
  echo "    done"
  echo ""
  echo "Pressione Enter após copiar os arquivos..."
  read -p ""
fi

for f in server.js package.json; do
  [[ ! -f $APP_DIR/$f ]] && { echo "ERRO: $APP_DIR/$f não encontrado."; exit 1; }
done
echo "Arquivos OK: $(ls $APP_DIR/*.js $APP_DIR/package.json 2>/dev/null | tr '\n' ' ')"

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 7 — npm install
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [5/8] Instalando dependências Node.js ---"
cd $APP_DIR
npm install --omit=dev
echo "Pacotes instalados: $(ls node_modules | wc -l)"

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 8 — .env local (fallback para desenvolvimento)
# O .env é usado apenas se o Secrets Manager não estiver disponível.
# Em produção (EC2 com LabInstanceProfile), o server.js lê do Secrets Manager.
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [6/8] Criando .env local (fallback) ---"

cat > $APP_DIR/.env << ENV
# .env — FALLBACK LOCAL
# Em produção, as variáveis são lidas do AWS Secrets Manager: ${SECRET_NAME}
# Este arquivo é usado apenas em desenvolvimento ou se o Secrets Manager falhar.
TECHSTOCK_SECRET_NAME=${SECRET_NAME}
AWS_REGION=${AWS_REGION}
PORT=3000
NODE_ENV=production
ENV

chown techstock:techstock $APP_DIR/.env
chmod 640 $APP_DIR/.env
echo "  ✓ .env criado (apenas TECHSTOCK_SECRET_NAME e AWS_REGION)"
echo ""
echo "  Secret name salvo: $SECRET_NAME"
echo "  O server.js deve ler as demais variáveis do Secrets Manager."
echo ""

chown -R techstock:techstock $APP_DIR
chmod 755 $APP_DIR

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 9 — Schema do banco
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [6b/8] Inicializando schema do banco ---"

if [[ -f $APP_DIR/schema.sql ]]; then
  echo "Executando schema.sql em $DB_HOST..."
  PGPASSWORD="$DB_PASSWORD" psql \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --set=sslmode=require \
    -f $APP_DIR/schema.sql \
    && echo "Schema: OK" \
    || echo "AVISO: erro no schema — execute manualmente se necessário"
else
  echo "schema.sql não encontrado. Execute depois:"
  echo "  PGPASSWORD='...' psql -h $DB_HOST -U $DB_USER -d $DB_NAME --set=sslmode=require -f schema.sql"
fi

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 10 — Serviço systemd
# EnvironmentFile passa apenas TECHSTOCK_SECRET_NAME e AWS_REGION.
# As demais variáveis sensíveis vêm do Secrets Manager em runtime.
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [7/8] Configurando serviço systemd ---"

cat > /etc/systemd/system/techstock.service << SVC
[Unit]
Description=TechStock Backend API
After=network.target

[Service]
Type=simple
User=techstock
WorkingDirectory=${APP_DIR}

# Apenas variáveis não-sensíveis via EnvironmentFile
# Variáveis sensíveis (DB_PASSWORD etc) vêm do Secrets Manager em runtime
EnvironmentFile=${APP_DIR}/.env

ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=techstock

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable techstock
systemctl start techstock
sleep 4

echo ""
echo "Status do serviço:"
systemctl is-active techstock

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 11 — Node Exporter + CloudWatch Agent
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [8/8] Instalando Node Exporter + CloudWatch Agent ---"

wget -q \
  "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" \
  -O /tmp/node_exporter.tar.gz
tar xzf /tmp/node_exporter.tar.gz -C /tmp/
cp /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/ 2>/dev/null || true
chmod +x /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service << 'NE'
[Unit]
Description=Node Exporter
After=network.target
[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure
[Install]
WantedBy=multi-user.target
NE

dnf install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CW
{
  "logs": {
    "logs_collected": {
      "systemd": {
        "collect_list": [
          {
            "log_group_name": "/techstock/app",
            "log_stream_name": "{instance_id}",
            "log_system_journal_id": "techstock"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "TechStock/EC2",
    "metrics_collected": {
      "cpu":  { "measurement": ["cpu_usage_active"],  "metrics_collection_interval": 60 },
      "mem":  { "measurement": ["mem_used_percent"],   "metrics_collection_interval": 60 },
      "disk": { "measurement": ["disk_used_percent"],  "resources": ["/"], "metrics_collection_interval": 60 }
    }
  }
}
CW

systemctl daemon-reload
systemctl enable node_exporter amazon-cloudwatch-agent
systemctl start  node_exporter amazon-cloudwatch-agent

# ══════════════════════════════════════════════════════════════════════════════
# VERIFICAÇÃO FINAL
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "============================================"
echo " Verificação Final"
echo "============================================"

echo ""
echo "Secret Manager:"
aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region "$AWS_REGION" \
  --query '{Name:Name,LastChanged:LastChangedDate}' \
  --output table 2>/dev/null || echo "  ✗ Secret não encontrado"

echo ""
echo "Serviços:"
for svc in techstock node_exporter amazon-cloudwatch-agent; do
  STATUS=$(systemctl is-active $svc 2>/dev/null)
  ICON=$([[ "$STATUS" == "active" ]] && echo "✓" || echo "✗")
  echo "  $ICON $svc: $STATUS"
done

echo ""
echo "Teste da API:"
sleep 2
curl -s http://localhost:3000/api/health | python3 -m json.tool 2>/dev/null \
  || curl -s http://localhost:3000/api/health

echo ""
echo "Teste CORS:"
curl -s -I -H "Origin: $CORS_ORIGIN" \
  http://localhost:3000/api/produtos 2>&1 | grep -i "access-control" \
  || echo "  (sem header CORS)"

echo ""
echo "Node Exporter:"
curl -s http://localhost:9100/metrics | grep "^node_load1" | head -1

echo ""
echo "============================================"
echo " Setup CONCLUÍDO: $(date)"
echo "============================================"
echo ""
MY_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
echo "IP privado desta instância: $MY_IP"
echo ""
echo "Secret Manager:"
echo "  Nome:   $SECRET_NAME"
echo "  Região: $AWS_REGION"
echo "  Console: AWS → Secrets Manager → $SECRET_NAME"
echo ""
echo "Para atualizar variáveis (sem redeploy):"
echo "  1. AWS → Secrets Manager → $SECRET_NAME → Retrieve secret value → Edit"
echo "  2. sudo systemctl restart techstock"
echo ""
echo "Para ver logs:"
echo "  sudo journalctl -u techstock -f"
echo ""
echo "PENDÊNCIAS MANUAIS (Console AWS):"
echo "  1. Adicionar este EC2 ao Target Group do ALB (porta 3000)"
echo "  2. SG do Backend: liberar 3000 e 9100 para o SG do EC2 Monitoring"
echo ""
echo "IMPORTANTE — server.js:"
echo "  O server.js precisa ser atualizado para ler do Secrets Manager."
echo "  Adicione no início do server.js (antes de usar process.env):"
echo "  Ver: aws-secrets-loader.js gerado em $APP_DIR/"
echo ""

# Gera helper de integração para o server.js
cat > $APP_DIR/aws-secrets-loader.js << 'LOADER'
/**
 * aws-secrets-loader.js
 * Lê variáveis do AWS Secrets Manager e popula process.env.
 * Chame ANTES de qualquer uso de process.env no server.js.
 *
 * Uso no server.js:
 *   await require('./aws-secrets-loader')();
 *   // A partir daqui process.env tem todas as variáveis do secret
 *
 * Fallback: se o Secrets Manager não estiver disponível,
 * usa as variáveis já presentes em process.env (vindas do .env via systemd).
 */
'use strict';

const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

module.exports = async function loadSecrets() {
  const secretName = process.env.TECHSTOCK_SECRET_NAME;
  const region     = process.env.AWS_REGION || 'us-east-1';

  if (!secretName) {
    console.log('[Secrets] TECHSTOCK_SECRET_NAME não definido — usando variáveis do ambiente');
    return;
  }

  try {
    const client = new SecretsManagerClient({ region });
    const cmd    = new GetSecretValueCommand({ SecretId: secretName });
    const resp   = await client.send(cmd);
    const secret = JSON.parse(resp.SecretString);

    // Popula process.env com os valores do secret
    Object.entries(secret).forEach(([k, v]) => {
      process.env[k] = v;
    });

    console.log(`[Secrets] Carregado: ${secretName} (${Object.keys(secret).length} variáveis)`);
  } catch (err) {
    console.warn(`[Secrets] Falha ao ler ${secretName}: ${err.message}`);
    console.warn('[Secrets] Usando variáveis do ambiente como fallback');
  }
};
LOADER

chown techstock:techstock $APP_DIR/aws-secrets-loader.js
echo "  ✓ aws-secrets-loader.js criado em $APP_DIR/"
