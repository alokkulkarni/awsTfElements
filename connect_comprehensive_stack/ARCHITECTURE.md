# Connect Comprehensive Stack Architecture

This document provides a detailed architectural overview of the **Connect Comprehensive Stack**, a production-ready Amazon Connect solution featuring advanced AI integration, tiered security validation, and a custom agent workspace.

## 1. High-Level Architecture

The solution leverages a **Hub-and-Spoke** architecture where Amazon Connect acts as the central communication hub, delegating logic to Amazon Lex and AWS Lambda, which in turn orchestrate services like Amazon Bedrock, DynamoDB, and internal validation logic.

### Architecture Diagram

```
                                       +-----------------------------------------------------------------------+
                                       |                       AWS Cloud (Zero Trust)                          |
                                       |                                                                       |
      +--------+                       |   +-------------------+       +-----------------------------------+   |
      |        |   Voice / Chat        |   |                   |       |          Observability            |   |
      |  User  +-------------------------->+   Amazon Connect  +------>+  CloudWatch Logs / Contact Lens   |   |
      |        |                       |   |                   |       |  (Real-time Sentiment/Scribe)     |   |
      +--------+                       |   +---------+---------+       +-----------------------------------+   |
                                       |             |                                                         |
                                       |             v                                                         |
                                       |   +---------+---------+                                               |
                                       |   |                   |                                               |
                                       |   |   Contact Flow    |                                               |
                                       |   |                   |                                               |
                                       |   +----+-------+------+                                               |
                                       |        |       |                                                      |
                                       |        |       +----------------------------------+                   |
                                       |        v                                          |                   |
                                       |   +----+----+    Fallback (Unrecognized)    +-----+------+            |
                                       |   |         +------------------------------>+            |            |
                                       |   | Lex V2  |                               |   Lambda   |            |
                                       |   |         +<------------------------------+ (Fallback) |            |
                                       |   +---------+      Delegate (Recognized)    +-----+------+            |
                                       |                                                   |                   |
                                       |                                                   v                   |
                                       |                                         +---------+---------+         |
                                       |                                         |                   |         |
                                       |                                         |  Amazon Bedrock   |         |
                                       |                                         | (Classification)  |         |
                                       |                                         |                   |         |
                                       |                                         +---------+---------+         |
                                       |                                                   |                   |
                                       |                                                   v                   |
                                       |                                         +---------+---------+         |
                                       |                                         | Bedrock Guardrail |         |
                                       |                                         | (Content Mod.)    |         |
                                       |                                         +-------------------+         |
                                       |                                                                       |
                                       |                                                                       |
                                       |   +-------------------+       +-----------------------------------+   |
                                       |   |                   |       |                                   |   |
                                       |   |    Agent Queue    |<------+      DynamoDB (New Intents)       |   |
                                       |   |                   |       |                                   |   |
                                       |   +---------+---------+       +-----------------------------------+   |
                                       |             |                                                         |
                                       |             v                                                         |
      +--------+                       |   +---------+---------+       +-----------------------------------+   |
      |        |   HTTPS (WAF)         |   |                   |       |                                   |   |
      | Agent  +<--------------------------+   Human Agent     |       |    S3 (Recordings/Transcripts)    |   |
      |        |   Custom CCP          |   |                   |       |          (KMS Encrypted)          |   |
      +--------+                       |   +-------------------+       +-----------------------------------+   |
                                       |                                                                       |
```
      +--------+                       |   +-------------------+       +-----------------------------------+   |
      | Mobile |   Push Notification   |   |                   |       |                                   |   |
      |  App   +<--------------------------+        SNS        |<------+      DynamoDB (Auth State)        |   |
      |        |                       |   |                   |       |                                   |   |
      |        +-------------------------->+    API Gateway    +------>+        Lambda (Auth API)          |   |
      +--------+      HTTPS (API)      |   +-------------------+       +-----------------------------------+   |
                                       |                                                                       |
                                       |   +-------------------+       +-----------------------------------+   |
                                       |   |                   |       |                                   |   |
                                       |   |    CRM API        |<------+        Lambda (CRM Mock)          |   |
                                       |   |                   |       |                                   |   |
                                       |   +---------+---------+       +-----------------------------------+   |
                                       |             ^                                                         |
                                       |             | (HTTPS / x-api-key)                                     |
                                       |             |                                                         |
                                       |   +---------+---------+                                               |
                                       |   |                   |                                               |
                                       |   |  Lambda (Main)    |                                               |
                                       |   |                   |                                               |
                                       |   +-------------------+                                               |
                                       +-----------------------------------------------------------------------+
```

### Data Flow Description

1.  **Ingestion**: User interacts via Voice or Chat. Amazon Connect handles the session.
2.  **Orchestration**: Connect invokes the Contact Flow.
3.  **Understanding**: Lex V2 interprets the user's intent.
4.  **Fulfillment**:
    *   **Known Intent**: Lex invokes Lambda. Lambda checks security (Validation Module) and executes business logic (Fulfillment Module).
    *   **Unknown Intent**: Lex invokes Lambda (Fallback). Lambda calls Bedrock to classify the text.
5.  **Data Lookup**: Lambda calls the **CRM API** (Internal Microservice) via API Gateway to fetch customer details securely using an API Key.
6.  **Authentication (Companion App)**:
    *   **Initiation**: Lambda publishes a message to **SNS**, which sends a push notification to the user's mobile app.
    *   **State Tracking**: Lambda creates a `PENDING` record in **DynamoDB (Auth State)**.
    *   **Approval**: User approves in the app. App calls **API Gateway**, which triggers **Lambda (Auth API)** to update the record to `APPROVED`.
    *   **Verification**: The main Lambda polls **DynamoDB** to confirm the approval.
7.  **Safety**: Bedrock Guardrails filter inappropriate content before it reaches the user.
8.  **Agent Routing**: If escalation is needed, Connect routes the call to the appropriate queue.
9.  **Agent Access**: Agents access the system via a secure, WAF-protected Custom CCP hosted on S3/CloudFront.

---

## 2. Component Deep Dive

### 2.1 Amazon Connect (The Core)
*   **Role**: Entry point for all voice and chat interactions.
*   **Key Features**:
    *   **Contact Flows**: Defines the customer journey (IVR).
    *   **Contact Lens**: Real-time sentiment analysis and transcription.
    *   **Voice ID**: (Optional) Passive biometric authentication.
    *   **Queues**: Routing logic for `General`, `Account`, `Lending`, and `Onboarding` queues.

### 2.2 Amazon Lex V2 (The Ear)
*   **Role**: Natural Language Understanding (NLU).
*   **Intents**:
    *   `CheckBalance`: Sensitive intent (Requires Authentication).
    *   `LoanInquiry`: Public intent (No Auth required).
    *   `OnboardingStatus`: Sensitive intent (Requires Authentication).
    *   `VerifyIdentity`: Helper intent for PIN collection.
    *   `TransferToAgent`: Explicit handover.
    *   `FallbackIntent`: Catch-all for unrecognized input.

### 2.3 Modular Lambda Fulfillment (The Brain)
The fulfillment logic is centralized in a single Lambda function but **modularized** for maintainability and performance.

*   **Path**: `connect_comprehensive_stack/lambda/lex_fallback/`
*   **Structure**:
    *   `lambda_function.py`: **Entry Point**. Handles event routing, session state management, and orchestrates the flow between validation and fulfillment.
    *   `validation.py`: **Security Layer**.
        *   **Identification**: Passive lookup of ANI (Phone Number) against `MOCK_DATA`.
        *   **Tier 1 (Biometric)**: Checks `VoiceIdStatus` (if `ENABLE_VOICE_ID` is true).
        *   **Tier 2 (Knowledge)**: Challenges user for a PIN (if `ENABLE_PIN_VALIDATION` is true).
    *   `fulfillment.py`: **Business Logic**. Contains specific handlers for `CheckBalance`, `LoanInquiry`, etc.
    *   `utils.py`: **Helpers**. Standardized Lex response builders (`close`, `delegate`, `elicit_slot`) and logging.

### 2.4 Amazon Bedrock (The Safety Net)
*   **Role**: Intelligent Fallback and Guardrails.
*   **Flow**: When Lex triggers `FallbackIntent`, the Lambda calls Bedrock to classify the utterance.
    *   If it matches a known intent (but Lex missed it), it re-routes.
    *   If it's a completely new intent, it logs it to **DynamoDB** for analysis.
*   **Guardrails**: Filters out harmful, PII, or off-topic content (e.g., financial advice restrictions).

### 2.5 Custom Agent Workspace (CCP)
*   **Role**: Secure interface for agents.
*   **Components**:
    *   **S3 Static Website**: Hosts the custom CCP HTML/JS.
    *   **CloudFront**: Delivers the site globally with low latency.
    *   **AWS WAF**: Protects the agent portal from common web exploits (SQLi, XSS).
    *   **Origin Access Control (OAC)**: Ensures S3 is only accessible via CloudFront.

---

## 3. User Journey Flows

### 3.1 Secure Transaction (Check Balance)

This flow demonstrates the tiered security model. The user attempts to access sensitive information (`CheckBalance`), triggering an authentication challenge.

```
User                Lex V2              Lambda (Router)     Lambda (Validation)
 |                    |                    |                    |
 | "Check Balance"    |                    |                    |
 |------------------->|                    |                    |
 |                    | Intent: CheckBal   |                    |
 |                    |------------------->|                    |
 |                    |                    | Check Auth?        |
 |                    |                    |------------------->|
 |                    |                    |                    | No (False)
 |                    |                    |<-------------------|
 |                    | Elicit Slot: PIN   |                    |
 |<-------------------|--------------------|                    |
 | "1234"             |                    |                    |
 |------------------->|                    |                    |
 |                    | Intent: VerifyID   |                    |
 |                    | Slot: PIN=1234     |                    |
 |                    |------------------->|                    |
 |                    |                    | Validate PIN       |
 |                    |                    |------------------->|
 |                    |                    |                    | Yes (True)
 |                    |                    |<-------------------|
 |                    | Delegate: CheckBal |                    |
 |<-------------------|--------------------|                    |
 |                    |                    |                    |
 |                    | Intent: CheckBal   |                    |
 |                    |------------------->|                    |
 |                    |                    | Check Auth?        |
 |                    |                    |------------------->|
 |                    |                    |                    | Yes (True)
 |                    |                    |<-------------------|
 |                    | Fulfill: Balance   |                    |
 |<-------------------|--------------------|                    |
```

### 3.2 Public Inquiry (Loan Options)

This flow demonstrates a public intent that bypasses the security validation layer.

```
User                Lex V2              Lambda (Router)     Lambda (Fulfillment)
 |                    |                    |                    |
 | "I need a loan"    |                    |                    |
 |------------------->|                    |                    |
 |                    | Intent: LoanInq    |                    |
 |                    |------------------->|                    |
 |                    |                    | Check Auth?        |
 |                    |                    | (Not Required)     |
 |                    |                    |                    |
 |                    |                    | Handle Inquiry     |
 |                    |                    |------------------->|
 |                    |                    |                    | Return Info
 |                    |                    |<-------------------|
 |                    | Fulfill: Options   |                    |
 |<-------------------|--------------------|                    |
```

### 3.3 Fallback & Classification

This flow demonstrates the AI-powered fallback mechanism using Amazon Bedrock.

```
User                Lex V2              Lambda (Router)     Amazon Bedrock
 |                    |                    |                    |
 | "Crypto Account"   |                    |                    |
 |------------------->|                    |                    |
 |                    | Intent: Fallback   |                    |
 |                    |------------------->|                    |
 |                    |                    | Classify Text      |
 |                    |                    |------------------->|
 |                    |                    |                    | "NewIntent" (0.9)
 |                    |                    |<-------------------|
 |                    | Log to DynamoDB    |                    |
 |                    |------------------->|                    |
 |                    | Close: "Noted"     |                    |
 |<-------------------|--------------------|                    |
```

### 3.4 Companion App Authentication (Seamless Out-of-Band)

This flow integrates a companion mobile app for multi-factor authentication. Instead of speaking a PIN, the user approves a push notification. The voice experience is **seamless**: the system automatically polls for the approval status, so the user does not need to verbally confirm "I'm ready".

**Additional Components Required:**
1.  **Auth State Table (DynamoDB)**: Stores temporary authentication requests (`request_id`, `status`, `user_id`).
2.  **Push Notification Service (Amazon SNS / Pinpoint)**: Sends the approval prompt to the user's device.
3.  **Auth API (API Gateway + Lambda)**: Receives the "Approve" or "Decline" signal from the mobile app.

#### Scenario A: Request Approved

```
User (Voice)      Mobile App        Lex/Connect         Lambda              Auth State DB       Auth API
 |                    |                    |                    |                    |              |
 | "Check Balance"    |                    |                    |                    |              |
 |---------------------------------------->|                    |                    |              |
 |                    |                    | Intent: CheckBal   |                    |              |
 |                    |                    |------------------->|                    |              |
 |                    |                    |                    | 1. Create Req      |              |
 |                    |                    |                    | (PENDING)          |              |
 |                    |                    |                    |------------------->|              |
 |                    |                    |                    | 2. Send Push       |              |
 |                    | <------------------|--------------------|                    |              |
 |                    |                    |                    |                    |              |
 |                    |                    | 3. Start Polling   |                    |              |
 |                    |                    | (Loop/Wait)        |                    |              |
 |                    |                    |------------------->| 4. Check Status    |              |
 |                    |                    |                    |------------------->|              |
 |                    |                    |                    | Status=PENDING     |              |
 |                    |                    |                    |<-------------------|              |
 |                    |                    |                    |                    |              |
 |                    | 5. User Approves   |                    |                    |              |
 |                    |---------------------------------------------------------------------------->|
 |                    |                    |                    |                    | 6. Update    |
 |                    |                    |                    |                    | (APPROVED)   |
 |                    |                    |                    |                    | <------------|
 |                    |                    |                    |                    |              |
 |                    |                    | (Next Poll)        |                    |              |
 |                    |                    |------------------->| 7. Check Status    |              |
 |                    |                    |                    |------------------->|              |
 |                    |                    |                    | Status=APPROVED    |              |
 |                    |                    |                    |<-------------------|              |
 |                    |                    |                    |                    |              |
 |                    |                    | Fulfill: Balance   |                    |              |
 |<-------------------|--------------------|--------------------|                    |              |
```

#### Scenario B: Request Declined

```
User (Voice)      Mobile App        Lex/Connect         Lambda              Auth State DB       Auth API
 |                    |                    |                    |                    |              |
 | "Check Balance"    |                    |                    |                    |              |
 |---------------------------------------->|                    |                    |              |
 |                    |                    | Intent: CheckBal   |                    |              |
 |                    |                    |------------------->|                    |              |
 |                    |                    |                    | 1. Create Req      |              |
 |                    |                    |                    | (PENDING)          |              |
 |                    |                    |                    |------------------->|              |
 |                    |                    |                    | 2. Send Push       |              |
 |                    | <------------------|--------------------|                    |              |
 |                    |                    |                    |                    |              |
 |                    |                    | 3. Start Polling   |                    |              |
 |                    |                    | (Loop/Wait)        |                    |              |
 |                    |                    |------------------->| 4. Check Status    |              |
 |                    |                    |                    |------------------->|              |
 |                    |                    |                    | Status=PENDING     |              |
 |                    |                    |                    |<-------------------|              |
 |                    |                    |                    |                    |              |
 |                    | 5. User Declines   |                    |                    |              |
 |                    |---------------------------------------------------------------------------->|
 |                    |                    |                    |                    | 6. Update    |
 |                    |                    |                    |                    | (DECLINED)   |
 |                    |                    |                    |                    | <------------|
 |                    |                    |                    |                    |              |
 |                    |                    | (Next Poll)        |                    |              |
 |                    |                    |------------------->| 7. Check Status    |              |
 |                    |                    |                    |------------------->|              |
 |                    |                    |                    | Status=DECLINED    |              |
 |                    |                    |                    |<-------------------|              |
 |                    |                    |                    |                    |              |
 |                    |                    | Response: "Unable  |                    |              |
 |                    |                    | to process req."   |                    |              |
 |<-------------------|--------------------|--------------------|                    |              |
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
| `enable_voice_id` | Feature flag for Biometric Auth | `false` |
| `enable_pin_validation` | Feature flag for PIN Auth | `false` |
| `mock_data` | JSON string for customer lookup | (Default JSON provided) |

### 4.3 Feature Flags & Environment Variables
Terraform injects configuration directly into the Lambda environment:
*   `ENABLE_VOICE_ID` -> Controls logic in `validation.py`.
*   `ENABLE_PIN_VALIDATION` -> Controls logic in `validation.py`.
*   `MOCK_DATA` -> Parsed by `validation.py` to simulate a CRM lookup.

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
