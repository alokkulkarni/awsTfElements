# output "contact_flows" {
#   description = "Map of created contact flows"
#   value = {
#     for k, v in aws_connect_contact_flow.flows : k => {
#       id          = v.contact_flow_id
#       arn         = v.arn
#       name        = v.name
#       type        = v.type
#     }
#   }
# }

output "flow_template_files" {
  description = "Paths to flow template files"
  value = {
    main_flow          = local_file.main_flow_template.filename
    customer_queue     = local_file.customer_queue_flow_template.filename
    callback_flow      = local_file.callback_flow_template.filename
  }
}
