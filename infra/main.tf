locals {
  name         = "${var.project}-${var.environment}"
  app_domain   = "${var.app_subdomain}.${var.root_domain}"
  api_domain   = "${var.api_subdomain}.${var.root_domain}"
  db_url_param = "/${var.project}/${var.environment}/DATABASE_URL"
}

data "aws_caller_identity" "current" {}

# Uses the account's default VPC to keep this simple and NAT-free.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ---------------- Security groups ----------------
resource "aws_security_group" "api" {
  name        = "${local.name}-api"
  description = "API server: HTTP/HTTPS in. No SSH (use SSM Session Manager)."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "MySQL from the API server only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "MySQL from API"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }
}

# ---------------- RDS MySQL ----------------
resource "random_password" "db" {
  length  = 24
  special = false # keeps the DATABASE_URL free of characters that need escaping
}

resource "aws_db_subnet_group" "db" {
  name       = "${local.name}-db"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_instance" "db" {
  identifier        = "${local.name}-db"
  engine            = "mysql"
  engine_version    = "8.4"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = "admin"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period    = 7
  auto_minor_version_upgrade = true
  deletion_protection        = var.db_deletion_protection
  skip_final_snapshot        = var.db_skip_final_snapshot
  final_snapshot_identifier  = var.db_skip_final_snapshot ? null : "${local.name}-final"

  lifecycle {
    ignore_changes = [engine_version]
  }
}

# The backend reads this at deploy time. Never committed, never in GitHub.
resource "aws_ssm_parameter" "database_url" {
  name  = local.db_url_param
  type  = "SecureString"
  value = "mysql://${aws_db_instance.db.username}:${random_password.db.result}@${aws_db_instance.db.address}:3306/${aws_db_instance.db.db_name}"
}

# ---------------- Release artifacts bucket ----------------
resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name}-artifacts-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    id     = "expire-old-releases"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
  }
}

# ---------------- EC2 instance role ----------------
resource "aws_iam_role" "api" {
  name = "${local.name}-api"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_ssm" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "api" {
  name = "app-access"
  role = aws_iam_role.api.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = aws_ssm_parameter.database_url.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "api" {
  name = "${local.name}-api"
  role = aws_iam_role.api.name
}

# ---------------- EC2 + Elastic IP ----------------
resource "aws_instance" "api" {
  ami                    = data.aws_ssm_parameter.ubuntu_ami.insecure_value
  instance_type          = var.instance_type
  subnet_id              = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.api.id]
  iam_instance_profile   = aws_iam_instance_profile.api.name

  user_data = templatefile("${path.module}/scripts/user_data.sh.tftpl", {
    region        = var.region
    api_domain    = local.api_domain
    certbot_email = var.certbot_email
    db_url_param  = local.db_url_param
    cors_origin   = "https://${local.app_domain}"
    deploy_script = file("${path.module}/scripts/deploy-api.sh")
  })

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${local.name}-api"
  }

  # Don't replace the server when a newer Ubuntu AMI is published or this script
  # changes. Code changes ship through the deploy pipeline instead.
  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

resource "aws_eip" "api" {
  domain   = "vpc"
  instance = aws_instance.api.id
}
