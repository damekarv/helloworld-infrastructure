provider "aws" {
  region = "eu-west-1"
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "eu-west-1"]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "eu-west-1"]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "eu-west-1"]
  }
}

module "vpc" {
  source = "../../modules/vpc"

  environment = var.environment
  region      = "eu-west-1"
  name_suffix = random_string.suffix.result
}

module "eks" {
  source = "../../modules/eks"

  environment     = var.environment
  region          = "eu-west-1"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  public_subnets  = module.vpc.public_subnets

  access_entries = {
    github_actions = {
      principal_arn = aws_iam_role.github_actions.arn
      policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    }
  }
}

module "karpenter" {
  source = "../../modules/karpenter"

  environment                        = var.environment
  region                             = "eu-west-1"
  cluster_name                       = module.eks.cluster_name
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  oidc_provider_arn                  = module.eks.oidc_provider_arn
  oidc_provider_url                  = module.eks.oidc_provider_url
  node_role_name                     = module.eks.node_role_name
  node_role_arn                      = module.eks.node_role_arn
}

module "loadbalancer" {
  source = "../../modules/loadbalancer"

  environment                        = var.environment
  region                             = "eu-west-1"
  cluster_name                       = module.eks.cluster_name
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  oidc_provider_arn                  = module.eks.oidc_provider_arn
  oidc_provider_url                  = module.eks.oidc_provider_url
  
  # Force dependency
  depends_on = [module.eks] 
}

module "external_secrets" {
  source = "../../modules/external-secrets"

  environment                        = var.environment
  region                             = "eu-west-1"
  cluster_name                       = module.eks.cluster_name
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  oidc_provider_arn                  = module.eks.oidc_provider_arn
  oidc_provider_url                  = module.eks.oidc_provider_url

  depends_on = [module.eks, module.loadbalancer]
}

module "secrets" {
  source = "../../modules/secrets"

  environment = var.environment
  region      = "eu-west-1"
  name_suffix = random_string.suffix.result
}

module "flux" {
  source = "../../modules/flux"

  environment                        = var.environment
  region                             = "eu-west-1"
  cluster_name                       = module.eks.cluster_name
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data

  repositories = {
    eks-infra = {
      url         = "https://github.com/damekarv/helloworld-infrastructure"
      branch      = "main"
      path        = "./clusters/${var.environment}"
      secret_name = "flux-system"
    }
  }


  depends_on = [module.eks, module.loadbalancer]
}

module "monitoring" {
  source = "../../modules/monitoring"

  environment = var.environment
  region      = "eu-west-1"

  depends_on = [module.eks, module.karpenter]
}

module "flagger" {
  source = "../../modules/flagger"

  environment = var.environment
  region      = "eu-west-1"

  depends_on = [module.monitoring, module.loadbalancer] # Flagger needs Prometheus and LoadBalancer
}

resource "kubernetes_namespace" "helloworld" {
  metadata {
    labels = {
      name = "helloworld"
    }

    name = "helloworld"
  }
}

