terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Configuração do backend (opcional - para salvar o estado remotamente)
  # backend "s3" {
  #   bucket         = "techstock-terraform-state"
  #   key            = "terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region
  
  # Opcional: Usar um perfil específico
  # profile = "default"
  
  # Opcional: Configurar timeout para operações AWS
  # max_retries = 5
  # assume_role {
  #   role_arn = "arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
  # }
}