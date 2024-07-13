terraform {
   required_providers {
   aws = {
      source  = "hashicorp/aws"
      version = "5.30.0"
    }
  }
# Save json only in eu-north-1
  backend "s3" {
    bucket = "galgu-tf-state-files"
    key    = "tfstate.json"
    region = "eu-north-1"
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}

# S3 Bucket
resource "aws_s3_bucket" "polybot_bucket" {
  bucket = "galgu-polybot-bucket-tf"
  tags = {
    Name      = "galgu-polybot-bucket-tf"
    Terraform = "true"
  }
}

# SQS Queue
resource "aws_sqs_queue" "polybot_queue" {
  name = "galgu-polybot-queue-tf"
  tags = {
    Name      = "galgu-polybot-queue-tf"
    Terraform = "true"
  }
}



module "app_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "galgu-PolybotServiceVPC-tf"
  cidr = "10.0.0.0/16"

  azs             = var.vpc_azs
  public_subnets  = var.public_subnets


  tags = {
    Name      = "galgu-PolybotServiceVPC-tf"
    Terraform = "true"
    Environment = "dev"
  }
}


module "polybot" {
  source            = "./modules/polybot"
  vpc_id            = module.app_vpc.vpc_id
  public_subnet_cidrs = module.app_vpc.public_subnets
  instance_ami_polybot = var.instance_ami_polybot
  instance_type_polybot = var.instance_type_polybot
  key_pair_name_polybot = var.key_pair_name_polybot
  availability_zones = var.availability_zones
}



module "yolo5" {
  source = "./modules/yolo5"

  instance_ami_yolo5     = var.instance_ami_yolo5
  instance_type_yolo5    = var.instance_type_yolo5
  key_pair_name_yolo5    = var.key_pair_name_yolo5
  vpc_id                 = module.app_vpc.vpc_id
  public_subnet_ids      = module.app_vpc.public_subnets
  asg_min_size           = 1
  asg_max_size           = 2
  asg_desired_capacity   = 1
}

