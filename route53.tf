/* 

Management der Route53 Resourcen

*/

# Festlegen der aktiven Zone für das Deployment der Website

# Ermitteln der aktiven Zone, in der die Subdomain erstellt wird
data "aws_route53_zone" "active_zone" {
  name         = var.hosted_zone
  private_zone = false
}

# Einfügen des Records für die DNS-Validierung des Zertifikats
resource "aws_route53_record" "certificate_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.active_zone.id
}

# Einfügen des Eintrags für die Subdomain mit verweis auf die CloudFront Distribution
resource "aws_route53_record" "subdomain" {
  zone_id = data.aws_route53_zone.active_zone.zone_id
  name    = "${var.subdomain}.${data.aws_route53_zone.active_zone.name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_cloudfront_distribution.s3_distribution]
}