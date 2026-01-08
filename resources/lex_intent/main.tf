resource "aws_lexv2models_intent" "this" {
  bot_id      = var.bot_id
  bot_version = var.bot_version
  locale_id   = var.locale_id
  name        = var.name
  description = var.description

  dynamic "sample_utterance" {
    for_each = var.sample_utterances
    content {
      utterance = sample_utterance.value
    }
  }

  fulfillment_code_hook {
    enabled = var.fulfillment_enabled
  }

  dialog_code_hook {
    enabled = true
  }
}
