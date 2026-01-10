output "kms_key_arn" {
  description = "The ARN of the KMS key"
  value       = aws_kms_key.secrets.arn
}

output "secret_arn" {
  description = "The ARN of the sample secret"
  value       = aws_secretsmanager_secret.app_secret.arn
}
