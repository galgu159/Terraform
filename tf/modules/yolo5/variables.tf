variable "instance_ami_yolo5" {
  description = "AMI ID for the instance."
  type        = string
}

variable "instance_type_yolo5" {
  description = "Instance type for the instance."
  type        = string
}
# IAM Role and Policies
variable "iam_role_name" {
  description = "Iam Role name for the instance"
  type = string
  default = "galgu-role-yolo5-tf"
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

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "yolo5_predictions"
}

variable "dynamodb_billing_mode" {
  description = "The billing mode of the DynamoDB table"
  type        = string
  default     = "PAY_PER_REQUEST"
}
variable "iam_instance_profile_name" {
  default = ""
}
variable "iam_role_name_yolo" {
  description = "IAM Role name for the instance"
  type = string
}
variable "cpu_utilization_high_threshold" {
  description = "High CPU utilization threshold for scaling out"
  type        = number
  default     = 60  # Adjust as needed
}

variable "cpu_utilization_low_threshold" {
  description = "Low CPU utilization threshold for scaling in"
  type        = number
  default     = 30  # Adjust as needed
}

variable "scale_out_cooldown" {
  description = "Cooldown period in seconds for scale-out actions"
  type        = number
  default     = 300  # Example: 5 minutes (adjust as needed)
}

variable "scale_in_cooldown" {
  description = "Cooldown period in seconds for scale-in actions"
  type        = number
  default     = 300  # Example: 5 minutes (adjust as needed)
}
variable "region" {
  default = ""
  type = string
}