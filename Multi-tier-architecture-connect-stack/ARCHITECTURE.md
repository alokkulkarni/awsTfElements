# Architecture Document - Contact Center in a Box

## Executive Summary

The Contact Center in a Box is a comprehensive, modular AWS solution that provides enterprise-grade contact center capabilities with intelligent routing, AI-powered assistance, and scalable infrastructure. Built entirely with Terraform, this solution enables rapid deployment of a fully functional contact center supporting both voice and chat channels.

## Design Principles

### 1. Modularity
- Each component is a standalone Terraform module
- Modules can be deployed independently or together
- Clear interfaces between modules using outputs/inputs

### 2. Security First
- Least privilege IAM roles for all services
- Encrypted storage for all data
- PII protection through Bedrock guardrails
- Secure credential management

### 3. Scalability
- Horizontal scaling through queue and agent management
- Stateless Lambda functions
- Support for multi-region deployment (future)
- Version-controlled bot and Lambda deployments

### 4. Maintainability
- Infrastructure as Code (Terraform)
- Parameterized configuration
- Comprehensive documentation
- Clear naming conventions

### 5. Cost Optimization
- Pay-per-use pricing model
- Efficient resource utilization
- Auto-scaling capabilities
- Configurable retention policies

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          CUSTOMER CHANNELS                           │
│                   Voice │ Chat │ Email │ Social                      │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS CONNECT INSTANCE                          │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Contact Flows (Entry Points)                     │  │
│  │  • Main Flow: Primary routing logic                           │  │
│  │  • Customer Queue Flow: Hold experience                       │  │
│  │  • Callback Flow: Callback management                         │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Storage Layer (S3)                               │  │
│  │  • Call Recordings • Chat Transcripts • CTRs                  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└────────┬──────────────────────────────┬────────────────────────────┘
         │                              │
         │ Lex Integration              │ Lambda Integration
         ▼                              ▼
┌─────────────────────────┐    ┌────────────────────────────┐
│    LEX BOT LAYER       │    │   BEDROCK AGENT LAYER      │
│                         │    │   (Fallback Handler)       │
│  ┌──────────────────┐  │    │                            │
│  │ Concierge Bot    │  │    │  Banking Assistant Agent   │
│  │ (Primary Router) │◄─┼────┤  • Intent Classification   │
│  └─────┬────────────┘  │    │  • Product Information     │
│        │                │    │  • Query Understanding     │
│        │                │    │                            │
│  ┌─────┴────────────┐  │    │  With Guardrails:          │
│  │  Domain Bots     │  │    │  • Content Filtering       │
│  ├──────────────────┤  │    │  • PII Protection          │
│  │ • Banking Bot    │  │    │  • Topic Control           │
│  │ • Product Bot    │  │    │  • Word Filtering          │
│  │ • Sales Bot      │  │    └────────────────────────────┘
│  └─────┬────────────┘  │
└────────┼────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      LAMBDA FULFILLMENT LAYER                        │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐            │
│  │  Banking    │    │  Product    │    │   Sales     │            │
│  │  Lambda     │    │  Lambda     │    │   Lambda    │            │
│  │             │    │             │    │             │            │
│  │ • Balance   │    │ • Info      │    │ • New Acct  │            │
│  │ • Txn Hist  │    │ • Compare   │    │ • Upgrade   │            │
│  │ • Cards     │    │ • Features  │    │ • Offers    │            │
│  │ • Branches  │    │ • Avail     │    │ • Pricing   │            │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘            │
└─────────┼──────────────────┼──────────────────┼────────────────────┘
          │                  │                  │
          └──────────────────┴──────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           QUEUE LAYER                                │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │ Banking │  │ Product │  │  Sales  │  │ General │  │Callback │ │
│  │  Queue  │  │  Queue  │  │  Queue  │  │  Queue  │  │  Queue  │ │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘ │
└───────┼────────────┼────────────┼────────────┼────────────┼────────┘
        │            │            │            │            │
        └────────────┴────────────┴────────────┴────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        ROUTING LAYER                                 │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │            Routing Profiles                                   │  │
│  │  • Priority-based routing                                     │  │
│  │  • Skills-based routing (future)                              │  │
│  │  • Channel-specific concurrency                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AGENT LAYER                                  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Contact Control Panel (CCP)                                  │  │
│  │  • Voice Controls • Chat Interface • Customer Context         │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  Roles:                                                               │
│  • Admin (Full Access)                                                │
│  • Call Center Manager (Management + Metrics)                         │
│  • Security Officer (Audit + Monitoring)                              │
│  • Agent (Contact Handling)                                           │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY LAYER                               │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  CloudWatch Logs                                              │  │
│  │  • Connect Logs • Lex Logs • Lambda Logs • Bedrock Logs      │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  CloudWatch Metrics                                           │  │
│  │  • Call Metrics • Queue Metrics • Agent Metrics               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Contact Lens (Optional)                                      │  │
│  │  • Sentiment Analysis • Transcription • Analytics             │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. AWS Connect Instance

**Purpose**: Core contact center platform

**Components**:
- Instance configuration with alias
- Storage configuration (S3)
- Hours of operation (24/7)
- Phone number claims
- Security profiles and users
- Routing profiles

**Key Features**:
- Inbound/outbound calling
- Chat support
- Contact flow engine
- CTR generation
- Contact Lens integration

### 2. Lex Bot Layer

#### Concierge Bot (Primary Router)

**Purpose**: First point of contact for all customers

**Responsibilities**:
- Greet customers
- Understand initial intent
- Route to domain-specific bots
- Handle simple queries directly
- Fallback to Bedrock for complex queries

**Intents**:
- RouteToSpecialistIntent
- FallbackIntent (→ Bedrock)

#### Domain-Specific Bots

**Banking Bot**:
- AccountBalanceIntent
- TransactionHistoryIntent
- AccountOpeningIntent
- BranchFinderIntent
- CardIssueIntent

**Product Bot**:
- ProductInformationIntent
- ProductComparisonIntent
- ProductFeaturesIntent
- ProductAvailabilityIntent

**Sales Bot**:
- NewAccountIntent
- UpgradeAccountIntent
- SpecialOffersIntent
- PricingInquiryIntent

### 3. Lambda Fulfillment Layer

**Architecture**: Stateless, event-driven functions

**Common Pattern**:
```python
def lambda_handler(event, context):
    1. Extract intent and slots from event
    2. Route to appropriate handler
    3. Process business logic
    4. Set session attributes (queue, priority, context)
    5. Return Lex response
```

**Key Features**:
- Domain-specific handlers
- Error handling and logging
- Session attribute management
- Queue routing logic
- Context enrichment for agents

### 4. Bedrock Agent (Fallback Handler)

**Purpose**: AI-powered intent classification and assistance

**Capabilities**:
1. **Intent Classification**:
   - Analyzes unclear queries
   - Categorizes into domains
   - Provides confidence scores

2. **Product Information**:
   - Account opening processes
   - Branch finding
   - Product features
   - Banking services

3. **Query Understanding**:
   - Natural language comprehension
   - Context extraction
   - Entity recognition

**Guardrails**:
- Content filtering (hate, violence, etc.)
- PII protection
- Topic restrictions
- Word filtering

### 5. Queue Management

**Queue Types**:

| Queue    | Purpose                  | Priority | Max Contacts |
|----------|--------------------------|----------|--------------|
| Banking  | Banking services         | High     | 15           |
| Product  | Product information      | Medium   | 10           |
| Sales    | Sales inquiries          | High     | 12           |
| General  | Unclassified contacts    | Low      | 10           |
| Callback | Callback requests        | Medium   | 5            |

**Routing Logic**:
1. Intent identified by bot
2. Lambda sets queue attribute
3. Contact flow routes to queue
4. Agent assigned based on routing profile
5. Context passed to agent

### 6. Security Architecture

#### IAM Roles and Policies

**Connect Role**:
```json
{
  "Permissions": [
    "lex:PostContent/PostText",
    "lambda:InvokeFunction",
    "logs:CreateLogStream/PutLogEvents",
    "s3:GetObject/PutObject"
  ]
}
```

**Lex Role**:
```json
{
  "Permissions": [
    "polly:SynthesizeSpeech",
    "lambda:InvokeFunction",
    "bedrock:InvokeAgent",
    "logs:CreateLogStream/PutLogEvents"
  ]
}
```

**Lambda Role**:
```json
{
  "Permissions": [
    "logs:CreateLogStream/PutLogEvents",
    "dynamodb:GetItem/PutItem",
    "connect:GetContactAttributes/UpdateContactAttributes"
  ]
}
```

**Bedrock Role**:
```json
{
  "Permissions": [
    "bedrock:InvokeModel",
    "logs:CreateLogStream/PutLogEvents",
    "s3:GetObject"
  ]
}
```

#### Data Security

**Encryption at Rest**:
- S3: AES-256
- CloudWatch Logs: AWS managed keys
- Connect: AWS managed keys

**Encryption in Transit**:
- TLS 1.2+ for all API calls
- Encrypted signaling for calls
- HTTPS for all web interfaces

**Access Control**:
- IAM policies (least privilege)
- Security profiles in Connect
- S3 bucket policies
- VPC endpoints (optional)

### 7. Integration Layer

**Bot Associations**:
- Registers Lex bot aliases with Connect
- Maps bot versions to environments (prod/test)
- Enables bot invocation from contact flows

**Lambda Associations**:
- Registers Lambda functions with Connect
- Enables direct Lambda invocation from flows
- Manages permissions

## Data Flow Diagrams

### Voice Call Flow

```
Customer Dials → Connect Answers → Main Contact Flow
                                          │
                                          ▼
                                   Invoke Concierge Bot
                                          │
                         ┌────────────────┼────────────────┐
                         ▼                ▼                ▼
                    Banking          Product          Sales
                      Bot              Bot             Bot
                         │                │                │
                         ▼                ▼                ▼
                    Banking          Product          Sales
                     Lambda           Lambda          Lambda
                         │                │                │
                         ▼                ▼                ▼
                  Set Queue to      Set Queue to    Set Queue to
                    "banking"        "product"        "sales"
                         │                │                │
                         └────────────────┼────────────────┘
                                          │
                                          ▼
                                   Route to Queue
                                          │
                                          ▼
                                   Assign to Agent
                                          │
                                          ▼
                                   Agent Handles
                                          │
                                          ▼
                                    Call Ends
```

### Chat Flow

```
Customer Opens Chat → Connect Chat API → Main Contact Flow
                                                │
                                                ▼
                                         Invoke Concierge Bot
                                                │
                                                ▼
                                         [Same as Voice]
                                                │
                                                ▼
                                         Route to Queue
                                                │
                                                ▼
                                         Agent Receives
                                                │
                                                ▼
                                         Chat Conversation
                                                │
                                                ▼
                                         Chat Ends
                                                │
                                                ▼
                                         Save Transcript
```

### Fallback Flow (Bedrock)

```
Concierge Bot → Intent Not Confident → FallbackIntent Triggered
                                             │
                                             ▼
                                    Invoke Bedrock Agent
                                             │
                                             ▼
                                    Bedrock Analyzes Query
                                             │
                         ┌───────────────────┼───────────────────┐
                         ▼                   ▼                   ▼
                    Classified:         Classified:         Classified:
                      Banking            Product              Sales
                         │                   │                   │
                         └───────────────────┼───────────────────┘
                                             │
                                             ▼
                                    Return to Contact Flow
                                             │
                                             ▼
                                    Route Based on Classification
```

## Deployment Architecture

### Terraform Module Structure

```
Root Module (main.tf)
├── Module: IAM
│   ├── Outputs: role ARNs
│   └── Dependencies: None
│
├── Module: Lambda
│   ├── Inputs: lambda_role_arn
│   ├── Outputs: function ARNs
│   └── Dependencies: IAM
│
├── Module: Lex
│   ├── Inputs: lex_role_arn, lambda ARNs
│   ├── Outputs: bot IDs, alias ARNs
│   └── Dependencies: IAM, Lambda
│
├── Module: Bedrock
│   ├── Inputs: bedrock_role_arn
│   ├── Outputs: agent ARN, guardrail ID
│   └── Dependencies: IAM
│
├── Module: Connect
│   ├── Inputs: None (minimal dependencies)
│   ├── Outputs: instance ID, queue IDs
│   └── Dependencies: IAM
│
├── Module: Contact Flows
│   ├── Inputs: connect_instance_id
│   ├── Outputs: flow ARNs
│   └── Dependencies: Connect
│
└── Module: Integration
    ├── Inputs: connect_instance_id, bot ARNs, lambda ARNs
    ├── Outputs: association IDs
    └── Dependencies: Connect, Lex, Lambda
```

### Dependency Graph

```
IAM
 ├── Lambda
 │    └── Lex
 │         └── Integration
 ├── Bedrock
 └── Connect
      ├── Contact Flows
      └── Integration
```

## Scalability Considerations

### Horizontal Scaling

**Queues**:
- Add new queues via `terraform.tfvars`
- No code changes required
- Automatic routing profile updates

**Agents**:
- Add users via `terraform.tfvars`
- Assign to appropriate security profiles
- Configure routing profiles

**Bots**:
- Add new domain bots as modules
- Create corresponding Lambda functions
- Update integrations

### Vertical Scaling

**Lambda**:
- Increase memory_size
- Adjust timeout
- Configure reserved concurrency

**Connect**:
- Adjust max_contacts per queue
- Configure multiple routing profiles
- Add hours of operation configurations

## High Availability

### Component Availability

| Component | HA Strategy | RTO | RPO |
|-----------|-------------|-----|-----|
| Connect   | AWS Managed | < 1min | 0 |
| Lex       | AWS Managed | < 1min | 0 |
| Lambda    | Multi-AZ    | < 1min | 0 |
| Bedrock   | AWS Managed | < 1min | 0 |
| S3        | 99.99%      | < 1min | 0 |

### Disaster Recovery

**Backup Strategy**:
- Terraform state in S3 backend (recommended)
- Daily state file backups
- Contact flow exports
- Configuration backups

**Recovery Procedure**:
1. Restore Terraform state
2. Run `terraform apply`
3. Import contact flows
4. Verify integrations
5. Test functionality

## Performance Optimization

### Lambda

**Cold Start Mitigation**:
- Use provisioned concurrency for critical functions
- Keep functions warm with CloudWatch Events
- Optimize package size

**Execution Optimization**:
- Efficient code patterns
- Connection pooling
- Caching strategies

### Lex

**Response Time**:
- Optimize intent structure
- Minimize slot elicitation
- Use slot type optimization

### Connect

**Call Quality**:
- Regional endpoints
- Adequate queue sizes
- Appropriate timeout settings

## Monitoring and Alerting

### Key Metrics

**Connect Metrics**:
- CallsPerInterval
- MissedCalls
- AbandonmentRate
- AverageHandleTime
- AverageQueueAnswerTime

**Lambda Metrics**:
- Invocations
- Errors
- Duration
- ConcurrentExecutions

**Lex Metrics**:
- RuntimeRequestCount
- RuntimeIntentCount
- RuntimeSlotCount
- RuntimeSessions

**Bedrock Metrics**:
- Invocations
- Latency
- Errors
- GuardrailActions

### Recommended Alarms

```hcl
# High error rate alarm
alarm_lambda_errors_high

# Queue overflow alarm
alarm_queue_full

# Agent unavailable alarm
alarm_no_available_agents

# High abandon rate alarm
alarm_abandon_rate_high
```

## Cost Optimization

### Cost Breakdown

**Connect**:
- Per-minute charges for voice
- Per-message charges for chat
- Monthly service fee

**Lex**:
- Per-request pricing
- Text and voice requests
- No per-bot charges

**Lambda**:
- Per-invocation
- Per-GB-second

**Bedrock**:
- Per-1000 input tokens
- Per-1000 output tokens
- Model-dependent pricing

### Optimization Strategies

1. **Right-size Lambda functions**
2. **Use bot session caching**
3. **Implement efficient Lex designs**
4. **Configure appropriate log retention**
5. **Use S3 lifecycle policies**
6. **Monitor and adjust concurrency**

## Future Enhancements

### Planned Features

1. **Multi-Region Support**
   - Active-active configuration
   - Regional failover
   - Data residency compliance

2. **Advanced Analytics**
   - Custom dashboards
   - Predictive analytics
   - Sentiment analysis integration

3. **Skills-Based Routing**
   - Agent skills matrix
   - Dynamic routing
   - Workload balancing

4. **CRM Integration**
   - Salesforce connector
   - Dynamics 365 integration
   - Screen pop configuration

5. **Advanced AI Features**
   - Voice biometrics
   - Real-time translation
   - Automated summarization

## Compliance and Governance

### Compliance Considerations

- **GDPR**: Data residency, right to deletion
- **PCI DSS**: Secure payment handling
- **HIPAA**: PHI protection (if applicable)
- **SOC 2**: Audit trails and logging

### Governance

- **Tagging Strategy**: All resources tagged
- **Naming Conventions**: Consistent naming
- **Access Control**: Role-based access
- **Change Management**: Infrastructure as Code

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Maintained By**: Infrastructure Team
