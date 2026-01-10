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

variable "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "The URL on the EKS cluster for the OIDC Provider"
  type        = string
}

variable "extra_tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
