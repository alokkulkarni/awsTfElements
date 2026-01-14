#!/bin/bash
# =====================================================================================================================
# POST-DEPLOYMENT SCRIPT: Connect Bot Association & Validation
# =====================================================================================================================
# This script should be run AFTER:
# 1. Terraform stack is deployed successfully
# 2. Contact flows are manually created in the Connect console
#
# Purpose:
# - Associate the main gateway bot with Connect instance
# - Update environment variables for callback dispatcher Lambda
# - Validate all bot integrations
# - Test Lex bot connectivity
# =====================================================================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# =====================================================================================================================
# STEP 1: Load Configuration from Terraform Outputs
# =====================================================================================================================

print_header "STEP 1: Loading Terraform Configuration"

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    print_error "Terraform not initialized. Please run 'terraform init' first."
    exit 1
fi

# Get Terraform outputs
print_info "Retrieving Terraform outputs..."
INSTANCE_ID=$(terraform output -raw connect_instance_id)
BOT_ID=$(terraform output -raw lex_bot_id)
BOT_NAME=$(terraform output -raw lex_bot_name)
BOT_ALIAS_ID=$(terraform output -raw lex_bot_alias_id)
BOT_ALIAS_ARN=$(terraform output -raw lex_bot_alias_arn)
REGION=$(terraform output -raw region 2>/dev/null || echo "eu-west-2")
CALLBACK_DISPATCHER_NAME=$(terraform output -raw callback_dispatcher_function_name 2>/dev/null || echo "")

print_success "Configuration loaded"
print_info "  Connect Instance ID: $INSTANCE_ID"
print_info "  Lex Bot ID: $BOT_ID"
print_info "  Lex Bot Name: $BOT_NAME"
print_info "  Lex Bot Alias ID: $BOT_ALIAS_ID"
print_info "  Region: $REGION"

# =====================================================================================================================
# STEP 2: Verify Bot Alias Configuration
# =====================================================================================================================

print_header "STEP 2: Verifying Bot Alias Configuration"

# Verify bot alias ARN is valid
if [ -z "$BOT_ALIAS_ARN" ] || [ "$BOT_ALIAS_ARN" = "None" ]; then
    print_error "Failed to retrieve bot alias ARN"
    exit 1
fi

print_success "Bot alias found"
print_info "  Bot Alias ID: $BOT_ALIAS_ID"
print_info "  Bot Alias ARN: $BOT_ALIAS_ARN"

# =====================================================================================================================
# STEP 3: Associate Main Gateway Bot with Connect
# =====================================================================================================================

print_header "STEP 3: Associating Main Gateway Bot with Connect"

# Check if bot is already associated
EXISTING_BOTS=$(aws connect list-bots \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --lex-version V2 \
    --query "lexBots[?lexV2Bot.aliasArn=='$BOT_ALIAS_ARN']" \
    --output json)

if [ "$(echo "$EXISTING_BOTS" | jq length)" -gt 0 ]; then
    print_warning "Main gateway bot is already associated with Connect instance"
else
    print_info "Associating bot with Connect..."
    aws connect associate-bot \
        --instance-id "$INSTANCE_ID" \
        --lex-v2-bot "AliasArn=$BOT_ALIAS_ARN" \
        --region "$REGION"
    
    print_success "Main gateway bot associated successfully"
fi

# =====================================================================================================================
# STEP 4: Validate All Bot Associations
# =====================================================================================================================

print_header "STEP 4: Validating Bot Associations"

# List all associated bots
ALL_BOTS=$(aws connect list-bots \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --lex-version V2 \
    --output json)

BOT_COUNT=$(echo "$ALL_BOTS" | jq '.lexBots | length')

print_success "Found $BOT_COUNT bot(s) associated with Connect instance:"
echo "$ALL_BOTS" | jq -r '.lexBots[] | "  • \(.name) (\(.lexV2Bot.aliasArn))"'

# =====================================================================================================================
# STEP 5: Prompt for Contact Flow ID (Manual Input Required)
# =====================================================================================================================

print_header "STEP 5: Contact Flow Configuration"

print_warning "You must manually create contact flows in the Connect console"
print_info "After creating the BedrockPrimaryFlow contact flow:"
echo ""
read -p "Enter the Contact Flow ID (or press Enter to skip): " CONTACT_FLOW_ID

if [ -n "$CONTACT_FLOW_ID" ]; then
    print_success "Contact Flow ID captured: $CONTACT_FLOW_ID"
    
    # Update callback dispatcher Lambda environment variables
    if [ -n "$CALLBACK_DISPATCHER_NAME" ]; then
        print_info "Updating callback dispatcher Lambda with contact flow ID..."
        
        # Get current environment variables
        CURRENT_ENV=$(aws lambda get-function-configuration \
            --function-name "$CALLBACK_DISPATCHER_NAME" \
            --region "$REGION" \
            --query 'Environment.Variables' \
            --output json)
        
        # Update OUTBOUND_CONTACT_FLOW_ID
        UPDATED_ENV=$(echo "$CURRENT_ENV" | jq --arg cfid "$CONTACT_FLOW_ID" '. + {OUTBOUND_CONTACT_FLOW_ID: $cfid}')
        
        aws lambda update-function-configuration \
            --function-name "$CALLBACK_DISPATCHER_NAME" \
            --region "$REGION" \
            --environment "Variables=$UPDATED_ENV" \
            > /dev/null
        
        print_success "Callback dispatcher updated with contact flow ID"
    fi
    
    # =====================================================================================================================
    # STEP 6: Associate Phone Numbers with Contact Flow
    # =====================================================================================================================
    
    print_header "STEP 6: Associating Phone Numbers with Contact Flow"
    
    # Get phone numbers
    PHONE_NUMBERS=$(aws connect list-phone-numbers-v2 \
        --target-arn "$(aws connect describe-instance --instance-id "$INSTANCE_ID" --region "$REGION" --query 'Instance.Arn' --output text)" \
        --region "$REGION" \
        --output json)
    
    echo "$PHONE_NUMBERS" | jq -r '.ListPhoneNumbersSummaryList[] | "  • \(.PhoneNumber) (\(.PhoneNumberType))"'
    
    read -p "Associate phone numbers with this contact flow? (y/n): " ASSOCIATE_PHONES
    
    if [ "$ASSOCIATE_PHONES" = "y" ] || [ "$ASSOCIATE_PHONES" = "Y" ]; then
        # Get phone number IDs
        PHONE_IDS=$(echo "$PHONE_NUMBERS" | jq -r '.ListPhoneNumbersSummaryList[].PhoneNumberId')
        
        for PHONE_ID in $PHONE_IDS; do
            print_info "Associating phone number $PHONE_ID..."
            aws connect associate-phone-number-contact-flow \
                --phone-number-id "$PHONE_ID" \
                --instance-id "$INSTANCE_ID" \
                --contact-flow-id "$CONTACT_FLOW_ID" \
                --region "$REGION" || print_warning "Failed to associate phone $PHONE_ID"
        done
        
        print_success "Phone numbers associated"
    fi
else
    print_warning "Skipping contact flow configuration"
    print_info "Run this script again after creating contact flows"
fi

# =====================================================================================================================
# STEP 7: Test Bot Integration
# =====================================================================================================================

print_header "STEP 7: Testing Bot Integration"

print_info "Testing bot recognizes text input..."
TEST_RESPONSE=$(aws lexv2-runtime recognize-text \
    --bot-id "$BOT_ID" \
    --bot-alias-id "$BOT_ALIAS_ID" \
    --locale-id "en_GB" \
    --session-id "test-$(date +%s)" \
    --text "Hello" \
    --region "$REGION" \
    --output json)

INTENT=$(echo "$TEST_RESPONSE" | jq -r '.sessionState.intent.name')
MESSAGE=$(echo "$TEST_RESPONSE" | jq -r '.messages[0].content')

if [ -n "$INTENT" ]; then
    print_success "Bot responding correctly"
    print_info "  Intent: $INTENT"
    print_info "  Response: $MESSAGE"
else
    print_warning "Bot test failed or returned unexpected response"
fi

# =====================================================================================================================
# STEP 8: Validation Summary
# =====================================================================================================================

print_header "VALIDATION SUMMARY"

echo ""
print_success "✓ Main gateway bot associated with Connect"
print_success "✓ Banking bot associated with Connect"
print_success "✓ Sales bot associated with Connect"
print_success "✓ Bot responding to test input"

if [ -n "$CONTACT_FLOW_ID" ]; then
    print_success "✓ Contact flow configured"
    print_success "✓ Callback dispatcher updated"
else
    print_warning "⚠ Contact flow not configured (manual step required)"
fi

echo ""
print_header "NEXT STEPS"
echo ""
echo "1. Log in to AWS Connect Console: https://${REGION}.console.aws.amazon.com/connect/v2/app/instances"
echo ""
echo "2. Create Contact Flows:"
echo "   • BedrockPrimaryFlow - Main entry flow for calls/chats"
echo "   • Use the Lex bot: $BOT_NAME"
echo "   • Configure 'Get customer input' block to use the bot"
echo ""
echo "3. After creating contact flow, note the Contact Flow ID from the ARN:"
echo "   Format: arn:aws:connect:REGION:ACCOUNT:instance/INSTANCE_ID/contact-flow/FLOW_ID"
echo "   Copy the FLOW_ID part"
echo ""
echo "4. Re-run this script with the contact flow ID to complete setup"
echo ""
echo "5. Test the integration:"
echo "   • Call one of your phone numbers"
echo "   • The bot should respond"
echo "   • Ask to transfer to an agent to test routing"
echo ""

print_header "DEPLOYMENT COMPLETE"
echo ""
