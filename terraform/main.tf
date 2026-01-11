provider "aws" {
  region = var.region

  # Trigger workflow update

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = terraform.workspace
      ManagedBy   = "Terraform"
    }
  }
}

# Ensure execution is limited to eu-west-1
data "aws_region" "current" {
  lifecycle {
    postcondition {
      condition     = self.id == "eu-west-1"
      error_message = "Error: This configuration must be applied in eu-west-1 only. Current region: ${self.id}"
    }
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

module "vpc" {
  source = "./modules/vpc"

  environment = terraform.workspace
  region      = var.region
  name_suffix = random_string.suffix.result
}

module "secrets" {
  source = "./modules/secrets"

  environment = terraform.workspace
  region      = var.region
  name_suffix = random_string.suffix.result
}

module "eks" {
  source = "./modules/eks"

  environment = terraform.workspace
  region      = var.region
  
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  public_subnets  = module.vpc.public_subnets
  
  cluster_version = "1.34"
  kms_key_arn     = module.secrets.kms_key_arn

  access_entries = {
    (aws_iam_role.github_actions.arn) = {
      policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
    }
  }
}

module "karpenter" {
  source = "./modules/karpenter"

  environment = terraform.workspace
  region      = var.region

  cluster_name                         = module.eks.cluster_name
  cluster_endpoint                     = module.eks.cluster_endpoint
  cluster_certificate_authority_data   = module.eks.cluster_certificate_authority_data
  oidc_provider_arn                    = module.eks.oidc_provider_arn
  oidc_provider_url                    = module.eks.oidc_provider_url
  node_role_name                       = module.eks.node_role_name
  node_role_arn                        = module.eks.node_role_arn

  depends_on = [module.eks]
}

module "flux" {
  source = "./modules/flux"

  environment = terraform.workspace
  region      = var.region

  cluster_name                         = module.eks.cluster_name
  cluster_endpoint                     = module.eks.cluster_endpoint
  cluster_certificate_authority_data   = module.eks.cluster_certificate_authority_data

  depends_on = [module.eks]
}

module "loadbalancer" {
  source = "./modules/loadbalancer"

  environment = terraform.workspace
  region      = var.region

  cluster_name                         = module.eks.cluster_name
  cluster_endpoint                     = module.eks.cluster_endpoint
  cluster_certificate_authority_data   = module.eks.cluster_certificate_authority_data
  oidc_provider_arn                    = module.eks.oidc_provider_arn
  oidc_provider_url                    = module.eks.oidc_provider_url

  depends_on = [module.eks]
}

module "external_secrets" {
  source = "./modules/external-secrets"

  environment = terraform.workspace
  region      = var.region

  cluster_name                         = module.eks.cluster_name
  cluster_endpoint                     = module.eks.cluster_endpoint
  cluster_certificate_authority_data   = module.eks.cluster_certificate_authority_data
  oidc_provider_arn                    = module.eks.oidc_provider_arn
  oidc_provider_url                    = module.eks.oidc_provider_url

  depends_on = [module.eks]
}

