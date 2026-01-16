# ============================================================================
# Bedrock Agent Module
# Creates Bedrock agent with guardrails for banking assistant
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# Bedrock Guardrail
# ============================================================================
resource "aws_bedrock_guardrail" "banking" {
  name                      = var.guardrail_name
  description               = var.guardrail_description
  blocked_input_messaging   = var.blocked_input_message
  blocked_outputs_messaging = var.blocked_output_message
  
  # Content policy filters
  content_policy_config {
    filters_config {
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
      type            = "HATE"
    }
    
    filters_config {
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
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
    
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type            = "MISCONDUCT"
    }
  }
  
  # Sensitive information filters
  sensitive_information_policy_config {
    pii_entities_config {
      action = "BLOCK"
      type   = "EMAIL"
    }
    
    pii_entities_config {
      action = "BLOCK"
      type   = "PHONE"
    }
    
    pii_entities_config {
      action = "BLOCK"
      type   = "NAME"
    }
    
    pii_entities_config {
      action = "BLOCK"
      type   = "ADDRESS"
    }
    
    pii_entities_config {
      action = "BLOCK"
      type   = "CREDIT_DEBIT_CARD_NUMBER"
    }
    
    pii_entities_config {
      action = "BLOCK"
      type   = "US_SOCIAL_SECURITY_NUMBER"
    }
    
    pii_entities_config {
      action = "BLOCK"
      type   = "US_BANK_ACCOUNT_NUMBER"
    }
    
    pii_entities_config {
      action = "BLOCK"
      type   = "UK_NATIONAL_INSURANCE_NUMBER"
    }
  }
  
  # Topic policy to ensure staying on topic
  topic_policy_config {
    topics_config {
      name       = "Financial Advice"
      definition = "Providing specific investment advice or guarantees about financial returns"
      examples   = [
        "You should invest all your money in this stock",
        "I guarantee you will make 20% profit",
        "This investment is risk-free"
      ]
      type = "DENY"
    }
    
    topics_config {
      name       = "Account Access"
      definition = "Attempting to access or modify customer accounts"
      examples   = [
        "Let me log into your account",
        "What is your password",
        "I can transfer money for you"
      ]
      type = "DENY"
    }
  }
  
  # Word filters for sensitive terms
  word_policy_config {
    words_config {
      text = "password"
    }
    
    words_config {
      text = "pin"
    }
    
    words_config {
      text = "ssn"
    }
    
    words_config {
      text = "social security"
    }
    
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }
  
  tags = var.tags
}

# ============================================================================
# Bedrock Agent
# ============================================================================
resource "aws_bedrockagent_agent" "banking_assistant" {
  agent_name              = var.agent_name
  agent_resource_role_arn = var.agent_role_arn
  foundation_model        = var.foundation_model
  description             = var.agent_description
  
  instruction = var.agent_instruction
  
  idle_session_ttl_in_seconds = 600
  
  # Guardrail configuration
  guardrail_configuration {
    guardrail_identifier = aws_bedrock_guardrail.banking.guardrail_id
    guardrail_version    = aws_bedrock_guardrail.banking.version
  }
  
  # Prompt override configuration for better control
  prompt_override_configuration {
    prompt_configurations {
      prompt_type     = "PRE_PROCESSING"
      prompt_state    = "ENABLED"
      prompt_creation_mode = "DEFAULT"
      inference_configuration {
        temperature   = 0.7
        top_p         = 0.9
        top_k         = 250
        stop_sequences = []
      }
    }
    
    prompt_configurations {
      prompt_type     = "ORCHESTRATION"
      prompt_state    = "ENABLED"
      prompt_creation_mode = "DEFAULT"
      inference_configuration {
        temperature   = 0.7
        top_p         = 0.9
        top_k         = 250
        stop_sequences = []
      }
    }
    
    prompt_configurations {
      prompt_type     = "POST_PROCESSING"
      prompt_state    = "ENABLED"
      prompt_creation_mode = "DEFAULT"
      inference_configuration {
        temperature   = 0.7
        top_p         = 0.9
        top_k         = 250
        stop_sequences = []
      }
    }
  }
  
  tags = var.tags
}

# ============================================================================
# Agent Alias for Production
# ============================================================================
resource "aws_bedrockagent_agent_alias" "prod" {
  agent_alias_name = "prod"
  agent_id         = aws_bedrockagent_agent.banking_assistant.id
  description      = "Production alias for banking assistant agent"
  
  tags = var.tags
  
  depends_on = [aws_bedrockagent_agent.banking_assistant]
}

# ============================================================================
# Agent Alias for Test
# ============================================================================
resource "aws_bedrockagent_agent_alias" "test" {
  agent_alias_name = "test"
  agent_id         = aws_bedrockagent_agent.banking_assistant.id
  description      = "Test alias for banking assistant agent"
  
  tags = var.tags
  
  depends_on = [aws_bedrockagent_agent.banking_assistant]
}

# ============================================================================
# CloudWatch Log Group for Agent
# ============================================================================
resource "aws_cloudwatch_log_group" "agent_logs" {
  name              = "/aws/bedrock/agent/${var.agent_name}"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}
