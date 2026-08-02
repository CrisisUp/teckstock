# ── Bootstrap do Remote State (S3 + DynamoDB) ─────────────────────────────────
# Este arquivo CRIA a infraestrutura do remote state (bucket S3 + tabela de lock).
# Fluxo de ativação (executar UMA vez, na ordem):
#
#   1) Com o backend AINDA COMENTADO em provider.tf:
#        terraform init
#        terraform apply \
#          -target=aws_s3_bucket.terraform_state \
#          -target=aws_s3_bucket_versioning.terraform_state \
#          -target=aws_s3_bucket_server_side_encryption_configuration.terraform_state \
#          -target=aws_s3_bucket_public_access_block.terraform_state \
#          -target=aws_dynamodb_table.terraform_lock
#      (cria o bucket e a tabela DynamoDB)
#
#   2) Descomente o bloco "backend \"s3\"" em provider.tf:
#        terraform init -reconfigure -migrate-state
#      (migra o tfstate local para o S3)
#
#   3) A partir daqui todo apply/plan usa o state remoto com lock.
#
# ⚠️ Se o bucket for destruído, o state remoto é perdido. Não rode
#    `terraform destroy` neste módulo após ativar o backend sem backup.

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "techstock-terraform-state"
  force_destroy = false

  tags = {
    Name = "techstock-terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"   # versionamento protege o tfstate contra corrupção/erro
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  name           = "terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Name = "techstock-terraform-lock"
  }
}
