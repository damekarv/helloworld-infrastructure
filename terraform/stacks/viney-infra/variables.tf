variable "environment" {
  description = "The deployment environment (e.g., dev-cluster, staging-cluster, prod-cluster)"
  type        = string
}

variable "allowed_ips" {
  description = "List of allowed IPs to access the EKS cluster"
  type        = list(string)
}
