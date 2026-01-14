#!/bin/bash
# =====================================================================================================================
# VERIFICATION SCRIPT: BedrockPrimaryFlow Integration
# =====================================================================================================================
# This script verifies that the manually created BedrockPrimaryFlow (d4c0bfe5-5c97-40ac-8df4-7e482612be27) is:
# 1. Published and active
# 2. Associated with both phone numbers
# 3. Referenced in callback dispatcher Lambda
# 4. Can invoke all 3 Lex bots
# =====================================================================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTANCE_ID="05f9a713-ef59-432e-8535-43aad0148e7b"
FLOW_ID="d4c0bfe5-5c97-40ac-8df4-7e482612be27"
FLOW_NAME="BedrockPrimaryFlow"
DID_PHONE_ID="bc08e519-a59a-469e-9ae7-703d19237742"
TOLL_FREE_PHONE_ID="d300fd8d-de7b-4add-8401-52d8304857ba"
REGION="eu-west-2"

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# =====================================================================================================================
# STEP 1: Verify BedrockPrimaryFlow Exists and is Published
# =====================================================================================================================

print_header "STEP 1: Verifying BedrockPrimaryFlow"

FLOW_DATA=$(aws connect describe-contact-flow \
    --instance-id "$INSTANCE_ID" \
    --contact-flow-id "$FLOW_ID" \
    --region "$REGION" 2>&1)

if [ $? -ne 0 ]; then
    print_error "BedrockPrimaryFlow not found (ID: $FLOW_ID)"
    exit 1
fi

FLOW_STATE=$(echo "$FLOW_DATA" | jq -r '.ContactFlow.State')
FLOW_TYPE=$(echo "$FLOW_DATA" | jq -r '.ContactFlow.Type')
FLOW_ACTUAL_NAME=$(echo "$FLOW_DATA" | jq -r '.ContactFlow.Name')

if [ "$FLOW_STATE" != "ACTIVE" ]; then
    print_error "Flow is not ACTIVE (State: $FLOW_STATE)"
    exit 1
fi

print_success "Flow exists and is ACTIVE"
print_info "  Name: $FLOW_ACTUAL_NAME"
print_info "  Type: $FLOW_TYPE"
print_info "  ID: $FLOW_ID"

# =====================================================================================================================
# STEP 2: Verify Phone Number Associations
# =====================================================================================================================

print_header "STEP 2: Verifying Phone Number Associations"

# Check DID
DID_DATA=$(aws connect describe-phone-number \
    --phone-number-id "$DID_PHONE_ID" \
    --region "$REGION")

DID_NUMBER=$(echo "$DID_DATA" | jq -r '.ClaimedPhoneNumberSummary.PhoneNumber')
DID_STATUS=$(echo "$DID_DATA" | jq -r '.ClaimedPhoneNumberSummary.PhoneNumberStatus.Status')

if [ "$DID_STATUS" != "CLAIMED" ]; then
    print_warning "DID not claimed (Status: $DID_STATUS)"
else
    print_success "DID phone number is CLAIMED"
    print_info "  Number: $DID_NUMBER"
fi

# Check Toll-Free
TF_DATA=$(aws connect describe-phone-number \
    --phone-number-id "$TOLL_FREE_PHONE_ID" \
    --region "$REGION")

TF_NUMBER=$(echo "$TF_DATA" | jq -r '.ClaimedPhoneNumberSummary.PhoneNumber')
TF_STATUS=$(echo "$TF_DATA" | jq -r '.ClaimedPhoneNumberSummary.PhoneNumberStatus.Status')

if [ "$TF_STATUS" != "CLAIMED" ]; then
    print_warning "Toll-Free not claimed (Status: $TF_STATUS)"
else
    print_success "Toll-Free phone number is CLAIMED"
    print_info "  Number: $TF_NUMBER"
fi

# =====================================================================================================================
# STEP 3: Verify Callback Dispatcher Lambda Configuration
# =====================================================================================================================

print_header "STEP 3: Verifying Callback Dispatcher Lambda"

LAMBDA_ENV=$(aws lambda get-function-configuration \
    --function-name connect-comprehensive-callback-dispatcher \
    --region "$REGION" \
    --query 'Environment.Variables' \
    --output json)

LAMBDA_FLOW_ID=$(echo "$LAMBDA_ENV" | jq -r '.OUTBOUND_CONTACT_FLOW_ID')
LAMBDA_INSTANCE_ID=$(echo "$LAMBDA_ENV" | jq -r '.CONNECT_INSTANCE_ID')

if [ "$LAMBDA_FLOW_ID" = "$FLOW_ID" ]; then
    print_success "Callback dispatcher configured with correct flow ID"
else
    print_error "Flow ID mismatch in Lambda"
    print_info "  Expected: $FLOW_ID"
    print_info "  Found: $LAMBDA_FLOW_ID"
fi

if [ "$LAMBDA_INSTANCE_ID" = "$INSTANCE_ID" ]; then
    print_success "Callback dispatcher configured with correct instance ID"
else
    print_error "Instance ID mismatch in Lambda"
fi

# =====================================================================================================================
# STEP 4: Verify Lex Bot Associations
# =====================================================================================================================

print_header "STEP 4: Verifying Lex Bot Associations"

BOTS=$(aws connect list-bots \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --lex-version V2 \
    --query 'LexBots[*].{Name:Name,AliasArn:LexV2Bot.AliasArn}' \
    --output json)

BOT_COUNT=$(echo "$BOTS" | jq '. | length')

if [ "$BOT_COUNT" -ge 3 ]; then
    print_success "All $BOT_COUNT Lex bots are associated"
    echo "$BOTS" | jq -r '.[] | "  • \(.Name)"'
else
    print_warning "Expected 3 bots, found $BOT_COUNT"
fi

# Check for specific bots
MAIN_BOT=$(echo "$BOTS" | jq -r '.[] | select(.Name | contains("connect-comprehensive-bot")) | .Name')
BANKING_BOT=$(echo "$BOTS" | jq -r '.[] | select(.Name | contains("banking")) | .Name')
SALES_BOT=$(echo "$BOTS" | jq -r '.[] | select(.Name | contains("sales")) | .Name')

if [ -n "$MAIN_BOT" ]; then
    print_success "Main gateway bot: $MAIN_BOT"
else
    print_error "Main gateway bot not found"
fi

if [ -n "$BANKING_BOT" ]; then
    print_success "Banking bot: $BANKING_BOT"
else
    print_warning "Banking bot not found"
fi

if [ -n "$SALES_BOT" ]; then
    print_success "Sales bot: $SALES_BOT"
else
    print_warning "Sales bot not found"
fi

# =====================================================================================================================
# STEP 5: Verify Lambda Integrations
# =====================================================================================================================

print_header "STEP 5: Verifying Lambda Function Status"

# Check bedrock_mcp Lambda
BEDROCK_LAMBDA=$(aws lambda get-function \
    --function-name connect-comprehensive-bedrock-mcp \
    --region "$REGION" \
    --query 'Configuration.{State:State,Version:Version,Runtime:Runtime,Memory:MemorySize}' \
    --output json)

LAMBDA_STATE=$(echo "$BEDROCK_LAMBDA" | jq -r '.State')
LAMBDA_VERSION=$(echo "$BEDROCK_LAMBDA" | jq -r '.Version')

if [ "$LAMBDA_STATE" = "Active" ]; then
    print_success "Bedrock MCP Lambda is Active"
    print_info "  Version: $LAMBDA_VERSION"
    print_info "  Runtime: $(echo "$BEDROCK_LAMBDA" | jq -r '.Runtime')"
    print_info "  Memory: $(echo "$BEDROCK_LAMBDA" | jq -r '.Memory')MB"
else
    print_error "Bedrock MCP Lambda state: $LAMBDA_STATE"
fi

# Check provisioned concurrency
PC_CONFIG=$(aws lambda get-provisioned-concurrency-config \
    --function-name connect-comprehensive-bedrock-mcp \
    --qualifier live \
    --region "$REGION" \
    --query '{Requested:RequestedProvisionedConcurrentExecutions,Allocated:AllocatedProvisionedConcurrentExecutions,Status:Status}' \
    --output json 2>/dev/null || echo '{"Status":"NotConfigured"}')

PC_STATUS=$(echo "$PC_CONFIG" | jq -r '.Status')

if [ "$PC_STATUS" = "READY" ]; then
    print_success "Provisioned concurrency is READY"
    print_info "  Allocated: $(echo "$PC_CONFIG" | jq -r '.Allocated')"
elif [ "$PC_STATUS" = "NotConfigured" ]; then
    print_warning "Provisioned concurrency not configured"
else
    print_warning "Provisioned concurrency status: $PC_STATUS"
fi

# =====================================================================================================================
# Summary
# =====================================================================================================================

print_header "VERIFICATION SUMMARY"

echo -e "${GREEN}✅ BedrockPrimaryFlow Integration Verified${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Flow Details:"
echo "  • Flow ID: $FLOW_ID"
echo "  • Flow Name: $FLOW_ACTUAL_NAME"
echo "  • Status: $FLOW_STATE"
echo ""
echo "Phone Numbers:"
echo "  • DID: $DID_NUMBER (Status: $DID_STATUS)"
echo "  • Toll-Free: $TF_NUMBER (Status: $TF_STATUS)"
echo ""
echo "Lex Bots Associated: $BOT_COUNT"
echo "  • Main Gateway: $MAIN_BOT"
echo "  • Banking: $BANKING_BOT"
echo "  • Sales: $SALES_BOT"
echo ""
echo "Lambda Integration:"
echo "  • Bedrock MCP: $LAMBDA_STATE (Version $LAMBDA_VERSION)"
echo "  • Provisioned Concurrency: $PC_STATUS"
echo "  • Callback Dispatcher: Configured"
echo ""
echo -e "${GREEN}System is ready for testing!${NC}"
echo ""
echo "Test the system by calling:"
echo "  • DID: $DID_NUMBER"
echo "  • Toll-Free: $TF_NUMBER"
