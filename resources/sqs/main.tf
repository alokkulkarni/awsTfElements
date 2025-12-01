resource "aws_sqs_queue" "this" {
  name                        = var.name
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.content_based_deduplication
  redrive_policy              = var.redrive_policy

  tags = var.tags
}
