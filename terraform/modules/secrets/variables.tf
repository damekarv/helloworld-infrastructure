variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "extra_tags" {
  description = "Extra tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "name_suffix" {
  description = "Random suffix to avoid naming collisions"
  type        = string
  default     = ""
}
