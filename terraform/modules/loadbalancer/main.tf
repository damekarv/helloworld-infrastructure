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
# AWS Load Balancer Controller
################################################################################
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  # repository = "https://aws.github.io/eks-charts"
  chart      = "${path.module}/charts/aws-load-balancer-controller"
  version    = "1.17.0"
  namespace  = "kube-system"
  wait       = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }
}

################################################################################
# ALB Controller Role
################################################################################
resource "aws_iam_role" "alb_controller" {
  name = "${local.name}-alb-controller"

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
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${local.name}-alb-controller"
  policy      = file("${path.module}/policies/alb_controller_policy.json") 
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}
