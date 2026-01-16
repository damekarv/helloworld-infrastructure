# ---------------------------------------------------------------------------------------------------------------------
# AWS SECRETS MANAGER
# ---------------------------------------------------------------------------------------------------------------------

# Secret for GitHub Container Registry (GHCR) PAT
resource "aws_secretsmanager_secret" "ghcr_secret" {
  name        = "${var.project_name}-ghcr-pat"
  description = "GitHub Container Registry PAT for External Secrets Operator"
  
  # Allow deletion without recovery for this demo/bootstrap, usually 7-30 days recovery window
  recovery_window_in_days = 0 
}

# Initial placeholder version (Value MUST be updated manually or via script to actual keys)
resource "aws_secretsmanager_secret_version" "ghcr_secret_initial" {
  secret_id     = aws_secretsmanager_secret.ghcr_secret.id
  secret_string = jsonencode({
    username = "PLACEHOLDER_USERNAME"
    password = "PLACEHOLDER_PAT_TOKEN"
  })

  # Ignore changes to the secret string so Terraform doesn't overwrite manual updates
  lifecycle {
    ignore_changes = [secret_string]
  }
}
