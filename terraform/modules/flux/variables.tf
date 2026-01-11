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
