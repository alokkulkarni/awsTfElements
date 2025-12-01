module "s3" {
  source = "../../../resources/s3"

  bucket_name           = "${var.project_name}-frontend-assets-${var.environment}"
  enable_versioning     = true
  enable_logging        = true
  logging_target_bucket = var.logs_bucket_id
  logging_target_prefix = "s3-access-logs/"

  tags = var.tags
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = module.s3.id
  policy = data.aws_iam_policy_document.frontend_s3_policy.json
}

data "aws_iam_policy_document" "frontend_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.s3.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.arn]
    }
  }
}

module "cloudfront" {
  source = "../../../resources/cloudfront"

  project_name               = var.project_name
  origin_domain_name         = module.s3.bucket_regional_domain_name
  origin_id                  = "S3-${module.s3.id}"
  logging_bucket_domain_name = "${var.logs_bucket_id}.s3.amazonaws.com"
  web_acl_id                 = var.waf_acl_arn

  tags = var.tags
}

