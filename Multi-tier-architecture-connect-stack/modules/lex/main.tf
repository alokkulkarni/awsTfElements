# ============================================================================
# Lex Bots Module
# Creates Lex V2 bots with intents, slots, and aliases
# ============================================================================

# Data source for account ID
data "aws_caller_identity" "current" {}

# ============================================================================
# Lex Bots
# ============================================================================
resource "aws_lexv2models_bot" "bots" {
  for_each = var.lex_bots

  name                        = "${var.project_name}-${var.environment}-${each.key}-bot"
  role_arn                    = var.lex_role_arn
  idle_session_ttl_in_seconds = each.value.idle_session_ttl

  data_privacy {
    child_directed = false
  }

  description = each.value.description

  tags = merge(
    var.tags,
    {
      BotType = each.value.bot_type
      Domain  = each.key
    }
  )
}

# ============================================================================
# Bot Locales
# ============================================================================
resource "aws_lexv2models_bot_locale" "locales" {
  for_each = var.lex_bots

  bot_id      = aws_lexv2models_bot.bots[each.key].id
  bot_version = "DRAFT"
  locale_id   = each.value.locale

  n_lu_intent_confidence_threshold = 0.4

  voice_settings {
    voice_id = each.value.voice_id
  }

  depends_on = [aws_lexv2models_bot.bots]
}

# ============================================================================
# Bot Versions
# ============================================================================
resource "time_sleep" "wait_for_bot_locale" {
  depends_on = [
    aws_lexv2models_bot_locale.locales,
    aws_lexv2models_intent.intents
  ]

  create_duration = "10s"
}

resource "aws_lexv2models_bot_version" "prod" {
  for_each = var.lex_bots

  bot_id = aws_lexv2models_bot.bots[each.key].id
  locale_specification = {
    (each.value.locale) = {
      source_bot_version = "DRAFT"
    }
  }

  description = "Production version"

  depends_on = [
    time_sleep.wait_for_bot_locale
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "time_sleep" "wait_for_prod_versions" {
  depends_on = [aws_lexv2models_bot_version.prod]

  create_duration = "10s"
}

resource "aws_lexv2models_bot_version" "test" {
  for_each = var.lex_bots

  bot_id = aws_lexv2models_bot.bots[each.key].id
  locale_specification = {
    (each.value.locale) = {
      source_bot_version = "DRAFT"
    }
  }

  description = "Test version"

  depends_on = [
    time_sleep.wait_for_prod_versions
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# Bot Aliases
# NOTE: aws_lexv2models_bot_alias is not supported in AWS provider 5.x
# Aliases need to be created via AWS Console or CLI after deployment
# ============================================================================
# resource "aws_lexv2models_bot_alias" "prod" {
#   for_each = var.lex_bots
#   
#   bot_alias_name = "prod"
#   bot_id         = aws_lexv2models_bot.bots[each.key].id
#   bot_version    = aws_lexv2models_bot_version.prod[each.key].bot_version
#   description    = "Production alias"
#   
#   bot_alias_locale_settings {
#     bot_alias_locale_setting {
#       enabled = true
#       locale_id = each.value.locale
#       
#       code_hook_specification {
#         lambda_code_hook {
#           lambda_arn              = var.lambda_functions[each.key].arn
#           code_hook_interface_version = "1.0"
#         }
#       }
#     }
#   }
#   
#   tags = var.tags
#   
#   depends_on = [aws_lexv2models_bot_version.prod]
# }

# resource "aws_lexv2models_bot_alias" "test" {
#   for_each = var.lex_bots
#   
#   bot_alias_name = "test"
#   bot_id         = aws_lexv2models_bot.bots[each.key].id
#   bot_version    = aws_lexv2models_bot_version.test[each.key].bot_version
#   description    = "Test alias"
#   
#   bot_alias_locale_settings {
#     bot_alias_locale_setting {
#       enabled = true
#       locale_id = each.value.locale
#       
#       code_hook_specification {
#         lambda_code_hook {
#           lambda_arn              = var.lambda_functions[each.key].arn
#           code_hook_interface_version = "1.0"
#         }
#       }
#     }
#   }
#   
#   tags = var.tags
#   
#   depends_on = [aws_lexv2models_bot_version.test]
# }


# ============================================================================
# Intents for each bot
# ============================================================================
locals {
  # Define intents for each bot type
  bot_intents = {
    concierge = [
      {
        name        = "RouteToSpecialistIntent"
        description = "Route customer to appropriate specialist"
        sample_utterances = [
          "I need help with banking",
          "I want to know about products",
          "I'm interested in sales",
          "Can you help me",
          "I have a question",
          "Connect me to banking",
          "I need product information",
          "Talk to sales team",
          "Help me with my account",
          "I want to speak to someone about products",
          "Transfer me to banking department",
          "I need assistance with sales",
          "Can I talk to a specialist",
          "Get me help with products",
          "I need banking support"
        ]
      },
      {
        name                    = "FallbackIntent"
        description             = "Fallback to Bedrock agent"
        sample_utterances       = []
        parent_intent_signature = "AMAZON.FallbackIntent"
      }
    ]
    banking = [
      {
        name        = "AccountBalanceIntent"
        description = "Check account balance"
        sample_utterances = [
          "What is my account balance",
          "Check my balance",
          "How much money do I have",
          "Show me my account balance",
          "What's my current balance",
          "Tell me my balance",
          "How much do I have in my account",
          "Can you check my balance",
          "I need to know my balance",
          "Display my account balance"
        ]
      },
      {
        name        = "TransactionHistoryIntent"
        description = "View transaction history"
        sample_utterances = [
          "Show my recent transactions",
          "What are my latest transactions",
          "Transaction history",
          "Recent account activity",
          "Show me my transaction history",
          "What transactions have I made",
          "List my recent purchases",
          "Display my account activity",
          "Show last month's transactions",
          "What did I spend money on"
        ]
      },
      {
        name        = "AccountOpeningIntent"
        description = "Open new account"
        sample_utterances = [
          "I want to open an account",
          "How do I open a new account",
          "Account opening",
          "Create new account",
          "I'd like to open a bank account",
          "Start a new account",
          "Open a savings account",
          "How can I create an account",
          "New account setup",
          "I need to open an account"
        ]
      },
      {
        name        = "BranchFinderIntent"
        description = "Find branch locations"
        sample_utterances = [
          "Find nearest branch",
          "Where is your branch",
          "Branch locations",
          "Bank near me",
          "Closest branch location",
          "Find a branch nearby",
          "Where can I find your bank",
          "Branch finder",
          "Locate nearest branch",
          "Show me branch addresses"
        ]
      },
      {
        name        = "CardIssueIntent"
        description = "Report card issues"
        sample_utterances = [
          "My card is not working",
          "Card issue",
          "Problem with my card",
          "Card blocked",
          "My debit card isn't working",
          "Card declined",
          "I can't use my card",
          "Card not functioning",
          "Report card problem",
          "Card error"
        ]
      }
    ]
    product = [
      {
        name        = "ProductInformationIntent"
        description = "Get product information"
        sample_utterances = [
          "Tell me about your products",
          "Product information",
          "What products do you offer",
          "I need product details",
          "Show me your products",
          "What do you sell",
          "Product catalog",
          "List your products",
          "Available products",
          "What items are available"
        ]
      },
      {
        name        = "ProductComparisonIntent"
        description = "Compare products"
        sample_utterances = [
          "Compare products",
          "What's the difference between",
          "Product comparison",
          "Which product is better",
          "Compare these products",
          "Help me choose between products",
          "Difference between products",
          "Which one should I get",
          "Compare features",
          "Product versus product"
        ]
      },
      {
        name        = "ProductFeaturesIntent"
        description = "Learn about product features"
        sample_utterances = [
          "What features does it have",
          "Product features",
          "Tell me about the features",
          "What can it do",
          "What are the features",
          "Describe the features",
          "Feature list",
          "What does this product offer",
          "Product capabilities",
          "Specifications"
        ]
      },
      {
        name        = "ProductAvailabilityIntent"
        description = "Check product availability"
        sample_utterances = [
          "Is the product available",
          "Do you have this in stock",
          "Product availability",
          "When will it be available",
          "Is this in stock",
          "Can I get this product",
          "Check availability",
          "Do you have it",
          "Stock status",
          "Is it available now"
        ]
      }
    ]
    sales = [
      {
        name        = "NewAccountIntent"
        description = "Open new account sales"
        sample_utterances = [
          "I want to open an account",
          "New account",
          "Sign up for an account",
          "Create an account",
          "I'd like to start an account",
          "Register for an account",
          "Open new account",
          "Account registration",
          "Start new account",
          "I need a new account"
        ]
      },
      {
        name        = "UpgradeAccountIntent"
        description = "Upgrade existing account"
        sample_utterances = [
          "Upgrade my account",
          "I want premium account",
          "Account upgrade",
          "Switch to better plan",
          "Upgrade to premium",
          "Change my account type",
          "Move to premium account",
          "Upgrade my plan",
          "I want to upgrade",
          "Better account options"
        ]
      },
      {
        name        = "SpecialOffersIntent"
        description = "Learn about special offers"
        sample_utterances = [
          "What offers do you have",
          "Special offers",
          "Any promotions",
          "Current deals",
          "What promotions are available",
          "Do you have any discounts",
          "Special deals",
          "What's on offer",
          "Available promotions",
          "Current specials"
        ]
      },
      {
        name        = "PricingInquiryIntent"
        description = "Pricing information"
        sample_utterances = [
          "How much does it cost",
          "Pricing",
          "What's the price",
          "Cost information",
          "How much is it",
          "What are your prices",
          "Price details",
          "Cost details",
          "What does it cost",
          "Pricing information"
        ]
      }
    ]
  }

  # Flatten intents for resource creation
  all_intents = flatten([
    for bot_key, bot in var.lex_bots : [
      for intent in lookup(local.bot_intents, bot_key, []) : {
        bot_key     = bot_key
        intent_name = intent.name
        intent_data = intent
        locale      = bot.locale
      }
    ]
  ])

  intents_map = {
    for item in local.all_intents :
    "${item.bot_key}-${item.intent_name}" => item
  }
}

resource "aws_lexv2models_intent" "intents" {
  for_each = {
    for k, v in local.intents_map : k => v
    if v.intent_name != "FallbackIntent" # Exclude FallbackIntent as it's a built-in intent
  }

  bot_id      = aws_lexv2models_bot.bots[each.value.bot_key].id
  bot_version = "DRAFT"
  locale_id   = each.value.locale
  name        = each.value.intent_name
  description = each.value.intent_data.description

  parent_intent_signature = lookup(each.value.intent_data, "parent_intent_signature", null)

  dynamic "sample_utterance" {
    for_each = lookup(each.value.intent_data, "sample_utterances", [])
    content {
      utterance = sample_utterance.value
    }
  }

  fulfillment_code_hook {
    enabled = true
  }

  depends_on = [aws_lexv2models_bot_locale.locales]
}
