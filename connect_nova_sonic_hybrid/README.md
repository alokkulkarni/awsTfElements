# Hybrid Connect & Nova Sonic Architecture

This project deploys a next-generation contact center architecture that utilizes a hybrid approach for multimodal interactions.

## Architecture Overview

The solution splits interactions into two optimized paths:

1.  **Text Chat Channel (Standard)**:
    *   **Flow**: User -> Amazon Connect -> Amazon Lex V2 -> Lambda (Chat) -> Bedrock (Claude 3 Haiku).
    *   **Purpose**: Handles web chat, SMS, and text-based interactions.
    *   **Logic**: Uses standard Lex intents and slots.
    *   **Safety**: Bedrock Guardrails applied in the Lambda fulfillment.

2.  **Voice Channel (Nova Sonic)**:
    *   **Flow**: User -> Amazon Connect -> Lambda (Voice Orchestrator) <-> Nova Sonic (Bidirectional Stream).
    *   **Purpose**: Handles voice calls with ultra-low latency and expressive audio.
    *   **Logic**: Uses a bidirectional stream to process audio chunks in real-time.
    *   **Safety**: Bedrock Guardrails applied to the stream events in real-time.
    *   **Human Handover**: Intelligent detection of "Talk to Agent" requests with transparent handover to Amazon Connect queues.

## Key Features

### 1. Polyglot Lambda Support
The architecture now supports multiple runtimes for all Lambda functions, giving you the flexibility to choose your preferred language:
*   **Node.js (Default)**: High-performance, asynchronous event handling.
*   **Python**: Uses **FastMCP** for the MCP server and Boto3 for AWS SDK interactions.
*   **Go**: Ultra-low latency, statically typed implementation for high-throughput voice processing.

### 2. Localization & Region Awareness
The system is designed for global deployment with built-in localization support:
*   **Infrastructure**: A `LOCALE` Terraform variable injects the target locale (e.g., `en_US`, `en_GB`, `fr_FR`) into all Lambda functions.
*   **Validation**: The MCP Server adapts its validation logic (e.g., Zip Code formats) based on the active locale.
*   **Currency**: Financial tools automatically return the correct currency symbol (USD, GBP, EUR).
*   **AI Context**: Both Chat (Claude) and Voice (Nova Sonic) models receive the locale in their system prompts to ensure culturally appropriate responses.

### 3. FastMCP Integration
The Python MCP Server implementation utilizes the **FastMCP** library, providing a robust, decorator-based approach to defining tools and resources. This simplifies the creation of new tools and ensures strict type validation using Pydantic models.

## Observability & Compliance (Audit Trails)

To ensure "all bells and whistles" for problem-solving and regulatory compliance, this stack includes a comprehensive logging and monitoring architecture:

### 1. Centralized Audit Logging (S3)
*   **Resource**: `aws_s3_bucket.audit_logs`
*   **Encryption**: Server-side encryption using a dedicated KMS Key (`aws_kms_key.log_key`).
*   **Versioning**: Enabled to prevent accidental deletion or tampering of audit logs.
*   **Contents**:
    *   **Connect Call Recordings**: Encrypted audio files of all voice interactions.
    *   **Connect Chat Transcripts**: JSON transcripts of all text interactions.
    *   **Bedrock Invocation Logs**: Full request/response payloads for every AI model invocation (Text & Voice), useful for debugging and safety audits.

### 2. CloudWatch Logs & Retention
*   **Log Groups**: Dedicated log groups for Lex, Chat Lambda, and Voice Lambda.
*   **Retention**: Configured for **365 days** (configurable) to meet standard compliance requirements.
*   **Encryption**: All CloudWatch logs are encrypted using the same KMS key.

### 3. Contact Lens for Amazon Connect
*   **Enabled**: Provides advanced analytics, sentiment analysis, and automated categorization of contacts.

## Remote State Management

For production deployments, it is critical to store the Terraform state remotely to allow collaboration and prevent state corruption.

1.  **Create Backend Resources**: Manually create an S3 Bucket and a DynamoDB Table (for locking) in your AWS account.
2.  **Configure `providers.tf`**: Uncomment the `backend "s3"` block in `providers.tf` and fill in your bucket and table names.
    ```hcl
    backend "s3" {
      bucket         = "my-terraform-state-bucket"
      key            = "connect-nova-sonic-hybrid/terraform.tfstate"
      region         = "us-east-1"
      dynamodb_table = "my-terraform-lock-table"
      encrypt        = true
    }
    ```
3.  **Initialize**: Run `terraform init` to migrate your local state to the remote backend.

## Zero Trust Security Implementation

This architecture adheres to Zero Trust principles by enforcing strict least-privilege access controls:

*   **Identity-Based Access**:
    *   **Chat Lambda Role**: Explicitly allowed to invoke *only* the `anthropic.claude-3-haiku` model and the specific Guardrail ARN. It cannot access other models or resources.
    *   **Voice Lambda Role**: Explicitly allowed to invoke *only* the `amazon.nova-sonic-v1` model via `InvokeModelWithResponseStream`. It cannot perform standard invocations or access other models.
    *   **Lex Role**: Minimal permissions required for bot execution.

*   **Resource Isolation**:
    *   The Bedrock Guardrail is deployed as a shared resource but referenced by specific ARNs in IAM policies, preventing unauthorized usage by other entities.
    *   Lambda functions are isolated by function-specific roles.

*   **Secure Communication**:
    *   All data in transit (Connect to Lambda, Lambda to Bedrock) is encrypted via AWS standard TLS 1.2+.
    *   No public access to Lambda functions or databases.

## Deployment Instructions

1.  **Prerequisites**:
    *   Terraform v1.0+
    *   AWS Credentials configured
    *   Node.js 18.x (for local testing of Lambda code if needed)

2.  **Deploy**:
    ```bash
    cd connect_nova_sonic_hybrid
    terraform init
    terraform apply
    ```

3.  **Post-Deployment**:
    *   Configure the Amazon Connect Contact Flow to route "Chat" contacts to the Lex Bot.
    *   Configure the Amazon Connect Contact Flow to route "Voice" contacts to invoke the `voice-orchestrator` Lambda.

## Directory Structure

*   `main.tf`: Core infrastructure definition.
*   `lambda_chat/`: Node.js code for text chat fulfillment.
*   `lambda_voice/`: Node.js code for voice stream orchestration.
*   `../resources/bedrock_guardrail/`: Shared Terraform module for content safety.
