variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for EKS encryption"
  type        = string
  default     = ""
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.34"
}

variable "extra_tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
