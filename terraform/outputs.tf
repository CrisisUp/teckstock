# Endereço do Load Balancer (ALB) - Central de acesso à aplicação
output "alb_dns_name" {
  description = "DNS do Load Balancer (Use este link para acessar o sistema)"
  value       = aws_lb.main.dns_name
}

# Endpoint do Banco de Dados RDS
output "rds_endpoint" {
  description = "Endpoint do Banco de Dados RDS (Necessário para o setup do Backend)"
  value       = aws_db_instance.postgres.endpoint
}

# URL do Frontend no S3 (Migração Desafio Final)
output "s3_frontend_url" {
  description = "URL do Site Estático no S3"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

# IDs das Subnets (Útil para scripts manuais se necessário)
output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnets" {
  value = aws_subnet.private[*].id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

# Azure - Informações Iniciais
output "azure_resource_group" {
  value = azurerm_resource_group.main.name
}

output "azure_vnet_name" {
  value = azurerm_virtual_network.main.name
}

# IPs Privados das EC2s (Essenciais para configurar Prometheus e VPN)
output "backend_private_ip" {
  value = aws_instance.backend.private_ip
}

output "frontend_private_ip" {
  value = aws_instance.frontend.private_ip
}

output "monitoring_private_ip" {
  value = aws_instance.monitoring.private_ip
}
