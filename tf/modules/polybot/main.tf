# IAM Role and Policies
resource "aws_iam_role" "polybot_role" {
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
  role       = aws_iam_role.polybot_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_policy" {
  role       = aws_iam_role.polybot_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "sqs_policy" {
  role       = aws_iam_role.polybot_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "secretsmanager_policy" {
  role       = aws_iam_role.polybot_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_instance_profile" "polybot_instance_profile" {
  name = "polybot-instance-profile"
  role = aws_iam_role.polybot_role.name
}

# Security Group
resource "aws_security_group" "polybot_sg" {
  name        = "polybot-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access from anywhere"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from anywhere"
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow application-specific traffic"
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["91.108.4.0/22"]
    description = "Allow secure traffic from specific IP range"
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["149.154.160.0/20"]
    description = "Allow secure traffic from specific IP range"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

# EC2 Instances
resource "aws_instance" "polybot_instance1" {
  ami                     = var.instance_ami_polybot
  instance_type           = var.instance_type_polybot
  key_name                = var.key_pair_name_polybot
  subnet_id               = var.public_subnet_cidrs[0]
  security_groups         = [aws_security_group.polybot_sg.id]
  associate_public_ip_address = true
  iam_instance_profile    = aws_iam_instance_profile.polybot_instance_profile.name
  availability_zone       = var.availability_zones[0]
  user_data               = base64encode(file("${path.module}/user_data.sh"))
  tags = {
    Name      = "galgu-PolybotService1-polybot-tf"
    Terraform = "true"
  }
}

resource "aws_instance" "polybot_instance2" {
  ami                     = var.instance_ami_polybot
  instance_type           = var.instance_type_polybot
  key_name                = var.key_pair_name_polybot
  subnet_id               = var.public_subnet_cidrs[1]
  security_groups         = [aws_security_group.polybot_sg.id]
  associate_public_ip_address = true
  iam_instance_profile    = aws_iam_instance_profile.polybot_instance_profile.name
  availability_zone       = var.availability_zones[1]
  user_data               = base64encode(file("${path.module}/user_data.sh"))
  tags = {
    Name      = "galgu-PolybotService2-polybot-tf"
    Terraform = "true"
  }
}

# Load Balancer
resource "aws_lb" "polybot_alb" {
  name               = "galgu-polybot-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.polybot_sg.id]
  subnets            = var.public_subnet_cidrs

  tags = {
    Name      = "galgu-polybot-lb"
    Terraform = "true"
  }
}

# ALB Target Groups
resource "aws_lb_target_group" "galgu-polybot_tg_8443-new" {
  name        = "polybot-target-group-8443-new"
  port        = 8443
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/healthcheck"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name      = "galgu-polybot-target-group-8443-tf-new"
    Terraform = "true"
  }
}

resource "aws_lb_target_group" "galgu-polybot_tg_443-new" {
  name        = "polybot-target-group-443-new"
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/healthcheck"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name      = "galgu-polybot-target-group-443-tf-new"
    Terraform = "true"
  }
}

# ALB Listeners
resource "aws_lb_listener" "polybot_listener_8443" {
  load_balancer_arn = aws_lb.polybot_alb.arn
  port              = 8443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = ""  # Add your SSL certificate ARN here

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.galgu-polybot_tg_8443-new.arn
  }
}

resource "aws_lb_listener" "polybot_listener_443" {
  load_balancer_arn = aws_lb.polybot_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = ""  # Add your SSL certificate ARN here

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.galgu-polybot_tg_443-new.arn
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "polybot_instance1_attachment_8443" {
  target_group_arn = aws_lb_target_group.galgu-polybot_tg_8443-new.arn
  target_id        = aws_instance.polybot_instance1.id
  port             = 8443
}

resource "aws_lb_target_group_attachment" "polybot_instance2_attachment_8443" {
  target_group_arn = aws_lb_target_group.galgu-polybot_tg_8443-new.arn
  target_id        = aws_instance.polybot_instance2.id
  port             = 8443
}

resource "aws_lb_target_group_attachment" "polybot_instance1_attachment_443" {
  target_group_arn = aws_lb_target_group.galgu-polybot_tg_443-new.arn
  target_id        = aws_instance.polybot_instance1.id
  port             = 443
}

resource "aws_lb_target_group_attachment" "polybot_instance2_attachment_443" {
  target_group_arn = aws_lb_target_group.galgu-polybot_tg_443-new.arn
  target_id        = aws_instance.polybot_instance2.id
  port             = 443
}