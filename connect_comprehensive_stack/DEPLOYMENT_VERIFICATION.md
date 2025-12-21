# Deployment Verification Guide - Bedrock Primary Flow Stack

## Overview
This document verifies that when deploying the stack, all components are properly configured:
1. **BedrockPrimaryFlow** is deployed as the DEFAULT contact flow
2. **All required Lex intents** are created and associated
3. **Phone numbers** are associated with the correct flow

---

## 1. Contact Flow Deployment

### Primary Contact Flow: BedrockPrimaryFlow ✅
- **Resource**: `aws_connect_contact_flow.bedrock_primary`
- **Template**: `contact_flows/bedrock_primary_flow_fixed.json.tftpl`
- **Associated With**: Both inbound phone numbers (DID and Toll-Free)
- **Status**: PRIMARY FLOW FOR ALL INBOUND CALLS

#### Flow Logic:
```
Inbound Call (DID or Toll-Free)
    ↓
BedrockPrimaryFlow
    ↓
Greet Customer: "Hello! Welcome to our banking service..."
    ↓
Connect to Lex Bot (en_GB locale)
    ↓
Lambda Fulfillment (bedrock-mcp)
    ├─ Process input with Bedrock (Claude 3.5 Sonnet)
    └─ Return response with intent
        ├─ ChatIntent → Continue conversation
        └─ TransferToAgent → Route to agent queue
    ↓
Loop or Transfer
```

### Configuration Parameters:
- **Lex Bot Alias ARN**: `awscc_lex_bot_alias.this.arn`
- **Queue ARN**: `aws_connect_queue.queues["GeneralAgentQueue"].arn`

---

## 2. Lex Bot Intent Deployment

### Bot Structure
- **Bot ID**: AZZCDGTN2I (connect-comprehensive-bot)
- **Bot Alias**: prod
- **Alias Version**: Latest created by stack

### Intents Created

#### Locale: en_GB (Primary)
| Intent | Type | Fulfillment | Created By | Status |
|--------|------|-------------|-----------|--------|
| ChatIntent | User-defined | Lambda | Module | ✅ Created |
| TransferToAgent | System | None | Explicit | ✅ Created |

#### Locale: en_US (Secondary)
| Intent | Type | Fulfillment | Created By | Status |
|--------|------|-------------|-----------|--------|
| ChatIntent | User-defined | Lambda | Explicit | ✅ Created |
| TransferToAgent | System | None | Explicit | ✅ Created |

### Intent Details

#### ChatIntent (Both Locales)
- **Purpose**: Handles user input for conversation
- **Fulfillment**: Lambda code hook enabled
- **Lambda**: `bedrock-mcp` (Bedrock fulfillment)
- **Sample Utterances**:
  - "Hi"
  - "Hello"
  - "I need help"

#### TransferToAgent (Both Locales)
- **Purpose**: Signal agent transfer from Lambda
- **Fulfillment**: Disabled (returned by Lambda only)
- **Contact Flow Handling**: 
  - Contact flow checks intent name
  - If "TransferToAgent" → transfer to GeneralAgentQueue
  - Otherwise → continue bot conversation

---

## 3. Deployment Sequence & Dependencies

### Step-by-Step Execution Order:

```
1. Create Lex Bot
   └─ module.lex_bot
      ├─ Creates bot shell
      ├─ Creates en_GB locale
      ├─ Creates ChatIntent for en_GB
      └─ Creates IAM role for Lex

2. Create en_US Locale
   └─ aws_lexv2models_bot_locale.en_us
      └─ Depends on: module.lex_bot

3. Create ChatIntent for en_US
   └─ aws_lexv2models_intent.chat_en_us
      └─ Depends on: aws_lexv2models_bot_locale.en_us

4. Create TransferToAgent Intent for en_GB
   └─ aws_lexv2models_intent.transfer_to_agent_en_gb
      └─ Depends on: module.lex_bot

5. Create TransferToAgent Intent for en_US
   └─ aws_lexv2models_intent.transfer_to_agent_en_us
      └─ Depends on: aws_lexv2models_bot_locale.en_us

6. Build Bot Locales (AWS CLI)
   └─ null_resource.build_bot_locales
      ├─ Depends on: All intents created in steps 1-5
      ├─ Executes: aws lexv2-models build-bot-locale for en_GB
      ├─ Executes: aws lexv2-models build-bot-locale for en_US
      └─ Waits for both locales to reach "Built" status

7. Create Bot Version
   └─ aws_lexv2models_bot_version.this
      ├─ Depends on: null_resource.build_bot_locales
      ├─ Captures: All intents at point in time
      └─ Creates: Immutable version snapshot

8. Create Bot Alias
   └─ awscc_lex_bot_alias.this
      ├─ Name: "prod"
      ├─ Points to: Latest bot version
      ├─ Configuration:
      │  ├─ Lambda code hooks for en_GB
      │  ├─ Lambda code hooks for en_US
      │  └─ Conversation logs enabled
      └─ Depends on: aws_lexv2models_bot_version.this

9. Create Contact Flows
   ├─ aws_connect_contact_flow.bedrock_primary (DEFAULT)
   ├─ aws_connect_contact_flow.voice_entry
   ├─ aws_connect_contact_flow.chat_entry
   └─ Depends on: awscc_lex_bot_alias.this

10. Associate Phone Numbers
    └─ null_resource.associate_phone_numbers
       ├─ Associates DID to BedrockPrimaryFlow
       ├─ Associates Toll-Free to BedrockPrimaryFlow
       └─ Depends on: aws_connect_contact_flow.bedrock_primary
```

---

## 4. Verification Checklist

### Pre-Deployment
- [ ] All Terraform files syntax validated: `terraform validate`
- [ ] Plan reviewed: `terraform plan`
- [ ] Lambda code deployed and tested
- [ ] Contact flow template exists: `contact_flows/bedrock_primary_flow_fixed.json.tftpl`

### Post-Deployment Verification

#### A. Lex Bot Verification
```bash
# Check bot exists
aws lexv2-models describe-bot --bot-id AZZCDGTN2I --region eu-west-2

# List all intents for en_GB
aws lexv2-models list-intents --bot-id AZZCDGTN2I --bot-version DRAFT --locale-id en_GB --region eu-west-2

# List all intents for en_US
aws lexv2-models list-intents --bot-id AZZCDGTN2I --bot-version DRAFT --locale-id en_US --region eu-west-2

# Verify ChatIntent exists in en_GB
aws lexv2-models describe-intent --intent-id <INTENT_ID> --bot-id AZZCDGTN2I --bot-version DRAFT --locale-id en_GB --region eu-west-2

# Verify TransferToAgent exists in en_GB
aws lexv2-models describe-intent --intent-id <INTENT_ID> --bot-id AZZCDGTN2I --bot-version DRAFT --locale-id en_GB --region eu-west-2
```

#### B. Contact Flow Verification
```bash
# Check BedrockPrimaryFlow exists and is active
aws connect describe-contact-flow --instance-id <INSTANCE_ID> --contact-flow-id <FLOW_ID> --region eu-west-2

# Verify phone number association
aws connect describe-phone-number --instance-id <INSTANCE_ID> --phone-number-id <PHONE_ID> --region eu-west-2
# Should show: "TargetArn": "arn:aws:connect:eu-west-2:ACCOUNT:instance/INSTANCE/contact-flow/FLOW_ID"
```

#### C. Phone Number Verification
```bash
# Check DID association
aws connect describe-phone-number --instance-id <INSTANCE_ID> --phone-number-id <DID_ID> --region eu-west-2

# Check Toll-Free association  
aws connect describe-phone-number --instance-id <INSTANCE_ID> --phone-number-id <TOLL_FREE_ID> --region eu-west-2

# Expected output shows contact flow ID matches BedrockPrimaryFlow
```

#### D. Test Call Flow
1. **Call DID Number**: +442046321768
2. **Expected Behavior**:
   - ✅ Call connects to BedrockPrimaryFlow
   - ✅ Greeting plays: "Hello! Welcome to our banking service..."
   - ✅ Lex bot connects (en_GB locale)
   - ✅ Lambda processes input with Bedrock
   - ✅ Bot responds with conversational AI
   - ✅ Say "transfer" or "agent" → transfers to agent queue
   - ✅ Otherwise → continues conversation

---

## 5. Key Configuration Files

### Main Terraform
- **File**: `main.tf`
- **Lines**: See inline comments for:
  - Lines 645-680: Lex bot configuration
  - Lines 675-730: Intent definitions
  - Lines 751-850: Build bot locales
  - Lines 851-870: Bot version creation
  - Lines 892-970: Bot alias creation
  - Lines 75-107: Phone number association
  - Lines 1388-1420: BedrockPrimaryFlow definition

### Contact Flow Template
- **File**: `contact_flows/bedrock_primary_flow_fixed.json.tftpl`
- **Variables Substituted**:
  - `${lex_bot_alias_arn}`: Bot alias ARN (e.g., `prod` version)
  - `${queue_arn}`: General Agent Queue ARN

### Lambda Function
- **File**: `lambda/bedrock_mcp/lambda_function.py`
- **Role**: Fulfillment for both ChatIntent and TransferToAgent
- **Returns**:
  - When conversational: `sessionState.intent.name = "ChatIntent"`
  - When agent needed: `sessionState.intent.name = "TransferToAgent"`

---

## 6. Deployment Command

```bash
cd connect_comprehensive_stack

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan

# Deploy stack
terraform apply -auto-approve

# Verify deployment
terraform output
```

---

## 7. Important Notes

### Intent Dependencies
- **All intents must exist BEFORE building locales**
  - Build fails if intents don't exist
  - Terraform wait loops ensure proper sequencing
  
### Contact Flow Condition
- The BedrockPrimaryFlow uses a condition to check intent:
  ```json
  {
    "ConditionType": "IntentName",
    "Operands": ["TransferToAgent"]
  }
  ```
- Only "TransferToAgent" intent triggers transfer
- All other intents (like "ChatIntent") continue the conversation

### Lambda Return Values
- Lambda MUST return intent name in `sessionState.intent.name`
- Contact flow checks this exact value
- Proper case sensitivity is critical

### Phone Number Association
- Both phone numbers (DID and Toll-Free) point to same flow
- Change can be made by modifying terraform and re-applying
- Association is bidirectional - removing flow removes association

---

## 8. Rollback & Recovery

### If Deployment Fails
```bash
# View error logs
terraform output

# Review AWS Connect logs
aws logs tail /aws/connect/bedrock-primary-flow --follow

# Review Lex logs
aws logs tail /aws/lex/connect-comprehensive-bot --follow

# Check Lambda invocation
aws logs tail /aws/lambda/connect-comprehensive-bedrock-mcp --follow
```

### To Rollback
```bash
# Destroy entire stack
terraform destroy -auto-approve

# Or manually update phone associations
aws connect associate-phone-number-contact-flow \
  --instance-id <INSTANCE_ID> \
  --phone-number-id <PHONE_ID> \
  --contact-flow-id <OLD_FLOW_ID> \
  --region eu-west-2
```

---

## 9. Support & Debugging

### Common Issues

**Issue**: Phone number still directs to agent
- [ ] Verify phone association with correct flow
- [ ] Verify contact flow is ACTIVE
- [ ] Verify Lex bot alias is correctly configured
- [ ] Check Lambda logs for errors

**Issue**: Intents not found
- [ ] Verify build-bot-locale completed successfully
- [ ] Check Lex bot version was created
- [ ] Verify alias points to correct version

**Issue**: Lambda not responding
- [ ] Verify Lambda has Bedrock invoke permissions
- [ ] Check Lambda logs for errors
- [ ] Verify environment variables are set

---

**Document Version**: 1.0  
**Last Updated**: 2025-12-21  
**Stack**: connect_comprehensive_stack  
**Status**: ✅ Ready for Deployment
