terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 0.1"
    }
  }

  # -------------------------------------------------------------------------
  # Remote State Configuration (S3 Backend)
  # -------------------------------------------------------------------------
  # Uncomment and configure the following block to enable remote state storage.
  # This ensures state is stored securely in S3 and locked via DynamoDB.
  #
  # backend "s3" {
  #   bucket         = "YOUR_TERRAFORM_STATE_BUCKET"
  #   key            = "connect-nova-sonic-hybrid/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "YOUR_TERRAFORM_LOCK_TABLE"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}
