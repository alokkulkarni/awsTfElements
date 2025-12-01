# -------------------------------------------------------------------------
# DynamoDB Table for Hallucination Feedback Loop
# -------------------------------------------------------------------------
resource "aws_dynamodb_table" "hallucination_feedback" {
  name           = "${var.project_name}-hallucination-feedback"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "SessionId"
  range_key      = "Timestamp"

  attribute {
    name = "SessionId"
    type = "S"
  }

  attribute {
    name = "Timestamp"
    type = "S"
  }

  attribute {
    name = "Status"
    type = "S"
  }

  # Global Secondary Index for querying by Status (e.g., "NEW", "REVIEWED")
  global_secondary_index {
    name               = "StatusIndex"
    hash_key           = "Status"
    range_key          = "Timestamp"
    projection_type    = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.log_key.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Purpose = "Hallucination Feedback Loop"
  }
}
