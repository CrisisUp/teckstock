# Bucket S3 para o Frontend (Migração do desafio)
# ⚠️ Learner Lab não suporta HTTPS/ACM, então NÃO usamos CloudFront+OAC aqui.
# A melhor prática seria bucket 100% privado + CloudFront OAC (HTTPS, zero
# exposição direta). Para o desafio, mantemos site estático com leitura pública
# via policy, mas bloqueando ACLs/escrita anônima (ver public_access_block abaixo).
# Em produção: migrar para CloudFront + OAC e remover esta policy.
resource "aws_s3_bucket" "frontend" {
  bucket = "techstock-frontend-projeto-final-${random_string.suffix.result}"

  tags = {
    Name = "techstock-frontend"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Endurecimento: bloqueia ACLs públicas e escrita anônima.
# O bucket continua legível publicamente via policy (GetObject) — necessário
# para o site estático — mas NINGUÉM pode fazer upload/overwrite sem ser o dono.
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = false   # policy GetObject pública (site estático)
  ignore_public_acls      = true
  restrict_public_buckets = false   # mantém a policy de leitura ativa
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

output "frontend_url" {
  value = aws_s3_bucket_website_configuration.frontend.website_endpoint
}
