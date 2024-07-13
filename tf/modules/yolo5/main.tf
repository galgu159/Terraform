# Reuse existing IAM role and instance profile from polybot

# Launch Template
resource "aws_launch_template" "galgu_yolo5_lt-tf" {
  name_prefix   = "galgu-yolo5-lt-tf"
  image_id      = var.instance_ami_yolo5
  instance_type = var.instance_type_yolo5
  key_name      = var.key_pair_name_yolo5

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.galgu_yolo5_sg_tf.id]  # Reuse existing security group
  }

  # Use existing IAM instance profile
  iam_instance_profile {
    name = aws_iam_instance_profile.yolo5_instance_profile.name
  }

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "galgu-yolo5-instance-tf"
    }
  }

  user_data = base64encode(file("${path.module}/user_data.sh"))
}

# Auto Scaling Group
resource "aws_autoscaling_group" "galgu_yolo5_asg_tf" {
  desired_capacity     = var.asg_desired_capacity
  max_size             = var.asg_max_size
  min_size             = var.asg_min_size
  launch_template {
    id      = aws_launch_template.galgu_yolo5_lt-tf.id
    version = "$Latest"
  }
  vpc_zone_identifier = var.public_subnet_ids

  tag {
    key                 = "Name"
    value               = "galgu-yolo5-instance-tf"
    propagate_at_launch = true
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  force_delete = true
}
# Define DynamoDB table
resource "aws_dynamodb_table" "galgu_table" {
  name           = "galgu-dynamodb-table"
  billing_mode   = "PROVISIONED"  # Or "PROVISIONED" if you want to specify capacity
  read_capacity  = 1              # Set read capacity units to 1
  write_capacity = 1              # Set write capacity units to 1
  hash_key       = "prediction_id"    # Partition key attribute
  attribute {
    name = "prediction_id"
    type = "S"  # String attribute type for the partition key
  }

  tags = {
    Name = "Galgu DynamoDB Table"
  }
}
resource "aws_security_group" "galgu_yolo5_sg_tf" {
  name        = "galgu_yolo5_sg-tf"
  description = "Security group for YOLO5 instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "galgu-yolo5-sg-tf"
  }
}
# IAM Role and Policies
resource "aws_iam_role" "yolo5_role" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_policy" {
  role       = aws_iam_role.yolo5_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_policy" {
  role       = aws_iam_role.yolo5_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "sqs_policy" {
  role       = aws_iam_role.yolo5_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "secretsmanager_policy" {
  role       = aws_iam_role.yolo5_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_instance_profile" "yolo5_instance_profile" {
  name = "yolo5-instance-profile"
  role = aws_iam_role.yolo5_role.name
}
