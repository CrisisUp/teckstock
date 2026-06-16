# 🌐 TechStock Multi-Cloud Project — SENAI

Este repositório contém a automação e documentação para o desafio final da matéria de Redes e Infraestrutura Cloud. O projeto consiste em implementar, gerenciar e migrar a aplicação **TechStock** em um cenário híbrido e multi-cloud (AWS + Azure).

---

## 🔗 Links de Acesso

*   **GitHub:** [https://github.com/CrisisUp/teckstock](https://github.com/CrisisUp/teckstock)
*   **Aplicação TechStock:** [http://techstock-alb-1787035187.us-east-1.elb.amazonaws.com](http://techstock-alb-1787035187.us-east-1.elb.amazonaws.com)
*   **Grafana Dashboards:** [http://techstock-alb-1787035187.us-east-1.elb.amazonaws.com/grafana](http://techstock-alb-1787035187.us-east-1.elb.amazonaws.com/grafana)
*   **Prometheus Console:** [http://techstock-alb-1787035187.us-east-1.elb.amazonaws.com/prometheus](http://techstock-alb-1787035187.us-east-1.elb.amazonaws.com/prometheus)

---

## 🔐 Variáveis e Credenciais (Ambiente de Lab)

### 🟠 AWS Infrastructure
*   **VPC CIDR:** `172.16.0.0/16`
*   **Public Subnets:** `172.16.0.0/24` (AZ-a), `172.16.1.0/24` (AZ-b)
*   **Private Subnets:** `172.16.10.0/24` (AZ-a), `172.16.11.0/24` (AZ-b)
*   **RDS Endpoint:** `techstock-db.cpq7pnn7gdwj.us-east-1.rds.amazonaws.com`

### 🔑 Acessos
| Serviço | Usuário | Senha | Porta |
| :--- | :--- | :--- | :--- |
| **Banco de Dados (RDS)** | `techstock_user` | `TechStock12345` | 5432 |
| **Grafana** | `admin` | `admin` (inicial) | 80 (/grafana) |
| **Backend API** | - | - | 3000 (/api) |
| **Prometheus** | - | - | 9090 (/prometheus) |

### 🔵 Azure Infrastructure
*   **VNet CIDR:** `10.0.0.0/16`
*   **Subnet Monitoring:** `10.0.0.0/24`
*   **GatewaySubnet:** `10.0.255.0/27`

---

## 📅 Cronograma de Entregas

| Data | Fase | Descrição | Status |
| :--- | :--- | :--- | :--- |
| **17/06** | **Entrega Parcial** | Base de rede AWS, Segurança (SGs), RDS e ALB. | ✅ Pronto |
| **19/06** | **Entrega AWS** | Instâncias EC2, Deploy da API e Monitoramento Stack. | ✅ Pronto |
| **22/06** | **Entrega Final** | Migração Frontend S3, Azure VNet e VPN Site-to-Site. | 🛠️ Em andamento |
| **23/06** | **Apresentação** | Demonstração final do ambiente Multi-Cloud. | ⏳ Pendente |

---

## 🏗️ Arquitetura do Projeto

O projeto utiliza **Terraform** para garantir uma infraestrutura imutável e profissional.

### 🟠 AWS (Região: us-east-1)
*   **Rede:** VPC `172.16.0.0/16` (planejada para evitar conflito com a Azure).
*   **Segurança:** 5 Security Groups modulares (ALB, Backend, Frontend, Monitoring, RDS).
*   **Computação:** 3 Instâncias EC2 (t3.micro) em subnets privadas.
*   **Banco de Dados:** RDS PostgreSQL em subnets privadas.
*   **Load Balancer:** ALB gerenciando tráfego via Path-Based Routing (`/api*`, `/grafana*`, etc.).
*   **Storage:** Bucket S3 configurado para Static Website Hosting.

### 🔵 Azure (Região: East US)
*   **Rede:** VNet `10.0.0.0/16`.
*   **Monitoramento:** Espaço reservado para migração do Grafana/Prometheus.
*   **Conectividade:** GatewaySubnet preparada para VPN Site-to-Site.

---

## 📂 Estrutura de Arquivos Terraform

Localizados na pasta `/terraform`:

*   `aws_network.tf`: Definição de VPC, Subnets, IGW e NAT Gateway.
*   `aws_security.tf`: Regras de firewall (Inbound/Outbound) conforme requisitos.
*   `aws_rds.tf`: Provisionamento do banco de dados gerenciado.
*   `aws_alb.tf`: Configuração do Load Balancer e Target Groups.
*   `aws_compute.tf`: Definição dos servidores EC2 e vinculação ao ALB.
*   `aws_s3.tf`: Infraestrutura para migração do frontend.
*   `azure.tf`: Base de rede na Microsoft Azure.
*   `outputs.tf`: Exibição automática de dados críticos (IPs, DNS, Endpoints).

---

## 🚀 Como Executar

### Pré-requisitos
*   AWS CLI configurado com as credenciais do **Learner Lab** (vockey).
*   Terraform instalado.

### Passo a Passo
1.  Acesse a pasta do terraform:
    ```bash
    cd terraform
    ```
2.  Inicialize o projeto:
    ```bash
    terraform init
    ```
3.  Valide a configuração:
    ```bash
    terraform validate
    ```
4.  Aplique a infraestrutura (Para a entrega de 17/06, pode-se focar na rede):
    ```bash
    terraform apply
    ```

---

## 🛡️ Decisões Técnicas (Diferenciais)

1.  **Isolamento de Rede:** Todas as instâncias críticas (Backend e RDS) estão em **subnets privadas**, protegidas de acesso direto via Internet, sendo acessíveis apenas através do ALB.
2.  **Roteamento Estratégico:** O uso do CIDR `172.16.0.0/16` na AWS garante que a futura conexão VPN com a Azure (`10.0.0.0/16`) funcione sem necessidade de NAT complexo ou re-endereçamento.
3.  **Monitoramento Centralizado:** A arquitetura já prevê que o Grafana/Prometheus coletem métricas tanto da infraestrutura (Node Exporter) quanto da aplicação (API Metrics).

---

## 🧠 Lições Aprendidas (Post-Mortem Técnico)

Durante a implantação, enfrentamos e resolvemos desafios críticos que serviram como grande aprendizado:

1.  **Restrições de Caracteres no RDS:** Aprendemos que a API da AWS (via Terraform/SDK) rejeita caracteres como `@` em senhas de banco de dados, embora o Console Web aceite. **Lição:** Usar senhas alfanuméricas em automações.
2.  **Integridade do `package.json`:** O código fonte exigia bibliotecas (`helmet`, `express-async-errors`, `prom-client`) que não estavam listadas nas dependências. **Lição:** Sempre auditar os `require()` do código antes do deploy.
3.  **Ambiente de Execução SSM:** Comandos via AWS Systems Manager rodam em ambientes restritos. **Lição:** É fundamental definir variáveis de ambiente como `HOME=/root` e usar caminhos absolutos para garantir que o `npm install` e outros binários funcionem corretamente.
4.  **Escapamento em Scripts (Echo vs S3):** Tentar gerar arquivos de configuração via `echo` pode corromper caracteres de aspas. **Lição:** É mais seguro gerar arquivos localmente e sincronizá-los via S3 ou usar codificação **Base64** para garantir a integridade de caracteres especiais como `$` em configurações de proxy Nginx.
5.  **Roteamento de API:** O erro de `/api/api` (404) nos ensinou a sempre validar se o frontend já prefixa as chamadas de rede antes de configurar a URL base no `config.js`.

### 📊 Observabilidade como Código (Grafana/Prometheus)

1.  **Conflito de UID de DataSource:** Dashboards importados possuem UIDs vinculados às suas consultas. Se o DataSource for criado sem um UID idêntico, o dashboard retornará "No Data". **Solução:** Usar o diretório `/etc/grafana/provisioning/` para forçar a criação de fontes de dados com UIDs fixos.
2.  **Wrappers JSON:** Arquivos de dashboard exportados podem conter metadados extras (`{ "dashboard": ... }`) que impedem a importação direta via UI. **Solução:** Sempre validar a estrutura raiz do JSON antes da importação.
3.  **Relabeling no Prometheus:** O Grafana muitas vezes busca por labels específicas (ex: `instance: techstock-api`). O Prometheus, por padrão, usa o IP:Porta. **Solução:** Usar `relabel_configs` no `prometheus.yml` para criar nomes amigáveis que coincidam com os painéis.

---

**TechStock — Desafio Multi-Cloud AWS + Azure**
*Desenvolvido como parte da formação técnica do SENAI.*
