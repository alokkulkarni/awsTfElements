terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for remote state storage in S3 with DynamoDB locking.
  backend "s3" {
    bucket         = "live-chat-content-moderation-tf-state-bucket"
    key            = "terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "live-chat-content-moderation-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
