module "s3_logs" {
  source = "../../../resources/s3"

  bucket_name               = "${var.project_name}-central-logs-${var.environment}"
  enable_ownership_controls = true
  enable_acl                = true
  acl                       = "log-delivery-write"
  enable_lifecycle          = true

  tags = var.tags
}


# KMS Key for CloudTrail and other logs encryption
module "kms" {
  source = "../../../resources/kms"

  description = "KMS key for centralized logs"
  policy      = data.aws_iam_policy_document.kms_key_policy.json

  tags = var.tags
}


data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow CloudTrail to encrypt logs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"]
    }
  }

  statement {
    sid    = "Allow CloudWatch Logs to encrypt logs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }
}

data "aws_caller_identity" "current" {}
