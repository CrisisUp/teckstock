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