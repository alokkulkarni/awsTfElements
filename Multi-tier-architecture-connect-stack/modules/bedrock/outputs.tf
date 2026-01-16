output "agent_id" {
  description = "ID of the Bedrock agent"
  value       = aws_bedrockagent_agent.banking_assistant.id
}

output "agent_arn" {
  description = "ARN of the Bedrock agent"
  value       = aws_bedrockagent_agent.banking_assistant.agent_arn
}

output "agent_name" {
  description = "Name of the Bedrock agent"
  value       = aws_bedrockagent_agent.banking_assistant.agent_name
}

output "guardrail_id" {
  description = "ID of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.banking.guardrail_id
}

output "guardrail_arn" {
  description = "ARN of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.banking.guardrail_arn
}

output "prod_alias_id" {
  description = "ID of the production agent alias"
  value       = aws_bedrockagent_agent_alias.prod.id
}

output "prod_alias_arn" {
  description = "ARN of the production agent alias"
  value       = aws_bedrockagent_agent_alias.prod.agent_alias_arn
}

output "test_alias_id" {
  description = "ID of the test agent alias"
  value       = aws_bedrockagent_agent_alias.test.id
}

output "test_alias_arn" {
  description = "ARN of the test agent alias"
  value       = aws_bedrockagent_agent_alias.test.agent_alias_arn
}
