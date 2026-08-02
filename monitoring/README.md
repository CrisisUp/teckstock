# Monitoring — TechStack

Documentação do stack de observabilidade do TechStack.

---

## 📊 Dashboards (5)

| Dashboard | UID | Foco | Painéis |
|---|---|---|---|
| **TechStock API** | `techstock-api` | Requests, error rate, heap, event loop | 12 |
| **DevOps** | `techstock-devops` | Uptime dos targets, container status | 13 |
| **Infra EC2** | `techstock-infra-ec2` | CPU, memória, disco, rede | 12 |
| **Observabilidade** | `techstock-observability` | Prometheus internals (series, chunks, samples) | 10 |
| **RDS** | `techstock-rds` | Conexões ativas, erros 5xx, requests por path | 7 |

> **UID do datasource:** `PBFA97CFB590B2093` (configurado no provisioning)

---

## 📦 Provisionamento Declarativo

O Grafana é provisionado via arquivos YAML/JSON em `/etc/grafana/provisioning/` (configurado no `grafana.ini`).

### Estrutura

```
monitoring/
├── provisioning/
│   ├── datasources/
│   │   └── datasources.yaml       # Datasource Prometheus
│   └── dashboards/
│       ├── dashboards.yaml        # Config do provider de dashboards
│       └── dashboards/            # JSONs dos 5 dashboards
│           ├── dashboard_techstock-api.json
│           ├── dashboard_techstock-devops.json
│           ├── dashboard_techstock-infra-ec2.json
│           ├── dashboard_techstock-observability.json
│           └── dashboard_techstock-rds.json
```

### Como provisionar (setup automático)

O script `setup-monitoring-v3-fullsecrets.sh` já faz tudo:
1. Instala Grafana + Prometheus
2. Cria datasource `PBFA97CFB590B2093` via API
3. Importa os 5 dashboards via API
4. Configura `grafana.ini` com `provisioning` apontando para os arquivos YAML

```bash
# Provisionamento automático (executado pelo setup-monitoring-v3-fullsecrets.sh)
grafana.ini:
  paths:
    provisioning: /etc/grafana/provisioning
```

---

## 📊 Métricas disponíveis (exemplos)

| Dashboard | Métricas-chave (PromQL) |
|---|---|
| **API** | `rate(techstock_http_requests_total[5m])`, `rate(techstock_http_requests_total{status=~"5.."}[5m])`, `heap_used/heap_total`, `eventloop_lag_p99` |
| **DevOps** | `up{job="techstock-app"}`, `up{job="node-exporter-*"}` |
| **Infra EC2** | `100 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m]))*100`, `node_memory_MemAvailable_bytes` |
| **Observabilidade** | `prometheus_tsdb_head_series`, `rate(prometheus_tsdb_head_samples_appended_total[5m])` |
| **RDS** | `techstock_nodejs_active_handles`, `rate(techstock_http_requests_total{status="500",path=~"/api/.*"}[5m])` |

### UIDs dos Dashboards
| Dashboard | UID |
|---|---|
| TechStock API | `techstock-api` |
| DevOps | `techstock-devops` |
| Infra EC2 | `techstock-infra-ec2` |
| Observabilidade | `techstock-observability` |
| RDS | `techstock-rds` |

---

## 🔧 Como adicionar/atualizar um dashboard

1. Edite o JSON em `monitoring/dashboard_techstock-*.json`
2. O provisionamento carrega automaticamente (intervalo 300s) ou reinicie o Grafana:
   ```bash
   systemctl restart grafana-server
   ```
3. Verifique em: `http://<grafana>:3000/dashboards` → pasta **TechStock**

---

## 🔍 Métricas expostas pelo backend (prefixo `techstock_*`)

| Categoria | Métricas |
|---|---|
| HTTP | `techstock_http_requests_total`, `techstock_http_requests_total{status=~"5.."}` |
| Node.js | `heap_size_used_bytes`, `heap_size_total_bytes`, `eventloop_lag_p99_seconds`, `active_handles` |
| Processo | `process_cpu_seconds_total`, `process_cpu_system_seconds_total` |
| Movimentos | `movimentos_por_dia_7d` (agregado custom) |

---

## 🔒 Segurança

- Datasource usa **trust** no Prometheus (sem auth mTLS — rede privada VPC)
- Grafana atrás do ALB (acesso via `/grafana/*` via proxy)
- Senha do admin no Secrets Manager (não em arquivo)

---

## 🔗 Links úteis

- [Grafana Provisioning Docs](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Prometheus Querying](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Chart.js Colors](https://www.chartjs.org/docs/latest/general/colors/)