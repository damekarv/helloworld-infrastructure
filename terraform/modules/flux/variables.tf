variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "Kubernetes Cluster Name"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  type        = string
}

variable "repositories" {
  description = "List of Git repositories to sync"
  type = map(object({
    url      = string
    branch   = string
    path     = optional(string, "./clusters/dev") # Defaulting/Exmaple
    interval    = optional(string, "1m")
    secret_name = optional(string)
  }))
  default = {}
}

variable "cluster_secret_store" {
  description = "Configuration for ClusterSecretStore"
  type = object({
    enabled = bool
    name    = string
  })
  default = {
    enabled = true
    name    = "aws-secrets-manager"
  }
}

variable "ghcr_secret" {
  description = "Configuration for GHCR ExternalSecret (Flux System)"
  type = object({
    enabled     = bool
    name        = string
    secret_name = string # AWS Secrets Manager Secret Name
  })
  default = {
    enabled     = true
    name        = "flux-system"
    secret_name = "helloworld-ghcr-pat"
  }
}

variable "app_ghcr_secret" {
  description = "Configuration for App Image Pull Secret (Helloworld Namespace)"
  type = object({
    enabled     = bool
    name        = string
    namespace   = string
    secret_name = string # AWS Secrets Manager Secret Name
  })
  default = {
    enabled     = true
    name        = "helloworld-ghcr-pat"
    namespace   = "helloworld"
    secret_name = "helloworld-ghcr-pat"
  }
}
