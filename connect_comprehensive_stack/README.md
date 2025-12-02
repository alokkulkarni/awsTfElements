# Connect Comprehensive Stack

This Terraform stack deploys a complete Amazon Connect environment with Lex, Bedrock, and advanced fallback logic.

## Prerequisites
- Terraform >= 1.0
- AWS Credentials configured
- Python 3.11 (for Lambda packaging)

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

## Configuration
Update `variables.tf` to customize:
- `region`: AWS Region.
- `connect_instance_alias`: Unique alias for your Connect instance.
- `project_name`: Prefix for resources.

## Architecture
See [ARCHITECTURE.md](ARCHITECTURE.md) for details.
