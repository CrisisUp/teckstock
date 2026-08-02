# NOTA: Data source removido porque não temos permissão para descrever AMIs
# data "aws_ami" "amazon_linux_2023" {
#   most_recent = true
#   owners      = ["amazon"]
#
#   filter {
#     name   = "name"
#     values = ["al2023-ami-2023*-x86_64"]
#   }
# }

# Definir AMI ID fixa para Amazon Linux 2023
# Ajuste conforme sua região (veja tabela abaixo)
locals {
  # Amazon Linux 2023 AMI ID para us-east-1
  # Atualize se estiver usando outra região
  amazon_linux_2023_ami = "ami-0c02fb55956c7d316"
  
  # Se preferir usar Amazon Linux 2 (mais estável/testado):
  # amazon_linux_2023_ami = "ami-0abcdef1234567890"  # AL2 em us-east-1
}

# EC2 - Backend (API Node.js)
resource "aws_instance" "backend" {
  ami                    = local.amazon_linux_2023_ami
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = "LabInstanceProfile" # Obrigatorio no Learner Lab

  # Adicionar user_data para instalar Node.js (opcional, mas recomendado)
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nodejs npm git
    # Clone e configure seu app aqui
  EOF

  tags = {
    Name = "techstock-backend"
  }
}

# EC2 - Frontend (Nginx)
resource "aws_instance" "frontend" {
  ami                    = local.amazon_linux_2023_ami
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[1].id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  iam_instance_profile   = "LabInstanceProfile"

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = {
    Name = "techstock-frontend"
  }
}

# EC2 - Monitoring (Grafana/Prometheus)
resource "aws_instance" "monitoring" {
  ami                    = local.amazon_linux_2023_ami
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    Name = "techstock-monitoring"
  }
}

# Atualizar Outputs para mostrar os IPs Internos (Importante para a VPN)
resource "aws_lb_target_group_attachment" "backend" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend.id
  port             = 3000
}

resource "aws_lb_target_group_attachment" "frontend" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "monitoring" {
  target_group_arn = aws_lb_target_group.monitoring.arn
  target_id        = aws_instance.monitoring.id
  port             = 80
}