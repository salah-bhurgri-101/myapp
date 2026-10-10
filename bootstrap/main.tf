# Run ONCE from your laptop with admin AWS credentials (local state is fine).
# Creates: Terraform state bucket, GitHub OIDC provider, 3 IAM roles for GitHub Actions.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "project" {
  type        = string
  description = "Short name, lowercase. Must match infra/prod.tfvars"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "github_org" {
  type        = string
  description = "GitHub user or organisation that owns the repo"
}

variable "github_repo" {
  type        = string
  description = "Repository name (monorepo with frontend/, backend/, infra/)"
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "Set false if this AWS account already has the GitHub OIDC provider"
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  repo       = "${var.github_org}/${var.github_repo}"
}

# ---------- Remote state bucket ----------
resource "aws_s3_bucket" "state" {
  bucket = "${var.project}-tfstate-${local.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------- GitHub OIDC ----------
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  # role name => which GitHub workflow contexts may assume it
  roles = {
    tf-plan    = ["repo:${local.repo}:pull_request", "repo:${local.repo}:ref:refs/heads/main"]
    tf-apply   = ["repo:${local.repo}:environment:production"]
    app-deploy = ["repo:${local.repo}:ref:refs/heads/main"]
  }
}

resource "aws_iam_role" "this" {
  for_each = local.roles
  name     = "${var.project}-gha-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = each.value }
      }
    }]
  })
}

# tf-plan: read-only + access to the state bucket (runs on pull requests)
resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.this["tf-plan"].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_state" {
  name = "state-access"
  role = aws_iam_role.this["tf-plan"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.state.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.state.arn
      }
    ]
  })
}

# tf-apply: only reachable through the protected "production" GitHub environment
resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.this["tf-apply"].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# app-deploy: least privilege for the backend/frontend pipelines
resource "aws_iam_role_policy" "deploy" {
  name = "app-deploy"
  role = aws_iam_role.this["app-deploy"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:AbortMultipartUpload"]
        Resource = "arn:aws:s3:::${var.project}-*-artifacts-*/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.project}-*-frontend-*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
        Resource = "arn:aws:s3:::${var.project}-*-frontend-*/*"
      },
      {
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = "arn:aws:cloudfront::${local.account_id}:distribution/*"
      },
      {
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ssm:${var.region}::document/AWS-RunShellScript"
      },
      {
        Effect    = "Allow"
        Action    = "ssm:SendCommand"
        Resource  = "arn:aws:ec2:${var.region}:${local.account_id}:instance/*"
        Condition = { StringEquals = { "ssm:resourceTag/Project" = var.project } }
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations", "ec2:DescribeInstances"]
        Resource = "*"
      }
    ]
  })
}

output "region" {
  value = var.region
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "tf_plan_role_arn" {
  value = aws_iam_role.this["tf-plan"].arn
}

output "tf_apply_role_arn" {
  value = aws_iam_role.this["tf-apply"].arn
}

output "deploy_role_arn" {
  value = aws_iam_role.this["app-deploy"].arn
}
