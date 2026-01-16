output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "oidc_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "runner_public_ip" {
  value = aws_eip.runner.public_ip
}

output "runner_ssh_command" {
  value = "ssh -i <YOUR_PRIVATE_KEY_PATH> ec2-user@${aws_eip.runner.public_ip}"
}

output "ghcr_secret_name" {
  value = aws_secretsmanager_secret.ghcr_secret.name
}

output "ghcr_secret_arn" {
  value = aws_secretsmanager_secret.ghcr_secret.arn
}
