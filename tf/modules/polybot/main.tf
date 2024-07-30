# EC2 Instances
resource "aws_instance" "polybot_instance1" {
  ami                    = var.instance_ami_polybot
  instance_type          = var.instance_type_polybot
  key_name               = var.key_pair_name_polybot
  subnet_id              = var.public_subnet_ids[0]
  security_groups        = [aws_security_group.polybot_sg.id]
  associate_public_ip_address = true
  user_data              = base64encode(templatefile("${path.module}/user_data.sh", { AWS_REGION = var.region }))
  #user_data              = templatefile("${path.module}/user_data.sh", {AWS_REGION = "var.region" })
  iam_instance_profile   = aws_iam_instance_profile.polybot_instance_profile.name

  tags = {
    Name      = "galgu-PolybotService1-tf"
    Terraform = "true"
  }
}

resource "aws_instance" "polybot_instance2" {
  ami                    = var.instance_ami_polybot
  instance_type          = var.instance_type_polybot
  key_name               = var.key_pair_name_polybot
  subnet_id              = var.public_subnet_ids[1]
  security_groups        = [aws_security_group.polybot_sg.id]
  associate_public_ip_address = true
  # user_data              = base64encode(file("${path.module}/user_data.sh"))
  iam_instance_profile   = aws_iam_instance_profile.polybot_instance_profile.name
  user_data              = base64encode(templatefile("${path.module}/user_data.sh", { AWS_REGION = var.region }))

  tags = {
    Name      = "galgu-PolybotService2-tf"
    Terraform = "true"
  }
}

data "aws_iam_role" "existing_polybot_service_role" {
  name = var.iam_role_name
}

# IAM Role and Policies
resource "aws_iam_role" "polybot_service_role" {
  count = length(data.aws_iam_role.existing_polybot_service_role.name) == 0 ? 1 : 0
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_full_access" {
  count = length(data.aws_iam_role.existing_polybot_service_role.name) == 0 ? 1 : 0
  role       = aws_iam_role.polybot_service_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
resource "aws_iam_role_policy_attachment" "sqs_full_access" {
  count = length(data.aws_iam_role.existing_polybot_service_role.name) == 0 ? 1 : 0
  role       = aws_iam_role.polybot_service_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  count = length(data.aws_iam_role.existing_polybot_service_role.name) == 0 ? 1 : 0
  role       = aws_iam_role.polybot_service_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


resource "aws_iam_role_policy_attachment" "secrets_manager_rw" {
  count = length(data.aws_iam_role.existing_polybot_service_role.name) == 0 ? 1 : 0
  role       = aws_iam_role.polybot_service_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_instance_profile" "polybot_instance_profile" {
  count = length(data.aws_iam_role.existing_polybot_service_role.name) == 0 ? 1 : 0
  name = var.iam_role_name
  role = aws_iam_role.polybot_service_role[count.index].name
}

# Create the security group only if it doesn't already exist
resource "aws_security_group" "polybot_sg" {
  name        = var.security_group_name
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

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic from anywhere"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

# Load Balancer
resource "aws_lb" "polybot_alb" {
  name               = "galgu-PolybotServiceLB-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.polybot_sg.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name      = "galgu-PolybotServiceLB-tf"
    Terraform = "true"
  }
}

# Target Group
resource "aws_lb_target_group" "polybot_tg" {
  name     = "galgu-polybot-target-group-tf"
  port     = 8443
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health_checks/"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name      = "galgu-polybot-target-group-tf"
    Terraform = "true"
  }
}


resource "aws_lb_listener" "polybot_listener_8443" {
  load_balancer_arn = aws_lb.polybot_alb.arn
  port              = 8443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.polybot_tg.arn
  }
}

resource "aws_lb_listener" "polybot_listener_443" {
  load_balancer_arn = aws_lb.polybot_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.polybot_tg.arn
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "polybot_instance1_attachment" {
  target_group_arn = aws_lb_target_group.polybot_tg.arn
  target_id        = aws_instance.polybot_instance1.id
  port             = 8443
}

resource "aws_lb_target_group_attachment" "polybot_instance2_attachment" {
  target_group_arn = aws_lb_target_group.polybot_tg.arn
  target_id        = aws_instance.polybot_instance2.id
  port             = 8443
}