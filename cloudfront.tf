/* 

Management der CloudFront Resourcen

*/

# Hier wird eine Access Identity in CloudFront erstellt. Diese dient für den Zugriff auf das
# S3-Bucket. Somit muss das Bucket nicht auf öffentlich gestellt werden.
# Danach wird die S3-Policy ermittelt, welche im Bucket eingetragen wird, eine Caching Policy ermittelt
# und die CloudFront Distribution erstellt

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
  }

  enabled             = true
  is_ipv6_enabled     = false
  default_root_object = "index.html"

  aliases = ["${var.subdomain}.${data.aws_route53_zone.active_zone.name}"]

  depends_on = [aws_acm_certificate_validation.certificate_validation]
}