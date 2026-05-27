#!/bin/bash
# =============================================================================
# setup-frontend.sh — Configuração do EC2 Frontend TechStock
# Nginx :80 | config.js dinâmico | Node Exporter | CloudWatch Agent
# Execução via SSM Session Manager
# =============================================================================

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 1 — VARIÁVEIS FIXAS (não alterar)
# ══════════════════════════════════════════════════════════════════════════════
NODE_EXPORTER_VERSION="1.7.0"
WEBROOT="/usr/share/nginx/html/techstock"

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 2 — ENTRADA INTERATIVA DE DADOS
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "============================================"
echo " TechStock — Setup Frontend EC2 (Nginx)"
echo " $(date)"
echo "============================================"
echo ""

# ALB DNS — obrigatório
while true; do
  echo "DNS do ALB (sem http://):"
  echo "  Exemplo: techstock-alb-105375070.us-east-1.elb.amazonaws.com"
  echo "  Console AWS → EC2 → Load Balancers → DNS name"
  read -p "  → " ALB_INPUT
  ALB_INPUT="${ALB_INPUT// /}"
  ALB_INPUT="${ALB_INPUT#http://}"
  ALB_INPUT="${ALB_INPUT#https://}"
  ALB_INPUT="${ALB_INPUT%/}"
  [[ -n "$ALB_INPUT" ]] && break
  echo "  ✗ Obrigatório. Tente novamente."
  echo ""
done
ALB_DNS="$ALB_INPUT"
echo "  ✓ ALB_DNS: $ALB_DNS"
echo "  ✓ API_URL: http://$ALB_DNS"
echo ""

# Região AWS — obrigatório
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

# GitHub — URL base do repositório
echo "URL base do repositório GitHub (raw):"
echo "  Exemplo: https://raw.githubusercontent.com/SEU_USER/SEU_REPO/main"
echo "  Como obter: GitHub → arquivo → botão Raw → copie a URL até /main"
read -p "  → " GITHUB_RAW
GITHUB_RAW="${GITHUB_RAW// /}"
GITHUB_RAW="${GITHUB_RAW%/}"
if [[ -n "$GITHUB_RAW" ]]; then
  echo "  ✓ GITHUB_RAW: $GITHUB_RAW"
  echo "  Subdiretório do frontend no repo (Enter se raiz):"
  echo "  Exemplo: frontend  ou  src/frontend"
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
echo "   ALB_DNS   = $ALB_DNS"
echo "   API_URL   = http://$ALB_DNS"
   echo "   AWS_REGION = $AWS_REGION"
echo "   GITHUB    = ${GITHUB_BASE:-'(upload manual)'}"
echo "   WEBROOT   = $WEBROOT"
echo "--------------------------------------------"
echo "   WEBROOT   = $WEBROOT"
echo "--------------------------------------------"
echo ""
read -p "Confirma e inicia a instalação? (s/N): " CONFIRM
[[ "$CONFIRM" =~ ^[Ss]$ ]] || { echo "Cancelado."; exit 0; }

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 3 — Instalação do Nginx
# CORREÇÃO: nginx.conf substituído para remover server block default do AL2023
# que conflitava com a configuração customizada
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [1/6] Atualizando sistema e instalando Nginx ---"
dnf update -y
dnf install -y nginx wget
echo "Nginx: $(nginx -v 2>&1)"

# Substitui nginx.conf padrão — bloco server default do AL2023 conflita
cat > /etc/nginx/nginx.conf << 'NGXMAIN'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    include             /etc/nginx/conf.d/*.conf;
}
NGXMAIN
echo "nginx.conf: OK (server block default removido)"

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 4 — Diretório e arquivos
# CORREÇÃO: chown/chmod aplicados imediatamente após criação
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [2/6] Criando diretório do frontend ---"
mkdir -p $WEBROOT
chown -R nginx:nginx $WEBROOT
chmod -R 755 $WEBROOT

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 5 — Copia arquivos
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [3/6] Copiando arquivos do frontend ---"

if [[ -n "$GITHUB_BASE" ]]; then
  echo "Baixando arquivos do GitHub: $GITHUB_BASE"
  mkdir -p $WEBROOT
  for f in index.html style.css app.js config.js; do
    echo "  baixando $f..."
    if wget -q -O $WEBROOT/$f "$GITHUB_BASE/$f"; then
      echo "  ✓ $f"
    else
      echo "  ✗ $f — não encontrado em $GITHUB_BASE/$f"
    fi
  done
  chown -R nginx:nginx $WEBROOT/
  chmod -R 755 $WEBROOT/
  echo ""
  echo "Arquivos baixados:"
  ls -la $WEBROOT/
else
  echo ""
  echo "Copie os arquivos manualmente para $WEBROOT/:"
  echo ""
  echo "  GitHub (raw):"
  echo "    BASE=https://raw.githubusercontent.com/USER/REPO/main"
  echo "    for f in index.html style.css app.js config.js; do"
  echo "      wget -O $WEBROOT/\$f \$BASE/\$f"
  echo "    done"
  echo ""
  echo "  scp:"
  echo "    scp -i vockey.pem index.html style.css app.js config.js ec2-user@IP:/tmp/"
  echo "    sudo cp /tmp/{index.html,style.css,app.js,config.js} $WEBROOT/"
  echo ""
  echo "Pressione Enter após copiar os arquivos..."
  read -p ""
  chown -R nginx:nginx $WEBROOT/
  chmod -R 755 $WEBROOT/
fi

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 6 — Gera config.js com URL do ALB
# CRÍTICO: config.js contém a URL do ALB — deve ser gerado/atualizado aqui
# Se o S3 sobrescreveu com um config.js antigo, este bloco corrige
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [4/6] Configurando config.js ---"

cat > $WEBROOT/config.js << CFG
// config.js — gerado pelo setup-frontend.sh em $(date)
// NÃO edite manualmente — execute o script novamente para atualizar
window.TECHSTOCK_CONFIG = {
  apiUrl: 'http://${ALB_DNS}'
};
CFG

chown nginx:nginx $WEBROOT/config.js
chmod 644 $WEBROOT/config.js

echo "config.js gerado:"
cat $WEBROOT/config.js

echo ""
echo "Verificando arquivos:"
for f in index.html style.css app.js config.js; do
  if [[ -f $WEBROOT/$f ]]; then
    echo "  ✓ $f ($(stat -c%s $WEBROOT/$f) bytes)"
  else
    echo "  ✗ $f ← FALTANDO"
  fi
done

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 7 — Configuração do Nginx
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [5/6] Configurando Nginx ---"

cat > /etc/nginx/conf.d/techstock.conf << 'NGINX'
server {
    listen 80 default_server;
    server_name _;
    root  /usr/share/nginx/html/techstock;
    index index.html;

    # config.js: SEM cache — contém URL do ALB que pode mudar
    location = /config.js {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        add_header Pragma "no-cache";
        expires -1;
    }

    # SPA fallback
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache";
        add_header X-Frame-Options "SAMEORIGIN";
    }

    # CSS/JS com cache curto
    location ~* \.(css|js)$ {
        expires 1h;
        add_header Cache-Control "public, max-age=3600";
    }

    # Health check para o ALB
    location = /health {
        default_type application/json;
        return 200 '{"ok":true,"service":"frontend-nginx"}';
        add_header Content-Type application/json;
    }

    access_log /var/log/nginx/techstock-access.log;
    error_log  /var/log/nginx/techstock-error.log;
}
NGINX

nginx -t && echo "Configuração Nginx: OK" || { echo "ERRO na configuração Nginx!"; exit 1; }

systemctl enable nginx
# CORREÇÃO: restart (não start) garante que novo conf seja carregado
systemctl restart nginx
sleep 2
echo "nginx: $(systemctl is-active nginx)"

# ══════════════════════════════════════════════════════════════════════════════
# SEÇÃO 8 — Node Exporter + CloudWatch Agent
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- [6/6] Instalando Node Exporter + CloudWatch Agent ---"

wget -q \
  "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" \
  -O /tmp/node_exporter.tar.gz
tar xzf /tmp/node_exporter.tar.gz -C /tmp/
cp /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
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

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CW'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/techstock-access.log",
            "log_group_name": "/techstock/nginx-access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/techstock-error.log",
            "log_group_name": "/techstock/nginx-error",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "TechStock/Frontend",
    "metrics_collected": {
      "cpu":  { "measurement": ["cpu_usage_active"],  "metrics_collection_interval": 60 },
      "mem":  { "measurement": ["mem_used_percent"],   "metrics_collection_interval": 60 }
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
echo "Serviços:"
for svc in nginx node_exporter amazon-cloudwatch-agent; do
  STATUS=$(systemctl is-active $svc 2>/dev/null)
  ICON=$([[ "$STATUS" == "active" ]] && echo "✓" || echo "✗")
  echo "  $ICON $svc: $STATUS"
done

echo ""
echo "Teste Nginx (local):"
curl -s http://localhost/health
echo ""
for path in "" "index.html" "style.css" "app.js" "config.js"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/${path}")
  ICON=$([[ "$CODE" == "200" ]] && echo "✓" || echo "✗")
  printf "  %s HTTP %s — /%s\n" "$ICON" "$CODE" "$path"
done

echo ""
echo "Permissões:"
ls -la $WEBROOT/

echo ""
echo "Logs de erro Nginx (últimas 5 linhas):"
tail -5 /var/log/nginx/techstock-error.log 2>/dev/null || echo "  (sem erros)"

echo ""
echo "Node Exporter:"
curl -s http://localhost:9100/metrics | grep "^node_load1" | head -1

echo ""
echo "============================================"
echo " Setup Frontend CONCLUÍDO: $(date)"
echo "============================================"
echo ""
MY_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
echo "IP privado desta instância: $MY_IP"
echo ""
echo "PENDÊNCIAS MANUAIS (Console AWS):"
echo "  1. Registrar este EC2 no Target Group do ALB (porta 80)"
echo "  2. ALB Listener Rules — HTTP:80:"
echo "       Prioridade 1 → /api*        → tg-backend"
echo "       Prioridade 2 → /grafana*    → tg-monitoring"
echo "       Prioridade 3 → /prometheus* → tg-monitoring"
echo "       Prioridade 4 → /*           → tg-frontend"
echo ""
echo "Para atualizar a URL da API:"
echo "  sudo nano $WEBROOT/config.js"
echo "  (ou execute o script novamente)"
