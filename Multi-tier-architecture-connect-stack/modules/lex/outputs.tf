output "bots" {
  description = "Map of Lex bot details"
  value = {
    for k, v in aws_lexv2models_bot.bots : k => {
      id          = v.id
      arn         = v.arn
      name        = v.name
      description = v.description
    }
  }
}

output "bot_ids" {
  description = "Map of bot names to IDs"
  value = {
    for k, v in aws_lexv2models_bot.bots : k => v.id
  }
}

# NOTE: Bot aliases are commented out as aws_lexv2models_bot_alias
# is not supported in AWS provider 5.x
# output "bot_prod_aliases" {
#   description = "Map of production bot aliases"
#   value = {
#     for k, v in aws_lexv2models_bot_alias.prod : k => {
#       id              = v.id
#       bot_alias_id    = v.bot_alias_id
#       bot_id          = v.bot_id
#       bot_version     = v.bot_version
#       arn             = v.arn
#     }
#   }
# }

# output "bot_test_aliases" {
#   description = "Map of test bot aliases"
#   value = {
#     for k, v in aws_lexv2models_bot_alias.test : k => {
#       id              = v.id
#       bot_alias_id    = v.bot_alias_id
#       bot_id          = v.bot_id
#       bot_version     = v.bot_version
#       arn             = v.arn
#     }
#   }
# }

output "bot_versions" {
  description = "Map of bot version details"
  value = {
    prod = {
      for k, v in aws_lexv2models_bot_version.prod : k => {
        bot_version = v.bot_version
        bot_id      = v.bot_id
      }
    }
    test = {
      for k, v in aws_lexv2models_bot_version.test : k => {
        bot_version = v.bot_version
        bot_id      = v.bot_id
      }
    }
  }
}

output "bot_locales" {
  description = "Map of bot locale IDs"
  value = {
    for k, v in aws_lexv2models_bot_locale.locales : k => {
      locale_id = v.locale_id
      bot_id    = v.bot_id
    }
  }
}
