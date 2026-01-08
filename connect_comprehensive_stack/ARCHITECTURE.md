# Connect Comprehensive Stack Architecture

This document provides a detailed architectural overview of the **Connect Comprehensive Stack**, a production-ready Amazon Connect solution featuring Bedrock-primary conversational AI, intelligent tool calling with FastMCP 2.0, real-time hallucination detection, seamless agent handover, and a scalable **Data Lake** for advanced analytics.

## 1. High-Level Architecture (Hybrid)

The solution leverages a **Hybrid Pattern** combining the flexibility of Bedrock-based Generative AI with the speed and reliability of deterministic Lambdas. The main **Bedrock MCP Lambda** serves as an intelligent router:
*   **Specialized Intents** (e.g., Balance Check, Statements) are dispatched to lightweight, dedicated Lambdas for sub-second response times and zero token costs.
*   **Generative Path** (Complex Queries) queries are routed to Claude 3.5 Sonnet (via Bedrock) for contextual understanding and reasoning.

### Architecture Diagram

```ascii
                                       +-------------------------------------------------------------------------+
                                       |                       AWS Cloud (Zero Trust)                            |
                                       |                                                                         |
      +--------+                       |   +-------------------+       +-------------------------------------+   |
      |        |   Voice / Chat        |   |                   |       |          Observability              |   |
      |  User  +-------------------------->+   Amazon Connect  +------>+  CloudWatch Logs / Contact Lens     |   |
      |        |                       |   |                   |       |  CloudWatch Dashboard & Alarms      |   |
      +--------+                       |   +---------+---------+       +-------------------------------------+   |
                                       |             |                                                           |
                                       |             v                                                           |
                                       |   +---------+---------+                                                 |
                                       |   |                   |                                                 |
                                       |   |   Contact Flow    |                                                 |
                                       |   |                   |                                                 |
                                       |   +----+-------+------+                                                 |
                                       |        |       |                                                        |
                                       |        v       +---> (Error) --> Agent Queue                            |
                                       |   +----+----+                                                           |
                                       |   |         |   ALL Intents                                             |
                                       |   | Lex V2  +------------------------------------------------+          |
                                       |   |         |                                                |          |
                                       |   +---------+                                                |          |
                                       |                                                              v          |
                                       |                                                    +---------+-------+  |
                                       |                                                    |                 |  |
                                       |                                                    | Bedrock MCP     |  |
                                       |                                                    | Lambda (Router) |  |
                                       |                                                    +--------+--------+  |
                                       |                                                             |           |
                                       |                       +-------------------------------------+           |
                                       |                       |                                     |           |
                                       |             (Complexity > Threshold)                  (Specialized)     |
                                       |                       |                                     |           |
                                       |         +-------------v-------------+             +---------v----------+|
                                       |         |                           |             |                    ||
                                       |         |     Amazon Bedrock        |             | Specialized Lambdas||
                                       |         | (Generative "Smart Path") |             | ("Fast Path")      ||
                                       |         +-------------+-------------+             +---------+----------+|
                                       |                       |                                     |           |
                                       |         +-------------+-------------+                       |           |
                                       |         |             |             |                       v           |
                                       |         v             v             v               +-------+------+    |
                                       | +-------+----+  +-----+------+  +---+--------+      |              |    |
                                       | | FastMCP    |  | Validation |  | Handover   |      | Core Banking |    |
                                       | | Tools      |  | Agent      |  | Detection  |      | APIs         |    |
                                       | +------------+  +------------+  +------------+      |              |    |
                                       |                                                     +--------------+    |
                                       +-------------------------------------------------------------------------+
```

### Data Flow Description

1.  **Ingestion**: User interacts via Voice or Chat. Amazon Connect handles the session.
2.  **Orchestration**: Connect invokes the Bedrock Primary Contact Flow.
3.  **Pass-through**: Lex V2 receives user input. If it matches a Specialized Intent (e.g. "Check Balance"), Lex identifies it.
4.  **Routing (Lambda)**:
    *   **Fast Path**: If intent is specialized, the Router invokes the dedicated Child Lambda (e.g., `check_balance.py`) synchronously.
    *   **Smart Path**: If intent is fallback/unknown, the Router invokes Claude 3.5 Sonnet to generate a response.
    *   **Tool Execution**: Bedrock can request tool execution (e.g., `find_nearest_branch`) which is handled by the same Lambda.
    *   **Validation**: The response is validated by the Validation Agent. Latency, Hallucination Scores, and security violations are logged to the Data Lake.

## 2. Data Lake Architecture

The solution includes a scalable Serverless Data Lake to analyze Contact Trace Records (CTRs), Agent Event streams, and Generative AI Insights.

### Data Lake Diagram

```ascii
                               +-----------------+             +---------------------+
                               |  Amazon Connect |             | Bedrock MCP Lambda  |
                               +--------+--------+             +----------+----------+
                                        |                                 |
                 +----------------------+----------------------+          | (AI Insights & Validation Logs)
                 | (CTR Stream)         | Metric Stream        |          |
                 v (Agent Events)       v                      v          v
      +----------+-----------+      +---+----------------+  +----------+----------+
      | Kinesis Data Stream  |      | CloudWatch Metrics |  | Kinesis Data Stream |
      | (ctrs & agent-events)|      | (System Health)    |  | (ai-insights)       |
      +----------+-----------+      +---+----------------+  +----------+----------+
                 |                      |                              |
                 v                      v                              v
      +----------+-----------+      +---+----------------+  +----------+-----------+
      | Kinesis Firehose     |      | Kinesis Firehose   |  | Kinesis Firehose     |
      | (Batch & Buffer)     |      | (Batch & Buffer)   |  | (Batch & Buffer)     |
      +----------+-----------+      +---+----------------+  +----------+-----------+
                 |                      |                              |
                 +----------------------+------------------------------+
                                        | Parquet / JSON
                                        v
                            +-----------+-----------+                     +------------------+
                            |     S3 Data Lake      |<--------------------+ Contact Lens     |
                            | (Partitioned by Date) |                     | (Sentiment/JSON) |
                            +-----------+-----------+                     +------------------+
                                        |
                            +-----------+-----------+
                            |   AWS Glue Catalog    |
                            | (Database & Tables)   |
                            +-----------+-----------+
                                        |
                            +-----------+-----------+
                            |     Amazon Athena     |
                            |    (SQL Interface)    |
                            +-----------+-----------+
                                        |
                            +-----------+-----------+
                            |   Amazon QuickSight   |
                            |    (Visualization)    |
                            +-----------------------+
```

### Components

1.  **Kinesis Data Streams**: Real-time ingestion of raw records from Connect & Bedrock Lambda.
2.  **Kinesis Firehose**: Buffers data (e.g., 5MB or 300s) and writes it to S3.
3.  **S3 Data Lake**: Durable storage with Hive-style partitioning (`year=YYYY/month=MM/day=DD`).
4.  **AWS Glue**: Metastore defining the schema for `ctrs`, `agent_events`, `ai_insights`, and `contact_lens_analysis`.
5.  **Athena**: Serverless SQL engine to query S3 data directly.
6.  **Metric Stream**: Continuous stream of CloudWatch metrics (Connect, Lambda, BedrockValidation) to S3.
7.  **Contact Lens Integration**: Direct Glue table mapping to Contact Lens JSON analysis files in S3.

For example queries, see [ATHENA_QUERIES.md](ATHENA_QUERIES.md).
    *   Customer Queue Flow manages wait with position updates and callback option
9.  **Monitoring**: CloudWatch tracks:
    *   Hallucination detection rates
    *   Conversation metrics (duration, turns, tool usage)
    *   Queue metrics (size, wait times, abandonment)
    *   Error rates and Lambda performance
10. **Audit Trail**: All interactions logged to:
    *   CloudWatch Logs (structured logging)
    *   S3 (chat transcripts, call recordings, contact trace records)
    *   DynamoDB (hallucination logs, callback requests)
    *   CloudTrail (API access auditing)

---

## 2. Component Deep Dive

### 2.1 Amazon Connect (The Hub)
*   **Role**: Entry point for all voice and chat interactions.
*   **Key Features**:
    *   **Bedrock Primary Contact Flow**: Simplified flow that greets users and passes control to Lex
    *   **Customer Queue Flow**: Manages wait experience with position updates and callback options
    *   **Contact Lens**: Real-time sentiment analysis and transcription
    *   **Queues**: GeneralAgentQueue for agent handover
    *   **Storage**: S3 storage for chat transcripts, call recordings, and contact trace records

### 2.2 Amazon Lex V2 (The Pass-Through)
*   **Role**: Simple pass-through layer that forwards all input to Lambda.
*   **Configuration**:
    *   **Single Intent**: FallbackIntent only (no complex intent definitions)
    *   **Two Locales**: en_GB (primary) and en_US (for Connect compatibility)
    *   **Lambda Integration**: All input immediately forwarded to Bedrock MCP Lambda
    *   **Conversation History**: Maintains session attributes for context preservation
*   **Simplified Architecture**: Lex no longer performs NLU; it simply acts as a connector between Connect and Lambda

### 2.3 Bedrock MCP Lambda (The Brain)
The primary fulfillment Lambda function that orchestrates the entire conversational AI experience.

*   **Path**: `connect_comprehensive_stack/lambda/bedrock_mcp/`
*   **Structure**:
    *   `lambda_function.py`: **Main orchestrator**
        *   Extracts user input and conversation history from Lex event
        *   Invokes Claude 3.5 Sonnet with system prompt and tools
        *   Handles tool_use responses by executing FastMCP 2.0 tools
        *   Manages conversation history serialization
        *   Detects handover needs and initiates agent transfer
        *   Formats responses for Lex delivery
    *   `validation_agent.py`: **Hallucination detection**
        *   ValidationAgent class with comprehensive validation methods
        *   Detects fabricated data not present in tool results
        *   Checks domain boundaries and document accuracy
        *   Logs hallucinations to DynamoDB with severity levels
        *   Publishes CloudWatch metrics
        *   Implements severity-based response strategies

*   **FastMCP 2.0 Tools**:
    *   `get_branch_account_opening_info(account_type)`: Returns branch account opening process and required documents
    *   `get_digital_account_opening_info(account_type)`: Returns digital account opening process and required documents
    *   `get_debit_card_info(card_type)`: Returns debit card information, features, and ordering process
    *   `find_nearest_branch(location)`: Returns nearest branch with address, hours, and services

*   **Handover Detection Logic**:
    *   Explicit agent requests (keywords: "agent", "human", "person")
    *   Frustration detection (keywords: "frustrated", "annoyed", "useless")
    *   Repeated query detection (same intent 3+ times)
    *   Capability limitation detection from Bedrock response
    *   Tool failure counting with threshold checking

### 2.4 Amazon Bedrock (The Conversational AI Engine)
*   **Role**: Primary conversational AI using Claude 3.5 Sonnet.
*   **Model**: `anthropic.claude-3-5-sonnet-20241022-v2:0`
*   **Capabilities**:
    *   Natural language understanding and generation
    *   Tool calling with FastMCP 2.0 integration
    *   Multi-turn conversation with context awareness
    *   Banking domain expertise via system prompt
*   **System Prompt**: Configured as a banking service agent specializing in:
    *   Account opening processes (branch and digital)
    *   Debit card information and ordering
    *   Branch location services
    *   Natural, helpful conversation style

### 2.5 Validation Agent (The Safety Net)
*   **Role**: Real-time hallucination detection and prevention.
*   **Detection Methods**:
    *   **Fabricated Data**: Compares response facts against tool results
    *   **Domain Boundaries**: Ensures responses stay within banking topics
    *   **Document Accuracy**: Validates document requirements match tool data
    *   **Branch Accuracy**: Verifies branch information is correct
*   **Response Strategies**:
    *   **High Severity**: Safe fallback message, no regeneration
    *   **Medium Severity**: Regenerate with stricter constraints
    *   **Low Severity**: Log and continue
*   **Logging**: DynamoDB table with 90-day TTL containing:
    *   log_id, timestamp, user_query, tool_results, model_response
    *   hallucination_type, severity, validation_details, action_taken
*   **Metrics**: CloudWatch metrics for monitoring:
    *   HallucinationDetectionRate
    *   ValidationSuccessRate
    *   ValidationLatency

### 2.5 Custom Agent Workspace (CCP)
*   **Role**: Secure interface for agents.
*   **Components**:
    *   **S3 Static Website**: Hosts the custom CCP HTML/JS.
    *   **CloudFront**: Delivers the site globally with low latency.
    *   **AWS WAF**: Protects the agent portal from common web exploits (SQLi, XSS).
    *   **Origin Access Control (OAC)**: Ensures S3 is only accessible via CloudFront.

---

## 3. User Journey Flows

### 3.1 Simple Query with Tool Execution

This flow demonstrates a basic account opening inquiry that requires tool execution.

```
User                Lex V2              Lambda              Bedrock             FastMCP Tool
 |                    |                    |                    |                    |
 | "How do I open     |                    |                    |                    |
 |  a checking        |                    |                    |                    |
 |  account?"         |                    |                    |                    |
 |------------------->|                    |                    |                    |
 |                    | FallbackIntent     |                    |                    |
 |                    |------------------->|                    |                    |
 |                    |                    | Invoke with        |                    |
 |                    |                    | system prompt      |                    |
 |                    |                    | + tools            |                    |
 |                    |                    |------------------->|                    |
 |                    |                    |                    | tool_use:          |
 |                    |                    |                    | get_branch_        |
 |                    |                    |                    | account_opening    |
 |                    |                    |<-------------------|                    |
 |                    |                    | Execute tool       |                    |
 |                    |                    |----------------------------------->|
 |                    |                    |                    |                    | Return docs
 |                    |                    |<-----------------------------------|
 |                    |                    | Send tool result   |                    |
 |                    |                    |------------------->|                    |
 |                    |                    |                    | Compose response   |
 |                    |                    |<-------------------|                    |
 |                    |                    | Validate response  |                    |
 |                    |                    | (No hallucination) |                    |
 |                    | Response: "To open |                    |                    |
 |                    | a checking account |                    |                    |
 |                    | at a branch..."    |                    |                    |
 |<-------------------|--------------------|                    |                    |
```

### 3.2 Multi-turn Conversation with Context

This flow demonstrates conversation history management across multiple turns.

```
User                Lex V2              Lambda              Bedrock
 |                    |                    |                    |
 | "What debit cards  |                    |                    |
 |  do you offer?"    |                    |                    |
 |------------------->|                    |                    |
 |                    | FallbackIntent     |                    |
 |                    |------------------->|                    |
 |                    |                    | Invoke + tool      |
 |                    |                    |------------------->|
 |                    | Response: "We      |                    |
 |                    | offer Classic..."  |                    |
 |<-------------------|--------------------|                    |
 |                    |                    |                    |
 | "Which one has     |                    |                    |
 |  cashback?"        |                    |                    |
 |------------------->|                    |                    |
 |                    | FallbackIntent     |                    |
 |                    | + history          |                    |
 |                    |------------------->|                    |
 |                    |                    | Invoke with        |
 |                    |                    | conversation       |
 |                    |                    | history            |
 |                    |                    |------------------->|
 |                    |                    |                    | (Uses context)
 |                    | Response: "The     |                    |
 |                    | Premium card..."   |                    |
 |<-------------------|--------------------|                    |
```

### 3.3 Hallucination Detection and Recovery

This flow demonstrates the validation agent detecting and preventing a hallucination.

```
User                Lambda              Bedrock             ValidationAgent     DynamoDB
 |                    |                    |                    |                    |
 | "What documents    |                    |                    |                    |
 |  do I need?"       |                    |                    |                    |
 |------------------->|                    |                    |                    |
 |                    | Invoke + tool      |                    |                    |
 |                    |------------------->|                    |                    |
 |                    | Tool result:       |                    |                    |
 |                    | [ID, Proof of      |                    |                    |
 |                    |  Address]          |                    |                    |
 |                    |<-------------------|                    |                    |
 |                    | Response: "You     |                    |                    |
 |                    | need ID, Address,  |                    |                    |
 |                    | and Birth Cert"    |                    |                    |
 |                    |<-------------------|                    |                    |
 |                    | Validate response  |                    |                    |
 |                    |----------------------------------->|                    |
 |                    |                    |                    | Detect: "Birth     |
 |                    |                    |                    | Cert" not in       |
 |                    |                    |                    | tool results       |
 |                    |                    |                    | Severity: MEDIUM   |
 |                    |                    |                    |------------------->|
 |                    |                    |                    | Log hallucination  |
 |                    |                    |                    |<-------------------|
 |                    |<-----------------------------------|                    |
 |                    | Regenerate with    |                    |                    |
 |                    | stricter prompt    |                    |                    |
 |                    |------------------->|                    |                    |
 |                    | Corrected response |                    |                    |
 |                    |<-------------------|                    |                    |
 | Response: "You     |                    |                    |                    |
 | need ID and        |                    |                    |                    |
 | Proof of Address"  |                    |                    |                    |
 |<-------------------|                    |                    |                    |
```

### 3.4 Agent Handover with Context Preservation

This flow demonstrates intelligent handover detection and context passing to the agent.

```
User                Lambda              Bedrock             Connect Queue
 |                    |                    |                    |
 | "I need to speak   |                    |                    |
 |  to an agent"      |                    |                    |
 |------------------->|                    |                    |
 |                    | Detect handover    |                    |
 |                    | (explicit request) |                    |
 |                    |                    |                    |
 |                    | Format context:    |                    |
 |                    | - Main query       |                    |
 |                    | - Topics discussed |                    |
 |                    | - Info collected   |                    |
 |                    |                    |                    |
 |                    | Return:            |                    |
 |                    | TransferToAgent    |                    |
 |                    | + context          |                    |
 |                    |----------------------------------->|
 |                    |                    |                    |
 | "I'm connecting    |                    |                    |
 |  you to an agent"  |                    |                    |
 |<-------------------|                    |                    |
 |                    |                    |                    | Enter queue
 |                    |                    |                    | (with context)
 | Queue flow:        |                    |                    |
 | - Position updates |                    |                    |
 | - Callback option  |                    |                    |
 |<-------------------------------------------------------|
```

---

## 4. Infrastructure as Code (Terraform)

The project follows a **modular** Terraform structure to ensure reusability and separation of concerns.

### 4.1 Directory Structure
```
awsTfElements/
├── resources/                  # Reusable Generic Modules
│   ├── connect/                # Connect Instance & Config
│   ├── lex/                    # Lex Bot Shell
│   ├── lambda/                 # Generic Lambda Wrapper
│   ├── s3/                     # Secure S3 Buckets
│   ├── kms/                    # Encryption Keys
│   └── ... (dynamodb, waf, etc.)
│
└── connect_comprehensive_stack/ # The Main Deployment
    ├── main.tf                 # Orchestration of modules
    ├── variables.tf            # Configuration & Feature Flags
    ├── providers.tf            # AWS Provider (Multi-region support)
    └── lambda/                 # Application Code
        └── lex_fallback/       # Modular Python Code
```

### 4.2 Key Configuration (`variables.tf`)
The stack is highly configurable via Terraform variables:

| Variable | Description | Default |
| :--- | :--- | :--- |
| `region` | Primary deployment region | `eu-west-2` (London) |
| `project_name` | Prefix for all resources | `connect-comprehensive` |
| `bedrock_mcp_lambda` | Lambda configuration object | See below |

**Bedrock MCP Lambda Configuration:**
```hcl
bedrock_mcp_lambda = {
  source_dir = "lambda/bedrock_mcp"
  handler    = "lambda_function.lambda_handler"
  runtime    = "python3.11"
  timeout    = 60
}
```

### 4.3 Environment Variables
Terraform injects configuration directly into the Bedrock MCP Lambda environment:
*   `BEDROCK_MODEL_ID` -> Claude 3.5 Sonnet model identifier
*   `AWS_REGION` -> Deployment region
*   `LOG_LEVEL` -> Logging level (INFO)
*   `ENABLE_HALLUCINATION_DETECTION` -> Enable validation agent (true)
*   `HALLUCINATION_TABLE_NAME` -> DynamoDB table for hallucination logs

---

## 5. Security & Compliance

1.  **Zero Trust Encryption**:
    *   All S3 buckets (Recordings, Transcripts, Logs) are encrypted using a **Customer Managed KMS Key**.
    *   DynamoDB tables are encrypted at rest.

2.  **Network Security**:
    *   **WAF**: Deployed in `us-east-1` (Global) to protect the CloudFront distribution.
    *   **OAC**: S3 buckets are completely private; only accessible via CloudFront signed requests.

3.  **Identity & Access**:
    *   **IAM Roles**: Least-privilege policies for Lambda (only access to specific DynamoDB table and Bedrock models).
    *   **Resource Policies**: S3 bucket policies strictly limit access to Connect and CloudTrail services.

4.  **Audit Trails**:
    *   **CloudTrail**: Multi-region trail enabled, logging to a dedicated, locked-down S3 bucket.
    *   **Contact Lens**: Full transcript and sentiment logging for compliance review.
