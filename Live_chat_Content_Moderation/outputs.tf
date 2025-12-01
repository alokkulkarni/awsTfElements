output "frontend_url" {
  value = module.frontend.cloudfront_domain_name
}

output "api_url" {
  value = module.backend.api_gateway_endpoint
}

output "realtime_api_url" {
  description = "The GraphQL endpoint for real-time updates (AppSync)"
  value       = module.backend.appsync_graphql_api_url
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}
