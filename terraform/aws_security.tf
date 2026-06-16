# SG do Application Load Balancer
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

# SG do Backend (API Node.js)
resource "aws_security_group" "backend" {
  name        = "techstock-backend-sg"
  description = "Acesso para API e Metricas"
  vpc_id      = aws_vpc.main.id

  # Porta da API
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id, aws_security_group.monitoring.id]
  }

  # Node Exporter
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

# SG do Frontend (Nginx)
resource "aws_security_group" "frontend" {
  name        = "techstock-frontend-sg"
  description = "Acesso para o Servidor Web"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

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

# SG do Monitoring (Grafana/Prometheus)
resource "aws_security_group" "monitoring" {
  name        = "techstock-monitoring-sg"
  description = "Acesso ao Monitoring Stack"
  vpc_id      = aws_vpc.main.id

  # Grafana/Prometheus via Nginx proxy (Porta 80)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Auto-scrapping e metricas internas
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

# SG do RDS (PostgreSQL)
resource "aws_security_group" "rds" {
  name        = "techstock-rds-sg"
  description = "Acesso ao Banco de Dados"
  vpc_id      = aws_vpc.main.id

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
