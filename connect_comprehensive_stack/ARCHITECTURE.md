# Connect Comprehensive Stack Architecture

This document provides a detailed architectural overview of the **Connect Comprehensive Stack**, a production-ready Amazon Connect solution featuring Bedrock-primary conversational AI, intelligent tool calling with FastMCP 2.0, real-time hallucination detection, seamless agent handover, and a scalable **Data Lake** for advanced analytics.

## 1. High-Level Architecture (Federated & Hybrid)

The solution leverages a **Federated Hybrid Pattern** combining the flexibility of Bedrock-based Generative AI with the control and speed of specialized, domain-specific Bots.

*   **Gateway Bot (Router)**: The entry point (bedrock-primary) that uses Claude 3.5 Sonnet to understand intent and context.
*   **Specialized Bots**: Dedicated Lex V2 bots (Banking, Sales) that handle deterministic, high-compliance workflows.
*   **Connect Orchestrator**: The Contact Flow manages the routing between the Gateway and Specialized bots based on intent signals.

### Federated Architecture Diagram

```ascii
                                       +-----------------------------------------------------------------------------------+
                                       |                          AWS Cloud (Federated Architecture)                       |
                                       |                                                                                   |
      +--------+                       |     +------------------+         +----------------+          +----------------+   |
      |        |   Voice / Chat        |     |                  |Check    |                |          |                |   |
      |  User  +-------------------------->  +  Gateway Bot     +-------->+  Bedrock MCP   +--------->+ Claude 3.5     |   |
      |        |                       |     |  (Router)        |Intent   |  Lambda        |          | Sonnet         |   |
      +--------+                       |     +--------+---------+         +----------------+          +----------------+   |
                                       |              |                                                                    |
                                       |              | (Router Decision: "Transfer", "Banking", etc.)                     |
                                       |              v                                                                    |
                                       |     +--------+---------+                                                          |
                                       |     |                  |                                                          |
                                       |     |  Connect Flow    +---------------------------------------------------+      |
                                       |     |  Orchestrator    |                                                   |      |
                                       |     |                  |                                                   |      |
                                       |     +---+--------+-----+                                                   |      |
                                       |         |        |                                                         |      |
                                       |         |        |                                                         |      |
                                       |   +-----v--------v-----+                                         +---------v------+-----+
                                       |   |                    |                                         |                      |
                                       |   |   Banking Bot      +---------------------------------------->+    Sales Bot         |
                                       |   |   (Specialized)    |                                         |    (Specialized)     |
                                       |   |                    |                                         |                      |
                                       |   +---------+----------+                                         +-----------+----------+
                                       |             |                                                                |
                                       |             v                                                                v
                                       |   +---------+----------+                                         +-----------+----------+
                                       |   |   Banking Lambda   |                                         |    Sales Lambda      |
                                       |   |   (Deterministic)  |                                         |    (Deterministic)   |
                                       |   +--------------------+                                         +----------------------+
                                       |
                                       +-----------------------------------------------------------------------------------+
```

### Data Flow Description

1.  **Ingestion**: User interacts via Voice or Chat. Amazon Connect handles the session.
2.  **Gateway Analysis**: The **Gateway Bot** invokes Bedrock (Claude 3.5 Sonnet) to analyze the user's request.
3.  **Routing Decision**:
    *   **Conversational**: If the query is general, Bedrock answers directly.
    *   **Specialized**: If the query matches a domain (e.g., "I want to open an account"), Bedrock signals the intent to Amazon Connect.
4.  **Federated Handoff**: Connect transitions the contact to the appropriate **Specialized Bot** (e.g., Sales Bot).
5.  **Execution**: The Specialized Bot uses its dedicated Lambda (e.g., `sales_lambda`) to execute the business logic deterministically.

## 2. Observability & Data Lake Architecture

A centralized Data Lake aggregates logs from all federated components, ensuring a unified view of the entire customer journey regardless of which bot handled the interaction.

### Observability Diagram

```ascii
      +---------------------+      +----------------------+      +----------------------+      +----------------------+
      |  Gateway Bot        |      |  Banking Bot         |      |  Sales Bot           |      |  Specialized Lambdas |
      |  (Conversation Logs)|      |  (Conversation Logs) |      |  (Conversation Logs) |      |  (App Logs)          |
      +----------+----------+      +-----------+----------+      +----------+-----------+      +-----------+----------+
                 |                             |                            |                              |
                 v                             v                            v                              v
      +----------+-----------------------------+----------------------------+------------------------------+----------+
      |                                              CloudWatch Log Groups                                            |
      | (/aws/lex/gateway, /aws/lex/banking, /aws/lex/sales, /aws/lambda/banking, /aws/lambda/sales)                  |
      +----------+----------------------------------------------------------------------------------------------------+
                 |
                 | (Subscription Filters)
                 v
      +----------+-----------+
      |  Kinesis Firehose    |
      |  (Central Aggregator)|
      +----------+-----------+
                 |
                 | (Buffering & Batching)
                 v
      +----------+----------------------------------------------------------------+
      |                                   S3 Data Lake                            |
      |  s3://<bucket>/cloudwatch-logs/year=YYYY/month=MM/day=DD/                 |
      +----------+----------------------------------------------------------------+
                 |
                 v
      +----------+-----------+      +---------------------------+
      |   AWS Glue Catalog   |----->|       Amazon Athena       |
      |   (Table Definition) |      | (Unified SQL Interface)   |
      +----------------------+      +---------------------------+
```

### Components

1.  **Unified Logging**: Every Bot and Lambda writes to its own CloudWatch Log Group.
2.  **Subscription Filters**: Terraform automatically subscribes all new Log Groups to the central **Log Archive Firehose**.
3.  **S3 Aggregation**: Firehose writes all logs to the same partition structure in S3, preserving the `cloudwatch-logs/` prefix.
4.  **Athena Queries**: Existing Athena queries continue to work, allowing cross-component analysis (e.g., tracing a request from Gateway -> Bedrock -> Sales Bot -> Sales Lambda).

## 3. Real-Time Lifecycle Events

This solution uses EventBridge to capture granular contact state changes (e.g., `Queued`, `Connected`, `Disconnected`) in real-time, enabling "Live Backlog" monitoring that is faster than standard CTR generation.

#### Lifecycle Events Sequence

```ascii
      +----------------+       +----------------+       +----------------+       +----------------+
      | Amazon Connect |       |   EventBridge  |       | Kinesis        |       | Data Lake      |
      | Instance       |       |   Rule         |       | Firehose       |       | (S3/Athena)    |
      +-------+--------+       +-------+--------+       +-------+--------+       +-------+--------+
              |                        |                        |                        |
              | (Contact State Change) |                        |                        |
              +----------------------->| (Match Rule)           |                        |
              |                        +----------------------->|                        |
              |                        |                        +----------------------->| (Buffer & Write)
              |                        |                        |                        |
              | (Queued)               |                        |                        |
              +----------------------->|                        |                        |
              |                        |                        +----------------------->| (Row: Status=Queued)
              |                        |                        |                        |
              | (ConnectedToAgent)     |                        |                        |
              +----------------------->|                        |                        |
              |                        +----------------------->|                        |
              |                        |                        +----------------------->| (Row: Status=Connected)
              |                        |                        |                        |
              v                        v                        v                        v
                                                                                (SQL: Queued - Connected)
                                                                                = Current Backlog
```

## 4. Metrics Source Mapping

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

---

## 5. Component Deep Dive

### 5.1 Amazon Connect (The Orchestrator)
*   **Role**: Entry point and central router for all voice and chat interactions.
*   **Key Features**:
    *   **Gateway Contact Flow**: Routes to Gateway Bot initially.
    *   **Federated Routing**: Checks Gateway output signal to switch Flow execution to **Banking Bot** or **Sales Bot**.
    *   **Customer Queue Flow**: Manages wait experience with position updates and callback options
    *   **Contact Lens**: Real-time sentiment analysis and transcription
    *   **Queues**: GeneralAgentQueue for agent handover
    *   **Storage**: S3 storage for chat transcripts, call recordings, and contact trace records

### 5.2 Amazon Lex V2 (Federated Mesh)
*   **Gateway Bot**:
    *   **Role**: Smart Router. Uses Bedrock/LLM to categorize intent.
    *   **Fulfillment**: Bedrock MCP Lambda.
*   **Banking Bot**:
    *   **Role**: Specialized execution for "Check Balance", "Transfer".
    *   **Fulfillment**: Banking Lambda (Python).
*   **Sales Bot**:
    *   **Role**: Specialized execution for "Open Account".
    *   **Fulfillment**: Sales Lambda (Python).

### 5.3 Logging & Data Lake
*   **Unified Prefix**: All components write to `cloudwatch-logs/`.
*   **No Code Changes Required for Analytics**: Queries written for the monolithic bot work for the federated bots because the log structure (JSON) and storage path remain consistent.
