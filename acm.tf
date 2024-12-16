/* 

Management der Amazon Certificate Manager Resourcen

*/

resource "aws_acm_certificate" "certificate" {
  provider          = aws.acm_provider
  domain_name       = "${var.subdomain}.${data.aws_route53_zone.active_zone.name}"
  validation_method = "DNS"
}

resource "aws_acm_certificate_validation" "certificate_validation" {
  provider                = aws.acm_provider
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation_record : record.fqdn]
}