# Lex Fulfillment & Customer Validation Guide

This document details how the **Connect Comprehensive Stack** handles automated customer servicing, API integrations, and customer validation using Amazon Lex and AWS Lambda.

## 1. Architecture Overview (Hybrid Model)

The solution uses a **Hybrid Hub-and-Spoke** fulfillment model. Amazon Lex captures user intent and invokes a central **Router Lambda**. This router intelligently dispatches requests either to specialized, deterministic Lambdas (for speed/cost) or to Amazon Bedrock (for complex/generative tasks).

```mermaid
graph TD
    User((User)) <--> Connect[Amazon Connect]
    Connect <--> Lex[Amazon Lex V2]
    Lex <--> Router[Router Lambda (Bedrock MCP)]
    
    Router -- "CheckBalance / GetStatement" --> Deterministic[Specialized Lambdas]
    Router -- "Complex / General Query" --> Bedrock[Amazon Bedrock (Claude 3.5)]
    
    Deterministic <--> APIs[Core Banking APIs]
    Bedrock <--> Tools[FastMCP Tools]
```

### The "Router" (Main Lambda)
The central Lambda function (`bedrock_mcp`) receives every intent request from Lex. It acts as a traffic controller:
1.  **Direct Dispatch**: If the intent is known and specialized (e.g., `CheckBalance`), it synchronously invokes a lightweight child Lambda.
2.  **Generative AI**: If the intent is `ChatIntent` or `FallbackIntent`, it invokes Amazon Bedrock using conversational context.

---

## 2. Automated Servicing vs. Agent Transfer

### How it works
The Lambda function's `lambda_handler` switches logic based on the `intent.name`.

#### A. Service Intents (e.g., `CheckBalance`, `LoanInquiry`)
For these intents, the Lambda performs the work automatically:
1.  **Extract Slots**: Gets parameters (e.g., account type) from the user's input.
2.  **Call API**: Queries backend systems.
3.  **Format Response**: Constructs a natural language response.
4.  **Close Dialog**: Tells Lex the interaction is done.

**Example Logic:**
```python
if intent_name == 'CheckBalance':
    balance = api.get_balance(customer_id)
    return {
        "sessionState": {
            "dialogAction": { "type": "Close" },
            "intent": {
                "name": "CheckBalance",
                "state": "Fulfilled"
            }
        },
        "messages": [{ "contentType": "PlainText", "content": f"Your balance is ${balance}." }]
    }
```

#### B. TransferToAgent
For the `TransferToAgent` intent, the Lambda does **not** fulfill the request. Instead, it sets a session attribute or returns a specific state that Amazon Connect listens for.

1.  **User says**: "I want to speak to a human."
2.  **Lex**: Identifies `TransferToAgent` intent.
3.  **Lambda**: Returns a response that signals "End of Conversation" but with a specific tag.
4.  **Connect Contact Flow**: Checks the `Lex Intent` result. If it is `TransferToAgent`, it routes the call to the `GeneralAgentQueue`.

---

## 3. Connecting to External APIs

The Lambda function runs in a standard Python environment. You can connect to any REST/GraphQL API to fetch customer data.

### Implementation Steps
1.  **Environment Variables**: Store API Endpoints in the Lambda configuration (managed via Terraform `variables.tf`).
2.  **Secrets Management**: Store API Keys/Tokens in **AWS Secrets Manager**. Do **not** hardcode them.
3.  **Networking**:
    *   **Public APIs**: The Lambda works out-of-the-box (it has internet access).
    *   **Private APIs (On-Prem/VPC)**: Configure the Lambda to run inside a VPC and use a NAT Gateway or VPC Peering.

**Code Pattern:**
```python
import requests
import boto3

def get_customer_data(customer_id):
    # 1. Retrieve API Key securely
    secrets = boto3.client('secretsmanager')
    api_key = secrets.get_secret_value(SecretId='crm-api-key')['SecretString']
    
    # 2. Call External API
    response = requests.get(
        f"https://api.yourcompany.com/customers/{customer_id}",
        headers={"Authorization": api_key}
    )
    
    return response.json()
```

---

## 4. Customer Identification & Validation

To service a customer securely, you must know **who** they are and **verify** they are who they say they are.

### Step 1: Identification (Who is calling?)
Amazon Connect automatically passes telephony metadata to Lex, which passes it to Lambda.

*   **Phone Number (ANI)**: Available in the event object.
    *   Path: `event['sessionState']['sessionAttributes']['x-amz-lex:phoneNumber']` (Note: This varies slightly based on channel, check `requestAttributes` as well).
*   **Customer ID**: If you identified the customer in the IVR *before* Lex (e.g., via a Lambda in Connect), pass it as a Session Attribute.

### Step 2: Validation (Are they authorized?)
You can implement multiple layers of validation inside the Lambda.

#### Level 1: Passive Validation (ANI Match)
Check if the incoming phone number matches a record in your CRM.
```python
phone_number = event['sessionState']['sessionAttributes'].get('PhoneNumber')
customer = crm_api.lookup_by_phone(phone_number)

if not customer:
    return ask_user("I don't recognize this number. Please say your Member ID.")
```

#### Level 2: Active Validation (PIN/DOB)
If the intent involves sensitive data (like `CheckBalance`), force a validation step.

1.  **Lambda Logic**:
    ```python
    if intent_name == 'CheckBalance':
        if not session_attributes.get('isAuthenticated'):
            # Switch context to authentication
            return {
                "sessionState": {
                    "dialogAction": { "type": "ElicitSlot", "slotToElicit": "PIN" },
                    "intent": { "name": "VerifyIdentity" }
                },
                "messages": [{ "content": "For security, please say your 4-digit PIN." }]
            }
    ```
2.  **Verify**: Once the user provides the PIN, validate it against the API. If correct, set `isAuthenticated = true` in session attributes and proceed to fulfill the original request.

#### Level 3: Voice ID (Biometric)
If Amazon Connect Voice ID is enabled:
1.  Connect analyzes the voice stream.
2.  Connect passes the `VoiceIdResult` (Auth/Fraud status) to Lex as a session attribute.
3.  **Lambda Logic**:
    ```python
    auth_status = event['sessionState']['sessionAttributes'].get('VoiceIdStatus')
    if auth_status == 'AUTHENTICATED':
        # Skip PIN, proceed directly
        return handle_check_balance()
    else:
        # Fallback to PIN
        return ask_for_pin()
    ```

---

## 5. Summary of Workflow

1.  **Call Starts**: User calls Connect.
2.  **Context**: Connect passes `PhoneNumber` to Lex.
3.  **Intent**: User says "Check my balance".
4.  **Lambda (Identification)**: Looks up `PhoneNumber` in CRM. Finds "John Doe".
5.  **Lambda (Validation)**: Checks if `VoiceId` is verified.
    *   *If No*: Lambda elicits "PIN" slot. User provides PIN. Lambda verifies.
6.  **Lambda (Fulfillment)**: Calls Banking API for "John Doe".
7.  **Response**: "John, your balance is $500."
8.  **Next Step**: Lambda asks "Anything else?".
9.  **Transfer**: If user says "Agent", Lambda returns `Delegate`. Connect routes to queue.
