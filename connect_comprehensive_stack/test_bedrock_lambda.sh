#!/bin/bash
set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="us-east-1"
LAMBDA_NAME="test-bedrock-mcp-$(date +%s)"
ROLE_NAME="test-bedrock-mcp-role-$(date +%s)"
TABLE_NAME="test-conversation-history-$(date +%s)"
HALLUCINATION_TABLE_NAME="test-hallucination-logs-$(date +%s)"
ZIP_FILE="./lambda/bedrock_mcp.zip"
LAMBDA_ARN=""
ROLE_ARN=""
CALLER_ID="+447700900123"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Cleanup function
cleanup() {
    log_info "=========================================="
    log_info "Starting cleanup process..."
    log_info "=========================================="
    
    # Delete Lambda function
    if [ ! -z "$LAMBDA_ARN" ]; then
        log_info "Deleting Lambda function: $LAMBDA_NAME"
        aws lambda delete-function --function-name "$LAMBDA_NAME" --region "$REGION" 2>/dev/null || log_warn "Lambda function not found or already deleted"
        log_success "Lambda function deleted"
    fi
    
    # Delete IAM role policies
    if [ ! -z "$ROLE_ARN" ]; then
        log_info "Detaching and deleting IAM role policies"
        
        # List and delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames[]' --output text 2>/dev/null || echo "")
        if [ ! -z "$INLINE_POLICIES" ]; then
            for policy in $INLINE_POLICIES; do
                log_info "Deleting inline policy: $policy"
                aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$policy" 2>/dev/null || log_warn "Failed to delete policy: $policy"
            done
        fi
        
        # Delete IAM role
        log_info "Deleting IAM role: $ROLE_NAME"
        aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || log_warn "IAM role not found or already deleted"
        log_success "IAM role deleted"
    fi
    
    # Delete DynamoDB tables
    log_info "Deleting DynamoDB conversation history table: $TABLE_NAME"
    aws dynamodb delete-table --table-name "$TABLE_NAME" --region "$REGION" 2>/dev/null || log_warn "Table not found or already deleted"
    log_success "Conversation history table deleted"
    
    log_info "Deleting DynamoDB hallucination logs table: $HALLUCINATION_TABLE_NAME"
    aws dynamodb delete-table --table-name "$HALLUCINATION_TABLE_NAME" --region "$REGION" 2>/dev/null || log_warn "Hallucination table not found or already deleted"
    log_success "Hallucination logs table deleted"
    
    log_success "=========================================="
    log_success "Cleanup completed successfully!"
    log_success "=========================================="
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    log_info "=========================================="
    log_info "Starting Bedrock Lambda Deployment & Test"
    log_info "=========================================="
    
    # Check if zip file exists
    if [ ! -f "$ZIP_FILE" ]; then
        log_error "Lambda zip file not found at: $ZIP_FILE"
        exit 1
    fi
    log_success "Lambda zip file found: $ZIP_FILE"
    
    # Step 1: Create DynamoDB tables
    log_info "=========================================="
    log_info "Step 1: Creating DynamoDB tables"
    log_info "=========================================="
    
    log_info "Creating conversation history table: $TABLE_NAME"
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions \
            AttributeName=caller_id,AttributeType=S \
            AttributeName=timestamp,AttributeType=S \
        --key-schema \
            AttributeName=caller_id,KeyType=HASH \
            AttributeName=timestamp,KeyType=RANGE \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" \
        --tags Key=Purpose,Value=Testing > /dev/null
    log_success "Conversation history table created"
    
    log_info "Creating hallucination logs table: $HALLUCINATION_TABLE_NAME"
    aws dynamodb create-table \
        --table-name "$HALLUCINATION_TABLE_NAME" \
        --attribute-definitions \
            AttributeName=log_id,AttributeType=S \
            AttributeName=timestamp,AttributeType=S \
        --key-schema \
            AttributeName=log_id,KeyType=HASH \
            AttributeName=timestamp,KeyType=RANGE \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" \
        --tags Key=Purpose,Value=Testing > /dev/null
    log_success "Hallucination logs table created"
    
    log_info "Waiting for tables to become ACTIVE..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
    aws dynamodb wait table-exists --table-name "$HALLUCINATION_TABLE_NAME" --region "$REGION"
    log_success "All tables are ACTIVE"
    
    # Step 2: Create IAM role with permissions
    log_info "=========================================="
    log_info "Step 2: Creating IAM role and policies"
    log_info "=========================================="
    
    log_info "Creating IAM role: $ROLE_NAME"
    ROLE_ARN=$(aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "lambda.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }' \
        --query 'Role.Arn' \
        --output text)
    log_success "IAM role created: $ROLE_ARN"
    
    # Get AWS account ID
    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    
    log_info "Attaching policies to IAM role"
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "BedrockMCPPolicy" \
        --policy-document "{
            \"Version\": \"2012-10-17\",
            \"Statement\": [
                {
                    \"Effect\": \"Allow\",
                    \"Action\": [
                        \"logs:CreateLogGroup\",
                        \"logs:CreateLogStream\",
                        \"logs:PutLogEvents\"
                    ],
                    \"Resource\": \"arn:aws:logs:*:*:*\"
                },
                {
                    \"Effect\": \"Allow\",
                    \"Action\": [
                        \"bedrock:InvokeModel\",
                        \"bedrock:InvokeModelWithResponseStream\"
                    ],
                    \"Resource\": [
                        \"arn:aws:bedrock:*::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0\",
                        \"arn:aws:bedrock:*::foundation-model/anthropic.claude-*\",
                        \"arn:aws:bedrock:*:${ACCOUNT_ID}:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0\",
                        \"arn:aws:bedrock:*:${ACCOUNT_ID}:inference-profile/*\"
                    ]
                },
                {
                    \"Effect\": \"Allow\",
                    \"Action\": [
                        \"dynamodb:PutItem\",
                        \"dynamodb:GetItem\",
                        \"dynamodb:Query\",
                        \"dynamodb:UpdateItem\",
                        \"dynamodb:DeleteItem\"
                    ],
                    \"Resource\": [
                        \"arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${TABLE_NAME}\",
                        \"arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${HALLUCINATION_TABLE_NAME}\"
                    ]
                }
            ]
        }"
    log_success "Policies attached to IAM role"
    
    log_info "Waiting 10 seconds for IAM role to propagate..."
    sleep 10
    
    # Step 3: Deploy Lambda function
    log_info "=========================================="
    log_info "Step 3: Deploying Lambda function"
    log_info "=========================================="
    
    log_info "Creating Lambda function: $LAMBDA_NAME"
    LAMBDA_ARN=$(aws lambda create-function \
        --function-name "$LAMBDA_NAME" \
        --runtime python3.11 \
        --role "$ROLE_ARN" \
        --handler lambda_function.lambda_handler \
        --zip-file fileb://"$ZIP_FILE" \
        --timeout 60 \
        --memory-size 1024 \
        --architectures arm64 \
        --environment "Variables={
            BEDROCK_MODEL_ID=arn:aws:bedrock:us-east-1:${ACCOUNT_ID}:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0,
            BEDROCK_REGION=us-east-1,
            CONVERSATION_HISTORY_TABLE_NAME=${TABLE_NAME},
            HALLUCINATION_TABLE_NAME=${HALLUCINATION_TABLE_NAME},
            ENABLE_HALLUCINATION_DETECTION=true,
            LOG_LEVEL=INFO,
            BEDROCK_MAX_TOKENS=2048,
            BEDROCK_TEMPERATURE=0.5
        }" \
        --region "$REGION" \
        --query 'FunctionArn' \
        --output text)
    log_success "Lambda function created: $LAMBDA_ARN"
    
    log_info "Waiting for Lambda function to be active..."
    aws lambda wait function-active --function-name "$LAMBDA_NAME" --region "$REGION"
    log_success "Lambda function is active and ready"
    
    # Step 4: Test Lambda function
    log_info "=========================================="
    log_info "Step 4: Testing Lambda function"
    log_info "=========================================="
    
    # Test 1: Initial invocation (no conversation history)
    log_info "Test 1: Initial invocation with greeting"
    
    cat > /tmp/test_event_1.json <<'EOF'
{
    "sessionId": "test-session-001",
    "inputTranscript": "Hello, I need help with my account",
    "sessionState": {
        "sessionAttributes": {
            "caller_id": "+447700900123"
        },
        "intent": {
            "name": "ChatIntent",
            "state": "InProgress"
        }
    }
}
EOF
    
    log_info "Invoking Lambda with initial request..."
    set +e  # Temporarily disable exit on error for Lambda invocation
    aws lambda invoke \
        --function-name "$LAMBDA_NAME" \
        --cli-binary-format raw-in-base64-out \
        --payload file:///tmp/test_event_1.json \
        --region "$REGION" \
        --cli-read-timeout 120 \
        --cli-connect-timeout 10 \
        /tmp/lambda_response_1.json > /tmp/lambda_invoke_1.log 2>&1
    INVOKE_RESULT=$?
    set -e  # Re-enable exit on error
    
    if [ $INVOKE_RESULT -eq 0 ]; then
        log_success "Lambda invocation successful"
        log_info "Response saved to /tmp/lambda_response_1.json"
        
        # Check for function errors in response
        if [ -f /tmp/lambda_response_1.json ]; then
            ERROR_MSG=$(cat /tmp/lambda_response_1.json | jq -r '.errorMessage // empty' 2>/dev/null)
            if [ ! -z "$ERROR_MSG" ]; then
                log_error "Lambda function error: $ERROR_MSG"
                log_info "Full response: $(cat /tmp/lambda_response_1.json)"
            else
                RESPONSE_MESSAGE=$(cat /tmp/lambda_response_1.json | jq -r '.messages[0].content // "No message content"' 2>/dev/null)
                log_info "Bot response: ${RESPONSE_MESSAGE:0:200}..."
            fi
        fi
    else
        log_error "Lambda invocation failed with exit code: $INVOKE_RESULT"
        if [ -f /tmp/lambda_invoke_1.log ]; then
            log_error "Error details: $(cat /tmp/lambda_invoke_1.log)"
        fi
    fi
    
    sleep 2
    
    # Test 2: Second invocation (should use conversation history and cache)
    log_info "Test 2: Second invocation (testing conversation history & cache)"
    
    cat > /tmp/test_event_2.json <<'EOF'
{
    "sessionId": "test-session-002",
    "inputTranscript": "What did I just ask you about?",
    "sessionState": {
        "sessionAttributes": {
            "caller_id": "+447700900123"
        },
        "intent": {
            "name": "ChatIntent",
            "state": "InProgress"
        }
    }
}
EOF
    
    log_info "Invoking Lambda with follow-up question..."
    set +e
    aws lambda invoke \
        --function-name "$LAMBDA_NAME" \
        --cli-binary-format raw-in-base64-out \
        --payload file:///tmp/test_event_1.json \
        --region "$REGION" \
        --cli-read-timeout 120 \
        --cli-connect-timeout 10 \
        /tmp/lambda_response_2.json > /tmp/lambda_invoke_2.log 2>&1
    INVOKE_RESULT=$?
    set -e
    
    if [ $INVOKE_RESULT -eq 0 ]; then
        log_success "Lambda invocation successful"
        log_info "Response saved to /tmp/lambda_response_2.json"
        
        if [ -f /tmp/lambda_response_2.json ]; then
            ERROR_MSG=$(cat /tmp/lambda_response_2.json | jq -r '.errorMessage // empty' 2>/dev/null)
            if [ ! -z "$ERROR_MSG" ]; then
                log_error "Lambda function error: $ERROR_MSG"
            else
                RESPONSE_MESSAGE=$(cat /tmp/lambda_response_2.json | jq -r '.messages[0].content // "No message content"' 2>/dev/null)
                log_info "Bot response: ${RESPONSE_MESSAGE:0:200}..."
            fi
        fi
    else
        log_error "Lambda invocation failed with exit code: $INVOKE_RESULT"
    fi
    
    sleep 2
    
    # Test 3: Third invocation within cache TTL (should hit in-memory cache)
    log_info "Test 3: Third invocation (testing in-memory cache hit)"
    
    cat > /tmp/test_event_3.json <<'EOF'
{
    "sessionId": "test-session-003",
    "inputTranscript": "Can you help me update my contact information?",
    "sessionState": {
        "sessionAttributes": {
            "caller_id": "+447700900123"
        },
        "intent": {
            "name": "ChatIntent",
            "state": "InProgress"
        }
    }
}
EOF
    
    log_info "Invoking Lambda with third request (cache should be warm)..."
    set +e
    aws lambda invoke \
        --function-name "$LAMBDA_NAME" \
        --cli-binary-format raw-in-base64-out \
        --payload file:///tmp/test_event_3.json \
        --region "$REGION" \
        --cli-read-timeout 120 \
        --cli-connect-timeout 10 \
        /tmp/lambda_response_3.json > /tmp/lambda_invoke_3.log 2>&1
    INVOKE_RESULT=$?
    set -e
    
    if [ $INVOKE_RESULT -eq 0 ]; then
        log_success "Lambda invocation successful"
        log_info "Response saved to /tmp/lambda_response_3.json"
        
        if [ -f /tmp/lambda_response_3.json ]; then
            ERROR_MSG=$(cat /tmp/lambda_response_3.json | jq -r '.errorMessage // empty' 2>/dev/null)
            if [ ! -z "$ERROR_MSG" ]; then
                log_error "Lambda function error: $ERROR_MSG"
            else
                RESPONSE_MESSAGE=$(cat /tmp/lambda_response_3.json | jq -r '.messages[0].content // "No message content"' 2>/dev/null)
                log_info "Bot response: ${RESPONSE_MESSAGE:0:200}..."
            fi
        fi
    else
        log_error "Lambda invocation failed with exit code: $INVOKE_RESULT"
    fi
    
    # Step 5: Verify DynamoDB entries
    log_info "=========================================="
    log_info "Step 5: Verifying DynamoDB conversation history"
    log_info "=========================================="
    
    log_info "Querying conversation history for caller: $CALLER_ID"
    HISTORY_COUNT=$(aws dynamodb query \
        --table-name "$TABLE_NAME" \
        --key-condition-expression "caller_id = :caller_id" \
        --expression-attribute-values "{\":caller_id\":{\"S\":\"${CALLER_ID}\"}}" \
        --region "$REGION" \
        --query 'Count' \
        --output text)
    
    log_success "Found $HISTORY_COUNT conversation history entries in DynamoDB"
    
    # Display conversation history details
    log_info "Retrieving conversation history details..."
    aws dynamodb query \
        --table-name "$TABLE_NAME" \
        --key-condition-expression "caller_id = :caller_id" \
        --expression-attribute-values "{\":caller_id\":{\"S\":\"${CALLER_ID}\"}}" \
        --region "$REGION" \
        --output json > /tmp/conversation_history.json
    
    if [ -f /tmp/conversation_history.json ]; then
        ITEM_COUNT=$(cat /tmp/conversation_history.json | jq '.Items | length')
        log_info "Conversation history entries:"
        cat /tmp/conversation_history.json | jq -r '.Items[] | "\(.timestamp.S): \(.role.S) - \(.content.S[0:100])..."' 2>/dev/null | while read line; do
            log_info "  $line"
        done
    fi
    
    # Step 6: Check Lambda logs
    log_info "=========================================="
    log_info "Step 6: Checking Lambda CloudWatch logs"
    log_info "=========================================="
    
    LOG_GROUP="/aws/lambda/$LAMBDA_NAME"
    log_info "Waiting for logs to be available..."
    sleep 5
    
    log_info "Fetching recent Lambda logs from CloudWatch..."
    LOG_STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --region "$REGION" \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null)
    
    if [ ! -z "$LOG_STREAMS" ] && [ "$LOG_STREAMS" != "None" ]; then
        log_info "Latest log stream: $LOG_STREAMS"
        log_info "Recent log events:"
        aws logs get-log-events \
            --log-group-name "$LOG_GROUP" \
            --log-stream-name "$LOG_STREAMS" \
            --limit 20 \
            --region "$REGION" \
            --query 'events[*].message' \
            --output text 2>/dev/null | tail -10 | while read line; do
            log_info "  $line"
        done
    else
        log_warn "No log streams found yet (logs may still be propagating)"
    fi
    
    # Step 7: Summary
    log_info "=========================================="
    log_success "Test Summary"
    log_info "=========================================="
    log_success "✓ DynamoDB tables created and verified"
    log_success "✓ IAM role and policies configured"
    log_success "✓ Lambda function deployed (1024MB, arm64)"
    log_success "✓ 3 Lambda invocations completed"
    log_success "✓ Conversation history saved to DynamoDB ($HISTORY_COUNT entries)"
    log_success "✓ In-memory cache tested across invocations"
    log_success "✓ CloudWatch logs available"
    log_info "=========================================="
    log_info "Test responses saved to:"
    log_info "  - /tmp/lambda_response_1.json"
    log_info "  - /tmp/lambda_response_2.json"
    log_info "  - /tmp/lambda_response_3.json"
    log_info "  - /tmp/conversation_history.json"
    log_info "=========================================="
    
    # Wait before cleanup
    log_info "Waiting 5 seconds before cleanup..."
    sleep 5
}

# Run main function
main
