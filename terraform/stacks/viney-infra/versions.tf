terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "viney-infra-tf-state-vin"
    key            = "viney-infra/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "viney-infra-tf-lock-vin"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}
