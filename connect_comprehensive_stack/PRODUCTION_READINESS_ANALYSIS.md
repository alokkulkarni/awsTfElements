# Production Readiness Analysis - Financial Services Contact Center

## Executive Summary

This document provides a comprehensive analysis of the current AWS Connect + Lex implementation and outlines the specific improvements required to make it production-ready for a financial services organization (bank). The analysis covers architecture, contact flows, Lambda functions, routing, security, and operational requirements.

## Current State Assessment

### ✅ Strengths

1. **Infrastructure as Code**: Complete Terraform implementation with modular resources
2. **Security Foundation**: KMS encryption, WAF, CloudTrail auditing, encrypted S3 storage
3. **AI Integration**: Lex V2 bot with Bedrock fallback for intent classification
4. **Multi-Channel**: Support for voice, chat, and tasks
5. **Authentication Framework**: Companion auth mechanism with DynamoDB state management
6. **CRM Integration**: API Gateway + Lambda for customer data lookup
7. **Observability**: CloudWatch logs, Contact Lens enabled
8. **Custom CCP**: CloudFront-hosted agent workspace

### ❌ Critical Gaps for Production

#### 1. **Contact Flow Architecture**

**Current State:**
- Single simple flow: `main_flow.json.tftpl` (45 lines)
- Just one Lex block that loops to itself
- No voice vs chat differentiation
- No IVR menu for voice calls
- No error handling beyond disconnect
- No agent transfer logic
- No queue overflow handling
- No hours of operation checks
- No callback functionality

**Required for Production:**
- Separate voice and chat entry flows
- Voice IVR with DTMF menu and speech recognition
- Modular reusable flows for common patterns:
  - Authentication module
  - Queue routing module
  - Agent transfer module with context
  - Customer callback module
  - Survey/feedback module
- Comprehensive error handling at every step
- Hours of operation and holiday routing
- Queue position announcements
- Estimated wait time announcements
- Music/prompts management
- Agent whisper flows (context before connection)

#### 2. **Lambda Intent Handlers**

**Current State:**
```python
# Only 3 basic intents implemented:
- CheckBalance: Returns mock balance
- LoanInquiry: Generic message
- OnboardingStatus: Generic message

# Issues:
- Authentication DISABLED for testing (commented out)
- No real CRM integration (mock data)
- No error handling for API failures
- No retry logic
- No logging/monitoring
- No input validation
- Basic fulfillment responses
```

**Required for Production:**
- Enable and enhance authentication logic
- Add comprehensive financial services intents:
  - **Account Services**: Check balance, transaction history, account details, statement requests
  - **Card Services**: Card activation, PIN change, lost/stolen card, fraud reporting
  - **Transfer Services**: Internal transfers, external transfers, wire transfers
  - **Loan Services**: Loan status, payment due date, payoff amount, loan application
  - **Security**: Block account, update contact info, voice ID enrollment
  - **General**: Branch locations, routing numbers, dispute transaction
- Implement proper error handling with fallback paths
- Add retry logic with exponential backoff
- Integrate with real CRM/core banking systems
- Add comprehensive logging (CloudWatch Insights)
- Implement circuit breakers for external APIs
- Add input validation and sanitization
- PCI-DSS compliance for payment card data handling
- Session management for multi-turn conversations

#### 3. **Routing and Queue Management**

**Current State:**
```terraform
# Single routing profile with fixed concurrency:
- Voice: 1 concurrent
- Chat: 2 concurrent
- Task: 10 concurrent

# Four generic queues:
- GeneralAgentQueue (catch-all)
- AccountQueue
- LendingQueue
- OnboardingQueue

# All queues use default hours of operation
# No skills-based routing
# No queue priority
# No overflow logic
```

**Required for Production:**
- **Multiple routing profiles** for different agent skill sets:
  - Tier 1 General Support (voice + chat)
  - Tier 2 Account Specialists (voice + chat)
  - Tier 3 Lending Experts (voice primary)
  - Fraud Team (voice only, priority)
  - Back Office Tasks (task only)
- **Enhanced queue configuration**:
  - Priority queuing (fraud = highest)
  - Queue-to-queue transfers
  - Overflow routing (after X minutes, route to general queue)
  - Maximum queue size limits
  - Queue position announcements every 30 seconds
- **Skills-based routing**:
  - Language skills (English, Spanish, Welsh for UK)
  - Product expertise (mortgages, business banking, investments)
  - Channel preference
- **Hours of operation**:
  - Business hours (9 AM - 5 PM local time)
  - Extended hours for fraud (24/7)
  - Holiday calendar
  - After-hours routing to voicemail or callback

#### 4. **Voice vs Chat Channel Separation**

**Current State:**
- Same flow used for both channels
- No channel-specific logic
- No differentiation in prompts

**Required for Production:**

**Voice Channel:**
- IVR menu with DTMF (press 1 for..., press 2 for...)
- Speech recognition for natural language input
- Longer, more descriptive prompts
- Hold music and queue announcements
- Transfer to agent with whisper (agent hears context before customer)
- Call recording with opt-in/opt-out
- Voice ID biometric authentication
- Post-call survey

**Chat Channel:**
- Conversational Lex bot as primary interface
- Shorter, concise messages
- Rich messages (buttons, cards)
- Typing indicators
- File attachment support (if needed)
- Co-browse capability references
- Quick reply suggestions
- Chat transcript via email
- Pre-chat form (name, email, issue)
- Post-chat survey

#### 5. **Security and Compliance**

**Current State:**
- Basic encryption (KMS, S3 server-side)
- CloudTrail for audit logs
- WAF for CCP protection
- Authentication framework exists but disabled

**Required for Production (Financial Services):**
- **Authentication**:
  - Enable Voice ID for biometric auth (already configured, need flows)
  - Implement PIN validation with retry limits (3 attempts)
  - Companion app push authentication
  - Account lockout after failed attempts
  - Session timeout (5 minutes inactivity)
- **Data Protection**:
  - PCI-DSS compliance for card data
  - Redact sensitive data in recordings/transcripts
  - Mask PII in logs (account numbers, SSN, etc.)
  - Encrypt data in transit (TLS 1.2+)
- **Access Control**:
  - Least privilege IAM roles
  - MFA for Connect admin access
  - Agent permission sets (view-only vs modify)
  - Security group restrictions
- **Compliance**:
  - GDPR compliance (for UK operations)
  - SOC 2 Type II alignment
  - Regular security assessments
  - Incident response procedures
  - Data retention policies
  - Right to deletion workflows

#### 6. **Error Handling and Resilience**

**Current State:**
- Basic error handling: disconnect on error
- No retry logic
- No graceful degradation
- No failover mechanisms

**Required for Production:**
- **Lambda resilience**:
  - Retry logic with exponential backoff
  - Circuit breakers for external APIs
  - Timeout configuration (3-5 seconds per call)
  - Dead letter queues for failed invocations
  - Health checks for dependencies
- **Flow error handling**:
  - Try-catch patterns for every external call
  - Graceful degradation (if CRM down, still transfer to agent)
  - Error-specific messages ("System temporarily unavailable")
  - Automatic escalation on repeated failures
  - Queue to callback if all agents busy
- **Monitoring and alerting**:
  - CloudWatch alarms for:
    - Lambda error rate > 5%
    - Queue wait time > 5 minutes
    - Abandoned call rate > 20%
    - API latency > 2 seconds
    - Failed authentication attempts
  - SNS notifications to operations team
  - PagerDuty integration for critical alerts

#### 7. **Lex Bot Improvements**

**Current State:**
```terraform
# Basic bot configuration:
- 4 intents (TransferToAgent, CheckBalance, LoanInquiry, OnboardingStatus)
- Minimal utterances per intent (3-5)
- No slots for data collection
- Confidence threshold: 0.40 (very low)
- No context carryover
- No multi-turn conversations
```

**Required for Production:**
- **Enhanced intents** (15-20 intents minimum):
  - Account inquiry intents with account type slot
  - Transaction history with date range slots
  - Card services with card type slot
  - Transfer money with amount and recipient slots
  - Fraud reporting with urgency classification
- **Comprehensive utterances** (20-30 per intent):
  - Natural language variations
  - Include typos and common misspellings
  - Slang and colloquialisms
  - Multi-intent utterances
- **Slots and validation**:
  - Account number (with regex validation)
  - Amount (currency format, min/max)
  - Date ranges (built-in date slot)
  - Custom slot types (account types, card types)
  - Slot validation prompts
- **Conversation flow**:
  - Context carryover between intents
  - Confirmation prompts for sensitive actions
  - Multi-turn conversations for complex requests
  - Clarification prompts when confidence low
- **Raise confidence threshold** to 0.70 for better accuracy
- **Add AMAZON.FallbackIntent** improvements:
  - Better Bedrock prompts for classification
  - Offer suggestions based on context
  - Escalate to agent after 2 failed attempts

#### 8. **Observability and Monitoring**

**Current State:**
- CloudWatch logs for Lambda
- Contact Lens enabled
- Basic CloudTrail auditing

**Required for Production:**
- **Real-time dashboards** (CloudWatch Dashboard):
  - Calls in queue by queue
  - Average wait time
  - Agent occupancy rate
  - Service level (% answered in 30 sec)
  - Abandonment rate
  - Top contact reasons (from Lex)
  - API error rates
- **Contact Lens analytics**:
  - Sentiment analysis
  - Call drivers and categories
  - Agent performance (silence time, talk time)
  - Compliance checks (required disclosures)
  - Keyword spotting (fraud keywords)
- **Custom metrics**:
  - Authentication success rate
  - Self-service completion rate
  - Transfer rate by intent
  - Lex confidence scores distribution
- **Log aggregation**:
  - CloudWatch Insights queries for:
    - Top errors by Lambda function
    - Slow API calls (> 2 seconds)
    - Failed authentication attempts by phone number
    - Intents not recognized (for bot training)
- **Alerting strategy**:
  - Critical: System down, fraud detected, security breach
  - High: Queue times > 5 min, error rate > 10%, all agents busy
  - Medium: Low agent availability, increased abandonment
  - Low: Informational metrics

#### 9. **Testing and Validation**

**Current State:**
- Manual testing only
- No automated tests
- No load testing

**Required for Production:**
- **Unit tests** for Lambda functions (pytest):
  - Mock CRM API responses
  - Test all intent handlers
  - Test error scenarios
  - Test authentication logic
- **Integration tests** for Lex bot:
  - Test all intents with sample utterances
  - Test slot elicitation
  - Test confirmation prompts
  - Test fallback behavior
- **Contact flow testing**:
  - Test all branches and error paths
  - Test voice and chat separately
  - Test hours of operation routing
  - Test queue overflow logic
- **Load testing** (AWS Load Testing solution):
  - Simulate 100 concurrent calls
  - Simulate 500 concurrent chats
  - Test queue behavior under load
  - Test Lambda scaling
  - Test Lex throttling limits (100 TPS default)
- **Security testing**:
  - Penetration testing
  - Authentication bypass attempts
  - SQL injection in inputs
  - WAF rule validation

## Implementation Priority

### Phase 1: Critical Foundation (Week 1-2)
1. ✅ Create modular contact flow architecture
2. ✅ Separate voice and chat entry flows
3. ✅ Enable authentication in Lambda
4. ✅ Add comprehensive error handling
5. ✅ Create multiple routing profiles
6. ✅ Add hours of operation and holiday routing

### Phase 2: Enhanced Functionality (Week 3-4)
1. ✅ Expand Lex intents to 15+ financial services intents
2. ✅ Implement skills-based routing
3. ✅ Add Voice ID and PIN authentication flows
4. ✅ Integrate real CRM/core banking APIs
5. ✅ Add callback functionality
6. ✅ Implement queue overflow logic

### Phase 3: Observability and Resilience (Week 5-6)
1. ✅ Build CloudWatch dashboards
2. ✅ Configure Contact Lens analytics
3. ✅ Add comprehensive alerting
4. ✅ Implement circuit breakers and retries
5. ✅ Add dead letter queues
6. ✅ Create runbooks for common issues

### Phase 4: Testing and Optimization (Week 7-8)
1. ✅ Write and execute unit tests
2. ✅ Perform integration testing
3. ✅ Conduct load testing
4. ✅ Security assessment
5. ✅ Performance tuning
6. ✅ Documentation completion

## Detailed Recommendations

### Modular Flow Architecture

Create the following reusable flow modules:

1. **Voice Entry Flow** (`voice_entry_flow.json`)
   - Set contact attributes (channel=voice)
   - Check hours of operation
   - Play welcome message
   - Check if callback scheduled
   - Route to Voice IVR or After Hours flow

2. **Voice IVR Flow** (`voice_ivr_flow.json`)
   - Present menu: "Press 1 for accounts, 2 for cards, 3 for loans, 4 for fraud, 0 for agent"
   - DTMF input with timeout
   - Route to Lex Bot by selected category
   - Option to repeat menu

3. **Chat Entry Flow** (`chat_entry_flow.json`)
   - Set contact attributes (channel=chat)
   - Check hours of operation
   - Send welcome message
   - Collect pre-chat form (optional)
   - Route to Lex Bot

4. **Authentication Module** (`auth_module_flow.json`)
   - Check if already authenticated (session attribute)
   - Offer authentication methods:
     - Voice ID (if voice channel)
     - PIN entry
     - Companion app push
   - Validate and set authentication flag
   - Return to calling flow

5. **Lex Interaction Flow** (`lex_interaction_flow.json`)
   - Connect participant to Lex bot
   - Handle Lex errors gracefully
   - On TransferToAgent intent, route to queue routing
   - On Fulfilled, check if more help needed
   - Loop up to 3 times, then offer agent transfer

6. **Queue Routing Module** (`queue_routing_flow.json`)
   - Determine target queue based on:
     - Intent name
     - Customer attributes (VIP, language)
     - Agent availability
   - Check queue capacity
   - Transfer to queue or offer callback
   - Set queue priority if fraud/urgent

7. **Agent Transfer Flow** (`agent_transfer_flow.json`)
   - Set agent whisper with customer context
   - Transfer to queue
   - Handle transfer failures (all agents busy)
   - Offer callback option
   - Play hold music and position announcements

8. **Callback Module** (`callback_module_flow.json`)
   - Collect callback number (or use ANI)
   - Collect preferred time
   - Create callback task
   - Confirm callback scheduled
   - Send SMS confirmation

9. **After Hours Flow** (`after_hours_flow.json`)
   - Play after-hours message
   - Offer callback during business hours
   - For fraud/urgent, transfer to 24/7 queue
   - For general, offer voicemail

10. **Survey Flow** (`survey_flow.json`)
    - Ask satisfaction rating (1-5)
    - Collect feedback (speech/text)
    - Store in DynamoDB
    - Thank customer

### Lambda Function Enhancements

#### Enhanced Intent Handlers

Create separate handler files for each domain:

**`handlers/account_handlers.py`**:
```python
def handle_check_balance(event, customer_data):
    """
    Check account balance with proper error handling.
    - Validate customer authentication
    - Call core banking API
    - Handle API errors gracefully
    - Return formatted balance
    """
    
def handle_transaction_history(event, customer_data):
    """
    Retrieve transaction history with date range.
    - Elicit date range slots
    - Validate date format
    - Call core banking API with pagination
    - Return summary (email full details)
    """
    
def handle_account_details(event, customer_data):
    """
    Provide account details (routing, account number).
    - Verify authentication level (high security)
    - Retrieve from CRM
    - Mask sensitive data in logs
    """
```

**`handlers/card_handlers.py`**:
```python
def handle_card_activation(event, customer_data):
    """Activate new card with last 4 digits validation"""
    
def handle_lost_stolen_card(event, customer_data):
    """Block card immediately, escalate to fraud if needed"""
    
def handle_fraud_report(event, customer_data):
    """
    High priority fraud reporting.
    - Immediately block card
    - Create fraud ticket
    - Escalate to fraud queue
    - Send SMS confirmation
    """
```

**`handlers/transfer_handlers.py`**:
```python
def handle_internal_transfer(event, customer_data):
    """Transfer between customer's own accounts"""
    
def handle_external_transfer(event, customer_data):
    """Transfer to external account with confirmation"""
```

#### Error Handling Pattern

```python
import functools
import time
from typing import Callable

def with_retry(max_attempts=3, backoff_factor=2):
    """Decorator for retry logic with exponential backoff"""
    def decorator(func: Callable):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except TransientError as e:
                    if attempt == max_attempts - 1:
                        raise
                    sleep_time = backoff_factor ** attempt
                    time.sleep(sleep_time)
                    logger.warning(f"Retry {attempt + 1}/{max_attempts} after {sleep_time}s")
                except PermanentError:
                    raise
            return None
        return wrapper
    return decorator

@with_retry(max_attempts=3)
def call_core_banking_api(account_id):
    """Call with automatic retry"""
    response = requests.get(f"{API_URL}/accounts/{account_id}", timeout=5)
    if response.status_code >= 500:
        raise TransientError("API temporarily unavailable")
    elif response.status_code >= 400:
        raise PermanentError("Invalid request")
    return response.json()
```

#### Circuit Breaker Implementation

```python
class CircuitBreaker:
    """
    Prevent cascading failures when external service is down.
    States: CLOSED (normal), OPEN (failing), HALF_OPEN (testing)
    """
    def __init__(self, failure_threshold=5, timeout=60):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.failures = 0
        self.last_failure_time = None
        self.state = 'CLOSED'
    
    def call(self, func, *args, **kwargs):
        if self.state == 'OPEN':
            if time.time() - self.last_failure_time > self.timeout:
                self.state = 'HALF_OPEN'
            else:
                raise CircuitOpenError("Circuit breaker is OPEN")
        
        try:
            result = func(*args, **kwargs)
            self.on_success()
            return result
        except Exception as e:
            self.on_failure()
            raise
    
    def on_success(self):
        self.failures = 0
        self.state = 'CLOSED'
    
    def on_failure(self):
        self.failures += 1
        self.last_failure_time = time.time()
        if self.failures >= self.failure_threshold:
            self.state = 'OPEN'
            logger.error(f"Circuit breaker opened after {self.failures} failures")
```

### Enhanced Lex Bot Configuration

#### New Intent Structure

```python
# In variables.tf, expand lex_intents:
lex_intents = {
  # Account Services
  CheckBalance = {
    description = "Check account balance"
    utterances = [
      "what is my balance",
      "check my balance",
      "how much money do I have",
      "account balance",
      "show me my balance",
      # ... 20+ more variations
    ]
    slots = {
      AccountType = {
        type = "AMAZON.AlphaNumeric"
        prompt = "Which account? Checking or savings?"
        required = true
      }
    }
    fulfillment_enabled = true
  }
  
  TransactionHistory = {
    description = "Get recent transactions"
    utterances = [
      "show my transactions",
      "recent transactions",
      "what did I spend",
      "transaction history",
      # ... more variations
    ]
    slots = {
      DateRange = {
        type = "AMAZON.Date"
        prompt = "For which date range?"
        required = false
      }
    }
    fulfillment_enabled = true
  }
  
  ReportFraud = {
    description = "Report fraudulent activity"
    utterances = [
      "report fraud",
      "fraudulent charge",
      "I didn't make this transaction",
      "suspicious activity",
      "my card was stolen",
      # ... more variations
    ]
    fulfillment_enabled = true
    priority = "high"  # Custom attribute for routing
  }
  
  # ... 12 more intents
}
```

## Cost Estimation

### Current Monthly Costs (Development):
- Connect: ~$50 (light testing)
- Lex: ~$20 (< 1000 requests)
- Lambda: ~$5 (< 10K invocations)
- S3: ~$10 (minimal storage)
- CloudWatch: ~$15 (basic logs)
- **Total: ~$100/month**

### Projected Production Costs (1000 contacts/day):
- Connect: ~$400 (voice) + ~$200 (chat) = $600
  - Voice: $0.018/minute × 5 min avg × 600 calls/day × 30 days
  - Chat: $0.004/message × 10 messages avg × 400 chats/day × 30 days
- Lex: ~$150
  - $0.00075/request × 10 requests/contact × 1000 contacts × 30 days
- Lambda: ~$50
  - $0.20 per 1M requests × 250K requests/month
- Contact Lens: ~$300
  - $0.015/minute analyzed × 5 min × 600 calls × 30 days
- S3: ~$50 (recordings, transcripts)
- CloudWatch: ~$100 (detailed monitoring)
- Bedrock (fallback): ~$50 (claude-3-haiku)
- **Total: ~$1,300/month**

## Success Metrics

### Operational KPIs:
- Service Level: ≥ 80% answered in 30 seconds
- Abandonment Rate: ≤ 5%
- Average Handle Time: 4-6 minutes
- First Contact Resolution: ≥ 75%
- Self-Service Rate: ≥ 40%
- Customer Satisfaction: ≥ 4.0/5.0

### Technical KPIs:
- System Uptime: 99.9%
- API Error Rate: < 1%
- Lambda Error Rate: < 0.5%
- Lex Confidence Score: ≥ 0.75 average
- Authentication Success Rate: ≥ 95%
- Average API Latency: < 500ms

## Next Steps

1. **Review and approve** this analysis
2. **Prioritize** features based on business criticality
3. **Begin Phase 1 implementation** with modular flows
4. **Schedule** weekly progress reviews
5. **Plan** testing and staging environment
6. **Define** rollout strategy (pilot with 10% traffic)
7. **Establish** operations runbooks

## Appendix: Reference Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         CUSTOMER CHANNELS                        │
│         Phone (PSTN/SIP)        Chat (Web/Mobile App)           │
└───────────────────────┬──────────────────────┬──────────────────┘
                        │                      │
                        ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     AWS CONNECT INSTANCE                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Voice Entry Flow  →  Voice IVR  →  Auth Module          │  │
│  │  Chat Entry Flow   →  Lex Bot    →  Queue Routing        │  │
│  │                                                            │  │
│  │  [Hours Check] [Holiday Check] [Callback] [Survey]        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          ▼                                       │
│                    [Agent Queues]                                │
│          General | Account | Lending | Fraud (24/7)             │
└───────────────────────────┬─────────────────────────────────────┘
                            │
        ┌───────────────────┼────────────────────┐
        ▼                   ▼                    ▼
┌──────────────┐   ┌──────────────────┐   ┌────────────────┐
│  LEX V2 BOT  │   │  ROUTING ENGINE  │   │  AGENT (CCP)   │
│  15+ Intents │   │  Skills-Based    │   │  CloudFront    │
│  Multi-Locale│   │  Priority Queue  │   │  + WAF         │
└──────┬───────┘   └──────────────────┘   └────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────┐
│                    LAMBDA FULFILLMENT                             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │ Auth Handler │ │ Account Hdlr │ │  Card/Fraud Handlers     │ │
│  │ - Voice ID   │ │ - Balance    │ │  - Block Card            │ │
│  │ - PIN        │ │ - Txn Hist   │ │  - Report Fraud          │ │
│  │ - Companion  │ │ - Details    │ │  - PIN Change            │ │
│  └──────┬───────┘ └──────┬───────┘ └──────────┬───────────────┘ │
└─────────┼────────────────┼────────────────────┼──────────────────┘
          │                │                    │
          ▼                ▼                    ▼
┌──────────────────────────────────────────────────────────────────┐
│                    BACKEND INTEGRATIONS                           │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │  DynamoDB    │ │   CRM API    │ │  Core Banking System     │ │
│  │  Auth State  │ │  Customer    │ │  Accounts/Cards/Loans    │ │
│  │  Intent Log  │ │  Profile     │ │  Real-time Balance       │ │
│  └──────────────┘ └──────────────┘ └──────────────────────────┘ │
│                                                                   │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │  Bedrock     │ │  S3 Storage  │ │  SNS Notifications       │ │
│  │  Fallback    │ │  Recordings  │ │  Push Auth               │ │
│  │  Classify    │ │  Transcripts │ │  SMS/Email               │ │
│  └──────────────┘ └──────────────┘ └──────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY LAYER                            │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │  CloudWatch  │ │ Contact Lens │ │  CloudTrail              │ │
│  │  Dashboards  │ │  Analytics   │ │  Audit Logs              │ │
│  │  Alarms      │ │  Sentiment   │ │  Compliance              │ │
│  └──────────────┘ └──────────────┘ └──────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Prepared By**: GitHub Copilot  
**Status**: Draft for Review
