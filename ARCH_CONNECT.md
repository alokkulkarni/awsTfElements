# Architecture: Amazon Connect + Lex + Bedrock

This document details the architecture for the **Conversational Banking Assistant** using Amazon Connect as the primary interface for both Voice and Chat.

## High-Level Architecture

This architecture leverages **Amazon Connect** for telephony and session management, **Amazon Lex** for streaming speech recognition and conversational state, and **AWS Lambda + Amazon Bedrock** for intelligence and safety.

```ascii
                                      [User]
                                     /      \
                           (Phone Call)    (Chat Widget)
                                 |              |
                                 v              v
                        [Amazon Connect Instance]
                       (Orchestrator & Telephony)
                                 |
                                 v
                        [Amazon Lex V2] <-----------------------+
                   (Streaming ASR / NLU / TTS)                  |
                   (Maintains Conversation State)               |
                                 |                              |
                                 v                              |
                     [AWS Lambda (Fulfillment)]                 |
                     (The "Bridge" / Processor)                 |
                                 |                              |
                                 +-------------------------+    |
                                 |                         |    |
                                 v                         v    |
                       [Bedrock Guardrails]      [Amazon Bedrock (LLM)]
                       (Content Moderation)      (Claude 3 Haiku)
                       (The "Safety Layer")      (The "Brain")
```

## Components

### 1. Amazon Connect (The Front Door)
*   **Role**: Handles PSTN (Phone) connections, WebRTC (Chat) sessions, and contact flows.
*   **Integration**: Routes incoming contacts to Amazon Lex for conversational handling.

### 2. Amazon Lex V2 (The Conversational Engine)
*   **Role**:
    *   **ASR (Speech-to-Text)**: Converts streaming audio from Connect into text.
    *   **TTS (Text-to-Speech)**: Converts text responses back to audio using Amazon Polly (Neural).
    *   **State Management**: Tracks the conversation context.
*   **Configuration**: Configured with a "FallbackIntent" that catches all user input and passes it to the Lambda function for processing by the LLM.

### 3. AWS Lambda (The Bridge)
*   **Role**: Acts as the fulfillment hook for Lex.
*   **Logic**:
    1.  Receives transcribed text from Lex.
    2.  Calls **Amazon Bedrock** (Claude 3 Haiku) to generate a response.
    3.  Includes **Bedrock Guardrails** in the API call to ensure safety (Input/Output moderation).
    4.  Returns the safe text response to Lex.

### 4. Amazon Bedrock (The Brain & Safety)
*   **LLM**: Anthropic Claude 3 Haiku (Fast, cost-effective reasoning).
*   **Guardrails**: Filters out PII, toxicity, and financial advice violations before the model sees the input or the user sees the output.

## Why this Architecture?

1.  **True Conversation**: Amazon Lex supports **streaming audio**, allowing for "barge-in" (interruption) and natural pauses, unlike file-based approaches.
2.  **Managed Infrastructure**: No need to manage Load Balancers, ECS Clusters, or WebSocket servers. Amazon Connect and Lex are fully managed services.
3.  **Unified Logic**: The same Lambda/Bedrock backend serves both Voice callers and Chat users.
4.  **Safety**: Content moderation is intrinsic to the fulfillment flow via Bedrock Guardrails.

## Nova Sonic Integration (Optional)

If **Amazon Nova Sonic** (Generative Voice) is required instead of Amazon Polly:

*   **Challenge**: Amazon Lex natively integrates with Polly. Using Nova Sonic requires bypassing Lex's TTS.
*   **Complex Setup**:
    1.  Lambda would generate audio using Nova Sonic.
    2.  Lambda would save audio to S3.
    3.  Lambda would return the S3 URL to Connect (bypassing Lex for the response) OR use a custom "Play Audio" block in Connect.
*   **Benefit**: More emotive, human-like voice generation.
*   **Trade-off**: Higher latency (file generation vs streaming) and increased complexity.

## Deployment

This stack is standalone and can be deployed independently of the other stacks.

```bash
cd connect_lex_chatbot
terraform init
terraform apply
```
