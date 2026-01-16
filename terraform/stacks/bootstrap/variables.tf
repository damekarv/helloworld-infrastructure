variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "helloworld"
}

variable "github_repo" {
  description = "GitHub Repository (org/repo)"
  type        = string
  default     = "damekarv/helloworld-infrastructure"
}

variable "runner_instance_type" {
  description = "EC2 instance type for the runner"
  type        = string
  default     = "t3.small"
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDRs allowed to SSH into the runner"
  type        = list(string)
}

variable "runner_public_key" {
  description = "Public SSH key for the runner (e.g. usage: ssh-rsa AAA...)"
  type        = string
}
