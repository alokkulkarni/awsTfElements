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
