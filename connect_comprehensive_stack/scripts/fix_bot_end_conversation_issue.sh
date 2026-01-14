#!/bin/bash
# =====================================================================================================================
# FIX SCRIPT: Bot EndConversation Issue
# =====================================================================================================================
# Problem: All intents are configured with "EndConversation" after fulfillment, causing calls to drop
# Solution: Update intents to use "ElicitIntent" to continue the conversation
# =====================================================================================================================

set -e

BOT_ID="9FY9LC8OAB"
REGION="eu-west-2"

echo "🔧 Fixing bot configuration to prevent call drops..."
echo ""

# Get the DRAFT bot's intents
echo "📋 Step 1: Getting all intents from DRAFT bot..."
INTENTS=$(aws lexv2-models list-intents \
  --bot-id "$BOT_ID" \
  --bot-version DRAFT \
  --locale-id en_GB \
  --region "$REGION" \
  --query 'intentSummaries[?intentName!=`FallbackIntent`].{Name:intentName,Id:intentId}' \
  --output json)

echo "$INTENTS" | jq -r '.[] | "  • \(.Name) (\(.Id))"'
echo ""

# Update ChatIntent (en_GB)
echo "🔄 Step 2: Updating ChatIntent (en_GB) fulfillment..."
aws lexv2-models update-intent \
  --bot-id "$BOT_ID" \
  --bot-version DRAFT \
  --locale-id en_GB \
  --intent-id ZAP50MZBD3 \
  --intent-name ChatIntent \
  --fulfillment-code-hook '{
    "enabled": true,
    "postFulfillmentStatusSpecification": {
      "successNextStep": {
        "dialogAction": {"type": "ElicitIntent"}
      },
      "failureNextStep": {
        "dialogAction": {"type": "ElicitIntent"}
      },
      "timeoutNextStep": {
        "dialogAction": {"type": "ElicitIntent"}
      }
    }
  }' \
  --dialog-code-hook '{"enabled": true}' \
  --region "$REGION" > /dev/null

echo "✅ ChatIntent (en_GB) updated"

# Update ChatIntent (en_US)
echo "🔄 Step 3: Updating ChatIntent (en_US) fulfillment..."
aws lexv2-models update-intent \
  --bot-id "$BOT_ID" \
  --bot-version DRAFT \
  --locale-id en_US \
  --intent-id BDIZHSYLSJ \
  --intent-name ChatIntent \
  --fulfillment-code-hook '{
    "enabled": true,
    "postFulfillmentStatusSpecification": {
      "successNextStep": {
        "dialogAction": {"type": "ElicitIntent"}
      },
      "failureNextStep": {
        "dialogAction": {"type": "ElicitIntent"}
      },
      "timeoutNextStep": {
        "dialogAction": {"type": "ElicitIntent"}
      }
    }
  }' \
  --dialog-code-hook '{"enabled": true}' \
  --region "$REGION" > /dev/null

echo "✅ ChatIntent (en_US) updated"

# Update TransferToAgent intent (en_GB)
echo "🔄 Step 4: Updating TransferToAgent (en_GB) fulfillment..."
aws lexv2-models update-intent \
  --bot-id "$BOT_ID" \
  --bot-version DRAFT \
  --locale-id en_GB \
  --intent-id KDQHB5U7MA \
  --intent-name TransferToAgent \
  --fulfillment-code-hook '{
    "enabled": true,
    "postFulfillmentStatusSpecification": {
      "successNextStep": {
        "dialogAction": {"type": "EndConversation"}
      },
      "failureNextStep": {
        "dialogAction": {"type": "ElicitIntent"}
      },
      "timeoutNextStep": {
        "dialogAction": {"type": "ElicitIntent"}
      }
    }
  }' \
  --dialog-code-hook '{"enabled": true}' \
  --region "$REGION" > /dev/null

echo "✅ TransferToAgent (en_GB) updated (EndConversation on success is correct for agent transfer)"

# Update TransferToAgent intent (en_US)
echo "🔄 Step 5: Updating TransferToAgent (en_US) fulfillment..."
aws lexv2-models update-intent \
  --bot-id "$BOT_ID" \
  --bot-version DRAFT \
  --locale-id en_US \
  --intent-id TUXGLLROC3 \
  --intent-name TransferToAgent \
  --fulfillment-code-hook '{
    "enabled": true,
    "postFulfillmentStatusSpecification": {
      "successNextStep": {
        "dialogAction": {"type": "EndConversation"}
      },
      "failureNextStep": {
        "dialogAction": {"type": "ElicitIntent"}
      },
      "timeoutNextStep": {
        "dialogAction": {"type": "ElicitIntent"}
      }
    }
  }' \
  --dialog-code-hook '{"enabled": true}' \
  --region "$REGION" > /dev/null

echo "✅ TransferToAgent (en_US) updated"
echo ""

# Rebuild bot locales
echo "🔨 Step 6: Rebuilding bot locales..."
echo "  • Building en_GB locale..."
aws lexv2-models build-bot-locale \
  --bot-id "$BOT_ID" \
  --bot-version DRAFT \
  --locale-id en_GB \
  --region "$REGION" > /dev/null

echo "  • Building en_US locale..."
aws lexv2-models build-bot-locale \
  --bot-id "$BOT_ID" \
  --bot-version DRAFT \
  --locale-id en_US \
  --region "$REGION" > /dev/null

echo "⏳ Waiting for locales to build (this takes ~30-40 seconds)..."
sleep 15

# Check en_GB status
for i in {1..20}; do
  STATUS=$(aws lexv2-models describe-bot-locale \
    --bot-id "$BOT_ID" \
    --bot-version DRAFT \
    --locale-id en_GB \
    --region "$REGION" \
    --query 'botLocaleStatus' \
    --output text)
  
  echo "  en_GB status: $STATUS (attempt $i/20)"
  
  if [ "$STATUS" = "Built" ]; then
    echo "✅ en_GB locale built successfully"
    break
  elif [ "$STATUS" = "Failed" ]; then
    echo "❌ en_GB locale build failed"
    exit 1
  fi
  
  sleep 5
done

# Check en_US status
for i in {1..20}; do
  STATUS=$(aws lexv2-models describe-bot-locale \
    --bot-id "$BOT_ID" \
    --bot-version DRAFT \
    --locale-id en_US \
    --region "$REGION" \
    --query 'botLocaleStatus' \
    --output text)
  
  echo "  en_US status: $STATUS (attempt $i/20)"
  
  if [ "$STATUS" = "Built" ]; then
    echo "✅ en_US locale built successfully"
    break
  elif [ "$STATUS" = "Failed" ]; then
    echo "❌ en_US locale build failed"
    exit 1
  fi
  
  sleep 5
done

echo ""

# Create new bot version
echo "📦 Step 7: Creating new bot version..."
NEW_VERSION=$(aws lexv2-models create-bot-version \
  --bot-id "$BOT_ID" \
  --bot-version-locale-specification '{
    "en_GB": {"sourceBotVersion": "DRAFT"},
    "en_US": {"sourceBotVersion": "DRAFT"}
  }' \
  --region "$REGION" \
  --query 'botVersion' \
  --output text)

echo "✅ New bot version created: $NEW_VERSION"
echo ""

# Update the prod alias to point to new version
echo "🔄 Step 8: Updating 'prod' alias to point to version $NEW_VERSION..."
aws lexv2-models update-bot-alias \
  --bot-id "$BOT_ID" \
  --bot-alias-id QJMA5R3DQS \
  --bot-alias-name prod \
  --bot-version "$NEW_VERSION" \
  --bot-alias-locale-settings '{
    "en_GB": {
      "enabled": true,
      "codeHookSpecification": {
        "lambdaCodeHook": {
          "lambdaARN": "arn:aws:lambda:eu-west-2:395402194296:function:connect-comprehensive-bedrock-mcp:live",
          "codeHookInterfaceVersion": "1.0"
        }
      }
    },
    "en_US": {
      "enabled": true,
      "codeHookSpecification": {
        "lambdaCodeHook": {
          "lambdaARN": "arn:aws:lambda:eu-west-2:395402194296:function:connect-comprehensive-bedrock-mcp:live",
          "codeHookInterfaceVersion": "1.0"
        }
      }
    }
  }' \
  --region "$REGION" > /dev/null

echo "✅ Alias 'prod' updated to version $NEW_VERSION"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Bot configuration fixed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Changes made:"
echo "  • ChatIntent now uses 'ElicitIntent' to continue conversation"
echo "  • TransferToAgent still uses 'EndConversation' (correct for agent transfer)"
echo "  • Both en_GB and en_US locales updated"
echo "  • New bot version: $NEW_VERSION"
echo "  • Alias 'prod' now points to version $NEW_VERSION"
echo ""
echo "You can now test the system again:"
echo "  • Call: +44 20 4632 2399"
echo "  • Say: 'I want to check my balance'"
echo "  • Expected: Bot should respond and continue conversation"
echo ""
