# Quick Reference: Connect Comprehensive Stack Outputs

## 🔑 Terraform Outputs (After Deploy)

Run `terraform output` to see these values:

```bash
terraform output                    # See all outputs
terraform output -raw lex_bot_id    # Get specific output
```

### Key Outputs You'll Need:

| Output | Purpose |
|--------|---------|
| `connect_instance_id` | Connect instance for AWS CLI commands |
| `connect_instance_access_url` | URL to access Connect admin console |
| `lex_bot_id` | Main bot ID for testing/configuration |
| `lex_bot_name` | Main bot name for Connect flows |
| `specialized_bots` | ARNs for Banking & Sales bots |
| `ccp_url` | CloudFront URL for custom CCP |
| `did_phone_number` | Your DID phone number |
| `toll_free_phone_number` | Your toll-free number |

---

## 📋 Post-Deployment Checklist

### ✅ Automated (Handled by Scripts)
- [x] Lambda functions deployed
- [x] Lex bots created and built
- [x] Banking & Sales bots associated with Connect
- [x] DynamoDB tables created
- [x] Phone numbers claimed
- [x] Queues and routing profiles created
- [x] Contact flows (Voice/Chat Entry, Queue Transfer, Callback)

### ⚠️ Manual Steps Required

#### 1. Create BedrockPrimaryFlow in Console
**Why?** Complex multi-branch flow with Lex integration is easier to configure/test in UI.

**Steps:**
1. Open Connect Console: `terraform output connect_instance_access_url`
2. Go to: **Routing → Flows**
3. Click: **Create flow**
4. Name: `BedrockPrimaryFlow`
5. Add block: **Get customer input**
6. Configure:
   - Type: "Text to speech or chat text"
   - Prompt: "Hello! How can I help you today?"
   - **Amazon Lex**: Select bot name from `terraform output lex_bot_name`
   - **Alias**: prod
   - **Locale**: en_GB
7. Add branches:
   - **Intent: TransferToAgent** → Add **Transfer to queue** block → Select `GeneralAgentQueue`
   - **Error/Default** → Loop back or disconnect
8. **Save & Publish**
9. **Copy the Contact Flow ID** (from URL or ARN)

#### 2. Run Post-Deployment Script
```bash
./scripts/post_deployment_connect_bot.sh
```

This will:
- ✅ Associate main gateway bot with Connect
- ✅ Validate all bot associations (3 bots total)
- ✅ Update callback dispatcher Lambda with flow ID
- ✅ Associate phone numbers with BedrockPrimaryFlow
- ✅ Test bot integration

---

## 🧪 Testing Guide

### Test 1: Bot Direct Integration
```bash
# Get bot details
BOT_ID=$(terraform output -raw lex_bot_id)
ALIAS_ID=$(aws lexv2-models list-bot-aliases \
  --bot-id $BOT_ID --region eu-west-2 \
  --query "botAliasSummaries[?botAliasName=='prod'].botAliasId" \
  --output text)

# Test bot
aws lexv2-runtime recognize-text \
  --bot-id $BOT_ID \
  --bot-alias-id $ALIAS_ID \
  --locale-id en_GB \
  --session-id test-$(date +%s) \
  --text "Hello, I need help" \
  --region eu-west-2
```

**Expected Response:** Should get response from Bedrock via Lambda

### Test 2: Phone Call Flow
1. Call: `terraform output toll_free_phone_number`
2. Say: "I want to check my balance"
3. **Expected:**
   - Bot responds via Bedrock
   - Banking intent recognized
   - Balance returned

### Test 3: Agent Transfer
1. Call the phone number
2. Say: "I need to speak to an agent"
3. **Expected:**
   - Bot recognizes TransferToAgent intent
   - Call transferred to GeneralAgentQueue
   - Agent (if logged in) receives call

### Test 4: Banking Bot Specialization
1. Call and say: "Transfer money"
2. **Expected:** Banking bot responds with security prompt

### Test 5: Callback Request
```bash
# Test callback API
python3 scripts/callback_cli.py request \
  --phone "+447123456789" \
  --instance-id $(terraform output -raw connect_instance_id)
```

---

## 🔍 Monitoring & Logs

### CloudWatch Log Groups
```bash
# View Bedrock MCP logs
aws logs tail /aws/lambda/connect-comprehensive-bedrock-mcp --follow

# View Lex conversation logs
aws logs tail /aws/lex/connect-comprehensive-bot --follow

# View Banking bot logs
aws logs tail /aws/lambda/connect-comprehensive-banking --follow
```

### DynamoDB Tables
```bash
# Check conversation history
aws dynamodb scan --table-name connect-comprehensive-conversation-history --limit 5

# Check hallucination logs
aws dynamodb scan --table-name connect-comprehensive-hallucination-logs --limit 5

# Check callbacks
aws dynamodb scan --table-name connect-comprehensive-callbacks --limit 5
```

### Bot Status
```bash
BOT_ID=$(terraform output -raw lex_bot_id)

# Check bot version
aws lexv2-models describe-bot-version \
  --bot-id $BOT_ID \
  --bot-version DRAFT \
  --region eu-west-2

# List all intents
aws lexv2-models list-intents \
  --bot-id $BOT_ID \
  --bot-version DRAFT \
  --locale-id en_GB \
  --region eu-west-2
```

---

## 🚨 Troubleshooting

### Issue: Bot not responding
**Check:**
```bash
# 1. Verify bot alias status
aws lexv2-models describe-bot-alias \
  --bot-id $(terraform output -raw lex_bot_id) \
  --bot-alias-id <ALIAS_ID> \
  --region eu-west-2

# 2. Check Lambda permissions
aws lambda get-policy \
  --function-name connect-comprehensive-bedrock-mcp \
  --region eu-west-2
```

### Issue: Phone doesn't connect to bot
**Check:**
```bash
# 1. Verify phone number association
INSTANCE_ID=$(terraform output -raw connect_instance_id)
aws connect list-phone-numbers-v2 \
  --target-arn $(aws connect describe-instance \
    --instance-id $INSTANCE_ID \
    --query 'Instance.Arn' \
    --output text) \
  --region eu-west-2
```

### Issue: Agent transfer not working
**Check:**
1. TransferToAgent intent exists: See bot intents above
2. Contact flow has transfer block
3. Agents logged in to CCP

### Issue: Hallucinations detected
**View logs:**
```bash
aws dynamodb query \
  --table-name connect-comprehensive-hallucination-logs \
  --limit 10 \
  --scan-index-forward false
```

---

## 📞 Agent CCP Access

### Custom CCP
```bash
# Get CCP URL
terraform output ccp_url
```

Agents can access via this URL with their Connect credentials.

### Default CCP
```bash
# Get instance access URL
terraform output connect_instance_access_url
```

Then append `/ccp-v2` for default CCP.

---

## 🔄 Update Workflow

### Updating Lambda Code
```bash
# Make changes to lambda/bedrock_mcp/lambda_function.py
# Then:
terraform apply -target=null_resource.bedrock_mcp_build
terraform apply -target=module.bedrock_mcp
```

### Adding New Intents
1. Update `terraform.tfvars` with new specialized_intents
2. Add intent handler in Lambda
3. Run: `terraform apply`
4. Bot will rebuild automatically

### Updating Contact Flows
- Automated flows: Update template in `contact_flows/` then `terraform apply`
- BedrockPrimaryFlow: Update directly in Connect console

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Inbound Call/Chat                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              BedrockPrimaryFlow (Manual)                     │
│  ┌──────────────────────────────────────────────┐           │
│  │    Get Customer Input → Lex Bot              │           │
│  │    (connect-comprehensive-bot:prod)          │           │
│  └──────────────────────┬───────────────────────┘           │
└─────────────────────────┼───────────────────────────────────┘
                          │
                          ▼
         ┌────────────────────────────────┐
         │   Lambda: bedrock_mcp          │
         │   (FastMCP + Bedrock)          │
         └────────────────┬───────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
   TransferToAgent   Banking Intent  General Query
          │               │               │
          ▼               ▼               ▼
    Queue Transfer   Banking Bot     Bedrock LLM
                         │               │
                         ▼               ▼
                    Lambda:banking   Response
                         │               │
                         └───────┬───────┘
                                 │
                                 ▼
                        Customer Receives
                           Response
```

---

## ✅ Production Readiness

Before going live:
- [ ] All tests passing
- [ ] Agent transfer working
- [ ] CCP accessible by agents
- [ ] Monitoring dashboards configured
- [ ] Hallucination detection tested
- [ ] Callback functionality verified
- [ ] Load testing performed
- [ ] Disaster recovery plan documented

---

## 📖 Additional Resources

- [COMPREHENSIVE_VALIDATION.md](./COMPREHENSIVE_VALIDATION.md) - Detailed validation guide
- [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md) - Implementation details
- [DEPLOYMENT_READY.md](./DEPLOYMENT_READY.md) - Deployment checklist
- [AWS Connect Documentation](https://docs.aws.amazon.com/connect/)
- [Amazon Lex V2 Documentation](https://docs.aws.amazon.com/lexv2/)
