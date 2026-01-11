# AWS Connect Comprehensive Stack - Deployment Sequence

## Overview
This document visualizes the complete deployment sequence showing which resources are created sequentially (dependencies) vs in parallel (independent).

---

## Deployment Phases

### **PHASE 1: Foundation Layer** ⚡ (All in Parallel)
*No dependencies - can be created simultaneously*

```
                    ┌─────────────────────────┐
                    │     Data Sources        │
                    │   (instant queries)     │
                    └───────────┬─────────────┘
                                │
                ┌───────────────┼───────────────┬───────────────┐
                │               │               │               │
                ▼               ▼               ▼               ▼
    ┌──────────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │   IAM Roles &    │ │  S3 Buckets  │ │   KMS Keys   │ │  CloudWatch  │
    │    Policies      │ │              │ │              │ │ Log Groups   │
    └──────────────────┘ └──────────────┘ └──────────────┘ └──────────────┘

                        ⚡ ALL CREATED IN PARALLEL ⚡
```

**Resources Created:**
- ✅ **Data Sources** (instant - queries existing resources):
  - `data.aws_caller_identity.current`
  - `data.aws_region.current`
  - `data.archive_file.*` (Lambda ZIP files)
  
- ✅ **S3 Buckets** (parallel):
  - `module.connect_storage_bucket` - Call recordings, chat transcripts
  - `module.cloudtrail_bucket` - Audit logs
  - `module.datalake_bucket` - Analytics data
  - `module.recording_bucket` - Call recordings with lifecycle
  - `module.transcript_bucket` - Chat/voice transcripts
  - `module.reports_bucket` - Generated reports
  - `aws_s3_bucket.ccp_site` - CCP web interface

- ✅ **IAM Roles** (parallel):
  - `aws_iam_role.lambda_role` - Main Lambda execution role
  - `aws_iam_role.auth_api_role` - Auth API Gateway Lambda
  - `aws_iam_role.crm_api_role` - CRM API Lambda
  - `aws_iam_role.banking_lambda_role` - Banking bot fulfillment
  - `aws_iam_role.sales_lambda_role` - Sales bot fulfillment
  - `aws_iam_role.callback_lambda_role` - Callback API
  - `aws_iam_role.callback_dispatcher_role` - Callback dispatcher
  - `aws_iam_role.eventbridge_firehose_role` - EventBridge → Firehose

- ✅ **CloudWatch Log Groups** (parallel):
  - `aws_cloudwatch_log_group.bedrock_mcp`
  - `aws_cloudwatch_log_group.lex_logs`
  - `aws_cloudwatch_log_group.banking_lex_logs`
  - `aws_cloudwatch_log_group.sales_lex_logs`
  - `aws_cloudwatch_log_group.auth_api_gw`

- ✅ **DynamoDB Tables** (parallel):
  - `module.conversation_history_table`
  - `module.hallucination_logs_table`
  - `module.callback_table`
  - `module.auth_state_table`

- ✅ **SNS Topics** (parallel):
  - `module.alarm_sns_topic` - CloudWatch alarms
  - `module.auth_sns_topic` - Auth notifications

**Deployment Time:** ~30-60 seconds

---

### **PHASE 2: Connect Instance & Streaming Infrastructure** 🔄
*Depends on: S3 buckets, IAM roles*

```
                    ┌─────────────────────────┐
                    │   Phase 1 Complete      │
                    │  (Foundation Ready)     │
                    └───────────┬─────────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
                ▼                               ▼
    ┌──────────────────────┐        ┌──────────────────────┐
    │  Connect Instance    │        │  Kinesis Streams     │
    │                      │        │  (CTR, Agent, AI)    │
    └──────────┬───────────┘        └──────────┬───────────┘
               │                               │
               │                               ▼
               │                    ┌──────────────────────┐
               │                    │  Kinesis Firehose    │
               │                    │  (→ S3 delivery)     │
               │                    └──────────┬───────────┘
               │                               │
               └───────────────┬───────────────┘
                               │
                               ▼
                   ┌──────────────────────────┐
                   │ Connect Storage Config   │
                   │ (CTR, Recordings, Chat)  │
                   └──────────────────────────┘
```

**Resources Created:**
- ✅ **Connect Instance**:
  - `module.connect_instance.aws_connect_instance.this`
  - Settings: Inbound/Outbound calls, Contact Lens, Early media, Auto-resolve best available agent

- ✅ **Kinesis Streams** (parallel):
  - `module.kinesis_ctr` - Contact Trace Records (4 shards, 168h retention)
  - `module.kinesis_agent_events` - Agent status changes (2 shards, 24h retention)
  - `module.kinesis_ai_reporting` - AI insights (1 shard, 24h retention)

- ✅ **Kinesis Firehose Delivery Streams** (depends on Kinesis + S3):
  - `module.firehose_ctr` → S3 `ctr/` prefix
  - `module.firehose_agent_events` → S3 `agent-events/` prefix
  - `module.firehose_ai_reporting` → S3 `ai-insights/` prefix
  - `module.firehose_lifecycle_events` → S3 `lifecycle-events/` prefix

- ✅ **Connect Storage Configuration** (depends on Connect Instance + Kinesis):
  - `aws_connect_instance_storage_config.ctr_stream` - CTR streaming
  - `aws_connect_instance_storage_config.agent_events_stream` - Agent events
  - `aws_connect_instance_storage_config.call_recordings` - S3 recording storage
  - `aws_connect_instance_storage_config.chat_transcripts` - S3 chat storage

**Deployment Time:** ~2-3 minutes (Connect instance creation is slowest)

---

### **PHASE 3: Lambda Functions & API Gateways** 🔧
*Depends on: IAM roles, S3 buckets (for code)*

```
                    ┌─────────────────────────┐
                    │   Phase 1 Complete      │
                    └───────────┬─────────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
                ▼                               ▼
    ┌──────────────────────┐        ┌──────────────────────┐
    │   Lambda Build       │        │   API Gateways       │
    │ (bedrock_mcp, etc)   │        │ (Auth, CRM)          │
    └──────────┬───────────┘        └──────────┬───────────┘
               │                               │
               ▼                               │
    ┌──────────────────────┐                  │
    │  Lambda Functions    │                  │
    │  (6 functions)       │                  │
    └──────────┬───────────┘                  │
               │                               │
               ▼                               │
    ┌──────────────────────┐                  │
    │   Lambda Aliases     │                  │
    │   (live versions)    │                  │
    └──────────┬───────────┘                  │
               │                               │
               └───────────────┬───────────────┘
                               │
                               ▼
                   ┌──────────────────────────┐
                   │   Lambda Permissions     │
                   │ (Lex, Connect, API GW)   │
                   └──────────────────────────┘
```

**Resources Created:**

**Lambda Build Steps** (sequential per function):
1. `null_resource.bedrock_mcp_build` - Build Lambda code
2. `null_resource.bedrock_mcp_publish` - Publish new version
3. `null_resource.bedrock_mcp_update_alias` - Update live alias

**Lambda Functions** (parallel):
- ✅ `module.bedrock_mcp_lambda.aws_lambda_function.this`
  - Runtime: Python 3.12 / 3GB memory / 900s timeout
  - VPC-enabled, provisioned concurrency
  - Env vars: Bedrock model ID, DynamoDB tables, Kinesis stream
  
- ✅ `module.banking_lambda.aws_lambda_function.this`
  - Banking bot fulfillment (check balance, transfer money, etc.)
  
- ✅ `module.sales_lambda.aws_lambda_function.this`
  - Sales bot fulfillment (product info, pricing)
  
- ✅ `module.callback_lambda.aws_lambda_function.this`
  - Handle callback requests
  
- ✅ `module.callback_dispatcher.aws_lambda_function.this`
  - Process callback queue
  
- ✅ `module.auth_api_lambda.aws_lambda_function.this`
  - Authentication API handler

**Lambda Aliases** (depends on Lambda functions):
- `aws_lambda_alias.bedrock_mcp_live`
- `aws_lambda_alias.banking_live`
- `aws_lambda_alias.sales_live`

**API Gateways** (parallel):
- ✅ `module.auth_api_gateway` - HTTP API for authentication
- ✅ `module.crm_api_gateway` - (if enabled) CRM integrations

**Lambda Permissions** (depends on Lambda + APIs):
- `aws_lambda_permission.lex_invoke` - Allow Lex to invoke Lambda
- `aws_lambda_permission.connect_invoke_callback` - Allow Connect to invoke
- `aws_lambda_permission.apigw_invoke` - Allow API Gateway
- `aws_lambda_permission.apigw_invoke_crm`

**Deployment Time:** ~3-5 minutes (building and deploying Lambda code)

---

### **PHASE 4: Lex Bots - Gateway Bot** 🤖
*Depends on: Lambda functions, CloudWatch logs*

```
                         ┌─────────────────────────┐
                         │   Phase 3 Complete      │
                         │   (Lambda Ready)        │
                         └───────────┬─────────────┘
                                     │
                                     ▼
                         ┌──────────────────────────┐
                         │   Lex Bot Base           │
                         │   (Gateway Bot)          │
                         └───────────┬──────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
                    ▼                                 ▼
        ┌──────────────────────┐        ┌──────────────────────┐
        │  Bot Locale en_GB    │        │  Bot Locale en_US    │
        │  (Voice: Ruth)       │        │  (Voice: Joanna)     │
        └──────────┬───────────┘        └──────────┬───────────┘
                   │                               │
                   ▼                               ▼
        ┌──────────────────────┐        ┌──────────────────────┐
        │ Intent: ChatIntent   │        │ Intent: ChatIntent   │
        └──────────┬───────────┘        └──────────┬───────────┘
                   │                               │
                   ▼                               ▼
        ┌──────────────────────┐        ┌──────────────────────┐
        │Intent: TransferToAgent│       │Intent: TransferToAgent│
        └──────────┬───────────┘        └──────────┬───────────┘
                   │                               │
                   └───────────────┬───────────────┘
                                   │
                                   ▼
                       ┌──────────────────────────┐
                       │  Build Bot Locales       │
                       │  (AWS CLI polling)       │
                       │  ⏱️  5-10 minutes         │
                       └───────────┬──────────────┘
                                   │
                                   ▼
                       ┌──────────────────────────┐
                       │   Bot Version            │
                       │   (DRAFT → v1)           │
                       └───────────┬──────────────┘
                                   │
                                   ▼
                       ┌──────────────────────────┐
                       │   Bot Alias 'prod'       │
                       │   (+ Lambda hooks)       │
                       └───────────┬──────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                    ▼                             ▼
        ┌──────────────────────┐      ┌──────────────────────┐
        │ Connect Association  │      │ Validate Bot Alias   │
        └──────────────────────┘      └──────────────────────┘
```

**Gateway Bot Resources (Sequential):**
1. ✅ `module.lex_bot.aws_lexv2models_bot.this`
   - Base bot configuration
   - Privacy: Public, Idle session timeout: 300s

2. ✅ **Bot Locales** (parallel):
   - `module.lex_bot.aws_lexv2models_bot_locale.this` (en_GB)
   - `aws_lexv2models_bot_locale.en_us` (en_US)
   - Voice: Ruth (GB), Joanna (US)
   - NLU confidence: 0.40

3. ✅ **Intents per Locale** (parallel per locale):
   - `module.lex_bot.aws_lexv2models_intent.chat` (ChatIntent en_GB)
   - `aws_lexv2models_intent.chat_en_us` (ChatIntent en_US)
   - `aws_lexv2models_intent.transfer_to_agent_en_gb` (TransferToAgent en_GB)
   - `aws_lexv2models_intent.transfer_to_agent_en_us` (TransferToAgent en_US)
   - Sample utterances: "I want to talk to someone", "Can I speak to an agent"

4. ✅ **Fallback Intent Updates** (sequential):
   - `null_resource.update_fallback_intent_en_gb` - Update closing response
   - `null_resource.update_fallback_intent_en_us` - Update closing response

5. ✅ `null_resource.build_bot_locales`
   - CLI command: `aws lexv2-models build-bot-locale` for both locales
   - Polls every 10s until BUILT state
   - Max wait: 15 minutes

6. ✅ `aws_lexv2models_bot_version.this`
   - Version: DRAFT → Version 1
   - Depends on: All intents built

7. ✅ `awscc_lex_bot_alias.this` (Alias: "prod")
   - Points to Version 1
   - Lambda code hooks configured for both locales
   - Conversation logs enabled (CloudWatch + S3)

8. ✅ **Connect Integration** (parallel):
   - `null_resource.lex_bot_association` - Associate bot with Connect instance
   - `null_resource.validate_bot_alias` - Verify bot is accessible

**Deployment Time:** ~5-10 minutes (building locales is slowest)

---

### **PHASE 5: Lex Bots - Banking & Sales (Specialized)** 🤖
*Parallel with Phase 4 after Lambda functions ready*

```
                    ┌─────────────────────────────────┐
                    │      Phase 3 Complete           │
                    │      (Lambda Ready)             │
                    └────────────┬────────────────────┘
                                 │
            ┌────────────────────┴────────────────────┐
            │                                         │
            ▼                                         ▼
  ┌──────────────────────┐              ┌──────────────────────┐
  │  Banking Bot Base    │              │   Sales Bot Base     │
  └──────────┬───────────┘              └──────────┬───────────┘
             │                                     │
             ▼                                     ▼
  ┌──────────────────────┐              ┌──────────────────────┐
  │ Banking Locale en_GB │              │ Sales Locale en_GB   │
  └──────────┬───────────┘              └──────────┬───────────┘
             │                                     │
             ▼                                     ▼
  ┌──────────────────────┐              ┌──────────────────────┐
  │  Banking Intents:    │              │   Sales Intents:     │
  │  • CheckBalance      │              │   • ProductInfo      │
  │  • TransferMoney     │              │   • Pricing          │
  │  • GetStatement      │              │   • TransferToAgent  │
  │  • ReportLostCard    │              │                      │
  │  • TransferToAgent   │              │                      │
  └──────────┬───────────┘              └──────────┬───────────┘
             │                                     │
             ▼                                     ▼
  ┌──────────────────────┐              ┌──────────────────────┐
  │ Banking Bot Version  │              │  Sales Bot Version   │
  └──────────┬───────────┘              └──────────┬───────────┘
             │                                     │
             ▼                                     ▼
  ┌──────────────────────┐              ┌──────────────────────┐
  │ Banking Bot Alias    │              │  Sales Bot Alias     │
  │    'prod'            │              │    'prod'            │
  └──────────┬───────────┘              └──────────┬───────────┘
             │                                     │
             ▼                                     ▼
  ┌──────────────────────┐              ┌──────────────────────┐
  │Banking → Connect     │              │Sales → Connect       │
  │   Association        │              │   Association        │
  └──────────────────────┘              └──────────────────────┘

            🔄 BOTH BOTS BUILD IN PARALLEL 🔄
```

**Banking Bot (Parallel Track):**
1. ✅ `module.banking_bot.aws_lexv2models_bot.this`
2. ✅ `module.banking_bot.aws_lexv2models_bot_locale.this` (en_GB only)
3. ✅ **Banking Intents** (from vars.banking_intents):
   - `aws_lexv2models_intent.banking_intents_from_vars["CheckBalance"]`
   - `aws_lexv2models_intent.banking_intents_from_vars["TransferMoney"]`
   - `aws_lexv2models_intent.banking_intents_from_vars["GetStatement"]`
   - `aws_lexv2models_intent.banking_intents_from_vars["SetupDirectDebit"]`
   - `aws_lexv2models_intent.banking_intents_from_vars["ReportLostCard"]`
   - `aws_lexv2models_intent.banking_intents_from_vars["ChangePIN"]`
   - `aws_lexv2models_intent.banking_transfer` (TransferToAgent)
4. ✅ `aws_lexv2models_bot_version.banking`
5. ✅ `awscc_lex_bot_alias.banking` (Alias: "prod")
6. ✅ `null_resource.banking_bot_association` - Connect integration

**Sales Bot (Parallel Track):**
1. ✅ `module.sales_bot.aws_lexv2models_bot.this`
2. ✅ `module.sales_bot.aws_lexv2models_bot_locale.this` (en_GB only)
3. ✅ **Sales Intents**:
   - `aws_lexv2models_intent.sales_product` (ProductInfo)
   - Additional sales intents (from vars.sales_intents)
4. ✅ `aws_lexv2models_bot_version.sales`
5. ✅ `awscc_lex_bot_alias.sales` (Alias: "prod")
6. ✅ `null_resource.sales_bot_association` - Connect integration

**Deployment Time:** ~8-12 minutes (parallel with gateway bot, but banking has more intents)

---

### **PHASE 6: Connect Queues & Routing** 📞
*Depends on: Connect instance, phone numbers*

```
                    ┌─────────────────────────┐
                    │   Phase 2 Complete      │
                    │  (Connect Instance)     │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌──────────────────────────┐
                    │    Phone Numbers         │
                    │  • DID (+44)             │
                    │  • Toll-Free (0800)      │
                    └───────────┬──────────────┘
                                │
                                ▼
                    ┌──────────────────────────┐
                    │   Connect Queues (4x)    │
                    │  • GeneralAgentQueue     │
                    │  • AccountQueue          │
                    │  • LendingQueue          │
                    │  • OnboardingQueue       │
                    └───────────┬──────────────┘
                                │
                                ▼
                    ┌──────────────────────────┐
                    │   Routing Profile        │
                    │  (All queues enabled)    │
                    └───────────┬──────────────┘
                                │
                                ▼
                    ┌──────────────────────────┐
                    │      User Account        │
                    │  (Agent + Admin roles)   │
                    └──────────────────────────┘
```

**Resources Created:**

1. ✅ **Phone Numbers** (parallel):
   - `aws_connect_phone_number.outbound` - DID (+44)
   - `aws_connect_phone_number.toll_free` - 0800 number
   - Type: DID vs TOLL_FREE

2. ✅ **Connect Queues** (parallel, 4 queues):
   - `aws_connect_queue.queues["GeneralAgentQueue"]`
   - `aws_connect_queue.queues["AccountQueue"]`
   - `aws_connect_queue.queues["LendingQueue"]`
   - `aws_connect_queue.queues["OnboardingQueue"]`
   - Configuration:
     - Hours: 24/7 (default_hours_of_operation)
     - Outbound caller ID: DID number
     - Max contacts: 50 per queue
     - Timeout: 3600s (1 hour)

3. ✅ **Routing Profile** (depends on queues):
   - `aws_connect_routing_profile.this`
   - Default outbound queue: GeneralAgentQueue
   - All 4 queues configured with channels (Voice, Chat, Task)
   - Priority: 1 for all, Delay: 0

4. ✅ **User Account** (depends on routing profile):
   - `aws_connect_user.this`
   - Username: from `var.test_user_username`
   - Email: from `var.test_user_email`
   - Security profiles: Admin, Agent, CallCenterManager
   - Phone: Desk phone, Auto-accept enabled

**Deployment Time:** ~1-2 minutes

---

### **PHASE 7: Contact Flows** 📋
*Depends on: Lex bot aliases, queues, Lambda functions*

```
                         ┌─────────────────────────┐
                         │   Phase 4 Complete      │
                         │   (All Bots Ready)      │
                         └───────────┬─────────────┘
                                     │
        ┌────────────────────────────┼────────────────────────────┐
        │           │                │                │           │
        ▼           ▼                ▼                ▼           ▼
 ┌───────────┐ ┌──────────┐ ┌──────────────┐ ┌──────────┐ ┌──────────┐
 │  Queue    │ │  Voice   │ │   Bedrock    │ │   Chat   │ │ Callback │
 │ Transfer  │ │  Entry   │ │   Primary    │ │  Entry   │ │   Task   │
 │   Flow    │ │   Flow   │ │  Flow ⭐     │ │   Flow   │ │   Flow   │
 └─────┬─────┘ └──────────┘ └──────┬───────┘ └──────────┘ └──────────┘
       │                           │
       │                           │
       ▼                           ▼
 ┌────────────────────┐   ┌──────────────────────┐
 │  Quick Connects    │   │  Phone Number        │
 │  (4 queues)        │   │  Associations        │
 │  • GeneralAgent    │   │  • DID → Bedrock     │
 │  • Account         │   │  • TollFree→Bedrock  │
 │  • Lending         │   │                      │
 │  • Onboarding      │   │                      │
 └─────────┬──────────┘   └──────────────────────┘
           │
           ▼
 ┌────────────────────────┐
 │  Quick Connect         │
 │  Associations          │
 │  (All QCs → All Qs)    │
 └────────────────────────┘
```

**Contact Flows Created (Parallel after dependencies ready):**

1. ✅ `aws_connect_contact_flow.queue_transfer`
   - Type: **QUEUE_TRANSFER**
   - Template: `queue_transfer_flow.json.tftpl`
   - Purpose: Used by Quick Connects to transfer to queue
   - Depends on: `aws_connect_queue.queues`

2. ✅ `aws_connect_contact_flow.voice_entry`
   - Type: **CONTACT_FLOW**
   - Template: `voice_entry_simple.json.tftpl`
   - Variables: hours_of_operation_id, general_queue_arn
   - Purpose: Voice channel entry with hours check
   - Depends on: queues, hours_of_operation

3. ✅ `aws_connect_contact_flow.chat_entry`
   - Type: **CONTACT_FLOW**
   - Template: `chat_entry_simple.json.tftpl`
   - Variables: lex_bot_alias_arn, general_queue_arn
   - Purpose: Chat channel entry with Lex
   - Depends on: awscc_lex_bot_alias.this, queues

4. ✅ `aws_connect_contact_flow.bedrock_primary` ⭐ **DEFAULT FLOW**
   - Type: **CONTACT_FLOW**
   - Template: `bedrock_primary_flow.json.tftpl`
   - Variables:
     - lex_bot_alias_arn (Gateway Bot)
     - lex_bot_banking_alias_arn (Banking Bot)
     - lex_bot_sales_alias_arn (Sales Bot)
     - queue_arn (GeneralAgentQueue)
   - Purpose: Main multi-bot federated routing flow
   - Depends on: All 3 bot aliases, lex_bot_association, validate_bot_alias

5. ✅ `aws_connect_contact_flow.callback_task`
   - Type: **CONTACT_FLOW**
   - Template: `callback_task_flow.json.tftpl`
   - Purpose: Handle claimed callbacks as Connect tasks

**Quick Connects & Associations:**

6. ✅ **Quick Connects** (parallel, 4 instances):
   - `aws_connect_quick_connect.queue_transfer["GeneralAgentQueue"]`
   - `aws_connect_quick_connect.queue_transfer["AccountQueue"]`
   - `aws_connect_quick_connect.queue_transfer["LendingQueue"]`
   - `aws_connect_quick_connect.queue_transfer["OnboardingQueue"]`
   - Type: QUEUE
   - Contact Flow: queue_transfer flow
   - Depends on: `aws_connect_contact_flow.queue_transfer`

7. ✅ **Quick Connect Associations** (parallel, 4 instances):
   - `null_resource.associate_quick_connects` (for each queue)
   - Associates ALL Quick Connects with ALL queues
   - CLI: `aws connect associate-queue-quick-connects`

**Phone Number Associations:**

8. ✅ `null_resource.associate_phone_numbers`
   - Associates DID number → BedrockPrimaryFlow
   - Associates Toll-Free number → BedrockPrimaryFlow
   - CLI: `aws connect associate-phone-number-contact-flow`
   - Depends on: `aws_connect_contact_flow.bedrock_primary`

**Deployment Time:** ~2-3 minutes

---

### **PHASE 8: Monitoring & Observability** 📊
*Can start after Phase 1, runs in parallel*

```
                    ┌─────────────────────────────────┐
                    │      Phase 1 Complete           │
                    │   (Foundation Ready)            │
                    └────────────┬────────────────────┘
                                 │
     ┌───────────────┬───────────┼───────────┬───────────────┐
     │               │           │           │               │
     ▼               ▼           ▼           ▼               ▼
┌──────────┐  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│CloudWatch│  │CloudWatch│ │CloudTrail│ │   Log    │ │EventBridge│
│Dashboard │  │ Alarms   │ │          │ │Subscrip- │ │  Rules   │
│ (8 wid.) │  │  (8x)    │ │(Multi-Rgn)│ │ tions    │ │          │
└──────────┘  └──────────┘ └──────────┘ └──────────┘ └──────────┘

               ⚡ ALL CREATED IN PARALLEL ⚡
```

**Resources Created (Parallel):**

1. ✅ `aws_cloudwatch_dashboard.main`
   - 8 widgets: Queue metrics, Lambda metrics, Bedrock metrics, Lex metrics
   - Auto-refresh: 1 minute

2. ✅ **CloudWatch Alarms** (parallel):
   - `aws_cloudwatch_metric_alarm.queue_size` - Contacts > 50
   - `aws_cloudwatch_metric_alarm.queue_wait_time` - Wait > 300s
   - `aws_cloudwatch_metric_alarm.queue_abandonment_rate` - Abandon > 10%
   - `aws_cloudwatch_metric_alarm.lambda_error_rate` - Errors > 5%
   - `aws_cloudwatch_metric_alarm.bedrock_api_errors` - Bedrock errors
   - `aws_cloudwatch_metric_alarm.hallucination_rate_high` - Hallucination > 30%
   - `aws_cloudwatch_metric_alarm.hallucination_rate_medium` - Hallucination > 15%
   - `aws_cloudwatch_metric_alarm.validation_timeouts` - Validation timeouts
   - All alarms → `module.alarm_sns_topic`

3. ✅ **Log Subscriptions** (depends on log groups + Kinesis):
   - `aws_cloudwatch_log_subscription_filter.bedrock_mcp_logs` → Kinesis
   - `aws_cloudwatch_log_subscription_filter.lex_logs` → Kinesis
   - `aws_cloudwatch_log_subscription_filter.banking_lex_logs` → Kinesis
   - `aws_cloudwatch_log_subscription_filter.sales_lex_logs` → Kinesis
   - Pattern: `[timestamp, request_id, level, msg]`

4. ✅ `aws_cloudtrail.main`
   - Multi-region trail
   - S3: `module.cloudtrail_bucket`
   - Event selectors: All management events

5. ✅ **EventBridge Rules**:
   - `aws_cloudwatch_event_rule.connect_lifecycle`
   - Pattern: Connect instance state changes
   - Target: `module.firehose_lifecycle_events`

6. ✅ `aws_cloudwatch_metric_stream.connect_metrics`
   - Streams Connect metrics → Kinesis Firehose
   - Namespaces: AWS/Connect, AWS/Lex, AWS/Lambda

**Deployment Time:** ~1-2 minutes

---

### **PHASE 9: Web Interface (CCP & CloudFront)** 🌐
*Depends on: Connect instance, S3 buckets*

```
                    ┌─────────────────────────┐
                    │   Phase 2 Complete      │
                    │  (Connect + S3)         │
                    └───────────┬─────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
        ┌──────────────────┐    ┌──────────────────┐
        │  WAF Web ACL     │    │   S3 Objects     │
        │  (Rate limit)    │    │  • index.html    │
        └──────────┬───────┘    │  • streams.js    │
                   │            └──────────┬───────┘
                   │                       │
                   └───────────┬───────────┘
                               │
                               ▼
                   ┌──────────────────────┐
                   │  CloudFront OAC      │
                   │  (Origin Access)     │
                   └──────────┬───────────┘
                              │
                              ▼
                   ┌──────────────────────┐
                   │CloudFront Distribution│
                   │   ⏱️  5-8 minutes     │
                   └──────────┬───────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
   ┌─────────────────────┐       ┌──────────────────────┐
   │ S3 Bucket Policy    │       │ Origin Association   │
   │ (Allow CloudFront)  │       │ (Connect approved)   │
   └─────────────────────┘       └──────────────────────┘
```

**Resources Created:**

1. ✅ `aws_wafv2_web_acl.ccp_waf`
   - Rate limiting: 2000 requests per 5 minutes per IP
   - CloudWatch metrics enabled

2. ✅ **S3 Objects** (parallel):
   - `aws_s3_object.index_html` (from template: `ccp_site/index.html.tftpl`)
   - `aws_s3_object.connect_streams` (amazon-connect-streams-min.js)

3. ✅ `aws_cloudfront_origin_access_control.ccp_site`
   - Signing behavior: Always
   - Origin type: S3

4. ✅ `aws_cloudfront_distribution.ccp_site`
   - Origin: `aws_s3_bucket.ccp_site`
   - Price class: PriceClass_100 (US, EU)
   - Default root object: index.html
   - WAF: `aws_wafv2_web_acl.ccp_waf`
   - Cache policy: CachingOptimized
   - Compression: Enabled
   - **Deployment time: ~4-6 minutes** (slowest resource in entire stack)

5. ✅ `aws_s3_bucket_policy.ccp_site`
   - Allows CloudFront OAC to GetObject
   - Depends on: CloudFront distribution

6. ✅ `null_resource.associate_origin`
   - Associates approved origins with Connect instance
   - CLI: `aws connect associate-approved-origin`
   - Origin: CloudFront distribution URL

**Deployment Time:** ~5-8 minutes (CloudFront distribution dominates)

---

### **PHASE 10: Glue Data Catalog** 📚
*Depends on: S3 datalake bucket, Firehose delivery*

```
                    ┌─────────────────────────┐
                    │   Phase 2 Complete      │
                    │  (S3 Datalake Ready)    │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌──────────────────────────┐
                    │    Glue Database         │
                    │connect_comprehensive_datalake│
                    └───────────┬──────────────┘
                                │
                                ▼
                    ┌──────────────────────────┐
                    │   Glue Tables (5x)       │
                    │  • ctr (50+ columns)     │
                    │  • agent_events          │
                    │  • ai_insights           │
                    │  • lifecycle_events      │
                    │                          │
                    └──────────────────────────┘
```

**Resources Created:**

1. ✅ `module.datalake.aws_glue_catalog_database.this`
   - Database: `connect_comprehensive_datalake`
   - Location: `s3://bucket-name/`

2. ✅ **Glue Tables** (parallel):
   - `module.datalake.aws_glue_catalog_table.this["ctr"]`
     - Schema: 50+ columns (ContactId, InitiationMethod, Channel, etc.)
     - Partition: year, month, day, hour
     - Location: `s3://bucket/ctr/`
   
   - `module.datalake.aws_glue_catalog_table.this["agent_events"]`
     - Schema: AgentARN, CurrentAgentSnapshot, EventTimestamp, etc.
     - Location: `s3://bucket/agent-events/`
   
   - `module.datalake.aws_glue_catalog_table.this["ai_insights"]`
     - Schema: ContactId, Sentiment, Summary, etc.
     - Location: `s3://bucket/ai-insights/`
   
   - `module.datalake.aws_glue_catalog_table.this["lifecycle_events"]`
     - Schema: InstanceId, State, Reason, etc.
     - Location: `s3://bucket/lifecycle-events/`

**Deployment Time:** ~30-60 seconds

---

## Parallelization Summary

### Maximum Parallelization Points:

```
PHASE 1 (Foundation):       ~40 resources in parallel
PHASE 2 (Streaming):        ~12 resources in parallel
PHASE 3 (Lambda):           ~10 Lambda functions in parallel
PHASE 4 (Gateway Bot):      Sequential build (critical path)
PHASE 5 (Specialized Bots): 2 bots in parallel with Phase 4
PHASE 6 (Queues):           4 queues + routing in parallel
PHASE 7 (Contact Flows):    5 flows + Quick Connects in parallel
PHASE 8 (Monitoring):       ~20 alarms/dashboards in parallel
PHASE 9 (CloudFront):       Sequential (CloudFront is slow)
PHASE 10 (Glue):            5 tables in parallel
```

---

## Total Deployment Time Estimate

| Phase | Sequential | Parallel | Estimated Time |
|-------|-----------|----------|----------------|
| 1 - Foundation | No | ✅ | 30-60s |
| 2 - Connect & Streaming | No | ✅ | 2-3 min |
| 3 - Lambda | Mixed | ✅ | 3-5 min |
| 4 - Gateway Bot | ✅ Yes | No | 5-10 min ⏱️ |
| 5 - Banking/Sales Bots | No | ✅ | 8-12 min (parallel with Phase 4) |
| 6 - Queues & Routing | Mixed | ✅ | 1-2 min |
| 7 - Contact Flows | Mixed | ✅ | 2-3 min |
| 8 - Monitoring | No | ✅ | 1-2 min |
| 9 - CloudFront | ✅ Yes | No | 5-8 min ⏱️ |
| 10 - Glue Catalog | No | ✅ | 30-60s |

**Total Sequential Path (Critical Path):**
1. Phase 1 (60s)
2. Phase 2 (180s)  
3. Phase 3 (300s)
4. **Phase 4 + 5 (600s)** ← Bottleneck (Lex bot builds)
5. Phase 6 (120s)
6. Phase 7 (180s)
7. **Phase 9 (480s)** ← Bottleneck (CloudFront)
8. Phase 10 (60s)

**Total Time: ~25-35 minutes**
- **Critical Path 1:** Lex bot building (Phase 4-5)
- **Critical Path 2:** CloudFront distribution (Phase 9)

---

## Destruction Sequence

When running `terraform destroy`, resources are removed in **reverse dependency order**:

1. ⏱️ **CloudFront Distribution** (~4-6 min - slowest)
2. S3 objects, bucket policies, WAF ACLs
3. Phone number associations, Quick Connect associations
4. Contact flows (all types)
5. Quick Connects
6. Routing profiles, users
7. Queues
8. Phone numbers
9. Bot associations (Connect ↔ Lex)
10. Lex bot aliases → versions → intents → locales → bots
11. Lambda permissions → aliases → functions
12. Connect storage configs
13. Kinesis Firehose → Kinesis Streams
14. Connect instance
15. Glue tables → database
16. DynamoDB tables
17. S3 buckets (must be empty)
18. IAM role policies → roles
19. CloudWatch alarms, dashboards, log groups

**Total Destroy Time: ~8-12 minutes**
- CloudFront distribution deletion is the bottleneck

---

## Key Takeaways

✅ **Fastest to Create:** IAM roles, S3 buckets, DynamoDB tables (seconds)  
⏱️ **Slowest to Create:** Lex bot builds (5-10 min), CloudFront (5-8 min)  
🔄 **Most Parallel:** Phase 1 foundation (~40 resources simultaneously)  
🔗 **Most Sequential:** Phase 4 Lex bot (intents → build → version → alias)  
🚀 **Total Resources:** ~220 resources across 10 phases  
⚡ **Optimization:** Phases 4-5 run in parallel (Gateway + Specialized bots)  
🎯 **Critical Path:** Foundation → Connect → Lambda → Lex Bots → Flows → CloudFront

---

## Dependency Graph Visualization

```
╔══════════════════════════════════════════════════════════════╗
║                     DEPLOYMENT FLOW                          ║
╚══════════════════════════════════════════════════════════════╝

    ┌─────────────────────────────────────────────────┐
    │  PHASE 1: Foundation (S3, IAM, DDB, CW Logs)    │  ⚡ Parallel
    └───────────────────────┬─────────────────────────┘
                            │
                            ▼
    ┌─────────────────────────────────────────────────┐
    │  PHASE 2: Connect Instance + Kinesis Streams    │  🔄 Sequential
    └───────────────────────┬─────────────────────────┘
                            │
                            ▼
    ┌─────────────────────────────────────────────────┐
    │  PHASE 3: Lambda Functions + API Gateways       │  ⚡ Parallel
    └───────────────────────┬─────────────────────────┘
                            │
           ┌────────────────┼────────────────┐
           │                │                │
           ▼                ▼                ▼
    ┌────────────┐   ┌────────────┐   ┌────────────┐
    │  Gateway   │   │  Banking   │   │   Sales    │  🔄 Parallel
    │    Bot     │   │    Bot     │   │    Bot     │  ⏱️  10-12 min
    └─────┬──────┘   └─────┬──────┘   └─────┬──────┘
          │                │                │
          └────────────────┼────────────────┘
                           │
                           ▼
    ┌─────────────────────────────────────────────────┐
    │  PHASE 6: Phone Numbers + Queues                │  ⚡ Parallel
    └───────────────────────┬─────────────────────────┘
                            │
                            ▼
    ┌─────────────────────────────────────────────────┐
    │  PHASE 7: Contact Flows (5 flows)               │  ⚡ Parallel
    └───────────────────────┬─────────────────────────┘
                            │
                            ▼
    ┌─────────────────────────────────────────────────┐
    │  Quick Connects + Associations                  │  🔄 Sequential
    └───────────────────────┬─────────────────────────┘
                            │
                            ▼
    ┌─────────────────────────────────────────────────┐
    │  Phone Number → Flow Association                │  🔄 Sequential
    └───────────────────────┬─────────────────────────┘
                            │
                            ▼
    ┌─────────────────────────────────────────────────┐
    │  PHASE 9: CloudFront Distribution               │  🔄 Sequential
    └───────────────────────┬─────────────────────────┘  ⏱️  5-8 min
                            │
                            ▼
    ┌─────────────────────────────────────────────────┐
    │  PHASE 10: Glue Catalog (Tables)                │  ⚡ Parallel
    └─────────────────────────────────────────────────┘

         ┌───────────────────────────────────────────┐
         │  PHASE 8: Monitoring (CloudWatch, etc)    │  ⚡ Runs in
         │  Can start after Phase 1                  │  background
         └───────────────────────────────────────────┘

╔══════════════════════════════════════════════════════════════╗
║  🔗 Critical Paths (Bottlenecks):                            ║
║  1. Lex Bot Builds (Phase 4-5): 10-12 minutes               ║
║  2. CloudFront Distribution (Phase 9): 5-8 minutes           ║
║                                                              ║
║  ⚡ Total Deployment Time: 25-35 minutes                     ║
║  🗑️  Total Destroy Time: 8-12 minutes                        ║
╚══════════════════════════════════════════════════════════════╝
```

This sequence ensures proper dependency resolution while maximizing parallel resource creation for optimal deployment time.
