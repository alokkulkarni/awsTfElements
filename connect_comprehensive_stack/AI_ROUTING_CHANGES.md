# AI-First Routing Implementation Changes

## Overview
Converted the Connect comprehensive stack from hardcoded intent-based routing to AI-first dynamic routing where Lambda/Bedrock determines all routing decisions.

## Date: January 14, 2026

## Changes Made

### 1. Lambda Function Updates (`lambda/bedrock_mcp/lambda_function.py`)

#### `initiate_specialized_bot_transfer()` Function
- **Purpose**: Route calls to specialized bots (Banking/Sales) based on AI-detected intent
- **Changes**:
  - Maps detected intents to `routing_bot` session attribute:
    - Banking intents (CheckBalance, GetStatement, etc.) → `routing_bot=BankingBot`
    - Sales intents (NewProduct, Pricing) → `routing_bot=SalesBot`
  - Returns `dialogAction.type=Close` to end bot interaction
  - Sets `sessionAttributes` at both nested and top-level for Connect compatibility
  - Message: "Connecting you now..."

#### `initiate_agent_handover()` Function
- **Purpose**: Route calls to agent queue when handover needed
- **Changes**:
  - Sets `routing_bot=TransferToAgent` for queue routing
  - Returns `dialogAction.type=Close` to end bot interaction
  - Includes conversation summary and handover reason in session attributes
  - Dynamic queue selection via `determine_target_queue()`

**Latest Version**: 32 (deployed to alias 'live')

### 2. Contact Flow Updates (`contact_flows/BedrockPrimaryFlow.json`)

#### Flow Structure
```
InitialGreeting (Welcome message)
    ↓
GatewayBot (Lex Bot - Main interaction)
    → All input to FallbackIntent → Lambda
    → Lambda returns with routing_bot attribute
    → Bot closes (dialogAction.type=Close)
    ↓
Compare Block (Check $.Lex.SessionAttributes.routing_bot)
    → If "BankingBot" → BankingBot
    → If "SalesBot" → SalesBot
    → If "TransferToAgent" → SetQueueForTransfer
    → Default: Loop to GatewayBot
```

#### Key Configuration
- **GatewayBot Block**:
  - Type: `ConnectParticipantWithLexBot`
  - NextAction: `007908cc-2669-4f33-9ab9-2a530c733beb` (Compare block)
  - Conditions: `[]` (no intent matching - removed all hardcoded intents)
  - Errors: Loop back to GatewayBot

- **Compare Block** (`007908cc-2669-4f33-9ab9-2a530c733beb`):
  - Type: `Compare`
  - ComparisonValue: `$.Lex.SessionAttributes.routing_bot`
  - Conditions:
    - Equals "BankingBot" → Route to BankingBot
    - Equals "SalesBot" → Route to SalesBot
    - Equals "TransferToAgent" → Route to SetQueueForTransfer
  - NoMatchingCondition: Loop to GatewayBot

### 3. Terraform Configuration Updates

#### `main.tf`
- **Uncommented** `aws_connect_contact_flow.bedrock_primary` resource
- Updated description to reflect AI-first routing
- Contact flow now deployed via Terraform using template

#### `outputs.tf`
- **Uncommented** `bedrock_primary_flow_id` output
- Added description: "The ID of the Bedrock Primary contact flow with AI-first routing"

#### `contact_flows/bedrock_primary_flow.json.tftpl`
- **Template Variables**:
  - `${lex_bot_alias_arn}` - Main GatewayBot alias
  - `${lex_bot_banking_alias_arn}` - BankingBot alias
  - `${lex_bot_sales_alias_arn}` - SalesBot alias
  - `${queue_arn}` - GeneralAgentQueue for transfers

### 4. Documentation Updates

#### `README.md`
- Added **AI-First Routing** feature description
- Added **Intelligent Session Management** explanation
- New section: **AI-First Routing Architecture** with detailed flow
- Updated Bedrock MCP Lambda section to include routing_bot attribute

## Architecture Benefits

### 1. **No Hardcoded Intent Matching**
- Contact flows never check intent names
- All routing decisions made by AI in Lambda
- Add new intents without modifying contact flows

### 2. **Context-Aware Routing**
- AI considers full conversation history
- Detects user frustration and adjusts routing
- Can route to agent queue based on conversation context

### 3. **Dynamic Queue Assignment**
- Lambda determines target queue based on:
  - Conversation context
  - Handover reason (frustration, repeated queries, etc.)
  - Customer journey stage

### 4. **Flexible Intent Detection**
- New intents added by updating Lambda prompt
- No Terraform changes needed for new routing rules
- AI learns from conversation patterns

## Testing Performed

### Test Scenario 1: Banking Intent Routing
- **Input**: "I want to check my balance"
- **Lambda Response**: `routing_bot=BankingBot`
- **Contact Flow**: Routes to BankingBot ✅

### Test Scenario 2: Agent Transfer
- **Input**: "I want to speak to an agent"
- **Lambda Response**: `routing_bot=TransferToAgent`
- **Contact Flow**: Routes to SetQueueForTransfer ✅

## Deployment Instructions

### Initial Deployment
```bash
cd connect_comprehensive_stack
terraform init
terraform plan
terraform apply
```

### Update Existing Stack
```bash
# The contact flow will be updated/created by Terraform
terraform apply

# Phone numbers must be associated manually via AWS Console:
# 1. Navigate to Connect Console → Routing → Phone numbers
# 2. Select phone number
# 3. Set Contact Flow to "BedrockPrimaryFlow"
```

## Known Limitations

1. **Phone Number Association**: Must be done manually in console (Terraform doesn't support direct association to contact flow)
2. **Lex Bot Alias Updates**: Bot alias must have Lambda configured at locale level (handled by post-deployment script)
3. **First Call**: May experience slight delay as Lambda cold-starts

## Files Modified

- `lambda/bedrock_mcp/lambda_function.py` - Routing logic
- `contact_flows/BedrockPrimaryFlow.json` - Exported current working flow
- `contact_flows/bedrock_primary_flow.json.tftpl` - Terraform template with variables
- `main.tf` - Uncommented BedrockPrimaryFlow resource
- `outputs.tf` - Uncommented flow ID output
- `README.md` - Added routing architecture documentation

## Next Steps

1. Test end-to-end call flow with all routing scenarios
2. Monitor CloudWatch logs for routing_bot attribute values
3. Add CloudWatch dashboard for routing metrics
4. Document common troubleshooting scenarios
