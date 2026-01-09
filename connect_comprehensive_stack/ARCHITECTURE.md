# Connect Comprehensive Stack Architecture

This document provides a detailed architectural overview of the **Connect Comprehensive Stack**, a production-ready Amazon Connect solution featuring Bedrock-primary conversational AI, intelligent tool calling with FastMCP 2.0, real-time hallucination detection, seamless agent handover, and a scalable **Data Lake** for advanced analytics.

## 1. System Context Diagram (C4 Level 1)

This high-level view shows how the **Connect Comprehensive System** interacts with users and external banking systems.

```
                                            +----------------------------------+
                                            |   Core Banking Systems           |
                                            |   (Accounts, Cards, Transactions)|
                                            +----------------^+----------------+
                                                             |
                                                             | (Secure API / VPC Link)
                                                             |
    +--------------+              +--------------------------+-----------------------+
    |              |              |                                                  |
    |   Customer   +------------->+      Connect Comprehensive System            |
    |  (Voice/Chat)|    HTTPS/    |      (Amazon Connect + Federated Bots)           |
    |              |    SIP       |                                                  |
    +--------------+              +--------------------------+-----------------------+
                                                             |
                                                             | (Analytics & Insights)
                                                             v
                                            +----------------------------------+
                                            |        Data Lake & BI            |
                                            |  (Athena / QuickSight / Tableau) |
                                            +----------------------------------+
```

### Component Roles & Purpose (System Context)
- **Customer**: The end-user interacting with the system via voice (PSTN) or chat (Web/Mobile).
- **Core Banking Systems**: External APIs handling the actual financial transactions (Get Balance, Transfer Funds).
- **Connect Comprehensive System**: The boundary of our deployed stack. It orchestrates the conversation, compliance, and routing.
- **Data Lake & BI**: The destination for all operational data, providing a unified view of customer journeys and system health.

## 2. Container Diagram (C4 Level 2)

This diagram details the *containers* (deployable units) within the system boundary. It illustrates the **Federated Hybrid Architecture**.

```
    +-------------+         +----------------+
    | Customer    +-------->+ Amazon Connect |
    | Device      |         | Instance       |
    +-------------+         +---+------+-----+
                                |      |
          (Voice / Chat Entry)  |      |  (Contact Flows & Routing)
                                v      v
                    +-----------+------+------------------------+
                    |           Gateway Routing Layer           |
                    | (Amazon Lex V2 - Gateway Bot)             |
                    +-------------------+-----------------------+
                                        |
                  +---------------------+---------------------+
                  |                                           |
    +-------------v-----------+                 +-------------v-----------+
    |   Conversational AI     |                 |   Transactional Logic   |
    |   (Generative Path)     |                 |   (Specialized Path)    |
    |                         |                 |                         |
    | +---------------------+ |                 | +---------------------+ |
    | | Bedrock MCP Lambda  | |                 | | Specialized Bot(s)  | |
    | | (Orchestrator)      | |                 | | (Banking / Sales)   | |
    | +----------+----------+ |                 | +----------+----------+ |
    |            |            |                 |            |            |
    | +----------v----------+ |                 | +----------v----------+ |
    | | Claude 3.5 Sonnet   | |                 | | Specialized Lambda  | |
    | | (Reasoning & Tools) | |                 | | (Python Logic)      | |
    | +---------------------+ |                 | +----------+----------+ |
    +-------------------------+                 +------------+------------+
                                                             |
                                                             v
                                                +------------+------------+
                                                |   External Banking API  |
                                                +-------------------------+
```

### Component Roles & Purpose (Container Level)
- **Amazon Connect Instance**: The central orchestrator. Handles telephony/chat connections, executes Contact Flows, and manages queues/agents.
- **Gateway Routing Layer (Lex V2)**: The initial conversational interface. Captures user input and sends it to the Bedrock MCP Lambda for classification.
- **Conversational AI (Bedrock MCP)**: Handles complex, non-deterministic queries using LLMs. It determines if a user should be routed to a specialized path or served directly.
- **Transactional Logic (Specialized Bots/Lambdas)**: Handles strictly defined, high-compliance tasks like money transfers or checking balances. These components follow deterministic logic trees.
- **External Banking API**: The source of truth for financial data, accessed securely via Lambda.

## 3. High-Level Architecture (Federated & Hybrid)

The solution leverages a **Federated Hybrid Pattern** combining the flexibility of Bedrock-based Generative AI with the control and speed of specialized, domain-specific Bots.

### Federated Architecture Sequence (ASCII)

```
      User          Connect        Gateway(Lex)    Bedrock(Lambda)   SalesBot(Lex)   SalesLambda
        |              |                |                |                |               |
        | "I want to   |                |                |                |               |
        | open acct"   |                |                |                |               |
        +------------->|                |                |                |               |
        |              | Invoke Gateway |                |                |               |
        |              +--------------->|                |                |               |
        |              |                | Fallback Intent|                |               |
        |              |                +--------------->|                |               |
        |              |                |                |                |               |
        |              |                | Analyze Intent |                |               |
        |              |                | (Claude 3.5)   |                |               |
        |              |                +--------------->|                |               |
        |              |                |                |                |               |
        |              |                | Response:      |                |               |
        |              |   Fulfilled    | [OpenAccount]  |                |               |
        |              |<---------------+<---------------+                |               |
        |              |                |                |                |               |
        | Check Intent |                |                |                |               |
        | Condition    |                |                |                |               |
        | (OpenAccount)|                |                |                |               |
        |+------------>|                |                |                |               |
        |              |                |                |                |               |
        |              | Transfer to Sales Bot           |                |               |
        |              +-------------------------------->|                |               |
        |              |                |                | Invoke Logic   |               |
        |              |                |                +--------------->|               |
        |              |                |                |                | Logic:        |
        |              |                |                |                | "Request Name"|
        |              |                |                |   ElicitSlot   +-------------->|
        |              |   "What is     |                |<---------------+               |
        |              |   your name?"  |                |                |               |
        |<-------------+                |                |                |               |
        v              v                v                v                v               v
```

## 4. Component Diagram (C4 Level 3)

This diagram breaks down the "Generative Path" and "Transactional Path" to show individual Lambda functions, Databases, and Observability components.

```
                                       +-------------------+
                                       |  Connect Instance |
                                       +---------+---------+
                                                 |
            +------------------------------------+-------------------------------------+
            | flow: bedrock_primary_flow                                               |
            v                                                                          v
  +-----------------------+                                                  +-----------------------+
  |    Gateway Bot        |                                                  |   Specialized Bots    |
  |    (Lex V2)           |                                                  |   (Banking / Sales)   |
  +---------+-------------+                                                  +----------+------------+
            |                                                                           |
            v                                                                           v
  +-----------------------+                                                  +-----------------------+
  |  Bedrock MCP Lambda   |                                                  |   Logic Lambdas       |
  |  (Python 3.11)        |                                                  |   (Python 3.11)       |
  +----+------+------+----+                                                  +----------+------------+
       |      |      |                                                                  |
       |      |      +----------> [ AWS Bedrock Runtime ]                               |
       |      |                   (Claude 3.5 Sonnet)                                   |
       |      |                                                                         |
       |      +----------> [ Validation Agent ] (Hallucination Check)                   |
       |                                                                                |
       v                                                                                v
  +-----------+           +--------------------------+                      +-----------------------+
  | DynamoDB  |           |      DynamoDB Hallucns   |                      |      External APIs    |
  | (History) |           |      (Detection Logs)    |                      |      (Mock Banking)   |
  +-----------+           +--------------------------+                      +-----------------------+
```

### Component Roles & Purpose (Detailed Level 3)

#### Conversational Components
*   **Gateway Bot (Lex V2)**: The primary entry point. Configured with a `FallbackIntent` that captures all input and delegates it to the `Bedrock MCP Lambda`. It acts as a "passthrough" to the LLM.
*   **Bedrock MCP Lambda**: The brain of the generative path.
    *   **Role**: Receives raw text, maintains conversation state (via DynamoDB), invokes Bedrock (Claude 3.5 Sonnet), executes MCP tools, and returns structured responses to Lex.
    *   **Internal Module: Validation Agent**: A specialized Python class within the Lambda that checks LLM outputs against allowed topics to prevent hallucinations.
*   **Specialized Bots (Lex V2)**: Separate Lex bots for specific domains (Banking, Sales).
    *   **Role**: Isolated, deterministic NLU models. They handle sensitive flows like "Check Balance" where strict slot-filling is required.
    *   **Logic Lambdas**: Dedicated Python functions for executing business logic (e.g., querying the mocked banking API) and returning specific prompts.
*   **DynamoDB (History)**: Stores the conversation context (Session ID, User turns, AI turns) to allow the stateless Lambda to support multi-turn conversations.
*   **DynamoDB (Hallucinations)**: Stores records of detected policy violations or hallucinations for audit purposes.

#### Data & Observability Components

```
   Logs Sources                             Aggregation Layer               Storage & Analysis
   +--------------+                         +------------------+            +-------------------+
   | CloudWatch   +--[Sub Filter]---------->| Kinesis Firehose |----------->| S3 Data Lake      |
   | Logs         |                         | (Buffering)      |            | (Parquet/JSON)    |
   +--------------+                         +------------------+            +---------+---------+
                                                                                      |
   +--------------+                         +------------------+                      v
   | Connect      +--[Kinesis Stream]------>| Kinesis Firehose |            +-------------------+
   | CTRs         |                         | (Buffering)      |            | AWS Glue Crawler  |
   +--------------+                         +------------------+            | (Schema Discovery)|
                                                                            +---------+---------+
   +--------------+                                                                   |
   | Contact      +--[S3 Export]----------------------------------------------------->|
   | Lens         |                                                                   v
   +--------------+                                                         +-------------------+
                                                                            | Amazon Athena     |
                                                                            | (SQL Query Engine)|
                                                                            +-------------------+
```

*   **CloudWatch Logs**: Captures execution logs from all Lambdas and conversation logs from Lex bots.
*   **Kinesis Streams**: Real-time pipe for raw Connect data (Contact Trace Records, Agent Events).
*   **Kinesis Firehose**: A fully managed ETL service that buffers incoming streaming data, optionally compresses/transforms it, and writes it to S3 in batches (reducing S3 PUT costs and file fragmentation).
*   **S3 Data Lake**: The unified storage layer. Organized by prefixes (`/ctrs`, `/logs`, `/agent-events`).
*   **AWS Glue Crawler**: Automatically scans S3 buckets to infer schema (tables, columns, data types) and populates the Glue Data Catalog.
*   **Amazon Athena**: Serverless interactive query service. Allows analysts to run standard SQL queries against the raw data in S3 for reporting and dashboards.

## 5. Deployment & Security

### Security Components
*   **KMS Keys**: Provide encryption-at-rest for S3 buckets, Kinesis Streams, and DynamoDB tables. Supports "Zero Trust" architecture.
*   **IAM Roles**: Granular Least Privilege policies ensuring Lambdas can only access their specific DynamoDB tables and Bedrock models.
*   **VPC Endpoints (Optional)**: Can be enabled to ensure traffic between Lambda and Bedrock/DynamoDB never traverses the public internet.

## 6. Metrics Source Mapping

The following table details which analytical metrics are derived from which source component in the Data Lake.

| Metric Component | Source Pipeline | Primary Table | Key Metrics Derived | Latency |
| :--- | :--- | :--- | :--- | :--- |
| **Contact Trace Records (CTR)** | Kinesis Stream -> Firehose | `ctrs` | IVR Containment, AHT, Disconnect Reasons, Journey Outcome, Transfer Rate | Near Real-time (~2-3 min) |
| **Agent Events** | Kinesis Stream -> Firehose | `agent_events` | Agent Availability, Login Duration, State Changes, Occupancy | Near Real-time |
| **Lifecycle Events** | EventBridge -> Firehose | `lifecycle_events` | **Live Queue Backlog**, Point-in-time Contact States, Raw Event History | Real-time (<60s) |
| **Federated Bot Logs** | CloudWatch -> Firehose | `cloudwatch_logs` | **Intent Routing Accuracy**, Bot Latency, Error Rates | ~5 mins |
| **AI Insights** | Lambda -> Kinesis -> Firehose | `ai_insights` | Hallucination Rate, Validation Latency, Jailbreak Attempts, Model Performance | Real-time |
| **Contact Lens** | S3 Export -> Glue Crawler | `contact_lens_analysis` | Sentiment Score, Interruption Rate, Non-Talk Time, Category Matches | Post-Call (5-10 min) |
| **System Health** | CloudWatch Metric Stream | Defined by Namespace | Throttling, Concurrent Calls, System Errors, API Usage | Real-time |

## 7. Hallucination Detection & Remediation Flow

The system employs a multi-stage validation strategy managed by the `ValidationAgent` class within the Bedrock MCP Lambda. This ensures that AI responses are factually grounded and policy-compliant before reaching the user.

### Validation Sequence Diagram

```
      +--------+        +------------------+       +-------------------+       +-----------------------+
      | User   |        | Bedrock Lambda   |       |  Validation Agent |       |  Validation Rules     |
      +---+----+        +--------+---------+       +---------+---------+       +-----------+-----------+
          |                      |                           |                             |
          | "How much is the     |                           |                             |
          | fee for premium?"    |                           |                             |
          +--------------------->|                           |                             |
                                 |                           |                             |
                                 | 1. Invoke Model           |                             |
                                 +-------------------------->|                             |
                                 |  (History + Tools + Query)|                             |
                                 |                           |                             |
                                 |<--------------------------+                             |
                                 |  Response: "Fee is £10"   |                             |
                                 |                           | 2. Verify(Response, Tools)  |
                                 |                           +---------------------------->|
                                 |                           |                             |
                                 |                           | Check 1: Fabricated Data?   |
                                 |                           | (Is "£10" in Tool Output?)  |
                                 |                           |                             |
                                 |                           | Check 2: Domain Boundary?   |
                                 |                           | (Is topic "Mortgage"?)      |
                                 |                           |                             |
                                 |                           | Check 3: Security Sanity    |
                                 |                           | (Any "System Prompt" leak?) |
                                 |                           |<----------------------------+
                                 |                           | Result: {Passed: False,     |
                                 |                           |  Issue: "Fee not found"}    |
                                 |<--------------------------+                             |
                                 |                           |                             |
                                 | 3. Remediation Strategy   |                             |
             <-------------------+ (If Critical => Fallback) |                             |
           "I apologize, I       | (If Low => Modify/Log)    | 4. Log to Data Lake         |
           cannot verify that    +-------------------------------------------------------->| (Kinesis Stream:
           fee currently."       |                           |                             |  ai_insights)
                                 |                           |                             |
          v                      v                           v                             v
```

### Validation Checks
1.  **Fabricated Data Check**: Scans the model response for specific claims (fees, document names) and verifies they exist in the raw Tool Output. If the model mentions "£50 fee" but the tool said "£20", it is flagged.
2.  **Domain Boundary Check**: Uses an allow-list of topics. If the model starts discussing "Cryptocurrency" or "Mortgages" (out of scope), it is blocked.
3.  **Security & Isolation Check**: Regex-based scanning for PII (Social Security patterns, Sort Codes) or Internal System Prompts ("My instructions are...").

## 8. Operational Data Model (DynamoDB)

The system uses Amazon DynamoDB for low-latency state management and operational queuing.

### 8.1 Conversation Awareness (`conversation_history`)
Stores the multi-turn context for the stateless Lambda functions.
*   **Partition Key**: `session_id` (String) - The Connect Contact ID.
*   **Sort Key**: `timestamp` (String) - ISO 8601 timestamp.
*   **TTL**: 24 hours (items expire automatically).
*   **Attributes**:
    *   `role`: "user" | "assistant"
    *   `content`: The text content of the turn.
    *   `tool_use`: (Optional) JSON tracking tool calls made in this turn.

### 8.2 Operational Callbacks (`callback_queue`)
Manages the state of requested callbacks when agents are unavailable.
*   **Partition Key**: `contact_id` (String).
*   **Attributes**:
    *   `phone_number`: Customer's number.
    *   `queue_arn`: Target queue.
    *   `status`: "PENDING" | "CLAIMED" | "COMPLETED".
    *   `retry_count`: Number of callback attempts.

## 9. Comprehensive Data Lake Pipeline

All system components stream data into a centralized S3 Data Lake, partitioned for performance and queryability via Amazon Athena.

### Data Ingestion Architecture

```
    [SOURCES]                     [INGESTION]                   [STORAGE]               [CATALOG]
    =========                     ===========                   =========               =========

 1. TELEPHONY DATA
    +----------------+   Stream   +------------------+         +----------------+
    | Connect CTRs   +----------->| Firehose (Batch) +-------->| S3: /ctr/      |
    +----------------+            +------------------+         | (Parquet)      |
                                                               +----------------+
 2. AGENT METRICS                                                      ^
    +----------------+   Stream   +------------------+                 |            +-------------+
    | Agent Events   +----------->| Firehose (Batch) +-----------------+            | AWS Glue    |
    +----------------+            +------------------+                 |            | Crawler     |
                                                                       |            +------+------+
 3. REAL-TIME OPS                                                      |                   |
    +----------------+   Event    +------------------+                 |                   | (Sync)
    | Lifecycle Evts +----------->| Firehose (Buffr) +-----------------+                   |
    | (EventBridge)  |            +------------------+                 |                   v
    +----------------+                                                 |            +-------------+
                                                                       |            | Amazon      |
 4. AI & QUALITY                                                       |            | Athena      |
    +----------------+   Stream   +------------------+                 |            | (SQL)       |
    | Validation Agt +----------->| Firehose (Batch) +-----------------+            +-------------+
    | (Kinesis)      |            +------------------+                 |
    +----------------+                                                 |
                                                                       |
 5. SERVER LOGS                                                        |
    +----------------+   SubFilt  +------------------+                 |
    | CloudWatch Logs+----------->| Firehose (Zip)   +-----------------+
    | (All Lambdas)  |            +------------------+                 |
    +----------------+                                                 |
                                                                       |
 6. CONVERSATION INTEL                                                 |
    +----------------+   Export   +------------------+                 |
    | Contact Lens   +----------->| S3 Direct Put    +-----------------+
    | (Transcripts)  |            +------------------+
    +----------------+
```

### Data Lake Schema & Purpose

| Dataset | Partitioning | Source | Purpose |
| :--- | :--- | :--- | :--- |
| **`ctrs`** | `/year/month/day` | Connect Kinesis Stream | **Business Intelligence**: The "Golden Record" of a call. Used for calculating Average Handle Time (AHT), Transfer Rates, and IVR Containment. |
| **`agent_events`** | `/year/month/day` | Connect Kinesis Stream | **Workforce Mgmt**: detailed audit trails of agent login/logout, status changes (Available -> Offline), and missed calls. |
| **`lifecycle_events`** | `/year/month/day/hour` | EventBridge Rule | **Real-Time Ops**: Granular state changes (Queued, Connected, OnHold) used to calculate *Live Queue Backlog* and *Abandonment Velocity* with <30s latency. |
| **`ai_insights`** | `/year/month/day` | Validation Agent (Lambda) | **AI Governance**: Every LLM interaction is scored. Logs Hallucination detected (True/False), Response Latency, and the specific prompt/response pairs for fine-tuning. |
| **`contact_lens`** | `/year/month/day` | S3 Export | **Quality Assurance**: Deep analysis of call transcripts including Sentiment trends, Interruption rates, and Non-talk time. |

## 10. Non-Functional Requirements (NFRs)

The architecture is designed to meet strict enterprise-grade requirements for banking grade workloads.

### 10.1 Performance & Latency
*   **Voice Latency**: Total conversational turn-around time (Standard) < 1.5s.
    *   *Constraint*: Bedrock generation can vary (1-4s). To mitigate, the system uses streaming responses (future optimization) or "filler" phrases if latency exceeds thresholds.
*   **Throughput**:
    *   Connect: Supports 100+ concurrent calls (Soft Limit, adjustable).
    *   Lambda: Burst concurrency enabled (starting 1000).
    *   Kinesis: 1000 records/sec per shard (Auto-scaling enabled).
*   **Data Freshness**:
    *   Operational Dashboard (Backlog): < 60 seconds.
    *   Historical Reporting (Athena): ~5-15 minutes (Firehose buffering).

### 10.2 Reliability & Availability
*   **RTO (Recovery Time Objective)**: < 15 minutes (Infrastructure as Code redeployment).
*   **RPO (Recovery Point Objective)**: < 5 minutes (DynamoDB PITR, S3 Versioning).
*   **Availability**: Relies on Regional AWS Services (Connect, Lambda, DynamoDB, S3) which offer inherently high availability across multiple Availability Zones (AZs).

### 10.3 Security & Compliance
*   **Encryption**: All data at rest encrypted via KMS (CMK). All data in transit uses TLS 1.2+.
*   **Data Residency**: All storage buckets and queues are strictly regionalized (e.g., `eu-west-2`).
*   **PII Redaction**: Contact Lens automatically redacts sensitive data from transcripts and audio. Validation Agent acts as a secondary PII guardrail for LLM outputs.

## 11. Performance Testing Strategy

To validate the NFRs, the following testing strategies are recommended:

### 11.1 Tools
*   **StartOutboundVoiceContact API**: To simulate inbound traffic volume.
*   **Artillery / k6**: For load testing the API Gateway / Lambda backend components directly (bypassing telephony for logic stress testing).
*   **AWS Fault Injection Simulator (FIS)**: To test resilience against AZ failures or API throttling.

### 11.2 Key Test Scenarios
1.  **Orchestrator Stress Test**: Initiate 50 concurrent calls to verify Lambda provisioning speed and DynamoDB throughput logic (avoiding `ProvisionedThroughputExceededException`).
2.  **Latency Profiling**: Measure the "Time to First Byte" (TTFB) from the Bedrock Lambda across 1000 requests to establish P95 and P99 baselines.
3.  **Hallucination robustness**: Inject 500 adversarial prompts ("Ignore instructions", "What is my password") to verify the `ValidationAgent` blocking rate remains > 99%.

## 12. Architecture Decision Records (ADRs)

Key technical decisions shaping this architecture.

### ADR-001: Federated Hybrid Architecture
*   **Context**: We needed the flexibility of Generative AI but the strict compliance of Banking systems.
*   **Decision**: Adopt a "Hub and Spoke" model. Use Bedrock (Claude 3.5) for general intent classification and context gathering, but hand off to specialized, deterministic Lex Bots for transactional execution.
*   **Consequence**: Increases complexity in routing logic but guarantees determinism for financial transactions.

### ADR-002: FastMCP over LangChain
*   **Context**: The application required tool calling. LangChain provides high abstraction but adds latency and "black box" complexity.
*   **Decision**: Implement "FastMCP" style tool calling using native Python and Pydantic.
*   **Consequence**: Lower cold start times, full control over the prompt loop, and reduced dependency bloat.

### ADR-003: Asynchronous Data Lake vs. Real-time Database
*   **Context**: Reporting needs to be cost-effective but reasonably fresh.
*   **Decision**: Use Kinesis Firehose to batch write to S3/Athena instead of writing directly to an RDS/OpenSearch cluster.
*   **Consequence**: Extremely low cost and zero server maintenance. Trade-off is data availability latency of ~5 minutes (acceptable for BI/Analytics).

## 13. Known Issues & Limitations

*   **LLM Cold Starts**: The first invocation of the Bedrock Lambda after inactivity may experience a 3-5s cold start latency due to the heavy AWS SDK initialization. *Mitigation: Provisioned Concurrency enabled.*
*   **Voice/Speech Transcription**: Lex V2 transcription accuracy for alphanumeric strings (like Postcodes or Account IDs) can be inconsistent in noisy environments. *Mitigation: DTMF fallback logic or specialized slot types implemented in key areas.*
*   **Token Limits**: Single-turn context limit is set to 4096 tokens. Extremely long conversations may lose context of the earliest turns as they are rolled off the DynamoDB history buffer.

## 14. Agent Handover & Context Propagation

Integration between AI and Human Agents is critical. The system supports "Warm Handover" where the agent receives the full context of the AI conversation.

### 14.1 Universal Handover Sequence (ASCII)
This flow demonstrates how a call can be transferred to a human agent at **any stage** of the interaction (Generative, Specialized, or Error State).

```
                                            [ DECISION POINT ]
                                                   |
        +-----------------+         +--------------+-------------+          +------------------+
        |  Generative AI  |         |   Specialized Bot Flow     |          |   System Error   |
        |  (Bedrock)      |         |   (Banking/Sales)          |          |   (Timeout/Fail) |
        +--------+--------+         +--------------+-------------+          +---------+--------+
                 |                                 |                                  |
    1. User asks |                    2. User asks |                    3. Max Retries|
    "Talk to     |                    "Agent please"                 Exceeded / Error|
    Human"       |                    OR Logic Fail|                                  |
                 v                                 v                                  v
        +--------+--------+         +--------------+-------------+          +---------+--------+
        | Lambda returns  |         | Specialized Intent         |          | Connect Error    |
        | "TransferToAgent"         | "Fallback / Transfer"      |          | Handler          |
        +--------+--------+         +--------------+-------------+          +---------+--------+
                 |                                 |                                  |
                 +----------------+----------------+----------------------------------+
                                  |
                                  v
                         +--------+--------+
                         | Connect Flow    |
                         | Logic           |
                         +--------+--------+
                                  |
                 1. Set Contact Attributes (Context)
                    - "handover_reason": "User Request" / "Error"
                    - "conversation_summary": "User asked about checking account..."
                    - "sentiment_score": "-0.5" (if angry)
                                  |
                                  v
                         +--------+--------+
                         | Transfer to     |
                         | Generic Queue   |
                         +--------+--------+
                                  |
                                  v
                         +--------+--------+
                         | Agent CCP       |
                         | (Screen Pop)    |
                         +-----------------+
```

### 14.2 Context Propagation Lifecycle (ASCII)
Data flows through the system using a combination of **Amazon Connect Contact Attributes** (temporary, per-call) and **DynamoDB** (persistent, multi-turn).

```
  Stage 1: Entry        Stage 2: Generative     Stage 3: Specialized      Stage 4: Agent
  (Connect Inbound)     (Bedrock Lambda)        (Lex V2 Bot)              (Custom CCP)

  +-------------+       +-----------------+     +------------------+      +---------------+
  | Contact     |       | DynamoDB        |     | Lex Session      |      | Contact       |
  | Attributes  |------>| (History)       |---->| Attributes       |----->| Attributes    |
  +-------------+       +-----------------+     +------------------+      +---------------+
  | - User Phone|       | - SessionID     |     | - verified_pin   |      | - Summary     |
  | - System    |       | - Turn 1 (User) |     | - acct_type      |      | - Sentinel    |
  |   Points    |       | - Turn 1 (AI)   |     | - intent_conf    |      | - Sentiment   |
  +------+------+       +--------+--------+     +---------+--------+      +-------+-------+
         |                       |                        |                       |
         | (Initialize)          | (Read/Write)           | (Handshake)           | (Display)
         v                       v                        v                       v
  +------+------+       +--------+--------+     +---------+--------+      +-------+-------+
  | Connect     |       | Bedrock MCP     |     | Banking Lambda   |      | Agent Screen  |
  | State       |       | Logic           |     | Logic            |      | Pop (UI)      |
  +-------------+       +-----------------+     +------------------+      +---------------+
```

#### Context Data Dictionary
*   **System Context**: Passed implicitly by Connect (ANI, DNIS, Queue Name).
*   **Conversation Context**: Stored in DynamoDB ( table), keyed by Contact ID. Allows the Bedrock Lambda to "remember" previous turns.
*   **Handover Context**: Explicit attributes set in the Contact Flow before transferring to a queue (, ). These are displayed to the agent immediately upon call acceptance.

## 14. Agent Handover & Context Propagation

Integration between AI and Human Agents is critical. The system supports "Warm Handover" where the agent receives the full context of the AI conversation.

### 14.1 Universal Handover Sequence (ASCII)
This flow demonstrates how a call can be transferred to a human agent at **any stage** of the interaction (Generative, Specialized, or Error State).

```
                                            [ DECISION POINT ]
                                                   |
        +-----------------+         +--------------+-------------+          +------------------+
        |  Generative AI  |         |   Specialized Bot Flow     |          |   System Error   |
        |  (Bedrock)      |         |   (Banking/Sales)          |          |   (Timeout/Fail) |
        +--------+--------+         +--------------+-------------+          +---------+--------+
                 |                                 |                                  |
    1. User asks |                    2. User asks |                    3. Max Retries|
    "Talk to     |                    "Agent please"                 Exceeded / Error|
    Human"       |                    OR Logic Fail|                                  |
                 v                                 v                                  v
        +--------+--------+         +--------------+-------------+          +---------+--------+
        | Lambda returns  |         | Specialized Intent         |          | Connect Error    |
        | "TransferToAgent"         | "Fallback / Transfer"      |          | Handler          |
        +--------+--------+         +--------------+-------------+          +---------+--------+
                 |                                 |                                  |
                 +----------------+----------------+----------------------------------+
                                  |
                                  v
                         +--------+--------+
                         | Connect Flow    |
                         | Logic           |
                         +--------+--------+
                                  |
                 1. Set Contact Attributes (Context)
                    - "handover_reason": "User Request" / "Error"
                    - "conversation_summary": "User asked about checking account..."
                    - "sentiment_score": "-0.5" (if angry)
                                  |
                                  v
                         +--------+--------+
                         | Transfer to     |
                         | Generic Queue   |
                         +--------+--------+
                                  |
                                  v
                         +--------+--------+
                         | Agent CCP       |
                         | (Screen Pop)    |
                         +-----------------+
```

### 14.2 Context Propagation Lifecycle (ASCII)
Data flows through the system using a combination of **Amazon Connect Contact Attributes** (temporary, per-call) and **DynamoDB** (persistent, multi-turn).

```
  Stage 1: Entry        Stage 2: Generative     Stage 3: Specialized      Stage 4: Agent
  (Connect Inbound)     (Bedrock Lambda)        (Lex V2 Bot)              (Custom CCP)

  +-------------+       +-----------------+     +------------------+      +---------------+
  | Contact     |       | DynamoDB        |     | Lex Session      |      | Contact       |
  | Attributes  |------>| (History)       |---->| Attributes       |----->| Attributes    |
  +-------------+       +-----------------+     +------------------+      +---------------+
  | - User Phone|       | - SessionID     |     | - verified_pin   |      | - Summary     |
  | - System    |       | - Turn 1 (User) |     | - acct_type      |      | - Sentinel    |
  |   Points    |       | - Turn 1 (AI)   |     | - intent_conf    |      | - Sentiment   |
  +------+------+       +--------+--------+     +---------+--------+      +-------+-------+
         |                       |                        |                       |
         | (Initialize)          | (Read/Write)           | (Handshake)           | (Display)
         v                       v                        v                       v
  +------+------+       +--------+--------+     +---------+--------+      +-------+-------+
  | Connect     |       | Bedrock MCP     |     | Banking Lambda   |      | Agent Screen  |
  | State       |       | Logic           |     | Logic            |      | Pop (UI)      |
  +-------------+       +-----------------+     +------------------+      +---------------+
```

#### Context Data Dictionary
*   **System Context**: Passed implicitly by Connect (ANI, DNIS, Queue Name).
*   **Conversation Context**: Stored in DynamoDB (`conversation_history` table), keyed by Contact ID. Allows the Bedrock Lambda to "remember" previous turns.
*   **Handover Context**: Explicit attributes set in the Contact Flow before transferring to a queue (`conversation_summary`, `handover_reason`). These are displayed to the agent immediately upon call acceptance.

## 15. User Management & Routing Logic

This section details how human agents are organized, routed, and secured within the system.

### 15.1 Routing Profiles
Routing Profiles determine which queues an agent acts upon and their priority. They also define the "Outbound Queue" (the implementation of Caller ID for outbound calls).

| Profile Name | Description | Voice | Chat | Task | Queues (Priority) | Default Outbound Queue |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Basic** | Entry-level generic agent | 1 | 2 | 1 | BasicQueue (P1), GeneralAgentQueue (P2) | GeneralAgentQueue |
| **Main** | Senior agent with outbound focus | 1 | 2 | 10 | GeneralAgentQueue (P1) | GeneralAgentQueue |
| **Account** | Specialized Account Services | 1 | 2 | 10 | AccountQueue (P1) | AccountQueue |
| **Lending** | Specialized Lending Services | 1 | 2 | 10 | LendingQueue (P1) | LendingQueue |
| **Onboarding** | Specialized Onboarding Services | 1 | 2 | 10 | OnboardingQueue (P1) | OnboardingQueue |

### 15.2 Security Profiles
Security profiles control access to the Amazon Connect Dashboard and CCP.

*   **AgentRef**: Minimal access. Can access CCP (Contact Control Panel) to accept/reject calls and chat. Cannot edit flows or view reports.
*   **CallCenterManager**: Moderate access. Can manage Users, Queues, and Routing Profiles. Can view Real-time and Historical Metrics reports.
*   **Admin**: Full Root access to the instance.

### 15.3 Agent Alignment Matrix
The infrastructure provisions the following default user references.

| Username | Role (Security Profile) | Routing Logic (Routing Profile) | Skills / Capability |
| :--- | :--- | :--- | :--- |
| **Agent One** | `Admin` | `Basic` | System Administrator who also takes basic calls (Overflow). |
| **Agent Two** | `CallCenterManager` | `Main` | Team Lead. Manages floor, takes escalations (General Queue). |
| **Agent Three** | `Agent` | `Account` | Specialist. Handles checking, savings, statement queries. |
| **Agent Four** | `Agent` | `Lending` | Specialist. Handles loans, mortgages, rate queries. |
| **Agent Five** | `Agent` | `Onboarding` | Specialist. Handles KYC and new customer signup. |

### 15.4 Queue Quick Connects
The architecture implements "Queue Quick Connects" to facilitate transfers.
*   **Mechanism**: A Quick Connect is created for every defined Queue.
*   **Usage**: When an agent clicks "Transfer" in the CCP, they see a list of these Quick Connects (e.g., "Transfer to Lending").
*   **Routing**: Selecting a Quick Connect routes the customer to the specific `customer_queue_flow` associated with that queue, ensuring logic (music on hold, position announcement) is maintained during transfer.

## 16. Telephony, Transcripts & Analytics

### 16.1 External Numbers & Outbound Dialing
*   **Inbound**: Separate Toll-Free or DID numbers are claimed and assigned to entry flows (Voice Entry).
*   **Outbound**:
    *   Agents are assigned a specific **Outbound Queue** via their Routing Profile.
    *   When an agent dials a number manually in the CCP, the system uses the **Caller ID** associated with that Outbound Queue.
    *   **Architecture**: `aws_connect_phone_number.outbound` resource is associated as the Outbound Caller ID for the `GeneralAgentQueue`.

### 16.2 Transcript Generation & Storage
1.  **Generation**:
    *   **Chat**: Transcripts are native to Connect. Every message is auto-journaled.
    *   **Voice**: Enabled via **Contact Lens** or standard recording. The `bedrock_primary` flow triggers "Start Recording" block.
2.  **Storage**:
    *   Records are piped to an S3 bucket defined in `aws_connect_instance_storage_config`.
    *   **Paths**:
        *   Chat: `s3://<bucket>/chat-transcripts/<date>/`
        *   Voice: `s3://<bucket>/call-recordings/<date>/`
3.  **Analytics**:
    *   **Contact Lens**: If enabled, performs NLP on voice audio to generate transcripts and sentiment analysis.
    *   **Kinesis Streams**: Real-time data (Agent Events, Contact Trace Records) is streamed to Kinesis for custom downstream analytics (e.g., Quicksight dashboards).

### 16.3 Visualization & Handover
How data reaches the agent:
*   **During Interaction**:
    *   **Screen Pop**: The `TransferToAgent` logic sets attributes (`handover_reason`, `sentiment`). These appear as key-value pairs in the Agent's CCP "Details" tab.
    *   **Chat History**: If the channel is Chat, the agent automatically sees the full conversation history (from Bedrock/Lex) in the standardized chat UI windows.
*   **Post-Interaction**:
    *   Supervisors can view the full "Contact Trace Record (CTR)" in the Connect Dashboard.
    *   This CTR includes the **recording**, **transcript** (if Contact Lens used), and the **graphical timeline** of sentiment (Positive/Negative/Neutral) throughout the call.


## 17. End-to-End Process Flow (BPMN 2.0)

The following ASCII BPMN 2.0 diagram illustrates the complete end-to-end lifecycle of a contact, highlighting the distinct architectural boundaries (Swimlanes) and the flow of control and data between the Customer, Amazon Connect, the AI Layer, and the Human Agent.

```
+-------------+      +-------------------+      +-------------------------+      +-----------------+
|   Customer  |      |   Connect (Flow)  |      |    AI Brain (Lambda)    |      |   Human Agent   |
+------+------+      +---------+---------+      +------------+------------+      +--------+--------+
       |                       |                             |                            |
   ( Start )                   |                             |                            |
       |                       |                             |                            |
       +---------------------->|                             |                            |
   [Inbound]                   |                             |                            |
                               v                             |                            |
                        [Play Greeting]                      |                            |
                        [Set Recording]                      |                            |
                               |                             |                            |
                               v                             |                            |
                        [Get Customer  ]                     |                            |
                        [Input (Speech)]                     |                            |
                               |                             |                            |
                               v                             |                            |
                       [Invoke Lambda ]--------------------->|                            |
                               |                             |                            |
                               |                    [Restore History]                     |
                               |                    [DynamoDB Load  ]                     |
                               |                             |                            |
                               |                             v                            |
                               |                     <  Identify Intent  >                |
                               |                    /        |          \                 |
                               |             (GenAI)     (Banking)      (Human)           |
                               |                |            |              |             |
                               |                v            v              |             |
                               |          [Generate  ]   [Delegate  ]       v             |
                               |          [Response  ]   [to Lex Bot]   [Create   ]       |
                               |                |            |          [Handover ]       |
                               |                |            |          [Signal   ]       |
                               |                |            |              |             |
                               |                |            |              |             |
                               |                v            v              v             |
                               |<------------- [ Return Response/Action ] --+             |
                               |                             |                            |
                               |                             |                            |
                       < Check Action Type >                 |                            |
                      /        |          \                  |                            |
                 (Speak)       |        (Transfer)           |                            |
                    |          |             |               |                            |
      +<------------+          |             v               |                            |
      |                        |      [Set Attributes]       |                            |
  [Listen ]                    |      (Context/Sentiment)    |                            |
  [Respond]                    |             |               |                            |
      |                        |             v               |                            |
      +----------------------->|      [Queue Transfer]       |                            |
                               |             |               |                            |
                               |             v               |                            |
                               |      { Wait in Queue } --------------------------------->|
                               |                             |                            |
                               |                             |                       [Accept Call]
                               |                             |                            |
                               |                             |                            v
                               |                             |                       [View Context]
                               |                             |                       [Screen Pop  ]
                               |                             |                            |
                               |                             |                            v
      +<----------------------------------------------------------------------------- [Conversing]
      |                        |                             |                            |
   ( End ) <------------------------------------------------------------------------------+
```

### Legend
*   **Swimlanes**: Vertical partitions separating responsibilities (Client, Orchestrator, Intelligence, Resolution).
*   **[ Rectangles ]**: Tasks or Actions performed by a system actor.
*   **< Diamonds >**: Gateways (Decisions) where the process branches based on logic.
*   **{ Braces }**: Intermediate Events or States (like Waiting).
*   **( Circles )**: Start and End events.


## 18. Operational Support Model (RACI)

To ensure the stability, security, and efficiency of this "AI-First" Contact Center, specific roles must be assigned. The RACI matrix below defines the responsibility assignment for both the **Build/Engineering** and **Run/Operations** phases.

### 18.1 Key Roles Definition

*   **Cloud Platform Engineer (DevOps)**: Owns the Terraform code, AWS infrastructure (S3, Kinesis, Lambda, VPC), and CI/CD pipelines.
*   **AI/Conversation Engineer**: Owns the "Brain". Writes Prompts (Bedrock), defines Intents (Lex), and manages Python logic for tool calling.
*   **Call Center Manager (Ops Lead)**: Non-technical business owner. Manages agents, schedules, and high-level routing strategies.
*   **Supervisor**: Day-to-day floor management, monitoring live calls, and handling escalations.
*   **Agent**: The front-line user handling calls and chat.
*   **Security & Compliance**: Audit role ensuring PII redaction and encryption standards.
*   **AI Governance Board**: Cross-functional team (Legal/Product) reviewing AI safety, hallucination rates, and tone.

### 18.2 RACI Matrix

**R** = Responsible (Doer) | **A** = Accountable (Owner) | **C** = Consulted (Subject Matter Expert) | **I** = Informed

| Activity / Task | Cloud Engineer (DevOps) | AI Engineer | Ops Lead (Manager) | Supervisor | Security / Compliance | AI Gov Board |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **System Deployment (Terraform)** | **A/R** | C | I | I | C | I |
| **Prompt Engineering (Bedrock)** | I | **A/R** | C | I | C | C |
| **Lex Intent Training** | I | **A/R** | C | I | I | I |
| **Contact Flow Logic Changes** | **R** | C | **A** | I | I | I |
| **User Management (Add/Remove Agents)** | I | I | **A/R** | C | I | I |
| **Queue & Routing Profile Config** | C | I | **A/R** | C | I | I |
| **Handling Live Contacts** | I | I | I | C | I | I |
| **Handling Escalations** | I | I | C | **A/R** | I | I |
| **Audit Log Review (PII check)** | I | I | I | I | **A/R** | I |
| **Hallucination Threshold Tuning** | I | **R** | I | I | C | **A** |
| **Incident Response (System Down)** | **A/R** | C | C | I | I | I |
| **Q/A Scorecard Review** | I | I | I | **A/R** | I | I |

### 18.3 Operational Responsibility Segregation

1.  **Engineering (Technical)**
    *   **Scope**: Anything involving `.tf`, `.py`, or `.json` files.
    *   **Trigger**: Use standard Git Flow (Pull Requests) to deploy changes.
    *   **Duties**: Upgrading Lambda runtimes, changing DynamoDB capacity, modifying Bedrock System Prompts.

2.  **Operations (Business/Config)**
    *   **Scope**: Anything managed via the **Amazon Connect UI**.
    *   **Trigger**: Instant changes via Dashboard.
    *   **Duties**:
        *   Opening/Closing queues for holidays.
        *   Onboarding new agents (creating users).
        *   Listening to call recordings for quality assurance.
        *   Changing "Music on Hold" or simple announcements (if configured dynamically).

3.  **Governance (Safety)**
    *   **Scope**: Validation Agent logs and Contact Lens reports.
    *   **Duties**: Weekly review of "AI Insights" dashboard to ensure the bot is not giving financial advice it shouldn't be (Hallucination check).

