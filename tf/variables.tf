variable "region" {
  description = "AWS region"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "availability zones"
  default = ""
}

variable "availability_zones" {
  description = "availability zones"
  default = ""
}



variable "public_subnet_cidrs" {
  default = ""
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

variable "aws_lb_target_group" {
  default = ""
}