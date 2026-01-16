# ============================================================================
# Integration Module
# Registers Lex bot aliases with Connect instance
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# Lex Bot Associations (Lex V2)
# Uses AWS CLI via null_resource since Terraform AWS provider doesn't support
# Lex V2 bot associations with Connect (only supports deprecated Lex V1)
# ============================================================================

resource "null_resource" "bot_associations" {
  for_each = var.bot_versions

  triggers = {
    instance_id = var.connect_instance_id
    bot_id      = each.value.bot_id
    bot_version = each.value.bot_version
    bot_name    = each.key
    region      = data.aws_region.current.name
    account_id  = data.aws_caller_identity.current.account_id
    # Construct bot alias ARN
    # Format: arn:aws:lex:region:account-id:bot-alias/bot-id/alias-id
    # Using TSTALIASID as the standard test alias
    bot_alias_arn = "arn:aws:lex:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:bot-alias/${each.value.bot_id}/TSTALIASID"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "🔗 Associating ${self.triggers.bot_name} bot with Connect instance..."
      aws connect associate-bot \
        --instance-id ${self.triggers.instance_id} \
        --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} \
        --region ${self.triggers.region}
      
      echo "✅ ${self.triggers.bot_name} bot (${self.triggers.bot_id}) associated successfully"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "🔓 Disassociating ${self.triggers.bot_name} bot from Connect instance..."
      aws connect disassociate-bot \
        --instance-id ${self.triggers.instance_id} \
        --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} \
        --region ${self.triggers.region} || true
      
      echo "✅ ${self.triggers.bot_name} bot disassociated"
    EOT
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
