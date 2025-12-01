output "api_gateway_endpoint" {
  value = module.apigateway.api_endpoint
}

output "appsync_graphql_api_url" {
  value = module.appsync.uris["GRAPHQL"]
}

