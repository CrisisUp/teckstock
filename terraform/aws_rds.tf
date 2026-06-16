resource "aws_db_subnet_group" "rds" {
  name       = "techstock-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "techstock-rds-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "techstock-db"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "techstock"
  username               = "techstock_user"
  password               = "SenhaForte@2024!"
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "techstock-db"
  }
}
