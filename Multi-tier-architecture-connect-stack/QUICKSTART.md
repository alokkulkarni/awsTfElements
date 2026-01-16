# Quick Start Guide - Contact Center in a Box

Get your AWS Connect contact center up and running in 30 minutes.

## ⚡ Prerequisites (5 minutes)

### 1. Install Required Tools

```bash
# Check Terraform
terraform version  # Need >= 1.0

# Check AWS CLI
aws --version     # Need >= 2.0

# Configure AWS CLI
aws configure
```

### 2. Enable Bedrock Access

```bash
# Go to AWS Console → Bedrock → Model Access (eu-west-2)
# Request access to: Claude 3 Sonnet
# Or use CLI:
aws bedrock list-foundation-models --region eu-west-2
```

## 🚀 Deploy in 4 Steps (20 minutes)

### Step 1: Configure (3 minutes)

```bash
cd Multi-tier-architecture-connect-stack

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your details
vim terraform.tfvars
```

**Minimum Required Changes:**

```hcl
# Line 5: Unique alias
connect_instance_alias = "your-company-name-contact-center"

# Lines 25-35: Real email addresses
connect_users = {
  admin = {
    email = "your-email@company.com"  # ← CHANGE THIS
    ...
  }
}
```

### Step 2: Initialize (1 minute)

```bash
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 3: Deploy (15 minutes)

```bash
# Review plan
terraform plan

# Deploy
terraform apply -auto-approve
```

**Deployment Time:** ~15-20 minutes

### Step 4: Get Credentials (1 minute)

```bash
# Save credentials (SECURE THIS FILE!)
terraform output -json user_credentials > credentials.json
chmod 600 credentials.json

# Get login URL
terraform output connect_login_url
```

## ✅ Verify Deployment (5 minutes)

### Quick Verification

```bash
# Check all outputs
terraform output

# Verify Connect instance
aws connect describe-instance \
  --instance-id $(terraform output -raw connect_instance_id) \
  --region eu-west-2

# Test Lex bot
aws lexv2-runtime recognize-text \
  --bot-id $(terraform output -json lex_bot_ids | jq -r '.banking') \
  --bot-alias-id $(terraform output -json lex_prod_aliases | jq -r '.banking.bot_alias_id') \
  --locale-id en_GB \
  --session-id test \
  --text "check my balance" \
  --region eu-west-2
```

### Login to Connect

1. **Get URL:**
   ```bash
   terraform output connect_login_url
   ```

2. **Get Password:**
   ```bash
   cat credentials.json | jq '.admin.password' -r
   ```

3. **Login:**
   - Username: `admin`
   - Password: (from above)
   - You'll be prompted to change password

4. **Verify Setup:**
   - ✅ Check Queues (5 queues should exist)
   - ✅ Check Users (all users from tfvars)
   - ✅ Check Phone Number (1 claimed number)
   - ✅ Check Routing Profiles (Basic Routing Profile)

## 🎨 Design Contact Flows (Optional - 30 minutes)

Contact flows are **not deployed** by default. Design them in the console first:

1. **Navigate to Contact Flows:**
   - Connect Console → Routing → Contact Flows

2. **Create Main Flow:**
   - Click "Create contact flow"
   - Add blocks:
     - Set logging behavior
     - Get customer input (integrate Concierge bot)
     - Transfer to queue based on bot response
   - Save and Publish as "Main Flow"

3. **Create Queue Flow:**
   - Create "Customer queue flow" type
   - Add hold music and announcements
   - Save and Publish

4. **Associate with Phone Number:**
   - Channels → Phone Numbers
   - Edit your number
   - Associate with Main Flow

5. **Test:**
   - Call the number
   - Interact with bot
   - Verify routing

## 📊 Monitor (5 minutes)

### CloudWatch Dashboard

```bash
# View Connect logs
aws logs tail /aws/connect/$(terraform output -raw connect_instance_id) \
  --follow --region eu-west-2

# View Lambda logs
aws logs tail /aws/lambda/*banking* --follow --region eu-west-2
```

### Metrics to Watch

- **Call Volume:** Connect → Metrics & Quality
- **Queue Performance:** Routing → Queues → Select Queue
- **Agent Status:** Metrics & Quality → Real-time metrics
- **Bot Performance:** Lex Console → Analytics

## 🧪 Test Everything (10 minutes)

### Test 1: Call the Number

```bash
# Get phone number
terraform output connect_phone_number

# Call from your phone
# Expected: Hear greeting, interact with bot, get routed
```

### Test 2: Test Each Bot

```bash
# Banking Bot
aws lexv2-runtime recognize-text \
  --bot-id $(terraform output -json lex_bot_ids | jq -r '.banking') \
  --bot-alias-id $(terraform output -json lex_prod_aliases | jq -r '.banking.bot_alias_id') \
  --locale-id en_GB \
  --session-id test1 \
  --text "I want to check my account balance" \
  --region eu-west-2

# Product Bot
aws lexv2-runtime recognize-text \
  --bot-id $(terraform output -json lex_bot_ids | jq -r '.product') \
  --bot-alias-id $(terraform output -json lex_prod_aliases | jq -r '.product.bot_alias_id') \
  --locale-id en_GB \
  --session-id test2 \
  --text "Tell me about your products" \
  --region eu-west-2

# Sales Bot
aws lexv2-runtime recognize-text \
  --bot-id $(terraform output -json lex_bot_ids | jq -r '.sales') \
  --bot-alias-id $(terraform output -json lex_prod_aliases | jq -r '.sales.bot_alias_id') \
  --locale-id en_GB \
  --session-id test3 \
  --text "I want to open a premium account" \
  --region eu-west-2
```

### Test 3: Login as Different Users

```bash
# Get all credentials
cat credentials.json | jq

# Login as each user type:
# - Admin: Full access
# - Manager: Management features
# - Security: Audit features
# - Agent: CCP only
```

## 🔧 Common Tasks

### Add a New User

```bash
# Edit terraform.tfvars
vim terraform.tfvars

# Add to connect_users:
# agent2 = {
#   email = "agent2@company.com"
#   first_name = "Agent"
#   last_name = "Two"
#   security_profile = "Agent"
# }

# Apply changes
terraform apply
```

### Add a New Queue

```bash
# Edit terraform.tfvars
vim terraform.tfvars

# Add to queues:
# vip = {
#   description = "VIP customer queue"
#   max_contacts = 5
#   default_outbound_qid = null
# }

# Apply changes
terraform apply
```

### Update Bedrock Instructions

```bash
# Edit terraform.tfvars
vim terraform.tfvars

# Modify bedrock_agent_instruction

# Apply changes
terraform apply
```

### View Logs

```bash
# Connect logs
aws logs tail /aws/connect/$(terraform output -raw connect_instance_id) --follow

# Lambda logs (banking)
aws logs tail /aws/lambda/contact-center-box-dev-banking-fulfillment --follow

# Lex logs
# Available in Lex Console → Bot → Analytics

# Bedrock logs
aws logs tail /aws/bedrock/agent/banking-assistant-agent --follow
```

## 🆘 Quick Troubleshooting

### Issue: Instance Alias Already Exists

```bash
# Change alias in terraform.tfvars
connect_instance_alias = "new-unique-name-here"

# Retry
terraform apply
```

### Issue: Bedrock Access Denied

```bash
# Enable Bedrock model access
# AWS Console → Bedrock → Model Access → Request Access
```

### Issue: Phone Number Not Claimed

```bash
# Check available numbers
aws connect search-available-phone-numbers \
  --instance-id $(terraform output -raw connect_instance_id) \
  --phone-number-country-code GB \
  --phone-number-type DID \
  --region eu-west-2

# Contact AWS Support if no numbers available
```

### Issue: Bot Not Responding

```bash
# Check bot status
aws lexv2-models describe-bot \
  --bot-id $(terraform output -json lex_bot_ids | jq -r '.concierge') \
  --region eu-west-2

# Check Lambda permissions
aws lambda get-policy \
  --function-name contact-center-box-dev-banking-fulfillment \
  --region eu-west-2
```

## 📚 Next Steps

1. ✅ **Read Full Documentation:**
   - [README.md](README.md) - Complete overview
   - [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Detailed deployment
   - [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture details

2. ✅ **Design Contact Flows:**
   - Use Connect Flow Designer
   - Export and version control
   - Enable deployment via Terraform

3. ✅ **Configure Monitoring:**
   - Set up CloudWatch dashboards
   - Configure alarms
   - Enable Contact Lens

4. ✅ **Train Agents:**
   - Provide CCP training
   - Document processes
   - Set up knowledge base

5. ✅ **Go Live:**
   - Test thoroughly
   - Update to production environment
   - Monitor and optimize

## 📞 Support

- **Documentation:** See README.md
- **AWS Support:** https://console.aws.amazon.com/support/
- **Terraform:** https://www.terraform.io/docs/

## 💡 Pro Tips

1. **Always Review Plans:**
   ```bash
   terraform plan -out=tfplan
   terraform show tfplan
   terraform apply tfplan
   ```

2. **Backup State:**
   ```bash
   cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)
   ```

3. **Use Remote State (Production):**
   ```hcl
   terraform {
     backend "s3" {
       bucket = "your-terraform-state"
       key    = "contact-center/terraform.tfstate"
       region = "eu-west-2"
     }
   }
   ```

4. **Tag Everything:**
   - Already done! All resources are tagged

5. **Monitor Costs:**
   - Check AWS Cost Explorer daily
   - Set up billing alerts

---

**Need Help?** Review the full [README.md](README.md) and [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

**Deployment Time:** 30 minutes  
**Estimated Cost:** £18-55/month (light usage)

**Ready to Deploy?** Run `terraform apply` and get started! 🚀
