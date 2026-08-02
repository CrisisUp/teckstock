terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # ── Remote State (S3 + DynamoDB) ────────────────────────────────────────────
  # O bucket e a tabela são criados por state_bootstrap.tf (recursos raiz).
  # ATIVAÇÃO (uma vez): ver instruções em state_bootstrap.tf.
  # Passo 1: com este bloco AINDA comentado, crie os recursos do state:
  #   terraform init
  #   terraform apply -target=aws_s3_bucket.terraform_state \
  #                   -target=aws_s3_bucket_versioning.terraform_state \
  #                   -target=aws_dynamodb_table.terraform_lock
  # Passo 2: descomente este bloco e migre:
  #   terraform init -reconfigure -migrate-state
  # Passo 3: pronto — todo apply/plan passa a usar o state remoto com lock.
  #
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