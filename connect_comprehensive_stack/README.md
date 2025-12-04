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
