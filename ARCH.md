# Architecture: Multimodal Chatbot with Content Moderation

This document details the architecture, components, and data flow for the Multimodal Chatbot system. The system integrates a **Speech-to-Speech** interface with a robust **Live Chat Content Moderation** pipeline.

## High-Level Architecture

The architecture is designed to be modular, separating the **Speech Gateway** (Audio processing) from the **Core Logic** (Moderation, Guardrails, and Response Generation).

```ascii
                                      [User]
                                     /      \
                           (Text Chat)      (Audio/Speech)
                                 /              \
                                v                v
  [CloudFront] --> [S3 (Web App)]              [Network Load Balancer (NLB)]
        |                                        |
        v                                        v
   [AWS WAF]                           [Amazon ECS (Speech Gateway)]
        |                               |        |
        v                               |        | (1. Audio -> Text)
 [API Gateway (HTTP)] <--(Text)---------+        +--> [Amazon Bedrock (Nova Sonic)]
        |                               |        | (4. Text -> Audio)
        v                               |
   [Amazon SQS (FIFO)]                  | (3. Subscribe to Reply)
        |                               |
        v                               v
   [AWS Lambda (Backend)] --------> [AWS AppSync]
        |          ^                    ^
        |          |                    |
        v          | (2. Process)       |
 [Bedrock Guardrails]                   |
 [ & Claude Model   ]                   |
        |                               |
        v                               |
 [DynamoDB Tables] (History/Logs)       |
                                        |
   (Text Reply) ------------------------+
```

## Components

### 1. Speech Layer (New Stack: `speech_to_speech_chat`)
*   **Network Load Balancer (NLB)**: Handles low-latency TCP traffic for incoming audio streams.
*   **Amazon ECS (Fargate)**: Hosts the **Speech Gateway** containers.
    *   **Speech-to-Text (STT)**: Streams user audio to **Amazon Bedrock (Nova Sonic)** to convert speech to text.
    *   **Text-to-Speech (TTS)**: Receives text replies and uses **Amazon Bedrock (Nova Sonic)** to generate audio response.
    *   **Orchestration**: Forwards converted text to the API Gateway and subscribes to AppSync for responses.

### 2. Core Logic & Moderation (Existing Stack: `Live_chat_Content_Moderation`)
*   **Amazon API Gateway (HTTP API)**: The central entry point for all text-based interactions (from both the Web UI and the Speech Gateway).
*   **Amazon SQS (FIFO)**: Buffers incoming messages to ensure order and prevent system overload.
*   **AWS Lambda (Backend)**: The core processor.
    *   Validates input.
    *   Invokes **Amazon Bedrock Guardrails** to check for PII, toxicity, and policy violations.
    *   Invokes the LLM (Claude 3 Haiku) for response generation.
    *   Stores conversation history in **DynamoDB**.
*   **Amazon Bedrock Guardrails**: Enforces safety policies on both input prompts and model responses.
*   **AWS AppSync**: Provides a real-time GraphQL subscription endpoint. The Speech Gateway listens here to receive the bot's response immediately.

### 3. Frontend & Security
*   **Amazon S3 & CloudFront**: Hosts the React-based web application for text chat users.
*   **AWS WAF**: Protects the API Gateway and CloudFront distribution from common web exploits.

## Data Flow

1.  **Ingestion**:
    *   **Text**: User types in the Web UI -> CloudFront -> API Gateway.
    *   **Speech**: User speaks -> NLB -> ECS Speech Gateway -> Bedrock (STT) -> Text -> API Gateway.

2.  **Processing**:
    *   API Gateway pushes the message to an SQS FIFO queue.
    *   Lambda consumes the message.
    *   Lambda calls Bedrock Guardrails to sanitize the input.
    *   Lambda calls the LLM to generate a response.
    *   Lambda calls Bedrock Guardrails again to sanitize the output.

3.  **Response**:
    *   Lambda publishes the final text response to **AWS AppSync**.
    *   **Text Users**: The Web UI receives the update via AppSync subscription.
    *   **Speech Users**: The ECS Speech Gateway receives the update via AppSync subscription.
        *   The Gateway calls Bedrock (TTS) to generate audio.
        *   Audio is streamed back to the user via the open TCP connection.

## Deployment Strategy

The system is deployed in two incremental stacks:

1.  **`Live_chat_Content_Moderation`**: Deploys the core logic, databases, API Gateway, and frontend.
2.  **`speech_to_speech_chat`**: Deploys the NLB and ECS cluster, connecting to the core stack via remote state outputs (VPC ID, API URL, etc.).
