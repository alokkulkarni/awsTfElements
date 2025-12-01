module "hallucinations_table" {
  source = "../../../resources/dynamodb"

  name     = "${var.project_name}-hallucinations"
  hash_key = "id"
  tags     = var.tags
}

module "approved_messages_table" {
  source = "../../../resources/dynamodb"

  name     = "${var.project_name}-approved-messages"
  hash_key = "id"
  tags     = var.tags
}

module "unapproved_messages_table" {
  source = "../../../resources/dynamodb"

  name     = "${var.project_name}-unapproved-messages"
  hash_key = "id"
  tags     = var.tags
}

module "prompt_store_table" {
  source = "../../../resources/dynamodb"

  name     = "${var.project_name}-prompt-store"
  hash_key = "id"
  tags     = var.tags
}

