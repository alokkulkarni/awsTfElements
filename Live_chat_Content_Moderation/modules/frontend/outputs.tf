output "cloudfront_distribution_id" {
  value = module.cloudfront.id
}

output "cloudfront_domain_name" {
  value = module.cloudfront.domain_name
}

output "s3_bucket_name" {
  value = module.s3.id
}

