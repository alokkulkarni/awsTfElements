resource "aws_connect_instance" "this" {
  identity_management_type = "CONNECT_MANAGED"
  inbound_calls_enabled    = true
  outbound_calls_enabled   = true
  instance_alias           = var.instance_alias
  
  contact_flow_logs_enabled = var.contact_flow_logs_enabled
  contact_lens_enabled      = var.contact_lens_enabled

  tags = var.tags
}

data "aws_connect_hours_of_operation" "default" {
  instance_id = aws_connect_instance.this.id
  name        = "Basic Hours"
}
