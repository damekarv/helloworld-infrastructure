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

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, {
    Name = local.name
  })
}

resource "aws_eip" "nat" {
  count  = length(var.vpc_public_subnets)
  domain = "vpc"
  tags = merge(local.tags, {
    Name = "${local.name}-nat-${local.azs[count.index]}"
  })
}
resource "aws_nat_gateway" "this" {
  count = length(var.vpc_public_subnets)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = merge(local.tags, {
    Name = "${local.name}-${local.azs[count.index]}"
  })
  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.tags, {
    Name = "${local.name}-public"
  })
}
resource "aws_route_table_association" "public" {
  count = length(var.vpc_public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = length(var.vpc_private_subnets)
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  tags = merge(local.tags, {
    Name = "${local.name}-private-${local.azs[count.index]}"
  })
}
resource "aws_route_table_association" "private" {
  count = length(var.vpc_private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_flow_log" "this" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id
  tags = merge(local.tags, {
    Name = "${local.name}-flow-log"
  })
}
resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/${local.name}-${var.name_suffix}-flow-log"
  retention_in_days = 7
  tags = local.tags
}
resource "aws_iam_role" "flow_log" {
  name = "${local.name}-flow-log-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
  tags = local.tags
}
resource "aws_iam_role_policy" "flow_log" {
  name = "${local.name}-flow-log-policy"
  role = aws_iam_role.flow_log.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}