# Lex Only Deployment

This directory contains a minimal Terraform configuration that deploys **only** the Lex bots and their related Lambda functions from the comprehensive stack. No Amazon Connect, S3, DynamoDB, or other infrastructure is deployed.

## What Gets Deployed

### Lex Bots
- **Main Gateway Bot** (`lex-only-bot`) - Primary bot with ChatIntent and TransferToAgent intent
- **Banking Bot** (`lex-only-banking-bot`) - Specialized bot with banking intents (CheckBalance, GetStatement, CancelDirectDebit, CancelStandingOrder, TransferMoney)
- **Sales Bot** (`lex-only-sales-bot`) - Specialized bot with sales intents (ProductInfo)

### Lambda Functions
- **Bedrock MCP Lambda** - Main fulfillment Lambda that uses Claude 3.5 Sonnet for conversational AI
- **Banking Lambda** - Handles banking-specific intent fulfillment
- **Sales Lambda** - Handles sales-specific intent fulfillment

### IAM Roles & Permissions
- Lambda execution role with permissions for:
  - CloudWatch Logs
  - Bedrock model invocation
  - CloudWatch metrics
- Lex service roles with permissions for:
  - Polly (text-to-speech)
  - Lambda invocation

### CloudWatch Log Groups
- Log groups for all Lambda functions
- Conversation logs for Lex bots

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0
3. **Python 3.11** for Lambda builds
4. **Bedrock Access** - Ensure your AWS account has access to Claude 3.5 Sonnet in us-east-1

## Usage

### 1. Initialize Terraform

```bash
cd lex_only_deployment
terraform init
```

### 2. Review Configuration

Edit `terraform.tfvars` if you want to customize:
- AWS region
- Project name
- Locale (en_GB or en_US)
- Voice ID (Amy, Joanna, etc.)
- Banking intents and utterances

### 3. Plan Deployment

```bash
terraform plan
```

### 4. Deploy

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 5. Test the Bots

After deployment completes, you can test the bots in the AWS Console:

1. Go to Amazon Lex V2 console
2. Find your bots:
   - `lex-only-bot`
   - `lex-only-banking-bot`
   - `lex-only-sales-bot`
3. Use the "Test" feature to chat with the bots

## Outputs

After successful deployment, Terraform will output:

- Bot IDs and Alias IDs for all three bots
- Lambda ARNs for all functions
- Lambda Alias ARNs for integration

## Clean Up

To remove all deployed resources:

```bash
terraform destroy
```

## Cost Considerations

This deployment includes:
- 3 Lex bots (free tier: 10,000 text requests/month)
- 3 Lambda functions (free tier: 1M requests/month)
- CloudWatch Logs (pay per GB ingested/stored)
- Bedrock API calls (pay per token)

Monitor your usage in AWS Cost Explorer.

## Differences from Comprehensive Stack

This deployment **DOES NOT** include:
- Amazon Connect instance
- S3 buckets
- DynamoDB tables
- Kinesis streams
- API Gateway
- SNS topics
- Contact flows
- Queues or routing profiles
- Provisioned concurrency for Lambdas

## Integration Notes

If you want to integrate these bots with Amazon Connect later:

1. The bot IDs and alias IDs are available in Terraform outputs
2. You'll need to associate the bots with a Connect instance
3. Create contact flows that route to these bots
4. Update Lambda environment variables if they depend on Connect resources

## Troubleshooting

### Lambda Build Fails

Ensure you have Python 3.11 and pip installed:
```bash
python3 --version
pip3 --version
```

### Bedrock Permission Denied

Verify you have access to Bedrock in us-east-1:
```bash
aws bedrock list-foundation-models --region us-east-1
```

### Lex Bot Version Creation Fails

This usually happens if intents aren't properly built. Check CloudWatch logs and ensure all intents have at least one sample utterance.

## Architecture

```
┌─────────────────────────┐
│   Main Gateway Bot      │
│  (Bedrock MCP Lambda)   │
└───────────┬─────────────┘
            │
            ├─────────────────────┐
            │                     │
┌───────────▼───────────┐  ┌─────▼──────────────┐
│   Banking Bot         │  │   Sales Bot        │
│ (Banking Lambda)      │  │ (Sales Lambda)     │
└───────────────────────┘  └────────────────────┘
```

Each bot has its own Lambda fulfillment function and can operate independently.
