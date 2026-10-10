data "aws_route53_zone" "root" {
  name         = var.root_domain
  private_zone = false
}

resource "aws_route53_record" "app_a" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.app_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.app.domain_name
    zone_id                = aws_cloudfront_distribution.app.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "app_aaaa" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.app_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.app.domain_name
    zone_id                = aws_cloudfront_distribution.app.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.api_domain
  type    = "A"
  ttl     = 60
  records = [aws_eip.api.public_ip]
}
