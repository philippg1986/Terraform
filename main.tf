provider "aws" {
  region = "eu-north-1"
}
# ACM Certificate in us-east-1
provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}

# Random UUID for unique bucket name
resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
  lower   = true
  numeric = true
}

# Route53 Zone, Zertiikate und DNS Validation Records
# 1. Zone ermitteln und Zertifikat für gewünschte Subdomain erstellen (der Subdomain Record muss hierfür noch nicht verfügbar sein!)
data "aws_route53_zone" "active_zone" {
  name         = "guelink.services"
  private_zone = false
}

resource "aws_acm_certificate" "certificate" {
  provider          = aws.acm_provider
  domain_name       = "${var.subdomain}.${data.aws_route53_zone.active_zone.name}"
  validation_method = "DNS"
}

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

resource "aws_acm_certificate_validation" "certificate_validation" {
  provider                = aws.acm_provider
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation_record : record.fqdn]
}

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

# S3 Bucket Erstellung mit der Origin Access Identity (OAI) von CloudFront, um den Zugriff zu realisieren!
# Die OAI kann unabhängig von der CloudFront Distribution erstellt werden!
# Der Name setzt sich aus dem FQDN und einer UUID als eindeutigen Identifier zusammen.
locals {
  folder_path = abspath("${path.module}/website-files")
  files       = fileset(local.folder_path, "**")
}

resource "aws_s3_bucket" "bucket" {
  bucket = "${var.subdomain}.${data.aws_route53_zone.active_zone.name}-${random_string.random.result}"
}

resource "aws_cloudfront_origin_access_identity" "oai_bucket_access" {
  comment = "${var.subdomain}.${data.aws_route53_zone.active_zone.name}-Bucket Access Identity"
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai_bucket_access.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_s3_object" "website-files" {
  for_each = {
    for file in local.files : file => file
  }

  bucket = aws_s3_bucket.bucket.id
  key    = each.value
  source = "${local.folder_path}/${each.value}"
  etag   = filemd5("${local.folder_path}/${each.value}") #Vergleich für Änderungen der Datei

  # Definition der gängigsten MIME-Types für statischen Website Content
  content_type = lookup(
    {
      "html" = "text/html",
      "css"  = "text/css",
      "js" = "application/javascript"
      "png" = "image/png",
      "jpg" = "image/jpeg",
      "gif" = "image/gif"
    },
    split(".", each.value)[length(split(".", each.value)) - 1],
    "application/octet-stream" #Fallback
  )
}

# Erstellung der CloudFront Distribution.
data "aws_cloudfront_cache_policy" "selected_caching_policy" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.bucket.bucket_regional_domain_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai_bucket_access.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.certificate.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  default_cache_behavior {
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    target_origin_id       = aws_s3_bucket.bucket.bucket_regional_domain_name
    compress               = true

    cache_policy_id = data.aws_cloudfront_cache_policy.selected_caching_policy.id
    /*
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    */
  }

  enabled             = true
  is_ipv6_enabled     = false
  default_root_object = "index.html"

  aliases = ["${var.subdomain}.${data.aws_route53_zone.active_zone.name}"]

  depends_on = [aws_acm_certificate_validation.certificate_validation]
}