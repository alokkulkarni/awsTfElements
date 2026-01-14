# Connect Comprehensive Stack

This Terraform stack deploys a complete Amazon Connect environment with a Bedrock-primary conversational AI architecture, featuring natural language understanding, intelligent tool calling, hallucination detection, and seamless agent handover.

## Features
- **Amazon Connect**: Core contact center instance with Contact Lens, Flow Logs, and comprehensive queue management.
- **AI-First Routing**: BedrockPrimaryFlow uses Lambda to analyze caller intent and dynamically route to specialized bots or queues - no hardcoded intent matching in contact flows.
- **Federated Hybrid Architecture**: A "Hub and Spoke" design where a Gateway Bot routes to specialized Bedrock for general queries or dedicated Sub-Bots (Banking, Sales) for deterministic workflows.
- **Intelligent Session Management**: Lambda sets `routing_bot` session attribute (BankingBot/SalesBot/TransferToAgent) which Connect reads to dynamically route calls after bot interaction completes.
- **Data Lake & Analytics**: Serverless data pipeline (Kinesis -> Firehose -> S3 -> Athena) for deep analysis of:
    - Contact Trace Records (CTRs)
    - Agent Events
    - **Lifecycle Events** (Real-time contact state changes for live backlog monitoring)
    - AI Insights (Hallucination logs, Latency metrics, Full query/response audit)
    - **Contact Lens Analytics** (Sentiment trends, Interruption analysis, Category matches)
    - **System Health** (CloudWatch Metrics streamed to S3 for long-term trending)
- **FastMCP 2.0 Tools**: Intelligent tool calling for account opening information, debit card details, and branch location services.
- **Smart Routing**: Hybrid router automatically dispatches requests to either Generative AI (Bedrock) or Specialized Lambdas (Python) based on intent.
- **Hallucination Detection**: Real-time validation agent that detects and prevents AI hallucinations with automated logging and metrics.
- **Seamless Agent Handover**: Intelligent detection of handover needs with conversation context preservation and queue routing.
- **Amazon Lex V2**: Simplified bot configuration that passes all input to Bedrock via Lambda for processing.
- **Queue Management**: Customer queue flow with position updates, callback options, and after-hours handling.
- **Custom CCP**: Secure, serverless Agent Workspace hosted on S3 + CloudFront with WAF protection.
- **Comprehensive Monitoring**: CloudWatch alarms for hallucination rates, error rates, and queue metrics with unified dashboard.
- **Observability**: Full CloudTrail auditing, structured logging, S3 storage for recordings and transcripts, and lifecycle policies.
- **Security**: KMS encryption (Zero Trust), IAM roles, WAF rules, and Bedrock guardrails.

## Prerequisites
- Terraform >= 1.0
- AWS Credentials configured
- Python 3.11 (for Lambda packaging)
- **Dev Container**: Use the provided `.devcontainer` for a pre-configured environment with AWS CLI, Terraform, and more.

## Deployment

1.  Initialize Terraform:
    ```bash
    terraform init
    ```

2.  Review the plan:
    ```bash
    terraform plan
    ```

3.  Apply the stack:
    ```bash
    terraform apply
    ```

4.  **Access the CCP**:
    After deployment, Terraform will output `ccp_url`. Open this URL in your browser to access the custom Agent Workspace.

## Configuration
Update `variables.tf` to customize:
- `region`: AWS Region (default: eu-west-2).
- `connect_instance_alias`: Unique alias for your Connect instance.
- `project_name`: Prefix for resources.
- `bedrock_mcp_lambda`: Lambda configuration for Bedrock MCP integration.
  - `source_dir`: Lambda source directory (default: lambda/bedrock_mcp)
  - `handler`: Lambda handler function (default: lambda_function.lambda_handler)
  - `runtime`: Python runtime version (default: python3.11)
  - `timeout`: Function timeout in seconds (default: 60)

### Environment Variables
The Bedrock MCP Lambda is configured with:
- `BEDROCK_MODEL_ID`: Claude 3.5 Sonnet model identifier
- `AWS_REGION`: Deployment region
- `LOG_LEVEL`: Logging level (INFO)
- `ENABLE_HALLUCINATION_DETECTION`: Enable validation agent (true)
- `HALLUCINATION_TABLE_NAME`: DynamoDB table for hallucination logs

## Architecture
See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture and data flow.
See [HALLUCINATION_DETECTION.md](HALLUCINATION_DETECTION.md) for validation agent details and detection algorithms.
See [QUEUE_MANAGEMENT.md](QUEUE_MANAGEMENT.md) for queue configuration and callback functionality.
See [ROUTING_PROFILES.md](ROUTING_PROFILES.md) for routing profile configuration and differences.
See [TRANSFER_GUIDE.md](TRANSFER_GUIDE.md) for transferring contacts between agents and routing profiles.
See [CCP_INTEGRATION_GUIDE.md](CCP_INTEGRATION_GUIDE.md) for branding and CRM integration instructions.

## Key Components

### Bedrock MCP Lambda
The primary fulfillment Lambda function that:
- Receives all user input from Lex via FallbackIntent
- Invokes Claude 3.5 Sonnet with conversation history and tool definitions
- Executes FastMCP 2.0 tools for account opening, debit cards, and branch location
- Validates responses using the ValidationAgent to detect hallucinations
- Detects handover needs and initiates agent transfer when required
- **Sets routing_bot session attribute** (BankingBot, SalesBot, or TransferToAgent) for Connect to route intelligently
- Returns formatted responses to Lex for delivery to the customer

### AI-First Routing Architecture
The BedrockPrimaryFlow contact flow implements intelligent routing:

1. **GatewayBot (Lex)**: All user input routes to FallbackIntent → Lambda
2. **Lambda Analysis**: Claude 3.5 Sonnet analyzes intent and determines routing:
   - Banking intents (CheckBalance, GetStatement, etc.) → `routing_bot=BankingBot`
   - Sales intents (NewProduct, Pricing) → `routing_bot=SalesBot`
   - Agent handover needs → `routing_bot=TransferToAgent`
3. **Contact Flow Routing**: After bot closes (`dialogAction.type=Close`), Compare block checks `$.Lex.SessionAttributes.routing_bot` and routes accordingly
4. **No Hardcoded Intent Matching**: Contact flows never check intent names - all routing decisions made by AI in Lambda

This architecture allows:
- **Flexible Intent Detection**: Add new intents without modifying contact flows
- **Context-Aware Routing**: AI considers conversation history and user frustration
- **Dynamic Queue Assignment**: Lambda determines target queue based on conversation context

### FastMCP 2.0 Tools
Four intelligent tools provide banking information:
1. **get_branch_account_opening_info**: Branch account opening process and requirements
2. **get_digital_account_opening_info**: Digital account opening process and requirements
3. **get_debit_card_info**: Debit card types, features, and ordering process
4. **find_nearest_branch**: Location-based branch finder with address and hours

### Validation Agent
Real-time hallucination detection that:
- Checks for fabricated data not present in tool results
- Validates domain boundaries to prevent off-topic responses
- Verifies document accuracy and branch information
- Logs hallucinations to DynamoDB with 90-day retention
- **Streams detailed logs to Data Lake for SQL-based analysis**
- Publishes CloudWatch metrics (`HallucinationDetectionRate`, `ValidationSuccessRate`, `ValidationLatency`)
- Implements severity-based response strategies (regenerate or safe fallback)

### Agent Handover
Intelligent handover detection based on:
- Explicit agent requests (keywords: "agent", "human", "person")
- Frustration detection (keywords: "frustrated", "annoyed", "useless")
- Repeated queries (same intent 3+ times)
- Capability limitations detected in Bedrock response
- Tool failure thresholds
- Error conditions requiring human intervention

### Queue Management
Customer queue flow with:
- Real-time position updates and estimated wait times
- Callback option with phone number collection
- After-hours handling with callback scheduling
- Hold music and comfort messages
- Queue metrics and abandonment tracking

## Monitoring

### CloudWatch Dashboard
Access the monitoring dashboard at: AWS Console → CloudWatch → Dashboards → `{project_name}-monitoring`

The dashboard includes:
- Hallucination detection rate and validation metrics
- Conversation metrics (duration, turns, tool usage)
- Queue metrics (size, wait times, abandonment rate)
- Error rates (Lambda, Bedrock API, validation timeouts)
- Lambda performance metrics

### CloudWatch Alarms
Alarms are configured for:
- **Hallucination Rate**: High (>10% over 5min) and Medium (>5% over 15min) severity
- **Lambda Errors**: >5% error rate over 5 minutes
- **Bedrock API Errors**: >10 errors per hour
- **Validation Timeouts**: >5 timeouts per hour
- **Queue Size**: >10 contacts in queue over 5 minutes
- **Queue Wait Time**: >5 minutes maximum wait time
- **Abandonment Rate**: >20% abandonment rate

All alarms send notifications to the SNS topic: `{project_name}-alarms`

### Logs and Audit Trail
- **Lambda Logs**: CloudWatch Logs at `/aws/lambda/{project_name}-bedrock-mcp`
- **Lex Conversation Logs**: CloudWatch Logs at `/aws/lex/{project_name}-bot`
- **Hallucination Logs**: DynamoDB table `{project_name}-hallucination-logs` (90-day TTL)
- **Callback Requests**: DynamoDB table `{project_name}-callbacks` (7-day TTL)
- **Chat Transcripts**: S3 bucket at `{project_name}-storage-{account_id}/chat-transcripts`
- **Call Recordings**: S3 bucket at `{project_name}-storage-{account_id}/call-recordings`
- **Contact Trace Records**: S3 bucket at `{project_name}-storage-{account_id}/contact-trace-records`
- **CloudTrail**: S3 bucket at `{project_name}-cloudtrail-{account_id}`

## Agent Credentials

Two agents are pre-configured for testing:

**Agent 1 (Basic Routing Profile):**
- Username: `agent1`
- Password: `Password123!`
- Use for: Testing, training, chat functionality

**Agent 2 (Main Routing Profile):**
- Username: `agent2`
- Password: `Password123!`
- Use for: Advanced testing, high-volume tasks

Login at the CCP URL output after deployment.

## Testing the System

### Test Conversation Flows
1. **Account Opening Query**: "How do I open a checking account?"
   - Tests: Tool invocation, document requirements, validation
2. **Branch Location**: "Where is the nearest branch to London?"
   - Tests: Location-based tool, branch information validation
3. **Debit Card Query**: "What debit cards do you offer?"
   - Tests: Tool invocation, card information retrieval
4. **Agent Request**: "I need to speak to a human agent"
   - Tests: Handover detection, queue routing, context preservation
5. **Complex Multi-turn**: Ask about account opening, then debit cards, then request agent
   - Tests: Conversation history, context management, handover with full context

### Monitoring Test Results
After testing, check:
- CloudWatch Dashboard for conversation metrics
- Hallucination logs in DynamoDB (should be minimal/zero)
- Lambda logs for structured event logging
- Queue metrics if agent handover was triggered

## Troubleshooting

### High Hallucination Rate
If hallucination alarms trigger:
1. Check DynamoDB hallucination logs for patterns
2. Review tool responses for completeness
3. Verify Bedrock model configuration
4. Check system prompt for clarity

### Agent Handover Not Working
If handover fails:
1. Verify TransferToAgent intent is configured in Lex
2. Check Lambda logs for handover detection events
3. Verify queue configuration in Connect
4. Test with explicit phrases: "I need an agent"

### Tool Execution Errors
If tools fail:
1. Check Lambda logs for tool invocation errors
2. Verify tool input schemas match Bedrock output
3. Test tools independently with sample inputs
4. Check IAM permissions for Lambda

### Queue Issues
If queue flow problems occur:
1. Verify customer queue flow is associated with GeneralAgentQueue
2. Check hours of operation configuration
3. Test callback Lambda independently
4. Review queue metrics in CloudWatch

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

Note: S3 buckets with content may need to be emptied manually before destruction.