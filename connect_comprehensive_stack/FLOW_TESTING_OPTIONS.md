# Testing Contact Flows Without Full Stack Deployment

## What Was Fixed in bedrock_primary_flow.json.tftpl

### 1. ✅ All Bots Now Loop to Themselves
- **GatewayBot**: `NextAction: "GatewayBot"` - loops for continuous conversation
- **BankingBot**: `NextAction: "BankingBot"` - loops until transfer or error
- **SalesBot**: `NextAction: "SalesBot"` - loops until transfer or error

### 2. ✅ Two-Step Queue Transfer Pattern
```
SetQueueForTransfer → TransferToQueue
```
- `UpdateContactTargetQueue` sets the queue first
- `TransferContactToQueue` executes without Parameters

### 3. ✅ Intent-Based Routing with ConditionType
All conditions now specify `"ConditionType": "IntentName"` for proper intent routing.

### 4. ✅ Agent Handover Attributes
New `SetHandoverAttributes` action captures:
- `handover_source` - Channel (voice/chat)
- `conversation_summary` - Transfer reason
- `last_intent` - What customer was doing
- `sentiment_score` - Customer sentiment
- `bot_name` - Which bot they were talking to

### 5. ✅ Multi-Bot Architecture Preserved
- Gateway bot routes to Banking/Sales based on intents
- All bots can transfer to agent
- Errors route back to LoopPrompt for recovery

---

## Testing Options Without Full Terraform Deployment

### Option 1: Manual Contact Flow Upload (Fastest)

**Prerequisites:**
- AWS Connect instance (can be a dev/test instance)
- Lex bots deployed (even dummy bots work for structure testing)
- One queue created

**Steps:**
1. Manually replace template variables in the JSON:
   ```bash
   # Create test version
   cp contact_flows/bedrock_primary_flow.json.tftpl test_flow.json
   
   # Replace variables with actual ARNs
   sed -i '' 's|${lex_bot_alias_arn}|arn:aws:lex:eu-west-2:ACCOUNT:bot-alias/BOTID/ALIASID|g' test_flow.json
   sed -i '' 's|${lex_bot_banking_alias_arn}|arn:aws:lex:eu-west-2:ACCOUNT:bot-alias/BANKING_BOTID/ALIASID|g' test_flow.json
   sed -i '' 's|${lex_bot_sales_alias_arn}|arn:aws:lex:eu-west-2:ACCOUNT:bot-alias/SALES_BOTID/ALIASID|g' test_flow.json
   sed -i '' 's|${queue_arn}|arn:aws:connect:eu-west-2:ACCOUNT:instance/INSTANCE_ID/queue/QUEUE_ID|g' test_flow.json
   ```

2. Upload via AWS Console:
   - Go to Connect Console → Routing → Contact Flows
   - Create flow → Import flow (beta)
   - Upload test_flow.json
   - Save and Publish

3. Test in Connect Test Chat or assign to test phone number

**Pros:**
- Fast iteration
- No Terraform state management
- Can test structure immediately

**Cons:**
- Manual ARN replacement
- Not automated
- Must clean up manually

---

### Option 2: Minimal Terraform Stack

Create a minimal test configuration:

```bash
# Create test directory
mkdir -p connect_flow_test
cd connect_flow_test
```

**minimal_test.tf:**
```hcl
variable "region" { default = "eu-west-2" }
variable "connect_instance_id" { default = "YOUR_EXISTING_INSTANCE_ID" }

provider "aws" {
  region = var.region
}

# Use existing resources
data "aws_connect_instance" "test" {
  instance_id = var.connect_instance_id
}

data "aws_connect_queue" "basic" {
  instance_id = data.aws_connect_instance.test.id
  name        = "BasicQueue"  # Use any existing queue
}

# Minimal Lex bot for testing (or use existing)
data "aws_lex_bot_alias" "test" {
  bot_name = "YourExistingBot"
  name     = "TestAlias"
}

# Deploy just the contact flow
resource "aws_connect_contact_flow" "test" {
  instance_id = data.aws_connect_instance.test.id
  name        = "BedrockPrimaryFlow-Test"
  type        = "CONTACT_FLOW"
  content = templatefile("${path.module}/../contact_flows/bedrock_primary_flow.json.tftpl", {
    lex_bot_alias_arn         = data.aws_lex_bot_alias.test.arn
    lex_bot_banking_alias_arn = data.aws_lex_bot_alias.test.arn  # Reuse same bot
    lex_bot_sales_alias_arn   = data.aws_lex_bot_alias.test.arn
    queue_arn                 = data.aws_connect_queue.basic.arn
  })
}

output "flow_id" {
  value = aws_connect_contact_flow.test.contact_flow_id
}
```

**Run:**
```bash
terraform init
terraform plan
terraform apply -auto-approve
```

**Pros:**
- Tests actual template rendering
- Uses real AWS validation
- Quick deploy/destroy cycle
- No full stack needed

**Cons:**
- Requires existing Connect instance
- Requires at least one Lex bot

---

### Option 3: AWS CLI Validation (Structure Only)

Test JSON structure without deploying:

```bash
# 1. Render template locally
python3 << 'EOF'
import json
import sys

# Read template
with open('contact_flows/bedrock_primary_flow.json.tftpl', 'r') as f:
    content = f.read()

# Replace with dummy ARNs for validation
replacements = {
    '${lex_bot_alias_arn}': 'arn:aws:lex:eu-west-2:123456789012:bot-alias/BOT1/ALIAS1',
    '${lex_bot_banking_alias_arn}': 'arn:aws:lex:eu-west-2:123456789012:bot-alias/BOT2/ALIAS2',
    '${lex_bot_sales_alias_arn}': 'arn:aws:lex:eu-west-2:123456789012:bot-alias/BOT3/ALIAS3',
    '${queue_arn}': 'arn:aws:connect:eu-west-2:123456789012:instance/INST/queue/QUEUE'
}

for key, value in replacements.items():
    content = content.replace(key, value)

# Validate JSON
try:
    parsed = json.loads(content)
    print(json.dumps(parsed, indent=2))
    sys.exit(0)
except json.JSONDecodeError as e:
    print(f"JSON Error: {e}", file=sys.stderr)
    sys.exit(1)
EOF
```

**Validate structure:**
```bash
# Check for required fields
jq -e '.Version, .StartAction, .Actions' rendered_flow.json

# Check all actions have required fields
jq '.Actions[] | select(.Identifier == null or .Type == null)' rendered_flow.json

# Verify TransferContactToQueue has no Parameters
jq '.Actions[] | select(.Type == "TransferContactToQueue" and .Parameters != {})' rendered_flow.json
```

**Pros:**
- No AWS resources needed
- Fast validation
- Can test on laptop

**Cons:**
- Doesn't validate against AWS API
- Won't catch AWS-specific errors

---

### Option 4: Connect Test Chat (UI Testing)

Once flow is deployed (any method):

1. **Enable Test Chat:**
   - Connect Console → Dashboard
   - Test Settings → Enable test chat

2. **Test Flow:**
   - Open test chat
   - Type messages to trigger intents
   - Watch flow execution in real-time
   - View flow logs for debugging

3. **Test Scenarios:**
   ```
   User: "Hello" 
   → Gateway bot greeting
   
   User: "Check my balance"
   → Routes to BankingBot
   
   User: "I need to speak to an agent"
   → TransferToAgent intent
   → Sets attributes
   → Updates queue
   → Transfers
   ```

4. **Check Attributes:**
   - View contact attributes in Contact Details
   - Verify handover_source, sentiment_score, etc.

**Pros:**
- Tests real user experience
- Visual flow debugging
- See actual bot responses

**Cons:**
- Requires deployed flow
- Manual testing

---

### Option 5: Terraform Plan Check (Pre-Deploy Validation)

Safest option before full deployment:

```bash
# In connect_comprehensive_stack directory

# 1. Comment out all resources except flow
# (Keep: module.connect_instance, aws_connect_queue, flow resource)

# 2. Run plan
terraform plan -target=aws_connect_contact_flow.bedrock_primary

# 3. Check plan output for:
# - Template rendering errors
# - JSON validation issues
# - Missing variable values

# 4. If plan succeeds, apply just the flow
terraform apply -target=aws_connect_contact_flow.bedrock_primary -auto-approve

# 5. Test via phone number or test chat

# 6. Destroy when done
terraform destroy -target=aws_connect_contact_flow.bedrock_primary -auto-approve
```

**Pros:**
- Uses existing main.tf
- Terraform validates template
- Can target specific resources
- Easy rollback

**Cons:**
- Still needs Connect instance
- More complex than minimal stack

---

## Recommended Testing Sequence

1. **First**: JSON validation (Option 3) - catch syntax errors
2. **Second**: Minimal Terraform (Option 2) - validate AWS accepts it
3. **Third**: Test Chat (Option 4) - test user experience
4. **Fourth**: Full deployment - integrate with complete stack

---

## Key Validation Checkpoints

### ✅ Structure Validation
- [ ] JSON is valid
- [ ] All Actions have Identifier, Type, Transitions
- [ ] StartAction references valid action
- [ ] All NextAction references exist

### ✅ AWS Connect Requirements
- [ ] TransferContactToQueue has empty Parameters: {}
- [ ] UpdateContactTargetQueue comes before TransferContactToQueue
- [ ] Lex bots loop to themselves (NextAction = own Identifier)
- [ ] IntentName conditions have ConditionType specified

### ✅ Multi-Bot Flow
- [ ] Gateway routes to Banking on banking intents
- [ ] Gateway routes to Sales on sales intents
- [ ] All bots can transfer to agent
- [ ] Errors route to LoopPrompt for recovery

### ✅ Agent Handover
- [ ] SetHandoverAttributes captures required data
- [ ] Attributes flow to agent workspace
- [ ] Queue set before transfer
- [ ] Transfer handles QueueAtCapacity error

---

## Troubleshooting Common Issues

### Issue: "InvalidContactFlowException"
**Cause:** Missing ConditionType or wrong action structure
**Fix:** Check all Conditions have ConditionType: "IntentName"

### Issue: "Contact flow validation failed"
**Cause:** TransferContactToQueue has Parameters
**Fix:** Parameters should be empty {}, queue set by UpdateContactTargetQueue

### Issue: Bot doesn't loop
**Cause:** NextAction points to different action
**Fix:** Lex bot NextAction should be same as Identifier

### Issue: Attributes not visible to agent
**Cause:** UpdateContactAttributes comes after transfer
**Fix:** SetHandoverAttributes must come BEFORE UpdateContactTargetQueue

---

## Quick Test Commands

```bash
# Validate JSON syntax
jq empty contact_flows/bedrock_primary_flow.json.tftpl

# Check for Parameters in TransferContactToQueue
jq '.Actions[] | select(.Type == "TransferContactToQueue") | .Parameters' contact_flows/bedrock_primary_flow.json.tftpl

# Verify bot self-loops
jq '.Actions[] | select(.Type == "ConnectParticipantWithLexBot") | {id: .Identifier, next: .Transitions.NextAction}' contact_flows/bedrock_primary_flow.json.tftpl

# Count IntentName conditions
jq '[.Actions[] | .Transitions.Conditions[]? | select(.ConditionType == "IntentName")] | length' contact_flows/bedrock_primary_flow.json.tftpl
```

---

## Summary

**For quick structure testing**: Use Option 3 (CLI validation)
**For AWS validation**: Use Option 2 (Minimal Terraform)
**For user experience testing**: Use Option 4 (Test Chat)
**For production readiness**: Use Option 5 (Targeted deployment)

The fixed flow now properly handles multi-bot routing, agent transfers with context, and follows AWS Connect's strict structural requirements.
