data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.environment}-helloworld"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
}


resource "aws_vpc" "infra-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name}-vpc"
  }
}