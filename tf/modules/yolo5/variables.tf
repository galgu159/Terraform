variable "instance_ami_yolo5" {
  description = "AMI ID for the instance."
  type        = string
}

variable "instance_type_yolo5" {
  description = "Instance type for the instance."
  type        = string
}

variable "key_pair_name_yolo5" {
  description = "Key pair name for SSH access."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the instance will be launched."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs."
  type        = list(string)
}

variable "asg_min_size" {
  description = "Minimum size of the Auto Scaling group."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum size of the Auto Scaling group."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling group."
  type        = number
  default     = 1
}

variable "iam_role_name" {
  description = "IAM Role name for the instance profile."
  type        = string
  default     = "galgu-role-terraform-yolo5"
}