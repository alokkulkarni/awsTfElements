module "vpc" {
  source = "../../../resources/vpc"

  name                     = var.project_name
  cidr_block               = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_subnet_cidrs     = var.private_subnet_cidrs
  availability_zones       = var.availability_zones
  flow_log_destination_arn = var.logs_bucket_arn

  tags = var.tags
}

