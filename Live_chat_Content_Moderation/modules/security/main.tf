resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.project_name}"
  retention_in_days = 30
  tags              = var.tags
}

module "waf" {
  source = "../../../resources/waf"

  name                = "${var.project_name}-waf"
  description         = "WAF for CloudFront"
  scope               = "CLOUDFRONT"
  log_destination_arn = aws_cloudwatch_log_group.waf.arn

  tags = var.tags
}

