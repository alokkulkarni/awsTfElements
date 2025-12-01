resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy                  = var.policy
  tags                    = var.tags
}
