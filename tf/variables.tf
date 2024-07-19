variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone" {
  description = "availability zones"
  default = ""
}

variable "iam_role_name_polybot" {
  description = "The name of the IAM role for the Polybot instance"
  type        = string
  default     = "polybot-role"
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "polybot_predictions"
}


variable "public_subnets" {
  description = "Public Subnet for PolyBot instances"
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}


variable "instance_ami_polybot" {
  description = "instance ami for the polybot"
  default = ""
}

variable "instance_type_polybot" {
  description = "instance type for the polybot"
  default = ""
}

variable "key_pair_name_polybot" {
  description = "EC2 Key Pair for polybot Paris"
  default = ""
}

variable "my_queue" {
  description = "queue"
  default = ""
}

variable "instance_ami_yolo5" {
  description = "instance ami for the yolo5"
  default = ""
}

variable "instance_type_yolo5" {
  description = "instance type for the yolo5"
  default = ""
}

variable "key_pair_name_yolo5" {
  description = "EC2 Key Pair for yolo5 Paris"
  default = ""
}

variable "lb_target_group_arn" {
  description = "The ARN of the load balancer target group."
  type        = string
}

variable "TF_VAR_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS listener"
  type        = string
  default = ""
}
variable "certificate_arn" {
  description = "The ARN of the ACM certificate for HTTPS"
  type        = string
}


variable "aws_lb_target_group" {
  default = ""
}

variable "cpu_utilization_high_threshold" {
  default = ""
}
variable "cpu_utilization_low_threshold" {
  default = ""
}
variable "scale_out_cooldown" {
  default = ""
}
variable "scale_in_cooldown" {
  default = ""
}
variable "telegram_token" {
  description = "Telegram Token"
  type = string
  default = ""
}