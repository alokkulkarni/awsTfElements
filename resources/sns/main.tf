resource "aws_sns_topic" "this" {
  name              = var.name
  kms_master_key_id = var.kms_key_id
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "this" {
  for_each  = var.subscriptions
  topic_arn = aws_sns_topic.this.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint
}
