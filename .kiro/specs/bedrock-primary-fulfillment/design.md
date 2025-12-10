# Design Document

## Overview

This design transforms the Connect Comprehensive Stack from a Lex-centric intent classification system to a Bedrock-powered primary fulfillment architecture. The new design leverages Amazon Bedrock's Claude 3.5 Sonnet model with FastMCP 2.0 tool calling to handle all banking service queries, specifically focusing on account opening processes and debit card ordering.

### Key Design Principles

1. **Bedrock-First**: All intent classification and response generation happens in Bedrock, not Lex
2. **Tool-Based Architecture**: Use FastMCP 2.0 tools to provide structured, accurate banking information
3. **Simplicity**: Minimize Lex configuration complexity by using it as a pass-through
4. **Quality Assurance**: Implement validation agent to detect and manage hallucinations
5. **Conversation Context**: Maintain conversation history for natural, contextual interactions
6. **Natural Interaction**: Design conversations to be indistinguishable from human agents
7. **Seamless Handover**: Enable smooth transitions to human agents when needed

### Architecture Shift

**Before (Fallback-Based):**
```
User → Connect → Lex (Intent Classification) → Lambda (Fulfillment) → [Fallback] → Bedrock
```

**After (Bedrock-Primary):**
```
User → Connect → Lex (Pass-through) → Lambda → Bedrock (Classification + Tools) → Validation → Response
```

## Architecture

### High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Amazon Connect Contact Flow                         │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  1. Greeting: "Welcome to banking service..."                      │    │
│  │  2. Connect to Lex Bot                                             │    │
│  │  3. On Disconnect Signal → End Session                             │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Amazon Lex V2 Bot                                 │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  • Single FallbackIntent (catches all input)                       │    │
│  │  • Immediately invokes Lambda with full transcript                 │    │
│  │  • Returns Lambda response to user                                 │    │
│  │  • Manages session attributes (conversation history)               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Lambda Function (Primary Orchestrator)                  │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  1. Extract user input and conversation history                   │    │
│  │  2. Call Bedrock with system prompt + tools                        │    │
│  │  3. If tool_use → Execute MCP tools                                │    │
│  │  4. Send tool results back to Bedrock                              │    │
│  │  5. Validate response with Validation Agent                        │    │
│  │  6. Return formatted response to Lex                               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
           │                                    │                        │
           ▼                                    ▼                        ▼
┌──────────────────────┐      ┌──────────────────────────┐   ┌─────────────────┐
│  Amazon Bedrock      │      │   FastMCP 2.0 Tools      │   │  Validation     │
│  Claude 3.5 Sonnet   │      │                          │   │  Agent          │
│                      │      │  • get_branch_account_   │   │                 │
│  • Intent classify   │      │    opening_info          │   │  • Check for    │
│  • Tool selection    │      │  • get_digital_account_  │   │    hallucination│
│  • Response synthesis│      │    opening_info          │   │  • Log issues   │
│                      │      │  • get_debit_card_info   │   │  • Metrics      │
│                      │      │  • find_nearest_branch   │   │                 │
└──────────────────────┘      └──────────────────────────┘   └─────────────────┘
                                                                      │
                                                                      ▼
                                                          ┌─────────────────────┐
                                                          │  DynamoDB Table     │
                                                          │  (Hallucination     │
                                                          │   Logs)             │
                                                          └─────────────────────┘
```

### Data Flow Sequence

#### Scenario 1: Simple Query (No Tool Use)

```
User: "What types of accounts can I open?"
  │
  ├─> Connect Flow: Pass to Lex
  │
  ├─> Lex: Invoke Lambda with transcript
  │
  ├─> Lambda: Call Bedrock with system prompt
  │
  ├─> Bedrock: Generate response (no tools needed)
  │     Response: "We offer checking, savings, business, and student accounts..."
  │
  ├─> Validation Agent: Validate response
  │
  ├─> Lambda: Format for Lex
  │
  └─> User receives response
```

#### Scenario 2: Tool-Based Query

```
User: "How do I open a checking account online?"
  │
  ├─> Connect Flow: Pass to Lex
  │
  ├─> Lex: Invoke Lambda with transcript
  │
  ├─> Lambda: Call Bedrock with system prompt + tools
  │
  ├─> Bedrock: Classify intent → Need tool "get_digital_account_opening_info"
  │     Returns: tool_use with parameters {account_type: "checking"}
  │
  ├─> Lambda: Execute MCP tool
  │
  ├─> Tool: Return structured data (documents, steps, timeline)
  │
  ├─> Lambda: Send tool results back to Bedrock
  │
  ├─> Bedrock: Synthesize natural response from tool data
  │     Response: "To open a checking account online, you'll need..."
  │
  ├─> Validation Agent: Validate response against tool data
  │
  ├─> Lambda: Format for Lex
  │
  └─> User receives response
```

#### Scenario 3: Hallucination Detected

```
User: "What documents do I need for a savings account?"
  │
  ├─> [Normal flow through Connect → Lex → Lambda → Bedrock → Tool]
  │
  ├─> Bedrock: Generate response with tool data
  │     Response includes: "You'll need a passport and proof of income..."
  │
  ├─> Validation Agent: Check response against tool results
  │     ❌ HALLUCINATION DETECTED: "proof of income" not in tool results
  │
  ├─> Validation Agent: Log to DynamoDB
  │     {
  │       timestamp, user_query, tool_results, model_response,
  │       hallucination_type: "fabricated_requirement"
  │     }
  │
  ├─> Lambda: Request regeneration with stricter prompt
  │
  ├─> Bedrock: Generate corrected response
  │     Response: "You'll need a passport and proof of address..."
  │
  ├─> Validation Agent: ✅ Validated
  │
  └─> User receives corrected response
```

## Components and Interfaces

### 1. Lambda Function (lambda_function.py)

**Purpose**: Primary orchestrator that manages the entire request-response cycle

**Key Functions**:

- `lambda_handler(event, context)`: Main entry point
  - Extracts input transcript from Lex event
  - Retrieves conversation history from session attributes
  - Orchestrates Bedrock calls and tool execution
  - Manages validation flow
  - Returns formatted Lex response

- `call_bedrock_with_tools(user_message, conversation_history)`: Bedrock invocation
  - Constructs system prompt with banking agent persona
  - Builds message history
  - Includes tool definitions
  - Invokes Bedrock Runtime API
  - Returns response with potential tool_use or handover signal

- `detect_handover_need(bedrock_response, conversation_history)`: Handover detection
  - Analyzes response for handover indicators
  - Checks for tool limitations
  - Detects customer frustration patterns
  - Returns handover decision with reason

- `initiate_agent_handover(conversation_summary, handover_reason)`: Agent transfer
  - Formats conversation context for human agent
  - Constructs polite handover message
  - Triggers Connect transfer to appropriate queue
  - Logs handover metrics

- `process_tool_calls(bedrock_response)`: Tool execution handler
  - Extracts tool_use blocks from Bedrock response
  - Calls appropriate MCP tools asynchronously
  - Collects tool results
  - Returns formatted tool_result blocks

- `format_response_for_lex(bedrock_response, final_response)`: Response formatter
  - Extracts text content from Bedrock response
  - Constructs Lex response format with sessionState and messages
  - Sets dialogAction to "Close" with intent state "Fulfilled"
  - Includes updated session attributes

**Environment Variables**:
- `BEDROCK_MODEL_ID`: Model identifier (default: anthropic.claude-3-5-sonnet-20241022-v2:0)
- `AWS_REGION`: AWS region for Bedrock (default: eu-west-2)
- `LOG_LEVEL`: Logging level (default: INFO)
- `ENABLE_HALLUCINATION_DETECTION`: Enable validation agent (default: true)
- `HALLUCINATION_TABLE_NAME`: DynamoDB table for hallucination logs

**IAM Permissions Required**:
- `bedrock:InvokeModel` on Claude 3.5 Sonnet
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`
- `dynamodb:PutItem` on hallucination logs table
- `cloudwatch:PutMetricData` for validation metrics

### 2. FastMCP 2.0 Tools

**Purpose**: Provide structured, accurate banking information through tool calling

**Tool Definitions**:

#### Tool 1: get_branch_account_opening_info
```python
Input Schema:
{
  "account_type": "checking" | "savings" | "business" | "student"
}

Output:
{
  "account_type": str,
  "channel": "branch",
  "documents_required": List[str],
  "process_steps": List[str],
  "processing_time": str,
  "benefits": str
}
```

**Implementation Details**:
- Maintains dictionary of document requirements per account type
- Returns 8-step process for branch account opening
- Includes timing information (immediate activation, 5-7 days for card)

#### Tool 2: get_digital_account_opening_info
```python
Input Schema:
{
  "account_type": "checking" | "savings" | "business" | "student"
}

Output:
{
  "account_type": str,
  "channel": "digital",
  "documents_required": List[str],
  "process_steps": List[str],
  "processing_time": str,
  "benefits": str,
  "requirements": str
}
```

**Implementation Details**:
- Includes digital-specific requirements (UK mobile, email, digital photo upload)
- Returns 10-step online application process
- Highlights benefits (24/7, instant approval, faster delivery)

#### Tool 3: get_debit_card_info
```python
Input Schema:
{
  "card_type": "standard" | "premium" | "contactless" | "virtual"
}

Output:
{
  "card_type": str,
  "card_details": {
    "name": str,
    "features": List[str],
    "fees": str,
    "eligibility": str,
    "delivery_time": str
  },
  "ordering_process": List[str],
  "replacement_info": str,
  "activation": str
}
```

**Implementation Details**:
- Maintains card catalog with features, fees, eligibility
- Returns 8-step ordering process
- Includes activation and replacement information

#### Tool 4: find_nearest_branch
```python
Input Schema:
{
  "location": str,  # Postal code or city
  "service_type": "account_opening" | "card_services" | "general" | "business_banking" (optional)
}

Output:
{
  "search_location": str,
  "service_requested": str,
  "branches_found": int,
  "branches": List[{
    "name": str,
    "address": str,
    "phone": str,
    "hours": str,
    "services": List[str],
    "distance": str,
    "specialists_available": bool
  }]
}
```

**Implementation Details**:
- Simulated branch database (London, Manchester, Birmingham)
- Filters by service type if specified
- Returns sorted by distance (simulated)
- Includes fallback message if no branches found

### 3. Validation Agent

**Purpose**: Detect and manage model hallucinations to ensure response accuracy

**Architecture**:
```python
class ValidationAgent:
    def validate_response(self, user_query, tool_results, model_response):
        """Main validation entry point"""
        
    def check_fabricated_data(self, tool_results, model_response):
        """Detect information not present in tool results"""
        
    def check_domain_boundaries(self, model_response):
        """Ensure response stays within banking service domain"""
        
    def check_document_accuracy(self, tool_results, model_response):
        """Validate document requirements match tool data"""
        
    def check_branch_accuracy(self, tool_results, model_response):
        """Validate branch information matches tool data"""
        
    def log_hallucination(self, hallucination_data):
        """Log detected hallucination to DynamoDB"""
        
    def publish_metrics(self, validation_result):
        """Publish validation metrics to CloudWatch"""
```

**Validation Rules**:

1. **Fabricated Data Detection**:
   - Extract key facts from model response (documents, steps, timelines)
   - Compare against tool results
   - Flag any information not present in tool data

2. **Domain Boundary Check**:
   - Maintain list of allowed topics (account opening, debit cards, branch locations)
   - Flag responses discussing unrelated topics (loans, mortgages, investments)

3. **Document Accuracy**:
   - Extract document requirements from response
   - Compare against tool-provided document lists
   - Flag additions, omissions, or modifications

4. **Branch Information Accuracy**:
   - Extract branch details (address, phone, hours)
   - Compare against tool-provided branch data
   - Flag any discrepancies

**Hallucination Response Strategy**:

```python
if hallucination_detected:
    if severity == "high":
        # Replace with safe fallback
        return "I want to make sure I give you accurate information. Let me transfer you to a specialist."
    elif severity == "medium":
        # Request regeneration with stricter constraints
        regenerate_with_prompt("Only use information from tool results. Do not add any additional information.")
    else:
        # Log but allow (minor formatting differences)
        log_and_continue()
```

### 4. Lex Bot Configuration

**Purpose**: Act as a simple pass-through between Connect and Lambda

**Configuration**:
- **Bot Name**: `connect-comprehensive-bot`
- **Locales**: en_GB (primary), en_US (secondary)
- **Intents**: Single FallbackIntent
- **Fulfillment**: Lambda function invocation
- **Session Timeout**: 300 seconds (5 minutes)

**FallbackIntent Configuration**:
```json
{
  "name": "FallbackIntent",
  "description": "Catches all user input and passes to Bedrock via Lambda",
  "fulfillmentCodeHook": {
    "enabled": true
  },
  "intentConfirmationSetting": {
    "active": false
  }
}
```

**Bot Alias Configuration**:
- **Alias Name**: `prod`
- **Conversation Logs**: Enabled (CloudWatch)
- **Lambda Association**: bedrock-mcp Lambda function

### 5. Contact Flow with Input Preservation

**Purpose**: Provide simple entry point that greets user and connects to Lex without losing customer input

**Design Challenge**: Traditional contact flows that play a greeting message before connecting to Lex can lose customer input if the customer starts speaking during the greeting. This creates a poor user experience where customers have to repeat themselves.

**Solution**: Use the ConnectParticipantWithLexBot action's built-in greeting capability, which allows the greeting to be played while simultaneously capturing customer input.

**Flow Structure**:

```json
{
  "Actions": [
    {
      "Identifier": "connect-to-lex",
      "Type": "ConnectParticipantWithLexBot",
      "Parameters": {
        "Text": "Hello! Welcome to our banking service. I can help you with opening accounts and ordering debit cards. How can I assist you today?",
        "LexV2Bot": {
          "AliasArn": "${lex_bot_alias_arn}"
        }
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          {
            "NextAction": "error-handler",
            "ErrorType": "NoMatchingError"
          },
          {
            "NextAction": "error-handler",
            "ErrorType": "NoMatchingCondition"
          }
        ]
      }
    },
    {
      "Identifier": "error-handler",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Let me connect you with one of our specialists who can assist you. One moment please."
      },
      "Transitions": {
        "NextAction": "transfer-to-agent"
      }
    },
    {
      "Identifier": "transfer-to-agent",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${general_agent_queue_arn}"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          {
            "NextAction": "queue-full-handler",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "queue-full-handler",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "All our specialists are currently assisting other customers. Would you like to hold, or may I take your contact information for a callback?"
      },
      "Transitions": {
        "NextAction": "disconnect"
      }
    },
    {
      "Identifier": "disconnect",
      "Type": "DisconnectParticipant",
      "Parameters": {}
    }
  ]
}
```

**Flow Characteristics**:
- **Input Preservation**: Greeting is delivered via Lex connection, not separate message block
- **No Input Loss**: Customer can start speaking immediately, input is captured and processed
- **Seamless Experience**: No awkward pauses or need to repeat information
- **Error Handling**: All errors result in agent transfer with professional messaging
- **Queue Management**: Handles queue full scenarios with callback offer

**How Input Preservation Works**:

1. **Contact Initiated**: Customer connects to the flow
2. **Lex Connection with Greeting**: The ConnectParticipantWithLexBot action:
   - Plays the greeting message
   - Simultaneously starts listening for customer input
   - Captures any speech/text during or after greeting
3. **First Message Processing**: 
   - If customer speaks during greeting, that input is captured
   - Lex receives the input as the first user message
   - Lambda processes it with full context
4. **Conversation Continues**: Normal back-and-forth until completion or handover

**Alternative Approach (For Voice Channels)**:

If the above approach doesn't work for voice channels, use a "Get Customer Input" block with barge-in enabled:

```json
{
  "Identifier": "greeting-with-input",
  "Type": "GetParticipantInput",
  "Parameters": {
    "Text": "Hello! Welcome to our banking service. I can help you with opening accounts and ordering debit cards. How can I assist you today?",
    "LexV2Bot": {
      "AliasArn": "${lex_bot_alias_arn}"
    },
    "BargeInEnabled": true
  },
  "Transitions": {
    "NextAction": "disconnect",
    "Errors": [
      {
        "NextAction": "error-handler",
        "ErrorType": "NoMatchingError"
      }
    ]
  }
}
```

**Error Handling Philosophy**:
- All errors result in agent transfer, not disconnect
- Customer never sees technical error messages
- Handover messages are professional and natural
- No mention of "technical difficulties", "system errors", or "support lines"
- Seamless experience even during failures
- No customer input is ever lost or discarded

## Data Models

### Conversation History Model

**Storage**: Lex session attributes (JSON string)

**Structure**:
```python
conversation_history = [
    {
        "role": "user",
        "content": "How do I open a checking account?"
    },
    {
        "role": "assistant",
        "content": "I can help you with that! Would you prefer to open..."
    },
    # ... up to 20 messages (10 exchanges)
]
```

**Management**:
- Initialized as empty list on first interaction
- Appended with each user message and assistant response
- Trimmed to last 20 messages when exceeds limit
- Serialized to JSON string for storage in session attributes
- Deserialized on each Lambda invocation

### Hallucination Log Model

**Storage**: DynamoDB table

**Schema**:
```python
{
    "log_id": str,  # Partition key (UUID)
    "timestamp": str,  # Sort key (ISO 8601)
    "user_query": str,
    "tool_name": str,
    "tool_results": dict,
    "model_response": str,
    "hallucination_type": str,  # "fabricated_data", "off_topic", "incorrect_documents", "incorrect_branch"
    "severity": str,  # "low", "medium", "high"
    "validation_details": dict,
    "action_taken": str,  # "logged", "regenerated", "fallback"
    "session_id": str,
    "ttl": int  # 90 days retention
}
```

**Indexes**:
- GSI on `hallucination_type` for analysis
- GSI on `timestamp` for time-series queries

### Tool Result Model

**Structure** (Internal):
```python
{
    "type": "tool_result",
    "tool_use_id": str,  # From Bedrock tool_use block
    "content": str  # JSON string of tool output
}
```

## Error Handling

### Error Categories and Responses

1. **Bedrock API Errors**:
   - **Throttling**: Implement exponential backoff, max 3 retries
   - **Model Not Found**: Log error, return fallback message
   - **Invalid Request**: Log error, return fallback message
   - **Timeout**: Return partial response if available, otherwise fallback

2. **Tool Execution Errors**:
   - **Invalid Parameters**: Return error to Bedrock for handling
   - **Tool Not Found**: Return error message to Bedrock
   - **Execution Timeout**: Return timeout message to Bedrock

3. **Validation Errors**:
   - **Hallucination Detected**: Log and regenerate or use fallback
   - **Validation Timeout**: Allow response but log warning
   - **DynamoDB Write Failure**: Log to CloudWatch, continue with response

4. **Lex Integration Errors**:
   - **Invalid Event Format**: Log error, return error response
   - **Session Attribute Parse Error**: Initialize new session
   - **Response Format Error**: Log error, return safe fallback

### Fallback Messages

```python
FALLBACK_MESSAGES = {
    "general": "I apologize, but I'm having trouble processing your request. Could you please rephrase your question?",
    "technical": "I'm experiencing technical difficulties. Please try again in a moment.",
    "transfer": "I want to make sure you get accurate information. Let me transfer you to a specialist who can help.",
    "timeout": "This is taking longer than expected. Let me transfer you to someone who can assist you directly."
}
```

## Testing Strategy

### Unit Tests

1. **Lambda Handler Tests**:
   - Test event parsing (valid and invalid formats)
   - Test conversation history management
   - Test response formatting
   - Test error handling

2. **Bedrock Integration Tests**:
   - Test tool_use response handling
   - Test direct response handling
   - Test error responses
   - Test timeout handling

3. **Tool Tests**:
   - Test each tool with valid parameters
   - Test each tool with invalid parameters
   - Test tool response format
   - Test edge cases (unknown locations, invalid account types)

4. **Validation Agent Tests**:
   - Test fabricated data detection
   - Test domain boundary checking
   - Test document accuracy validation
   - Test branch information validation
   - Test hallucination logging

### Integration Tests

1. **End-to-End Flow Tests**:
   - Test simple query (no tools)
   - Test tool-based query (single tool)
   - Test multi-turn conversation
   - Test conversation history persistence
   - Test hallucination detection and recovery

2. **Lex Integration Tests**:
   - Test Lambda invocation from Lex
   - Test session attribute management
   - Test response format compatibility
   - Test error handling

3. **Connect Integration Tests**:
   - Test contact flow execution
   - Test greeting message
   - Test Lex connection
   - Test disconnect handling
   - Test error scenarios

### Performance Tests

1. **Latency Tests**:
   - Measure Lambda cold start time
   - Measure Bedrock API response time
   - Measure tool execution time
   - Measure validation time
   - Target: < 3 seconds total response time

2. **Concurrency Tests**:
   - Test multiple simultaneous conversations
   - Test Lambda scaling behavior
   - Test Bedrock throttling handling

3. **Load Tests**:
   - Simulate 100 concurrent users
   - Monitor error rates
   - Monitor response times
   - Monitor cost per conversation

### Validation Tests

1. **Hallucination Detection Tests**:
   - Test with known hallucination examples
   - Test false positive rate
   - Test false negative rate
   - Test regeneration success rate

2. **Response Quality Tests**:
   - Test response accuracy against tool data
   - Test response completeness
   - Test response tone and professionalism
   - Test conversation flow naturalness

## Deployment Considerations

### Terraform Changes Required

1. **Lambda Function**:
   - Update source directory to `lambda/bedrock_mcp`
   - Add FastMCP 2.0 library to requirements.txt
   - Update environment variables
   - Add DynamoDB permissions for hallucination logs

2. **Lex Bot**:
   - Simplify to single FallbackIntent
   - Remove complex intent definitions
   - Update Lambda association

3. **Contact Flow**:
   - Create new simplified flow template
   - Update greeting message
   - Remove complex routing logic

4. **DynamoDB Table**:
   - Create hallucination logs table
   - Configure TTL for 90-day retention
   - Create GSI indexes

5. **CloudWatch**:
   - Create alarms for hallucination rate
   - Create dashboard for validation metrics

### Deployment Steps

1. Package Lambda with dependencies (FastMCP 2.0)
2. Deploy DynamoDB table for hallucination logs
3. Deploy Lambda function with updated code
4. Update Lex bot configuration
5. Deploy simplified contact flow
6. Update Lambda permissions
7. Test end-to-end flow
8. Monitor CloudWatch metrics

### Rollback Plan

1. Keep existing Lambda version as backup
2. Maintain existing Lex bot configuration
3. Keep existing contact flow as fallback
4. Use Lambda aliases for gradual rollout
5. Monitor error rates and rollback if > 5%

## Security Considerations

1. **Data Privacy**:
   - Do not log PII in hallucination logs
   - Encrypt DynamoDB table at rest
   - Use KMS for encryption keys

2. **IAM Permissions**:
   - Least privilege for Lambda role
   - Separate roles for different functions
   - Regular permission audits

3. **API Security**:
   - Use VPC endpoints for Bedrock if available
   - Implement request signing
   - Monitor for unusual API patterns

4. **Conversation Security**:
   - Clear session attributes on disconnect
   - Implement session timeout
   - Do not persist sensitive information

## Monitoring and Observability

### CloudWatch Metrics

1. **Functional Metrics**:
   - `HallucinationDetectionRate`: Percentage of responses flagged
   - `ToolInvocationCount`: Number of tool calls per conversation
   - `ResponseLatency`: Time from request to response
   - `ValidationSuccessRate`: Percentage of responses passing validation

2. **Error Metrics**:
   - `BedrockAPIErrors`: Count of Bedrock API failures
   - `ToolExecutionErrors`: Count of tool execution failures
   - `ValidationErrors`: Count of validation failures

3. **Business Metrics**:
   - `ConversationsPerHour`: Conversation volume
   - `AverageConversationLength`: Number of turns per conversation
   - `TransferRate`: Percentage of conversations transferred to agents

### CloudWatch Alarms

1. **Critical Alarms**:
   - Hallucination rate > 10% (5-minute window)
   - Error rate > 5% (5-minute window)
   - Response latency > 5 seconds (p95)

2. **Warning Alarms**:
   - Hallucination rate > 5% (15-minute window)
   - Tool execution failures > 10/hour
   - Validation timeouts > 5/hour

### Logging Strategy

1. **Structured Logging**:
   - Use JSON format for all logs
   - Include correlation IDs
   - Log levels: DEBUG, INFO, WARN, ERROR

2. **Log Content**:
   - Request/response pairs (sanitized)
   - Tool invocations and results
   - Validation decisions
   - Error details with stack traces

3. **Log Retention**:
   - CloudWatch Logs: 30 days
   - Hallucination logs (DynamoDB): 90 days
   - Lex conversation logs: 30 days


## Agent Handover Design

### Handover Triggers

The system monitors for several conditions that indicate a need for human agent assistance:

1. **Tool Limitation**: Query requires capabilities beyond available tools
2. **Customer Frustration**: Detected through:
   - Repeated similar questions (3+ times)
   - Negative sentiment keywords ("frustrated", "annoyed", "useless")
   - Explicit requests ("speak to a person", "human agent")
3. **Complex Scenarios**: Multi-step processes requiring human judgment
4. **Sensitive Topics**: Complaints, disputes, or emotional situations
5. **Failed Resolution**: Multiple attempts (3+) without satisfactory resolution

### Handover Detection Logic

```python
def detect_handover_need(bedrock_response, conversation_history, user_message):
    """
    Analyze conversation for handover indicators
    Returns: (should_handover: bool, reason: str, message: str)
    """
    
    # Check for explicit agent requests
    agent_keywords = ["speak to agent", "human", "person", "representative", "someone"]
    if any(keyword in user_message.lower() for keyword in agent_keywords):
        return (True, "explicit_request", 
                "I'd be happy to connect you with one of our specialists. One moment please.")
    
    # Check for frustration indicators
    frustration_keywords = ["frustrated", "annoyed", "useless", "terrible", "awful"]
    if any(keyword in user_message.lower() for keyword in frustration_keywords):
        return (True, "customer_frustration",
                "I want to make sure you get the best help possible. Let me connect you with a specialist who can assist you directly.")
    
    # Check for repeated questions (same intent 3+ times)
    recent_intents = extract_intents_from_history(conversation_history, last_n=6)
    if len(recent_intents) >= 3 and len(set(recent_intents)) == 1:
        return (True, "repeated_query",
                "I'd like to connect you with a specialist who can provide more detailed assistance. One moment please.")
    
    # Check if Bedrock indicates it cannot help
    cannot_help_phrases = ["I cannot", "I'm unable", "beyond my capabilities", "I don't have"]
    response_text = extract_text_from_bedrock_response(bedrock_response)
    if any(phrase in response_text for phrase in cannot_help_phrases):
        return (True, "capability_limitation",
                "I'd be happy to connect you with one of our specialists who can better assist you with this. One moment please.")
    
    # Check for tool execution failures (3+ in conversation)
    tool_failures = count_tool_failures(conversation_history)
    if tool_failures >= 3:
        return (True, "technical_issues",
                "I'm experiencing some technical difficulties. Let me connect you with a specialist who can help you right away.")
    
    return (False, None, None)
```

### Handover Execution

```python
def initiate_agent_handover(event, conversation_history, handover_reason):
    """
    Execute handover to human agent with context
    """
    
    # Prepare conversation summary for agent
    conversation_summary = {
        "customer_query": extract_main_query(conversation_history),
        "conversation_turns": len(conversation_history) // 2,
        "topics_discussed": extract_topics(conversation_history),
        "information_collected": extract_collected_info(conversation_history),
        "handover_reason": handover_reason,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    # Determine appropriate queue based on context
    queue_arn = determine_queue(conversation_summary)
    
    # Format Lex response to trigger Connect transfer
    return {
        "sessionState": {
            "dialogAction": {
                "type": "Close"
            },
            "intent": {
                "name": "TransferToAgent",
                "state": "Fulfilled"
            },
            "sessionAttributes": {
                "conversation_summary": json.dumps(conversation_summary),
                "handover_reason": handover_reason
            }
        },
        "messages": [
            {
                "contentType": "PlainText",
                "content": get_handover_message(handover_reason)
            }
        ]
    }
```

### Contact Flow Integration

The contact flow must be updated to handle the TransferToAgent intent:

```json
{
  "Identifier": "check-intent",
  "Type": "CheckAttribute",
  "Parameters": {
    "Attribute": "IntentName",
    "ComparisonValue": "TransferToAgent"
  },
  "Transitions": {
    "NextAction": "transfer-to-queue",
    "Conditions": [
      {
        "NextAction": "transfer-to-queue",
        "Condition": {
          "Operator": "Equals",
          "Operands": ["TransferToAgent"]
        }
      }
    ],
    "Errors": [
      {
        "NextAction": "continue-lex",
        "ErrorType": "NoMatchingCondition"
      }
    ]
  }
},
{
  "Identifier": "transfer-to-queue",
  "Type": "TransferToQueue",
  "Parameters": {
    "QueueId": "${general_agent_queue_arn}"
  },
  "Transitions": {
    "NextAction": "disconnect",
    "Errors": [
      {
        "NextAction": "queue-full-message",
        "ErrorType": "NoMatchingError"
      }
    ]
  }
}
```

### Handover Messages

Professional, natural handover messages that don't reveal AI nature:

```python
HANDOVER_MESSAGES = {
    "explicit_request": "I'd be happy to connect you with one of our specialists. One moment please.",
    "customer_frustration": "I want to make sure you get the best help possible. Let me connect you with a specialist who can assist you directly.",
    "repeated_query": "I'd like to connect you with a specialist who can provide more detailed assistance. One moment please.",
    "capability_limitation": "I'd be happy to connect you with one of our specialists who can better assist you with this. One moment please.",
    "technical_issues": "I'm experiencing some technical difficulties. Let me connect you with a specialist who can help you right away.",
    "complex_scenario": "This requires some specialized assistance. Let me connect you with one of our experts. One moment please.",
    "sensitive_topic": "I'd like to connect you with a specialist who can give this the attention it deserves. One moment please."
}
```

## Natural Conversation Design

### System Prompt Enhancement

The system prompt is designed to create natural, human-like conversations:

```python
system_prompt = """You are a professional banking service specialist helping customers with account opening and debit card services. Engage naturally and conversationally - customers should feel they're speaking with a knowledgeable human colleague.

Your expertise areas:
1. Account opening (checking, savings, business, student) - both branch and digital channels
2. Required documents and eligibility for different account types
3. Debit card options, features, and ordering processes
4. Branch locations and services

Conversation guidelines:
- Use natural, varied language - avoid robotic patterns or repetitive phrases
- Ask clarifying questions conversationally: "Could you tell me a bit more about..." rather than "Please specify..."
- Acknowledge customer input naturally: "I understand," "That makes sense," "Let me help you with that"
- Present options conversationally: "You have a couple of options here..." not "Option 1:, Option 2:"
- Remember context - don't ask for information already provided
- Be warm but professional - use phrases like "I'd be happy to help" or "Great question"

When you need information from tools:
- Call the appropriate tool with correct parameters
- Synthesize tool results into natural, conversational responses
- Highlight key points without overwhelming the customer
- Offer next steps naturally

When you cannot help:
- If a query is beyond your tools or expertise, respond: "I'd be happy to connect you with one of our specialists who can better assist you with this. One moment please."
- If you detect customer frustration (repeated questions, negative tone), offer: "I want to make sure you get the best help possible. Let me connect you with a specialist who can assist you directly."
- Never explicitly state you're an AI or bot
- Always maintain a professional, helpful tone during handover

Remember: Your goal is a seamless, natural conversation that provides accurate information and excellent service."""
```

### Conversation Flow Examples

#### Example 1: Natural Account Opening Query

```
Customer: "Hi, I want to open an account"

AI: "I'd be happy to help you with that! We have a few different account types available. Are you looking for a checking account for everyday banking, a savings account, or perhaps something else?"

Customer: "Checking account"

AI: "Great choice! You can open a checking account either by visiting one of our branches or online through our website or mobile app. Which would be more convenient for you?"

Customer: "Online would be easier"

AI: "Perfect! Opening an account online is quick and straightforward. Let me get you the details on what you'll need..."

[Tool call: get_digital_account_opening_info]

AI: "Here's what you'll need to get started:

You'll need a valid photo ID like a passport or driving licence - you can just take a photo with your phone. You'll also need proof of address from the last 3 months, like a utility bill or bank statement, which you can upload as a PDF.

The whole process takes about 10-15 minutes, and you'll get instant access to your account through our mobile app once approved. Your physical debit card will arrive within 3-5 working days.

Would you like me to walk you through any specific part of the process?"
```

#### Example 2: Handover Due to Complex Query

```
Customer: "I need to open a business account but I have some tax issues I'm dealing with"

AI: "I understand you're looking to open a business account. That's something we can definitely help with. However, given the tax considerations you mentioned, I'd like to connect you with one of our business banking specialists who can give this the attention it deserves and provide guidance on how to proceed. One moment please."

[Handover initiated]
```

#### Example 3: Handling Frustration

```
Customer: "I've asked this three times already! Why can't you just tell me?"

AI: "I apologize for the confusion. I want to make sure you get the best help possible. Let me connect you with a specialist who can assist you directly and answer all your questions. One moment please."

[Handover initiated]
```

### Response Variation Techniques

To maintain natural conversation, the system uses varied responses:

1. **Acknowledgments**:
   - "I understand"
   - "That makes sense"
   - "Got it"
   - "I see"
   - "Absolutely"

2. **Transitions**:
   - "Let me help you with that"
   - "Here's what I can tell you"
   - "Let me get you that information"
   - "I'd be happy to explain"

3. **Clarifications**:
   - "Could you tell me a bit more about..."
   - "Just to make sure I understand..."
   - "To help you better, could you..."
   - "Would you mind clarifying..."

4. **Closings**:
   - "Is there anything else I can help you with?"
   - "Was there anything else you needed today?"
   - "Happy to help with anything else"
   - "Let me know if you have any other questions"

## Updated Monitoring Metrics

### Handover Metrics

1. **Handover Rate**: Percentage of conversations ending in agent transfer
2. **Handover Reasons**: Distribution of handover triggers
3. **Time to Handover**: Average conversation length before handover
4. **Post-Handover Satisfaction**: Customer satisfaction after agent assistance
5. **Handover Success Rate**: Percentage of successful transfers vs. failures

### Conversation Quality Metrics

1. **Conversation Naturalness Score**: Manual review of conversation quality
2. **Customer Satisfaction**: Post-conversation surveys
3. **Resolution Rate**: Percentage of queries resolved without handover
4. **Average Conversation Length**: Number of turns per conversation
5. **Repeat Query Rate**: Percentage of customers asking same question multiple times


## Contact Flow Design Validation

### Validation Against Requirements

✅ **Requirement 5: Input Preservation**
- Uses ConnectParticipantWithLexBot with inline Text parameter
- Greeting plays while simultaneously capturing customer input
- No separate message block that could lose input
- Customer can speak during or after greeting without loss

✅ **Requirement 11: Seamless Agent Handover**
- All errors route to error-handler → transfer-to-agent
- Professional handover message: "Let me connect you with one of our specialists..."
- No technical error messages exposed to customer
- Queue full scenario handled with callback offer
- No disconnect on errors (except after successful transfer or queue full message)

✅ **Error Handling Coverage**
- NoMatchingError → error-handler → transfer-to-agent
- NoMatchingCondition → error-handler → transfer-to-agent
- Queue transfer errors → queue-full-handler
- All paths lead to either successful conversation or agent transfer

✅ **Simplicity**
- Single entry point (connect-to-lex)
- Minimal actions (5 total)
- Clear error paths
- Easy to maintain and understand

### Flow Path Analysis

**Happy Path**:
```
Customer connects → connect-to-lex (with greeting) → Lex conversation → disconnect
```

**Error Path 1 (Lex Error)**:
```
Customer connects → connect-to-lex → Error → error-handler → transfer-to-agent → disconnect
```

**Error Path 2 (Queue Full)**:
```
Customer connects → connect-to-lex → Error → error-handler → transfer-to-agent → Queue Error → queue-full-handler → disconnect
```

**Handover Path (From Lambda)**:
```
Customer connects → connect-to-lex → Lex → Lambda detects handover need → Returns TransferToAgent intent → Flow checks intent → transfer-to-agent → disconnect
```

### Missing Element: Intent-Based Transfer

The current flow design is missing the logic to handle when Lambda returns a TransferToAgent intent. We need to add a check after Lex completes to see if the intent is TransferToAgent.

**Updated Flow Structure**:

```json
{
  "Actions": [
    {
      "Identifier": "connect-to-lex",
      "Type": "ConnectParticipantWithLexBot",
      "Parameters": {
        "Text": "Hello! Welcome to our banking service. I can help you with opening accounts and ordering debit cards. How can I assist you today?",
        "LexV2Bot": {
          "AliasArn": "${lex_bot_alias_arn}"
        }
      },
      "Transitions": {
        "NextAction": "check-intent",
        "Errors": [
          {
            "NextAction": "error-handler",
            "ErrorType": "NoMatchingError"
          },
          {
            "NextAction": "error-handler",
            "ErrorType": "NoMatchingCondition"
          }
        ]
      }
    },
    {
      "Identifier": "check-intent",
      "Type": "CheckAttribute",
      "Parameters": {
        "Attribute": "IntentName",
        "ComparisonValue": "TransferToAgent"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Conditions": [
          {
            "NextAction": "transfer-to-agent",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["TransferToAgent"]
            }
          }
        ],
        "Errors": [
          {
            "NextAction": "disconnect",
            "ErrorType": "NoMatchingCondition"
          }
        ]
      }
    },
    {
      "Identifier": "error-handler",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Let me connect you with one of our specialists who can assist you. One moment please."
      },
      "Transitions": {
        "NextAction": "transfer-to-agent"
      }
    },
    {
      "Identifier": "transfer-to-agent",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${general_agent_queue_arn}"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          {
            "NextAction": "queue-full-handler",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "queue-full-handler",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "All our specialists are currently assisting other customers. Would you like to hold, or may I take your contact information for a callback?"
      },
      "Transitions": {
        "NextAction": "disconnect"
      }
    },
    {
      "Identifier": "disconnect",
      "Type": "DisconnectParticipant",
      "Parameters": {}
    }
  ]
}
```

### Updated Flow Path Analysis

**Happy Path (No Transfer)**:
```
Customer connects → connect-to-lex (with greeting) → Lex conversation → check-intent (not TransferToAgent) → disconnect
```

**Handover Path (Lambda-Initiated)**:
```
Customer connects → connect-to-lex → Lex → Lambda returns TransferToAgent → check-intent (is TransferToAgent) → transfer-to-agent → disconnect
```

**Error Path (Lex Error)**:
```
Customer connects → connect-to-lex → Error → error-handler → transfer-to-agent → disconnect
```

**Error Path (Queue Full)**:
```
Customer connects → connect-to-lex → Error → error-handler → transfer-to-agent → Queue Error → queue-full-handler → disconnect
```

### Design Validation Summary

✅ **Input Preservation**: Greeting delivered via Lex connection, no input loss
✅ **Error Handling**: All errors route to agent transfer with professional messaging
✅ **Seamless Handover**: Lambda can trigger transfer via TransferToAgent intent
✅ **Queue Management**: Handles queue full scenarios gracefully
✅ **Simplicity**: 6 actions total, clear flow paths
✅ **Professional Messaging**: No technical jargon exposed to customers
✅ **No Disconnect on Errors**: Errors lead to agent transfer, not abrupt disconnect

### Potential Improvements

1. **Add Conversation Summary to Transfer**: When transferring, include conversation context in contact attributes
2. **Priority Routing**: Route to different queues based on handover reason (frustration → priority queue)
3. **Callback Scheduling**: If queue is full, offer to schedule a callback via Lambda
4. **Transfer Confirmation**: Optional confirmation message before transfer

These improvements can be added in future iterations without changing the core flow design.


## Queue Management and Customer Retention Design

### Problem Statement

When transferring customers to human agents, if the queue is full or all agents are busy, we must ensure customers are not lost or disconnected. Instead, they should be placed in a managed waiting queue with regular updates and options.

### Solution: Enhanced Queue Management

**Key Principles**:
1. Never disconnect a customer who needs agent assistance
2. Provide regular status updates while waiting
3. Offer alternatives (callback, voicemail) without forcing them
4. Maintain professional, reassuring tone throughout wait

### Updated Contact Flow with Queue Management

```json
{
  "Actions": [
    {
      "Identifier": "connect-to-lex",
      "Type": "ConnectParticipantWithLexBot",
      "Parameters": {
        "Text": "Hello! Welcome to our banking service. I can help you with opening accounts and ordering debit cards. How can I assist you today?",
        "LexV2Bot": {
          "AliasArn": "${lex_bot_alias_arn}"
        }
      },
      "Transitions": {
        "NextAction": "check-intent",
        "Errors": [
          {
            "NextAction": "error-handler",
            "ErrorType": "NoMatchingError"
          },
          {
            "NextAction": "error-handler",
            "ErrorType": "NoMatchingCondition"
          }
        ]
      }
    },
    {
      "Identifier": "check-intent",
      "Type": "CheckAttribute",
      "Parameters": {
        "Attribute": "IntentName",
        "ComparisonValue": "TransferToAgent"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Conditions": [
          {
            "NextAction": "transfer-to-agent",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["TransferToAgent"]
            }
          }
        ],
        "Errors": [
          {
            "NextAction": "disconnect",
            "ErrorType": "NoMatchingCondition"
          }
        ]
      }
    },
    {
      "Identifier": "error-handler",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Let me connect you with one of our specialists who can assist you. One moment please."
      },
      "Transitions": {
        "NextAction": "transfer-to-agent"
      }
    },
    {
      "Identifier": "transfer-to-agent",
      "Type": "SetQueue",
      "Parameters": {
        "QueueId": "${general_agent_queue_arn}"
      },
      "Transitions": {
        "NextAction": "check-queue-status"
      }
    },
    {
      "Identifier": "check-queue-status",
      "Type": "CheckHoursOfOperation",
      "Parameters": {
        "HoursOfOperationId": "${hours_of_operation_id}"
      },
      "Transitions": {
        "NextAction": "queue-customer",
        "Conditions": [
          {
            "NextAction": "after-hours-message",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["False"]
            }
          }
        ]
      }
    },
    {
      "Identifier": "queue-customer",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${general_agent_queue_arn}"
      },
      "Transitions": {
        "NextAction": "disconnect"
      }
    },
    {
      "Identifier": "after-hours-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Our specialists are currently unavailable. Our hours are Monday to Friday, 9 AM to 5 PM. Would you like to leave a callback number?"
      },
      "Transitions": {
        "NextAction": "get-callback-choice"
      }
    },
    {
      "Identifier": "get-callback-choice",
      "Type": "GetParticipantInput",
      "Parameters": {
        "Text": "Press 1 to leave your number for a callback, or press 2 to end this call.",
        "MaxDigits": 1,
        "Timeout": 10
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Conditions": [
          {
            "NextAction": "collect-callback-number",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["1"]
            }
          },
          {
            "NextAction": "goodbye-message",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["2"]
            }
          }
        ],
        "Errors": [
          {
            "NextAction": "goodbye-message",
            "ErrorType": "NoMatchingCondition"
          }
        ]
      }
    },
    {
      "Identifier": "collect-callback-number",
      "Type": "StoreUserInput",
      "Parameters": {
        "Text": "Please enter your phone number followed by the pound key.",
        "CustomerInputType": "Custom",
        "MaxDigits": 15
      },
      "Transitions": {
        "NextAction": "confirm-callback"
      }
    },
    {
      "Identifier": "confirm-callback",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Thank you. One of our specialists will call you back during business hours. Have a great day!"
      },
      "Transitions": {
        "NextAction": "disconnect"
      }
    },
    {
      "Identifier": "goodbye-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Thank you for contacting us. Have a great day!"
      },
      "Transitions": {
        "NextAction": "disconnect"
      }
    },
    {
      "Identifier": "disconnect",
      "Type": "DisconnectParticipant",
      "Parameters": {}
    }
  ]
}
```

### Queue Configuration

The queue itself must be configured with proper customer experience settings:

```terraform
resource "aws_connect_queue" "general_agent_queue" {
  instance_id           = module.connect_instance.id
  name                  = "GeneralAgentQueue"
  description           = "Queue for general agent assistance"
  hours_of_operation_id = data.aws_connect_hours_of_operation.default.hours_of_operation_id
  
  # Queue capacity - no hard limit, customers wait until served
  max_contacts = 0  # 0 means unlimited
  
  # Outbound caller config
  outbound_caller_config {
    outbound_caller_id_name      = "Banking Support"
    outbound_caller_id_number_id = aws_connect_phone_number.outbound.id
  }
  
  tags = var.tags
}

# Customer Queue Flow (plays while customer waits)
resource "aws_connect_contact_flow" "customer_queue_flow" {
  instance_id = module.connect_instance.id
  name        = "Customer Queue Flow"
  description = "Flow that plays while customer waits in queue"
  type        = "CUSTOMER_QUEUE"
  
  content = templatefile("${path.module}/contact_flows/customer_queue_flow.json.tftpl", {
    hold_music_arn = aws_connect_prompt.hold_music.arn
  })
}

# Associate queue flow with queue
resource "aws_connect_queue" "general_agent_queue" {
  # ... other config ...
  
  # This is not a direct Terraform resource property, but configured via:
  # 1. The queue's default customer queue flow
  # 2. Or set in the Connect console
  # 3. Or via AWS CLI/API
}
```

### Customer Queue Flow Design

This flow plays while the customer waits in queue:

```json
{
  "Version": "2019-10-30",
  "StartAction": "initial-message",
  "Metadata": {
    "entryPointPosition": { "x": 20, "y": 20 },
    "name": "CustomerQueueFlow",
    "description": "Plays while customer waits for agent",
    "type": "customerQueue"
  },
  "Actions": [
    {
      "Identifier": "initial-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Thank you for holding. All our specialists are currently assisting other customers. Your call is important to us."
      },
      "Transitions": {
        "NextAction": "check-queue-position"
      }
    },
    {
      "Identifier": "check-queue-position",
      "Type": "CheckAttribute",
      "Parameters": {
        "Attribute": "QueuePosition",
        "ComparisonValue": "1"
      },
      "Transitions": {
        "NextAction": "next-in-line-message",
        "Conditions": [
          {
            "NextAction": "next-in-line-message",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["1"]
            }
          }
        ],
        "Errors": [
          {
            "NextAction": "position-message",
            "ErrorType": "NoMatchingCondition"
          }
        ]
      }
    },
    {
      "Identifier": "next-in-line-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "You're next in line. A specialist will be with you shortly."
      },
      "Transitions": {
        "NextAction": "play-hold-music"
      }
    },
    {
      "Identifier": "position-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "You are number $.Attributes.QueuePosition in line. Estimated wait time is $.Attributes.EstimatedWaitTime minutes."
      },
      "Transitions": {
        "NextAction": "offer-callback"
      }
    },
    {
      "Identifier": "offer-callback",
      "Type": "GetParticipantInput",
      "Parameters": {
        "Text": "To continue holding, press 1. To request a callback, press 2.",
        "MaxDigits": 1,
        "Timeout": 10
      },
      "Transitions": {
        "NextAction": "play-hold-music",
        "Conditions": [
          {
            "NextAction": "play-hold-music",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["1"]
            }
          },
          {
            "NextAction": "callback-flow",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["2"]
            }
          }
        ],
        "Errors": [
          {
            "NextAction": "play-hold-music",
            "ErrorType": "NoMatchingCondition"
          }
        ]
      }
    },
    {
      "Identifier": "callback-flow",
      "Type": "InvokeExternalResource",
      "Parameters": {
        "FunctionArn": "${callback_lambda_arn}"
      },
      "Transitions": {
        "NextAction": "callback-confirmation"
      }
    },
    {
      "Identifier": "callback-confirmation",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Thank you. We'll call you back at $.Attributes.CustomerPhoneNumber within the next hour. You can end this call now."
      },
      "Transitions": {
        "NextAction": "end-flow"
      }
    },
    {
      "Identifier": "play-hold-music",
      "Type": "PlayPrompt",
      "Parameters": {
        "PromptId": "${hold_music_arn}"
      },
      "Transitions": {
        "NextAction": "wait-30-seconds"
      }
    },
    {
      "Identifier": "wait-30-seconds",
      "Type": "Wait",
      "Parameters": {
        "WaitTime": 30
      },
      "Transitions": {
        "NextAction": "comfort-message"
      }
    },
    {
      "Identifier": "comfort-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Thank you for your patience. A specialist will be with you soon."
      },
      "Transitions": {
        "NextAction": "check-queue-position"
      }
    },
    {
      "Identifier": "end-flow",
      "Type": "EndFlowExecution",
      "Parameters": {}
    }
  ]
}
```

### Queue Management Features

1. **Initial Queue Entry**:
   - Customer hears: "Thank you for holding. All our specialists are currently assisting other customers."
   - System checks queue position

2. **Position Updates** (every 30-60 seconds):
   - If position = 1: "You're next in line. A specialist will be with you shortly."
   - If position > 1: "You are number X in line. Estimated wait time is Y minutes."

3. **Callback Option**:
   - Offered periodically: "To continue holding, press 1. To request a callback, press 2."
   - If callback chosen: Lambda collects phone number and schedules callback
   - Confirmation: "We'll call you back at [number] within the next hour."

4. **Hold Music and Comfort Messages**:
   - Play hold music for 30 seconds
   - Comfort message: "Thank you for your patience. A specialist will be with you soon."
   - Loop back to position check

5. **After Hours Handling**:
   - Check hours of operation before queueing
   - If after hours: Offer callback for next business day
   - Collect callback number and preferences

### Callback Lambda Function

```python
def lambda_handler(event, context):
    """
    Handle callback request from customer in queue
    """
    # Extract customer phone number from contact attributes
    customer_phone = event.get('Details', {}).get('ContactData', {}).get('CustomerEndpoint', {}).get('Address')
    contact_id = event.get('Details', {}).get('ContactData', {}).get('ContactId')
    
    # Store callback request in DynamoDB
    callback_table.put_item(
        Item={
            'callback_id': str(uuid.uuid4()),
            'contact_id': contact_id,
            'customer_phone': customer_phone,
            'requested_at': datetime.utcnow().isoformat(),
            'status': 'PENDING',
            'queue_id': event.get('Details', {}).get('Parameters', {}).get('QueueId'),
            'priority': 'NORMAL',
            'ttl': int((datetime.utcnow() + timedelta(days=7)).timestamp())
        }
    )
    
    # Return success to contact flow
    return {
        'statusCode': 200,
        'callback_scheduled': True,
        'callback_phone': customer_phone
    }
```

### Queue Metrics and Monitoring

**CloudWatch Metrics**:
1. `QueueSize`: Number of customers waiting
2. `AverageQueueTime`: Average wait time
3. `AbandonmentRate`: Percentage of customers who hang up
4. `CallbackRequestRate`: Percentage choosing callback
5. `ServiceLevel`: Percentage answered within target time

**Alarms**:
1. Queue size > 10 for 5 minutes → Alert supervisors
2. Average wait time > 5 minutes → Alert management
3. Abandonment rate > 20% → Critical alert

### Design Validation

✅ **No Customer Loss**: TransferToQueue has no error handling that disconnects
✅ **Regular Updates**: Customer queue flow provides updates every 30-60 seconds
✅ **Callback Option**: Offered periodically without forcing
✅ **Professional Tone**: All messages are reassuring and professional
✅ **After Hours Handling**: Checks hours of operation and offers callback
✅ **Metrics**: Comprehensive monitoring of queue performance

This design ensures that once a customer needs agent assistance, they are never lost or disconnected, regardless of queue status.


## Audit and Monitoring Design

### Overview

Comprehensive logging and auditing ensures all customer interactions, Bedrock invocations, and tool calls are captured for quality assurance, compliance, and troubleshooting.

### Logging Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Customer Interaction                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Lambda Function                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Structured Logging:                                      │  │
│  │  - Input transcript                                       │  │
│  │  - Bedrock request/response                               │  │
│  │  - Tool invocations                                       │  │
│  │  - Validation results                                     │  │
│  │  - Handover decisions                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────┬────────────────────────────┬───────────────────────┘
             │                            │
             ▼                            ▼
┌────────────────────────┐   ┌───────────────────────────────────┐
│  CloudWatch Logs       │   │  S3 Bucket (Encrypted)            │
│  - Real-time logs      │   │  - Full transcripts               │
│  - 30-day retention    │   │  - Call recordings                │
│  - Searchable          │   │  - Chat transcripts               │
│  - Structured JSON     │   │  - 90-day retention               │
└────────────────────────┘   │  - KMS encrypted                  │
                             │  - Lifecycle policies             │
                             └───────────────────────────────────┘
                                          │
                                          ▼
                             ┌───────────────────────────────────┐
                             │  CloudTrail                       │
                             │  - S3 access logs                 │
                             │  - API call auditing              │
                             └───────────────────────────────────┘
```

### Structured Logging Format

All logs use JSON format for easy parsing and analysis:

```python
{
    "timestamp": "2025-10-12T14:30:45.123Z",
    "level": "INFO",
    "session_id": "abc123-def456-ghi789",
    "contact_id": "connect-contact-id-12345",
    "event_type": "bedrock_invocation",
    "data": {
        "user_message": "How do I open a checking account?",
        "bedrock_request": {
            "model_id": "anthropic.claude-3-5-sonnet-20241022-v2:0",
            "system_prompt": "[TRUNCATED]",
            "messages": [...],
            "tools": [...]
        },
        "bedrock_response": {
            "stop_reason": "tool_use",
            "content": [...]
        },
        "latency_ms": 1234
    }
}
```

### Log Event Types

1. **conversation_start**:
   ```json
   {
       "event_type": "conversation_start",
       "data": {
           "channel": "voice|chat",
           "customer_phone": "+447700900000",
           "queue_id": "queue-arn"
       }
   }
   ```

2. **user_input**:
   ```json
   {
       "event_type": "user_input",
       "data": {
           "transcript": "How do I open a checking account?",
           "input_mode": "voice|text",
           "confidence": 0.95
       }
   }
   ```

3. **bedrock_invocation**:
   ```json
   {
       "event_type": "bedrock_invocation",
       "data": {
           "model_id": "anthropic.claude-3-5-sonnet-20241022-v2:0",
           "user_message": "How do I open a checking account?",
           "conversation_history_length": 4,
           "tools_available": ["get_branch_account_opening_info", ...],
           "latency_ms": 1234
       }
   }
   ```

4. **bedrock_response**:
   ```json
   {
       "event_type": "bedrock_response",
       "data": {
           "stop_reason": "tool_use|end_turn",
           "tool_calls": [
               {
                   "tool_name": "get_digital_account_opening_info",
                   "tool_input": {"account_type": "checking"}
               }
           ],
           "response_text": "[RESPONSE]",
           "latency_ms": 1234
       }
   }
   ```

5. **tool_invocation**:
   ```json
   {
       "event_type": "tool_invocation",
       "data": {
           "tool_name": "get_digital_account_opening_info",
           "tool_input": {"account_type": "checking"},
           "tool_output": {...},
           "latency_ms": 45
       }
   }
   ```

6. **validation_check**:
   ```json
   {
       "event_type": "validation_check",
       "data": {
           "validation_passed": true,
           "hallucination_detected": false,
           "confidence_score": 0.95,
           "checks_performed": ["fabricated_data", "domain_boundary", "document_accuracy"]
       }
   }
   ```

7. **handover_decision**:
   ```json
   {
       "event_type": "handover_decision",
       "data": {
           "handover_triggered": true,
           "reason": "explicit_request",
           "conversation_turns": 3,
           "tools_used": ["get_branch_account_opening_info"]
       }
   }
   ```

8. **conversation_end**:
   ```json
   {
       "event_type": "conversation_end",
       "data": {
           "duration_seconds": 180,
           "total_turns": 6,
           "tools_used": ["get_digital_account_opening_info", "find_nearest_branch"],
           "handover_occurred": false,
           "resolution_status": "resolved|transferred|abandoned"
       }
   }
   ```

### Lambda Logging Implementation

```python
import json
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

class StructuredLogger:
    def __init__(self, session_id, contact_id):
        self.session_id = session_id
        self.contact_id = contact_id
    
    def log_event(self, event_type, data, level="INFO"):
        """Log structured event"""
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": level,
            "session_id": self.session_id,
            "contact_id": self.contact_id,
            "event_type": event_type,
            "data": data
        }
        
        log_message = json.dumps(log_entry)
        
        if level == "ERROR":
            logger.error(log_message)
        elif level == "WARN":
            logger.warning(log_message)
        else:
            logger.info(log_message)
    
    def log_conversation_start(self, channel, customer_phone, queue_id):
        self.log_event("conversation_start", {
            "channel": channel,
            "customer_phone": customer_phone,
            "queue_id": queue_id
        })
    
    def log_user_input(self, transcript, input_mode, confidence=None):
        self.log_event("user_input", {
            "transcript": transcript,
            "input_mode": input_mode,
            "confidence": confidence
        })
    
    def log_bedrock_invocation(self, model_id, user_message, history_length, tools, latency_ms):
        self.log_event("bedrock_invocation", {
            "model_id": model_id,
            "user_message": user_message,
            "conversation_history_length": history_length,
            "tools_available": tools,
            "latency_ms": latency_ms
        })
    
    def log_bedrock_response(self, stop_reason, tool_calls, response_text, latency_ms):
        self.log_event("bedrock_response", {
            "stop_reason": stop_reason,
            "tool_calls": tool_calls,
            "response_text": response_text,
            "latency_ms": latency_ms
        })
    
    def log_tool_invocation(self, tool_name, tool_input, tool_output, latency_ms):
        self.log_event("tool_invocation", {
            "tool_name": tool_name,
            "tool_input": tool_input,
            "tool_output": tool_output,
            "latency_ms": latency_ms
        })
    
    def log_validation_check(self, passed, hallucination_detected, confidence, checks):
        self.log_event("validation_check", {
            "validation_passed": passed,
            "hallucination_detected": hallucination_detected,
            "confidence_score": confidence,
            "checks_performed": checks
        })
    
    def log_handover_decision(self, triggered, reason, turns, tools_used):
        self.log_event("handover_decision", {
            "handover_triggered": triggered,
            "reason": reason,
            "conversation_turns": turns,
            "tools_used": tools_used
        })
    
    def log_conversation_end(self, duration, turns, tools_used, handover, resolution):
        self.log_event("conversation_end", {
            "duration_seconds": duration,
            "total_turns": turns,
            "tools_used": tools_used,
            "handover_occurred": handover,
            "resolution_status": resolution
        })

# Usage in lambda_handler
def lambda_handler(event, context):
    session_id = event.get('sessionId', 'unknown')
    contact_id = event.get('sessionState', {}).get('sessionAttributes', {}).get('contactId', 'unknown')
    
    structured_logger = StructuredLogger(session_id, contact_id)
    
    # Log conversation start
    structured_logger.log_conversation_start(
        channel="voice",
        customer_phone=event.get('customerPhoneNumber'),
        queue_id=event.get('queueId')
    )
    
    # ... rest of handler logic with logging at each step
```

### S3 Storage Configuration

The existing stack already has S3 storage configured, but we need to ensure it's properly set up:

```terraform
# S3 Bucket for Connect Storage (already exists in main.tf)
module "connect_storage_bucket" {
  source           = "../resources/s3"
  bucket_name      = "${var.project_name}-storage-${data.aws_caller_identity.current.account_id}"
  enable_lifecycle = true
  tags             = var.tags
}

# Connect Storage Configuration (already exists in main.tf)
resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = module.connect_instance.id
  resource_type = "CHAT_TRANSCRIPTS"

  storage_config {
    s3_config {
      bucket_name   = module.connect_storage_bucket.id
      bucket_prefix = "chat-transcripts"
      encryption_config {
        encryption_type = "KMS"
        key_id          = module.kms_key.arn
      }
    }
    storage_type = "S3"
  }
}

resource "aws_connect_instance_storage_config" "call_recordings" {
  instance_id   = module.connect_instance.id
  resource_type = "CALL_RECORDINGS"

  storage_config {
    s3_config {
      bucket_name   = module.connect_storage_bucket.id
      bucket_prefix = "call-recordings"
      encryption_config {
        encryption_type = "KMS"
        key_id          = module.kms_key.arn
      }
    }
    storage_type = "S3"
  }
}

# Add storage config for Contact Trace Records (CTRs)
resource "aws_connect_instance_storage_config" "contact_trace_records" {
  instance_id   = module.connect_instance.id
  resource_type = "CONTACT_TRACE_RECORDS"

  storage_config {
    s3_config {
      bucket_name   = module.connect_storage_bucket.id
      bucket_prefix = "contact-trace-records"
      encryption_config {
        encryption_type = "KMS"
        key_id          = module.kms_key.arn
      }
    }
    storage_type = "S3"
  }
}

# S3 Lifecycle Policy for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "connect_storage_lifecycle" {
  bucket = module.connect_storage_bucket.id

  rule {
    id     = "archive-old-recordings"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555  # 7 years for compliance
    }

    filter {
      prefix = "call-recordings/"
    }
  }

  rule {
    id     = "archive-old-transcripts"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555  # 7 years for compliance
    }

    filter {
      prefix = "chat-transcripts/"
    }
  }

  rule {
    id     = "delete-old-ctrs"
    status = "Enabled"

    expiration {
      days = 90
    }

    filter {
      prefix = "contact-trace-records/"
    }
  }
}
```

### CloudTrail Configuration

```terraform
# S3 Bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.project_name}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  tags   = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_encryption" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms_key.arn
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudTrail for S3 data events
resource "aws_cloudtrail" "connect_storage_trail" {
  name                          = "${var.project_name}-storage-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = false
  is_multi_region_trail         = false
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${module.connect_storage_bucket.arn}/*"]
    }
  }

  tags = var.tags
}
```

### Lex Conversation Logs

Lex conversation logs are already configured in the existing stack:

```terraform
# CloudWatch Log Group for Lex (already exists in main.tf)
resource "aws_cloudwatch_log_group" "lex_logs" {
  name              = "/aws/lex/${var.project_name}-bot"
  retention_in_days = 30
  tags              = var.tags
}

# Bot Alias with conversation logs (already exists in main.tf)
resource "awscc_lex_bot_alias" "this" {
  bot_id      = module.lex_bot.bot_id
  bot_alias_name = "prod"
  bot_version = aws_lexv2models_bot_version.this.bot_version
  
  conversation_log_settings = {
    text_log_settings = [
      {
        destination = {
          cloudwatch = {
            cloudwatch_log_group_arn = aws_cloudwatch_log_group.lex_logs.arn
            log_prefix               = "lex-logs"
          }
        }
        enabled = true
      }
    ]
  }
  # ... rest of config
}
```

### PII Redaction (Future Enhancement)

For PII redaction, we can use Amazon Comprehend:

```python
import boto3

comprehend = boto3.client('comprehend')

def redact_pii(text):
    """Redact PII from text using Amazon Comprehend"""
    if not os.environ.get('ENABLE_PII_REDACTION', 'false').lower() == 'true':
        return text
    
    try:
        response = comprehend.detect_pii_entities(
            Text=text,
            LanguageCode='en'
        )
        
        # Sort entities by offset in reverse order to maintain positions
        entities = sorted(response['Entities'], key=lambda x: x['BeginOffset'], reverse=True)
        
        redacted_text = text
        for entity in entities:
            start = entity['BeginOffset']
            end = entity['EndOffset']
            entity_type = entity['Type']
            redacted_text = redacted_text[:start] + f"[{entity_type}]" + redacted_text[end:]
        
        return redacted_text
    except Exception as e:
        logger.error(f"PII redaction failed: {str(e)}")
        return text  # Return original text if redaction fails
```

### Audit Query Examples

Using CloudWatch Logs Insights to query audit logs:

```sql
-- Find all conversations that resulted in handover
fields @timestamp, session_id, data.reason, data.conversation_turns
| filter event_type = "handover_decision" and data.handover_triggered = true
| sort @timestamp desc
| limit 100

-- Find all tool invocations for a specific session
fields @timestamp, data.tool_name, data.tool_input, data.latency_ms
| filter event_type = "tool_invocation" and session_id = "abc123-def456"
| sort @timestamp asc

-- Find conversations with hallucination detection
fields @timestamp, session_id, data.hallucination_detected, data.confidence_score
| filter event_type = "validation_check" and data.hallucination_detected = true
| sort @timestamp desc
| limit 50

-- Calculate average conversation duration
fields data.duration_seconds
| filter event_type = "conversation_end"
| stats avg(data.duration_seconds) as avg_duration, 
        max(data.duration_seconds) as max_duration,
        min(data.duration_seconds) as min_duration

-- Find most used tools
fields data.tool_name
| filter event_type = "tool_invocation"
| stats count() by data.tool_name
| sort count() desc
```

### Compliance and Retention

**Retention Policies**:
- CloudWatch Logs: 30 days (real-time monitoring)
- S3 Call Recordings: 7 years (compliance requirement)
- S3 Chat Transcripts: 7 years (compliance requirement)
- S3 Contact Trace Records: 90 days (operational)
- Hallucination Logs (DynamoDB): 90 days (quality improvement)

**Encryption**:
- All S3 buckets: KMS encryption with customer-managed key
- All DynamoDB tables: Encryption at rest
- CloudWatch Logs: Encrypted by default

**Access Control**:
- S3 bucket policies restrict access to Connect service and authorized IAM roles
- CloudTrail logs all S3 access for audit
- IAM policies follow least privilege principle

This comprehensive audit and monitoring design ensures full visibility into all customer interactions while maintaining security and compliance requirements.
