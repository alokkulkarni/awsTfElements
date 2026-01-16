# ============================================================================
# Integration Module
# Registers Lex bot aliases with Connect instance
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# Lex Bot Associations
# ============================================================================
resource "aws_connect_bot_association" "bots" {
  for_each = var.bot_aliases
  
  instance_id = var.connect_instance_id
  
  lex_bot {
    name        = each.value.bot_name
    lex_region  = data.aws_region.current.name
  }
  
  depends_on = [var.bot_dependencies]
}

# ============================================================================
# Lambda Function Associations (for direct invocation from Connect)
# ============================================================================
resource "aws_connect_lambda_function_association" "functions" {
  for_each = var.lambda_functions
  
  instance_id  = var.connect_instance_id
  function_arn = each.value.arn
}
