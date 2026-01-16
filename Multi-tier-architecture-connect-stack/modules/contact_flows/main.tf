# ============================================================================
# Contact Flows Module
# Creates contact flows from JSON definitions
# NOTE: This module is commented out by default. Design flows in the console
# first, then export and enable this module.
# ============================================================================

# ============================================================================
# Contact Flows - COMMENTED OUT
# ============================================================================

# Uncomment after designing flows in console and exporting JSON

# resource "aws_connect_contact_flow" "flows" {
#   for_each = var.deploy_flows ? var.contact_flows : {}
#   
#   instance_id = var.connect_instance_id
#   name        = each.key
#   description = each.value.description
#   type        = each.value.type
#   
#   content = file("${path.module}/${each.value.filename}")
#   
#   tags = merge(
#     var.tags,
#     {
#       FlowName = each.key
#       FlowType = each.value.type
#     }
#   )
# }

# ============================================================================
# Placeholder Contact Flow Templates
# ============================================================================

# These are placeholder templates. You should design actual flows in the console
# and export them to replace these templates.

resource "local_file" "main_flow_template" {
  filename = "${path.module}/flows/main_flow.json"
  content  = jsonencode({
    Version     = "2019-10-30"
    StartAction = "placeholder"
    Actions     = []
    Settings    = {
      InputParameters  = []
      OutputParameters = []
      Transitions      = []
    }
  })
}

resource "local_file" "customer_queue_flow_template" {
  filename = "${path.module}/flows/customer_queue_flow.json"
  content  = jsonencode({
    Version     = "2019-10-30"
    StartAction = "placeholder"
    Actions     = []
    Settings    = {
      InputParameters  = []
      OutputParameters = []
      Transitions      = []
    }
  })
}

resource "local_file" "callback_flow_template" {
  filename = "${path.module}/flows/callback_flow.json"
  content  = jsonencode({
    Version     = "2019-10-30"
    StartAction = "placeholder"
    Actions     = []
    Settings    = {
      InputParameters  = []
      OutputParameters = []
      Transitions      = []
    }
  })
}
