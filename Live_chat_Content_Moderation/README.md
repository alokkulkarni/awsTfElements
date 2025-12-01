# AWS Terraform Elements

This project sets up a complete AWS architecture using Terraform, following a Zero Trust model.

## Architecture

The architecture includes:

- **Networking**: VPC, Public/Private Subnets, Security Groups.
- **Frontend**: S3 for static assets, CloudFront for CDN, WAF for security.
- **Backend**: API Gateway, Lambda, AppSync, SQS (FIFO).
- **Data**: DynamoDB tables for Hallucinations, Approved/Unapproved Messages, Prompt Store.
- **AI**: Bedrock Guardrails.
- **Security**: IAM Roles (Least Privilege), WAF.

## Modules

- `modules/networking`
- `modules/frontend`
- `modules/backend`
- `modules/data`
- `modules/security`
- `modules/ai`

## Usage

### Prerequisites
- Terraform v1.0+
- AWS CLI configured with appropriate credentials

### Inputs
The following variables can be customized in `variables.tf` or passed via `-var`:

| Name | Description | Default |
|------|-------------|---------|
| `aws_region` | AWS Region to deploy resources | `eu-west-2` |
| `project_name` | Base name for project resources | `aws-tf-elements` |
| `environment` | Deployment environment (dev, prod, etc.) | `dev` |
| `tags` | Map of tags to apply to all resources | `{ Project = "...", Environment = "...", ManagedBy = "Terraform" }` |

### Deployment

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Plan the deployment:
   ```bash
   terraform plan
   ```

3. Apply the deployment:
   ```bash
   terraform apply
   ```

### Outputs
After a successful apply, Terraform will output the following endpoints:

- **`frontend_url`**: The CloudFront URL for the web application.
- **`api_url`**: The API Gateway endpoint for message ingestion.
- **`realtime_api_url`**: The AppSync GraphQL endpoint for real-time updates.

## Zero Trust Principles

- **Least Privilege**: IAM roles are scoped to only necessary actions and resources.
- **Network Segmentation**: VPC with public/private subnets.
- **WAF**: Web Application Firewall protects the frontend.
- **Encryption**: Data at rest encryption enabled for DynamoDB and S3.
