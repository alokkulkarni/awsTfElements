# Contact Center in a Box

A complete, modular, enterprise-ready AWS Connect contact center solution with Lex bots, Lambda fulfillment, and Bedrock AI integration. Deploy a fully functional contact center with chat and voice capabilities in minutes.

## 🏗️ Architecture Overview

This solution provides a comprehensive contact center infrastructure with:

- **AWS Connect Instance**: Fully configured with queues, routing profiles, and user roles
- **Lex Bots**: Concierge bot and domain-specific bots (Banking, Product, Sales)
- **Lambda Functions**: Domain-specific fulfillment handlers for each bot
- **Bedrock Agent**: AI-powered banking assistant with guardrails for fallback intent classification
- **Integrations**: Seamless integration between all components
- **Security**: Least privilege IAM roles and comprehensive guardrails

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Customer Contact                              │
│                     (Voice / Chat / Email)                           │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS Connect Instance                              │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Contact Flows: Main, Customer Queue, Callback              │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────┬──────────────────────────┬──────────────────────────┘
               │                          │
               ▼                          ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│   Lex Concierge Bot     │  │   Bedrock Agent         │
│   (Primary Router)       │  │   (Banking Assistant)    │
└────────┬─────────────────┘  │   (Fallback Handler)     │
         │                    └──────────────────────────┘
         │
         ├─────────────────────┬─────────────────────┬───────────────────┐
         ▼                     ▼                     ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Lex Banking    │  │  Lex Product    │  │  Lex Sales      │  │  General Queue  │
│     Bot         │  │     Bot         │  │     Bot         │  │                 │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘  └─────────────────┘
         │                    │                     │
         ▼                    ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│Lambda Banking   │  │Lambda Product   │  │Lambda Sales     │
│  Fulfillment    │  │  Fulfillment    │  │  Fulfillment    │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                     │
         ▼                    ▼                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          Queues                                      │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐       │
│  │Banking │  │Product │  │ Sales  │  │General │  │Callback│       │
│  └────────┘  └────────┘  └────────┘  └────────┘  └────────┘       │
└─────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Contact Center Agents                           │
│         (Admin, Manager, Security Officer, Agents)                   │
└─────────────────────────────────────────────────────────────────────┘
```

## 📋 Features

### ✅ Complete Infrastructure
- AWS Connect instance with configurable settings
- S3 bucket for call recordings, chat transcripts, and CTRs
- CloudWatch logging for all components
- Phone number claiming (UK/GB by default)

### ✅ Intelligent Routing
- **Concierge Bot**: Primary entry point for all customer interactions
- **Domain Bots**: Specialized bots for Banking, Product, and Sales
- **Bedrock Agent**: AI-powered fallback for complex intent classification
- **Five Queues**: Banking, Product, Sales, General, and Callback

### ✅ Security & Compliance
- **Least Privilege IAM**: Separate roles for each service
- **Bedrock Guardrails**: Content filtering, PII protection, topic control
- **Secure Storage**: Encrypted S3 buckets with versioning
- **User Roles**: Admin, Call Center Manager, Security Officer, Agent

### ✅ Scalability & Modularity
- Independent module deployment
- Environment-specific configurations (dev, test, prod)
- Bot and Lambda versioning with aliases
- Parameterized configuration via terraform.tfvars

### ✅ Production Ready
- Comprehensive error handling
- Logging and monitoring
- Password generation for users
- Documentation and deployment guides

## 📁 Project Structure

```
Multi-tier-architecture-connect-stack/
├── main.tf                      # Main orchestration file
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output definitions
├── providers.tf                 # Provider configuration
├── terraform.tfvars.example     # Example configuration
├── README.md                    # This file
│
├── modules/
│   ├── iam/                     # IAM roles and policies
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── lambda/                  # Lambda functions
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── templates/           # Lambda handler templates
│   │   │   ├── banking_handler.tpl
│   │   │   ├── product_handler.tpl
│   │   │   └── sales_handler.tpl
│   │   ├── src/                 # Generated Lambda source (auto-created)
│   │   └── dist/                # Compiled Lambda packages (auto-created)
│   │
│   ├── lex/                     # Lex bots
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── bedrock/                 # Bedrock agent
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── connect/                 # Connect instance
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── contact_flows/           # Contact flows
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── flows/               # Flow JSON files (design in console first)
│   │
│   └── integration/             # Bot/Lambda associations
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Access to AWS Bedrock in eu-west-2 region
- Permissions to create Connect, Lex, Lambda, and Bedrock resources

### Step 1: Configure

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your settings
vim terraform.tfvars
```

**Required Configuration:**
- `project_name`: Your project name
- `environment`: dev, test, or prod
- `connect_instance_alias`: Globally unique alias for Connect
- `connect_users`: User details (emails, names, roles)

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan carefully to ensure all resources will be created correctly.

### Step 4: Deploy

```bash
terraform apply tfplan
```

**Deployment Time**: Approximately 15-20 minutes

### Step 5: Retrieve Credentials

```bash
# Get all user credentials (passwords)
terraform output -json user_credentials

# Get deployment information
terraform output deployment_info
```

### Step 6: Access Connect Console

```bash
# Get the Connect login URL
terraform output connect_login_url
```

Log in using the credentials from Step 5.

## 📖 Detailed Configuration

### Module Deployment Control

Enable or disable specific modules in `terraform.tfvars`:

```hcl
deploy_connect_instance = true
deploy_lex_bots         = true
deploy_lambda_functions = true
deploy_bedrock_agent    = true
deploy_integrations     = true
deploy_contact_flows    = false  # Enable after designing flows
```

### Queue Configuration

Define custom queues in `terraform.tfvars`:

```hcl
queues = {
  general = {
    description          = "General inquiries"
    max_contacts         = 10
    default_outbound_qid = null
  }
  banking = {
    description          = "Banking services"
    max_contacts         = 15
    default_outbound_qid = null
  }
  # Add more queues as needed
}
```

### User Roles

Configure users with appropriate security profiles:

```hcl
connect_users = {
  admin = {
    email            = "admin@example.com"
    first_name       = "System"
    last_name        = "Administrator"
    security_profile = "Admin"
  }
  agent1 = {
    email            = "agent1@example.com"
    first_name       = "Agent"
    last_name        = "One"
    security_profile = "Agent"
  }
}
```

**Available Security Profiles:**
- `Admin`: Full administrative access
- `CallCenterManager`: Manager with elevated permissions
- `SecurityProfile`: Security officer with audit access
- `Agent`: Standard agent access

### Lambda Configuration

Customize Lambda functions for each domain:

```hcl
lambda_functions = {
  banking = {
    description = "Banking domain fulfillment"
    handler     = "index.lambda_handler"
    runtime     = "python3.11"
    timeout     = 30
    memory_size = 256
    environment_vars = {
      DOMAIN = "banking"
    }
  }
}
```

### Bedrock Agent Configuration

Customize the Bedrock agent instructions:

```hcl
bedrock_agent_instruction = <<-EOT
You are a banking assistant responsible for:
1. Classifying customer queries
2. Providing product information
3. Routing to appropriate queues
EOT
```

## 🔧 Advanced Usage

### Modular Deployment

Deploy only specific components:

```bash
# Deploy only IAM and Lambda
terraform apply -target=module.iam -target=module.lambda

# Deploy only Connect instance
terraform apply -target=module.connect
```

### Multi-Environment Setup

Create separate tfvars files for each environment:

```bash
# Development
terraform apply -var-file=dev.tfvars

# Production
terraform apply -var-file=prod.tfvars
```

### Contact Flow Development

1. **Design flows in Connect console** (not via Terraform initially)
2. **Export flows** as JSON from the console
3. **Place JSON files** in `modules/contact_flows/flows/`
4. **Enable deployment** by setting `deploy_contact_flows = true`
5. **Re-apply Terraform** to deploy flows

```bash
# After designing flows
terraform apply -var="deploy_contact_flows=true"
```

## 🏛️ Architecture Details

### Flow of Customer Interaction

1. **Customer Calls/Chats** → Connect Instance
2. **Connect** → Invokes **Main Contact Flow**
3. **Main Flow** → Routes to **Concierge Lex Bot**
4. **Concierge Bot** → Identifies domain (Banking/Product/Sales)
5. **Domain Identified** → Routes to **Domain-Specific Lex Bot**
6. **Domain Bot** → Invokes **Lambda Fulfillment Function**
7. **Lambda** → Processes intent and returns response
8. **If Intent Unclear** → Fallback to **Bedrock Agent**
9. **Bedrock Agent** → Classifies intent and returns to flow
10. **Flow** → Routes to appropriate **Queue**
11. **Agent** → Receives contact with context

### Bedrock Agent Fallback Logic

When the Concierge or domain bots cannot confidently identify the intent:

1. Bot returns fallback intent
2. Contact flow invokes Bedrock agent
3. Bedrock agent analyzes query with:
   - Content filtering
   - PII protection
   - Intent classification
4. Agent returns classification and confidence
5. Flow routes based on Bedrock response
6. If still unclear, routes to General queue

### Security Architecture

#### IAM Roles (Least Privilege)
- **Connect Role**: Lex invocation, Lambda calls, S3 access, logging
- **Lex Role**: Polly for TTS, Lambda invocation, Bedrock access
- **Lambda Role**: CloudWatch logs, DynamoDB access, Connect attributes
- **Bedrock Role**: Model invocation, logging, S3 read access

#### Bedrock Guardrails
- **Content Filters**: Hate, insults, sexual, violence, misconduct
- **PII Protection**: Email, phone, SSN, credit cards, bank accounts
- **Topic Restrictions**: Financial advice, account access
- **Word Filters**: Passwords, PINs, sensitive terms

## 📊 Monitoring and Logging

All components log to CloudWatch:

- `/aws/connect/{instance-id}`: Connect logs
- `/aws/lambda/{function-name}`: Lambda execution logs
- `/aws/lex/{bot-name}`: Lex conversation logs
- `/aws/bedrock/agent/{agent-name}`: Bedrock agent logs

Access logs via AWS Console or CLI:

```bash
# View Connect logs
aws logs tail /aws/connect/{instance-id} --follow

# View Lambda logs
aws logs tail /aws/lambda/{function-name} --follow
```

## 🧪 Testing

### Test Lex Bots

```bash
# Test via AWS Console: Lex → Bots → Test
# Or via CLI:
aws lexv2-runtime recognize-text \
  --bot-id {bot-id} \
  --bot-alias-id {alias-id} \
  --locale-id en_GB \
  --session-id test-session \
  --text "I want to check my balance"
```

### Test Lambda Functions

```bash
# Invoke Lambda directly
aws lambda invoke \
  --function-name {function-name} \
  --payload file://test-event.json \
  response.json
```

### Test Bedrock Agent

```bash
# Test via AWS Console: Bedrock → Agents → Test
# Or via CLI:
aws bedrock-agent-runtime invoke-agent \
  --agent-id {agent-id} \
  --agent-alias-id {alias-id} \
  --session-id test-session \
  --input-text "What banking products do you offer?"
```

### Test Connect Instance

1. Log in to Connect console
2. Use the Contact Control Panel (CCP)
3. Make test calls using the claimed phone number
4. Test chat interface via embedded CCP

## 🔄 Updates and Maintenance

### Update Lambda Code

1. Modify template in `modules/lambda/templates/{domain}_handler.tpl`
2. Run `terraform apply` to redeploy

### Update Lex Bots

1. Modify bot configuration in `terraform.tfvars`
2. Run `terraform apply` to update bots

### Update Bedrock Agent

1. Modify agent instructions in `terraform.tfvars`
2. Run `terraform apply` to update agent

### Rotate User Passwords

```bash
# Force recreation of passwords
terraform taint 'module.connect[0].random_password.user_passwords["username"]'
terraform apply
```

## 🐛 Troubleshooting

### Connect Instance Creation Fails

**Issue**: Instance alias already exists
**Solution**: Change `connect_instance_alias` to a unique value

### Lex Bot Association Fails

**Issue**: Bots not fully deployed
**Solution**: Wait for bots to complete deployment, then retry

### Lambda Permission Denied

**Issue**: IAM role not properly configured
**Solution**: Verify IAM policies, check CloudWatch logs

### Bedrock Access Denied

**Issue**: Bedrock not enabled in region
**Solution**: Enable Bedrock in eu-west-2 via AWS Console

### Phone Number Claiming Fails

**Issue**: No available numbers in country
**Solution**: Try different country code or contact AWS support

## 💰 Cost Estimation

Approximate monthly costs for light usage (EU-West-2):

- **AWS Connect**: £5-15 (depends on usage)
- **Lex**: £1-5 (requests-based)
- **Lambda**: £0.50-2 (minimal usage)
- **Bedrock**: £10-30 (Claude Sonnet, usage-based)
- **S3 Storage**: £0.50-1
- **CloudWatch Logs**: £1-2

**Total**: £18-55/month for development/testing

Production costs will vary based on:
- Number of concurrent calls/chats
- Call duration and volume
- Bedrock usage frequency
- Storage retention

## 🤝 Support and Contribution

### Getting Help

1. Review this README thoroughly
2. Check Terraform state for errors: `terraform show`
3. Review CloudWatch logs for component-specific issues
4. Check AWS service quotas and limits

### Best Practices

- Always review `terraform plan` before applying
- Use separate environments (dev, test, prod)
- Regularly backup `terraform.tfstate`
- Keep credentials secure (use AWS Secrets Manager in production)
- Monitor costs via AWS Cost Explorer
- Test changes in dev environment first

## 📝 License

This solution is provided as-is for use with your AWS account. Standard AWS service charges apply.

## 🎯 Roadmap

Future enhancements:
- [ ] Multi-region deployment support
- [ ] Advanced contact flow templates
- [ ] CCP customization module
- [ ] Analytics and reporting dashboard
- [ ] Automated testing framework
- [ ] CI/CD pipeline templates

## 📞 Quick Reference

### Important URLs
- **Connect Console**: `https://{alias}.my.connect.aws/`
- **CCP**: `https://{alias}.my.connect.aws/ccp-v2/`
- **Lex Console**: AWS Console → Amazon Lex
- **Bedrock Console**: AWS Console → Amazon Bedrock

### Key Commands
```bash
# Initialize
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Get credentials
terraform output -json user_credentials

# Destroy (CAUTION)
terraform destroy
```

### Default Region
All resources are deployed to **eu-west-2** (London)

---

**Built with ❤️ using Terraform, AWS Connect, Lex, Lambda, and Bedrock**
