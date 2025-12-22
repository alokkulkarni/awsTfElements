#!/bin/bash

# Test script to verify transfer agreement detection
# This tests the scenario where customer says "yes" to specialist transfer offer

set -e

REGION="eu-west-2"
FUNCTION_NAME="connect-mcp-test-transfer-$(date +%s)"
TABLE_NAME="${FUNCTION_NAME}-history"
ROLE_NAME="${FUNCTION_NAME}-role"
CALLER_ID="transfer-test-caller-$(date +%s)"
LOG_FILE="test_transfer_$(date +%Y%m%d-%H%M%S).log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "${BLUE}===> Testing Transfer Agreement Detection in region: $REGION${NC}"
log "Function: $FUNCTION_NAME"
log "Table: $TABLE_NAME"
log "Caller ID: $CALLER_ID"
log "Log file: $LOG_FILE"

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
log "AWS Account: $AWS_ACCOUNT"

# Check Lambda zip
if [ ! -f "./lambda/bedrock_mcp.zip" ]; then
    log "${RED}ERROR: Lambda zip not found!${NC}"
    exit 1
fi
ZIP_SIZE=$(ls -lh ./lambda/bedrock_mcp.zip | awk '{print $5}')
log "Lambda zip found: ./lambda/bedrock_mcp.zip ( $ZIP_SIZE)"

# Cleanup trap
cleanup() {
    log "${BLUE}===> Starting cleanup of all resources...${NC}"
    
    # Delete provisioned concurrency
    log "Deleting provisioned concurrency..."
    aws lambda delete-provisioned-concurrency-config \
        --function-name "$FUNCTION_NAME" \
        --provisioned-concurrent-executions-config {} \
        --region "$REGION" 2>/dev/null || true
    
    sleep 2
    
    # Delete alias
    log "Deleting Lambda alias..."
    aws lambda delete-alias \
        --function-name "$FUNCTION_NAME" \
        --name "live" \
        --region "$REGION" 2>/dev/null || true
    
    sleep 1
    
    # Delete function
    log "Deleting Lambda function..."
    aws lambda delete-function \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION" 2>/dev/null || true
    
    sleep 2
    
    # Delete DynamoDB table
    log "Deleting DynamoDB table..."
    aws dynamodb delete-table \
        --table-name "$TABLE_NAME" \
        --region "$REGION" 2>/dev/null || true
    
    sleep 2
    
    # Delete policy
    log "Deleting IAM role policy..."
    aws iam delete-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "${FUNCTION_NAME}-policy" \
        --region "$REGION" 2>/dev/null || true
    
    sleep 1
    
    # Delete role
    log "Deleting IAM role..."
    aws iam delete-role \
        --role-name "$ROLE_NAME" 2>/dev/null || true
    
    log "${GREEN}===> Cleanup complete!${NC}"
}

trap cleanup EXIT

# Step 1: Create IAM role
log "===> Step 1: Creating IAM role..."
ROLE_ARN=$(aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' \
    --query 'Role.Arn' \
    --output text)
log "IAM role created: $ROLE_ARN"

# Step 2: Create DynamoDB table
log "===> Step 2: Creating DynamoDB conversation history table..."
aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=caller_id,AttributeType=S AttributeName=timestamp,AttributeType=N \
    --key-schema AttributeName=caller_id,KeyType=HASH AttributeName=timestamp,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" > /dev/null

log "Waiting for table to become active..."
aws dynamodb wait table-exists \
    --table-name "$TABLE_NAME" \
    --region "$REGION"
log "DynamoDB table created: $TABLE_NAME"

# Step 3: Attach IAM policy
log "===> Step 3: Attaching IAM policy to role..."
aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "${FUNCTION_NAME}-policy" \
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
                \"Resource\": \"arn:aws:logs:$REGION:$AWS_ACCOUNT:log-group:/aws/lambda/$FUNCTION_NAME:*\"
            },
            {
                \"Effect\": \"Allow\",
                \"Action\": [
                    \"dynamodb:PutItem\",
                    \"dynamodb:GetItem\",
                    \"dynamodb:Query\",
                    \"dynamodb:UpdateItem\",
                    \"dynamodb:DeleteItem\",
                    \"dynamodb:BatchWriteItem\"
                ],
                \"Resource\": \"arn:aws:dynamodb:$REGION:$AWS_ACCOUNT:table/$TABLE_NAME\"
            },
            {
                \"Effect\": \"Allow\",
                \"Action\": [
                    \"bedrock:InvokeModel\"
                ],
                \"Resource\": \"arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0\"
            },
            {
                \"Effect\": \"Allow\",
                \"Action\": [
                    \"cloudwatch:PutMetricData\"
                ],
                \"Resource\": \"*\"
            }
        ]
    }" > /dev/null
log "IAM policy attached with permissions for: logs, dynamodb, bedrock, cloudwatch"

log "Waiting 10 seconds for IAM propagation..."
sleep 10

# Step 4: Create Lambda function
log "===> Step 4: Creating Lambda function..."
aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.11 \
    --role "$ROLE_ARN" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://./lambda/bedrock_mcp.zip \
    --memory-size 1024 \
    --architectures arm64 \
    --timeout 60 \
    --environment "Variables={DYNAMODB_TABLE=$TABLE_NAME,BEDROCK_REGION=us-east-1,BEDROCK_MAX_TOKENS=256,BEDROCK_TEMPERATURE=0.7}" \
    --region "$REGION" > /dev/null
log "Lambda function created: $FUNCTION_NAME (1024MB, arm64, 60s timeout)"

log "Waiting for Lambda function to become active..."
while true; do
    STATE=$(aws lambda get-function \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION" \
        --query 'Configuration.State' \
        --output text)
    if [ "$STATE" == "Active" ]; then
        break
    fi
    sleep 3
done
log "Lambda function is now active"

# Step 5: Publish version and create alias
log "===> Step 5: Publishing version and creating alias with provisioned concurrency..."
VERSION=$(aws lambda publish-version \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query 'Version' \
    --output text)
log "Published version: $VERSION"

aws lambda create-alias \
    --function-name "$FUNCTION_NAME" \
    --name "live" \
    --function-version "$VERSION" \
    --region "$REGION" > /dev/null
log "Alias created: live -> v$VERSION"

aws lambda put-provisioned-concurrency-config \
    --function-name "$FUNCTION_NAME" \
    --provisioned-concurrent-executions 1 \
    --qualifier "live" \
    --region "$REGION" > /dev/null
log "Provisioned concurrency configured: 1 warm instance"

log "Waiting 15 seconds for provisioned instance to warm up..."
sleep 15

# Step 6: Create test payloads for transfer agreement flow
log "===> Step 6: Creating test payloads for transfer agreement flow..."

# First message: Customer asks for balance
PAYLOAD_1=$(cat <<EOF
{
    "inputTranscript": "Hi there, I'd like to check my account balance.",
    "sessionState": {
        "intent": {
            "name": "ChatIntent"
        },
        "sessionAttributes": {
            "customer_number": "$CALLER_ID"
        }
    }
}
EOF
)

# Second message: Customer agrees to transfer (this should trigger TransferToAgent intent)
PAYLOAD_2=$(cat <<EOF
{
    "inputTranscript": "Yes, please connect me to a specialist.",
    "sessionState": {
        "intent": {
            "name": "ChatIntent"
        },
        "sessionAttributes": {
            "customer_number": "$CALLER_ID"
        }
    }
}
EOF
)

log "Test payloads created for caller: $CALLER_ID"

# Step 7: First invocation - Customer asks for balance
log "===> Step 7: Invoking Lambda - First call (customer asks for balance)..."
OUT_1="/tmp/${FUNCTION_NAME}-out1.json"
LOGS_1="/tmp/${FUNCTION_NAME}-logs1.txt"

aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --invocation-type RequestResponse \
    --payload "$(echo "$PAYLOAD_1" | base64)" \
    --cli-binary-format raw-in-base64-out \
    "$OUT_1" > "$LOGS_1" 2>&1

log "Response saved to: $OUT_1"
log "Logs saved to: $LOGS_1"

RESPONSE_STATUS=$(jq -r '.sessionState.intent.name' "$OUT_1" 2>/dev/null || echo "unknown")
log "Response intent: $RESPONSE_STATUS"
echo "Response:" 
jq . "$OUT_1" 2>/dev/null | head -30

log "Recent log entries:"
tail -15 "$LOGS_1" | sed 's/^/  /'

# Check if specialist transfer was offered
if grep -q "connect you with a specialist\|transfer you" "$OUT_1" 2>/dev/null; then
    log "${GREEN}✓ Specialist transfer offer detected in response${NC}"
else
    log "${RED}✗ Specialist transfer offer NOT found in response${NC}"
fi

# Step 8: Query DynamoDB
log "===> Step 8: Querying DynamoDB for saved conversation history..."
ITEMS=$(aws dynamodb query \
    --table-name "$TABLE_NAME" \
    --key-condition-expression "caller_id = :caller_id" \
    --expression-attribute-values "{\":caller_id\":{\"S\":\"$CALLER_ID\"}}" \
    --region "$REGION" \
    --output json)

ITEM_COUNT=$(echo "$ITEMS" | jq '.Items | length')
log "Items in DynamoDB for caller $CALLER_ID: $ITEM_COUNT"

if [ "$ITEM_COUNT" -gt 0 ]; then
    log "Sample items:"
    echo "$ITEMS" | jq -r '.Items[] | "\(.timestamp.N | tonumber | floor) \(.role.S): \(.content.S | .[0:80])"' | sed 's/^/  /'
fi

# Step 9: Second invocation - Customer agrees to transfer
log "===> Step 9: Invoking Lambda - Second call (customer agrees to transfer)..."
OUT_2="/tmp/${FUNCTION_NAME}-out2.json"
LOGS_2="/tmp/${FUNCTION_NAME}-logs2.txt"

aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --invocation-type RequestResponse \
    --payload "$(echo "$PAYLOAD_2" | base64)" \
    --cli-binary-format raw-in-base64-out \
    "$OUT_2" > "$LOGS_2" 2>&1

log "Response saved to: $OUT_2"
log "Logs saved to: $LOGS_2"

RESPONSE_INTENT=$(jq -r '.sessionState.intent.name' "$OUT_2" 2>/dev/null || echo "unknown")
log "Response intent: $RESPONSE_INTENT"
echo "Response:"
jq . "$OUT_2" 2>/dev/null | head -30

log "Recent log entries:"
tail -20 "$LOGS_2" | sed 's/^/  /'

# Step 10: Verify transfer agreement was detected
if [ "$RESPONSE_INTENT" == "TransferToAgent" ]; then
    log "${GREEN}✓✓✓ SUCCESS! TransferToAgent intent triggered on customer agreement!${NC}"
elif grep -q "TRANSFER AGREEMENT DETECTED\|customer agreed to transfer" "$LOGS_2" 2>/dev/null; then
    log "${GREEN}✓ Transfer agreement detected in logs${NC}"
else
    log "${RED}✗ Transfer agreement NOT detected${NC}"
fi

# Check for confirmation message
if grep -q "connecting you\|specialist now\|Thank you for your patience" "$OUT_2" 2>/dev/null; then
    log "${GREEN}✓ Confirmation message for transfer found${NC}"
else
    log "${RED}⚠ Confirmation message not found${NC}"
fi

# Step 11: Final DynamoDB count
log "===> Step 11: Final DynamoDB query..."
FINAL_ITEMS=$(aws dynamodb query \
    --table-name "$TABLE_NAME" \
    --key-condition-expression "caller_id = :caller_id" \
    --expression-attribute-values "{\":caller_id\":{\"S\":\"$CALLER_ID\"}}" \
    --region "$REGION" \
    --output json)

FINAL_COUNT=$(echo "$FINAL_ITEMS" | jq '.Items | length')
log "Final item count in DynamoDB: $FINAL_COUNT (should be 4: 2 from first invocation + 2 from second)"

log "All conversation items:"
echo "$FINAL_ITEMS" | jq -r '.Items[] | "\(.timestamp.N | tonumber | floor) \(.role.S): \(.content.S | .[0:100])"' | sed 's/^/  /'

log "${GREEN}===> Test completed!${NC}"
