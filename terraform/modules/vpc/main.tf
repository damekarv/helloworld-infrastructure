data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.environment}-helloworld"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
  
  tags = merge({
    created-by     = "DevOps Team"
    Application    = "helloworld"
  }, var.extra_tags)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name}-vpc"
  }
}

resource "aws_subnet" "public" {
  count = length(var.vpc_public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.vpc_public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name                     = "${local.name}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb" = 1
  })
}

resource "aws_subnet" "private" {
  count = length(var.vpc_private_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.vpc_private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(local.tags, {
    Name                              = "${local.name}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = local.name
  })
}