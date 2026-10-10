output "app_url" {
  value = "https://${local.app_domain}"
}

output "api_url" {
  value = "https://${local.api_domain}"
}

output "artifact_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}

output "frontend_bucket" {
  value = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.app.id
}

output "api_instance_name" {
  value = "${local.name}-api"
}

output "rds_endpoint" {
  value = aws_db_instance.db.address
}
