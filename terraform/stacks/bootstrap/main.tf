# ---------------------------------------------------------------------------------------------------------------------
# REMOTE STATE STORAGE (S3 + DynamoDB)
# ---------------------------------------------------------------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${random_string.suffix.result}"

  # Prevent accidental deletion of this critical resource
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GITHUB OIDC
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" : "repo:${var.github_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ---------------------------------------------------------------------------------------------------------------------
# SELF-HOSTED RUNNER INFRASTRUCTURE
# ---------------------------------------------------------------------------------------------------------------------

# 1. Security Group
resource "aws_security_group" "runner" {
  name        = "${var.project_name}-runner-sg"
  description = "Security group for GitHub Actions Runner"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH Access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Key Pair
resource "aws_key_pair" "runner" {
  key_name   = "${var.project_name}-runner-key"
  public_key = var.runner_public_key
}

# 3. Instance
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_instance" "runner" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.runner_instance_type
  key_name      = aws_key_pair.runner.key_name

  vpc_security_group_ids = [aws_security_group.runner.id]

  tags = {
    Name = "${var.project_name}-github-runner"
  }
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y libicu git nodejs
              # Install Docker (Optional, for building containers)
              yum install -y docker
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ec2-user
              EOF
}

# 4. Elastic IP
resource "aws_eip" "runner" {
  instance = aws_instance.runner.id
  domain   = "vpc"
}
