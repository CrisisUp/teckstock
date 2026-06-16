# Obter a AMI mais recente do Amazon Linux 2023
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# EC2 - Backend (API Node.js)
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = "LabInstanceProfile" # Obrigatorio no Learner Lab

  tags = {
    Name = "techstock-backend"
  }
}

# EC2 - Frontend (Nginx)
resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[1].id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    Name = "techstock-frontend"
  }
}

# EC2 - Monitoring (Grafana/Prometheus)
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.amazon_linux_2023.id
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
