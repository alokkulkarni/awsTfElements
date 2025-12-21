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
  bot_id      = aws_lexv2models_bot.this.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.this.locale_id
  name        = "ChatIntent"
  
  sample_utterance {
    utterance = "Hi"
  }
  sample_utterance {
    utterance = "Hello"
  }
  sample_utterance {
    utterance = "I need help"
  }

  fulfillment_code_hook {
    enabled = true
  }

  dialog_code_hook {
    enabled = true
  }
}

resource "aws_lexv2models_intent" "fallback" {
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
}


