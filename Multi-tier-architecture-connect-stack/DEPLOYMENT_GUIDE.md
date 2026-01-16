# Deployment Guide - Contact Center in a Box

## Pre-Deployment Checklist

### ✅ AWS Prerequisites

- [ ] AWS Account with appropriate permissions
- [ ] AWS CLI installed and configured
- [ ] AWS credentials with access to:
  - AWS Connect
  - Amazon Lex V2
  - AWS Lambda
  - Amazon Bedrock
  - IAM
  - S3
  - CloudWatch
- [ ] Terraform CLI version >= 1.0 installed
- [ ] Access to AWS Bedrock enabled in eu-west-2 region

### ✅ Bedrock Model Access

Before deployment, ensure you have access to the Bedrock model:

```bash
# Check if you have Bedrock access
aws bedrock list-foundation-models --region eu-west-2

# Request access to Claude 3 Sonnet if needed:
# 1. Go to AWS Console → Bedrock → Model Access
# 2. Request access to: anthropic.claude-3-sonnet-20240229-v1:0
# 3. Wait for approval (usually immediate)
```

### ✅ Service Quotas

Verify service quotas in your account:

```bash
# Check Connect quotas
aws service-quotas get-service-quota \
  --service-code connect \
  --quota-code L-0A2D1715 \
  --region eu-west-2

# Check Lex quotas
aws service-quotas get-service-quota \
  --service-code lex \
  --quota-code L-2D017E50 \
  --region eu-west-2
```

## Step-by-Step Deployment

### Step 1: Clone and Configure

```bash
# Navigate to project directory
cd Multi-tier-architecture-connect-stack

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

### Step 2: Customize Configuration

Edit `terraform.tfvars` and update these **required** fields:

```hcl
# REQUIRED: Make this globally unique
connect_instance_alias = "your-company-contact-center-unique-name"

# REQUIRED: Update with real email addresses
connect_users = {
  admin = {
    email      = "admin@yourcompany.com"  # CHANGE THIS
    first_name = "System"
    last_name  = "Administrator"
    security_profile = "Admin"
  }
  manager = {
    email      = "manager@yourcompany.com"  # CHANGE THIS
    first_name = "Call Center"
    last_name  = "Manager"
    security_profile = "CallCenterManager"
  }
}

# OPTIONAL: Customize project details
project_name = "your-project-name"
environment  = "dev"
```

### Step 3: Initialize Terraform

```bash
# Initialize Terraform and download providers
terraform init

# Expected output:
# Initializing modules...
# Initializing provider plugins...
# Terraform has been successfully initialized!
```

### Step 4: Validate Configuration

```bash
# Validate Terraform syntax
terraform validate

# Expected output:
# Success! The configuration is valid.

# Format Terraform files
terraform fmt -recursive
```

### Step 5: Review Deployment Plan

```bash
# Create execution plan
terraform plan -out=tfplan

# Review the plan carefully:
# - Check resource counts
# - Verify resource names
# - Confirm regions
# - Review IAM policies
```

**Expected Resources**: Approximately 60-80 resources will be created:
- 1 Connect Instance
- 5 Queues
- 4 Lex Bots (with locales, intents, versions, aliases)
- 3 Lambda Functions (with versions, aliases, permissions)
- 1 Bedrock Agent (with guardrail and aliases)
- Multiple IAM Roles and Policies
- S3 Buckets and configurations
- CloudWatch Log Groups
- User accounts and routing profiles

### Step 6: Deploy Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# When prompted, review and type 'yes' to confirm

# Deployment typically takes 15-20 minutes
# Progress will be displayed in real-time
```

### Step 7: Capture Outputs

```bash
# Save all outputs to a file
terraform output -json > outputs.json

# Get user credentials (SENSITIVE - handle securely)
terraform output -json user_credentials > credentials.json
chmod 600 credentials.json

# Display deployment information
terraform output deployment_info
```

### Step 8: Access Connect Instance

```bash
# Get the Connect login URL
CONNECT_URL=$(terraform output -raw connect_login_url)
echo "Connect Login URL: $CONNECT_URL"

# Get the phone number
terraform output connect_phone_number
```

### Step 9: Initial Login and Setup

1. **Open the Connect Console**:
   ```bash
   open $CONNECT_URL  # On macOS
   # Or copy and paste the URL into your browser
   ```

2. **Login as Admin**:
   - Username: `admin`
   - Password: (from `credentials.json`)

3. **Change Password**: You'll be prompted to change the password on first login

4. **Verify Setup**:
   - Check Queues: Routing → Queues
   - Check Routing Profiles: Users → Routing Profiles
   - Check Users: Users → User Management
   - Check Phone Number: Channels → Phone Numbers

### Step 10: Design Contact Flows

Contact flows are **NOT deployed initially** - you must design them first:

1. **Navigate to Contact Flows**:
   - Connect Console → Routing → Contact Flows

2. **Create Main Flow**:
   - Click "Create contact flow"
   - Design your flow using these blocks:
     - Get customer input (integrate with Concierge bot)
     - Transfer to queue based on bot response
     - Set contact attributes
     - Play prompts
   - Save and Publish

3. **Create Customer Queue Flow**:
   - Create "Customer queue flow" type
   - Add hold music
   - Add position in queue announcements
   - Save and Publish

4. **Create Callback Flow**:
   - Create callback flow
   - Configure callback queue
   - Save and Publish

5. **Export Flows**:
   - For each flow: Actions → Export flow
   - Save JSON files to `modules/contact_flows/flows/`

6. **Enable Terraform Deployment**:
   ```bash
   # Update terraform.tfvars
   deploy_contact_flows = true
   
   # Re-deploy
   terraform apply
   ```

### Step 11: Test the System

#### Test 1: Lex Bots

```bash
# Test Banking Bot
aws lexv2-runtime recognize-text \
  --bot-id $(terraform output -json lex_bot_ids | jq -r '.banking') \
  --bot-alias-id $(terraform output -json lex_prod_aliases | jq -r '.banking.bot_alias_id') \
  --locale-id en_GB \
  --session-id test-1 \
  --text "I want to check my account balance" \
  --region eu-west-2
```

#### Test 2: Lambda Functions

```bash
# Create test event
cat > test-banking-event.json <<EOF
{
  "sessionState": {
    "intent": {
      "name": "AccountBalanceIntent",
      "slots": {
        "AccountType": {
          "value": {
            "interpretedValue": "checking"
          }
        }
      }
    },
    "sessionAttributes": {}
  }
}
EOF

# Invoke Lambda
aws lambda invoke \
  --function-name $(terraform output -json lambda_functions | jq -r '.banking.function_name') \
  --payload file://test-banking-event.json \
  --region eu-west-2 \
  response.json

# View response
cat response.json | jq
```

#### Test 3: Bedrock Agent

Via AWS Console:
1. Navigate to Amazon Bedrock → Agents
2. Select your agent
3. Click "Test" tab
4. Enter: "I want to open a savings account"
5. Verify response and classification

#### Test 4: Complete Call Flow

1. **Call the Phone Number**:
   ```bash
   terraform output connect_phone_number
   ```

2. **Expected Flow**:
   - Hear greeting
   - Interact with Concierge bot
   - Bot routes to appropriate domain bot
   - Intent is fulfilled
   - Transferred to queue (if configured)
   - Agent receives call with context

3. **Test Chat**:
   - Use CCP embedded chat
   - Similar flow to voice

### Step 12: Configure CCP for Agents

1. **Agent Login URL**:
   ```
   https://{instance-alias}.my.connect.aws/ccp-v2/
   ```

2. **Distribute Credentials**:
   - Send login URLs and credentials to users
   - Advise password change on first login

3. **Agent Training**:
   - Show agents how to use CCP
   - Explain contact attributes and context
   - Demonstrate callback functionality

## Post-Deployment Configuration

### Configure Additional Features

#### Enable Contact Lens

```hcl
# In terraform.tfvars
connect_contact_lens_enabled = true
```

#### Add More Users

```hcl
# In terraform.tfvars
connect_users = {
  # ... existing users ...
  agent2 = {
    email            = "agent2@yourcompany.com"
    first_name       = "Agent"
    last_name        = "Two"
    security_profile = "Agent"
  }
}
```

#### Customize Queues

```hcl
# In terraform.tfvars
queues = {
  vip = {
    description          = "VIP customer queue"
    max_contacts         = 5
    default_outbound_qid = null
  }
}
```

#### Update Bedrock Instructions

```hcl
# In terraform.tfvars
bedrock_agent_instruction = <<-EOT
Your custom instructions here...
EOT
```

After any changes:
```bash
terraform plan
terraform apply
```

## Deployment Scenarios

### Scenario 1: Fresh Deployment

```bash
# All modules enabled
deploy_connect_instance = true
deploy_lex_bots         = true
deploy_lambda_functions = true
deploy_bedrock_agent    = true
deploy_integrations     = true
deploy_contact_flows    = false  # Enable after designing

terraform apply
```

### Scenario 2: Incremental Deployment

```bash
# Phase 1: Core infrastructure
deploy_connect_instance = true
deploy_lex_bots         = false
deploy_lambda_functions = false
deploy_bedrock_agent    = false
deploy_integrations     = false

terraform apply

# Phase 2: Add bots and Lambda
deploy_lex_bots         = true
deploy_lambda_functions = true

terraform apply

# Phase 3: Add Bedrock and integrations
deploy_bedrock_agent    = true
deploy_integrations     = true

terraform apply
```

### Scenario 3: Update Existing Deployment

```bash
# Modify configuration in terraform.tfvars
vim terraform.tfvars

# Plan changes
terraform plan -out=tfplan

# Review changes carefully
terraform show tfplan

# Apply updates
terraform apply tfplan
```

## Rollback Procedures

### Rollback Recent Changes

```bash
# View state history
terraform state list

# Rollback to previous state (if available)
cp terraform.tfstate.backup terraform.tfstate

# Or use workspace
terraform workspace select previous
```

### Destroy Specific Modules

```bash
# Destroy only integrations
terraform destroy -target=module.integration

# Destroy only contact flows
terraform destroy -target=module.contact_flows
```

### Complete Teardown

**⚠️ WARNING: This will delete ALL resources**

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm by typing 'yes' when prompted
```

## Troubleshooting Deployment Issues

### Issue: Connect Instance Alias Already Exists

**Error**: `InvalidRequestException: Instance alias already exists`

**Solution**:
```bash
# Change alias in terraform.tfvars
connect_instance_alias = "new-unique-alias-here"

# Retry
terraform apply
```

### Issue: Bedrock Access Denied

**Error**: `AccessDeniedException: You don't have access to the model`

**Solution**:
1. Go to AWS Console → Bedrock → Model Access
2. Request access to Claude 3 Sonnet
3. Wait for approval (usually instant)
4. Retry deployment

### Issue: Lambda Deployment Fails

**Error**: `Error creating Lambda function`

**Solution**:
```bash
# Check Lambda role
terraform state show 'module.iam.aws_iam_role.lambda'

# Verify permissions
aws iam get-role --role-name {role-name}

# Manually fix and retry
terraform apply -target=module.lambda
```

### Issue: Insufficient Permissions

**Error**: `UnauthorizedOperation` or `AccessDenied`

**Solution**:
```bash
# Verify your AWS credentials
aws sts get-caller-identity

# Check required permissions in AWS Console → IAM
# Ensure your user/role has:
# - ConnectFullAccess
# - LexV2FullAccess
# - LambdaFullAccess
# - BedrockFullAccess
# - IAMFullAccess
```

### Issue: State Lock

**Error**: `Error locking state: ConditionalCheckFailedException`

**Solution**:
```bash
# If you're sure no other process is running:
terraform force-unlock {LOCK_ID}

# Or wait for the other process to complete
```

## Maintenance Windows

### Planned Updates

1. **Notify Users**: Send advance notice of maintenance
2. **Backup State**: 
   ```bash
   cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)
   ```
3. **Apply Changes**:
   ```bash
   terraform apply
   ```
4. **Verify**: Test all functionality
5. **Notify Users**: Confirm completion

### Emergency Rollback

If deployment causes issues:

```bash
# Quick rollback
terraform apply -replace="{resource_address}"

# Or restore backup
cp terraform.tfstate.backup terraform.tfstate
terraform refresh
```

## Validation Checklist

After deployment, verify:

- [ ] Connect instance is accessible
- [ ] Users can log in with provided credentials
- [ ] Phone number is claimed and functional
- [ ] All queues are visible in console
- [ ] Lex bots respond to test utterances
- [ ] Lambda functions execute successfully
- [ ] Bedrock agent responds correctly
- [ ] Bot associations are active in Connect
- [ ] CloudWatch logs are populated
- [ ] S3 bucket is created and accessible

## Next Steps

1. **Design Contact Flows**: Use Connect Flow Designer
2. **Train Agents**: Provide CCP training
3. **Configure Reporting**: Set up CloudWatch dashboards
4. **Set Up Monitoring**: Configure alarms and alerts
5. **Enable Contact Lens**: For analytics and insights
6. **Customize Branding**: Update CCP appearance
7. **Scale**: Add more agents and queues as needed

## Support Resources

- **AWS Connect Documentation**: https://docs.aws.amazon.com/connect/
- **Lex V2 Documentation**: https://docs.aws.amazon.com/lexv2/
- **Bedrock Documentation**: https://docs.aws.amazon.com/bedrock/
- **Terraform Documentation**: https://registry.terraform.io/providers/hashicorp/aws/

---

**Deployment Complete! 🎉**

Your contact center is now ready for configuration and testing.
