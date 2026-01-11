locals {
  name = "${var.environment}-helloworld"
  
  tags = merge({
    created-by     = "DevOps Team"
    created-by     = "DevOps Team"
    Application    = "helloworld"
    awsApplication = "helloworld"
  }, var.extra_tags)
}

################################################################################
# AWS Secrets Manager
################################################################################
resource "aws_secretsmanager_secret" "app_secret" {
  name        = "app/${local.name}-${var.name_suffix}/db-credentials"
  description = "Example application secret"
  kms_key_id  = aws_kms_key.secrets.id
  recovery_window_in_days = 0

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "app_secret" {
  secret_id     = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode({
    username = "admin"
    password = "changeme"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

################################################################################
# KMS Key for Secrets
################################################################################
resource "aws_kms_key" "secrets" {
  description             = "KMS key for ${local.name} secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${local.name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}
