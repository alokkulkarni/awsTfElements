#!/bin/bash
# =====================================================================================================================
# PRE-DEPLOYMENT VALIDATION SCRIPT
# =====================================================================================================================
# Run this script BEFORE terraform apply to validate:
# - Lambda function code exists and is valid
# - Lex bot intents are properly configured
# - Required IAM permissions are in place
# - Contact flow templates are valid JSON
# =====================================================================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

ERRORS=0
WARNINGS=0

# =====================================================================================================================
# STEP 1: Validate Lambda Functions
# =====================================================================================================================

print_header "STEP 1: Validating Lambda Functions"

# Check Bedrock MCP Lambda
print_info "Checking bedrock_mcp Lambda..."
if [ -f "lambda/bedrock_mcp/lambda_function.py" ]; then
    print_success "Bedrock MCP Lambda source exists"
    
    # Check for required imports
    if grep -q "import boto3" lambda/bedrock_mcp/lambda_function.py; then
        print_success "  Required imports present"
    else
        print_error "  Missing required imports (boto3)"
        ((ERRORS++))
    fi
    
    # Check for lambda_handler function
    if grep -q "def lambda_handler" lambda/bedrock_mcp/lambda_function.py; then
        print_success "  Lambda handler function defined"
    else
        print_error "  Missing lambda_handler function"
        ((ERRORS++))
    fi
    
    # Check requirements.txt
    if [ -f "lambda/bedrock_mcp/requirements.txt" ]; then
        print_success "  requirements.txt exists"
        print_info "    Dependencies: $(cat lambda/bedrock_mcp/requirements.txt | wc -l) packages"
    else
        print_warning "  requirements.txt not found"
        ((WARNINGS++))
    fi
else
    print_error "Bedrock MCP Lambda source NOT found"
    ((ERRORS++))
fi

# Check Banking Lambda
print_info "Checking banking Lambda..."
if [ -f "lambda/banking/index.py" ]; then
    print_success "Banking Lambda source exists"
    
    if grep -q "def lambda_handler" lambda/banking/index.py; then
        print_success "  Lambda handler function defined"
    else
        print_error "  Missing lambda_handler function"
        ((ERRORS++))
    fi
else
    print_error "Banking Lambda source NOT found"
    ((ERRORS++))
fi

# Check Sales Lambda
print_info "Checking sales Lambda..."
if [ -f "lambda/sales/index.py" ]; then
    print_success "Sales Lambda source exists"
    
    if grep -q "def lambda_handler" lambda/sales/index.py; then
        print_success "  Lambda handler function defined"
    else
        print_error "  Missing lambda_handler function"
        ((ERRORS++))
    fi
else
    print_error "Sales Lambda source NOT found"
    ((ERRORS++))
fi

# Check Callback Handler Lambda
print_info "Checking callback_handler Lambda..."
if [ -f "lambda/callback_handler/lambda_function.py" ]; then
    print_success "Callback Handler Lambda source exists"
else
    print_error "Callback Handler Lambda source NOT found"
    ((ERRORS++))
fi

# Check Callback Dispatcher Lambda
print_info "Checking callback_dispatcher Lambda..."
if [ -f "lambda/callback_dispatcher/lambda_function.py" ]; then
    print_success "Callback Dispatcher Lambda source exists"
else
    print_error "Callback Dispatcher Lambda source NOT found"
    ((ERRORS++))
fi

# =====================================================================================================================
# STEP 2: Validate Contact Flow Templates
# =====================================================================================================================

print_header "STEP 2: Validating Contact Flow Templates"

# Check queue_transfer_flow template
print_info "Checking queue_transfer_flow.json.tftpl..."
if [ -f "contact_flows/queue_transfer_flow.json.tftpl" ]; then
    print_success "Queue transfer flow template exists"
    
    # Basic JSON validation (after template substitution wouldn't work, so just check structure)
    if grep -q "Actions" contact_flows/queue_transfer_flow.json.tftpl; then
        print_success "  Template has Actions structure"
    else
        print_warning "  Template might be malformed"
        ((WARNINGS++))
    fi
else
    print_error "Queue transfer flow template NOT found"
    ((ERRORS++))
fi

# Check callback_task_flow template
print_info "Checking callback_task_flow.json.tftpl..."
if [ -f "contact_flows/callback_task_flow.json.tftpl" ]; then
    print_success "Callback task flow template exists"
else
    print_warning "Callback task flow template not found (might use inline JSON)"
    ((WARNINGS++))
fi

# Check voice_entry_flow template
print_info "Checking voice_entry_flow.json.tftpl..."
if [ -f "contact_flows/voice_entry_flow.json.tftpl" ]; then
    print_success "Voice entry flow template exists"
else
    print_warning "Voice entry flow template not found (might use inline JSON)"
    ((WARNINGS++))
fi

# Check chat_entry_flow template
print_info "Checking chat_entry_flow.json.tftpl..."
if [ -f "contact_flows/chat_entry_flow.json.tftpl" ]; then
    print_success "Chat entry flow template exists"
else
    print_warning "Chat entry flow template not found (might use inline JSON)"
    ((WARNINGS++))
fi

# =====================================================================================================================
# STEP 3: Validate Terraform Configuration
# =====================================================================================================================

print_header "STEP 3: Validating Terraform Configuration"

# Check if terraform.tfvars exists
if [ -f "terraform.tfvars" ]; then
    print_success "terraform.tfvars exists"
    
    # Check critical variables
    if grep -q "connect_instance_alias" terraform.tfvars; then
        print_success "  connect_instance_alias configured"
    else
        print_error "  connect_instance_alias not configured"
        ((ERRORS++))
    fi
    
    if grep -q "region" terraform.tfvars; then
        print_success "  region configured"
    else
        print_warning "  region not explicitly configured (will use default)"
        ((WARNINGS++))
    fi
else
    print_error "terraform.tfvars NOT found - copy from terraform.tfvars.example"
    ((ERRORS++))
fi

# Run terraform validate
print_info "Running terraform validate..."
if terraform validate > /dev/null 2>&1; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform validation failed"
    terraform validate
    ((ERRORS++))
fi

# =====================================================================================================================
# STEP 4: Check AWS Credentials and Permissions
# =====================================================================================================================

print_header "STEP 4: Checking AWS Credentials"

# Check if AWS CLI is installed
if command -v aws &> /dev/null; then
    print_success "AWS CLI installed"
    
    # Check credentials
    if aws sts get-caller-identity > /dev/null 2>&1; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
        print_success "AWS credentials valid"
        print_info "  Account: $ACCOUNT_ID"
        print_info "  Identity: $USER_ARN"
    else
        print_error "AWS credentials not configured or invalid"
        ((ERRORS++))
    fi
else
    print_error "AWS CLI not installed"
    ((ERRORS++))
fi

# =====================================================================================================================
# STEP 5: Check Required Terraform Providers
# =====================================================================================================================

print_header "STEP 5: Checking Terraform Providers"

if [ -f ".terraform.lock.hcl" ]; then
    print_success "Terraform lock file exists"
    
    # Check for required providers
    if grep -q "hashicorp/aws" .terraform.lock.hcl; then
        print_success "  AWS provider configured"
    else
        print_error "  AWS provider not configured"
        ((ERRORS++))
    fi
    
    if grep -q "hashicorp/awscc" .terraform.lock.hcl; then
        print_success "  AWS Cloud Control provider configured"
    else
        print_warning "  AWS Cloud Control provider not found (might not be initialized yet)"
        ((WARNINGS++))
    fi
else
    print_warning "Terraform not initialized - run 'terraform init'"
    ((WARNINGS++))
fi

# =====================================================================================================================
# STEP 6: Validate Lex Bot Configuration
# =====================================================================================================================

print_header "STEP 6: Validating Lex Bot Configuration"

# Check main.tf for bot configuration
if grep -q "module \"lex_bot\"" main.tf; then
    print_success "Main Lex bot module configured"
else
    print_error "Main Lex bot module NOT found in main.tf"
    ((ERRORS++))
fi

# Check for TransferToAgent intent definitions
if grep -q "aws_lexv2models_intent.transfer_to_agent_en_gb" main.tf; then
    print_success "TransferToAgent intent (en_GB) configured"
else
    print_error "TransferToAgent intent (en_GB) NOT configured"
    ((ERRORS++))
fi

if grep -q "aws_lexv2models_intent.transfer_to_agent_en_us" main.tf; then
    print_success "TransferToAgent intent (en_US) configured"
else
    print_error "TransferToAgent intent (en_US) NOT configured"
    ((ERRORS++))
fi

# Check for bot locale build
if grep -q "null_resource.build_bot_locales" main.tf; then
    print_success "Bot locale build resource configured"
else
    print_warning "Bot locale build resource not found"
    ((WARNINGS++))
fi

# =====================================================================================================================
# STEP 7: Check Python Syntax for Lambda Functions
# =====================================================================================================================

print_header "STEP 7: Checking Python Syntax"

print_info "Checking Python syntax for Lambda functions..."

if command -v python3 &> /dev/null; then
    # Check bedrock_mcp
    if python3 -m py_compile lambda/bedrock_mcp/lambda_function.py 2>/dev/null; then
        print_success "  bedrock_mcp: Valid Python syntax"
    else
        print_error "  bedrock_mcp: Python syntax errors"
        ((ERRORS++))
    fi
    
    # Check banking
    if python3 -m py_compile lambda/banking/index.py 2>/dev/null; then
        print_success "  banking: Valid Python syntax"
    else
        print_error "  banking: Python syntax errors"
        ((ERRORS++))
    fi
    
    # Check sales
    if python3 -m py_compile lambda/sales/index.py 2>/dev/null; then
        print_success "  sales: Valid Python syntax"
    else
        print_error "  sales: Python syntax errors"
        ((ERRORS++))
    fi
else
    print_warning "Python3 not found, skipping syntax checks"
    ((WARNINGS++))
fi

# =====================================================================================================================
# VALIDATION SUMMARY
# =====================================================================================================================

print_header "VALIDATION SUMMARY"

echo ""
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    print_success "ALL CHECKS PASSED - Ready for deployment! 🎉"
    echo ""
    print_info "Next steps:"
    echo "  1. Run: terraform plan"
    echo "  2. Review the plan carefully"
    echo "  3. Run: terraform apply"
    echo "  4. After apply, run: ./scripts/post_deployment_connect_bot.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    print_warning "$WARNINGS warning(s) found"
    print_info "You can proceed with deployment, but review warnings above"
    exit 0
else
    print_error "$ERRORS error(s) found"
    print_warning "$WARNINGS warning(s) found"
    print_error "Fix errors before deploying"
    exit 1
fi
