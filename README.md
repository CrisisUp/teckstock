# 🌐 TechStock Multi-Cloud Project — SENAI

Este repositório contém a automação e documentação para o desafio final da matéria de Redes e Infraestrutura Cloud. O projeto consiste em implementar, gerenciar e migrar a aplicação **TechStock** em um cenário híbrido e multi-cloud (AWS + Azure).

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

**TechStock — Desafio Multi-Cloud AWS + Azure**
*Desenvolvido como parte da formação técnica do SENAI.*
