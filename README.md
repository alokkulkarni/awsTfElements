# AWS Terraform Elements: Multimodal Chatbot

This repository contains the Infrastructure as Code (Terraform) for a secure, scalable, **Multimodal Chatbot** capable of handling both **Live Chat** (Text) and **Speech-to-Speech** interactions.

The system is built with a "Safety First" approach, utilizing **Amazon Bedrock Guardrails** to ensure all content—whether spoken or typed—is moderated for toxicity, PII, and policy violations.

## Project Structure

The project is divided into modular stacks for incremental deployment:

*   **`Live_chat_Content_Moderation/`**: The core stack. Contains the "Brain" of the system.
    *   Resources: API Gateway, Lambda, DynamoDB, Bedrock Guardrails, SQS, AppSync, S3/CloudFront (Frontend).
*   **`speech_to_speech_chat/`**: The extension stack. Adds voice capabilities.
    *   Resources: Network Load Balancer (NLB), Amazon ECS (Fargate), connection to Bedrock Nova Sonic.
*   **`resources/`**: Shared Terraform modules (VPC, ECS, NLB, Lambda, etc.) used by the stacks.

## Architecture

For a detailed breakdown of the components, data flow, and ASCII diagrams, please refer to [ARCH.md](./ARCH.md).

## Getting Started

### Prerequisites
*   Terraform v1.5+
*   AWS CLI configured with appropriate permissions.
*   An S3 bucket for Terraform remote state (configured in `provider.tf`).

### Deployment

1.  **Deploy the Core Stack**:
    ```bash
    cd Live_chat_Content_Moderation
    terraform init
    terraform apply
    ```

2.  **Deploy the Speech Stack**:
    ```bash
    cd ../speech_to_speech_chat
    terraform init
    terraform apply
    ```

## Key Features
*   **Unified Moderation**: Voice inputs are converted to text and passed through the exact same moderation pipeline as text chats.
*   **Real-time Response**: Uses AWS AppSync for low-latency delivery of bot responses.
*   **Scalable**: Built on serverless (Lambda) and containerized (Fargate) compute.
*   **Secure**: WAF protection, IAM least privilege, and encrypted data stores.
