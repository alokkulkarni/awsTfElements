resource "aws_iam_role" "lex_role" {
  name = "${var.bot_name}-lex-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lex.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lex_policy" {
  name = "${var.bot_name}-lex-policy"
  role = aws_iam_role.lex_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "polly:SynthesizeSpeech"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = var.fulfillment_lambda_arn
      }
    ]
  })
}

resource "aws_lexv2models_bot" "this" {
  name                        = var.bot_name
  role_arn                    = aws_iam_role.lex_role.arn
  data_privacy {
    child_directed = false
  }
  idle_session_ttl_in_seconds = 300
  
  tags = var.tags
}

resource "aws_lexv2models_bot_locale" "this" {
  bot_id          = aws_lexv2models_bot.this.id
  bot_version     = "DRAFT"
  locale_id       = var.locale
  n_lu_intent_confidence_threshold = 0.40
  
  voice_settings {
    voice_id = var.voice_id
    engine   = "neural"
  }
}



resource "aws_lexv2models_intent" "chat" {
  count       = 0  # Disabled - using FallbackIntent to catch all user inputs
  bot_id      = aws_lexv2models_bot.this.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.this.locale_id
  name        = "ChatIntent"
  
  sample_utterance {
    utterance = "Hi"
  }

  fulfillment_code_hook {
    enabled = true
  }

  dialog_code_hook {
    enabled = true
  }
}

resource "aws_lexv2models_intent" "fallback" {
  count                  = 0  # existing FallbackIntent already present; skip creation to avoid conflicts
  bot_id                  = aws_lexv2models_bot.this.id
  bot_version             = "DRAFT"
  locale_id               = aws_lexv2models_bot_locale.this.locale_id
  name                    = "FallbackIntent"
  parent_intent_signature = "AMAZON.FallbackIntent"

  fulfillment_code_hook {
    enabled = true
  }

  dialog_code_hook {
    enabled = true
  }

  lifecycle {
    ignore_changes = [name]
  }
}

resource "aws_lexv2models_bot_version" "this" {
  count = var.create_version ? 1 : 0
  bot_id = aws_lexv2models_bot.this.id
  locale_specification = {
    (var.locale) = {
      source_bot_version = "DRAFT"
    }
  }
}

resource "awscc_lex_bot_alias" "this" {
  count = var.create_alias ? 1 : 0
  bot_id      = aws_lexv2models_bot.this.id
  bot_alias_name = "prod"
  # Dependencies
  bot_version = var.create_version ? aws_lexv2models_bot_version.this[0].bot_version : "DRAFT" 
  # Wait, if we don't create version, we can't point to it. 
  # Usually if create_alias is true, create_version should be true, or we point to DRAFT?
  # But if create_alias=false, we skip this block entirely.
  
  conversation_log_settings = var.conversation_log_group_arn != null ? {
    text_log_settings = [
      {
        enabled = true
        destination = {
          cloudwatch = {
            cloudwatch_log_group_arn = var.conversation_log_group_arn
            log_prefix               = "lex-logs"
          }
        }
      }
    ]
  } : null

  bot_alias_locale_settings = [
    {
      locale_id = var.locale
      bot_alias_locale_setting = {
        enabled = true
        code_hook_specification = {
          lambda_code_hook = {
            lambda_arn = var.fulfillment_lambda_arn
            code_hook_interface_version = "1.0"
          }
        }
      }
    }
  ]
}


