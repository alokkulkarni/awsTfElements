# Production Implementation Guide

## Quick Start Summary

This guide provides step-by-step instructions to transform the current AWS Connect stack into a production-ready financial services contact center with:
- ✅ **Federated Bot Architecture** (Gateway + Banking + Sales Bots)
- ✅ Enhanced Modular Contact Flows
- ✅ Production-grade error handling and resilience
- ✅ Security and compliance features
- ✅ Comprehensive monitoring and alerting


## Files Created

### Contact Flows (Modular Architecture)
All flows are in `/contact_flows/`:

1. **`voice_entry_flow.json.tftpl`** - Voice channel entry point
   - Hours of operation check
   - Set voice channel attributes
   - Welcome message with recording notice
   - Route to voice IVR or after-hours flow

2. **`voice_ivr_flow.json.tftpl`** - Interactive Voice Response menu
   - DTMF menu (press 1-4 for services, 0 for agent)
   - Speech recognition support
   - Category routing (accounts, cards, loans, fraud)
   - Authentication integration
   - Fraud urgency handling

3. **`chat_entry_flow.json.tftpl`** - Chat channel entry point
   - Hours of operation check
   - Set chat channel attributes
   - Friendly welcome message with emoji
   - Direct Lex bot interaction
   - After-hours callback option

4. **`auth_module_flow.json.tftpl`** - Reusable authentication module
   - Voice ID authentication
   - PIN validation (with retry limits)
   - Companion app push authentication
   - Channel-aware (voice vs chat)
   - Security lockout after 3 failed attempts

### Lambda Functions (Enhanced Handlers)
All Lambda code in `/lambda/lex_fallback/`:

1. **`enhanced_lex_handler.py`** - Main orchestrator
   - Routes 15+ intents to specialized handlers
   - Authentication enforcement for sensitive intents
   - Bedrock fallback for unknown intents
   - Comprehensive error handling
   - Production logging

2. **`handlers/resilience.py`** - Resilience patterns
   - Circuit breaker implementation
   - Retry decorator with exponential backoff
   - Rate limiter
   - Transient vs permanent error handling
   - Global circuit breakers for APIs

3. **`handlers/account_handlers.py`** - Account services (4 intents)
   - `CheckBalance` - Real-time balance with account type
   - `TransactionHistory` - Recent transactions with date range
   - `AccountDetails` - Routing/account numbers (high-security)
   - `RequestStatement` - Email or mail delivery

4. **`handlers/card_handlers.py`** - Card & fraud services (5 intents)
   - `ActivateCard` - Card activation with validation
   - `ReportLostStolenCard` - **CRITICAL** - Immediate block & escalate
   - `ReportFraud` - **CRITICAL** - Fraud team escalation
   - `ChangePIN` - Secure channel guidance
   - `DisputeTransaction` - Dispute case creation

## Implementation Steps

### Phase 1: Update Contact Flows (2-3 hours)

#### Step 1.1: Deploy New Flow Templates

The new contact flows are already created. Update `main.tf` to include them:

```terraform
# Replace the existing single flow with modular flows

# Voice Entry Flow
resource "aws_connect_contact_flow" "voice_entry" {
  instance_id = module.connect_instance.id
  name        = "VoiceEntryFlow"
  description = "Voice channel entry with hours check"
  type        = "CONTACT_FLOW"
  content = templatefile("${path.module}/contact_flows/voice_entry_flow.json.tftpl", {
    hours_of_operation_id   = data.aws_connect_hours_of_operation.default.hours_of_operation_id
    voice_ivr_flow_arn      = aws_connect_contact_flow.voice_ivr.arn
    after_hours_flow_arn    = aws_connect_contact_flow.after_hours.arn
  })
  tags = var.tags
}

# Voice IVR Flow
resource "aws_connect_contact_flow" "voice_ivr" {
  instance_id = module.connect_instance.id
  name        = "VoiceIVRFlow"
  description = "IVR menu with DTMF and speech"
  type        = "CONTACT_FLOW"
  content = templatefile("${path.module}/contact_flows/voice_ivr_flow.json.tftpl", {
    auth_module_flow_arn    = aws_connect_contact_flow.auth_module.arn
    lex_interaction_flow_arn = aws_connect_contact_flow.main_flow.arn  # Reuse existing
    queue_routing_flow_arn  = aws_connect_contact_flow.queue_routing.arn
    agent_transfer_flow_arn = aws_connect_contact_flow.agent_transfer.arn
  })
  tags = var.tags
  depends_on = [aws_connect_contact_flow.auth_module]
}

# Chat Entry Flow
resource "aws_connect_contact_flow" "chat_entry" {
  instance_id = module.connect_instance.id
  name        = "ChatEntryFlow"
  description = "Chat channel entry"
  type        = "CONTACT_FLOW"
  content = templatefile("${path.module}/contact_flows/chat_entry_flow.json.tftpl", {
    hours_of_operation_id     = data.aws_connect_hours_of_operation.default.hours_of_operation_id
    lex_bot_alias_arn         = awscc_lex_bot_alias.this.arn
    agent_transfer_flow_arn   = aws_connect_contact_flow.agent_transfer.arn
    survey_flow_arn           = aws_connect_contact_flow.survey.arn
    callback_module_flow_arn  = aws_connect_contact_flow.callback.arn
  })
  tags = var.tags
}

# Authentication Module Flow
resource "aws_connect_contact_flow" "auth_module" {
  instance_id = module.connect_instance.id
  name        = "AuthenticationModule"
  description = "Reusable authentication with Voice ID, PIN, Companion"
  type        = "CONTACT_FLOW"
  content = templatefile("${path.module}/contact_flows/auth_module_flow.json.tftpl", {
    auth_lambda_arn    = module.lex_fallback_lambda.arn
    calling_flow_arn   = aws_connect_contact_flow.voice_ivr.arn  # Return to caller
    opt_out_flow_id    = "opt-out-flow-id-here"  # Voice ID opt-out
  })
  tags = var.tags
}

# TODO: Create additional flows:
# - after_hours_flow
# - queue_routing_flow
# - agent_transfer_flow
# - callback_module_flow
# - survey_flow
```

#### Step 1.2: Update Phone Number Associations

Route voice calls to new voice entry flow:

```terraform
# In main.tf, update phone number associations
resource "null_resource" "associate_voice_flow" {
  triggers = {
    flow_id = aws_connect_contact_flow.voice_entry.id
    phone_id = aws_connect_phone_number.inbound.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws connect associate-phone-number-contact-flow \
        --instance-id ${module.connect_instance.id} \
        --phone-number-id ${aws_connect_phone_number.inbound.id} \
        --contact-flow-id ${aws_connect_contact_flow.voice_entry.id} \
        --region ${var.region}
    EOT
  }
}
```

### Phase 2: Deploy Enhanced Lambda Functions (1-2 hours)

#### Step 2.1: Update Lambda Code Structure

```bash
cd /lambda/lex_fallback/

# Create handlers directory
mkdir -p handlers

# Move new files to correct locations
mv enhanced_lex_handler.py lex_handler.py  # Replace old handler
mv handlers/resilience.py handlers/
mv handlers/account_handlers.py handlers/
mv handlers/card_handlers.py handlers/

# Create empty __init__.py for Python package
touch handlers/__init__.py
```

#### Step 2.2: Create Missing Handler Files

Create placeholder handlers for other domains:

```python
# handlers/transfer_handlers.py
def handle_internal_transfer(event, customer_data, session_attributes):
    # Implement internal transfer logic
    pass

def handle_external_transfer(event, customer_data, session_attributes):
    pass

def handle_wire_transfer(event, customer_data, session_attributes):
    pass

# handlers/loan_handlers.py
def handle_loan_status(event, customer_data, session_attributes):
    pass

def handle_loan_payment(event, customer_data, session_attributes):
    pass

def handle_loan_application(event, customer_data, session_attributes):
    pass
```

#### Step 2.3: Update Lambda Dependencies

Add `requirements.txt`:

```
boto3>=1.26.0
requests>=2.28.0
```

#### Step 2.4: Update Environment Variables in Terraform

```terraform
# In main.tf, update Lambda environment variables
module "lex_fallback_lambda" {
  # ... existing config ...
  
  environment_variables = {
    # Existing
    INTENT_TABLE_NAME     = module.intent_table.name
    AUTH_STATE_TABLE_NAME = module.auth_state_table.name
    SNS_TOPIC_ARN         = module.auth_sns_topic.topic_arn
    CRM_API_ENDPOINT      = "${module.auth_api_gateway.api_endpoint}/customer"
    CRM_API_KEY           = "secret-api-key-123"  # Use Secrets Manager in production
    
    # New - Authentication toggles
    ENABLE_VOICE_ID       = "true"  # Enable Voice ID
    ENABLE_PIN_VALIDATION = "true"  # Enable PIN validation
    ENABLE_COMPANION_AUTH = "true"  # Enable companion app
    
    # New - Bedrock configuration
    ENABLE_BEDROCK_FALLBACK = "true"
    LEX_CONFIDENCE_THRESHOLD = "0.70"  # Raised from 0.40
    
    # New - API configuration
    CORE_BANKING_API_URL  = "https://banking-api.example.com"  # Replace with real
    CORE_BANKING_API_KEY  = "banking-api-key"  # Use Secrets Manager
    API_TIMEOUT           = "5"
    
    # New - Security event logging
    SECURITY_EVENTS_TABLE = module.security_events_table.name
    FRAUD_ALERT_SNS_TOPIC = aws_sns_topic.fraud_alerts.arn
  }
}
```

#### Step 2.5: Create Additional Resources

```terraform
# Security Events Table (DynamoDB)
module "security_events_table" {
  source             = "../resources/dynamodb"
  name               = "${var.project_name}-security-events"
  hash_key           = "customer_id"
  range_key          = "timestamp"
  ttl_enabled        = true
  ttl_attribute_name = "ttl"
  tags               = var.tags
}

# Fraud Alerts Topic (SNS)
resource "aws_sns_topic" "fraud_alerts" {
  name              = "${var.project_name}-fraud-alerts"
  kms_master_key_id = module.kms_key.key_id
  tags              = var.tags
}

# Subscribe operations email to fraud alerts
resource "aws_sns_topic_subscription" "fraud_email" {
  topic_arn = aws_sns_topic.fraud_alerts.arn
  protocol  = "email"
  endpoint  = "fraud-ops@example.com"  # Replace with real email
}
```

### Phase 3: Expand Lex Bot Intents (2-3 hours)

#### Step 3.1: Update variables.tf

Replace the existing `lex_intents` map with expanded intents:

```terraform
variable "lex_intents" {
  description = "Enhanced Lex intents for financial services"
  type = map(object({
    description          = string
    utterances           = list(string)
    fulfillment_enabled  = bool
    slots                = optional(map(object({
      type     = string
      prompt   = string
      required = bool
    })))
  }))
  
  default = {
    # Account Services (4 intents)
    CheckBalance = {
      description = "Check account balance"
      utterances = [
        "what is my balance",
        "check my balance",
        "how much money do I have",
        "account balance",
        "show me my balance",
        "balance inquiry",
        "what's in my account",
        "how much do I have in my account"
      ]
      fulfillment_enabled = true
      slots = {
        AccountType = {
          type     = "AMAZON.AlphaNumeric"
          prompt   = "Which account? Checking or savings?"
          required = true
        }
      }
    }
    
    TransactionHistory = {
      description = "View recent transactions"
      utterances = [
        "show my transactions",
        "recent transactions",
        "what did I spend",
        "transaction history",
        "view my transactions",
        "last transactions",
        "show me what I spent"
      ]
      fulfillment_enabled = true
      slots = {
        AccountType = {
          type     = "AMAZON.AlphaNumeric"
          prompt   = "Which account?"
          required = true
        }
        DateRange = {
          type     = "AMAZON.Number"
          prompt   = "How many days back?"
          required = false
        }
      }
    }
    
    # Card Services (5 intents)
    ActivateCard = {
      description = "Activate a new card"
      utterances = [
        "activate my card",
        "activate card",
        "I got a new card",
        "new card activation",
        "turn on my card"
      ]
      fulfillment_enabled = true
    }
    
    ReportLostStolenCard = {
      description = "Report lost or stolen card - CRITICAL"
      utterances = [
        "my card is lost",
        "lost my card",
        "card was stolen",
        "stolen card",
        "I lost my card",
        "can't find my card",
        "block my card",
        "cancel my card"
      ]
      fulfillment_enabled = true
    }
    
    ReportFraud = {
      description = "Report fraudulent activity - CRITICAL"
      utterances = [
        "report fraud",
        "fraudulent charge",
        "I didn't make this transaction",
        "suspicious activity",
        "fraud on my account",
        "someone is using my card",
        "unauthorized transaction"
      ]
      fulfillment_enabled = true
    }
    
    # Transfer Services (3 intents)
    InternalTransfer = {
      description = "Transfer between own accounts"
      utterances = [
        "transfer money",
        "move money between accounts",
        "internal transfer",
        "transfer funds"
      ]
      fulfillment_enabled = true
    }
    
    # General Services
    TransferToAgent = {
      description = "Transfer to human agent"
      utterances = [
        "speak to an agent",
        "talk to a person",
        "human agent",
        "customer service",
        "speak to someone",
        "agent"
      ]
      fulfillment_enabled = true
    }
    
    BranchLocator = {
      description = "Find nearest branch"
      utterances = [
        "find a branch",
        "nearest branch",
        "branch locations",
        "where is the nearest branch"
      ]
      fulfillment_enabled = true
    }
    
    # ... Add more intents as needed
  }
}
```

#### Step 3.2: Deploy Updated Bot

```bash
terraform apply -target=module.lex_bot
terraform apply -target=aws_lexv2models_intent.intents
terraform apply -target=null_resource.build_bot_locales
```

### Phase 4: Enhanced Routing and Queues (2 hours)

#### Step 4.1: Create Multiple Routing Profiles

```terraform
# In main.tf, add multiple routing profiles

# Tier 1 - General Support
resource "aws_connect_routing_profile" "tier1_general" {
  instance_id               = module.connect_instance.id
  name                      = "Tier1-GeneralSupport"
  description               = "First level support for all channels"
  default_outbound_queue_id = aws_connect_queue.queues["GeneralAgentQueue"].queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }

  media_concurrencies {
    channel     = "CHAT"
    concurrency = 3
  }

  media_concurrencies {
    channel     = "TASK"
    concurrency = 5
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.queues["GeneralAgentQueue"].queue_id
  }

  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.queues["GeneralAgentQueue"].queue_id
  }

  tags = var.tags
}

# Tier 2 - Account Specialists
resource "aws_connect_routing_profile" "tier2_accounts" {
  instance_id               = module.connect_instance.id
  name                      = "Tier2-AccountSpecialists"
  description               = "Account and transaction specialists"
  default_outbound_queue_id = aws_connect_queue.queues["AccountQueue"].queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 2
  }

  media_concurrencies {
    channel     = "CHAT"
    concurrency = 2
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.queues["AccountQueue"].queue_id
  }

  tags = var.tags
}

# Fraud Team - 24/7
resource "aws_connect_routing_profile" "fraud_team" {
  instance_id               = module.connect_instance.id
  name                      = "FraudTeam-24x7"
  description               = "24/7 fraud prevention team"
  default_outbound_queue_id = aws_connect_queue.queues["FraudQueue"].queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1  # High priority, one at a time
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 10  # Highest priority
    queue_id = aws_connect_queue.queues["FraudQueue"].queue_id
  }

  tags = var.tags
}
```

#### Step 4.2: Add Fraud Queue

```terraform
# In variables.tf, add fraud queue to queues map
queues = {
  GeneralAgentQueue = {
    description = "General customer inquiries"
  }
  AccountQueue = {
    description = "Account services and transactions"
  }
  LendingQueue = {
    description = "Loan and lending services"
  }
  OnboardingQueue = {
    description = "New customer onboarding"
  }
  FraudQueue = {  # NEW
    description = "Fraud and security - 24/7"
  }
}
```

### Phase 5: Testing and Validation (3-4 hours)

#### Step 5.1: Unit Tests for Lambda

Create `lambda/lex_fallback/tests/test_handlers.py`:

```python
import pytest
from handlers import account_handlers
from unittest.mock import patch, MagicMock

def test_check_balance_success():
    event = {
        'sessionState': {
            'intent': {
                'name': 'CheckBalance',
                'slots': {
                    'AccountType': {
                        'value': {'interpretedValue': 'checking'}
                    }
                }
            },
            'sessionAttributes': {}
        }
    }
    
    customer_data = {
        'customer_id': '12345',
        'name': 'John Doe'
    }
    
    with patch('handlers.account_handlers.call_core_banking_api') as mock_api:
        mock_api.return_value = {
            'balance': 1500.50,
            'available_balance': 1450.50,
            'currency': 'GBP',
            'account_number': '12345678'
        }
        
        result = account_handlers.handle_check_balance(event, customer_data, {})
        
        assert result['sessionState']['intent']['state'] == 'Fulfilled'
        assert '1,500.50' in result['messages'][0]['content']

# Add more tests...
```

Run tests:
```bash
cd lambda/lex_fallback
pip install pytest pytest-cov
pytest tests/ -v --cov=handlers
```

#### Step 5.2: Flow Testing

Test each flow manually:

1. **Voice Entry Flow**: Call the number, verify hours check
2. **Voice IVR**: Test DTMF menu (press 1-4)
3. **Chat Entry**: Open chat widget, send "hello"
4. **Authentication**: Test Voice ID, PIN, companion auth
5. **Intent Handling**: Test each of the 15+ intents
6. **Error Handling**: Test timeout, invalid input, API failures
7. **Agent Transfer**: Verify transfers work with context

#### Step 5.3: Load Testing

Use AWS Connect Load Testing or custom script:

```bash
# Install AWS Connect simulator
npm install -g aws-connect-simulator

# Run load test
aws-connect-sim \
  --instanceId <instance-id> \
  --contactFlowId <flow-id> \
  --concurrent 50 \
  --duration 300
```

### Phase 6: Monitoring and Observability (2 hours)

#### Step 6.1: Create CloudWatch Dashboard

```terraform
resource "aws_cloudwatch_dashboard" "connect_operations" {
  dashboard_name = "${var.project_name}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Connect", "ContactsHandled", {stat = "Sum"}],
            [".", "ContactsAbandoned", {stat = "Sum"}]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Contact Volume"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", {stat = "Sum", dimensions = {FunctionName = module.lex_fallback_lambda.function_name}}],
            [".", "Duration", {stat = "Average"}]
          ]
          period = 300
          region = var.region
          title  = "Lambda Performance"
        }
      }
    ]
  })
}
```

#### Step 6.2: Create CloudWatch Alarms

```terraform
# High error rate alarm
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "${var.project_name}-lambda-high-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Lambda error rate exceeded threshold"
  alarm_actions       = [aws_sns_topic.fraud_alerts.arn]

  dimensions = {
    FunctionName = module.lex_fallback_lambda.function_name
  }
}

# Queue wait time alarm
resource "aws_cloudwatch_metric_alarm" "queue_wait_time" {
  alarm_name          = "${var.project_name}-queue-wait-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "QueueWaitTime"
  namespace           = "AWS/Connect"
  period              = 300
  statistic           = "Average"
  threshold           = 300  # 5 minutes
  alarm_description   = "Average queue wait time exceeded 5 minutes"
  alarm_actions       = [aws_sns_topic.fraud_alerts.arn]
}
```

## Deployment Checklist

- [ ] **Backup current configuration**
  ```bash
  terraform state pull > backup_$(date +%Y%m%d).tfstate
  ```

- [ ] **Update Terraform code**
  - [ ] Add new contact flows
  - [ ] Update Lambda environment variables
  - [ ] Add new routing profiles
  - [ ] Add fraud queue
  - [ ] Expand Lex intents

- [ ] **Deploy Lambda functions**
  - [ ] Update handler code
  - [ ] Add new dependencies
  - [ ] Deploy and test locally first

- [ ] **Deploy infrastructure**
  ```bash
  terraform plan -out=plan.out
  terraform apply plan.out
  ```

- [ ] **Validate deployment**
  - [ ] Test voice calls
  - [ ] Test chat
  - [ ] Test all intents
  - [ ] Verify agent transfers
  - [ ] Check CloudWatch logs

- [ ] **Enable monitoring**
  - [ ] Set up CloudWatch dashboard
  - [ ] Configure alarms
  - [ ] Test alerting

- [ ] **Documentation**
  - [ ] Update README
  - [ ] Create runbooks
  - [ ] Document escalation procedures

## Rollback Plan

If issues occur:

```bash
# Option 1: Rollback specific resources
terraform apply -target=aws_connect_contact_flow.main_flow

# Option 2: Full rollback from backup
terraform state push backup_YYYYMMDD.tfstate
terraform apply

# Option 3: Emergency - disable new flows, route to old flow
aws connect update-contact-flow-content \
  --instance-id <instance-id> \
  --contact-flow-id <flow-id> \
  --content file://backup_flow.json
```

## Production Launch Checklist

- [ ] Complete all testing phases
- [ ] Train agents on new flows
- [ ] Prepare monitoring team
- [ ] Schedule maintenance window
- [ ] Deploy to production
- [ ] Pilot with 10% of traffic
- [ ] Monitor for 24 hours
- [ ] Gradual rollout to 100%
- [ ] Post-launch review

## Support

For issues during implementation:
- **Terraform errors**: Check AWS provider version, resource dependencies
- **Lambda errors**: Check CloudWatch logs, test locally first
- **Flow errors**: Validate JSON syntax, check ARN references
- **Authentication issues**: Verify Lambda permissions, DynamoDB access

## Next Steps

After successful deployment:
1. ✅ Monitor metrics for 1 week
2. ✅ Gather agent feedback
3. ✅ Tune Lex confidence thresholds
4. ✅ Add more intents based on usage
5. ✅ Implement advanced features (callback, survey)
6. ✅ Optimize queue routing based on data
7. ✅ Enable Contact Lens analytics
8. ✅ Integrate with CRM system

---

**Last Updated**: 2024  
**Version**: 1.0  
**Maintained By**: DevOps/Platform Team
