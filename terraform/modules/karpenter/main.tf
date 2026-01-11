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
# Karpenter Installation
################################################################################
resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  # repository = "oci://public.ecr.aws/karpenter"
  chart      = "${path.module}/charts/karpenter"
  version    = "1.8.0"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }
  
  set {
    name  = "settings.interruptionQueueName"
    value = var.cluster_name
  }
}

################################################################################
# Karpenter NodeClass (Graviton)
################################################################################
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2023
      role: "${var.node_role_name}"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}"
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}"
      amiSelectorTerms:
        - alias: al2023@latest
      tags:
        karpenter.sh/discovery: "${var.cluster_name}"
  YAML

  depends_on = [helm_release.karpenter]
}

################################################################################
# Karpenter NodePool (Graviton)
################################################################################
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        metadata:
          labels:
            app: helloworld
        spec:
          taints:
            - key: app
              value: helloworld
              effect: NoSchedule
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["arm64"]
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["6"]
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30m
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}


################################################################################
# Karpenter Controller Role
################################################################################
resource "aws_iam_role" "karpenter_controller" {
  name = "${local.name}-karpenter-controller"

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
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${local.name}-karpenter-controller"
  description = "Karpenter controller policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts",
          "iam:GetInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:AddRoleToInstanceProfile"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = "ec2:TerminateInstances"
        Effect = "Allow"
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Action = "iam:PassRole"
        Effect = "Allow"
        Resource = "${var.node_role_arn}"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      },
      {
        Action = "eks:DescribeCluster"
        Effect = "Allow"
        Resource = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

data "aws_caller_identity" "current" {}
