data "aws_caller_identity" "current" {}

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
# External Secrets Operator
################################################################################
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  # repository = "https://charts.external-secrets.io"
  chart      = "${path.module}/charts/external-secrets"
  version    = "1.2.1"
  namespace  = "external-secrets"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_secrets.arn
  }
}

################################################################################
# External Secrets Operator Role
################################################################################
resource "aws_iam_role" "external_secrets" {
  name = "${local.name}-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          }
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_policy" "external_secrets" {
  name        = "${local.name}-external-secrets"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:app/${local.name}/*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:helloworld-ghcr-pat-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}
