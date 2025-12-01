locals {
  vpc_id             = data.terraform_remote_state.live_chat.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.live_chat.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.live_chat.outputs.private_subnet_ids
  api_url            = data.terraform_remote_state.live_chat.outputs.api_url
  realtime_api_url   = data.terraform_remote_state.live_chat.outputs.realtime_api_url
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stack       = "Speech-to-Speech"
  }
}

module "nlb" {
  source = "../resources/nlb"

  project_name = var.project_name
  vpc_id       = local.vpc_id
  subnet_ids   = local.public_subnet_ids
  tags         = local.tags
}

module "ecs" {
  source = "../resources/ecs"

  project_name       = var.project_name
  vpc_id             = local.vpc_id
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.ecs_sg.id]
  container_image    = var.container_image
  target_group_arn   = module.nlb.target_group_arn
  
  environment_variables = {
    API_URL          = local.api_url
    REALTIME_API_URL = local.realtime_api_url
    AWS_REGION       = var.aws_region
  }

  task_role_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "execute-api:Invoke"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_name}-speech-ecs-sg"
  description = "Security group for Speech Gateway ECS tasks"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}
