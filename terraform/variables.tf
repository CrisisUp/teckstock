variable "aws_region" {
  description = "Região da AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block para a VPC"
  type        = string
  default     = "172.16.0.0/16"
}

variable "az_count" {
  description = "Número de zonas de disponibilidade para usar"
  type        = number
  default     = 2  # Use 2 para economizar recursos
}

variable "environment" {
  description = "Ambiente (dev, staging, production)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "techstock"
}

# ── Segredos ─────────────────────────────────────────────────────────────────
# ⚠️ NUNCA defina um default para db_password. O valor deve vir de:
#   - Var de ambiente:  TF_VAR_db_password="..." terraform plan/apply
#   - Arquivo .tfvars:  db_password = "..."  (nunca commitar)
#   - CI/CD secret (GitHub Actions / GitLab CI, etc.)
variable "db_password" {
  description = "Senha do banco PostgreSQL RDS (NÃO commitar — use TF_VAR_db_password ou .tfvars)"
  type        = string
  sensitive   = true
}