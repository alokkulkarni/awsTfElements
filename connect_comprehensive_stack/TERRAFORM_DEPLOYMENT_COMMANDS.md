# Terraform Deployment Commands - Phase-by-Phase Guide

## Overview
This guide provides the exact Terraform commands to deploy the comprehensive stack in phases, following the dependency sequence outlined in DEPLOYMENT_SEQUENCE.md.

---

## Pre-Deployment Setup

### 1. Initialize Terraform
```bash
cd connect_comprehensive_stack
terraform init
```

### 2. Validate Configuration
```bash
terraform validate
```

### 3. Review Full Plan (Optional)
```bash
terraform plan -out=tfplan
```

---

## Deployment Strategies

### **Strategy A: Full Stack Deployment** (Recommended for first deployment)
Deploy everything at once - Terraform handles dependencies automatically.

```bash
terraform apply -auto-approve
```

**Time:** ~25-35 minutes  
**Resources:** ~220 resources

---

### **Strategy B: Phased Deployment** (For testing/troubleshooting)
Deploy in phases to isolate issues and verify each layer.

---

## PHASE 1: Foundation Layer (30-60 seconds)

Deploy IAM roles, S3 buckets, DynamoDB tables, CloudWatch log groups, SNS topics.

```bash
# IAM Roles
terraform apply -target=aws_iam_role.lambda_role \
                -target=aws_iam_role.auth_api_role \
                -target=aws_iam_role.crm_api_role \
                -target=aws_iam_role.banking_lambda_role \
                -target=aws_iam_role.sales_lambda_role \
                -target=aws_iam_role.callback_lambda_role \
                -target=aws_iam_role.callback_dispatcher_role \
                -target=aws_iam_role.eventbridge_firehose_role \
                -auto-approve

# IAM Role Policies
terraform apply -target=aws_iam_role_policy.lambda_policy \
                -target=aws_iam_role_policy.auth_api_policy \
                -target=aws_iam_role_policy.crm_api_policy \
                -target=aws_iam_role_policy.callback_lambda_policy \
                -target=aws_iam_role_policy.callback_dispatcher_policy \
                -target=aws_iam_role_policy.ai_insights_kinesis_policy \
                -target=aws_iam_role_policy.eventbridge_firehose_policy \
                -target=aws_iam_role_policy_attachment.banking_lambda_basic \
                -target=aws_iam_role_policy_attachment.sales_lambda_basic \
                -auto-approve

# S3 Buckets (Modules)
terraform apply -target=module.connect_storage_bucket \
                -target=module.cloudtrail_bucket \
                -target=module.datalake_bucket \
                -target=module.recording_bucket \
                -target=module.transcript_bucket \
                -target=module.reports_bucket \
                -target=aws_s3_bucket.ccp_site \
                -auto-approve

# DynamoDB Tables
terraform apply -target=module.conversation_history_table \
                -target=module.hallucination_logs_table \
                -target=module.callback_table \
                -target=module.auth_state_table \
                -auto-approve

# CloudWatch Log Groups
terraform apply -target=aws_cloudwatch_log_group.bedrock_mcp \
                -target=aws_cloudwatch_log_group.lex_logs \
                -target=aws_cloudwatch_log_group.banking_lex_logs \
                -target=aws_cloudwatch_log_group.sales_lex_logs \
                -target=aws_cloudwatch_log_group.auth_api_gw \
                -target=aws_cloudwatch_log_group.banking_lambda_logs \
                -target=aws_cloudwatch_log_group.sales_lambda_logs \
                -auto-approve

# SNS Topics
terraform apply -target=module.alarm_sns_topic \
                -target=module.auth_sns_topic \
                -auto-approve
```

---

## PHASE 2: Connect Instance & Streaming (2-3 minutes)

Deploy Connect instance, Kinesis streams, Firehose, and storage configuration.

```bash
# Connect Instance
terraform apply -target=module.connect_instance \
                -auto-approve

# Kinesis Streams
terraform apply -target=module.kinesis_ctr \
                -target=module.kinesis_agent_events \
                -target=module.kinesis_ai_reporting \
                -auto-approve

# Kinesis Firehose Delivery Streams
terraform apply -target=module.firehose_ctr \
                -target=module.firehose_agent_events \
                -target=module.firehose_ai_reporting \
                -target=module.firehose_lifecycle_events \
                -auto-approve

# Connect Storage Configuration
terraform apply -target=aws_connect_instance_storage_config.ctr_stream \
                -target=aws_connect_instance_storage_config.agent_events_stream \
                -target=aws_connect_instance_storage_config.call_recordings \
                -target=aws_connect_instance_storage_config.chat_transcripts \
                -auto-approve

# Hours of Operation (Data Source)
terraform apply -target=data.aws_connect_hours_of_operation.default \
                -auto-approve
```

---

## PHASE 3: Lambda Functions & API Gateways (3-5 minutes)

Deploy Lambda functions, build code, create aliases, and set up API Gateways.

```bash
# Lambda Functions (Modules)
terraform apply -target=module.bedrock_mcp_lambda \
                -target=module.banking_lambda \
                -target=module.sales_lambda \
                -target=module.callback_lambda \
                -target=module.callback_dispatcher \
                -target=module.auth_api_lambda \
                -auto-approve

# Lambda Build & Publish
terraform apply -target=null_resource.bedrock_mcp_build \
                -target=null_resource.bedrock_mcp_publish \
                -target=null_resource.bedrock_mcp_update_alias \
                -auto-approve

# Lambda Aliases
terraform apply -target=aws_lambda_alias.bedrock_mcp_live \
                -target=aws_lambda_alias.banking_live \
                -target=aws_lambda_alias.sales_live \
                -auto-approve

# Lambda Provisioned Concurrency
terraform apply -target=aws_lambda_provisioned_concurrency_config.bedrock_mcp_pc \
                -auto-approve

# API Gateways (Modules)
terraform apply -target=module.auth_api_gateway \
                -auto-approve

# API Gateway Integrations
terraform apply -target=aws_apigatewayv2_integration.auth_integration \
                -target=aws_apigatewayv2_integration.crm_integration \
                -target=aws_apigatewayv2_route.auth_route \
                -target=aws_apigatewayv2_route.crm_route \
                -auto-approve

# Lambda Permissions
terraform apply -target=aws_lambda_permission.lex_invoke \
                -target=aws_lambda_permission.connect_invoke_callback \
                -target=aws_lambda_permission.apigw_invoke \
                -target=aws_lambda_permission.apigw_invoke_crm \
                -auto-approve
```

---

## PHASE 4: Gateway Bot (5-10 minutes) ⏱️ CRITICAL PATH

Deploy the main Lex bot with both locales (en_GB and en_US).

```bash
# Lex Bot Base
terraform apply -target=module.lex_bot \
                -auto-approve

# Bot Locales (Parallel)
terraform apply -target=aws_lexv2models_bot_locale.en_us \
                -auto-approve

# Intents for en_GB (created by module)
# Intents for en_US
terraform apply -target=aws_lexv2models_intent.chat_en_us \
                -target=aws_lexv2models_intent.transfer_to_agent_en_us \
                -auto-approve

# Update Fallback Intents
terraform apply -target=null_resource.update_fallback_intent_en_gb \
                -target=null_resource.update_fallback_intent_en_us \
                -auto-approve

# Build Bot Locales (CRITICAL - Takes 5-10 minutes)
terraform apply -target=null_resource.build_bot_locales \
                -auto-approve

# Bot Version
terraform apply -target=aws_lexv2models_bot_version.this \
                -auto-approve

# Bot Alias
terraform apply -target=awscc_lex_bot_alias.this \
                -auto-approve

# Connect Bot Association
terraform apply -target=null_resource.lex_bot_association \
                -auto-approve

# Validate Bot Alias
terraform apply -target=null_resource.validate_bot_alias \
                -auto-approve
```

---

## PHASE 5: Banking & Sales Bots (8-12 minutes) 🔄 PARALLEL with Phase 4

Deploy specialized bots for banking and sales.

### Banking Bot
```bash
# Banking Bot Base
terraform apply -target=module.banking_bot \
                -auto-approve

# Banking Intents
terraform apply -target=aws_lexv2models_intent.banking_intents_from_vars \
                -target=aws_lexv2models_intent.banking_transfer \
                -auto-approve

# Banking Bot Version
terraform apply -target=aws_lexv2models_bot_version.banking \
                -auto-approve

# Banking Bot Alias
terraform apply -target=awscc_lex_bot_alias.banking \
                -auto-approve

# Banking Bot Association
terraform apply -target=null_resource.banking_bot_association \
                -auto-approve
```

### Sales Bot
```bash
# Sales Bot Base
terraform apply -target=module.sales_bot \
                -auto-approve

# Sales Intents
terraform apply -target=aws_lexv2models_intent.sales_product \
                -auto-approve

# Sales Bot Version
terraform apply -target=aws_lexv2models_bot_version.sales \
                -auto-approve

# Sales Bot Alias
terraform apply -target=awscc_lex_bot_alias.sales \
                -auto-approve

# Sales Bot Association
terraform apply -target=null_resource.sales_bot_association \
                -auto-approve
```

---

## PHASE 6: Phone Numbers & Queues (1-2 minutes)

Deploy phone numbers, queues, routing profiles, and users.

```bash
# Phone Numbers
terraform apply -target=aws_connect_phone_number.outbound \
                -target=aws_connect_phone_number.toll_free \
                -auto-approve

# Connect Queues (4 queues)
terraform apply -target=aws_connect_queue.queues \
                -auto-approve

# Routing Profile
terraform apply -target=aws_connect_routing_profile.this \
                -auto-approve

# User Account
terraform apply -target=aws_connect_user.this \
                -auto-approve
```

---

## PHASE 7: Contact Flows (2-3 minutes)

Deploy all contact flows, Quick Connects, and associations.

```bash
# Contact Flows
terraform apply -target=aws_connect_contact_flow.queue_transfer \
                -target=aws_connect_contact_flow.voice_entry \
                -target=aws_connect_contact_flow.chat_entry \
                -target=aws_connect_contact_flow.bedrock_primary \
                -target=aws_connect_contact_flow.callback_task \
                -auto-approve

# Quick Connects
terraform apply -target=aws_connect_quick_connect.queue_transfer \
                -auto-approve

# Quick Connect Associations
terraform apply -target=null_resource.associate_quick_connects \
                -auto-approve

# Phone Number to Flow Associations
terraform apply -target=null_resource.associate_phone_numbers \
                -auto-approve
```

---

## PHASE 8: Monitoring & Observability (1-2 minutes)

Deploy CloudWatch dashboards, alarms, CloudTrail, and EventBridge rules.

```bash
# CloudWatch Dashboard
terraform apply -target=aws_cloudwatch_dashboard.main \
                -auto-approve

# CloudWatch Alarms
terraform apply -target=aws_cloudwatch_metric_alarm.queue_size \
                -target=aws_cloudwatch_metric_alarm.queue_wait_time \
                -target=aws_cloudwatch_metric_alarm.queue_abandonment_rate \
                -target=aws_cloudwatch_metric_alarm.lambda_error_rate \
                -target=aws_cloudwatch_metric_alarm.bedrock_api_errors \
                -target=aws_cloudwatch_metric_alarm.hallucination_rate_high \
                -target=aws_cloudwatch_metric_alarm.hallucination_rate_medium \
                -target=aws_cloudwatch_metric_alarm.validation_timeouts \
                -auto-approve

# CloudWatch Log Subscriptions
terraform apply -target=aws_cloudwatch_log_subscription_filter.bedrock_mcp_logs \
                -target=aws_cloudwatch_log_subscription_filter.lex_logs \
                -target=aws_cloudwatch_log_subscription_filter.banking_lex_logs \
                -target=aws_cloudwatch_log_subscription_filter.sales_lex_logs \
                -target=aws_cloudwatch_log_subscription_filter.banking_lambda_logs \
                -target=aws_cloudwatch_log_subscription_filter.sales_lambda_logs \
                -auto-approve

# CloudWatch Log Resource Policy
terraform apply -target=aws_cloudwatch_log_resource_policy.lex_logs \
                -auto-approve

# CloudTrail
terraform apply -target=aws_cloudtrail.main \
                -auto-approve

# EventBridge Rules
terraform apply -target=aws_cloudwatch_event_rule.connect_lifecycle \
                -target=aws_cloudwatch_event_target.connect_lifecycle_firehose \
                -auto-approve

# CloudWatch Metric Stream
terraform apply -target=aws_cloudwatch_metric_stream.connect_metrics \
                -auto-approve
```

---

## PHASE 9: CloudFront Distribution (5-8 minutes) ⏱️ CRITICAL PATH

Deploy WAF, S3 objects, CloudFront distribution, and origin association.

```bash
# WAF Web ACL
terraform apply -target=aws_wafv2_web_acl.ccp_waf \
                -auto-approve

# S3 Objects for CCP Site
terraform apply -target=aws_s3_object.index_html \
                -target=aws_s3_object.connect_streams \
                -auto-approve

# S3 Bucket Public Access Block
terraform apply -target=aws_s3_bucket_public_access_block.ccp_site \
                -auto-approve

# CloudFront Origin Access Control
terraform apply -target=aws_cloudfront_origin_access_control.ccp_site \
                -auto-approve

# CloudFront Distribution (SLOWEST - 5-8 minutes)
terraform apply -target=aws_cloudfront_distribution.ccp_site \
                -auto-approve

# S3 Bucket Policy (Allow CloudFront)
terraform apply -target=aws_s3_bucket_policy.ccp_site \
                -auto-approve

# Associate Origin with Connect
terraform apply -target=null_resource.associate_origin \
                -auto-approve
```

---

## PHASE 10: Glue Data Catalog (30-60 seconds)

Deploy Glue database and tables for analytics.

```bash
# Glue Database
terraform apply -target=module.datalake \
                -auto-approve
```

---

## Additional Resources (Optional)

### Bedrock Guardrail
```bash
terraform apply -target=module.bedrock_guardrail \
                -auto-approve
```

---

## Verification Commands

### Check Deployment Status
```bash
# Count deployed resources
terraform state list | wc -l

# Show outputs
terraform output

# Verify specific resources
terraform state show module.connect_instance.aws_connect_instance.this
terraform state show awscc_lex_bot_alias.this
terraform state show aws_cloudfront_distribution.ccp_site
```

### Test Connectivity
```bash
# Get Connect Instance ID
terraform output connect_instance_id

# Get Lex Bot ARN
terraform output lex_bot_id

# Get CloudFront URL
terraform output cloudfront_url

# Test API Gateway
curl -X GET "$(terraform output -raw auth_api_url)/auth/status"
```

---

## Troubleshooting Commands

### Fix Failed Resource
```bash
# Taint resource to force recreation
terraform taint aws_connect_contact_flow.bedrock_primary

# Apply just that resource
terraform apply -target=aws_connect_contact_flow.bedrock_primary -auto-approve
```

### Refresh State
```bash
# Sync state with actual infrastructure
terraform refresh
```

### View Resource Dependencies
```bash
# Generate dependency graph
terraform graph | dot -Tpng > graph.png

# View in DOT format
terraform graph
```

### Check for Drift
```bash
# Plan without applying
terraform plan -detailed-exitcode

# Exit codes:
# 0 = No changes
# 1 = Error
# 2 = Changes detected
```

---

## Destruction Commands

### Destroy Entire Stack
```bash
terraform destroy -auto-approve
```
**Time:** ~8-12 minutes (CloudFront is slowest)

### Destroy Specific Phase

#### Destroy CloudFront (Before full destroy)
```bash
terraform destroy -target=aws_cloudfront_distribution.ccp_site -auto-approve
```

#### Destroy Contact Flows
```bash
terraform destroy -target=aws_connect_contact_flow.bedrock_primary \
                  -target=aws_connect_contact_flow.voice_entry \
                  -target=aws_connect_contact_flow.chat_entry \
                  -target=aws_connect_contact_flow.queue_transfer \
                  -target=aws_connect_contact_flow.callback_task \
                  -auto-approve
```

#### Destroy Lex Bots
```bash
terraform destroy -target=awscc_lex_bot_alias.this \
                  -target=awscc_lex_bot_alias.banking \
                  -target=awscc_lex_bot_alias.sales \
                  -target=module.lex_bot \
                  -target=module.banking_bot \
                  -target=module.sales_bot \
                  -auto-approve
```

---

## Best Practices

### 1. Always Use Plan First (Production)
```bash
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

### 2. State Backup
```bash
# Backup state before major changes
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)
```

### 3. Target Specific Resources for Updates
```bash
# Update just the contact flow
terraform apply -target=aws_connect_contact_flow.bedrock_primary -auto-approve
```

### 4. Parallel Execution (Reduce Time)
```bash
# Increase parallelism (default is 10)
terraform apply -parallelism=20 -auto-approve
```

### 5. Debug Mode
```bash
# Enable detailed logging
export TF_LOG=DEBUG
terraform apply

# Save logs to file
export TF_LOG_PATH=terraform.log
terraform apply
```

### 6. Lock Timeout (For Stuck Locks)
```bash
terraform apply -lock-timeout=10m
```

### 7. Refresh Only (No Changes)
```bash
terraform apply -refresh-only
```

---

## Quick Reference

| Command | Purpose | Time |
|---------|---------|------|
| `terraform init` | Initialize backend & providers | 10-30s |
| `terraform validate` | Validate syntax | 1-2s |
| `terraform plan` | Preview changes | 30-60s |
| `terraform apply` | Deploy full stack | 25-35m |
| `terraform apply -target=<resource>` | Deploy specific resource | Varies |
| `terraform destroy` | Destroy all resources | 8-12m |
| `terraform state list` | List all resources | 1s |
| `terraform output` | Show outputs | 1s |
| `terraform refresh` | Sync state with reality | 10-20s |
| `terraform taint <resource>` | Mark for recreation | 1s |

---

## Environment Variables

### AWS Credentials
```bash
export AWS_PROFILE=your-profile
export AWS_REGION=eu-west-2
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
```

### Terraform Variables
```bash
# Override variables
export TF_VAR_project_name="MyConnect"
export TF_VAR_region="eu-west-2"
export TF_VAR_environment="dev"

# Or use -var flag
terraform apply -var="project_name=MyConnect" -var="region=eu-west-2" -auto-approve
```

---

## Phase Timing Summary

| Phase | Resources | Time | Critical Path |
|-------|-----------|------|---------------|
| 1. Foundation | ~40 | 30-60s | No |
| 2. Connect & Streaming | ~12 | 2-3m | No |
| 3. Lambda | ~10 | 3-5m | No |
| 4. Gateway Bot | ~15 | 5-10m | ⏱️ **YES** |
| 5. Banking/Sales Bots | ~20 | 8-12m | Parallel with 4 |
| 6. Queues & Routing | ~7 | 1-2m | No |
| 7. Contact Flows | ~9 | 2-3m | No |
| 8. Monitoring | ~20 | 1-2m | Background |
| 9. CloudFront | ~6 | 5-8m | ⏱️ **YES** |
| 10. Glue Catalog | ~5 | 30-60s | No |
| **TOTAL** | **~220** | **25-35m** | **2 bottlenecks** |

---

## Notes

- **Auto-approve flag** (`-auto-approve`) skips interactive confirmation. Remove for production safety.
- **Targeted deployments** use `-target` to deploy specific resources. Dependencies are automatically included.
- **Critical paths** (Phase 4 & 9) cannot be parallelized within themselves but other phases can run simultaneously.
- **State locking** prevents concurrent modifications. If locked, wait or use `-lock=false` (not recommended).
- **Resource count** may vary slightly based on configuration (e.g., number of queues, intents).

This guide ensures you can deploy the stack systematically while understanding dependencies and timing for each phase!
