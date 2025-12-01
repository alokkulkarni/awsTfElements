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
  # Partial configuration: Details are passed via -backend-config in CI/CD
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.tags
  }
}

provider "awscc" {
  region = var.aws_region
}
