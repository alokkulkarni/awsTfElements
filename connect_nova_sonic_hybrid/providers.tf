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
  
  backend "s3" {
    bucket         = "live-chat-content-moderation-tf-state-bucket"
    key            = "connect-nova-sonic-hybrid/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "live-chat-content-moderation-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}
