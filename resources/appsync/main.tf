resource "aws_appsync_graphql_api" "this" {
  authentication_type = var.authentication_type
  name                = var.name
  xray_enabled        = var.xray_enabled

  log_config {
    cloudwatch_logs_role_arn = var.log_cloudwatch_logs_role_arn
    field_log_level          = "ALL"
  }

  tags = var.tags
}
