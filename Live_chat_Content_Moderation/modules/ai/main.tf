# Bedrock Guardrail
resource "aws_bedrock_guardrail" "main" {
  name                      = "${var.project_name}-guardrail"
  blocked_input_messaging   = "Input blocked by guardrail"
  blocked_outputs_messaging = "Output blocked by guardrail"
  description               = "Guardrail for ${var.project_name}"

  content_policy_config {
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "HATE"
    }
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "INSULTS"
    }
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "SEXUAL"
    }
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "VIOLENCE"
    }
  }

  topic_policy_config {
    topics_config {
      name       = "FinancialAdvice"
      examples   = ["How should I invest my money?", "What stocks should I buy?"]
      type       = "DENY"
      definition = "Providing financial advice or investment recommendations."
    }
  }

  tags = var.tags
}

resource "aws_bedrock_guardrail_version" "main" {
  guardrail_arn = aws_bedrock_guardrail.main.guardrail_arn
  description   = "Initial version"
}
