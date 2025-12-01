terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }

  backend "s3" {
    bucket         = "live-chat-content-moderation-tf-state-bucket"
    key            = "connect-lex-chatbot.tfstate"
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
