# ---------------------------------------------------------------------------------------------------------------------
# CCP Hosting (S3 + CloudFront)
# ---------------------------------------------------------------------------------------------------------------------

# S3 Bucket for CCP Website
resource "aws_s3_bucket" "ccp_site" {
  bucket_prefix = "${var.project_name}-ccp-site-"
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "ccp_site" {
  bucket = aws_s3_bucket.ccp_site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "ccp_site" {
  name                              = "${var.project_name}-ccp-oac"
  description                       = "OAC for CCP Site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "ccp_site" {
  origin {
    domain_name              = aws_s3_bucket.ccp_site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.ccp_site.id
    origin_id                = "S3-${aws_s3_bucket.ccp_site.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "CCP Custom Portal"
  web_acl_id          = aws_wafv2_web_acl.ccp_waf.arn

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.ccp_site.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}

# S3 Bucket Policy for CloudFront OAC
resource "aws_s3_bucket_policy" "ccp_site" {
  bucket = aws_s3_bucket.ccp_site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.ccp_site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.ccp_site.arn
          }
        }
      }
    ]
  })
}

# Upload index.html with template substitution
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.ccp_site.id
  key          = "index.html"
  content_type = "text/html"
  content = templatefile("${path.module}/ccp_site/index.html.tftpl", {
    instance_alias = var.connect_instance_alias
    region         = var.region
  })
  etag = md5(templatefile("${path.module}/ccp_site/index.html.tftpl", {
    instance_alias = var.connect_instance_alias
    region         = var.region
  }))
}

# ---------------------------------------------------------------------------------------------------------------------
# Connect Allowed Origin Association
# ---------------------------------------------------------------------------------------------------------------------

# Note: Terraform AWS Provider does not yet support aws_connect_origin natively in all versions or it's complex.
# Using null_resource to associate the CloudFront domain with the Connect Instance.
resource "null_resource" "associate_origin" {
  triggers = {
    instance_id = module.connect_instance.id
    origin      = "https://${aws_cloudfront_distribution.ccp_site.domain_name}"
  }

  provisioner "local-exec" {
    command = "aws connect associate-approved-origin --instance-id ${module.connect_instance.id} --origin https://${aws_cloudfront_distribution.ccp_site.domain_name} --region ${var.region}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# WAF (Security)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "ccp_waf" {
  provider    = aws.us_east_1
  name        = "${var.project_name}-ccp-waf"
  description = "WAF for CCP CloudFront Distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ccp-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  tags = var.tags
}

