terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.30.0"
    }
  }

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

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "galgu-PolybotServiceVPC-tf"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "galgu-PolybotServiceIGW-tf"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "galgu-PolybotServiceRT-tf"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.main.id
  depends_on     = [aws_internet_gateway.main]
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.main.id
  depends_on     = [aws_internet_gateway.main]
}

resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[0]
  availability_zone       = var.availability_zone[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "galgu-public-subnet1-tf"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[1]
  availability_zone       = var.availability_zone[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "galgu-public-subnet2-tf"
  }
}
# S3 Bucket
resource "aws_s3_bucket" "polybot_bucket" {
  bucket = var.bucket_name
  tags = {
    Name      = "galgu-bucket"
    Terraform = "true"
  }
}
# Define DynamoDB table
resource "aws_dynamodb_table" "PolybotService-DynamoDB" {
  name           = var.dynamoDB_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "prediction_id"
  attribute {
    name = "prediction_id"
    type = "S"
  }

  tags = {
    Name = "galgu-PolybotService-DynamoDB-tf"
  }
}
# SQS Queue and Policy
resource "aws_sqs_queue" "polybot_queue" {
  name = var.sqs_queue_name
  tags = {
    Name      = "galgu-PolybotServiceQueue"
    Terraform = "true"
  }
}

resource "aws_sqs_queue_policy" "polybot_queue_policy" {
  queue_url = aws_sqs_queue.polybot_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "__default_policy_ID"
    Statement = [
      {
        Sid       = "__owner_statement"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::019273956931:root"
        }
        Action   = "SQS:*"
        Resource = aws_sqs_queue.polybot_queue.arn
      }
    ]
  })
}


module "polybot" {
  source               = "./modules/polybot"
  vpc_id               = aws_vpc.main.id
  public_subnet_ids    = [aws_subnet.public1.id, aws_subnet.public2.id]
  instance_ami_polybot = var.instance_ami_polybot
  instance_type_polybot = var.instance_type_polybot
  key_pair_name_polybot = var.key_pair_name_polybot
  certificate_arn       = var.certificate_arn
  region                = var.region
  is_main_region  = var.is_main_region
  iam_role_name         = var.iam_role_name
  security_group_name = var.security_group_name
}

module "yolo5" {
  source = "./modules/yolo5"

  instance_ami_yolo5     = var.instance_ami_yolo5
  instance_type_yolo5    = var.instance_type_yolo5
  key_pair_name_yolo5    = var.key_pair_name_yolo5
  vpc_id                 = aws_vpc.main.id
  region                 = var.region
  iam_role_name_yolo     = var.iam_role_name_yolo
  public_subnet_ids      = [aws_subnet.public1.id, aws_subnet.public2.id]
  asg_min_size           = 1
  asg_max_size           = 2
  asg_desired_capacity   = 1
 cpu_utilization_high_threshold = 60  # Example: Set your desired thresholds
  cpu_utilization_low_threshold  = 30  # Example: Set your desired thresholds
  scale_out_cooldown         = 300  # Example: Set your cooldown periods
  scale_in_cooldown          = 300  # Example: Set your cooldown periods
}