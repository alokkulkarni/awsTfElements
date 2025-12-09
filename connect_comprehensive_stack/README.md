# Connect Comprehensive Stack

This Terraform stack deploys a complete Amazon Connect environment with Lex, Bedrock, advanced fallback logic, and a secure custom Agent Workspace (CCP).

## Features
- **Amazon Connect**: Core contact center instance with Contact Lens and Flow Logs enabled.
- **Amazon Lex V2**: Conversational AI with fallback to Bedrock.
- **Amazon Bedrock**: Generative AI for intent classification and guardrails.
- **Custom CCP**: Secure, serverless Agent Workspace hosted on S3 + CloudFront with WAF protection.
- **Observability**: Full CloudTrail auditing, X-Ray tracing for Lambda, and S3 lifecycle policies for cost optimization.
- **Security**: KMS encryption (Zero Trust), IAM roles, and WAF rules.

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
- `region`: AWS Region.
- `connect_instance_alias`: Unique alias for your Connect instance.
- `project_name`: Prefix for resources.

## Architecture
See [ARCHITECTURE.md](ARCHITECTURE.md) for details.
See [ROUTING_PROFILES.md](ROUTING_PROFILES.md) for routing profile configuration and differences.
See [TRANSFER_GUIDE.md](TRANSFER_GUIDE.md) for transferring contacts between agents and routing profiles.
See [CCP_INTEGRATION_GUIDE.md](CCP_INTEGRATION_GUIDE.md) for branding and CRM integration instructions.

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


as part of the connect_comprehensive stack we have a lambda that connect to bedrock to recougnise the fallback intent... instead of that create a lambda that connects into the bedrock but then is used as a primary mechanism to clasify the intent and then call the relevant tool to pull the data and compose a response back to user. this lambda is called by Lex bot. in this case the Lex bot just handles the query and passes to bedrock through lambda and then processes the response back to user. the lambda is written in python and uses python FastMCP 2.0 library for mcp server. it also passes the prompt to model as a banking service agent that is dealing with account opening process and ordering debit cards. can you make sure this lambda is then linked correctly to the lex bot and right detials are passed from lex to this lambda which then can go to the model. the lambda also has tools that provides response on how to open an account through branch or digital channels and required documents through both processess as well if there is a current location required all that is handled by the bedrock so it can then provide branch locaton etc. make sure everything is connected when deployed. in terms of contact flow use a simple contact flow that allows lex to perform everything. the flow greets the user and passes the control to lex bot. the flow terminates when lex bot is done with conversation and lex bot send the disconnect signal to contact flow.