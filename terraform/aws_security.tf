# Security Group do Application Load Balancer (Porta de Entrada Pública)
resource "aws_security_group" "alb" {
  name        = "techstock-alb-sg"
  description = "Acesso publico HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group do Backend (API Node.js)
resource "aws_security_group" "backend" {
  name        = "techstock-backend-sg"
  description = "Acesso para API e Metricas"
  vpc_id      = aws_vpc.main.id

  # Porta da API: Permite tráfego vindo do ALB e do Servidor de Monitoramento
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id, aws_security_group.monitoring.id]
  }

  # Node Exporter: Permite que a máquina de Monitoramento raspe métricas do SO
  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group do Frontend (Nginx Web Server)
resource "aws_security_group" "frontend" {
  name        = "techstock-frontend-sg"
  description = "Acesso para o Servidor Web"
  vpc_id      = aws_vpc.main.id

  # Permite tráfego HTTP vindo estritamente do ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Node Exporter: Monitoramento do SO
  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group do Monitoring (Grafana/Prometheus)
resource "aws_security_group" "monitoring" {
  name        = "techstock-monitoring-sg"
  description = "Acesso ao Monitoring Stack"
  vpc_id      = aws_vpc.main.id

  # Interface Web (Grafana/Prometheus proxy) vinda do ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Auto-scrapping e comunicação interna de métricas locais
  ingress {
    from_port = 9090
    to_port   = 9100
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group do RDS (PostgreSQL)
resource "aws_security_group" "rds" {
  name        = "techstock-rds-sg"
  description = "Acesso ao Banco de Dados"
  vpc_id      = aws_vpc.main.id

  # Isolamento Estrito: Apenas a instância de Backend acessa a porta 5432
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
